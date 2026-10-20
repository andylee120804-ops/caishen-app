// entry/src/main/ets/components/HallDecorDialog.ets
// 殿内装扮弹窗：展示灯样式 / 香炉 / 殿宇主题三组分档装扮。
// 已解锁项可「使用」切换；未解锁项点击 → DecorPayDialog 解锁对应装扮档位（独立商品 decor_*），
// 支付成功后 unlockTier 解锁（2026-10-20 自打赏 tip_* 拆出，装扮不再走打赏/公益榜）。
import { HallViewModel, HALL_DECOR_ORDER, DecorGroup, DecorOption } from '../viewmodels/HallViewModel'
import { DecorPayDialog } from './DecorPayDialog'
import { DecorProduct, decorByAmount } from '../service/IPaymentService'

@CustomDialog
export struct HallDecorDialog {
  controller: CustomDialogController
  hallVM!: HallViewModel
  /** 关闭兜底：注入的 controller 可能为 undefined，由创建方用自己持有的引用关闭 */
  onClose: () => void = () => {}
  private decorController: CustomDialogController | null = null

  /** 打开装扮解锁指定单品（tier = 8/18/88/888） */
  private openPay(opt: DecorOption): void {
    // 先取局部引用：收银台会把应用切后台，ArkUI 可能把本装扮弹窗一并销毁，
    // 支付成功回调里再读 this.hallVM 就是访问已销毁组件（与打赏弹窗闪退同一类）。
    const hall = this.hallVM
    const product: DecorProduct = decorByAmount(opt.tier)
    const dlg = new CustomDialogController({
      builder: DecorPayDialog({
        product: product,
        title: `装扮 · ${opt.name}`,
        onClose: (): void => {
          // 关闭兜底：用本弹窗持有的 decorController 引用关掉解锁弹窗
          const c = this.decorController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[HallDecorDialog] decor dialog onClose failed')
            }
          }
        },
        onSuccess: (p: DecorProduct): void => {
          // 解锁成功即解锁该档及更低档装扮（本地，不记公益榜）
          hall.unlockTier(p.amount)
          // 不再 close()：收银台期间应用退后台，ArkUI 会把本装扮弹窗与解锁弹窗
          // 一并销毁；回到前台后再 close 已销毁的弹窗会闪退。
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.decorController = dlg
    dlg.open()
  }

  /**
   * 关闭弹窗。⚠️ 闪退修复（2026-10-20）：Pura X 实测注入的 this.controller 可能为 undefined
   * —— 未判空直接 close 会闪退；只判空又「点了没反应」。① 优先注入的 controller；② 否则走 onClose。
   */
  private closeDialog(): void {
    const c = this.controller
    if (c !== undefined && c !== null) {
      try {
        c.close()
        return
      } catch (err) {
        const msg = (err instanceof Error) ? err.message : JSON.stringify(err)
        console.error('[HallDecorDialog] controller.close failed: ' + msg)
      }
    }
    this.onClose()
  }

  build() {
    Column() {
      Row() {
        Text('殿内装扮')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
        Text('✕')
          .fontSize(16)
          .fontColor('rgba(253, 246, 227, 0.75)')
          .margin({ left: 'auto' })
          .onClick(() => {
            this.closeDialog()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ bottom: 8 })

      ForEach(HALL_DECOR_ORDER, (group: DecorGroup) => {
        this.DecorGroupView(group)
      }, (group: DecorGroup) => group.key)

      Text('装扮仅改变殿内视觉效果，不涉及任何祈福效力；解锁为对开发者的自愿支持。')
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .margin({ top: 10 })
    }
    .width('86%')
    .padding(18)
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .clip(true)
  }

  @Builder
  DecorGroupView(group: DecorGroup) {
    Column() {
      Text(group.title)
        .fontSize(13)
        .fontColor('rgba(255, 209, 0, 0.85)')
        .margin({ top: 14, bottom: 4 })
        .width('100%')
      ForEach(group.opts, (opt: DecorOption) => {
        Row() {
          Text(opt.name)
            .fontSize(14)
            .fontColor('#fdf6e3')
            .layoutWeight(1)
          if (this.hallVM.isUnlocked(opt.tier)) {
            if (this.hallVM.isActive(group.key, opt.id)) {
              Text('使用中')
                .fontSize(12)
                .fontColor('rgba(46, 204, 113, 0.9)')
            } else {
              Button('使用')
                .fontSize(12)
                .height(28)
                .backgroundColor('rgba(255, 209, 0, 0.15)')
                .fontColor('#FFD700')
                .onClick(() => {
                  this.hallVM.useDecor(group.key, opt.id)
                })
            }
          } else {
            Button(`¥${opt.tier} 解锁`)
              .fontSize(12)
              .height(28)
              .backgroundColor('#FFD700')
              .fontColor('#1a1a0a')
              .onClick(() => {
                this.openPay(opt)
              })
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .border({ width: { bottom: 1 }, color: 'rgba(255, 209, 0, 0.12)' })
      }, (opt: DecorOption) => opt.id)
    }
    .width('100%')
  }
}
