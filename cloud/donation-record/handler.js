// cloud/donation-record/handler.js
// 打赏（支持作者）云记账 + 公益排行榜：
//   action=record —— 上报打赏流水，幂等（同 purchaseToken 只记一次）+ 从流水重算累计
//   action=query  —— 拉取我的累计 { totalAmount, totalCount }
//   action=board  —— 公益排行榜：按累计打赏金额排名的公开榜单（昵称脱敏）+ 全站汇总
// 客户端 data: { action, __uid, productId?, purchaseToken?, purchaseData?, orderId? }
// 时序契约（设计文档第 5 节）：记账在消耗之前——客户端上报成功后才 finishPurchase；
//   上报失败订单保持未完成，下次启动 queryPurchases 补单（幂等保证不双记）。
// 金额以服务端商品白名单为准，客户端传的 amount 一律忽略（防篡改：productId 决定价格）。
// ⚠️ v1 已知取舍（设计文档第 10 节）：不做服务端票据校验——purchaseToken 不与华为核实，
//   客户端可控。榜单是「公开展示」而非权益发放（打赏不解锁任何东西），可接受；
//   一旦用于任何 entitle 判定，必须先补 action=verify（purchaseData 已存证，接口留位）。
const { wrapHttp, success, fail, CODE } = require('./shared/response');
const { getDB, toGenericObjects, toPlainObject, withTimeout, DB_TIMEOUT_MS } = require('./shared/db');

var DONATION_TYPE = 'Donation';
var MERIT_TYPE = 'UserMerit';

// 商品白名单：productId -> 金额。必须与 AGC 控制台「应用内购买服务」配置一致，
// 并与客户端 entry/src/main/ets/service/IPaymentService.ets 的 TIP_PRODUCTS 三方一致。
// ⚠️ 控制台改价/新增档位时需同步更新此处（v2 的 action=verify 可改为服务端拉取商品列表）。
var PRODUCT_IDS = {
  tip_8: 8,
  tip_18_2: 18,
  tip_88_2: 88,
  tip_188: 188,
  tip_888: 888
};

// 客户端可控字段长度上限（伪造面缓解：防大对象滥用存储/拖垮查询）
var MAX_TOKEN_LEN = 256;    // purchaseToken
// ⚠️ purchaseData 上限实测受控制台字段容量限制（真实 Cloud DB 二分验证：
//    200 字符 PASS、255 字符 3007007 out of range）。华为 JWS（含 x5c 证书链）
//    2500+ 字符，控制台字段装不下完整 JWS —— 这里只截断存证，真正的校验键是
//    purchaseToken（已单独存储，v2 action=verify 走 token 调华为订单服务）。
var MAX_DATA_LEN = 200;     // purchaseData（截断存证，勿再调大——控制台字段就这容量）
var MAX_ORDER_LEN = 128;    // purchaseOrderId

/** 查累计功德缓存（query 快路径读 UserMerit 表）。无记录返回 { 0, 0 } */
async function getMyMerit(db, uid) {
  var rows = await withTimeout(
    db.collection(MERIT_TYPE).query().equalTo('uid', uid).get(),
    DB_TIMEOUT_MS,
    'donation-record:merit-query'
  );
  var obj = rows && rows.length > 0 ? toPlainObject(rows[0]) : null;
  return {
    totalAmount: obj ? (Number(obj.totalAmount) || 0) : 0,
    totalCount: obj ? (Number(obj.totalCount) || 0) : 0
  };
}

/**
 * 从 Donation 流水重算累计功德并写回 UserMerit。
 * 为什么不 read-modify-write：merit 累加若在上次执行中断裂（donation 已落、
 * merit 写失败/超时），重试会被幂等挡住永远少计。改为从流水 SUM/COUNT 推导后，
 * 无论中断在哪一步，重试（含幂等命中路径）都重算到正确值——自愈，
 * 且天然无并发双计。代价：每次 record 多一次按 uid 索引的流水扫描
 * （供奉频次低、单用户流水少，可接受；query 走 UserMerit 缓存不受影响）。
 */
async function recomputeMerit(db, uid, log) {
  var rows = await withTimeout(
    db.collection(DONATION_TYPE).query().equalTo('uid', uid).get(),
    DB_TIMEOUT_MS,
    'donation-record:merit-scan'
  );
  var totalAmount = 0;
  var totalCount = 0;
  for (var i = 0; i < (rows ? rows.length : 0); i++) {
    var obj = toPlainObject(rows[i]);
    totalAmount += Number(obj.amount) || 0;
    totalCount++;
  }
  // Double 累计浮点漂移归一（0.1+0.2 != 0.3），保留 2 位
  totalAmount = Math.round(totalAmount * 100) / 100;
  var meritData = {
    uid: uid,
    totalAmount: totalAmount,
    totalCount: totalCount,
    updatedAt: new Date().toISOString()
  };
  await withTimeout(
    db.collection(MERIT_TYPE).upsert(toGenericObjects(MERIT_TYPE, meritData)),
    DB_TIMEOUT_MS,
    'donation-record:merit-upsert'
  );
  return { totalAmount: meritData.totalAmount, totalCount: meritData.totalCount };
}

var BOARD_LIMIT = 50;        // 榜单展示条数（与祈福榜一致）
var MERIT_SCAN_LIMIT = 2000; // UserMerit 扫描上限（防护性上限，避免全表爆炸）

/** uid -> 对外展示昵称（脱敏：只留尾号，绝不把设备 ID 直接暴露给别人） */
function maskName(uid) {
  var tail = String(uid || '').replace(/[^a-zA-Z0-9]/g, '').slice(-4);
  return tail ? ('好友 ' + tail) : '好友';
}

