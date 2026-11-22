// entry/src/main/ets/util/AuditFlags.ets

/**
 * 审核整改（2026-11-15）：祈福流程页面整体下线。
 * 审核结论：不允许出现「祈福」页面（NameCard 写祈福话 → PrayerCard 磕头祈福
 * → BlessingCard 祈福完成页，三页均保留在工程中，仅隐藏全部可达入口）。
 *  · 2026-11-04 已摘下底栏「祈福」「还愿」Tab（EntryConfigVM.AUDIT_HIDDEN_ENTRY_IDS
 *    + MainTabs.FIXED_FIRST_TAB_ID 改财神殿），但求签页残留「去祈福」按钮仍可进流程。
 *  · 本次隐藏的入口：求签页两处「去祈福」按钮（揭签操作行 + 解签详情弹层）、
 *    HomePage（旧首页，现无路由可达，防御性隐藏）「开始祈福」按钮、
 *    还愿页心愿条「还愿」按钮（磕头还愿走 PrayerCard）。
 *
 * 恢复上线：本值改回 true，并按 EntryConfigVM / MainTabs 头注释恢复 Tab 配置。
 */
export const PRAYER_FLOW_VISIBLE: boolean = false
