// entry/src/main/ets/components/DonateDialog.ets
// 打赏入口弹窗（我的页「支持作者 · 打赏」）：多档金额 + 华为 IAP 在线支付。
//
// 文案约定（合规关键，改动前请先读 docs/superpowers/specs/2026-09-27-jieqian-unlock-design.md）：
// 1) 打赏是「对开发者的自愿赠与」，必须写明用于后续开发和维护，**不承诺任何祈福效果、
//    不解锁任何权益**（否则会被判封建迷信类的应用内付款而拒审）；
// 2) 金额档位 = IAP 消耗型商品 tip_8 / tip_18_2 / tip_88_2 / tip_188 / tip_888（见 IPaymentService.TIP_PRODUCTS），
//    付款成功后必须 finishPurchase 消耗，否则同档再买会被 1001860051 拦截；
// 3) 公益部分写到小字：打赏所得的一部分捐赠给联合国儿童基金会（UNICEF），明细在
//    pages/DonationDetailPage 公示。
//
// WCAG（规则 common/wcag-contrast.md，弹窗底 #580E15）：#FFD700 仅用于大字/实底钮，
// 正文米色 alpha≥0.75（0.5→4.17、0.55→4.77 均不达标或过近），金色 alpha≥0.75（0.6→4.30 ✗）。
//
// ⚠️ 生命周期红线（2026-10-20 闪退事故）：拉起华为收银台前**必须先关闭本弹窗**。
// 应用退到后台时 ArkUI 会自动销毁 CustomDialog；用户取消支付回前台后，旧弹窗已不存在，
// 此时再写 @State / 调用 controller.close() 会命中已销毁组件直接闪退（用户实测：点取消→闪退）。
// 因此支付流程全部放在模块级 runTipFlow 中，只使用入参（HostContext / toast / onSuccess），
// 绝不访问 this 的组件状态。
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { IapPaymentService } from '../service/IapPaymentService'
import { CloudService } from '../service/CloudService'
import { TIP_PRODUCTS, TipProduct, ExtraDrawResult, PaymentError, PaymentErrorKind } from '../service/IPaymentService'

/** 由华为返回的 productId 反查本地档位（recover 补单路径用） */
function productById(productId: string): TipProduct {
  for (const p of TIP_PRODUCTS) {
    if (p.productId === productId) {
      return p
    }
  }
  return TIP_PRODUCTS[0]
}

/** 轻提示函数（UIContext 属于 Ability 窗口，弹窗销毁后依旧可用） */
type ToastFn = (msg: string) => void

/** 统一错误日志：Error 的 message/stack 是不可枚举属性，JSON.stringify 会得到 {}，必须单独取 */
function logError(tag: string, err: Object): void {
  try {
    if (err instanceof Error) {
      const e = err as Error
      console.error('[Donate] ' + tag + ': ' + e.message + '\n' + (e.stack || ''))
      return
    }
    console.error('[Donate] ' + tag + ': ' + JSON.stringify(err))
  } catch (e) {
    console.error('[Donate] ' + tag + ': <unserializable error>')
  }
}

/**
 * 落账：打赏无本地权益，只需感谢 + 记账 + 消耗（失败项都不阻塞，均有补单兜底）。
 * ⚠️ 模块级函数：支付流程运行期间弹窗可能已被销毁，绝不能访问组件成员（@State/this.controller）。
 */
async function completeTip(iap: IapPaymentService, result: ExtraDrawResult, thanks: boolean,
  toast: ToastFn): Promise<void> {
  if (thanks) {
    toast('感谢您的打赏 · 心意已收 🙏')
  }
  // ① 云端记账 → 公益排行榜数据源。金额由服务端按商品白名单算（防篡改），
  //    purchaseToken 做幂等键，重复上报（含补单路径）不会双记。
  //    ⚠️ 顺序不能反：必须「先记账、后消耗」——先消耗的话订单就从
  //    queryPurchases(UNFINISHED) 里消失了，记账失败再无补单机会（钱到华为侧，
  //    榜上却没记录）。故这里 await，失败也照常继续（下次进入自动补单重放）。
  try {
    const recorded: boolean = await CloudService.recordDonation({
      productId: result.productId,
      purchaseToken: result.purchaseToken,
      purchaseData: result.purchaseData,
      orderId: result.orderId
    })
    if (!recorded) {
      console.error('[Donate] recordDonation failed（本次暂不计入公益榜，下次进入自动补单）')
    }
  } catch (err) {
    logError('recordDonation threw', err as Object)
  }
  // ② 消耗商品（同档下次还能再买）；失败留 recoverTipPending 补单
  try {
    await iap.consume(result)
  } catch (err) {
    logError('consume failed（下次进入自动补单）', err as Object)
  }
}

