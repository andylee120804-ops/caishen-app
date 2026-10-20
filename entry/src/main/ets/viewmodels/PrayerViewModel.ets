// entry/src/main/ets/viewmodels/PrayerViewModel.ets
import { PrayerRecord, PrayerPhase, UserPrefs, DeityInfo } from '../model/PrayerTypes'
import { DeityRotator } from '../engine/DeityRotator'
import { BlessingEngine } from '../engine/BlessingEngine'
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { EnrichViewModel } from './EnrichViewModel'
import { CloudService } from '../service/CloudService'

const PREF_NAME = 'mashen_user_prefs'
const HISTORY_KEY = 'prayer_history'
const RECENT_NAMES_KEY = 'recentNames'
const TOTAL_PRAYERS_KEY = 'totalPrayers'
const PRIVACY_KEY = 'privacy_accepted'
const MAX_HISTORY = 100
const MAX_RECENT_NAMES = 5

/** 本地日期 YYYY-MM-DD（跨天比对基准） */
function dateStrOf(d: Date): string {
  const m: string = (d.getMonth() + 1).toString().padStart(2, '0')
  const day: string = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}

@Observed
export class PrayerViewModel {
  currentPhase: PrayerPhase = PrayerPhase.IDLE
  userName: string = ''
  todayDeity: DeityInfo = DeityRotator.getTodayDeity()
  /** 本次祈福用户手动选择的财神（NameCard 选神；null = 未选，回退日期轮转主神） */
  selectedDeity: DeityInfo | null = null
  blessing: string = ''
  kowtowCount: number = 0
  recentNames: string[] = []
  totalPrayers: number = 0
  history: PrayerRecord[] = []
  private blessingEngine: BlessingEngine | null = null
  private dataPrefs: preferences.Preferences | null = null
  private todayDeityDate: string = ''

  /**
   * 跨天才重算今日主财神；同一天内 no-op，保证「当天的主神不变」。
   * 顶部主神牌 / 五神阵 / 祝福卡共用 todayDeity（@Observed 属性，赋值即通知 UI）。
   */
  refreshTodayDeity(): void {
    const dateStr = dateStrOf(new Date())
    if (dateStr !== this.todayDeityDate) {
      this.todayDeityDate = dateStr
      this.todayDeity = DeityRotator.getTodayDeity()
    }
  }

  /** 本次祈福实际敬拜的财神：用户选择优先，否则当日主财神 */
  activeDeity(): DeityInfo {
    return this.selectedDeity ?? this.todayDeity
  }

  /** NameCard 选神写入：仅影响本次祈福流程，不改「今日主财神」 */
  selectDeity(deity: DeityInfo | null): void {
    this.selectedDeity = deity
  }

  constructor() {
    this.refreshTodayDeity()
  }

  async initialize(context: Context): Promise<void> {
    this.blessingEngine = new BlessingEngine()
    await this.blessingEngine.loadBlessings(context)
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    await this.loadPrefs()
  }

  startPrayer(): void {
    this.currentPhase = PrayerPhase.INPUT_NAME
    this.selectedDeity = null
    this.refreshTodayDeity()
  }

  confirmName(name: string): void {
    this.userName = name
    this.saveRecentName(name)
    // 写入 AppStorage 供 CloudService 生成脱敏昵称（首字 + ***）
    AppStorage.setOrCreate('lastPrayerName', name)
    this.currentPhase = PrayerPhase.ANIMATING
  }

  onAnimationComplete(kowtowCount: number = 0): void {
    if (!this.blessingEngine) return
    this.blessing = this.blessingEngine.getBlessing(this.activeDeity().id, this.userName)
    this.kowtowCount = kowtowCount
    this.currentPhase = PrayerPhase.BLESSING
    this.saveRecord()
  }

  resetPrayer(): void {
    this.selectedDeity = null
    this.currentPhase = PrayerPhase.IDLE
    this.userName = ''
    this.blessing = ''
    this.kowtowCount = 0
  }

