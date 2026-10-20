# 祈福主位每日轮转 + 顶部主神牌设计

> 日期：2026-10-05
> 状态：设计已确认（brainstorming 完成：排位方案 A、顶部卡片方案 B），待实现计划
> 背景：用户反馈祈福页五神阵主位永远是赵公明（位置写死），与「今日主麻神」每日轮转逻辑（DeityRotator 已存在）矛盾；页顶黄历卡 emoji 与项目风格不符、信息冗余、主神地位不突出。

## 1. 问题现状

1. **主位不轮转**：`DeityArrayView.ets` 的 `DEITY_LAYOUTS` 将神 id 1（赵公明）固定绑在中央锚点（`x:50%, y:54%, size:80`），`highlightId` 只影响光晕强度与名号字号，不换位置。而 `DeityRotator.getTodayDeity()`（按 `((dayOfYear-1) % 5) + 1` 每日轮换）、BlessingCard 主位令牌、桌面「今日主麻神」卡（DeityCard2x2）均已显示当日主神 → 图文不一致。
2. **顶部黄历卡**：`DailyAlmanac` 组件含 emoji（📅、宜✅、忌❌、香火🔥）、五行信息（日期/宜忌/主神/吉位/花色/香火），主神只是一行夹在中间的小字，不突出拜麻神主题。
3. **跨天残留**：`PrayerViewModel.todayDeity` 仅在构造函数与 `startPrayer()` 时计算；App 跨午夜不重启，主神显示停留在昨天。

## 2. 目标与范围

| 项 | 内容 |
|---|---|
| 主位轮转 | 五神阵主位（中央最大、光晕最强、先现身）由当日主麻神占据，**当天固定不变**，跨天自动轮换 |
| 顶部主神牌 | 精简为「主神突出」卡片：主神名号大字号为主体，黄历压缩成一行小字；**去掉全部 emoji** |
| 跨天刷新 | 回到前台/Tab 时刷新今日主神，消除跨午夜残留 |

**不做**（YAGNI）：每神专属音效（`DeityInfo.soundFile` 素材在，随时可加）；五神全体轮转（方位标签会与站位错位）；桌面卡片改动（已与新逻辑天然一致）；黄历页（FortuneAlmanacPage）内容改动；五神阵上额外加「今日主神」徽章（顶部主神牌已承担）。

## 3. 主位轮转（方案 A：主神对调）

### 3.1 轮转规则

五个锚点（坐标/尺寸/现身 delay）**保持不变**，只改「神 → 锚点」映射。锚点编号恰好等于神 id 的方位序（1中/2东/3西/4南/5北），映射为纯函数：

```typescript
// DeityRotator 新增
static anchorOf(deityId: number, todayId: number): number {
  if (deityId === todayId) return 1            // 今日主神 → 中央主位
  if (deityId === 1) return todayId            // 赵公明 → 主神原方位锚点（暂代其位）
  return deityId                               // 其余三路财神守本方位
}
```

- 今日主神是赵公明时（todayId=1）全体维持现状布局。
- 例如今日主神为曹宝（id 3）：曹宝↔锚点1（中路主位）、赵公明↔锚点3（西路位）、萧升/陈九公/姚少司不动。

### 3.2 DeityArrayView 改动

- 新增 `@Prop todayId: number = 1`。
- `layoutOf(id)` 改为 `getDeityLayout(DeityRotator.anchorOf(id, this.todayId))`——锚点表 `DEITY_LAYOUTS` 与 delay/现身顺序保持锚点绑定（主位先现身，视觉自然）。
- 传入 `deities` 数组与 `highlightId`（=todayId）语义不变；`ForEach` key 仍为 `deity.id`，ArkTS diff 只改 position，不重建节点。
- 三个调用点（MainTabs 祈福 Tab、PrayerCard、HomePage）传入 `viewModel.todayDeity.id`。

### 3.3 「当天固定」语义

- `DeityRotator` 按本地日期（年内第 N 天）纯函数计算：同一天任意时刻结果相同，天然满足「当天是谁不变」。
- 叩拜流程在 APPEAR 动画开始时已锁定主神，跨午夜进行中的动画/祈福不中途换神（记录里的 `deityId` 与画面一致）。

## 4. 顶部主神牌（方案 B）

改造 `DailyAlmanac` 组件（仅祈福 Tab 使用，黄历页独立渲染不受影响）：

