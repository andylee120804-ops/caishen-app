// entry/src/main/ets/viewmodels/HallViewModel.ets
// 财神殿 ViewModel：管理「心意值」经济、长明灯、上香、殿内装扮解锁。
//
// 合规要点（与整体方案一致）：灯与香绝不售卖，付费只走殿内装扮（复用打赏档 tip_8/18_2/88_2/188/888），
// 不新建 AGC 商品；心意值靠每日行为获取、每日清零，屏幕上看不到「钱换香」的因果链。
import { preferences } from '@kit.ArkData'
import { DeityRotator } from '../engine/DeityRotator'
import { DeityInfo } from '../model/PrayerTypes'

const PREF_NAME = 'caishen_hall_prefs'
const KEY_STATE = 'hallState'
const HEART_CAP = 20        // 每日心意值上限
const LAMP_COST = 2         // 点一盏灯 −2
const INCENSE_COST = 3      // 上一炷香 −3
const TIERS: number[] = [8, 18, 88, 888]

/** 殿内装扮三组分档（殿内四件陈设的价位模型在 CaiShenHallPage.WARES：8/18/88/188） */

/** 单件装扮定义 */
export interface DecorOption {
  id: string
  name: string
  tier: number              // 0=默认免费, 8/18/88/888=打赏档
}
/** 装扮分组（灯样式 / 香炉 / 殿宇主题） */
export interface DecorGroup {
  key: string
  title: string
  opts: DecorOption[]
}

/** 殿内装扮分组（按展示顺序固定三组分） */
export interface HallDecorMap {
  lamp: DecorGroup
  burner: DecorGroup
  theme: DecorGroup
}

/** 殿内装扮静态定义（tier 与打赏档一一对应，越买越多） */
export const HALL_DECOR: HallDecorMap = {
  lamp: {
    key: 'lamp', title: '灯样式（打赏 ¥8 解锁）', opts: [
      { id: 'palace', name: '宫灯', tier: 0 },
      { id: 'lotus', name: '莲灯', tier: 8 },
      { id: 'glass', name: '琉璃灯', tier: 8 }
    ]
  },
  burner: {
    key: 'burner', title: '香炉（打赏 ¥18 解锁）', opts: [
      { id: 'bronze', name: '青铜炉', tier: 0 },
      { id: 'threeleg', name: '三足炉', tier: 18 },
      { id: 'gilt', name: '鎏金炉', tier: 18 }
    ]
  },
  theme: {
    key: 'theme', title: '殿宇主题（打赏 ¥88 解锁）', opts: [
      { id: 'vermilion', name: '朱红昼殿', tier: 0 },
      { id: 'gold', name: '金辉殿', tier: 88 },
      { id: 'night', name: '夜殿', tier: 88 },
      { id: 'crystal', name: '水晶殿（尊享）', tier: 888 }
    ]
  }
}

/** 装扮分组遍历顺序（直接持有分组对象，避免 ArkTS 禁用的字段索引访问） */
export const HALL_DECOR_ORDER: DecorGroup[] = [HALL_DECOR.lamp, HALL_DECOR.burner, HALL_DECOR.theme]

interface HallPersist {
  lastDate: string
  lastLampDate: string
  todayHeart: number
  heart: number
  lampLit: boolean
  lampStreak: number
  checkedIn: boolean
  sticksToday: number
  sticksTotal: number
  focusSecToday: number
  focusSecTotal: number
  unlocked: Record<string, boolean>
  activeLamp: string
  activeBurner: string
  activeTheme: string
  wareOwned: Record<string, boolean>
  wareLit: Record<string, boolean>
}

/** 本地日期 YYYY-MM-DD（跨天比对基准） */
function todayStr(d: Date): string {
  const m = (d.getMonth() + 1).toString().padStart(2, '0')
  const day = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}

@Observed
export class HallViewModel {
  heart: number = 0
  todayHeart: number = 0
  lampLit: boolean = false
  lampStreak: number = 0
  checkedIn: boolean = false
  sticksToday: number = 0
  sticksTotal: number = 0
  focusSecToday: number = 0
  focusSecTotal: number = 0
  unlocked: Record<string, boolean> = {}
  activeLamp: string = 'palace'
  activeBurner: string = 'bronze'
  activeTheme: string = 'vermilion'
  /** 殿内四件陈设：是否已购买（owned）/ 是否点亮常驻（lit） */
  wareOwned: Record<string, boolean> = {}
  wareLit: Record<string, boolean> = {}
  /** 四件陈设 key 顺序：宫灯→金瓶→鲜花→聚宝盆（按价格升序，殿内由左至右） */
  wareOrder: string[] = ['lamp', 'vase', 'fresh', 'basin']
  /** 今日主财神（每日轮换，跨天自动换） */
  todayDeity: DeityInfo = DeityRotator.getTodayDeity()

