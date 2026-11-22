// entry/src/main/ets/viewmodels/EntryConfigVM.ets
// 界面定制：可配置入口的 Tab 开关与排序（v1.3.0 个性化显示）。
// 固定首位 Tab（当前为「财神殿」）与我的（固定最后一个 Tab）不在此配置，不可隐藏。
import { preferences } from '@kit.ArkData'

/**
 * 审核整改（2026-11-04）：临时隐藏「祈福」「还愿」两个 Tab。
 *  · 固定首位 Tab 由「祈福」改为「财神殿」，见 MainTabs.FIXED_FIRST_TAB_ID；
 *    祈福页（BlessingSquare → NameCard 流程）保留在工程中，仅从底栏摘下。
 *  · 下列 id 不再进入可配置入口池：还愿整体下线；财神殿已升为固定首位，
 *    若仍留在池里会出现两个「财神殿」Tab。
 *  · 默认可配置 Tab 改为「求签 + 木鱼」，见 DEFAULT_ITEMS / migrateDefaults(v5)。
 *
 * 审核整改（2026-11-15）：「leaderboard」（祈福排行榜）一并下线——
 * 审核结论不允许出现祈福页面，而该页标题与空态文案（快去祈福…）均含「祈福」，
 * 且排名数据来自磕头祈福计数。页面保留在工程中，仅从入口池摘下。
 * 恢复上线：清空此数组 + 把 MainTabs.FIXED_FIRST_TAB_ID/TITLE 改回 blessing/祈福
 * + 把 leaderboard 加回 DEFAULT_ITEMS + bump 一次 CURRENT_DEFAULT_VER。
 */
export const AUDIT_HIDDEN_ENTRY_IDS: string[] = ['wishwall', 'caishenhall', 'leaderboard']

/** 入口当前是否可作为可配置 Tab / 「我的」功能入口出现 */
export function isEntryAvailable(id: string): boolean {
  return AUDIT_HIDDEN_ENTRY_IDS.indexOf(id) < 0
}

/** 可配置入口静态定义 */
export interface EntryDef {
  id: string
  icon: string
  title: string
  /** 底部 Tab 短标题（列表/定制页用完整 title，Tab 栏宽度有限用 tabTitle） */
  tabTitle?: string
}

/** 入口运行时配置项 */
export interface EntryItem {
  id: string
  enabled: boolean   // 是否作为底部 Tab 显示
  order: number       // 排序权重（越小越靠前，Tab 与「我的入口」共用）
}

/**
 * 入口池（id → 页面组件映射见 MainTabs/EntryShell）。
 * 财神历·神诞已并入运势·黄历页（v1.3.0 反馈），不再作为独立入口。
 */
export const ENTRY_POOL: EntryDef[] = [
  // ☯ 太极：纯字形（无 emoji 变体），Tab/列表里随主题色渲染成金色，比彩色 🗓️ 更贴项目古文化调性
  { id: 'fortune', icon: '☯', title: '运势·黄历' },
  { id: 'qiuqian', icon: '🎋', title: '求签' },
  { id: 'muyu', icon: '🪵', title: '木鱼' },
  // Tab 栏每项约 72vp，「还愿·感谢财神」会被截断，Tab 上只显示「还愿」
  { id: 'wishwall', icon: '🙏', title: '还愿·感谢财神', tabTitle: '还愿' },
  { id: 'leaderboard', icon: '🏆', title: '祈福排行榜' },
  { id: 'encyclopedia', icon: '📜', title: '财神百科' },
  // 🎲 骰子：与 🎋🙏🏆 等功能入口同风格。收支记录在「我的」页置顶固定展示、
  // 不随开关消失（MyPage 顶部卡即入口，不入「功能入口」行），开启后额外以底部 Tab 直达。
  { id: 'gamerecord', icon: '🎲', title: '收支记录' },
  // 🪙 铜钱兜底 emoji（原 🏯 为日式城堡，不符主题；列表实际显示走自绘 CaiShenHallIcon）
  { id: 'caishenhall', icon: '🪙', title: '财神殿' }
]

