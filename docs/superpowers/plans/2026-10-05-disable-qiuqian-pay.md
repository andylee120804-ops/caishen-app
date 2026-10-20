# 暂时下架求签付费（保留免费求签）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 下架求签内嵌的付费（qiu_extra「打赏作者 · 解锁更多乐趣」），每日免费 1 签保持不变；独立的四档打赏（DonateDialog）与额度模型/服务代码全部保留。

**Architecture:** 只删 UI 不动逻辑——移除 QiuQian 页的支付层与购买流程、桌面求签卡的「❤ 打赏」按钮与 `open:'buy'` 深链、EntryAbility 的 `pendingOpenPay` 解析；`QiuQianViewModel` / `IapPaymentService` / `IPaymentService` / `CloudService.recordSignUnlock` 一律不动（恢复时只需把 UI 加回）。qiu_extra 启动补单（EntryAbility 101-125 行）保留（不可见、保护已付费用户）。

**Tech Stack:** HarmonyOS ArkTS（ArkUI 声明式 UI），构建 hvigorw（Node 18 语法兼容，无 npm 依赖）。

**验证策略（本项目无单测设施）:** 每个代码任务后跑一次 ArkTS 编译验证（`assembleHap`，~30-60s）；全部完成后按 Task 4 真机手验清单逐项核对。

**构建前置条件（已确认存在）:** 根目录 `package.json` 内容为 `{"type":"commonjs"}` 已存在；hvigorw 用 Bash 直跑 node（勿走 cmd.exe）:

```bash
export DEVECO_SDK_HOME="C:\Program Files\Huawei\DevEco\sdk"
export JAVA_HOME="C:\Program Files\Huawei\DevEco\jbr"
export PATH="/c/Program Files/Huawei/DevEco/jbr/bin:$PATH"
node hvigorw.js --mode module -p product=default -p buildMode=debug --no-daemon assembleHap
# 预期: BUILD SUCCESSFUL（~30s），产物 entry/build/default/outputs/default/entry-default-signed.hap
```

**编辑工具说明:** 以下 Edit 全部用精确 old_string 匹配（QiuQian.ets 行号会随编辑前移，勿依赖行号；每段 old_string 在文件中唯一）。

---

### Task 1: QiuQian.ets — 移除支付层与购买流程

**Files:**
- Modify: `entry/src/main/ets/pages/QiuQian.ets`

- [ ] **Step 1: 更新文件头注释（付费形态说明）**

old:
```typescript
// 付费形态（2026-10-04 审核整改：对外一律表述为「打赏作者」）：
//   · 解签全文、签运速览、今日建议 → **永久免费**，详情页没有任何付费墙；
//   · 对外口径：当日免费体验用完后，入口与弹层一律写成「❤️ 打赏作者 · 解锁更多乐趣」，
//     界面上**不出现**「增加次数 / 购买次数 / ¥1 换一签」等表述，话术与 DonateDialog
//     保持一致（对开发者的自愿赠与、用于后续开发与维护、不承诺任何效果）；
//   · 后台实现：打赏成功回调 grantExtraOnce() → 当日额度 +1（每日最多 MAX_EXTRA_QIU 次，
//     总额度上限 MAX_DAILY_QIU 签，跨天自动重置）。
```
new:
```typescript
// 付费形态（2026-10-05 起暂时下架）：求签付费（打赏解锁更多次数，qiu_extra）审核不通过
// 已下架，恢复时只需把支付层 UI 加回（QiuQianViewModel 额度模型 / IapPaymentService 未动）。
//   · 解签全文、签运速览、今日建议 → **永久免费**，详情页没有任何付费墙；
//   · 每日免费第 1 签，用完后提示「明日再来」，不再出现任何付费入口。
```

- [ ] **Step 2: 清理 imports**

逐个 Edit（每个 old_string 唯一）：

a) old:
```typescript
import { QiuQianViewModel, MAX_DAILY_QIU, FREE_DAILY_QIU, MAX_EXTRA_QIU } from '../viewmodels/QiuQianViewModel'
```
new:
```typescript
import { QiuQianViewModel, FREE_DAILY_QIU } from '../viewmodels/QiuQianViewModel'
```

b) 删除整行 `import { ContactSupportDialog } from '../components/ContactSupportDialog'`

