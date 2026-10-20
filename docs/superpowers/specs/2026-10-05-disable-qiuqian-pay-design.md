# 暂时下架求签付费（保留免费求签）设计

> 日期：2026-10-05
> 状态：设计已确认（brainstorming 完成：范围 = 只去求签付费，独立打赏不动），待实现计划
> 背景：求签内嵌的「打赏解锁更多次数」（qiu_extra 消耗型 IAP）审核不通过。用户决定**暂时**下架求签的付费部分，保留每日免费 1 签的求签功能；独立的「打赏作者」四档（DonateDialog）**完全不动**。

## 1. 问题现状

求签付费链路（全部指向 qiu_extra 商品 /「打赏作者 · 解锁更多乐趣」话术）：

1. **QiuQian 页**：每日免费 1 签（`FREE_DAILY_QIU`）用完后 → 底部出现「❤️ ¥1 打赏作者」按钮 + `ExtraDrawPaySheet` 支付层（`purchaseExtraDraw` 购买 → `applyExtraDraw` 落账额度 +1 → 云端补记 → 消耗）。
2. **桌面求签卡**（SignCard2x2 / SignCard2x4）：额度用完 → 显示「❤ 打赏」按钮，`postCardAction` 深链 `open:'buy'` 跳 App 弹支付层。
3. **EntryAbility**：`applyDeepLink` 把 `open:'buy'` 写入 `pendingOpenPay`（QiuQian 页据此弹支付层）；另有 qiu_extra **启动补单**（已付未消耗订单，`recoverPending` → 补额度，不可见）。

## 2. 目标与范围

| 项 | 内容 |
|---|---|
| 求签付费 | **全部下架**：支付层 UI、购买流程、卡片打赏按钮与 buy 深链、pendingOpenPay 链路 |
| 免费求签 | **完整保留**：摇一摇抽签、36 签、解签免费、签录、每日免费 1 签 |
| 额度模型 | **保留代码**：`QiuQianViewModel` 的 quota/extra 模型与 `IapPaymentService` 服务不动（恢复时只需把 UI 加回来） |
| 已购未用额度 | **仍可用**：用户此前已付费获得的额外次数照常生效（`grantExtraOnce` 已写入盘内）；`MAX_DAILY_QIU=3` 等判断逻辑不变，只是 UI 不再提供购买入口 |
| 独立打赏 | **完全不动**：DonateDialog 四档、我的页「支持作者」、祈福结算「供奉麻神」、心愿墙打赏引导、公益明细/排行榜、TIP_PRODUCTS 补单 |

**不做**（YAGNI）：删除 qiu_extra 商品配置 / 云函数 `jieqian-unlock` / `recordSignUnlock`；改动 QiuQianViewModel 额度模型；改动打赏任何部分。

## 3. 改动清单

### 3.1 QiuQian.ets（求签页）

**删除（付费专属）：**

- `ExtraDrawPaySheet()` @Builder（含内部 `PayRow` 调用、购买按钮、客服入口、「以后再说」）
- `@State showPaySheet` / `@State paying` / `pendingOpenPay @StorageLink` + `onPendingOpenPay()`
- 方法：`openPaySheet()`、`purchaseExtraDraw()`、`applyExtraDraw()`、`tryRestoreExtra()`、`handleUnlockError()`、`openSupportDialog()`（若仅被支付层使用；`supportDialogController` 字段一并删）
- `aboutToAppear()` 内 `this.onPendingOpenPay()` 调用
- 底部操作区 IDLE 分支的打赏按钮块（`todayUsed >= todayQuota && todayQuota < MAX_DAILY_QIU` → `openPaySheet`）
- `build()` 尾部 `if (this.showPaySheet) { this.ExtraDrawPaySheet() }`
- 相关 import：`EXTRA_DRAW_PRODUCT`、`ExtraDrawResult`、`PaymentError`、`PaymentErrorKind`、`IapPaymentService`、`common`（确认无其他引用后）

**改写（免费额度用尽行为）：**