  private lastDate: string = ''
  private lastLampDate: string = ''
  private dataPrefs: preferences.Preferences | null = null
  private todayDeityDate: string = ''
  private rev: number = 0

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    await this.load()
    this.checkDaily()
    this.refreshTodayDeity()
    this.persist()
  }

  /** App 回前台 / 进殿时调用：跨天则重置并补发每日进殿奖励 */
  checkDaily(): void {
    const s = todayStr(new Date())
    if (this.lastDate !== s) {
      this.lastDate = s
      // 跨天未点灯 → 连续点亮中断归零
      if (this.lastLampDate !== this.yesterdayStr()) {
        this.lampStreak = 0
      }
      this.todayHeart = 0
      this.heart = 0
      this.lampLit = false
      this.checkedIn = false
      this.sticksToday = 0
      this.focusSecToday = 0
      this.addHeart(5) // 每日首进殿 +5
    }
  }

  private yesterdayStr(): string {
    const d = new Date()
    d.setDate(d.getDate() - 1)
    return todayStr(d)
  }

  /** 跨天才重算今日主财神；当天内 no-op */
  refreshTodayDeity(): void {
    const s = todayStr(new Date())
    if (s !== this.todayDeityDate) {
      this.todayDeityDate = s
      this.todayDeity = DeityRotator.getTodayDeity()
    }
  }

  // ── 心意值 ──
  private addHeart(n: number): void {
    const room = HEART_CAP - this.todayHeart
    const add = Math.min(n, Math.max(0, room))
    if (add <= 0) {
      return
    }
    this.todayHeart += add
    this.heart += add
    this.notify()
  }

  /** 每日签到 +3（每账号每日一次），返回是否首次签到 */
  checkIn(): boolean {
    if (this.checkedIn) {
      return false
    }
    this.checkedIn = true
    this.addHeart(3)
    this.persist()
    return true
  }

  private spend(n: number): boolean {
    if (this.heart < n) {
      return false
    }
    this.heart -= n
    this.notify()
    return true
  }

  // ── 长明灯 ──
  /** 点长明灯：扣 2 心意值；返回 'ok' / 'already' / 'noheart' */
  lightLamp(): string {
    if (this.lampLit) {
      return 'already'
    }
    if (!this.spend(LAMP_COST)) {
      return 'noheart'
    }
    const t = todayStr(new Date())
    if (this.lastLampDate === t) {
      // 同日重复点（正常情况下不会发生）
    } else if (this.lastLampDate === this.yesterdayStr()) {
      this.lampStreak += 1
    } else {
      this.lampStreak = 1
    }
    this.lastLampDate = t
    this.lampLit = true
    this.persist()
    return 'ok'
  }

  // ── 上香 ──
  /** 开始上香：校验并扣除 3 心意值；成功返回 true */
  beginIncense(): boolean {
    if (this.heart < INCENSE_COST) {
      return false
    }
    this.spend(INCENSE_COST)
    this.persist()
    return true
  }

  /** 上香完成：记 +2 心意值、支数 +1 */
  completeIncense(): void {
    this.sticksToday += 1
    this.sticksTotal += 1
    this.addHeart(2)
    this.persist()
  }

  // ── 装扮 ──
  isUnlocked(tier: number): boolean {
    return tier <= 0 || this.unlocked[tier.toString()] === true
  }

  isActive(group: string, id: string): boolean {
    if (group === 'lamp') return this.activeLamp === id
    if (group === 'burner') return this.activeBurner === id
    if (group === 'theme') return this.activeTheme === id
    return false
  }

  /** 打赏解锁某档：解锁该档及更低档对应装扮（越买越多，¥888 解锁全部尊享） */
  unlockTier(tier: number): void {
    let changed = false
    for (const t of TIERS) {
      if (t <= tier && !this.unlocked[t.toString()]) {
        this.unlocked[t.toString()] = true
        changed = true
      }
    }
    if (changed) {
      // 重建引用以触发 @Observed 观察（ArkTS 不支持对象展开 {...}）
      const next: Record<string, boolean> = {}
      for (const t of TIERS) {
        next[t.toString()] = this.unlocked[t.toString()] === true
      }
      this.unlocked = next
      this.persist()
      this.notify()
    }
  }

  useDecor(group: string, id: string): void {
    if (group === 'lamp') this.activeLamp = id
    else if (group === 'burner') this.activeBurner = id
    else if (group === 'theme') this.activeTheme = id
    this.persist()
    this.notify()
  }

  // ── 殿内四件陈设 ──
  isWareOwned(item: string): boolean {
    return this.wareOwned[item] === true
  }

  isWareLit(item: string): boolean {
    return this.wareLit[item] === true
  }

  /** 购买/解锁某件陈设（复用打赏档位，购买即拥有） */
  setWareOwned(item: string, v: boolean): void {
    const next: Record<string, boolean> = {}
    for (const k of this.wareOrder) {
      next[k] = (k === item) ? v : (this.wareOwned[k] === true)
    }
    this.wareOwned = next
    this.persist()
    this.notify()
  }

  /** 切换点亮常驻辉光（仅已拥有者可点亮） */
  toggleWareLit(item: string): void {
    if (!this.isWareOwned(item)) {
      return
    }
    const next: Record<string, boolean> = {}
    for (const k of this.wareOrder) {
      next[k] = (k === item) ? !this.wareLit[k] : (this.wareLit[k] === true)
    }
    this.wareLit = next
    this.persist()
    this.notify()
  }

  /** 当前主题对应的殿宇背景渐变（朱红昼殿 / 金辉 / 夜殿 / 水晶殿） */
  themeColors(): [string, string, string] {
    switch (this.activeTheme) {
      case 'gold': return ['#B8860B', '#8A5A00', '#3A2400'] as [string, string, string]
      case 'night': return ['#1B2A4A', '#101A30', '#070B16'] as [string, string, string]
      case 'crystal': return ['#3A4A6B', '#232F4D', '#0E1424'] as [string, string, string]
      default: return ['#880E1F', '#720F18', '#4B0C12'] as [string, string, string] // vermilion 朱红昼殿
    }
  }

  // ── 持久化 ──
  private async load(): Promise<void> {
    if (this.dataPrefs === null) {
      return
    }
    try {
      const str = await this.dataPrefs.get(KEY_STATE, '') as string
      if (str === '') {
        return
      }
      const s = JSON.parse(str) as HallPersist
      this.lastDate = s.lastDate ?? ''
      this.lastLampDate = s.lastLampDate ?? ''
      this.todayHeart = s.todayHeart ?? 0
      this.heart = s.heart ?? 0
      this.lampLit = s.lampLit ?? false
      this.lampStreak = s.lampStreak ?? 0
      this.checkedIn = s.checkedIn ?? false
      this.sticksToday = s.sticksToday ?? 0
      this.sticksTotal = s.sticksTotal ?? 0
      this.focusSecToday = s.focusSecToday ?? 0
      this.focusSecTotal = s.focusSecTotal ?? 0
      this.unlocked = s.unlocked ?? {}
      this.activeLamp = s.activeLamp ?? 'palace'
      this.activeBurner = s.activeBurner ?? 'bronze'
      this.activeTheme = s.activeTheme ?? 'vermilion'
      const wo = s.wareOwned ?? {}
      const wl = s.wareLit ?? {}
      const nextOwned: Record<string, boolean> = {}
      const nextLit: Record<string, boolean> = {}
      for (const k of this.wareOrder) {
        nextOwned[k] = wo[k] === true
        nextLit[k] = wl[k] === true
      }
      this.wareOwned = nextOwned
      this.wareLit = nextLit
    } catch (err) {
      console.error('[HallVM] load failed:', JSON.stringify(err))
    }
  }

  private async persist(): Promise<void> {
    if (this.dataPrefs === null) {
      return
    }
    const s: HallPersist = {
      lastDate: this.lastDate,
      lastLampDate: this.lastLampDate,
      todayHeart: this.todayHeart,
      heart: this.heart,
      lampLit: this.lampLit,
      lampStreak: this.lampStreak,
      checkedIn: this.checkedIn,
      sticksToday: this.sticksToday,
      sticksTotal: this.sticksTotal,
      focusSecToday: this.focusSecToday,
      focusSecTotal: this.focusSecTotal,
      unlocked: this.unlocked,
      activeLamp: this.activeLamp,
      activeBurner: this.activeBurner,
      activeTheme: this.activeTheme,
      wareOwned: this.wareOwned,
      wareLit: this.wareLit
    }
    try {
      await this.dataPrefs.put(KEY_STATE, JSON.stringify(s))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[HallVM] persist failed:', JSON.stringify(err))
    }
  }

  /** 嵌套变更通知：bump AppStorage hallRev（UI 以 @Watch 重建派生） */
  private notify(): void {
    this.rev += 1
    try {
      const cur = AppStorage.get<number>('hallRev') ?? 0
      AppStorage.setOrCreate('hallRev', cur + 1)
    } catch (err) {
      console.error('[HallVM] notify failed:', JSON.stringify(err))
    }
  }
}