c) old:
```typescript
import { pasteboard, BusinessError } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { router } from '@kit.ArkUI'
import { sensor, vibrator } from '@kit.SensorServiceKit'
import { IapPaymentService } from '../service/IapPaymentService'
import { PaymentError, PaymentErrorKind, ExtraDrawResult, EXTRA_DRAW_PRODUCT } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'
```
new:
```typescript
import { pasteboard } from '@kit.BasicServicesKit'
import { router } from '@kit.ArkUI'
import { sensor, vibrator } from '@kit.SensorServiceKit'
```

- [ ] **Step 3: 删除支付相关字段**

a) 删除（含上面注释行）:
```typescript
  /** 桌面卡片「继续畅玩」深链（open:'buy'）：打开「打赏作者 · 解锁更多乐趣」弹层 */
  @StorageLink('pendingOpenPay') @Watch('onPendingOpenPay') pendingOpenPay: boolean = false
```

b) 删除:
```typescript
  @State showPaySheet: boolean = false     // 「打赏作者 · 解锁更多乐趣」弹层
  @State paying: boolean = false           // 打赏支付进行中（防重入 + 驱动按钮态）
  private supportDialogController: CustomDialogController | null = null  // 联系客服弹窗（惰性创建）
  private restoreCheckDone: boolean = false  // 本页会话内只做一次补单恢复检查
```

- [ ] **Step 4: aboutToAppear 删除 onPendingOpenPay 调用**

old:
```typescript
    // 冷启动深链：flag 在本页创建前已写入，@Watch 不会触发，这里补一次
    this.onPendingOpenUnlock()
    this.onPendingOpenPay()
```
new:
```typescript
    // 冷启动深链：flag 在本页创建前已写入，@Watch 不会触发，这里补一次
    this.onPendingOpenUnlock()
```

- [ ] **Step 5: 删除 onPendingOpenPay 方法（含文档注释）**

删除从 `  /** 卡片「继续畅玩」深链到站：直接打开打赏弹层（不让用户再点一次） */` 开始到 `  }`（其方法体结尾，含 `      this.openPaySheet()` 与 `    })`、`  }`）的整段。可用如下 old_string 精确删除：

old:
```typescript
  /** 卡片「继续畅玩」深链到站：直接打开打赏弹层（不让用户再点一次） */
  onPendingOpenPay(): void {
    if (!this.pendingOpenPay) {
      return
    }
    // 消费后清空，避免下次回前台/切 Tab 重复弹
    this.pendingOpenPay = false
    console.info('[IapDraw] pay deeplink arrived, wait vm ready')
    // 必须等额度读盘完成：冷启动时 initialize() 还在飞，此刻 daily.count 是 0，
    // 会把「今日已抽完」误判成「还能抽」而不弹付款窗 —— 也就是用户反馈的
    // 「进了初始界面还要自己再点一次才弹窗」。
    QiuQianViewModel.awaitInit().then((): void => {
      if (this.leaving) {
        return
      }
      // 深链来自卡片快照，可能滞后于本机真实额度（App 里刚买过次数但卡片没刷到）。
      // 真实额度还够 → 绝不重复收钱，回到待摇界面等用户摇
      if (this.qiuVM.canDraw()) {
        this.syncFromVM()
        this.resetDraw()
        return
      }
      this.openPaySheet()
    })
  }
```

- [ ] **Step 6: startDraw 额度用完分支去掉弹支付层**

old:
```typescript
    if (!this.qiuVM.canDraw()) {
      // 今日额度用完：还能打赏 → 弹「打赏作者」；已到上限 → 提示明日再来（均不进入动画）
      this.vibrate(80)
      this.syncFromVM()
      if (this.qiuVM.canBuyExtra()) {
        this.openPaySheet()
      } else {
        this.toast('今日体验已达上限 · 明日再来 🙏')
      }
      return
    }
```
new:
```typescript
    if (!this.qiuVM.canDraw()) {
      // 今日免费额度用完（付费加购已下架）：提示明日再来，不进入动画
      this.vibrate(80)
      this.syncFromVM()
      this.toast('今日体验已达上限 · 明日再来 🙏')
      return
    }
```

- [ ] **Step 7: resetDraw 尾部去掉弹支付层**

old:
```typescript
    // 回到待求签态后：额度已用完时直接给出下一步（还能打赏 → 弹打赏层；已到上限 → 提示）
    if (!this.qiuVM.canDraw()) {
      if (this.qiuVM.canBuyExtra()) {
        this.openPaySheet()
      } else {
        this.toast('今日体验已达上限 · 明日再来 🙏')
      }
    }
```
new:
```typescript
    // 回到待求签态后：额度已用完时直接提示明日再来（付费加购已下架）
    if (!this.qiuVM.canDraw()) {
      this.toast('今日体验已达上限 · 明日再来 🙏')
    }
```

