// entry/src/main/ets/pages/MainTabs.ets
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { EntryConfigVM, EntryDef, isEntryAvailable } from '../viewmodels/EntryConfigVM'
import { HallViewModel } from '../viewmodels/HallViewModel'
import { DeityArrayView } from '../components/DeityArrayView'
import { DailyAlmanac } from '../components/DailyAlmanac'
import { CaiShenHallIcon } from '../components/CaiShenHallIcon'
import { PrivacyDialog } from '../components/PrivacyDialog'
import { BouncePage } from '../components/BouncePage'
import { FIVE_DEITIES } from '../model/PrayerTypes'
import { WishWallPage } from './WishWall'
import { QiuQianPage } from './QiuQian'
import { MuyuPage } from './MuyuPage'
import { FortuneAlmanacPage } from './FortuneAlmanacPage'
import { LeaderboardPage } from './Leaderboard'
import { EncyclopediaPage } from './EncyclopediaPage'
import { GameRecordPage } from './GameRecordPage'
import { MyPage } from './MyPage'
import { CaiShenHallPage } from './CaiShenHallPage'
import { PrivacyConsent } from '../util/PrivacyConsent'
import { router } from '@kit.ArkUI'

/** 祈福页神阵区顶部下限（vp）。「今日主财神」卡从屏顶按固定 vp 定位（底缘恒
 *  178 = 46 + 132），神阵却按内容区高的百分比定位——短屏上 30% 收缩后，顶部
 *  两神外圈（锚点上方探出约 58，为 48px 神的整列半高）会上移压进卡片底缘。
 *  下限 210 ≈ 卡底 178 + 外圈上探 58 − 短屏锚点上浮 0.06×内容高(≈36) + 10 余量，
 *  使外圈顶 ≥ 188 > 178。常规屏（30% ≥ 210 即内容高 ≥ 700）布局完全不变。 */
const BLESSING_ARRAY_MIN_TOP = 210

/**
 * 审核整改（2026-11-04）：底栏固定首位 Tab 由「祈福」临时改为「财神殿」。
 * 祈福页（BlessingSquare → NameCard 流程）保留在工程中，只是不再挂到底栏；
 * build() 的 blessing 分支与 TabBarBuilder 的元宝图标分支一并保留，便于恢复。
 * 审核通过后把下面两个常量改回 'blessing' / '祈福'，并清空
 * EntryConfigVM.AUDIT_HIDDEN_ENTRY_IDS 即可整体恢复。
 */
const FIXED_FIRST_TAB_ID: string = 'caishenhall'
const FIXED_FIRST_TAB_TITLE: string = '财神殿'

