// entry/src/main/ets/util/PrefsRename.ets
// 一次性 preferences 文件改名迁移：mashen_* → caishen_*。
// 项目自「麻神保佑」独立为「财神保佑」后统一内部存储名前缀；老安装（升级用户）的
// 签录/功德/磕头/木鱼/入口配置等数据必须连续，直接改名会把一切累计归零。
//
// 用法：任何 VM 读盘之前调用 PrefsRename.migrateOnce(context)——
// 主进程 EntryAbility.onCreate、卡片进程 WidgetFormAbility 各调一次，
// 进程内单例（模块级 promise，跨实例存活），两个进程都跑也幂等。
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'

const LOG_DOMAIN: number = 0xF811
const LOG_TAG: string = 'PrefsRename'

interface RenameSpec {
  oldName: string
  newName: string
  /** 该文件全部 key（值类型不限，按 key 逐个搬；新文件已有即跳过） */
  keys: string[]
}

const RENAME_SPECS: RenameSpec[] = [
  {
    oldName: 'mashen_user_prefs', newName: 'caishen_user_prefs',
    keys: ['prayer_history', 'recentNames', 'totalPrayers', 'privacy_accepted', 'deviceUserId']
  },
  {
    oldName: 'mashen_enrich_prefs', newName: 'caishen_enrich_prefs',
    keys: ['checkin', 'gameRecords', 'diaryNotes', 'totalKowtow', 'bowedDeities',
      'wasTopDaily', 'wishFulfilledCount', 'lastGameRecordBackupAt', 'deletedGameDates']
  },
  { oldName: 'mashen_qiuqian_prefs', newName: 'caishen_qiuqian_prefs', keys: ['qiuRecords', 'qiuDaily'] },
  { oldName: 'mashen_muyu_prefs', newName: 'caishen_muyu_prefs', keys: ['todayDate', 'todayCount', 'totalCount'] },
  { oldName: 'mashen_kowtow_prefs', newName: 'caishen_kowtow_prefs', keys: ['kowtowDaily'] },
  { oldName: 'mashen_fortune_prefs', newName: 'caishen_fortune_prefs', keys: ['zodiacIdx', 'shengxiaoIdx', 'shendanFavorites'] },
  { oldName: 'mashen_entry_prefs', newName: 'caishen_entry_prefs', keys: ['entryConfig', 'entryDefaultVer'] },
  { oldName: 'mashen_form_prefs', newName: 'caishen_form_prefs', keys: ['formIdMap'] }
]

export class PrefsRename {
  /** 进程内单例 promise：多处调用只执行一次 */
  private static migration: Promise<void> | null = null

  /** 幂等入口：本进程首次调用触发迁移，随后直接复用同一 promise */
  static async migrateOnce(context: Context): Promise<void> {
    if (PrefsRename.migration === null) {
      PrefsRename.migration = PrefsRename.migrate(context)
    }
    return PrefsRename.migration
  }

  private static async migrate(context: Context): Promise<void> {
    for (const spec of RENAME_SPECS) {
      try {
        // 迁移先于一切 VM 初始化，新旧两个名字都无常驻持有者，掉缓存安全
        await preferences.removePreferencesFromCache(context, spec.oldName)
        await preferences.removePreferencesFromCache(context, spec.newName)
        const oldPrefs: preferences.Preferences = await preferences.getPreferences(context, spec.oldName)
        const newPrefs: preferences.Preferences = await preferences.getPreferences(context, spec.newName)
        let copied: number = 0
        for (const key of spec.keys) {
          if (await newPrefs.has(key)) {
            continue
          }
          if (!(await oldPrefs.has(key))) {
            continue
          }
          // key 已确认存在，默认值不参与返回；按 string 读不影响 number/boolean 原值
          const value: string = await oldPrefs.get(key, '') as string
          await newPrefs.put(key, value)
          copied++
        }
        if (copied > 0) {
          await newPrefs.flush()
          hilog.info(LOG_DOMAIN, LOG_TAG, `migrated ${spec.oldName} -> ${spec.newName}, keys=${copied}`)
        }
      } catch (err) {
        // 单文件失败不影响其余文件，也不抛断迁移链（migrateOnce 永不 reject）
        hilog.error(LOG_DOMAIN, LOG_TAG, `migrate ${spec.oldName} failed: ` + JSON.stringify(err))
      }
    }
  }
}