/** 当前可用的可配置入口池（审核整改下线的入口不在此列） */
export function getAvailableEntryPool(): EntryDef[] {
  return ENTRY_POOL.filter((d: EntryDef): boolean => isEntryAvailable(d.id))
}

/** 中间可配置 Tab 上限（底部导航最多 5 项：固定首位 + 3 + 我的） */
const MAX_TABS = 3
const PREF_NAME = 'caishen_entry_prefs'
const KEY_ENTRY_CONFIG = 'entryConfig'
/** 默认 Tab 版本：老用户已持久化过配置，改 DEFAULT_ITEMS 不会生效，
 *  靠这个标记做一次性补齐（见 migrateDefaults） */
const KEY_DEFAULT_VER = 'entryDefaultVer'
const CURRENT_DEFAULT_VER = 5
/** AppStorage 版本信号：UI v1 下 @StorageLink 只观察顶层键，@Observed 嵌套属性
 *  变更不会自动通知读取方（MainTabs 的 Tab 列表等），每次持久化变更后 +1，
 *  各消费页以 @StorageLink('entryConfigRev') + @Watch 重取派生数据。 */
const KEY_CONFIG_REV = 'entryConfigRev'

/** 默认配置（v5 起，审核整改）：财神殿（固定首位）| 求签 | 木鱼 | 我的（固定末位）；
 *  其余（运势、百科、收支）走「我的 → 界面定制」按需开启。
 *  2026-11-15：leaderboard（祈福排行榜）随审核整改下线，从默认表移除
 *  （见 AUDIT_HIDDEN_ENTRY_IDS 头注释，恢复时需加回本表）。 */
const DEFAULT_ITEMS: EntryItem[] = [
  { id: 'qiuqian', enabled: true, order: 1 },
  { id: 'muyu', enabled: true, order: 2 },
  { id: 'fortune', enabled: false, order: 3 },
  { id: 'encyclopedia', enabled: false, order: 5 },
  { id: 'gamerecord', enabled: false, order: 6 }
]

@Observed
export class EntryConfigVM {
  items: EntryItem[] = DEFAULT_ITEMS.map((it: EntryItem): EntryItem => {
    return { id: it.id, enabled: it.enabled, order: it.order }
  })
  private dataPrefs: preferences.Preferences | null = null

  async initialize(context: Context): Promise<void> {
    this.dataPrefs = await preferences.getPreferences(context, PREF_NAME)
    try {
      const savedStr = await this.dataPrefs.get(KEY_ENTRY_CONFIG, '') as string
      if (savedStr !== '') {
        const saved: EntryItem[] = JSON.parse(savedStr)
        // 以池为准合并：新增入口补默认值，已下线入口忽略
        // （无存档时保持 DEFAULT_ITEMS，migrateDefaults 仍需执行以写版本标记）
        if (Array.isArray(saved) && saved.length > 0) {
          this.items = getAvailableEntryPool().map((def: EntryDef): EntryItem => {
            const found = saved.find((it: EntryItem): boolean => it.id === def.id)
            if (found) {
              return { id: found.id, enabled: found.enabled === true, order: found.order }
            }
            const fallback = DEFAULT_ITEMS.find((it: EntryItem): boolean => it.id === def.id)
            if (fallback) {
              return { id: fallback.id, enabled: fallback.enabled, order: fallback.order }
            }
            return { id: def.id, enabled: false, order: 99 }
          })
        }
      }
    } catch (err) {
      console.error('[EntryConfigVM] Failed to load prefs:', JSON.stringify(err))
    }
    // 审核整改：无论有无存档、版本是否已升级，已下线入口都不进入运行时配置
    this.items = this.items.filter((it: EntryItem): boolean => isEntryAvailable(it.id))
    await this.migrateDefaults()
    this.notifyChanged()
  }