- [ ] **Step 8: 底部操作区 IDLE 分支去掉打赏按钮**

old:
```typescript
        if (this.phase === QiuPhase.IDLE) {
          if (this.todayUsed >= this.todayQuota && this.todayQuota < MAX_DAILY_QIU) {
            // 今日免费体验已用完 → 给「打赏作者 · 解锁更多乐趣」入口
            // （对外一律打赏话术；解签本身永远免费，这里不卖次数）
            Text('❤️')
              .fontSize(26)
            Button(`❤️ ¥${EXTRA_DRAW_PRODUCT.amount} 打赏作者`)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .backgroundColor('#f9ca24')
              .borderRadius(22)
              .width('76%')
              .margin({ top: 10 })
              .padding({ top: 11, bottom: 11 })
              .onClick((): void => { this.openPaySheet() })
          } else {
            // 无按钮：仅摇晃出签
            Text('📳')
              .fontSize(26)
            Text('双手持机，摇晃手机出签')
              .fontSize(13)
              .fontColor('rgba(249, 202, 36, 0.75)')
              .margin({ top: 8 })
          }
```
new:
```typescript
        if (this.phase === QiuPhase.IDLE) {
          // 无按钮：仅摇晃出签（付费加购已下架，不再出现「打赏作者」按钮）
          Text('📳')
            .fontSize(26)
          Text('双手持机，摇晃手机出签')
            .fontSize(13)
            .fontColor('rgba(249, 202, 36, 0.75)')
            .margin({ top: 8 })
```

- [ ] **Step 9: build() 删除支付层渲染**

删除:
```typescript
      // 打赏作者弹层（今日免费额度用完后出现；对外是打赏话术，不出现「购买次数」）
      if (this.showPaySheet) {
        this.ExtraDrawPaySheet()
      }
```

- [ ] **Step 10: 删除 ExtraDrawPaySheet + PayRow 两个 @Builder**

删除从 `  /**` 开头（`「打赏作者 · 解锁更多乐趣」弹层` 的文档注释）到 PayRow builder 结尾 `  }` 的整段（含 `ExtraDrawPaySheet()` 与 `PayRow()` 两个 builder 及中间全部内容）。可用如下 old_string（首尾锚定）精确删除：

old:
```typescript
  /**
   * 「打赏作者 · 解锁更多乐趣」弹层（对外一律打赏话术，界面不出现「增加/购买次数」）。
   * 文案要点（合规 + 用户预期管理）：
   *   ① 明说是**对开发者的自愿赠与**，款项用于应用后续开发与维护；
   *   ② 打赏后解锁今日更多玩法（后台仍是额度 +1，每日最多 MAX_EXTRA_QIU 次，跨天重置）；
   *   ③ 不承诺任何效果：签文由随机算法生成，仅供娱乐，不作为任何决策依据。
   */
  @Builder
  ExtraDrawPaySheet() {
```
…（中间 70 余行整段）…
```typescript
  /** 购买弹层内的一行说明（图标 + 标题 + 副标题） */
  @Builder
  PayRow(icon: string, title: string, sub: string) {
    Row() {
      Text(icon)
        .fontSize(16)
      Column() {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('rgba(253, 246, 227, 0.9)')
        Text(sub)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.55)')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 10 })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 7, bottom: 7 })
  }
```

> 实操提示：把 `@Builder\n  ExtraDrawPaySheet() {` 到 `  PayRow(...) { ... }` 结束 `  }` 之间的整段替换为空。若担心超长 old_string 出错，可分两次 Edit：先删 `ExtraDrawPaySheet`（从注释 `  /**\n   * 「打赏作者 · 解锁更多乐趣」弹层` 到其结尾 `  }`），再删 `PayRow`（从 `  /** 购买弹层内的一行说明` 到其结尾 `  }`），但须保证每次 old_string 唯一。

- [ ] **Step 11: 签录覆层今日计数改用 todayQuota**

old:
```typescript
          Text(`今日已求 ${this.todayUsed}/${MAX_DAILY_QIU} 签`)
```
new:
```typescript
          Text(`今日已求 ${this.todayUsed}/${this.todayQuota} 签`)
```

