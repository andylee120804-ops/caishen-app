# 祈福主位每日轮转 + 顶部主神牌 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 五神阵主位由当日主麻神占据（当天固定、跨天轮换），顶部黄历卡精简为主神突出卡片（去 emoji）。

**Architecture:** 复用已有 `DeityRotator`（按年内天数 `%5` 每日轮换主神），新增纯函数 `anchorOf` 把「神 id → 锚点」做对调映射，`DeityArrayView` 布局由该映射驱动；顶部 `DailyAlmanac` 组件整体重写为主神牌 UI；`PrayerViewModel` 增加按日期缓存的 `refreshTodayDeity()` 消除跨天残留。

**Tech Stack:** HarmonyOS ArkTS（ArkUI 声明式 UI），构建 hvigorw（Node 18 语法兼容，无 npm 依赖）。

**验证策略（本项目无单测设施）:** 每个代码任务后跑一次 ArkTS 编译验证（`assembleHap`，~30-60s）；全部完成后按 Task 6 真机手验清单逐项核对。TDD 单元测试在本仓库无运行环境，逻辑正确性靠编译 + 纯函数映射表自查 + 真机视觉验证兜底。

**构建前置条件（已确认存在）:** 根目录 `package.json` 内容为 `{"type":"commonjs"}` 已存在；hvigorw 用 Bash 直跑 node（勿走 cmd.exe）:

```bash
export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco\sdk"
export JAVA_HOME="C:\Program Files\Huawei\DevEco\jbr"
export PATH="/c/Program Files/Huawei/DevEco/jbr/bin:$PATH"
node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
# 预期: BUILD SUCCESSFUL（~28s），产物 entry/build/default/outputs/default/entry-default-signed.hap
```

---

### Task 1: DeityRotator.anchorOf 对调映射

**Files:**
- Modify: `entry/src/main/ets/engine/DeityRotator.ets`（computerDeityId 之后插入）

- [ ] **Step 1: 新增 anchorOf 静态方法**

用 Edit 在 `computeDeityId` 方法结束后（第 10 行 `}` 之后、`static getTodayDeity` 之前）插入：

```typescript

  /**
   * 主位轮转映射（对调方案）：锚点编号 == 神 id 方位序（1中/2东/3西/4南/5北）。
   * 今日主神站中央主位（锚点1），赵公明暂代主神原方位锚点，其余三路财神守本方位。
   * 纯函数：同一天结果恒定（当天固定），跨天随 todayId 变化（轮换）。
   */
  static anchorOf(deityId: number, todayId: number): number {
    if (deityId === todayId) return 1
    if (deityId === 1) return todayId
    return deityId
  }
```

- [ ] **Step 2: 自查映射表（头脑里过一遍，无需工具）**

todayId=1（赵公明）: 1→1, 2→2, 3→3, 4→4, 5→5（现状不变 ✓）
todayId=3（曹宝，2026-10-05 实值）: 3→1（中路主位 ✓）, 1→3（西路位 ✓）, 2→2, 4→4, 5→5

- [ ] **Step 3: 编译验证**