```
— 今日主麻神 —                   rgba(249,202,36,0.8)·11fp·字距4
    曹宝                        #f9ca24 实色·26fp·Bold     ← 主神地位
西路 · 纳珍入库，攒好牌型          rgba(253,246,227,0.7)·12fp（direction + mahjongMeaning）
────────────────                                      分隔线 rgba(249,202,36,0.25)
八月廿五 · 周日 ｜ 宜 纳财 · 忌 动土 ｜ 吉位 东方   rgba(253,246,227,0.55)·11fp 一行小字
```

**去掉**：📅/✅/❌/🔥 全部 emoji；「今日香火」行（签到卡/排行榜已有）；「花色」行（黄历页可查）。
**保留**：农历+周、宜、忌、吉位（一行内）；主神名号/方位/麻将寓意。

配色对照 WCAG 规范（卡片底 `#1a1a0a`）：金色大字实色 `#f9ca24`（11.29 ✓）；米色辅助文字 alpha ≥0.5 ✓。卡片整体配色沿用现有红褐底 `rgba(192,57,43,0.08)` + 金边 `rgba(249,202,36,0.2)`，圆角 10，宽 90%，定位不变（`y:48` 避开状态栏）。

**数据结构**：照旧使用 `viewModel.todayDeity` 与 `enrichVM.getAlmanac()`，`getAlmanac()` 的 suitable/avoid/direction 字段不变；删除组件内 `getIncenseBar()` 与 emoji 模板。

## 5. 跨天刷新

`PrayerViewModel` 新增（示意，`dateStrOf` 为本地日期 `YYYY-MM-DD` 格式化的私有辅助）：

```typescript
private todayDeityDate: string = ''   // YYYY-MM-DD 缓存

refreshTodayDeity(): void {
  const dateStr = this.dateStrOf(new Date())   // 本地日期 YYYY-MM-DD
  if (dateStr !== this.todayDeityDate) {
    this.todayDeityDate = dateStr
    this.todayDeity = DeityRotator.getTodayDeity()
  }
}
```

### 5.1 用户选神与今日主神严格分离（执行期审查新增，2026-10-05 用户选定方案 A）

原代码 NameCard 将用户手动选的财神直接写入 `todayDeity`（原依赖 `startPrayer()` 每次重算来隐式清除）。同日缓存会把这个「本次祈福有效」的选择变成「整天有效」，污染顶部主神牌与五神阵主位。修正（方案 A）：

- `todayDeity` **永远** = 当日日期轮转主神：顶部主神牌（DailyAlmanac）、祈福 Tab/HomePage 五神阵主位、桌面卡片均只读它。
- 新增 `selectedDeity: DeityInfo | null`：NameCard 用户选择只影响**本次祈福流程**。
  - `selectDeity(deity)` 写入；`startPrayer()` 与 `resetPrayer()` 均清空（`null`）。
  - 新增只读 `activeDeity(): DeityInfo => selectedDeity ?? todayDeity`。
  - 使用 `activeDeity()` 的位置：PrayerCard 五神阵（todayId/highlightId）、BlessingCard 主位令牌、`onAnimationComplete` 祝福生成、`saveRecord` 的 `deityId`、`enrichVM.onKowtowDone`、NameCard `createWish` 的 deityId。
- 语义结果：主位/顶部牌当天固定由日期轮转（需求核心）；用户选谁只决定本次叩拜对象与祝福卡。

## 5.3 还愿拜许愿时的麻神（2026-10-05 用户新增）

还愿与许愿常跨天，日期轮转后今日主神已换人；「还愿」须还**许愿当日所拜的那位麻神**，而非今日主神：

- 心愿记录（`Wish`）在创建时已存 `deityId`（NameCard `createWish` 传 `activeDeity().id`，云函数 `wish-wall` 持久化并随 list 返回）。
- `WishWall.fulfillWish` 导航 PrayerCard 时携带 `fulfillDeityId: wish.deityId`（心愿查无此条时兜底 `0`）。
- `PrayerCard` 还愿分支由 `selectDeity(null)` 改为：`FIVE_DEITIES.find(d => d.id === fulfillDeityId)` → `selectDeity(wishDeity ?? null)`。命中则本次还愿主位/光晕/祝福卡/磕头记录全部记许愿时的神；`deityId` 缺失（旧数据）回落今日主神。
- 还愿结束后 `resetPrayer()`/`startPrayer()` 照常清空 `selectedDeity`，不污染后续会话。