/**
 * 公益排行榜：按累计打赏金额降序。返回 { entries, summary }。
 * entries 的 rank>0 为上榜名次；自己不在前 BOARD_LIMIT 时追加一条 rank=0
 * （与祈福榜同一约定：客户端据此拆分「榜单」与「我的位置」）。
 * ⚠️ 隐私红线（2026-10-20）：榜单是公开接口，绝不返回原始设备 ID（uid），
 *    否则会被伪造 __uid 交叉读取他人私有数据。改为服务端算 isMe。
 */
async function getDonationBoard(db, uid, log) {
  var rows = await withTimeout(
    db.collection(MERIT_TYPE).query().limit(MERIT_SCAN_LIMIT).get(),
    DB_TIMEOUT_MS,
    'donation-record:board-scan'
  );
  var all = [];
  var totalAmount = 0;
  for (var i = 0; i < (rows ? rows.length : 0); i++) {
    var obj = toPlainObject(rows[i]);
    var amt = Math.round((Number(obj.totalAmount) || 0) * 100) / 100;
    if (amt <= 0) {
      continue; // 没打赏过的不进榜
    }
    all.push({
      isMe: obj.uid === uid,
      nickname: maskName(obj.uid),
      amount: amt,
      count: Number(obj.totalCount) || 0
    });
    // Double 累加漂移归一
    totalAmount = Math.round((totalAmount + amt) * 100) / 100;
  }
  all.sort(function (a, b) {
    return (b.amount - a.amount) || (b.count - a.count);
  });

  var entries = all.slice(0, BOARD_LIMIT).map(function (item, index) {
    return {
      isMe: item.isMe,
      nickname: item.nickname,
      amount: item.amount,
      count: item.count,
      rank: index + 1
    };
  });

  var inList = false;
  for (var j = 0; j < entries.length; j++) {
    if (entries[j].isMe) {
      inList = true;
      break;
    }
  }
  if (uid && !inList) {
    for (var k = 0; k < all.length; k++) {
      if (all[k].isMe) {
        entries.push({
          isMe: all[k].isMe,
          nickname: all[k].nickname,
          amount: all[k].amount,
          count: all[k].count,
          rank: 0
        });
        break;
      }
    }
  }
  log.info('[donation-record] board entries=' + entries.length + ' donors=' + all.length + ' total=' + totalAmount);
  return {
    entries: entries,
    summary: { donorCount: all.length, totalAmount: totalAmount }
  };
}

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
    log.error('[donation-record] UID NOT FOUND, diag: ' + JSON.stringify(diag));
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
        if (typeof productId !== 'string' || !PRODUCT_IDS.hasOwnProperty(productId)) {
          return fail(CODE.PARAM_ERROR, 'invalid productId: ' + productId);
        }
        if (typeof purchaseToken !== 'string' || !purchaseToken || purchaseToken.length > MAX_TOKEN_LEN) {
          return fail(CODE.PARAM_ERROR, 'invalid purchaseToken');
        }

        // ---- 幂等检查：同 purchaseToken 只记一次（补单/重试不双记）----
        // 依赖 Donation 表 purchaseToken 索引（schema 已建），未建索引查询会报错。
        // 同 token 换 __uid 重放不增益：流水不重复落，merit 重算的是新 uid 自己的。
        var existing = await withTimeout(
          db.collection(DONATION_TYPE).query().equalTo('purchaseToken', purchaseToken).get(),
          DB_TIMEOUT_MS,
          'donation-record:idem-query'
        );
        if (existing && existing.length > 0) {
          var existed = toPlainObject(existing[0]);
          log.info('[donation-record] duplicate purchaseToken, skip uid=' + uid + ' id=' + existed.id);
          // 幂等命中也重算 merit：若上次 donation 已落但 merit 写失败，此处自愈
          return success(await recomputeMerit(db, uid, log), 'duplicate ignored');
        }

        // ---- 落流水（amount 以服务端白名单为准，防客户端篡改）----
        var amount = PRODUCT_IDS[productId];
        var donation = {
          id: orderId || ('d_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8)),
          uid: uid,
          productId: productId,
          amount: amount,
          purchaseToken: purchaseToken,
          purchaseData: purchaseData,
          status: 'done',
          createdAt: new Date().toISOString()
        };
        await withTimeout(
          db.collection(DONATION_TYPE).upsert(toGenericObjects(DONATION_TYPE, donation)),
          DB_TIMEOUT_MS,
          'donation-record:donation-upsert'
        );
        log.info('[donation-record] recorded id=' + donation.id + ' productId=' + productId + ' amount=' + amount);

        // ---- 重算累计功德（从流水推导，中断重试自愈）----
        var merit = await recomputeMerit(db, uid, log);
        log.info('[donation-record] merit uid=' + uid + ' totalAmount=' + merit.totalAmount + ' totalCount=' + merit.totalCount);
        return success(merit);
      }

      case 'query': {
        return success(await getMyMerit(db, uid));
      }

      case 'board': {
        // ---- 公益排行榜：按累计打赏金额排名，昵称脱敏后公开展示 ----
        // 为什么不 orderByDesc('totalAmount')：UserMerit 表 schema 的 indexes 为空
        // （见 agc-clouddb-object-types-donation.json），未索引字段做排序式查询会报错。
        // 打赏用户规模远小于祈福用户，这里全量取 + 内存排序；到量级瓶颈再加索引改排序下推。
        return success(await getDonationBoard(db, uid, log));
      }

      default:
        return fail(CODE.PARAM_ERROR, 'unknown action: ' + action);
    }
  } catch (err) {
    log.error('[donation-record] DB error: ' + (err && err.message));
    return fail(CODE.SERVER_ERROR, 'db error: ' + (err && err.message));
  }
}

module.exports.myHandler = wrapHttp(handler);