Run 见文头「构建前置条件」命令。
Expected: `BUILD SUCCESSFUL`（新增纯函数不影响既有编译）。

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/engine/DeityRotator.ets
git commit -m "feat(prayer): DeityRotator.anchorOf 主位对调映射"
```

---

### Task 2: DeityArrayView 按 todayId 映射布局

**Files:**
- Modify: `entry/src/main/ets/components/DeityArrayView.ets`

- [ ] **Step 1: 引入 DeityRotator 并新增 @Prop todayId**

将第 1 行的 import 区改为（在 `DeityView` import 后新增一行）：

```typescript
import { DeityInfo } from '../model/PrayerTypes'
import { DeityView } from './DeityView'
import { DeityRotator } from '../engine/DeityRotator'
```

组件 Props 区（当前第 37-42 行）：

```typescript
@Component
export struct DeityArrayView {
  @Prop deities: DeityInfo[]
  @Prop todayId: number = 1
  @Prop highlightId: number = 1
  @Prop appearProgress: number = 0
  @Prop blessingProgress: number = 0
```

- [ ] **Step 2: layoutOf 走 anchorOf 映射**

将当前 `layoutOf` 实现（第 43-45 行）：

```typescript
  private layoutOf(id: number): DeityLayout {
    return getDeityLayout(id)
  }
```

替换为：

```typescript
  private layoutOf(id: number): DeityLayout {
    // 先做「神 → 锚点」对调映射，再查固定锚点表；
    // 锚点表的坐标/尺寸/现身 delay 不变 → 主位（锚点1）恒先现身、最大、光晕最强
    return getDeityLayout(DeityRotator.anchorOf(id, this.todayId))
  }
```

注意：`appearOf()` 复用 `layoutOf()`，位置与 delay 一起随锚点变化，无需改动。

- [ ] **Step 3: 编译验证**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/components/DeityArrayView.ets
git commit -m "feat(prayer): 五神阵布局由 todayId 驱动，今日主神站主位"
```

---

### Task 3: PrayerViewModel.refreshTodayDeity 跨天刷新

**Files:**
- Modify: `entry/src/main/ets/viewmodels/PrayerViewModel.ets`

- [ ] **Step 1: 模块级日期格式化函数**

在文件顶部 import 区之后（第 16 行 `const MAX_RECENT_NAMES = 5` 之后）插入：

```typescript

/** 本地日期 YYYY-MM-DD（跨天比对基准） */
function dateStrOf(d: Date): string {
  const m: string = (d.getMonth() + 1).toString().padStart(2, '0')
  const day: string = d.getDate().toString().padStart(2, '0')
  return `${d.getFullYear()}-${m}-${day}`
}
```

- [ ] **Step 2: 新增日期缓存字段 + refreshTodayDeity**

在类内 `private blessingEngine: BlessingEngine | null = null` 之后（当前第 28 行附近）插入：

```typescript
  private todayDeityDate: string = ''

  /**
   * 跨天才重算今日主麻神；同一天内 no-op，保证「当天的主神不变」。
   * 顶部主神牌 / 五神阵 / 祝福卡共用 todayDeity（@Observed 属性，赋值即通知 UI）。
   */
  refreshTodayDeity(): void {
    const dateStr = dateStrOf(new Date())
    if (dateStr !== this.todayDeityDate) {
      this.todayDeityDate = dateStr
      this.todayDeity = DeityRotator.getTodayDeity()
    }
  }
```

- [ ] **Step 3: 构造函数与 startPrayer 改走 refresh**

构造函数（第 31-33 行）：

```typescript
  constructor() {
    this.refreshTodayDeity()
  }
```

`startPrayer()`（第 42-45 行）改为：

```typescript
  startPrayer(): void {
    this.currentPhase = PrayerPhase.INPUT_NAME
    this.refreshTodayDeity()
  }
```

- [ ] **Step 4: 编译验证**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/viewmodels/PrayerViewModel.ets
git commit -m "feat(prayer): todayDeity 按日期缓存跨天刷新，当天固定不变"
```

---

### Task 4: DailyAlmanac 重写为主神牌

**Files:**
- Modify: `entry/src/main/ets/components/DailyAlmanac.ets`（整文件替换）

- [ ] **Step 1: 用 Write 整体替换文件内容**

```typescript
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'

/**
 * 祈福 Tab 顶部主神牌：今日主麻神（名号大字 + 方位寓意）为主体，
 * 黄历简信息（农历周 + 宜忌 + 吉位）压缩为一行小字。无 emoji。
 */
@Component
export struct DailyAlmanac {
  @Link enrichVM: EnrichViewModel
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()

  build() {
    Column() {
      Text('— 今日主麻神 —')
        .fontSize(11)
        .fontColor('rgba(249, 202, 36, 0.8)')
        .letterSpacing(4)
        .margin({ bottom: 4 })

      Text(this.viewModel.todayDeity.name)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#f9ca24')

      Text(`${this.viewModel.todayDeity.direction} · ${this.viewModel.todayDeity.mahjongMeaning}`)
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.7)')
        .margin({ top: 4 })

      Divider()
        .strokeWidth(1)
        .color('rgba(249, 202, 36, 0.25)')
        .margin({ top: 10, bottom: 8 })

      Text(`${this.getLunarDate()} · ${this.getWeekday()} ｜ 宜 ${this.enrichVM.getAlmanac().suitable} · 忌 ${this.enrichVM.getAlmanac().avoid} ｜ 吉位 ${this.enrichVM.getAlmanac().direction}`)
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.55)')
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('90%')
    .padding(12)
    .backgroundColor('rgba(192, 57, 43, 0.08)')
    .border({ width: 1, color: 'rgba(249, 202, 36, 0.2)', radius: 10 })
    .position({ x: '50%', y: 48 }) // 避开沉浸式状态栏（时间/电量区域）
    .translate({ x: '-50%', y: '0' })
  }

  private getLunarDate(): string {
    const d: Date = new Date()
    const months: string[] = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月']
    const days: string[] = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十']
    const m: number = ((d.getMonth() + 11) % 12)
    const day: number = ((d.getDate() + 30) % 30)
    return `${months[m]}${days[day]}`
  }

  private getWeekday(): string {
    const days: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    return days[new Date().getDay()]
  }
}
```

删除内容确认：原 `getIncenseBar()`、emoji 模板、宜/忌/中间三列 Row、香火行全部移除（整文件替换即完成）。

- [ ] **Step 2: 编译验证**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 3: Commit**

```bash
git add entry/src/main/ets/components/DailyAlmanac.ets
git commit -m "feat(prayer): 顶部黄历卡精简为主神牌，去 emoji 突出今日主麻神"
```

---

### Task 5: 三处调用点传 todayId + MainTabs 跨天刷新钩子

**Files:**
- Modify: `entry/src/main/ets/pages/MainTabs.ets`
- Modify: `entry/src/main/ets/pages/PrayerCard.ets`
- Modify: `entry/src/main/ets/pages/HomePage.ets`

- [ ] **Step 1: MainTabs — DeityArrayView 传 todayId + onPageShow 刷新**

`BlessingSquare()` 内 DeityArrayView 调用（当前约第 276-282 行）：

```typescript
        DeityArrayView({
          deities: FIVE_DEITIES,
          todayId: this.viewModel.todayDeity.id,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: 1,
          blessingProgress: 0
        })