/** 前置错误按 kind 给可行动提示，其余笼统兜底（避免把华为错误码甩给用户） */
function reportPayError(err: Object, toast: ToastFn): void {
  if (err instanceof PaymentError) {
    const pe = err as PaymentError
    if (pe.kind === PaymentErrorKind.NEED_LOGIN) {
      toast('请先登录华为帐号后打赏')
      return
    }
    if (pe.kind === PaymentErrorKind.REGION) {
      toast('当前地区暂不支持打赏')
      return
    }
    if (pe.kind === PaymentErrorKind.PRODUCT) {
      toast('该档位准备中，请稍后再来')
      return
    }
    if (pe.kind === PaymentErrorKind.ALREADY_OWNED) {
      // 注意：购买前的 recoverTipPending 已经查过未完成订单，走到这里说明那一次没查到
      // （华为侧同步延迟）。真实补单发生在下次启动/再次打赏时，别谎称「已恢复」。
      toast('有未完成的打赏订单，稍后会自动补单')
      return
    }
  }
  let code: number = -1
  if (err !== undefined && err !== null) {
    const e = err as BusinessError
    if (typeof e.code === 'number') {
      code = e.code
    }
  }
  logError('purchase failed: code=' + code, err)
  toast('打赏失败，请稍后重试')
}

/** 成功回调（页面闭包）：异常只记日志，不能把它当成支付失败去提示用户 */
function notifySuccess(onSuccess: ((product: TipProduct) => void) | undefined,
  product: TipProduct): void {
  if (onSuccess === undefined || onSuccess === null) {
    return
  }
  try {
    onSuccess(product)
  } catch (err) {
    logError('onSuccess threw', err as Object)
  }
}

/**
 * 打赏全流程（**弹窗已关闭后**执行）：补单 → 购买 → 落账 → 成功回调。
 *
 * ⚠️ 闪退修复（2026-10-20）：华为收银台会把应用切到后台，ArkUI 在应用退后台时
 * 会自动关闭 CustomDialog。用户点「取消」回到前台后，原弹窗已销毁；旧实现在
 * finally 里继续写 @State（this.paying = false），命中已销毁组件 → 闪退。
 * 因此本流程被抽成模块级函数：只依赖入参（HostContext / toast / onSuccess），
 * 全程不读不写弹窗组件状态。任何异常都在这里终结，绝不向 ArkUI 冒泡。
 */
async function runTipFlow(ctx: common.UIAbilityContext, product: TipProduct, toast: ToastFn,
  onSuccess: ((product: TipProduct) => void) | undefined): Promise<void> {
  const iap = new IapPaymentService(ctx)
  try {
    // ① 补单：上次支付成功却没消耗完的打赏订单，先把坑填上（不重复弹感谢）
    const pending: ExtraDrawResult | null = await iap.recoverTipPending()
    if (pending !== null) {
      const recovered: TipProduct = productById(pending.productId)
      await completeTip(iap, pending, false, toast)
      notifySuccess(onSuccess, recovered)
      return
    }
    // ② 购买所选档位（锁定模式即唯一档位）
    const result: ExtraDrawResult = await iap.purchaseTip(product)
    if (result.canceled) {
      return  // 用户取消：静默
    }
    await completeTip(iap, result, true, toast)
    // ③ 页面侧成功回调（财神殿解锁陈设等）；回调异常不得影响已完成的支付流程
    notifySuccess(onSuccess, product)
  } catch (err) {
    reportPayError(err as Object, toast)
  }
}