  /**
   * 默认 Tab 一次性升级：v5（审核整改）默认底栏 = 财神殿（固定）| 求签 | 木鱼 | 我的。
   * 老设备已持久化过配置，只改 DEFAULT_ITEMS 不生效，这里按版本标记强制迁移：
   *   ① 剔除已下线入口（还愿，以及升为固定首位、不能再留在池里的财神殿），
   *      否则老存档会让「财神殿」渲染两次、并让「还愿」继续出现在底栏；
   *   ② 补齐 DEFAULT_ITEMS 中新增的入口；
   *   ③ 求签、木鱼强制开启并排在可配 Tab 最前（审核期默认组合）；
   *   ④ 开启总数超过 MAX_TABS 时，按 order 从大到小关掉非默认项，保证底栏 ≤5 项。
   * 迁移只跑一次（写 KEY_DEFAULT_VER），之后用户仍可在「界面定制」自由调整。
   */
  private async migrateDefaults(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    let ver: number = 0
    try {
      ver = await this.dataPrefs.get(KEY_DEFAULT_VER, 0) as number
    } catch (err) {
      console.error('[EntryConfigVM] Failed to read default ver:', JSON.stringify(err))
    }
    if (ver >= CURRENT_DEFAULT_VER) {
      return
    }
    // ① + ②
    const kept: EntryItem[] = this.items
      .filter((it: EntryItem): boolean => isEntryAvailable(it.id))
      .map((it: EntryItem): EntryItem => {
        return { id: it.id, enabled: it.enabled === true, order: it.order }
      })
    for (const def of DEFAULT_ITEMS) {
      if (!kept.some((it: EntryItem): boolean => it.id === def.id)) {
        kept.push({ id: def.id, enabled: def.enabled, order: def.order })
      }
    }
    // ③ 求签、木鱼固定为默认前两位，其余保持用户原有相对顺序
    const rest: EntryItem[] = kept
      .filter((it: EntryItem): boolean => it.id !== 'qiuqian' && it.id !== 'muyu')
      .sort((a: EntryItem, b: EntryItem): number => a.order - b.order)
    const merged: EntryItem[] = [
      { id: 'qiuqian', enabled: true, order: 1 },
      { id: 'muyu', enabled: true, order: 2 }
    ]
    rest.forEach((it: EntryItem, i: number): void => {
      merged.push({ id: it.id, enabled: it.enabled, order: i + 3 })
    })
    this.items = merged
    // ④
    while (this.tabEnabledCount() > MAX_TABS) {
      const candidates: EntryItem[] = [...this.items]
        .filter((it: EntryItem): boolean =>
          it.enabled && it.id !== 'qiuqian' && it.id !== 'muyu')
        .sort((a: EntryItem, b: EntryItem): number => b.order - a.order)
      if (candidates.length === 0) {
        break
      }
      const victim = this.items.find((it: EntryItem): boolean => it.id === candidates[0].id)
      if (victim !== undefined) {
        victim.enabled = false
      }
    }
    await this.persist()
    try {
      await this.dataPrefs.put(KEY_DEFAULT_VER, CURRENT_DEFAULT_VER)
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[EntryConfigVM] Failed to write default ver:', JSON.stringify(err))
    }
  }

  /** 条目变更信号：写 AppStorage rev，消费页 @Watch 后重建派生 UI（见 KEY_CONFIG_REV 注释） */
  private notifyChanged(): void {
    try {
      const cur: number = AppStorage.get<number>(KEY_CONFIG_REV) ?? 0
      AppStorage.setOrCreate(KEY_CONFIG_REV, cur + 1)
    } catch (err) {
      console.error('[EntryConfigVM] notifyChanged failed:', JSON.stringify(err))
    }
  }

  /** 开关入口的 Tab 显示；开启第 MAX_TABS+1 个时拒绝并返回 false */
  setEnabled(id: string, on: boolean): boolean {
    if (!isEntryAvailable(id)) {
      return false
    }
    if (on && this.tabEnabledCount() >= MAX_TABS) {
      return false
    }
    this.items = this.items.map((it: EntryItem): EntryItem => {
      if (it.id === id) {
        return { id: it.id, enabled: on, order: it.order }
      }
      return it
    })
    this.persist()
    this.notifyChanged()
    return true
  }