```

`onPageShow()`（当前第 108-111 行）改为：

```typescript
  onPageShow(): void {
    // 跨天回来刷新今日主神：当天内 no-op，跨天自动换（顶部主神牌+五神阵一起更新）
    this.viewModel.refreshTodayDeity()
    const activeId = this.activeIdOf(this.currentTab)
    AppStorage.setOrCreate('activeEntryId', activeId)
  }
```

- [ ] **Step 2: PrayerCard — DeityArrayView 传 todayId**

`build()` 内 DeityArrayView 调用（当前约第 287-292 行）：

```typescript
        DeityArrayView({
          deities: FIVE_DEITIES,
          todayId: this.viewModel.todayDeity.id,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: this.appearProgress,
          blessingProgress: this.blessingProgress
        })
```

（`startPrayer()` 已走 refresh：进入叩拜页前主神已锁定当天值，APPEAR 后中途不变。）

- [ ] **Step 3: HomePage — DeityArrayView 传 todayId**

`build()` 内 DeityArrayView 调用（当前约第 62-68 行）：

```typescript
        DeityArrayView({
          deities: FIVE_DEITIES,
          todayId: this.viewModel.todayDeity.id,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: 1,
          blessingProgress: 0
        })
```

- [ ] **Step 4: 编译验证**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 5: Commit**

```bash
git add entry/src/main/ets/pages/MainTabs.ets entry/src/main/ets/pages/PrayerCard.ets entry/src/main/ets/pages/HomePage.ets
git commit -m "feat(prayer): 三页五神阵接入 todayId，回前台跨天自动刷新主神"
```

---

### Task 6: 全量构建 + 真机手验

**Files:** 无（验证任务）

- [ ] **Step 1: 全量 debug 构建**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`，产物 `entry/build/default/outputs/default/entry-default-signed.hap`。

可选真机安装（USB 连 Pura X，hdc 在 SDK toolchains）:

```bash
"C:/Program Files/Huawei/DevEco/sdk/default/openharmony/toolchains/hdc.exe" install -r entry/build/default/outputs/default/entry-default-signed.hap
```

- [ ] **Step 2: 真机手验清单（逐项勾选）**

今日主神按日期计算（2026-10-05 → 曹宝，用 node 速算佐证：`((dayOfYear-1)%5)+1`）:

- [ ] 祈福 Tab：曹宝站在五神阵中央主位（最大、金色光晕最强），赵公明站西路锚点、其余三路守本位；顶部主神牌显示「— 今日主麻神 — 曹宝 / 西路 · 纳珍入库，攒好牌型 / 一行黄历小字」，**无任何 emoji**
- [ ] 点「开始祈福」→ 叩拜页（PrayerCard）主位与首页一致，现身动画主位最先出现
- [ ] 完成祈福 → 祝福卡主位令牌名字/方位与画面主神一致（曹宝 · 西路主位）
- [ ] 当天内多次进出祈福页：主神不变（当天固定 ✓）
- [ ] 跨天刷新：把系统日期改到次日 → 回祈福 Tab：主神与顶部牌同步换神（次日 = 陈九公）；改回当天日期恢复正常
- [ ] WCAG 扫点：主神名号实色 #f9ca24 ✓；顶部牌各辅助文字 alpha 符合规范（金 0.8、米色 0.7/0.55 均 ≥ 门槛）✓
- [ ] 黄历页（FortuneAlmanacPage）不受影响：宜忌/香火数据完整
- [ ] 桌面「今日主麻神」卡与 App 主神一致（同 DeityRotator）

- [ ] **Step 3: 若手验发现问题，修复后在对应任务文件上再 commit；全部通过则完成**

```bash
git status   # 确认工作区仅剩用户原有改动，本计划新增修改全部已提交
```

---

## Self-Review 记录（计划书自我检查）

- **Spec coverage**: spec §3 轮转 → Task 1/2/5；§4 主神牌 → Task 4；§5 跨天刷新 → Task 3/5；§6 文件清单 7 个文件全部落入 Task 1-5；§7 验证清单 → Task 6。无遗漏。
- **Placeholder scan**: 无 TBD/TODO；每步均有完整代码与命令。
- **Type consistency**: `anchorOf(deityId: number, todayId: number): number` 在 Task 1 定义、Task 2 引用一致；`@Prop todayId: number = 1` 三处调用传 `viewModel.todayDeity.id` 一致；`refreshTodayDeity()` 在 Task 3 定义、Task 5 调用一致；`dateStrOf` 模块级函数 Task 3 定义即使用。
- **注意**: `PrayerViewModel` 类顶部需确认 `todayDeity` 声明保持 `@Observed` 类属性（未改，Task 3 只加缓存字段）。`todayDeity` 是类字段赋值（非 @State），靠 @Observed 类 + @StorageLink 通知 UI——既有机制，Task 3 注释已说明。