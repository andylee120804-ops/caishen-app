// entry/src/main/ets/pages/MyPage.ets
// 我的：财运汇总 + 打赏（支持作者）+ 界面定制 + 功能入口 + 联系客服。
// 顺序说明：
// 1) 财运汇总（GameRecordCard）置顶固定展示，即使「收支记录」被设为底部 Tab 也不隐藏；
// 2) 「支持作者」（打赏：打赏作者 = 敬财神，打赏部分用于公益）紧随其后，突出新增入口；
// 3) 界面定制紧随打赏之后（用户主诉求：定制入口更靠近顶部）；
// 4) 功能入口只列「未开启为底部 Tab」的项；联系客服与隐私政策并排做成底部小字双入口，
//    不占功能入口的位置。
// 说明：UI v1 下 @StorageLink 不通知 @Observed 嵌套变更，页面把派生数据快照到
// @State，靠 VM bump 的 rev 信号（@Watch）+ onPageShow 重建。
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryItem } from '../viewmodels/EntryConfigVM'
import { GameRecordCard } from '../components/GameRecordCard'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { ContactSupportDialog } from '../components/ContactSupportDialog'
import { DonateDialog } from '../components/DonateDialog'
import { CaiShenHallIcon } from '../components/CaiShenHallIcon'