  /** 长按拖拽排序：把 order 升序列表中的 fromIdx 移到 toIdx（其余依次顺延/前移） */
  move(fromIdx: number, toIdx: number): void {
    if (fromIdx === toIdx) {
      return
    }
    const sorted = this.getSortedItems()
    if (fromIdx < 0 || fromIdx >= sorted.length || toIdx < 0 || toIdx >= sorted.length) {
      return
    }
    const arr = sorted.map((it: EntryItem): EntryItem => {
      return { id: it.id, enabled: it.enabled, order: it.order }
    })
    const moved: EntryItem = arr.splice(fromIdx, 1)[0]
    arr.splice(toIdx, 0, moved)
    this.items = arr.map((it: EntryItem, i: number): EntryItem => {
      return { id: it.id, enabled: it.enabled, order: i + 1 }
    })
    this.persist()
    this.notifyChanged()
  }

  /** 与全量排序列表中的相邻项交换 order；dir=-1 上移，1 下移 */
  swap(id: string, dir: number): void {
    const sorted = this.getSortedItems()
    const idx = sorted.findIndex((it: EntryItem): boolean => it.id === id)
    const j = idx + dir
    if (idx < 0 || j < 0 || j >= sorted.length) {
      return
    }
    const a = sorted[idx]
    const b = sorted[j]
    this.items = this.items.map((it: EntryItem): EntryItem => {
      if (it.id === a.id) {
        return { id: it.id, enabled: it.enabled, order: b.order }
      }
      if (it.id === b.id) {
        return { id: it.id, enabled: it.enabled, order: a.order }
      }
      return it
    })
    this.persist()
  }

  isFirst(id: string): boolean {
    const sorted = this.getSortedItems()
    return sorted.length > 0 && sorted[0].id === id
  }

  isLast(id: string): boolean {
    const sorted = this.getSortedItems()
    return sorted.length > 0 && sorted[sorted.length - 1].id === id
  }

  isTabOn(id: string): boolean {
    const it = this.items.find((item: EntryItem): boolean => item.id === id)
    return it ? it.enabled : false
  }



  tabEnabledCount(): number {
    return this.items
      .filter((it: EntryItem): boolean => isEntryAvailable(it.id) && it.enabled)
      .length
  }

  /** 作为 Tab 显示的入口（按 order 升序），供 MainTabs 渲染 */
  getTabEntries(): EntryDef[] {
    const defs: EntryDef[] = []
    const enabled = [...this.items]
      .filter((it: EntryItem): boolean => isEntryAvailable(it.id))
      .sort((a: EntryItem, b: EntryItem): number => a.order - b.order)
      .filter((it: EntryItem): boolean => it.enabled)
    for (const it of enabled) {
      const def = getAvailableEntryPool().find((d: EntryDef): boolean => d.id === it.id)
      if (def) {
        defs.push(def)
      }
    }
    return defs
  }

  /** 全量配置项（按 order 升序），供「界面定制」与「我的入口」渲染 */
  getSortedItems(): EntryItem[] {
    return [...this.items]
      .filter((it: EntryItem): boolean => isEntryAvailable(it.id))
      .sort((a: EntryItem, b: EntryItem): number => a.order - b.order)
  }

  getIcon(id: string): string {
    const def = ENTRY_POOL.find((d: EntryDef): boolean => d.id === id)
    return def ? def.icon : ''
  }

  getTitle(id: string): string {
    const def = ENTRY_POOL.find((d: EntryDef): boolean => d.id === id)
    return def ? def.title : ''
  }

  private async persist(): Promise<void> {
    if (!this.dataPrefs) {
      return
    }
    try {
      await this.dataPrefs.put(KEY_ENTRY_CONFIG, JSON.stringify(this.items))
      await this.dataPrefs.flush()
    } catch (err) {
      console.error('[EntryConfigVM] Failed to persist:', JSON.stringify(err))
    }
  }
}
