// entry/src/main/ets/service/IPaymentService.ets
// 解签每日解锁支付服务接口（华为 IAP 消耗型商品）。
// 打赏历史：2026-09-27 曾以「供奉打赏」形态被判封建迷信拒审并移除；2026-10-03 以
// 「打赏作者 / 支持开发与维护 + 部分捐赠公益」重新上线（TIP_PRODUCTS 四档），
// 关键差别：UI 明确写成对开发者的支持，**不承诺任何祈福效果、不解锁任何权益**。
// 2026-10-04 审核整改：对外形态统一为「打赏作者 · 解锁更多乐趣」
//   · 解签全文、签运速览、今日建议 → 永久免费，App 内不再对「解签」本身收费；
//   · qiu_extra（¥1）消耗型，界面写成打赏作者（自愿赠与，与 DonateDialog 同套话术）；
//     打赏成功后后台发放当日额度 +1（每日最多 2 次，跨天归零）。
// 消耗型需在次数落账后 finishPurchase 消耗，否则下次购买被 1001860051 拦截；
// 崩溃在消耗前 → recoverPending 补单（queryPurchases UNFINISHED 拉已支付未消耗订单）。
// ⚠️ AGC 控制台必须存在消耗型商品 qiu_extra（¥1），否则 1001860007 商品未发布。

/** 额外求签次数商品（与 AGC 控制台消耗型商品 qiu_extra 唯一对应） */
export interface ExtraDrawProduct {
  productId: string      // AGC 商品 ID（qiu_extra，与服务端 jieqian-unlock 白名单一致）
  amount: number          // 本地展示金额（¥1，与 AGC 定价档一致）
  label: string           // 展示文案
}

/** 购买结果。success 时含云端记录所需全部字段 */
export interface ExtraDrawResult {
  success: boolean
  canceled: boolean       // 用户取消（1001860000），静默返回不弹错
  productId: string       // 白名单商品 ID（与云端 jieqian-unlock 白名单一致）
  purchaseToken: string   // 幂等去重键
  orderId: string          // purchaseOrderId，SignUnlock 主键
  purchaseData: string    // 华为签名原文（云端存证，未来 verify 用）
}

/** 打赏档位（消耗型；与 AGC 控制台消耗型商品一一对应） */
export interface TipProduct {
  productId: string      // AGC 商品 ID（tip_8 / tip_18_2 / tip_88_2 / tip_188 / tip_888）
  amount: number         // 本地展示金额（元，与 AGC 定价档一致）
  label: string          // 香名（文化标签）
}

/**
 * 打赏档位（2026-10-03 上线，2026-10-20 扩为五档）。三方一致：AGC 控制台消耗型商品 / 本表。
 * 打赏为纯自愿赠与，**不承诺任何效果**（这点必须在 UI 上讲清楚，也是过审的关键：
 * 打赏不能被理解为购买祈福效果）。消耗型，付款成功后必须 finishPurchase，
 * 否则同一档再买会被 1001860051 拦截。
 */
// label 后半段刻意不带「香/供奉/祈福」字样：打赏是对开发者的支持，不应被理解为购买仪式结果。
// 注：tip_188 对应殿内「聚宝盆」陈设（¥188），AGC 控制台须存在同名消耗型商品；
// 其余三档（8/18/88）复用原打赏档，购买即解锁对应陈设（见 HallViewModel.setWareOwned）。
export const TIP_PRODUCTS: TipProduct[] = [
  { productId: 'tip_8', amount: 8, label: '支持 · 心意' },
  { productId: 'tip_18_2', amount: 18, label: '祝愿 · 顺遂' },
  { productId: 'tip_88_2', amount: 88, label: '福田 · 同行' },
  { productId: 'tip_188', amount: 188, label: '殿设 · 聚宝' },
  { productId: 'tip_888', amount: 888, label: '至诚 · 厚爱' }
]

/** 打赏是否属于本表商品（recoverPending 用它做跨产品隔离） */
export function isTipProduct(productId: string): boolean {
  for (const p of TIP_PRODUCTS) {
    if (p.productId === productId) {
      return true
    }
  }
  return false
}

/** 支付前置错误（UI 按 kind 引导处理） */
export enum PaymentErrorKind {
  NEED_LOGIN = 'need_login',   // 1001860050 未登录华为帐号
  REGION = 'region',           // 1001860054 地区不支持
  PRODUCT = 'product',          // 1001860007 商品未发布
  ALREADY_OWNED = 'already_owned'  // 1001860051 同商品有未完成订单（上次购买成功未消耗），应补单恢复
}

export class PaymentError extends Error {
  readonly kind: PaymentErrorKind
  readonly rawCode: number
  constructor(kind: PaymentErrorKind, message: string, rawCode: number) {
    super(message)
    this.kind = kind
    this.rawCode = rawCode
  }
}

/** 额外求签次数商品静态配置（三方一致：AGC 控制台 / 云函数 jieqian-unlock 白名单 / 本表） */
export const EXTRA_DRAW_PRODUCT: ExtraDrawProduct = {
  productId: 'qiu_extra',
  amount: 1,
  label: '打赏作者 · 解锁更多乐趣'
}

export interface IExtraDrawService {
  /** 额外求签次数商品信息 */
  getProduct(): ExtraDrawProduct

  /**
   * 发起购买（拉起华为收银台，消耗型）。
   * 用户取消 → { success: false, canceled: true }；
   * 前置错误（未登录/地区/商品未发布/有未完成订单）→ 抛 PaymentError（UI 引导后处理）；
   * 其他错误 → 抛 Error（UI toast「购买失败请重试」）。
   */
  purchase(): Promise<ExtraDrawResult>

  /**
   * 补单恢复：queryPurchases(CONSUMABLE, UNFINISHED) 查已支付未消耗的额外次数订单。
   * 覆盖崩溃在消耗前 / 上次云端未记的场景。返回找到的首笔 qiu_extra 订单
   * （含 purchaseToken 供云端幂等补记）；无未完成订单/查询失败返回 null。
   */
  recoverPending(): Promise<ExtraDrawResult | null>

  /** 消耗商品（finishPurchase）——次数落账后调用，否则下次购买被 1001860051 拦截 */
  consume(result: ExtraDrawResult): Promise<void>
}

/**
 * 打赏支付服务（同属华为 IAP 消耗型）。
 * 与解锁商品的唯一区别：打赏**没有任何本地权益**，落账动作就是「感谢 + 消耗」，
 * 因此 consume 紧跟支付成功调用；崩溃在消耗前由 recoverTipPending 补齐（不重复感谢页面，
 * 只做消耗，避免再次购买被拦截）。
 */
export interface ITipService {
  /** 购买指定档位（拉起华为收银台）。取消 → canceled；前置错误 → PaymentError */
  purchaseTip(product: TipProduct): Promise<ExtraDrawResult>

  /** 补单：找出一笔「已支付未消耗」的打赏订单（只认 TIP_PRODUCTS，与额外次数商品隔离） */
  recoverTipPending(): Promise<ExtraDrawResult | null>
}