- [ ] **Step 12: 删除支付方法块（openPaySheet / tryRestoreExtra / purchaseExtraDraw / openSupportDialog / applyExtraDraw / handleUnlockError）**

从 `  /** 打开「打赏作者 · 解锁更多乐趣」弹层（今日免费额度用完时） */` 到 `handleUnlockError` 结尾 `  }` 整段删除（约 150 行：openPaySheet、tryRestoreExtra、purchaseExtraDraw、openSupportDialog、applyExtraDraw、handleUnlockError 六个方法）。锚定 old_string 首尾：

old 开头:
```typescript
  /** 打开「打赏作者 · 解锁更多乐趣」弹层（今日免费额度用完时） */
  private openPaySheet(): void {
    this.syncFromVM()
    this.showPaySheet = true
    this.tryRestoreExtra()
  }
```
old 结尾:
```typescript
  private handleUnlockError(err: Object): void {
    if (err instanceof PaymentError) {
      const pe = err as PaymentError
      if (pe.kind === PaymentErrorKind.NEED_LOGIN) {
        // 与供奉弹窗同款 v1 指引：系统设置登录（LoginWithHuaweiID 引导留 v2）
        this.toast('需要登录华为帐号，请在系统设置中登录后重试')
      } else if (pe.kind === PaymentErrorKind.ALREADY_OWNED) {
        // 消耗型同商品有未完成订单（上次购买成功未消耗）：重置恢复标记走补单恢复
        this.restoreCheckDone = false
        this.tryRestoreExtra()
      } else {
        this.toast(pe.message)
      }
      console.error('[QiuQian] unlock error: kind=' + pe.kind + ' code=' + pe.rawCode)
      return
    }
    const e = err as BusinessError
    console.error('[QiuQian] unlock error: code=' + e.code + ' msg=' + e.message)
    this.toast('购买失败请重试')
  }
```
（中间方法块：tryRestoreExtra / purchaseExtraDraw / openSupportDialog / applyExtraDraw 全部在区间内。整段替换为空。）

- [ ] **Step 13: idleSubText 去掉打赏话术**

old:
```typescript
  private idleSubText(): string {
    if (this.todayUsed >= this.todayQuota) {
      return this.todayQuota < MAX_DAILY_QIU
        ? '今日免费体验已用完 · 打赏作者解锁更多乐趣'
        : `今日已体验 ${MAX_DAILY_QIU} 签 · 明日再来 🙏`
    }
    if (this.todayUsed > 0) {
      return `今日已体验 ${this.todayUsed}/${this.todayQuota} 签 · 解签免费看`
    }
    return '每日第 1 签免费 · 解签全文免费查看'
  }
```
new:
```typescript
  private idleSubText(): string {
    if (this.todayUsed >= this.todayQuota) {
      return `今日已体验 ${this.todayQuota} 签 · 明日再来 🙏`
    }
    if (this.todayUsed > 0) {
      return `今日已体验 ${this.todayUsed}/${this.todayQuota} 签 · 解签免费看`
    }
    return '每日第 1 签免费 · 解签全文免费查看'
  }
```

- [ ] **Step 14: 编译验证**

Run 见文头「构建前置条件」命令。
Expected: `BUILD SUCCESSFUL`，且无 `unused import` / 未定义符号报错。

- [ ] **Step 15: Commit**

```bash
git add entry/src/main/ets/pages/QiuQian.ets
git commit -m "feat(qiuqian): 下架求签付费（支付层/购买流程移除，免费求签保留）"
```

---

### Task 2: 桌面求签卡 — 打赏按钮改「明日再来」

**Files:**
- Modify: `entry/src/main/ets/widget/pages/SignCard2x2.ets`
- Modify: `entry/src/main/ets/widget/pages/SignCard2x4.ets`

- [ ] **Step 1: SignCard2x2 — drawButtonText 兜底文案**

old:
```typescript
    return '❤ 打赏'
```
new:
```typescript
    return '明日再来'
```

- [ ] **Step 2: SignCard2x2 — 「❤ 打赏」按钮分支改置灰「明日再来」**