@Entry
@Component
struct MainTabs {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()
  @StorageLink('enrichViewModel') enrichVM: EnrichViewModel = new EnrichViewModel()
  @StorageLink('entryConfigVM') entryConfigVM: EntryConfigVM = new EntryConfigVM()
  // UI v1：@StorageLink 只观察顶层键，@Observed VM 嵌套变更不通知 UI。
  // VM 每次变更 bump entryConfigRev，这里 @Watch 后重建 tabDefs（@State）驱动刷新。
  @StorageLink('entryConfigRev') @Watch('onEntryConfigRev') entryConfigRev: number = 0
  // 桌面卡片深链（router 事件）：热启动靠 @Watch 触发切 Tab，冷启动在 aboutToAppear 补一次
  @StorageLink('pendingRoute') @Watch('onPendingRoute') pendingRoute: string = ''
  @State tabDefs: EntryDef[] = []
  @State currentTab: number = 0
  // 祈福画布（BouncePage 内容区）实测高：短屏时给神阵区顶部兜底，见 arrayZoneY()
  @State blessingCanvasH: number = 0
  private privacyDialogController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.syncTabs()
    // 当前激活入口 id 写入 AppStorage，供求签页判断是否激活
    // （摇晃出签只在求签入口激活时响应；Tab 可配置后索引不再固定，必须用 id）
    AppStorage.setOrCreate('activeEntryId', FIXED_FIRST_TAB_ID)
    // 冷启动：深链 flag 在 MainTabs 创建前就已写入 AppStorage，@Watch 不会触发，这里补一次
    // （放在默认值写入之后，否则刚切好的 activeEntryId 会被覆盖回固定首位）
    this.onPendingRoute()
    this.checkPrivacyAccepted()
  }

  /** 深链切 Tab：消费后立刻清空 flag，避免下次回前台重复跳转 */
  onPendingRoute(): void {
    const route: string = this.pendingRoute
    if (route === '') {
      return
    }
    this.pendingRoute = ''
    const idx: number = this.tabDefs.findIndex((d: EntryDef): boolean => d.id === route)
    if (idx >= 0) {
      this.currentTab = idx
      AppStorage.setOrCreate('activeEntryId', route)
      return
    }
    // 目标入口被用户关闭或审核期下线：降级回固定首位 Tab 并提示，不静默失败。
    // aboutToAppear 阶段 UI 未挂载完成，toast 可能抛异常——必须兜住，否则会中断
    // aboutToAppear 后续的 checkPrivacyAccepted（隐私弹窗是合规项）
    this.currentTab = 0
    AppStorage.setOrCreate('activeEntryId', this.activeIdOf(0))
    try {
      this.getUIContext().getPromptAction().showToast({
        message: '该入口暂未开放',
        duration: 3000
      })
    } catch (err) {
      console.error('[MainTabs] show toast failed:', JSON.stringify(err))
    }
  }

  /** VM 变更通知（AppStorage rev 信号）：重建 Tab 列表并校正当前索引 */
  onEntryConfigRev(): void {
    this.syncTabs()
  }

  /** 完整 Tab 列表：财神殿（审核期固定头）+ 已启用入口（按用户 order）+ 我的（固定尾）。
   *  审核整改：原固定头「祈福」不再挂到底栏；「还愿」在入口池侧下线，
   *  这里再按 isEntryAvailable 兜底过滤一次，防止老存档漏出已下线入口。 */
  private buildTabs(): EntryDef[] {
    const tabs: EntryDef[] = [
      { id: FIXED_FIRST_TAB_ID, icon: '🪙', title: FIXED_FIRST_TAB_TITLE }
    ]
    const enabled = this.entryConfigVM.getTabEntries()
    for (const e of enabled) {
      if (isEntryAvailable(e.id)) {
        tabs.push(e)
      }
    }
    tabs.push({ id: 'mine', icon: '🧧', title: '我的' })
    return tabs
  }

  /** 重建 tabDefs（@State 快照，UI 可靠刷新）并把 currentTab 收敛到有效范围 */
  private syncTabs(): void {
    const tabs = this.buildTabs()
    this.tabDefs = tabs
    if (this.currentTab >= tabs.length) {
      // 开启项被关闭导致尾部索引失效时收敛（「我的」固定在最后，正常总会落到它）
      this.currentTab = Math.max(0, tabs.length - 1)
    }
  }

  /** 从 EntryShell 返回时 Tab 未变、onChange 不触发，这里重新同步激活入口 id，
   *  避免 EntryShell 写入的 activeEntryId 残留导致摇晃门控误开 */
  onPageShow(): void {
    // 跨天回来刷新今日主神：当天内 no-op，跨天自动换（顶部主神牌+五神阵一起更新）
    this.viewModel.refreshTodayDeity()
    // 财神殿跨天重置（心意值清零 + 补发进殿奖励 + 主神轮换）
    const hall = AppStorage.get<HallViewModel>('hallVM')
    if (hall !== undefined && hall !== null) {
      hall.checkDaily()
      hall.refreshTodayDeity()
    }
    const activeId = this.activeIdOf(this.currentTab)
    AppStorage.setOrCreate('activeEntryId', activeId)
  }

  private activeIdOf(tabIndex: number): string {
    if (tabIndex >= 0 && tabIndex < this.tabDefs.length) {
      return this.tabDefs[tabIndex].id
    }
    return FIXED_FIRST_TAB_ID
  }

  private async checkPrivacyAccepted(): Promise<void> {
    let should: boolean = true
    try {
      // 读独立隐私文件（不依赖 PrayerViewModel 初始化，见 util/PrivacyConsent.ets）
      should = await PrivacyConsent.shouldPrompt()
    } catch (err) {
      console.error('[MainTabs] Failed to check privacy:', JSON.stringify(err))
      should = true
    }
    if (should) {
      this.openPrivacyDialog()
    }
  }

  private openPrivacyDialog(): void {
    this.privacyDialogController = new CustomDialogController({
      builder: PrivacyDialog({
        onAgree: () => {
          PrivacyConsent.accept().then((saved: boolean) => {
            if (!saved) {
              // 落盘失败必须让用户知道，否则下次启动仍会弹（旧实现就是静默失败→死循环）
              try {
                this.getUIContext().getPromptAction().showToast({
                  message: '隐私设置保存失败，请稍后重试',
                  duration: 3000
                })
              } catch (err) {
                console.error('[MainTabs] toast failed:', JSON.stringify(err))
              }
            }
          })
        },
        onClose: (): void => {
          // 关闭兜底：用本页持有的控制器引用关弹窗（Pura X 注入的 controller 可能为 undefined）
          const c = this.privacyDialogController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[MainTabs] privacy dialog onClose failed')
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
      // 叠加光晕仅为视觉装饰，必须置为不拦截触摸，否则会盖住下方 Tabs/按钮导致点击失效
      .hitTestBehavior(HitTestMode.None)
      .radialGradient({ center: ['50%', '12%'], radius: '58%', colors: [['rgba(255, 209, 0, 0.28)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]] })
  }


  build() {
    Column() {
      Tabs({ index: this.currentTab }) {
        // 全部 Tab 由 tabDefs 统一驱动（财神殿/我的固定项也在列表内，按 id 分支内容）
        // 审核期祈福分支保留但不挂载：tabDefs 里不再产生 blessing 项
        ForEach(this.tabDefs, (def: EntryDef, idx: number) => {
          TabContent() {
            if (def.id === 'blessing') {
              // 祈福页为固定全屏布局：BouncePage 内容恒比视口高 8vp（实测视口+8），
              // 滚动区间 >0，上下滑动到边界必有 Spring 回弹（AGC「滑动动效」标准）
              BouncePage() {
                this.BlessingSquare()
              }
            } else if (def.id === 'mine') {
              MyPage()
            } else {
              // 中间可配置 Tab（由「界面定制」子页控制开关与排序）
              this.EntryContent(def.id)
            }
          }
          .tabBar(this.TabBarBuilder(idx, def))
        }, (def: EntryDef) => def.id)
      }
      // 底部导航栏：Tabs 默认 BarPosition.Start 渲染在顶部，沉浸式下易与状态栏重叠
      // 导致点击不响应；显式指定 End 让 Tab 栏落在底部可点击安全区。
      .barPosition(BarPosition.End)
      // barHeight 含底部手势导航条高度，配合 TabBarBuilder 内 padding({bottom}) 把
      // 图标/文字顶到安全区上方（下缘距屏底 ≥28vp），避免与手势条/三键导航重叠。
      .barHeight(84)
      .barMode(BarMode.Fixed)
      // barBackgroundColor 只支持纯色；渐变底改由 TabBarBuilder 内自绘，
      // 这里置透明避免纯色盖住渐变
      .barBackgroundColor(Color.Transparent)
      // 滑到首尾 Tab 边界时回弹，满足 AGC「滑动到边界有反馈动效」质量标准
      .edgeEffect(EdgeEffect.Spring)
      .onChange((index: number) => {
        this.currentTab = index
        const activeId = this.activeIdOf(index)
        AppStorage.setOrCreate('activeEntryId', activeId)
      })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#A01124', 0.0], ['#931120', 0.55], ['#86121C', 1.0]] })
    .overlay(this.GlowOverlay)
  }

  /** 可配置入口的 Tab 内容（按入口 id 分发） */
  @Builder
  EntryContent(id: string) {
    if (id === 'qiuqian') {
      // 求签页同为固定全屏布局：BouncePage 内容恒超视口 8vp，上下边界有回弹
      BouncePage() {
        QiuQianPage()
      }
    } else if (id === 'muyu') {
      // 木鱼页固定全屏：同上，BouncePage 保证滑动到边界有回弹反馈
      BouncePage() {
        MuyuPage()
      }
    } else if (id === 'fortune') {
      FortuneAlmanacPage()
    } else if (id === 'wishwall') {
      WishWallPage()
    } else if (id === 'leaderboard') {
      LeaderboardPage()
    } else if (id === 'encyclopedia') {
      EncyclopediaPage()
    } else if (id === 'gamerecord') {
      // 收支记录：与「我的」页置顶卡片共用同一份数据（同 enrichViewModel）
      GameRecordPage()
    } else if (id === 'caishenhall') {
      // 财神殿：常驻沉浸页，不包 BouncePage（全屏沉浸、不加回弹）
      CaiShenHallPage()
    }
  }

  @Builder
  TabBarBuilder(index: number, def: EntryDef) {
    Stack() {
      // Tab 栏渐变底：顶部取 app_icon 背景渐变的观感均值 #931120，底部落回页面渐变的
      // #86121C，整条栏与页面/图标同属一套红。每个 Tab 项各自铺满同一条竖直渐变，
      // 并排后视觉上连成一条，这样选中项的金色高亮还能叠在渐变之上。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#931120', 0.0], ['#86121C', 1.0]] })

      // 选中项金色高亮：单独一层叠加，不能用 backgroundColor（会盖掉渐变）
      if (this.currentTab === index) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(255, 209, 0, 0.08)')
      }

      Column() {
        if (def.id === 'muyu') {
          // 木鱼入口：真实木鱼图（emoji 无木鱼字形，🪵 会看成木头）
          Image($rawfile('props/muyu.png'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        } else if (def.id === 'blessing') {
          // 祈福入口：金元宝自绘图（emoji 无元宝字形，贴合财神保佑主题）
          Image($rawfile('props/yuanbao.png'))
            .width(24)
            .height(24)
            .objectFit(ImageFit.Contain)
        } else if (def.id === 'caishenhall') {
          // 财神殿入口：方孔铜钱·財自绘图标（金圆方孔+財字），替代 emoji 🏯（日式城堡）
          CaiShenHallIcon({ iconSize:24 })
        } else {
          Text(def.icon)
            .fontSize(22)
            .fontColor('#FFD700')
        }
        // Tab 宽度随项数压缩（最多 5 项），优先取 tabTitle 短标题并单行截断
        Text(def.tabTitle ?? def.title)
          .fontSize(10)
          // 未选中文字 0.72：渐变最亮端 #931120 上对比度 4.88（0.62 只有 3.95，低于 AGC 4.5 线）
          .fontColor(this.currentTab === index ? '#FFD700' : 'rgba(253, 246, 227, 0.72)')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 3 })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 8, bottom: 32 }) // bottom 留出手势导航条空间，图标/文字下缘距屏底 ≥28vp
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  /** 神阵区顶部 y：常规屏维持 30%（原设计不变）；短屏（30% 高 < 210vp）时
   *  提到 210vp 下限，保证顶部两神外圈不压进「今日主财神」卡（底缘 178vp） */
  private arrayZoneY(): Length {
    if (this.blessingCanvasH <= 0) {
      return '30%'
    }
    return Math.max(this.blessingCanvasH * 0.3, BLESSING_ARRAY_MIN_TOP)
  }

  @Builder
  BlessingSquare() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#A01124', 0.0], ['#931120', 0.55], ['#86121C', 1.0]] })
        .overlay(this.GlowOverlay)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 黄历卡片
      DailyAlmanac({ enrichVM: $enrichVM })

      // 五神弧形阵（显式顶锚：避免 Stack 居中把阵型下沉压到副标题；常规屏 30% 让出顶部
      // 「今日主财神」卡片高度，短屏由 arrayZoneY() 兜底 210vp 防顶部两神外圈压进卡片）
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
      .position({ x: 0, y: this.arrayZoneY() })

      // 副标题
      Text('「心诚则灵，财运亨通」')
        .fontSize(14)
        .fontColor('rgba(255, 209, 0, 0.85)')
        .fontStyle(FontStyle.Italic)
        .position({ x: '50%', y: '78%' })
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
      .shadow({ radius: 20, color: 'rgba(255, 209, 0, 0.4)', offsetY: 4 })
      .onClick(() => {
        this.viewModel.startPrayer()
        setTimeout(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/NameCard' }, router.RouterMode.Standard)
        }, 0)
      })
      .position({ x: '50%', y: '84%' })
      .translate({ x: '-50%', y: '-50%' })
    }
    .width('100%')
    .height('100%')
    // 实测祈福画布高（BouncePage 视口 + 8 回弹余量）：arrayZoneY() 短屏兜底的依据
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      const h: number = Number(newArea.height) || 0
      if (h > 0 && Math.abs(h - this.blessingCanvasH) > 0.5) {
        this.blessingCanvasH = h
      }
    })
  }
}
