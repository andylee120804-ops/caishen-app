// entry/src/main/ets/viewmodels/QiuQianViewModel.ets
// 求签记录 + 每日求签额度，preferences 本地持久化。
// 记录在「揭晓」时自动写入（保留最近 MAX_QIU_RECORDS 条），额度在「出签」时消费。
//
// 额度模型（2026-10-05 起：付费加次数已取消）：
//   · 每日固定 FREE_DAILY_QIU（3）签，用完提示「明日再来」，跨天自动恢复；
//   · 解签全文（解签 / 签运速览 / 今日建议）永久免费，页面无任何付费墙；
//   · 不再有「付费加次数 / 每日上限 5 签」的概念——每天就是 3 签。
//
// 【存储位置 2026-10-04】额度与签录存在专属文件 mashen_qiuqian_prefs：
// 旧位置 mashen_user_prefs 与常驻的 PrayerViewModel 共用，**不能** removePreferencesFromCache，
// 否则跨进程（桌面卡片跑在 caishen.blessing.huawei:form）永远读到本进程的陈旧快照。
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { SignEntry, QiuRecord, LEVEL_RANK } from '../model/CultureContent'

const PREF_NAME = 'mashen_qiuqian_prefs'
const KEY_RECORDS = 'qiuRecords'
const KEY_DAILY = 'qiuDaily'
export const FREE_DAILY_QIU = 3     // 每日求签次数（每天固定 3 签，用完明日再来）
const MAX_QIU_RECORDS = 100         // 本机保留记录上限
// form 进程 console.* 打不进 hilog，额度相关的一律用 hilog 才能抓到
const LOG_DOMAIN_QIU: number = 0xF811
const LOG_TAG_QIU: string = 'QiuQianVM'

/** 每日额度（按本地日期滚动） */
interface QiuDaily {
  date: string
  count: number
}

function dayStrOf(d: Date): string {
  const mm = `${d.getMonth() + 1}`.padStart(2, '0')
  const dd = `${d.getDate()}`.padStart(2, '0')
  return `${d.getFullYear()}-${mm}-${dd}`
}

function todayStr(): string {
  return dayStrOf(new Date())
}

@Observed
export class QiuQianViewModel {
  records: QiuRecord[] = []
  daily: QiuDaily = { date: '', count: 0 }
  private dataPrefs: preferences.Preferences | null = null
  /** 有写盘在飞（persistRecords 执行中）：reload() 见到它必须让位，避免覆盖未落盘的新签 */
  private persisting: boolean = false

  /**
   * 初始化 promise（EntryAbility 冷启动时登记）。
   * 页面拿到深链要判断「还能不能抽 / 该不该弹付款」时**必须**先 awaitInit()：
   * initialize() 是异步的，未就绪时 daily.count 是 0，会把「今日已抽完」误判成「还能抽」，
   * 结果付款弹窗不弹，用户只能自己再点一次（卡片跳进来那一步就白跳了）。
   */
  private static initPromise: Promise<void> = Promise.resolve()

  static markInit(p: Promise<void>): void {
    QiuQianViewModel.initPromise = p
  }

  static async awaitInit(): Promise<void> {
    try {
      await QiuQianViewModel.initPromise
    } catch (err) {
      console.error('[QiuQianVM] awaitInit failed:', JSON.stringify(err))
    }
  }

