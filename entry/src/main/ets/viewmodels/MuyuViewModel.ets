// entry/src/main/ets/viewmodels/MuyuViewModel.ets
// 电子木鱼计数：今日敲击数（跨日清零）+ 累计功德。
import { preferences } from '@kit.ArkData'
import { formatDate } from '../model/FortuneTypes'

const PREF_NAME = 'mashen_muyu_prefs'
const KEY_TODAY_DATE = 'todayDate'
const KEY_TODAY_COUNT = 'todayCount'
const KEY_TOTAL_COUNT = 'totalCount'

@Observed
export class MuyuViewModel {
  todayDate: string = ''
  todayCount: number = 0
  totalCount: number = 0
  private dataPrefs: preferences.Preferences | null = null

  async initialize(context: Context): Promise<void> {
    // 卡片扩展跑在独立进程（caishen.blessing.huawei:form），preferences 有进程内缓存：
    // 不清缓存就会读到本进程上次留下的旧值，写回后把 App 进程刚写入的计数回滚掉。
    await MuyuViewModel.dropCache(context)
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      this.todayDate = await this.dataPrefs.get(KEY_TODAY_DATE, '') as string
      this.todayCount = await this.dataPrefs.get(KEY_TODAY_COUNT, 0) as number
      this.totalCount = await this.dataPrefs.get(KEY_TOTAL_COUNT, 0) as number
      this.rollDayIfNeeded()
    } catch (err) {
      console.error('[MuyuViewModel] Failed to load prefs:', JSON.stringify(err))
    }
  }

  knock(): void {
    this.rollDayIfNeeded()
    this.todayCount = this.todayCount + 1
    this.totalCount = this.totalCount + 1
    this.persist()
  }

  /** 卡片敲击专用：先重读盘再自增，避免并发 read-modify-write 丢计数。
   *  由 FormExtensionAbility 串行调用（见 WidgetFormAbility 的静态任务队列）。 */
  async knockAsync(): Promise<void> {
    await this.reload()
    this.rollDayIfNeeded()
    this.todayCount = this.todayCount + 1
    this.totalCount = this.totalCount + 1
    await this.persist()
  }

  /** 重读磁盘（卡片在 App 后台敲击后，App 回前台必须调用，否则显示旧值）。
   *  传 context 时会先清 preferences 进程缓存，确保读到独立卡片进程写下的最新值。 */
  async reload(context?: Context): Promise<void> {
    if (context !== undefined && context !== null) {
      await MuyuViewModel.dropCache(context)
      try {
        this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
      } catch (err) {
        console.error('[MuyuViewModel] reopen prefs failed:', JSON.stringify(err))
      }
    }
    if (this.dataPrefs === null) {
      return
    }
    try {
      this.todayDate = await this.dataPrefs.get(KEY_TODAY_DATE, '') as string
      this.todayCount = await this.dataPrefs.get(KEY_TODAY_COUNT, 0) as number
      this.totalCount = await this.dataPrefs.get(KEY_TOTAL_COUNT, 0) as number
      if (this.rollDayIfNeeded()) {
        // 跨天归零后落盘，避免 App 长驻前台跨天仍显示昨日数字
        await this.persist()
      }
    } catch (err) {
      console.error('[MuyuViewModel] reload failed:', JSON.stringify(err))
    }
  }

  /** 丢弃 preferences 进程内缓存（跨进程读到旧值的根因，失败不影响主流程） */
  private static async dropCache(context: Context): Promise<void> {
    try {
      await preferences.removePreferencesFromCache(context, PREF_NAME)
    } catch (err) {
      console.error('[MuyuViewModel] drop cache failed:', JSON.stringify(err))
    }
  }

  /** 跨日清零今日计数（返回是否发生了跨天归零） */
  private rollDayIfNeeded(): boolean {
    const today = formatDate(new Date())
    if (this.todayDate !== today) {
      this.todayDate = today
      this.todayCount = 0
      return true
    }
    return false
  }

  private async persist(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_TODAY_DATE, this.todayDate)
      await this.dataPrefs.put(KEY_TODAY_COUNT, this.todayCount)
      await this.dataPrefs.put(KEY_TOTAL_COUNT, this.totalCount)
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[MuyuViewModel] Failed to persist:', JSON.stringify(err))
    }
  }
}
