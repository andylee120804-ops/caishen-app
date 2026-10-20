// entry/src/main/ets/model/EnrichTypes.ets

/** 签到状态 */
export interface CheckinState {
  lastDate: string       // 上次签到日期 YYYY-MM-DD
  streak: number         // 连续签到天数 (1-7)
  totalIncense: number   // 累计香火值
}

/** 单笔收支结果 */
export interface GameResult {
  result: '+' | '-' | '·'  // + 赢 - 输 · 平
  magnitude: number         // 幅度 1-99
}

/** 某天的财运记录 */
export interface GameRecord {
  date: string           // YYYY-MM-DD
  deityId: number        // 当天拜的财神
  kowtowCount: number    // 当天磕头次数
  games: GameResult[]    // 收支结果
  note: string           // 备注
}

/** 排行榜条目 */
export interface LeaderboardEntry {
  isMe: boolean        // 服务端按 __uid 判定的「是不是我」——公开接口不返回原始设备 ID
  nickname: string
  count: number
  kowtow: number
  rank: number
}

/** 心愿 */
export interface Wish {
  id: string
  userId: string
  nickname: string
  content: string
  deityId: number
  fulfilled: boolean
  createdAt: string
  fulfilledAt: string
}

/** 额外求签次数购买上报参数（IAP 支付成功后传给 CloudService.recordSignUnlock；
 *  unlockDate 由 CloudService 按本地日期补入） */
export interface SignUnlockParams {
  productId: string       // AGC 商品 ID（qiu_extra，与服务端白名单一致）
  purchaseToken: string   // 幂等去重键
  purchaseData: string     // 华为签名原文存证
  orderId: string          // purchaseOrderId，SignUnlock 主键
}

/** 打赏上报参数（IAP 支付成功后传给 CloudService.recordDonation；
 *  amount 一律由服务端按商品白名单算，客户端不传，防篡改） */
export interface DonationRecordParams {
  productId: string       // AGC 商品 ID（tip_8 / tip_18_2 / tip_88_2 / tip_188 / tip_888）
  purchaseToken: string   // 幂等去重键
  purchaseData: string    // 华为签名原文存证
  orderId: string         // purchaseOrderId，Donation 主键
}

/** 公益排行榜条目（服务端已做昵称脱敏，昵称形如「好友 3f2a」） */
export interface DonationEntry {
  isMe: boolean           // 服务端按 __uid 判定的「是不是我」——公开接口不返回原始设备 ID
  nickname: string        // 脱敏昵称
  amount: number          // 累计打赏金额（元）
  count: number           // 打赏笔数
  rank: number            // >0 为上榜名次；0 表示未进前 50（专属「我的位置」）
}

/** 公益排行榜全站汇总（非打赏流水数学公式，仅展示） */
export interface DonationSummary {
  donorCount: number      // 打赏过的人数
  totalAmount: number     // 全站累计打赏金额（元）
}

/** 公益排行榜数据（云函数 donation-record action=board 返回体） */
export interface DonationBoard {
  entries: DonationEntry[]
  summary: DonationSummary
}

/** 排行榜类型 */
export enum LeaderboardType {
  DAILY = 'daily',
  WEEKLY = 'weekly',
  TOTAL = 'total'
}

/** 黄历数据 */
export interface AlmanacData {
  direction: string       // 吉位
  luckySuit: string       // 旺财吉物（元宝/铜钱/聚宝盆）
  avoid: string           // 忌
  suitable: string        // 宜
  incenseCount: number    // 今日香火人数
}

/** 黄历静态条目（不含每日变化的香火人数） */
export interface AlmanacEntry {
  direction: string       // 吉位
  luckySuit: string       // 旺财吉物（元宝/铜钱/聚宝盆）
  avoid: string           // 忌
  suitable: string        // 宜
}

