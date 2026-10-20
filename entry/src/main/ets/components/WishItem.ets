// entry/src/main/ets/components/WishItem.ets
import { Wish } from '../model/EnrichTypes'

/** 还愿确认弹窗：深色金边风格，与 PrivacyDialog 一致 */
@CustomDialog
struct FulfillWishDialog {
  controller: CustomDialogController
  onConfirm: () => void = () => {}
  /** 关闭兜底：注入的 controller 可能为 undefined，由创建方用自己持有的引用关闭 */
  onClose: () => void = () => {}

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
        console.error('[FulfillWishDialog] controller.close failed: ' + msg)
      }
    }
    this.onClose()
  }

  build() {
    Column() {
      // 顶部红色装饰条
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#D23B2E')

      // 标题
      Text('✦  磕头还愿  ✦')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .letterSpacing(2)
        .margin({ top: 22, bottom: 6 })

      Text('「诚心磕头，还愿谢神」')
        .fontSize(13)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 18 })

      // 分隔线
      Row()
        .width('48%')
        .height(1)
        .backgroundColor('rgba(255, 209, 0, 0.25)')
        .margin({ bottom: 20 })

      // 操作按钮组
      Row() {
        Button('取消')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(253, 246, 227, 0.75)')
          .backgroundColor('rgba(255, 255, 255, 0.05)')
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.35)', radius: 22 })
          .height(44)
          .padding({ left: 26, right: 26 })
          .onClick(() => this.closeDialog())

        Button('磕头还愿')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#FFD700')
          .borderRadius(22)
          .height(46)
          .padding({ left: 30, right: 30 })
          .shadow({ radius: 10, color: 'rgba(255, 209, 0, 0.35)', offsetY: 2 })
          .onClick(() => {
            this.closeDialog()
            this.onConfirm()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 10 })
    }
    .width('86%')
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}

@Component
export struct WishItem {
  @Prop wish: Wish
  @StorageLink('deviceUserId') deviceUserId: string = ''
  // 还愿回调由父页面持有（数据操作集中在页面层）
  onFulfill: (wishId: string) => void = (_wishId: string) => {}
  // 删除回调
  onDelete: (wishId: string) => void = (_wishId: string) => {}
  private fulfillDialogController: CustomDialogController | null = null

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.wish.content)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fdf6e3')
            .lineHeight(26)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row() {
            Text(this.wish.nickname)
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.75)')
            Text(' · ')
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.75)')
            Text(this.formatTime(this.wish.createdAt))
              .fontSize(13)
              .fontColor('rgba(253, 246, 227, 0.75)')
          }
          .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.wish.fulfilled) {
          Text('✅ 已还愿')
            .fontSize(14)
            .fontColor('#2ecc71')
            .backgroundColor('rgba(46, 204, 113, 0.12)')
            .borderRadius(14)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .margin({ left: 10 })
            .alignSelf(ItemAlign.Center)
        } else if (this.deviceUserId !== '' && this.deviceUserId === this.wish.userId) {
          Button('🙏 还愿')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#FFD700')
            .borderRadius(22)
            .height(44)
            .padding({ left: 20, right: 20 })
            .margin({ left: 10 })
            .alignSelf(ItemAlign.Center)
            .shadow({ radius: 10, color: 'rgba(255, 209, 0, 0.35)', offsetY: 2 })
            .onClick(() => { this.confirmFulfill() })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    .border({ width: { bottom: 0.5 }, color: 'rgba(255, 209, 0, 0.08)' })
    .gesture(
      LongPressGesture({ repeat: false })
        .onAction(() => {
          if (this.deviceUserId !== '' && this.deviceUserId === this.wish.userId) {
            this.confirmDelete()
          }
        })
    )
  }

  private confirmFulfill(): void {
    // 惰性创建弹窗控制器，避免提前构建子树
    this.fulfillDialogController = new CustomDialogController({
      builder: FulfillWishDialog({
        onClose: (): void => {
          // 关闭兜底：用 WishItem 持有的控制器引用关弹窗（Pura X 注入的 controller 可能为 undefined）
          const c = this.fulfillDialogController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[WishItem] fulfill dialog onClose failed')
            }
          }
        },
        onConfirm: () => { this.onFulfill(this.wish.id) }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.fulfillDialogController.open()
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除心愿',
      message: '确定要删除这条心愿吗？删除后不可恢复。',
      primaryButton: {
        value: '删除',
        action: () => { this.onDelete(this.wish.id) }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  private formatTime(isoStr: string): string {
    if (!isoStr) return ''
    try {
      const d: Date = new Date(isoStr)
      return `${d.getMonth() + 1}/${d.getDate()}`
    } catch {
      return ''
    }
  }
}
