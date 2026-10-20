import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { DeityArrayView } from '../components/DeityArrayView'
import { HistoryPanel } from '../components/HistoryPanel'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { PrayerPhase, FIVE_DEITIES } from '../model/PrayerTypes'
import { router } from '@kit.ArkUI'

@Entry
@Component
struct HomePage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @State showHistory: boolean = false
  @State showPrivacyDialog: boolean = false
  private privacyDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.checkPrivacyAccepted()
  }

  private async checkPrivacyAccepted(): Promise<void> {
    try {
      const accepted = await this.viewModel.isPrivacyAccepted()
      if (!accepted) {
        this.showPrivacyDialog = true
        this.openPrivacyDialog()
      }
    } catch (err) {
      console.error('[HomePage] Failed to check privacy:', JSON.stringify(err))
      // 读取失败时也展示弹窗，确保合规
      this.showPrivacyDialog = true
      this.openPrivacyDialog()
    }
  }

  private openPrivacyDialog(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyDialog({
        onAgree: () => {
          this.showPrivacyDialog = false
          this.viewModel.acceptPrivacy()
        },
        onClose: (): void => {
          // 关闭兜底：用本页持有的控制器引用关弹窗（Pura X 注入的 controller 可能为 undefined）
          const c = this.privacyDialogController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[HomePage] privacy dialog onClose failed')
            }
          }
        }
      }),
      autoCancel: false,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.privacyDialogController.open()
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
    Stack() {
      // 背景（延伸到状态栏/导航栏安全区，消除白边）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#D23B2E', 0.0], ['#A51D16', 0.55], ['#6F120E', 1.0]] })
        .overlay(this.GlowOverlay)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 五神弧形阵（远景贴顶，与叩拜页完全一致的层叠起点 y=0）
      Column() {
        DeityArrayView({
          deities: FIVE_DEITIES,
          todayId: this.viewModel.todayDeity.id,
          highlightId: this.viewModel.todayDeity.id,
          appearProgress: 1,
          blessingProgress: 0
        })
      }
      .width('100%')
      .height('50%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)

      // 顶部装饰文字（下移避开状态栏；金底加柔影，在更亮的红底上更协调清晰）
      Text('✦ 财神赐福 · 财气长虹 ✦')
        .fontSize(12)
        .fontColor('rgba(255, 217, 90, 0.85)')
        .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.3)' })
        .position({ x: '50%', y: 64 })
        .translate({ x: '-50%', y: '0' })

      // 副标题（下移避开主位财神下方四行名号/方位/寓意文字）
      Text('「心诚则灵，财运亨通」')
        .fontSize(14)
        .fontColor('rgba(255, 217, 90, 0.8)')
        .fontStyle(FontStyle.Italic)
        .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.3)' })
        .position({ x: '50%', y: '73%' })
        .translate({ x: '-50%', y: '-50%' })

      // 主按钮
      Row() {
        Image($rawfile('props/yuanbao.png'))
          .width(26)
          .height(26)
          .objectFit(ImageFit.Contain)
        Text('开始祈福')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .margin({ left: 10 })
      }
      .justifyContent(FlexAlign.Center)
      .padding({ left: 20, right: 36, top: 10, bottom: 10 })
      .backgroundColor('#FFD700')
      .borderRadius(25)
      .shadow({
        radius: 20,
        color: 'rgba(255, 209, 0, 0.4)',
        offsetY: 4
      })
      .onClick(() => {
        this.viewModel.startPrayer()
        // 延迟导航到下一帧，让按钮点击反馈先渲染
        setTimeout(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/NameCard' }, router.RouterMode.Standard)
        }, 0)
      })
      .position({ x: '50%', y: '82%' })
      .translate({ x: '-50%', y: '-50%' })

      // 左滑提示
      Text('← 左滑查看祈福记录')
        .fontSize(11)
        .fontColor('rgba(255, 209, 0, 0.6)')
        .position({ x: '50%', y: '86%' })
        .translate({ x: '-50%', y: '-50%' })

      // 隐私政策入口（底部小字，可随时查看）
      Text('隐私政策')
        .fontSize(11)
        .fontColor('rgba(255, 209, 0, 0.6)')
        .position({ x: '50%', y: '94%' })
        .translate({ x: '-50%', y: '-50%' })
        .onClick(() => {
          this.openPrivacyDialog()
        })

      // 历史面板（左滑呼出）
      if (this.showHistory) {
        HistoryPanel({
          records: this.viewModel.history,
          onClose: () => {
            this.showHistory = false
          },
          onClear: () => {
            this.viewModel.clearHistory()
          },
          onDelete: (id: string) => {
            this.viewModel.deleteRecord(id)
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .gesture(
      PanGesture({ direction: PanDirection.Left })
        .onActionEnd(() => {
          if (!this.showHistory) {
            this.showHistory = true
          }
        })
    )
  }
}