@Component
export struct MyPage {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  @StorageLink('entryConfigRev') @Watch('onConfigRev') entryConfigRev: number = 0
  // —— 派生数据快照 ——
  @State offRows: EntryItem[] = []     // 未开启为 Tab 的入口（按用户 order）
  @State tabCount: number = 0          // 已开启 Tab 数
  private privacyDialogController: CustomDialogController | null = null
  // 惰性创建联系客服弹窗控制器（审核问题1整改：付费应用需在应用内提供客服联系方式）
  private supportDialogController: CustomDialogController | null = null
  // 惰性创建打赏弹窗控制器（避免页面入场时提前构建子树，降低点击时延）
  private donateDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.syncAll()
  }

  /** 从 EntryShell/界面定制返回后重新同步（Tab 内容可能被另一页改过） */
  onPageShow(): void {
    this.syncAll()
  }

  onConfigRev(): void {
    this.syncConfig()
  }

  private syncAll(): void {
    this.syncConfig()
  }

  private syncConfig(): void {
    // gamerecord 除外：其入口是置顶固定的 GameRecordCard（开关在界面定制，
    // 开启后由底部 Tab 直达），不重复出现在「功能入口」行
    this.offRows = this.entryConfigVM.getSortedItems()
      .filter((it: EntryItem): boolean => !it.enabled && it.id !== 'gamerecord')
    let n: number = 0
    for (const it of this.entryConfigVM.getSortedItems()) {
      if (it.enabled) {
        n++
      }
    }
    this.tabCount = n
  }

  /** 打开打赏弹窗（打赏作者 = 敬财神；款项用于开发维护，部分捐赠公益） */
  private openDonateDialog(): void {
    if (this.donateDialogController === null) {
      this.donateDialogController = new CustomDialogController({
        builder: DonateDialog({
          onClose: (): void => {
            // 关闭兜底：用本页持有的控制器引用关弹窗（Pura X 注入的 controller 可能为 undefined）
            const c = this.donateDialogController
            if (c !== undefined && c !== null) {
              try {
                c.close()
              } catch (err) {
                console.error('[MyPage] donate dialog onClose failed')
              }
            }
          }
        }),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        customStyle: true
      })
    }
    this.donateDialogController.open()
  }

  /** 复阅隐私政策（首次同意后仍可随时查看；只读模式，不提供退出应用） */
  private openPrivacyDialog(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyDialog({
        reviewOnly: true,
        onClose: (): void => {
          const c = this.privacyDialogController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[MyPage] privacy dialog onClose failed')
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

  /** 打开联系客服弹窗（惰性创建，降低页面入场时延；客服邮箱 + 复制 / 发邮件） */
  private openSupportDialog(): void {
    if (this.supportDialogController === null) {
      this.supportDialogController = new CustomDialogController({
        builder: ContactSupportDialog({
          onClose: (): void => {
            const c = this.supportDialogController
            if (c !== undefined && c !== null) {
              try {
                c.close()
              } catch (err) {
                console.error('[MyPage] support dialog onClose failed')
              }
            }
          }
        }),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        customStyle: true
      })
    }
    this.supportDialogController.open()
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
      // 顶部标题
      Text('我的')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .width('100%')
        .padding({ left: 20, top: 44, bottom: 8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Scroll() {
        Column() {
          // 财运汇总卡片（置顶突出显示，固定不随 Tab 开关消失）。
          // 只显示汇总 + 记一笔；每笔明细在收支记录页（下方入口跳转，数据同一份）
          GameRecordCard({
            enrichVM: $enrichVM,
            showDetailEntry: true,
            onOpenDetail: (): void => {
              this.getUIContext().getRouter().pushUrl({
                url: 'pages/EntryShell',
                params: { entryId: 'gamerecord' }
              })
            }
          })
            .margin({ top: 4, bottom: 12 })

          // 打赏（打赏作者 = 敬财神；款项用于开发维护，部分捐赠公益）
          this.DonateSection()

          // 界面定制（子页：开关 + 长按拖拽排序）
          this.MenuItem('🏗', '界面定制', `Tab 已开 ${this.tabCount}/3`, false, false, (): void => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/CustomizePage' })
          })

          // 功能入口：只列未开启为底部 Tab 的功能（其余已由底部 Tab 直达）
          this.EntryListSection()

          // 底部小字双入口（并排，不占功能入口位）：
          // 联系客服（审核整改：应用含付费项目，需在应用内提供客服联系方式）
          // 隐私政策（可随时复阅；首次启动时已弹窗同意）
          Row() {
            Text('联系客服')
              .fontSize(11)
              .fontColor('rgba(255, 209, 0, 0.85)')
              .onClick((): void => {
                this.openSupportDialog()
              })
            Text('·')
              .fontSize(11)
              .fontColor('rgba(255, 209, 0, 0.5)')
              .margin({ left: 10, right: 10 })
            Text('隐私政策')
              .fontSize(11)
              .fontColor('rgba(255, 209, 0, 0.85)')
              .onClick((): void => {
                this.openPrivacyDialog()
              })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .margin({ top: 14, bottom: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        // 沉浸式全屏：内容滚到底需避让系统导航条/手势条（≥28vp）
        .padding({ bottom: 28 })
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#D23B2E', 0.0], ['#A51D16', 0.55], ['#6F120E', 1.0]] })
    .overlay(this.GlowOverlay)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  // ── 字形图标：圆形徽标 + 单字（替代 emoji，避免字形丑/多机型渲染差异）──
  @Builder
  GlyphIcon(glyph: string) {
    Row() {
      Text(glyph)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
    }
    .width(34)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .borderRadius(17)
    .backgroundColor('rgba(255, 209, 0, 0.10)')
    .border({ width: 1, color: 'rgba(255, 209, 0, 0.45)' })
    .margin({ right: 12 })
  }

  // ── 打赏入口（支持作者：打赏款项用于开发维护，部分捐赠公益）──
  @Builder
  DonateSection() {
    Row() {
      this.GlyphIcon('赏')
      Column() {
        Text('支持作者 · 打赏')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .width('100%')
        Text('打赏作者的一份心意 · 部分所得用于公益')
          .fontSize(11)
          .fontColor('#ffffff')
          .margin({ top: 4 })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text('›')
        .fontSize(22)
        .fontColor('rgba(255, 209, 0, 0.85)')
    }
    .alignItems(VerticalAlign.Center)
    .width('90%')
    .padding({ left: 16, right: 12, top: 14, bottom: 14 })
    .linearGradient({
      angle: 135,
      colors: [['rgba(255, 209, 0, 0.16)', 0.0], ['rgba(255, 209, 0, 0.04)', 1.0]]
    })
    .border({ width: 1, color: 'rgba(255, 209, 0, 0.28)', radius: 10 })
    .margin({ bottom: 10 })
    .onClick((): void => {
      this.openDonateDialog()
    })
  }

  // ── 功能入口（未开 Tab 项）──
  @Builder
  EntryListSection() {
    Column() {
      Row() {
        Text('🧭 功能入口')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
        Blank()
        Text('开启为 Tab 的功能不在此重复显示')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.75)')
      }
      // 15/10sp 混排标题行：底对齐避免基准线错位
      .alignItems(VerticalAlign.Bottom)
      .width('90%')
      .margin({ bottom: 6 })

      ForEach(this.offRows, (item: EntryItem) => {
        this.MenuItem(this.entryConfigVM.getIcon(item.id), this.entryConfigVM.getTitle(item.id), '', item.id === 'muyu', item.id === 'caishenhall', (): void => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/EntryShell', params: { entryId: item.id } })
        })
      }, (item: EntryItem) => item.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  MenuItem(icon: string, label: string, value: string, isMuyu: boolean, isCaishenHall: boolean, onClick: () => void) {
    Row() {
      if (isMuyu) {
        // 木鱼入口：真实木鱼图（emoji 无木鱼字形，🪵 会看成木头）
        Image($rawfile('props/muyu.png'))
          .width(26)
          .height(26)
          .objectFit(ImageFit.Contain)
          .margin({ right: 10 })
      } else if (isCaishenHall) {
        // 财神殿入口：金线自绘中国古建筑殿堂，替代 emoji 🏯（日式城堡）
        CaiShenHallIcon({ iconSize:26 })
          .margin({ right: 10 })
      } else {
        Text(icon)
          .fontSize(22)
          .fontColor('#FFD700')
          .margin({ right: 10 })
      }
      Text(label)
        .fontSize(14)
        .fontColor('#fdf6e3')
      Blank()
      if (value !== '') {
        Text(value)
          .fontSize(12)
          .fontColor('#FFD700')
          .margin({ right: 8 })
      }
      Text('→')
        .fontSize(14)
        .fontColor('rgba(253, 246, 227, 0.75)')
    }
    // 行内图标/图片/文本（22/26/14/12sp 混排）统一底对齐：不同字号底线齐平，
    // 避免 AGC「控件基准线不对齐」（默认 Center 对齐时不同行高底边错开）
    .alignItems(VerticalAlign.Bottom)
    .width('90%')
    .padding(16)
    .backgroundColor('rgba(255, 209, 0, 0.05)')
    .border({ width: 1, color: 'rgba(255, 209, 0, 0.1)', radius: 8 })
    .margin({ bottom: 8 })
    .onClick(onClick)
  }
}
