// entry/src/main/ets/util/PrivacyConsent.ets
// 隐私同意状态：独立小文件 + 独立 key，与业务 prefs 完全隔离。
//
// 为什么不再挂在 caishen_user_prefs / PrayerViewModel 上（「每次启动都弹」的根因）：
// 1) PrayerViewModel 的 prefs 依赖 initialize() 完成，而 initialize 被排在
//    PrefsRename.migrateOnce(...).then() 之后；MainTabs.aboutToAppear 早于此，
//    读到的 dataPrefs 还是 null → 误判「未同意」→ 弹窗；
// 2) 同意时同样可能撞上 dataPrefs=null，put/flush 被直接跳过且没有任何提示
//    → 永远写不进去 → 下次启动继续弹，形成死循环；
// 3) PrefsRename 每次启动都会 removePreferencesFromCache('caishen_user_prefs')
//    并 flush，与业务读写共用同一文件存在丢更新风险。
//
// 这里不依赖任何 VM 的初始化顺序：setContext() 在 onCreate 里同步调用，首次读写时才
// 惰性 getPreferences；文件名不在 RENAME_SPECS 内，不会被迁移/清缓存波及。
import { preferences } from '@kit.ArkData'
import { PrefsRename } from './PrefsRename'

const PREF_FILE = 'caishen_privacy_prefs'
const KEY_ACCEPTED_AT = 'accepted_at'
/** 旧版本把同意状态存在业务文件里；升级用户读一次并迁移过来，避免重复弹窗 */
const LEGACY_FILE = 'caishen_user_prefs'
const LEGACY_KEY = 'privacy_accepted'
/** 写盘失败重试次数（含首次） */
const WRITE_ATTEMPTS = 2

export class PrivacyConsent {
  private static ctx: Context | null = null
  private static prefs: preferences.Preferences | null = null
  private static opening: Promise<preferences.Preferences | null> | null = null
  /** 本进程内已确认同意：避免重复读盘，也避免同一次启动里二次弹窗 */
  private static acceptedInMemory: boolean = false
  /** 本进程已判定过一次（MainTabs 与 HomePage 都会查，防止双弹） */
  private static prompted: boolean = false

  /** onCreate 同步调用：只记 context，不做 I/O */
  static setContext(context: Context): void {
    PrivacyConsent.ctx = context
  }

  /** 惰性打开独立 prefs 文件（并发调用共用同一个 Promise） */
  private static async open(): Promise<preferences.Preferences | null> {
    if (PrivacyConsent.prefs !== null) {
      return PrivacyConsent.prefs
    }
    if (PrivacyConsent.opening !== null) {
      return await PrivacyConsent.opening
    }
    const ctx: Context | null = PrivacyConsent.ctx
    if (ctx === null) {
      console.error('[PrivacyConsent] open: context 未设置')
      return null
    }
    const task: Promise<preferences.Preferences | null> =
      (async (): Promise<preferences.Preferences | null> => {
        try {
          const p: preferences.Preferences = await preferences.getPreferences(ctx, PREF_FILE)
          PrivacyConsent.prefs = p
          return p
        } catch (err) {
          console.error('[PrivacyConsent] open prefs failed: ' + JSON.stringify(err))
          return null
        } finally {
          PrivacyConsent.opening = null
        }
      })()
    PrivacyConsent.opening = task
    return await task
  }

  /** 是否已同意（纯读取，不弹窗） */
  static async isAccepted(): Promise<boolean> {
    if (PrivacyConsent.acceptedInMemory) {
      return true
    }
    const p: preferences.Preferences | null = await PrivacyConsent.open()
    if (p === null) {
      return false
    }
    try {
      const at: number = await p.get(KEY_ACCEPTED_AT, 0) as number
      if (at > 0) {
        PrivacyConsent.acceptedInMemory = true
        return true
      }
      // 兼容老版本：旧文件里已有 privacy_accepted=true 视为已同意，并迁到新文件
      const legacy: boolean = await PrivacyConsent.readLegacyAccepted()
      if (legacy) {
        PrivacyConsent.acceptedInMemory = true
        await PrivacyConsent.writeAccepted(p)
        return true
      }
      return false
    } catch (err) {
      console.error('[PrivacyConsent] isAccepted failed: ' + JSON.stringify(err))
      return false
    }
  }

  /** 本进程是否该弹隐私窗：同一次启动只判定/弹一次 */
  static async shouldPrompt(): Promise<boolean> {
    if (PrivacyConsent.prompted) {
      return false
    }
    PrivacyConsent.prompted = true
    try {
      return !(await PrivacyConsent.isAccepted())
    } catch (err) {
      console.error('[PrivacyConsent] shouldPrompt failed: ' + JSON.stringify(err))
      // 判定失败按未同意处理（合规优先）
      return true
    }
  }

  /**
   * 记录同意。返回 true = 已确认落盘；false = 写盘失败（调用方应提示用户）。
   * 无论写盘结果，本进程内立即视为已同意，避免同一次使用里反复弹窗。
   */
  static async accept(): Promise<boolean> {
    PrivacyConsent.acceptedInMemory = true
    const p: preferences.Preferences | null = await PrivacyConsent.open()
    if (p === null) {
      return false
    }
    return await PrivacyConsent.writeAccepted(p)
  }

  /** put + flush + 读回校验，失败重试；返回是否确认写入 */
  private static async writeAccepted(p: preferences.Preferences): Promise<boolean> {
    for (let i = 0; i < WRITE_ATTEMPTS; i++) {
      try {
        await p.put(KEY_ACCEPTED_AT, Date.now())
        await p.flush()
        const readback: number = await p.get(KEY_ACCEPTED_AT, 0) as number
        if (readback > 0) {
          return true
        }
        console.error(`[PrivacyConsent] write 第 ${i + 1} 次未落盘（读回 ${readback}）`)
      } catch (err) {
        console.error(`[PrivacyConsent] write 第 ${i + 1} 次异常: ` + JSON.stringify(err))
      }
    }
    return false
  }

  /** 读旧版存在业务文件里的同意标记；等迁移完成后再读，避免读到迁移前的快照 */
  private static async readLegacyAccepted(): Promise<boolean> {
    const ctx: Context | null = PrivacyConsent.ctx
    if (ctx === null) {
      return false
    }
    try {
      await PrefsRename.migrateOnce(ctx)
      const legacy: preferences.Preferences = await preferences.getPreferences(ctx, LEGACY_FILE)
      const v: preferences.ValueType = await legacy.get(LEGACY_KEY, false)
      // 旧值可能是 boolean 也可能被上次迁移写成字符串，两种都认
      return String(v) === 'true'
    } catch (err) {
      console.error('[PrivacyConsent] legacy read failed: ' + JSON.stringify(err))
      return false
    }
  }
}