@CustomDialog
export struct DonateDialog {
  controller: CustomDialogController
  /** 选中档位下标（默认第一档 8 元，降低选择成本） */
  @State selected: number = 0
  /** 指定初始选中档位（装扮分档解锁时由调用方传入） */
  selectedIndex: number = 0
  /** 锁定单档（财神殿陈设分档解锁场景）：非空时只展示该价格、直接支付，不再列出四档供选择 */
  locked: TipProduct | null = null
  /** 锁定模式下的弹窗标题（如「财神殿陈设 · 聚宝盆」） */
  lockTitle: string = ''
  /** 支付成功回调（装扮解锁场景：传入后购买成功即回调对应档位） */
  onSuccess?: (product: TipProduct) => void
  /**
   * 关闭兜底：Pura X 实测注入的 this.controller 可能为 undefined（框架实例复用/回收时序下
   * 不注入），此时弹窗内部无法自行关闭。由创建方（owner）传入闭包，用 owner 持有的控制器
   * 引用关闭弹窗——该引用是 owner 自己 new 出来的对象，必然有效。
   */
  onClose: () => void = () => {}

  aboutToAppear(): void {
    if (this.selectedIndex >= 0 && this.selectedIndex < TIP_PRODUCTS.length) {
      this.selected = this.selectedIndex
    }
  }

  /**
   * 取档位（带兜底）。
   * ⚠️ 这里必须用**方法**而不是 `private get`：实测 @CustomDialog 的 initialRender 阶段，
   * 自定义 getter 里读 @State 会拿到 undefined（状态尚未挂上），导致
   * TIP_PRODUCTS[undefined] → undefined.amount → TypeError 直接闪退
   * （hilog: "Cannot read property amount of undefined" @ DonateDialog.ets:164）。
   * 方法调用发生在设计好的时机，且这里再做一次下标校验，双重保险。
   */
  private tierAt(index: number): TipProduct {
    const ok: boolean = (typeof index === 'number') && index >= 0 && index < TIP_PRODUCTS.length
    return TIP_PRODUCTS[ok ? index : 0]
  }

  /** 当前选中档位（同 tierAt 的兜底逻辑） */
  private selectedProduct(): TipProduct {
    return this.tierAt(this.selected)
  }

  /** 实际支付档位：锁定模式返回锁定档，否则返回用户选中的档 */
  private targetProduct(): TipProduct {
    if (this.locked !== null && this.locked !== undefined) {
      return this.locked
    }
    return this.selectedProduct()
  }

  /** 支付按钮文案（不用 getter，理由见 tierAt 注释） */
  private payLabel(): string {
    const p: TipProduct = this.targetProduct()
    return `打赏 ¥${p.amount} · ${p.label}`
  }

  /**
   * 打赏：**先关弹窗，再拉起华为收银台**。
   *
   * ⚠️ 闪退修复（2026-10-20）：收银台会把应用切到后台，ArkUI 在应用退后台时会
   * 自动关闭 CustomDialog。用户点「取消」回到前台后原弹窗已销毁，旧实现继续写
   * @State（this.paying = false）命中已销毁组件 → 闪退。
   * 现在：捕获 HostContext/UIContext 后立刻关闭弹窗，支付流程交给模块级
   * runTipFlow（不碰任何组件状态）；toast 走 UIContext，成功回调走页面闭包。
   */
  private donate(): void {
    // 入口兜底：getUIContext/getHostContext 在极端时序下可能抛错，绝不能让异常冒泡到 ArkUI
    try {
      this.startDonate()
    } catch (err) {
      logError('donate failed', err as Object)
    }
  }

  private startDonate(): void {
    // UIContext 只取一次：它属于 Ability 窗口（不属于弹窗），关闭弹窗后依旧可用，
    // 但重复调用 getUIContext() 会多一个可能抛错的时序点。
    const ui = this.getUIContext()
    const ctx = ui.getHostContext() as common.UIAbilityContext
    if (ctx === undefined || ctx === null) {
      this.toast('支付环境未就绪，请重试')
      return
    }
    const product: TipProduct = this.targetProduct()
    const onSuccess = this.onSuccess
    // 捕获 toast 能力：弹窗关闭后仍可用（UIContext 属于 Ability 窗口，不属于弹窗）
    const toast: ToastFn = (msg: string): void => {
      try {
        ui.getPromptAction().showToast({ message: msg, duration: 2500 })
      } catch (err) {
        logError('toast failed', err as Object)
      }
    }
    this.closeSelf()
    runTipFlow(ctx, product, toast, onSuccess).catch((err: Object) => {
      logError('tip flow rejected', err)
    })
  }

