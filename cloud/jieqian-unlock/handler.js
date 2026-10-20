// cloud/jieqian-unlock/handler.js
// 求签额度购买记录（IAP 消耗型商品 qiu_extra，¥1 = 今日求签次数 +1，每日最多加 2 次）：
//   action=record —— 上报购买，幂等（同 purchaseToken 只记一条），落 purchaseDate（客户端本地日期）
//   action=query  —— 查该 uid 最近一次购买日期 { unlockDate: 'YYYY-MM-DD' }（客户端按本地日期比较是否「今天」）
// 客户端 data: { action, __uid, productId?, purchaseToken?, purchaseData?, orderId?, unlockDate? }
// 计费模型（2026-10-03 整改：解签免费，只有「额外求签次数」付费）：
//   付款成功 → 本地今日额度 +1（立即生效）→ 云端记录（失败不阻塞，重装/换机由 recoverPending 补单）。
//   权益按天失效，客户端 extraToday() 只认本地今天。
// ⚠️ 旧商品 jieqian_unlock（付费解签）已废弃，仅保留白名单兜底（历史订单仍可补记），不再由客户端购买。
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');

var UNLOCK_TYPE = 'SignUnlock';

// 商品白名单。必须与 AGC 控制台「应用内购买服务」配置一致（均为消耗型）。
// qiu_extra = 额外求签次数（当前唯一在售）；jieqian_unlock = 旧版付费解签（废弃，仅兜底历史订单）。
var ALLOWED_PRODUCT_IDS = ['qiu_extra', 'jieqian_unlock'];

// 客户端可控字段长度上限（伪造面缓解：防大对象滥用存储/拖垮查询）
var MAX_TOKEN_LEN = 256;    // purchaseToken
// purchaseData 上限实测受控制台字段容量限制（真实 Cloud DB 二分验证：
//   200 字符 PASS、255 字符 3007007 out of range）。华为 JWS（含 x5c 证书链）
//   2500+ 字符，控制台字段装不下完整 JWS —— 这里只截断存证，真正的校验键是
//   purchaseToken（已单独存储，v2 action=verify 走 token 调华为订单服务）。
var MAX_DATA_LEN = 200;     // purchaseData（截断存证，勿再调大）
var MAX_ORDER_LEN = 128;    // purchaseOrderId
var MAX_UNLOCK_DATE_LEN = 10; // unlockDate（YYYY-MM-DD）

async function handler(body, event, context, log) {
  var action = body.action;
  var uid = body.__uid;

  if (!uid) {
    // 诊断模式（规则要求）：requestKeys 空数组 = 客户端 data 内容为空/未传
    var reqObj = event && event.request && typeof event.request === 'object' ? event.request : null;
    var diag = {
      requestKeys: reqObj ? Object.keys(reqObj) : [],
      bodyKeys: body ? Object.keys(body) : []
    };
    log.error('[jieqian-unlock] UID NOT FOUND, diag: ' + JSON.stringify(diag));
    return fail(CODE.UNAUTHORIZED, 'uid required: ' + JSON.stringify(diag));
  }

  var db = getDB();

  try {
    switch (action) {
      case 'record': {
        // ---- 参数校验（类型 + 长度，客户端可控字段一律不信任）----
        var productId = body.productId;
        var purchaseToken = body.purchaseToken;
        var orderId = typeof body.orderId === 'string' ? body.orderId.slice(0, MAX_ORDER_LEN) : '';
        var purchaseData = typeof body.purchaseData === 'string' ? body.purchaseData.slice(0, MAX_DATA_LEN) : '';
        // 客户端本地日期（解锁生效日，YYYY-MM-DD）；权益按天失效，云端仅存证/兜底查询
        var unlockDate = typeof body.unlockDate === 'string' ? body.unlockDate.slice(0, MAX_UNLOCK_DATE_LEN) : '';
        if (ALLOWED_PRODUCT_IDS.indexOf(productId) < 0) {
          return fail(CODE.PARAM_ERROR, 'invalid productId: ' + productId);
        }
        if (typeof purchaseToken !== 'string' || !purchaseToken || purchaseToken.length > MAX_TOKEN_LEN) {
          return fail(CODE.PARAM_ERROR, 'invalid purchaseToken');
        }

        // ---- 幂等检查：同 purchaseToken 只记一条（重复上报/补记不双记）----
        // 依赖 SignUnlock 表 purchaseToken 索引（控制台手动建，见 Task 13）。
        var existing = await withTimeout(
          db.collection(UNLOCK_TYPE).query().equalTo('purchaseToken', purchaseToken).get(),
          DB_TIMEOUT_MS,
          'jieqian-unlock:idem-query'
        );
        // 幂等命中：返回 unlockDate（该 token 已记账），不代表调用者今日已解锁
        // （跨用户重放时调用者 query 仍拿不到该日期；客户端不消费此值，fire-and-forget）
        if (existing && existing.length > 0) {
          log.info('[jieqian-unlock] duplicate purchaseToken, skip uid=' + uid);
          var dup = toPlainObject(existing[0]);
          return success({ unlockDate: (dup && dup.unlockDate) || '' }, 'duplicate ignored');
        }

        // ---- 落解锁记录 ----
        var unlock = {
          id: orderId || ('u_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8)),
          uid: uid,
          productId: productId,
          purchaseToken: purchaseToken,
          purchaseData: purchaseData,
          unlockDate: unlockDate,
          createdAt: new Date().toISOString()
        };
        await withTimeout(
          db.collection(UNLOCK_TYPE).upsert(toGenericObjects(UNLOCK_TYPE, unlock)),
          DB_TIMEOUT_MS,
          'jieqian-unlock:unlock-upsert'
        );
        log.info('[jieqian-unlock] recorded id=' + unlock.id + ' productId=' + productId
          + ' unlockDate=' + (unlockDate || 'none') + ' uid=' + uid);
        return success({ unlockDate: unlockDate });
      }

      case 'query': {
        // 依赖 SignUnlock 表 uid 索引（控制台手动建，见 Task 13）
        var rows = await withTimeout(
          db.collection(UNLOCK_TYPE).query().equalTo('uid', uid).get(),
          DB_TIMEOUT_MS,
          'jieqian-unlock:query'
        );
        // 每日解锁：返回最近一次解锁日期（YYYY-MM-DD 字符串比较即日期比较），
        // 客户端按本地日期判断是否「今天」（跨天自愈，不依赖服务端时区）。
        var latest = '';
        if (rows && rows.length > 0) {
          for (var i = 0; i < rows.length; i++) {
            var row = toPlainObject(rows[i]);
            var d = (row && row.unlockDate) || '';
            if (d > latest) latest = d;
          }
        }
        return success({ unlockDate: latest });
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[jieqian-unlock] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
