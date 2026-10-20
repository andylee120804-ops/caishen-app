// entry/src/main/ets/viewmodels/KowtowViewModel.ets
// 磕头统一计数：今日磕头数（跨日清零）+ 累计磕头。
// 两个写入方共用一份计数：桌面磕头卡直磕（卡片扩展进程）+ App 祈福完成（主进程按次并入）。
//
// 【存储位置】专属文件 mashen_kowtow_prefs：与 mashen_user_prefs / mashen_enrich_prefs
// 这类「常驻 VM 共用文件」不同（见 QiuQianViewModel 头注的进程纪律），本文件没有任何
// 常驻实例持有——两端都走「掉缓存 → 重开 → 读改写」，永远操作最新盘，可安全双进程写。
// 卡片扩展侧由 WidgetFormAbility 的静态任务队列串行；跨进程同时写（App 祈福与点卡同瞬）
// 最多丢一次计数，与木鱼卡的暴露面一致。
//
// 【播种】文件首次创建时从旧数据源播种，保证老用户卡片数字连续：
// 今日 = 当日祈福记录 kowtowCount 求和（prayer_history）；累计 = enrich 的 totalKowtow
// （App 祈福口径，供成就用；此后卡片直磕只进本文件，两者刻意分开——enrich 不能被
// 扩展进程写，否则与常驻 EnrichViewModel 双实例分叉互相覆盖）。
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { formatDate } from '../model/FortuneTypes'
import { PrayerRecord } from '../model/PrayerTypes'

const PREF_NAME = 'mashen_kowtow_prefs'
const KEY_DAILY = 'kowtowDaily'
const LEGACY_USER_PREFS = 'mashen_user_prefs'
const LEGACY_ENRICH_PREFS = 'mashen_enrich_prefs'
const LOG_DOMAIN: number = 0xF811
const LOG_TAG: string = 'KowtowVM'

/** 磕头计数快照 */
export interface KowtowDaily {
  date: string    // YYYY-MM-DD
  today: number   // 今日磕头（App 祈福 + 卡片直磕）
  total: number   // 累计磕头
}

export class KowtowViewModel {
  /** 读当前计数（跨日内存归零；文件不存在时播种并落盘）。
   *  mainProcess：调用方是否在主进程——仅影响播种读共用文件的方式
   *  （主进程绝不能掉缓存，见 seed 注释）。 */
  static async load(context: Context, mainProcess: boolean): Promise<KowtowDaily> {
    try {
      await KowtowViewModel.dropCache(context)
      const prefs = await preferences.getPreferences(context, PREF_NAME)
      const raw: string = await prefs.get(KEY_DAILY, '') as string
      if (raw === '') {
        const seeded: KowtowDaily = await KowtowViewModel.seed(context, mainProcess)
        await KowtowViewModel.write(context, seeded)
        hilog.info(LOG_DOMAIN, LOG_TAG, `seeded today=${seeded.today} total=${seeded.total}`)
        return seeded
      }
      const daily: KowtowDaily = JSON.parse(raw) as KowtowDaily
      const today: string = formatDate(new Date())
      if (daily.date !== today) {
        // 跨日：返回归零视图；落盘交给下一次写（避免只读路径产生写放大）
        return { date: today, today: 0, total: daily.total }
      }
      return daily
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'load failed: ' + JSON.stringify(err))
      return { date: formatDate(new Date()), today: 0, total: 0 }
    }
  }

  /** 磕头 count 次：同一实例内读改写（掉缓存重开 → 读 → 自增 → 落盘）。
   *  调用方：卡片扩展（WidgetFormAbility 串行队列，mainProcess=false）/
   *  App 祈福完成（PrayerCard，mainProcess=true）。 */
  static async bump(context: Context, count: number, mainProcess: boolean): Promise<KowtowDaily> {
    try {
      await KowtowViewModel.dropCache(context)
      const prefs = await preferences.getPreferences(context, PREF_NAME)
      const raw: string = await prefs.get(KEY_DAILY, '') as string
      let daily: KowtowDaily = raw === ''
        ? await KowtowViewModel.seed(context, mainProcess)
        : JSON.parse(raw) as KowtowDaily
      const today: string = formatDate(new Date())
      if (daily.date !== today) {
        daily = { date: today, today: 0, total: daily.total }
      }
      const next: KowtowDaily = { date: daily.date, today: daily.today + count, total: daily.total + count }
      await prefs.put(KEY_DAILY, JSON.stringify(next))
      await prefs.flush()
      hilog.info(LOG_DOMAIN, LOG_TAG, `bump +${count} today=${next.today} total=${next.total}`)
      return next
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'bump failed: ' + JSON.stringify(err))
      return { date: formatDate(new Date()), today: 0, total: 0 }
    }
  }

  /**
   * 播种（文件首次创建）：读旧数据源——
   * · 扩展进程（mainProcess=false）：无人常驻持有共用文件，掉缓存重开 = 直读最新盘；
   * · 主进程（mainProcess=true）：**绝不能掉缓存**——getPreferences 返回的正是常驻
   *   PrayerViewModel / EnrichViewModel 手里的实例，读到即最新（含未 flush 的写入）；
   *   掉缓存会另开实例造成双写分叉。
   */
  private static async seed(context: Context, mainProcess: boolean): Promise<KowtowDaily> {
    const today: string = formatDate(new Date())
    try {
      if (!mainProcess) {
        await preferences.removePreferencesFromCache(context, LEGACY_USER_PREFS)
        await preferences.removePreferencesFromCache(context, LEGACY_ENRICH_PREFS)
      }
      const prayerPrefs = await preferences.getPreferences(context, LEGACY_USER_PREFS)
      const enrichPrefs = await preferences.getPreferences(context, LEGACY_ENRICH_PREFS)
      let todayKowtow: number = 0
      const parsed: Object = JSON.parse(await prayerPrefs.get('prayer_history', '[]') as string)
      if (Array.isArray(parsed)) {
        const records: PrayerRecord[] = parsed as PrayerRecord[]
        for (const rec of records) {
          if (formatDate(new Date(rec.timestamp)) === today) {
            todayKowtow += rec.kowtowCount
          }
        }
      }
      const total: number = await enrichPrefs.get('totalKowtow', 0) as number
      return { date: today, today: todayKowtow, total: total }
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'seed failed: ' + JSON.stringify(err))
      return { date: today, today: 0, total: 0 }
    }
  }

  private static async write(context: Context, daily: KowtowDaily): Promise<void> {
    await KowtowViewModel.dropCache(context)
    const prefs = await preferences.getPreferences(context, PREF_NAME)
    await prefs.put(KEY_DAILY, JSON.stringify(daily))
    await prefs.flush()
  }

  /** 丢弃本文件进程内缓存（本文件无常驻持有者，掉缓存永远安全） */
  private static async dropCache(context: Context): Promise<void> {
    try {
      await preferences.removePreferencesFromCache(context, PREF_NAME)
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'drop cache failed: ' + JSON.stringify(err))
    }
  }
}