## 5.2 跨天刷新钩子

- 构造函数改用 `refreshTodayDeity()`（替代直接 getTodayDeity）。
- `MainTabs.onPageShow()` 调用 `refreshTodayDeity()`：回到前台/从子页返回即刷新；一天内 no-op，跨天自动换。
- `startPrayer()` 清空 `selectedDeity` + 调用 refresh（会话开始即回到日期轮转主神）。
- 顶部牌与五神阵均依赖 `viewModel.todayDeity`（@Observed），刷新后两处一起更新。

## 6. 改动文件清单

| 文件 | 改动 |
|---|---|
| `engine/DeityRotator.ets` | 新增 `anchorOf(deityId, todayId)` 纯函数 |
| `components/DeityArrayView.ets` | 新增 `@Prop todayId`；`layoutOf` 走 anchorOf 映射 |
| `components/DailyAlmanac.ets` | 整体重写为「主神牌」UI，删 emoji/香火/花色 |
| `viewmodels/PrayerViewModel.ets` | 新增 `refreshTodayDeity()` + 日期缓存；新增 `selectedDeity`/`activeDeity()`/`selectDeity()`；构造/startPrayer 改走 refresh，startPrayer/resetPrayer 清 selectedDeity；`onAnimationComplete`/`saveRecord` 用 activeDeity |
| `pages/NameCard.ets` | 选神写入 `selectDeity()`（不再直接改 todayDeity）；createWish 用 activeDeity |
| `pages/MainTabs.ets` | onPageShow 调 refresh；DeityArrayView 传 todayId=todayDeity.id |
| `pages/PrayerCard.ets` | DeityArrayView 传 todayId/highlightId=activeDeity().id（选神时拜谁谁主位，未选=当日主神）；还愿分支改为 `selectDeity(许愿时的麻神)` |
| `pages/WishWall.ets` | `fulfillWish` 导航携带 `fulfillDeityId: wish.deityId` |
| `pages/HomePage.ets` | DeityArrayView 传 todayId（保持与 MainTabs 一致） |
| `pages/BlessingCard.ets` | 主位令牌改用 activeDeity |

不动：`PrayerTypes.ets`（数据）、`WidgetData/DeityCard2x2`（已一致）、`BlessingEngine`（祝福生成已改走 activeDeity）。

## 7. 验证清单

项目无单测设施，验证方式：`hvigorw assembleApp` 构建通过 + 真机手验：

- [ ] 今日主神（依日期）站在五神阵中央主位，最大、光晕最强；赵公明站在主神原方位锚点
- [ ] 顶部显示「— 今日主麻神 —」+ 名号 + 方位寓意 + 一行黄历，无任何 emoji
- [ ] 进入叩拜页（PrayerCard）：主位与首页一致；完成祝福后 BlessingCard 名字/方位与画面主神一致
- [ ] 选神场景：NameCard 选另一位财神 → PrayerCard 主位/光晕为所选神、BlessingCard 令牌为所选神；回首页后顶部牌与五神阵主位恢复为当日日期主神；「再拜一次」不重选时回到当日主神
- [ ] 还愿场景：许愿当天拜的是 A 神（心愿记录 deityId=A），次日主神轮转为 B → 心愿墙点还愿，PrayerCard 主位/光晕为 A 神（非今日 B）、BlessingCard 令牌为「A · 主位」、磕头记录记 A；还愿完成后回首页主神仍为 B
- [ ] 跨天刷新：改系统日期到次日（或次日自然验证），回到祈福 Tab 主神与顶部牌同步换神；当天多次进出页面主神不变
- [ ] WCAG 扫点：新卡片文字 alpha 达标（金色 ≥0.6/米色 ≥0.5，主神名号实色）
- [ ] 黄历页（FortuneAlmanacPage）不受影响（宜忌/香火数据仍完整）

## 8. 边界与风险

- **跨午夜动画中**：主位在现身时已锁定，不中途换神（可接受，下轮自然刷新）。
- **highlightId 与 todayId 双参数**：同一调用点两值恒相等（PrayerCard 用 activeDeity，首页用 todayDeity），但语义不同（光晕 vs 位置），调用方必须同时传两者——实现时在 DeityArrayView 内不做二选一合并，保持显式。
- **HomePage 与 MainTabs 重复布局**：两页各自渲染五神阵，改动需同步（本次两处都改，长期可考虑收敛，但不在本设计范围）。