  async isPrivacyAccepted(): Promise<boolean> {
    if (!this.dataPrefs) return false
    try {
      return await this.dataPrefs.get(PRIVACY_KEY, false) as boolean
    } catch (err) {
      console.error('[PrayerViewModel] Failed to read privacy:', JSON.stringify(err))
      return false
    }
  }

  async acceptPrivacy(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      await this.dataPrefs.put(PRIVACY_KEY, true)
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[PrayerViewModel] Failed to save privacy:', JSON.stringify(err))
    }
  }

  async clearHistory(): Promise<void> {
    this.history = []
    await this.persistData()
  }

  private async saveRecord(): Promise<void> {
    const record: PrayerRecord = {
      id: util.generateRandomUUID(true),
      name: this.userName,
      deityId: this.activeDeity().id,
      blessing: this.blessing,
      kowtowCount: this.kowtowCount,
      timestamp: Date.now()
    }
    this.history.unshift(record)
    if (this.history.length > MAX_HISTORY) {
      this.history = this.history.slice(0, MAX_HISTORY)
    }
    this.totalPrayers++
    // 通知 EnrichViewModel 更新磕头/财神追踪
    let streak: number = 0
    try {
      const enrichVM: EnrichViewModel = AppStorage.get<EnrichViewModel>('enrichViewModel') as EnrichViewModel
      if (enrichVM) {
        enrichVM.onKowtowDone(this.kowtowCount, this.activeDeity().id)
        streak = enrichVM.checkin.streak
      }
    } catch (err) {
      console.error('[PrayerViewModel] Failed to update enrichVM:', JSON.stringify(err))
    }
    // 异步上报网络排行榜（不阻塞本地持久化；失败不影响本地流程）
    CloudService.updatePrayerCount(this.kowtowCount, streak).catch((e: Object) => {
      console.error('[PrayerViewModel] updatePrayerCount failed:', JSON.stringify(e))
    })
    await this.persistData()
  }

  removeRecentName(name: string): void {
    this.recentNames = this.recentNames.filter(n => n !== name)
    this.persistRecentNames()
  }

  deleteRecord(id: string): void {
    this.history = this.history.filter(r => r.id !== id)
    this.persistData()
  }

  private saveRecentName(name: string): void {
    this.recentNames = this.recentNames.filter(n => n !== name)
    this.recentNames.unshift(name)
    if (this.recentNames.length > MAX_RECENT_NAMES) {
      this.recentNames = this.recentNames.slice(0, MAX_RECENT_NAMES)
    }
    this.persistRecentNames()
  }

  private async persistRecentNames(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      await this.dataPrefs.put(RECENT_NAMES_KEY, JSON.stringify(this.recentNames))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('Failed to persist recent names:', JSON.stringify(err))
    }
  }

  private async loadPrefs(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      this.recentNames = this.parseJsonArray<string>(
        await this.dataPrefs.get(RECENT_NAMES_KEY, '[]') as string
      )
      this.totalPrayers = await this.dataPrefs.get(TOTAL_PRAYERS_KEY, 0) as number
      this.history = this.parseJsonArray<PrayerRecord>(
        await this.dataPrefs.get(HISTORY_KEY, '[]') as string
      )
    } catch (err) {
      console.error('Failed to load preferences:', JSON.stringify(err))
    }
  }

  private async persistData(): Promise<void> {
    if (!this.dataPrefs) return
    try {
      await this.dataPrefs.put(RECENT_NAMES_KEY, JSON.stringify(this.recentNames))
      await this.dataPrefs.put(TOTAL_PRAYERS_KEY, this.totalPrayers)
      await this.dataPrefs.put(HISTORY_KEY, JSON.stringify(this.history))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('Failed to persist data:', JSON.stringify(err))
    }
  }

  private parseJsonArray<T>(json: string): T[] {
    try {
      const parsed: Object = JSON.parse(json)
      return Array.isArray(parsed) ? (parsed as T[]) : []
    } catch {
      return []
    }
  }
}