  /**
   * 关闭弹窗。⚠️ 闪退修复（2026-10-20）：Pura X 实测注入的 this.controller 可能为 undefined
   * —— 未判空直接 close 会 "Cannot read property close of undefined" 闪退；只判空又会「点了没反应」。
   * 因此：① 优先用注入的 controller 关闭；② 注入缺失或 close 抛错时，走 onClose 回调由创建方
   * 用自己持有的控制器引用关闭（该引用必然有效）。
   */
  private closeSelf(): void {
    const c = this.controller
    if (c !== undefined && c !== null) {
      try {
        c.close()
        return
      } catch (err) {
        logError('controller.close failed', err as Object)
      }
    }
    this.onClose()
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2500 })
  }

  build() {
    Column() {
      // 顶部装饰条（与隐私/客服/供奉弹窗同一套语言）
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#D23B2E')

      Text(this.lockTitle && this.lockTitle.length > 0 ? this.lockTitle : '支持作者  ·  打赏')
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .letterSpacing(2)
        .margin({ top: 18, bottom: 6 })

      if (this.locked !== null && this.locked !== undefined) {
        // 锁定单档：只展示对应价格，不做四档选择
        Column() {
          Text(`对应价格  ¥${this.locked.amount} · ${this.locked.label}`)
            .fontSize(14)
            .fontColor('rgba(253, 246, 227, 0.75)')
            .margin({ top: 4, bottom: 14 })
          Text('打赏作者的一份心意 · 支持独立开发')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.75)')
            .fontStyle(FontStyle.Italic)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else {
        Text('打赏作者的一份心意 · 支持独立开发')
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.75)')
          .fontStyle(FontStyle.Italic)
          .margin({ bottom: 14 })

        // ── 打赏档位（Flex 自动换行，选中态：金色实描边 + 淡金底）──
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
          ForEach(TIP_PRODUCTS, (p: TipProduct, i: number) => {
            this.TierCard(p, i)
          }, (p: TipProduct) => p.productId)
        }
        .width('100%')
        .margin({ bottom: 14 })
      }

      Button(this.payLabel())
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#FFD700')
        .borderRadius(20)
        .height(42)
        .width('100%')
        .onClick(() => {
          this.donate()
        })

      // ── 用途小字 + 公益明细 ──
      Text('打赏款项用于作者后续开发和维护')
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ top: 10, bottom: 2 })

      Row() {
        Text('其中一部分将捐赠给联合国儿童基金会（UNICEF）')
          .fontSize(10)
          .fontColor('rgba(255, 209, 0, 0.75)')
        Text('公益明细 ›')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFD700')
          .margin({ left: 6 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 4 })
      .onClick(() => {
        this.closeSelf()
        this.getUIContext().getRouter().pushUrl({ url: 'pages/DonationDetailPage' })
      })

      Text('打赏为自愿赠与 · 不承诺任何效果')
        .fontSize(9)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ bottom: 12 })

      Button('关闭')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFD700')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: 'rgba(255, 209, 0, 0.4)' })
        .borderRadius(20)
        .height(34)
        .padding({ left: 28, right: 28 })
        .margin({ bottom: 12 })
        .onClick(() => {
          this.closeSelf()
        })
    }
    .width('84%')
    .padding({ left: 16, right: 16 })
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }

  /** 单个金额档位卡片 */
  @Builder
  TierCard(product: TipProduct, index: number) {
    Column() {
      Text(`¥${product.amount}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selected === index ? '#FFD700' : '#fdf6e3')
      Text(product.label)
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ top: 3 })
    }
    .width('47%')
    .padding({ top: 10, bottom: 10 })
    .borderRadius(10)
    .backgroundColor(this.selected === index ? 'rgba(255, 209, 0, 0.14)' : 'rgba(255, 209, 0, 0.04)')
    .border({
      width: this.selected === index ? 1.5 : 1,
      color: this.selected === index ? 'rgba(255, 209, 0, 0.7)' : 'rgba(255, 209, 0, 0.18)'
    })
    .margin({ bottom: 10 })
    .onClick(() => {
      this.selected = index
    })
  }
}