  async initialize(context: Context): Promise<void> {
    // 卡片扩展跑在独立进程（caishen.blessing.huawei:form），preferences 有进程内缓存：
    // 不清缓存就会读到本进程上次留下的旧值，写回后把 App 进程刚写入的额度/签录回滚掉。
    await QiuQianViewModel.dropCache(context)
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      const rawRec = await this.dataPrefs.get(KEY_RECORDS, '[]')
      this.records = JSON.parse(rawRec as string) as QiuRecord[]
      const rawDaily = await this.dataPrefs.get(KEY_DAILY, '')
      if (rawDaily !== '') {
        const disk = JSON.parse(rawDaily as string) as QiuDaily
        const t = todayStr()
        if (disk.date === t) {
          // 当日计数取内存/磁盘较大值：reload 不得把未落盘的本次抽签回退成 0
          const mem = this.daily.date === t ? this.daily.count : 0
          this.daily = { date: t, count: Math.max(mem, disk.count) }
        } else {
          // 跨天：以今日为准（内存若已是今日则保留，否则归零）
          if (this.daily.date !== t) {
            this.daily = { date: t, count: 0 }
          }
        }
      }
    } catch (err) {
      console.error('[QiuQianVM] load failed:', JSON.stringify(err))
      this.records = []
      this.daily = { date: '', count: 0 }
    }
    hilog.info(LOG_DOMAIN_QIU, LOG_TAG_QIU, `load daily: date=${this.daily.date} used=${this.daily.count}`)
  }

  /** 重读磁盘（卡片在 App 后台抽签/敲木鱼后，App 回前台必须调用，否则显示旧值）。
   *  未 initialize 过（dataPrefs 为空）时安全空转。 */
  async reload(context?: Context): Promise<void> {
    // 有写盘在飞（addRecord 已 unshift、persist 未完成时）不得覆盖内存，否则本次新签会被丢掉
    if (this.persisting) {
      return
    }
    if (context !== undefined && context !== null) {
      await QiuQianViewModel.dropCache(context)
      try {
        this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
      } catch (err) {
        console.error('[QiuQianVM] reopen prefs failed:', JSON.stringify(err))
      }
    }
    if (this.dataPrefs === null) {
      return
    }
    try {
      const rawRec = await this.dataPrefs.get(KEY_RECORDS, '[]')
      this.records = JSON.parse(rawRec as string) as QiuRecord[]
      const rawDaily = await this.dataPrefs.get(KEY_DAILY, '')
      if (rawDaily === '') {
        const t = todayStr()
        if (this.daily.date !== t) {
          this.daily = { date: t, count: 0 }
        }
      } else {
        const disk = JSON.parse(rawDaily as string) as QiuDaily
        const t = todayStr()
        if (disk.date === t) {
          const mem = this.daily.date === t ? this.daily.count : 0
          this.daily = { date: t, count: Math.max(mem, disk.count) }
        } else if (this.daily.date !== t) {
          this.daily = { date: t, count: 0 }
        }
      }
    } catch (err) {
      console.error('[QiuQianVM] reload failed:', JSON.stringify(err))
    }
  }

  /** 丢弃 preferences 进程内缓存（跨进程读到旧值的根因，失败不影响主流程） */
  private static async dropCache(context: Context): Promise<void> {
    try {
      await preferences.removePreferencesFromCache(context, PREF_NAME)
    } catch (err) {
      console.error('[QiuQianVM] drop cache failed:', JSON.stringify(err))
    }
  }

  /** 今日最吉签：等级最优（上上 > 上吉 > 中吉 > 中平 > 下），同级取最新；
   *  今日无记录返回 null（调用方回退到确定性每日签）。 */
  bestToday(): SignEntry | null {
    const t = todayStr()
    let best: QiuRecord | null = null
    for (const r of this.records) {
      if (dayStrOf(new Date(r.ts)) !== t) {
        continue
      }
      if (best === null) {
        best = r
        continue
      }
      const rank: number = LEVEL_RANK[r.sign.level]
      const bestRank: number = LEVEL_RANK[best.sign.level]
      if (rank < bestRank || (rank === bestRank && r.ts > best.ts)) {
        best = r
      }
    }
    return best === null ? null : best.sign
  }

  /** 今日最吉签是第几次抽到的（1-based；今日无记录返回 0）。
   *  比较口径与 bestToday() 一致，用于卡片标题「今天第 X 签」展示抽签次序（当日次数里的第几次）。 */
  bestDrawOrder(): number {
    const t: string = todayStr()
    const todayRecs: QiuRecord[] = this.records.filter((r: QiuRecord): boolean => dayStrOf(new Date(r.ts)) === t)
    if (todayRecs.length === 0) {
      return 0
    }
    let bestIdx: number = -1
    let bestRank: number = 999
    let bestTs: number = -1
    for (let i: number = 0; i < todayRecs.length; i++) {
      const r: QiuRecord = todayRecs[i]
      const rank: number = LEVEL_RANK[r.sign.level]
      if (rank < bestRank || (rank === bestRank && r.ts > bestTs)) {
        bestRank = rank
        bestTs = r.ts
        bestIdx = i
      }
    }
    // todayRecs 与 records 同序（最新在前），最新一条即第 todayRecs.length 次
    return todayRecs.length - bestIdx
  }

  /** 今日已用次数（跨天自动归零并落盘） */
  usedToday(): number {
    const t = todayStr()
    if (this.daily.date !== t) {
      this.daily = { date: t, count: 0 }
      this.persistDaily()
    }
    return this.daily.count
  }

  /** 今日可用额度：固定 FREE_DAILY_QIU（3）签，无付费加次数概念 */
  quotaToday(): number {
    return FREE_DAILY_QIU
  }

  /** 今日还可求几次 */
  remainingToday(): number {
    return Math.max(0, this.quotaToday() - this.usedToday())
  }

  canDraw(): boolean {
    return this.usedToday() < this.quotaToday()
  }

  /** 出签时消费一次今日额度（内存先行，落盘异步） */
  async consumeDraw(): Promise<void> {
    if (!this.canDraw()) {
      // form 进程 console.* 打不进 hilog，卡片「抽不动」只能靠这里定位
      hilog.warn(LOG_DOMAIN_QIU, LOG_TAG_QIU, `consumeDraw rejected: used=${this.usedToday()} quota=${this.quotaToday()}`)
      return
    }
    const t = todayStr()
    if (this.daily.date !== t) {
      this.daily = { date: t, count: 0 }
    }
    this.daily.count += 1
    await this.persistDaily()
  }

  /** 揭晓时自动记一条（最新在前，超上限截断） */
  async addRecord(sign: SignEntry): Promise<void> {
    const rec: QiuRecord = {
      recId: `${Date.now()}_${Math.floor(Math.random() * 100000)}`,
      ts: Date.now(),
      sign: sign
    }
    this.records.unshift(rec)
    if (this.records.length > MAX_QIU_RECORDS) {
      this.records = this.records.slice(0, MAX_QIU_RECORDS)
    }
    await this.persistRecords()
  }

  async deleteRecord(recId: string): Promise<void> {
    this.records = this.records.filter((r: QiuRecord): boolean => r.recId !== recId)
    await this.persistRecords()
  }

  async clearRecords(): Promise<void> {
    this.records = []
    await this.persistRecords()
  }

  private async persistRecords(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    // 置位期间 reload() 让位：addRecord 已 unshift 的新签不会被磁盘旧快照覆盖丢失
    this.persisting = true
    try {
      await this.dataPrefs.put(KEY_RECORDS, JSON.stringify(this.records))
      // 必须 flush 才落盘：进程被杀死时未 flush 的内存数据会丢失（历史记录消失）
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[QiuQianVM] save records failed:', JSON.stringify(err))
    } finally {
      this.persisting = false
    }
  }

  private async persistDaily(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_DAILY, JSON.stringify(this.daily))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[QiuQianVM] save daily failed:', JSON.stringify(err))
    }
  }
}