- `startDraw()`：额度用完分支由「能加购 → 弹支付层」改为**一律** toast「今日体验已达上限 · 明日再来 🙏」（不再调 `canBuyExtra()`）
- `resetDraw()` 尾部：同样去掉 `openPaySheet` 分支
- `idleSubText()`：「今日免费体验已用完 · 打赏作者解锁更多乐趣」→「今日免费次数已用完 · 明日再来 🙏」
- 顶部注释（付费形态说明 7-12 行）更新为「付费已暂时下架」

**保留：** 免费求签全部（摇签/解签/签录/额度判断 `canDraw()`）、`qiuRev` 刷新链路、传感器门控、`pushCards()`（跨天/抽签后刷新卡片额度）。

### 3.2 桌面求签卡（SignCard2x2 / SignCard2x4）

- 「❤ 打赏」按钮分支（`open:'buy'` 深链）→ 改为「明日再来」置灰样式（复用现有「抽满」分支视觉），onClick 仍发 `message draw` 让 FormExtension 重判（跨天自动恢复）
- `drawButtonText()` 的 `'❤ 打赏'` 兜底文案 → `'明日再来'`
- 其余（抽签/解签/额度展示）不动

### 3.3 EntryAbility.ets

- `applyDeepLink()`：删除 `pendingOpenPay` 写入（`open:'buy'` 不再有任何消费方）
- **保留**：qiu_extra 启动补单（`recoverPending`，不可见、保护已付费用户）；`pendingOpenUnlock`（解签免费）；打赏 TIP_PRODUCTS 补单

### 3.4 不动文件

`QiuQianViewModel.ets`、`IapPaymentService.ets`、`IPaymentService.ets`、`CloudService.ets`（`recordSignUnlock`）、`DonateDialog.ets`、`MyPage.ets`、`BlessingCard.ets`、`WishItem.ets`、`DonationDetailPage.ets`、`DonationBoardPage.ets`、`WidgetFormAbility.ets`、`WidgetData.ets`、`PrivacyDialog.ets`。

## 4. 边界与风险

- **已购未用次数**：用户旧版买过但没用完的额外次数继续生效（跨天不重置的已加购部分）；新版本不再有新购买入口，额度自然回落为免费 1 签。
- **卡片快照滞后**：卡片若仍显示旧 quota（如 3），用户把已购额度用完后显示「明日再来」，点击 message draw 由扩展按真实额度重判 —— 与现有「抽满」分支行为一致，无需 App 端兜底。
- **补单保留**：qiu_extra 启动补单不暴露任何付款 UI，只静默补额度，保留是安全的。
- **恢复路径**：仅需把 QiuQian 页支付层 + 卡片 buy 按钮 + EntryAbility buy 解析加回（全部代码仍在 git 历史 / IAP 服务仍在），无需改 VM/服务层。

## 5. 验证清单

项目无单测设施，验证方式：`hvigorw assembleHap` 构建通过 + 真机手验：

- [ ] 求签页每日免费第 1 签可正常摇签/解签；签录、复制、去祈福均正常
- [ ] 免费次数用完后：底部不再出现「打赏作者」按钮，改为「📳 双手持机，摇晃手机出签」提示 + 小字「今日免费次数已用完 · 明日再来」；摇晃不出签、弹 toast「今日体验已达上限 · 明日再来 🙏」
- [ ] 桌面求签卡：有额度正常抽签；额度用完后按钮为「明日再来」（非「❤ 打赏」），不再跳支付层
- [ ] 桌面卡「解签」深链正常（unlock 不受影响）；`open:'buy'` 深链已无消费方（不再弹支付层）
- [ ] 独立打赏全部入口正常：我的页「支持作者 · 打赏」、祈福结算「供奉麻神」、心愿墙打赏引导、公益明细/排行榜
- [ ] 启动无崩溃；构建无未使用 import 告警
- [ ] 恢复路径验证（可选）：确认 QiuQianViewModel/IapPaymentService 未被改动
