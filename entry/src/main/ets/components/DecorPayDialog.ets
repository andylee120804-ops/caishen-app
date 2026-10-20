// entry/src/main/ets/components/DecorPayDialog.ets
// 财神殿装扮 / 陈设解锁弹窗（2026-10-20 自打赏 tip_* 拆出的独立消耗型商品 decor_*）。
//
// 与 DonateDialog 的关键区别：
// 1) 商品是独立的 decor_8 / decor_18 / decor_88 / decor_188 / decor_888（非打赏 tip_*）；
// 2) 购买只解锁殿内视觉效果（本地 HallViewModel），**不调用 CloudService.recordDonation**、
//    不入公益排行榜——装扮不是打赏，审核据此把二者区分开；
// 3) 文案是「解锁装扮/陈设」，不是「打赏作者」，并写明「仅改变视觉效果、不承诺祈福效力」。
//
// 生命周期红线（复用 DonateDialog 2026-10-20 闪退事故结论）：拉起华为收银台前必须先关闭本弹窗，
// 支付流程全放模块级 runDecorFlow，只依赖入参（HostContext / toast / onSuccess），绝不访问组件状态。
// 时序：支付成功 → 本地解锁（onSuccess，幂等）→ consume（失败留 recoverDecorPending 补单）。
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { IapPaymentService } from '../service/IapPaymentService'
import { DecorProduct, decorById, ExtraDrawResult, PaymentError, PaymentErrorKind } from '../service/IPaymentService'

/** 轻提示函数（UIContext 属于 Ability 窗口，弹窗销毁后依旧可用） */
type ToastFn = (msg: string) => void

/** 统一错误日志：Error 的 message/stack 不可枚举，JSON.stringify 会得到 {}，必须单独取 */
function logError(tag: string, err: Object): void {
  try {
    if (err instanceof Error) {
      const e = err as Error
      console.error('[Decor] ' + tag + ': ' + e.message + '\n' + (e.stack || ''))
      return
    }
    console.error('[Decor] ' + tag + ': ' + JSON.stringify(err))
  } catch (e) {
    console.error('[Decor] ' + tag + ': <unserializable error>')
  }
}

/** 前置错误按 kind 给可行动提示，其余笼统兜底 */
function reportDecorError(err: Object, toast: ToastFn): void {
  if (err instanceof PaymentError) {
    const pe = err as PaymentError
    if (pe.kind === PaymentErrorKind.NEED_LOGIN) {
      toast('请先登录华为帐号后解锁')
      return
    }
    if (pe.kind === PaymentErrorKind.REGION) {
      toast('当前地区暂不支持购买')
      return
    }
    if (pe.kind === PaymentErrorKind.PRODUCT) {
      toast('该装扮准备中，请稍后再来')
      return
    }
    if (pe.kind === PaymentErrorKind.ALREADY_OWNED) {
      toast('有未完成的解锁订单，稍后会自动补单')
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
  toast('解锁失败，请稍后重试')
}

/** 消耗商品（finishPurchase）——本地解锁已完成，消耗失败留 recoverDecorPending 补单 */
async function completeDecor(iap: IapPaymentService, result: ExtraDrawResult): Promise<void> {
  try {
    await iap.consume(result)
  } catch (err) {
    logError('consume failed（下次进入自动补单）', err as Object)
  }
}

/** 成功回调（页面闭包，负责本地解锁 + 视觉反馈）：异常只记日志，不能当成解锁失败提示用户 */
function notifyDecorSuccess(onSuccess: ((product: DecorProduct) => void) | undefined,
  product: DecorProduct): void {
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
 * 装扮解锁全流程（弹窗已关闭后执行）：补单 → 购买 → 本地解锁 → 消耗。
 * 与打赏不同，这里无云端记账：解锁写本地 preferences（HallViewModel），重装不恢复（与旧版一致）。
 * 崩溃在消耗前 → 下次进入任一摆件购买时 recoverDecorPending 补单（按 productId 对应的档位解锁 + 消耗）。
 */
async function runDecorFlow(ctx: common.UIAbilityContext, product: DecorProduct, toast: ToastFn,
  onSuccess: ((product: DecorProduct) => void) | undefined): Promise<void> {
  const iap = new IapPaymentService(ctx)
  try {
    // ① 补单：上次支付成功却没消耗完的装扮订单，先解锁坑填上（幂等）
    const pending: ExtraDrawResult | null = await iap.recoverDecorPending()
    if (pending !== null) {
      const recovered: DecorProduct = decorById(pending.productId)
      notifyDecorSuccess(onSuccess, recovered)
      await completeDecor(iap, pending)
      return
    }
    // ② 购买对应装扮（锁定单档）
    const result: ExtraDrawResult = await iap.purchaseDecor(product)
    if (result.canceled) {
      return  // 用户取消：静默
    }
    // ③ 先本地解锁（幂等），后消耗——消耗失败订单保持未完成，留补单重放
    notifyDecorSuccess(onSuccess, product)
    await completeDecor(iap, result)
  } catch (err) {
    reportDecorError(err as Object, toast)
  }
}

@CustomDialog
export struct DecorPayDialog {
  controller: CustomDialogController
  /** 要解锁的装扮/陈设商品（decor_*，锁定单档） */
  product: DecorProduct = { productId: 'decor_8', amount: 8, label: '灯样式' }
  /** 弹窗标题（如「财神殿陈设 · 聚宝盆」） */
  title: string = ''
  /** 解锁成功回调（页面闭包负责 setWareOwned / unlockTier + 视觉反馈） */
  onSuccess?: (product: DecorProduct) => void
  /** 关闭兜底（Pura X 实测注入 controller 可能为 undefined，由创建方持引用关闭） */
  onClose: () => void = () => {}

  /**
   * 解锁：先关弹窗再拉起收银台（闪退修复同 DonateDialog）。
   */
  private unlock(): void {
    try {
      this.startUnlock()
    } catch (err) {
      logError('unlock failed', err as Object)
    }
  }

  private startUnlock(): void {
    const ui = this.getUIContext()
    const ctx = ui.getHostContext() as common.UIAbilityContext
    if (ctx === undefined || ctx === null) {
      this.toast('支付环境未就绪，请重试')
      return
    }
    const product: DecorProduct = this.product
    const onSuccess = this.onSuccess
    const toast: ToastFn = (msg: string): void => {
      try {
        ui.getPromptAction().showToast({ message: msg, duration: 2500 })
      } catch (err) {
        logError('toast failed', err as Object)
      }
    }
    this.closeSelf()
    runDecorFlow(ctx, product, toast, onSuccess).catch((err: Object) => {
      logError('decor flow rejected', err)
    })
  }

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
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#D23B2E')

      Text(this.title && this.title.length > 0 ? this.title : this.product.label)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .letterSpacing(2)
        .margin({ top: 18, bottom: 6 })

      Text(`¥${this.product.amount} 解锁`)
        .fontSize(14)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ top: 4, bottom: 14 })

      Button(`解锁 ¥${this.product.amount}`)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#FFD700')
        .borderRadius(20)
        .height(42)
        .width('100%')
        .onClick(() => {
          this.unlock()
        })

      Text('装扮仅改变殿内视觉效果 · 不涉及任何祈福效力')
        .fontSize(9)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ top: 12, bottom: 12 })

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
}