old:
```typescript
    } else if (this.used >= this.quotaCell()) {
      // 今日免费额度用完：跳到 App 的打赏弹层（与卡片话术一致）。
      // App 端会用真实额度复核，快照滞后时不会重复打赏，而是直接把这一签摇出来。
      Text('❤ 打赏')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(14)
        .height(30)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility',
            params: { route: 'qiuqian', open: 'buy' }
          })
        })
```
new:
```typescript
    } else if (this.used >= this.quotaCell()) {
      // 今日免费额度用完：付费加购已下架，显示「明日再来」置灰
      // （点击发 message draw 由扩展按真实额度重判，跨天自动恢复）
      Text('明日再来')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .backgroundColor('rgba(249, 202, 36, 0.08)')
        .border({ width: 1, color: 'rgba(249, 202, 36, 0.18)' })
        .borderRadius(14)
        .height(30)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: 'message',
            params: { msgAction: 'draw', form: 'sign_2x2' }
          })
        })
```

- [ ] **Step 3: SignCard2x2 — 文件头注释更新**

old:
```typescript
// 抽签按钮：有额度走 message draw（扩展真抽）；额度用完直接 router 到「打赏作者」弹层，
// 真正的付费校验在 App 端用真实额度复核，避免卡片快照滞后导致重复收费。
```
new:
```typescript
// 抽签按钮：有额度走 message draw（扩展真抽）；额度用完显示「明日再来」（付费加购已下架）。
```

- [ ] **Step 4: SignCard2x4 — drawButtonText 兜底文案**

old:
```typescript
    return '❤ 打赏'
```
new:
```typescript
    return '明日再来'
```

- [ ] **Step 5: SignCard2x4 — 「❤ 打赏」按钮分支改置灰「明日再来」**

old:
```typescript
    } else if (this.used >= this.quotaCell()) {
      // 今日免费额度用完：跳到 App 的打赏弹层（与卡片话术一致）。
      // 是否真的需要打赏由 App 用真实额度复核：万一快照滞后（已在 App 打赏过），
      // App 不会重复打赏，而是直接把这一签摇出来。
      Text('❤ 打赏')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#f9ca24')
        .borderRadius(20)
        .height(40)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility',
            params: { route: 'qiuqian', open: 'buy' }
          })
        })
```
new:
```typescript
    } else if (this.used >= this.quotaCell()) {
      // 今日免费额度用完：付费加购已下架，显示「明日再来」置灰
      // （点击发 message draw 由扩展按真实额度重判，跨天自动恢复）
      Text('明日再来')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .backgroundColor('rgba(249, 202, 36, 0.08)')
        .border({ width: 1, color: 'rgba(249, 202, 36, 0.18)' })
        .borderRadius(20)
        .height(40)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          postCardAction(this, {
            action: 'message',
            params: { msgAction: 'draw', form: 'sign_2x4' }
          })
        })
```

- [ ] **Step 6: SignCard2x4 — 注释更新**

old:
```typescript
   *   额度用完 → 跳到 App 的「打赏作者 · 解锁更多乐趣」弹层（对外打赏话术，不写付费买次数；
   *             打赏后 App 会立刻把新额度推回卡片，再点就是上面的「直接出签」）。
```
new:
```typescript
   *   额度用完 → 显示「明日再来」置灰（付费加购已下架；点击重判，跨天自动恢复）。
```

- [ ] **Step 7: 编译验证**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 8: Commit**

```bash
git add entry/src/main/ets/widget/pages/SignCard2x2.ets entry/src/main/ets/widget/pages/SignCard2x4.ets
git commit -m "feat(qiuqian): 桌面求签卡打赏按钮改「明日再来」，不再跳支付层"
```

---

### Task 3: EntryAbility — 移除 pendingOpenPay 深链解析

**Files:**
- Modify: `entry/src/main/ets/entryability/EntryAbility.ets`

- [ ] **Step 1: onCreate 删除 pendingOpenPay 初始化**

old:
```typescript
    AppStorage.setOrCreate('pendingRoute', '')
    AppStorage.setOrCreate('pendingOpenUnlock', false)
    // 桌面卡片「❤ 打赏」深链（open:'buy'）的目标标记
    AppStorage.setOrCreate('pendingOpenPay', false)
```
new:
```typescript
    AppStorage.setOrCreate('pendingRoute', '')
    AppStorage.setOrCreate('pendingOpenUnlock', false)
```

- [ ] **Step 2: applyDeepLink 删除 pendingOpenPay 写入**