/** 黄历 30 天轮换表 */
export const ALMANAC_TABLE: AlmanacEntry[] = [
  { direction: '坐东朝西', luckySuit: '💰 元宝', avoid: '心浮气躁', suitable: '稳扎稳打' },
  { direction: '坐南朝北', luckySuit: '🪙 铜钱', avoid: '贪心冒进', suitable: '见好就收' },
  { direction: '坐西朝东', luckySuit: '🧧 聚宝盆', avoid: '犹豫不决', suitable: '当机立断' },
  { direction: '坐北朝南', luckySuit: '💰 元宝', avoid: '急功近利', suitable: '耐心等待' },
  { direction: '坐东朝西', luckySuit: '🪙 铜钱', avoid: '目中无人', suitable: '低调行事' },
  { direction: '坐南朝北', luckySuit: '🧧 聚宝盆', avoid: '贪心不足', suitable: '适可而止' },
  { direction: '坐西朝东', luckySuit: '💰 元宝', avoid: '心猿意马', suitable: '专注一事' },
  { direction: '坐北朝南', luckySuit: '🪙 铜钱', avoid: '怨天尤人', suitable: '自省吾身' },
  { direction: '坐东朝西', luckySuit: '🧧 聚宝盆', avoid: '得意忘形', suitable: '戒骄戒躁' },
  { direction: '坐南朝北', luckySuit: '💰 元宝', avoid: '急于求成', suitable: '步步为营' },
  { direction: '坐西朝东', luckySuit: '🪙 铜钱', avoid: '刚愎自用', suitable: '广纳良言' },
  { direction: '坐北朝南', luckySuit: '🧧 聚宝盆', avoid: '患得患失', suitable: '放平心态' },
  { direction: '坐东朝西', luckySuit: '💰 元宝', avoid: '贪多嚼不烂', suitable: '集中精力' },
  { direction: '坐南朝北', luckySuit: '🪙 铜钱', avoid: '贸然进攻', suitable: '以守为攻' },
  { direction: '坐西朝东', luckySuit: '🧧 聚宝盆', avoid: '轻敌冒进', suitable: '重视对手' },
  { direction: '坐北朝南', luckySuit: '💰 元宝', avoid: '情绪上头', suitable: '冷静克制' },
  { direction: '坐东朝西', luckySuit: '🪙 铜钱', avoid: '瞻前顾后', suitable: '果断出击' },
  { direction: '坐南朝北', luckySuit: '🧧 聚宝盆', avoid: '好高骛远', suitable: '脚踏实地' },
  { direction: '坐西朝东', luckySuit: '💰 元宝', avoid: '自乱阵脚', suitable: '沉着冷静' },
  { direction: '坐北朝南', luckySuit: '🪙 铜钱', avoid: '畏首畏尾', suitable: '大胆出手' },
  { direction: '坐东朝西', luckySuit: '🧧 聚宝盆', avoid: '心浮气躁', suitable: '平心静气' },
  { direction: '坐南朝北', luckySuit: '💰 元宝', avoid: '贪大求全', suitable: '小胜即安' },
  { direction: '坐西朝东', luckySuit: '🪙 铜钱', avoid: '急功近利', suitable: '厚积薄发' },
  { direction: '坐北朝南', luckySuit: '🧧 聚宝盆', avoid: '一意孤行', suitable: '听取建议' },
  { direction: '坐东朝西', luckySuit: '💰 元宝', avoid: '半途而废', suitable: '坚持到底' },
  { direction: '坐南朝北', luckySuit: '🪙 铜钱', avoid: '患得患失', suitable: '笑看得失' },
  { direction: '坐西朝东', luckySuit: '🧧 聚宝盆', avoid: '心不在焉', suitable: '全神贯注' },
  { direction: '坐北朝南', luckySuit: '💰 元宝', avoid: '怨天尤人', suitable: '顺其自然' },
  { direction: '坐东朝西', luckySuit: '🪙 铜钱', avoid: '意气用事', suitable: '理智判断' },
  { direction: '坐南朝北', luckySuit: '🧧 聚宝盆', avoid: '骄傲自满', suitable: '虚心进取' }
]

/** 签到吉物序列（连续 7 天：一炷香 → 铜钱 → 钱袋 → 红包 → 灯笼 → 礼花 → 财神冠） */
export const CHECKIN_GLYPHS: string[] = ['🕯️', '🪙', '💰', '🧧', '🏮', '🎊', '👑']