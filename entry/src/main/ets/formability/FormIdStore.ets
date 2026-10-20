// entry/src/main/ets/formability/FormIdStore.ets
// 卡片实例登记表：formProvider.updateForm(formId, data) 必须传 formId，系统没有
// 「刷新本应用全部卡片」的公开接口。因此 onAddForm 时把 formId → formName 落盘，
// onRemoveForm 时移除；App 侧 FormSyncService 据此逐个刷新。
// 同一张卡可被添加多个实例（formId 各不相同），故用 map 而非单值。
import { preferences } from '@kit.ArkData'

const PREF_NAME = 'mashen_form_prefs'
const KEY_MAP = 'formIdMap'

function parseMap(raw: string): Record<string, string> {
  if (raw === '') {
    return {}
  }
  try {
    return JSON.parse(raw) as Record<string, string>
  } catch (err) {
    console.error('[FormIdStore] parse failed:', JSON.stringify(err))
    return {}
  }
}

export class FormIdStore {
  /** 登记（新建卡片 / 进程被杀后重建都会再走一次，幂等覆盖） */
  static async add(context: Context, formId: string, formName: string): Promise<void> {
    if (formId === '') {
      return
    }
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, PREF_NAME)
      const raw = await prefs.get(KEY_MAP, '')
      const map: Record<string, string> = parseMap(raw as string)
      map[formId] = formName
      await prefs.put(KEY_MAP, JSON.stringify(map))
      await prefs.flush()
    } catch (err) {
      console.error('[FormIdStore] add failed:', JSON.stringify(err))
    }
  }

  /** 移除（卡片被用户删除） */
  static async remove(context: Context, formId: string): Promise<void> {
    if (formId === '') {
      return
    }
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(context, PREF_NAME)
      const raw = await prefs.get(KEY_MAP, '')
      const old: Record<string, string> = parseMap(raw as string)
      // ArkTS 不支持 delete 运算符：重建一份排除该 formId 的 map
      const next: Record<string, string> = {}
      const ids: string[] = Object.keys(old)
      for (const id of ids) {
        if (id !== formId) {
          next[id] = old[id]
        }
      }
      await prefs.put(KEY_MAP, JSON.stringify(next))
      await prefs.flush()
    } catch (err) {
      console.error('[FormIdStore] remove failed:', JSON.stringify(err))
    }
  }

  /** 全部已添加卡片：formId → formName。
   *  卡片扩展与 App 在不同进程，preferences 有进程内缓存：读取前先清缓存，
   *  否则 App 侧会一直读到空表（表现为「推卡片没反应」）。 */
  static async all(context: Context): Promise<Record<string, string>> {
    try {
      await preferences.removePreferencesFromCache(context, PREF_NAME)
      const prefs: preferences.Preferences = await preferences.getPreferences(context, PREF_NAME)
      const raw = await prefs.get(KEY_MAP, '')
      return parseMap(raw as string)
    } catch (err) {
      console.error('[FormIdStore] all failed:', JSON.stringify(err))
      return {}
    }
  }
}