old:
```typescript
    const open: Object = params['open']
    AppStorage.setOrCreate('pendingOpenUnlock', open === 'unlock')
    // 新增：open:'buy' → 桌面卡片「❤ 打赏」深链，打开「打赏作者 · 解锁更多乐趣」弹层
    AppStorage.setOrCreate('pendingOpenPay', open === 'buy')
```
new:
```typescript
    const open: Object = params['open']
    // open:'buy'（求签打赏加购）已随付费下架：深链不再解析（卡片也不再发）
    AppStorage.setOrCreate('pendingOpenUnlock', open === 'unlock')
```

- [ ] **Step 3: 编译验证**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`。

- [ ] **Step 4: Commit**

```bash
git add entry/src/main/ets/entryability/EntryAbility.ets
git commit -m "feat(qiuqian): EntryAbility 移除 pendingOpenPay 深链解析（保留补单）"
```

---

### Task 4: 全量构建 + 真机手验

**Files:** 无（验证任务）

- [ ] **Step 1: 全量 debug 构建**

Run 见文头命令。Expected: `BUILD SUCCESSFUL`，产物 `entry/build/default/outputs/default/entry-default-signed.hap`。

可选真机安装（USB 连 Pura X，hdc 在 SDK toolchains）:

```bash
"C:/Program Files/Huawei/DevEco/sdk/default/openharmony/toolchains/hdc.exe" install -r entry/build/default/outputs/default/entry-default-signed.hap
```

- [ ] **Step 2: 真机手验清单（逐项勾选）**

- [ ] 求签页每日免费第 1 签可正常摇签/解签；签录、复制、去祈福均正常
- [ ] 免费次数用完后：底部不再出现「打赏作者」按钮，改为「📳 双手持机，摇晃手机出签」提示 + 小字「今日已体验 1 签 · 明日再来 🙏」；摇晃不出签、弹 toast「今日体验已达上限 · 明日再来 🙏」
- [ ] 桌面求签卡：有额度正常抽签；额度用完后按钮为「明日再来」（非「❤ 打赏」），点击不跳支付层
- [ ] 桌面卡「解签」深链正常（unlock 不受影响）
- [ ] 独立打赏全部入口正常：我的页「支持作者 · 打赏」、祈福结算「供奉麻神」、心愿墙打赏引导、公益明细/排行榜
- [ ] 启动无崩溃；hvigor 无未使用 import 告警
- [ ] `git status` 确认工作区仅剩用户原有未提交改动，本计划新增修改全部已提交

- [ ] **Step 3: 若手验发现问题，修复后在对应任务文件上再 commit；全部通过则完成**

---

## Self-Review 记录（计划书自我检查）

- **Spec coverage**: spec §3.1 QiuQian → Task 1（支付层/购买/深链/文案全删，免费额度行为改）；§3.2 桌面卡 → Task 2；§3.3 EntryAbility → Task 3；§3.4 不动文件 → 无任务触碰；§4 边界（补单保留、已购额度可用）→ Task 3 保留 EntryAbility 101-125 补单、QiuQianViewModel/IapPaymentService 未动；§5 验证 → Task 4。无遗漏。
- **Placeholder scan**: 无 TBD/TODO；每步有完整 old/new 代码与命令。Step 10/12 超长删除用「首尾锚定 + 分次删除」实操提示兜底，非占位。
- **Type consistency**: `openPaySheet` / `purchaseExtraDraw` / `applyExtraDraw` / `tryRestoreExtra` / `handleUnlockError` / `onPendingOpenPay` / `ExtraDrawPaySheet` / `PayRow` / `showPaySheet` / `paying` / `pendingOpenPay` / `supportDialogController` / `restoreCheckDone` / `MAX_EXTRA_QIU` / `MAX_DAILY_QIU` / `EXTRA_DRAW_PRODUCT` / `ExtraDrawResult` / `PaymentError` / `PaymentErrorKind` / `IapPaymentService` / `common` / `BusinessError` / `ContactSupportDialog` / `CloudService` —— 以上标识符在 Task 1 中被删除/清理的所有引用点均已覆盖（字段、调用、import、builder、方法）。`MAX_DAILY_QIU` 原用于 557/1117/1458/1460 四处，557 删除、1117/1460 改 `todayQuota` → import 一并移除；`FREE_DAILY_QIU` 仍用于 `todayQuota` 初值（108 行），保留。`qiuRev`/`syncFromVM`/`pushCards`/`onQiuRev` 保留（Task 1 未触碰）。
- **注意**: 卡片 `quotaCell()`/`max` 语义未改（用户旧版已购额度仍可继续用，用完才显示「明日再来」），与 spec §4 一致。
