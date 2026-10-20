// entry/src/main/ets/pages/WishWall.ets
// 还愿入口：展示心愿记录，点击还愿进入磕头动画，磕头完成后标记心愿达成
import { Wish } from '../model/EnrichTypes'
import { CloudService } from '../service/CloudService'
import { WishItem } from '../components/WishItem'
import { PageBack } from '../components/PageBack'
import { router } from '@kit.ArkUI'

@Component
export struct WishWallPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @State wishes: Wish[] = []
  @State loading: boolean = false
  @State errorMsg: string = ''
  // 还愿成功后 PrayerCard 设置此时间戳，触发刷新
  @StorageLink('wishFulfilledAt') @Watch('onWishFulfilledAtChange') wishFulfilledAt: number = 0

  aboutToAppear(): void {
    this.loadData()
  }

  onWishFulfilledAtChange(): void {
    if (this.wishFulfilledAt > 0) {
      this.loadData()
    }
  }

  async loadData(): Promise<void> {
    this.loading = true
    this.errorMsg = ''
    try {
      const result: Wish[] = await CloudService.getWishes()
      this.wishes = result
      console.info('[WishWall] loaded ' + result.length + ' wishes')
    } catch (err) {
      this.errorMsg = '加载失败，请下拉刷新重试'
      console.error('[WishWall] load failed:', JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  /** 点击还愿 → 导航到 PrayerCard 进行磕头还愿（携带许愿当日所拜财神，还愿拜同一神） */
  fulfillWish(wishId: string): void {
    const wish: Wish | undefined = this.wishes.find((w: Wish) => w.id === wishId)
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/PrayerCard',
      params: { fulfillWishId: wishId, fulfillDeityId: wish ? wish.deityId : 0 }
    }, router.RouterMode.Standard)
  }

  /** 删除心愿 → 调用云函数删除后刷新列表 */
  async deleteWish(wishId: string): Promise<void> {
    const errMsg: string = await CloudService.deleteWish(wishId)
    if (!errMsg) {
      this.wishes = this.wishes.filter((w: Wish) => w.id !== wishId)
    } else {
      this.getUIContext().getPromptAction().showToast({ message: errMsg })
    }
  }
  @Builder
  GlowOverlay() {
    Column()
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .radialGradient({ center: ['50%', '12%'], radius: '58%', colors: [['rgba(255, 209, 0, 0.40)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]] })
  }


  build() {
    Column() {
      // 标题 + 刷新按钮（独立模式返回键并入同行且标题居中；Tab 模式标题左对齐）
      Row() {
        if (this.standalone) {
          PageBack()
        }
        Text('🙏 还愿')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .layoutWeight(1)
          .textAlign(this.standalone ? TextAlign.Center : TextAlign.Start)
        Text('↻ 刷新')
          .fontSize(12)
          .fontColor('#ffffff')
          .onClick(() => { this.loadData() })
      }
      .width('100%')
      .padding({ left: this.standalone ? 6 : 20, right: 20, top: 44, bottom: 8 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.loading) {
        // 各状态均为固定居中布局：包 Scroll 保证上下滑动到边界有 Spring 回弹反馈
        Scroll() {
          Column() {
            LoadingProgress().width(40).height(40).color('#FFD700')
            Text('加载中...').fontSize(12).fontColor('rgba(253, 246, 227, 0.75)').margin({ top: 8 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      } else if (this.errorMsg) {
        // 错误状态：显示错误信息 + 重试按钮
        Scroll() {
          Column() {
            Text('⚠️').fontSize(36).margin({ bottom: 8 })
            Text(this.errorMsg)
              .fontSize(14)
              .fontColor('rgba(253, 246, 227, 0.75)')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 16 })
            Button('重新加载')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .backgroundColor('#FFD700')
              .borderRadius(20)
              .padding({ left: 24, right: 24, top: 8, bottom: 8 })
              .onClick(() => { this.loadData() })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      } else if (this.wishes.length === 0) {
        Scroll() {
          Column() {
            Text('🙏').fontSize(40).margin({ bottom: 8 })
            Text('还没有心愿记录').fontSize(14).fontColor('rgba(253, 246, 227, 0.75)')
            Text('祈福时可以许下心愿').fontSize(14).fontColor('rgba(253, 246, 227, 0.75)').margin({ top: 4 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      } else {
        Scroll() {
          Column() {
            // 未还愿的心愿排在前面
            ForEach(this.getSortedWishes(), (wish: Wish) => {
              WishItem({ wish: wish, onFulfill: (id: string) => { this.fulfillWish(id) }, onDelete: (id: string) => { this.deleteWish(id) } })
            }, (wish: Wish) => wish.id)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }

      // 底部提示：心愿数量
      if (this.wishes.length > 0 && !this.loading && !this.errorMsg) {
        Text(`共 ${this.wishes.length} 条心愿 · 长按可删除自己的心愿`)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.75)')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 4, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#D23B2E', 0.0], ['#A51D16', 0.55], ['#6F120E', 1.0]] })
    .overlay(this.GlowOverlay)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  /** 未还愿排前，已还愿排后 */
  private getSortedWishes(): Wish[] {
    const unfulfilled: Wish[] = this.wishes.filter((w: Wish) => !w.fulfilled)
    const fulfilled: Wish[] = this.wishes.filter((w: Wish) => w.fulfilled)
    return [...unfulfilled, ...fulfilled]
  }
}
