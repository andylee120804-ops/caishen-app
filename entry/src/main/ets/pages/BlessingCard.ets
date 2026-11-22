import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { ParticleCanvas, ParticleType } from '../components/ParticleCanvas'
import { LanternView, RisingLantern } from '../components/LanternView'
import { ConfettiRain } from '../components/ConfettiRain'
import { AudioManager } from '../service/AudioManager'
import { DeityInfo } from '../model/PrayerTypes'
import { router } from '@kit.ArkUI'

/**
 * 叩拜结束 · 万灯结彩结算页（方案二「喜庆民俗」，预览稿 blessing-end-preview.html）。
 *
 * 核心叙事：宫灯升起的热闹夜景中，大灯笼落下悬起受福人名牌，
 * 祝福语逐字蹦出（姓名二字金色），把"狠狠的祝福"砸到人身上。
 *
 * 动效分层：
 * - 入场编排（按钮 ~1s 可操作）：顶栏 -> 大灯笼落下 -> 名牌弹入 -> 金榜横向开卷
 *   （方案一卷轴展开：裁剪容器宽度 30->322，面板固定不变形，文字随中缝露出
 *   且与逐字蹦出叠加进行，与预览稿 clip-path 展开等效）
 * - 常驻氛围（永不静止）：上升宫灯 x6 与彩纸雨由子组件 setInterval 循环驱动
 *   （勿用 @State 数组 + animateTo iterations:-1 —— 真机上不生效，
 *   2026-10-29 踩坑）；灯笼摇摆 / 大灯笼悬摆为 iterations:-1 增强层；
 *   烟花金点为现有粒子层
 *
 * 对比度均按华为 UX 标准实测（金字红底 5.76 / 米白红底 7.49 / 小字 .85 ≥5.16）。
 */
interface RisingLanternSpec {
  x: number         // 水平位置（vp，屏宽 390 内）
  char: string
  scale: number     // 视觉缩放（position 布局不受影响，错开大小）
  durationMs: number // 单程上升时长（循环相位由 duration 差异自然漂移）
  delayMs: number   // 首轮起跑延迟
}

const RISING_LANTERNS: RisingLanternSpec[] = [
  { x: 22, char: '福', scale: 0.70, durationMs: 12000, delayMs: 0 },
  { x: 88, char: '财', scale: 0.55, durationMs: 15000, delayMs: 500 },
  { x: 152, char: '吉', scale: 0.80, durationMs: 13000, delayMs: 1000 },
  { x: 222, char: '祥', scale: 0.65, durationMs: 11000, delayMs: 1600 },
  { x: 292, char: '运', scale: 0.75, durationMs: 14000, delayMs: 2200 },
  { x: 346, char: '旺', scale: 0.50, durationMs: 16000, delayMs: 2800 }
]

/** 逐字蹦出的间隔与单字动画时长 */
const CHAR_TICK_MS = 45
const CHAR_ANIM_MS = 220

@Entry
@Component
struct BlessingCard {
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()

  // ── 入场编排状态 ──
  @State headerShown: boolean = false
  @State bigLanternShown: boolean = false
  @State plaqueShown: boolean = false
  @State panelShown: boolean = false
  @State footerShown: boolean = false
  @State showFirework: boolean = false
  @State visibleChars: number = 0
  /** 金榜开卷：裁剪容器宽度（面板固定 322vp，容器从中缝向两侧展开露出内容） */
  @State panelRevealWidth: number = 30

  // ── 常驻氛围状态（上升宫灯/彩纸由子组件自驱动画） ──
  @State bigLanternRot: number = -3.5

  // ── 祝福语/心愿逐字数据（aboutToAppear 填充，非响应式；visibleChars 跨两段计数） ──
  private blessChars: string[] = []
  private wishChars: string[] = []
  private nameStart: number = -1
  private nameLen: number = 0
  private charTimerId: number = -1
  private timerIds: number[] = []

  aboutToAppear(): void {
    // 逐字数据：姓名区间用于金字高亮（indexOf 未命中则不高亮，安全兜底）；
    // 祝福语与心愿共用一套 visibleChars 计数，心愿紧接祝福语逐字蹦出
    this.blessChars = Array.from(this.viewModel.blessing)
    this.wishChars = Array.from(this.viewModel.wish)
    this.nameStart = this.viewModel.blessing.indexOf(this.viewModel.userName)
    this.nameLen = this.viewModel.userName.length

    // ── 入场编排（AGC 点击完成时延预算内，按钮 ~1s 可操作） ──
    this.trackTimeout(0, () => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.headerShown = true
      })
    })
    this.trackTimeout(150, () => { this.showFirework = true })
    this.trackTimeout(200, () => {
      this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.bigLanternShown = true
      })
    })
    this.trackTimeout(500, () => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.plaqueShown = true
      })
    })
    this.trackTimeout(750, () => {
      // 祝福金榜横向开卷（方案一卷轴展开）：裁剪容器宽度 30 -> 322，
      // 面板本体固定 322vp 零变形，文字随中缝展开逐渐露出（与预览稿 clip-path 同效）
      this.getUIContext().animateTo({ duration: 500, curve: Curve.EaseOut }, () => {
        this.panelShown = true
        this.panelRevealWidth = 322
      })
    })
    this.trackTimeout(800, () => { this.startCharTicker() })
    this.trackTimeout(1050, () => {
      this.getUIContext().animateTo({ duration: 380, curve: Curve.EaseOut }, () => {
        this.footerShown = true
      })
    })

    // ── 常驻氛围：上升宫灯由 RisingLantern 子组件自驱（setInterval 循环保底，
    //    不依赖 @State 数组 + iterations:-1 —— 后者真机不生效，见文件头注释） ──

    // ── 常驻氛围：大灯笼悬摆（入场落下由 bigLanternShown 单独驱动） ──
    this.getUIContext().animateTo({
      duration: 4600,
      curve: Curve.EaseInOut,
      playMode: PlayMode.Alternate,
      delay: 200,
      iterations: -1
    }, () => {
      this.bigLanternRot = 3.5
    })
  }

  aboutToDisappear(): void {
    if (this.charTimerId !== -1) {
      clearInterval(this.charTimerId)
      this.charTimerId = -1
    }
    for (const id of this.timerIds) {
      clearTimeout(id)
    }
    this.timerIds = []
  }

  /** 统一登记 setTimeout，便于离场时清理，防 orphan 定时器 */
  private trackTimeout(ms: number, fn: () => void): void {
    const id: number = setTimeout(fn, ms)
    this.timerIds.push(id)
  }

  /** 祝福语+心愿逐字蹦出：每 45ms 显一字，单字 220ms 淡入 + 弹跳缩放 */
  private startCharTicker(): void {
    const total: number = this.blessChars.length + this.wishChars.length
    this.charTimerId = setInterval(() => {
      if (this.visibleChars >= total) {
        clearInterval(this.charTimerId)
        this.charTimerId = -1
        return
      }
      this.getUIContext().animateTo({ duration: CHAR_ANIM_MS, curve: Curve.EaseOut }, () => {
        this.visibleChars += 1
      })
    }, CHAR_TICK_MS)
  }

  /** 该序号字符是否落在姓名区间（用于金色高亮） */
  private isNameChar(idx: number): boolean {
    return this.nameStart >= 0 && this.nameLen > 0 &&
      idx >= this.nameStart && idx < this.nameStart + this.nameLen
  }

  /** 金榜最小高：按祝福语/心愿字数预估行数（约 13 字/行、心愿约 14 字/行），
      开卷时框体已是最终尺寸；
      行高*行数 + 双线框开销(外框2+垫3+内框1，上下共12) + 内边距(上18下14共32) + 尾联行富余 32
      + 心愿区（label 行 26 + 心愿行高，无心愿时为 0） */
  private panelMinHeight(): number {
    const lines: number = Math.max(1, Math.ceil(this.blessChars.length / 13))
    let height: number = lines * 36 + 76
    if (this.wishChars.length > 0) {
      const wishLines: number = Math.max(1, Math.ceil(this.wishChars.length / 14))
      height += 26 + wishLines * 30
    }
    return height
  }

  private repeatPrayer(): void {
    // 再拜一次必须保留姓名与选神：repeat 模式跳过 NameCard 直接重拜，
    // 若被 resetPrayer 清空 userName，重拜完成后 getBlessing(id, '') 会把
    // 祝福语里的【祈福者】替换成空串、名牌回退成"善信"——与输入框内容不吻合
    //（2026-10-29 真机反馈）。confirmName 仅恢复姓名与阶段，祝福语由
    // onAnimationComplete 重新随机生成，不在此生成。
    const name: string = this.viewModel.userName
    const deity: DeityInfo | null = this.viewModel.selectedDeity
    const wish: string = this.viewModel.wish
    this.viewModel.resetPrayer()
    this.viewModel.confirmName(name)
    this.viewModel.selectDeity(deity)
    this.viewModel.confirmWish(wish)
    // 延迟导航到下一帧，让按钮点击反馈先渲染
    setTimeout(() => {
      this.getUIContext().getRouter().replaceUrl({
        url: 'pages/PrayerCard',
        params: { repeat: true }
      }, router.RouterMode.Standard)
    }, 0)
  }

  private backHome(): void {
    this.viewModel.resetPrayer()
    // 延迟音频停止和导航到下一帧，让按钮点击反馈先渲染
    setTimeout(() => {
      AudioManager.getInstance().stopBgm()
      this.getUIContext().getRouter().clear()
      this.getUIContext().getRouter().pushUrl({ url: 'pages/MainTabs' }, router.RouterMode.Standard)
    }, 0)
  }

  @Builder
  GlowOverlay() {
    Column()
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .radialGradient({ center: ['50%', '12%'], radius: '58%', colors: [['rgba(255, 209, 0, 0.28)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]] })
  }

  build() {
    Stack() {
      // ── 背景：暖红夜景（延伸至安全区，消除白边） ──
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: [['#b82333', 0.0], ['#931120', 0.52], ['#580e15', 1.0]] })
        .overlay(this.GlowOverlay)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // ── 常驻氛围层：上升宫灯 x6（子组件 setInterval 自驱循环，真机可靠） ──
      Stack() {
        ForEach(RISING_LANTERNS, (spec: RisingLanternSpec, idx: number) => {
          RisingLantern({
            x: spec.x,
            char: spec.char,
            scaleVal: spec.scale,
            durationMs: spec.durationMs,
            delayMs: spec.delayMs
          })
        }, (spec: RisingLanternSpec, idx: number) => 'lantern' + idx.toString())
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)

      // ── 常驻氛围层：烟花 + 金点 + 彩纸雨 ──
      ParticleCanvas({
        particleType: ParticleType.FIREWORK,
        isActive: this.showFirework
      })

      ParticleCanvas({
        particleType: ParticleType.GOLD,
        isActive: this.showFirework
      })

      ConfettiRain({ isActive: this.showFirework })

      // ── 主内容 ──
      Column() {
        // 顶栏祝语
        Text('✦  万灯结彩 · 福星高照  ✦')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .letterSpacing(3)
          .opacity(this.headerShown ? 1 : 0)
          .translate({ y: this.headerShown ? 0 : 26 })

        // 财神徽章：本次坐镇的财神
        Text(`🧧 ${this.viewModel.activeDeity().direction}财神 · ${this.viewModel.activeDeity().name} 坐镇`)
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .letterSpacing(1)
          .margin({ top: 4 })
          .opacity(this.headerShown ? 1 : 0)
          .translate({ y: this.headerShown ? 0 : 26 })

        // 中央大灯笼：落下入场 + 常驻悬摆
        Column() {
          LanternView({
            char: '福',
            bodyWidth: 96,
            bodyHeight: 104,
            fontSize: 42,
            withTassel: false
          })
        }
        .margin({ top: 10 })
        .rotate({ angle: this.bigLanternRot })
        .translate({ y: this.bigLanternShown ? 0 : -60 })
        .opacity(this.bigLanternShown ? 1 : 0)

        // 挂穗线 ×2（连大灯笼底与名牌顶）
        Row() {
          Row().width(2).height(26).backgroundColor('rgba(255, 209, 0, 0.8)')
          Row().width(2).height(26).backgroundColor('rgba(255, 209, 0, 0.8)')
        }
        .width(220)
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 2 })
        .opacity(this.plaqueShown ? 1 : 0)

        // 受福人名牌：本页绝对主角之一
        Column() {
          Text('受 福 之 人')
            .fontSize(12)
            .fontColor('rgba(255, 209, 0, 0.85)')
            .letterSpacing(6)
            .margin({ bottom: 3 })
          Text(this.viewModel.userName || '善信')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
            .textShadow({ radius: 14, color: 'rgba(255, 209, 0, 0.55)', offsetX: 0, offsetY: 0 })
        }
        .width(220)
        .padding({ top: 9, bottom: 12 })
        .alignItems(HorizontalAlign.Center)
        .linearGradient({ angle: 180, colors: [['#8e1727', 0.0], ['#7d0e1c', 1.0]] })
        .border({ width: 1.5, color: '#FFD700', radius: 12 })
        .shadow({ radius: 22, color: 'rgba(0, 0, 0, 0.4)', offsetX: 0, offsetY: 6 })
        .margin({ top: -1 })
        .opacity(this.plaqueShown ? 1 : 0)
        .scale({ x: this.plaqueShown ? 1 : 0.9, y: this.plaqueShown ? 1 : 0.9 })

        // 祝福金榜：古书卷轴式横向开卷（与预览稿 clip-path inset 同效）
        // 三层结构：
        //   外层 Stack（不裁剪）：承载左右卷轴杆，杆随开卷从中间滚向两侧；
        //   裁剪 Stack：宽度 30 -> 322 动画，内容从中缝向两侧逐渐露出；
        //   金榜本体：固定 322vp 零变形，双线金框（外 2px 亮金 + 内 1px 暗金），
        //             文字在场，逐字蹦出与开卷叠加进行（预览稿同款时序）。
        Stack({ alignContent: Alignment.Center }) {
          Stack({ alignContent: Alignment.Center }) {
            Column() {                        // 外框：亮金 2px
              Column() {                      // 内框：暗金 1px
                Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Center }) {
                  ForEach(this.blessChars, (ch: string, idx: number) => {
                    Text(ch)
                      .fontSize(20)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.isNameChar(idx) ? '#FFD700' : '#fdf6e3')
                      .lineHeight(36)
                      .margin({ right: 1 })
                      .opacity(idx < this.visibleChars ? 1 : 0)
                      .scale({
                        x: idx < this.visibleChars ? 1 : 0.5,
                        y: idx < this.visibleChars ? 1 : 0.5
                      })
                  }, (ch: string, idx: number) => 'char' + idx.toString())
                }
                .width('100%')

                // 心愿区：用户在 NameCard 输入框亲手写下的心愿，同步进金榜（无心愿时整段隐藏）
                if (this.wishChars.length > 0) {
                  Column() {
                    Text('心 之 所 愿')
                      .fontSize(11)
                      .fontColor('rgba(255, 209, 0, 0.85)')
                      .letterSpacing(4)
                      .margin({ top: 10, bottom: 4 })
                      .opacity(this.visibleChars > this.blessChars.length ? 1 : 0)
                    Flex({ wrap: FlexWrap.Wrap, direction: FlexDirection.Row, justifyContent: FlexAlign.Center }) {
                      ForEach(this.wishChars, (ch: string, j: number) => {
                        Text(ch)
                          .fontSize(18)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#ffe9a0')
                          .lineHeight(30)
                          .margin({ right: 1 })
                          .opacity(this.blessChars.length + j < this.visibleChars ? 1 : 0)
                          .scale({
                            x: this.blessChars.length + j < this.visibleChars ? 1 : 0.5,
                            y: this.blessChars.length + j < this.visibleChars ? 1 : 0.5
                          })
                      }, (ch: string, j: number) => 'wish' + j.toString())
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Center)
                }

                Text('红灯高照  ·  福运绵长')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFD700')
                  .letterSpacing(4)
                  .margin({ top: 12 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Center)
              .padding({ left: 15, right: 15, top: 18, bottom: 14 })
              .backgroundColor('rgba(56, 4, 12, 0.68)')
              .border({ width: 1, color: 'rgba(255, 209, 0, 0.45)', radius: 9 })
            }
            .width(322)
            .constraintSize({ minHeight: this.panelMinHeight() })
            .alignItems(HorizontalAlign.Center)
            .padding(3)
            .border({ width: 2, color: '#FFD700', radius: 11 })
            .opacity(this.panelShown ? 1 : 0.3)
          }
          .width(this.panelRevealWidth)
          .clip(true)

          // 左右卷轴杆：贴开卷边缘滚动（translate 跟随 panelRevealWidth 同步动画）。
          // 刻意用内联写法而非 @Builder——@Builder 内 this 状态绑定的刷新语义
          // 无需依赖（杆卡在中间=明显穿帮），内联与页面其它动画属性同一机制最稳。
          Column() {
            Row()
              .width(13)
              .height(7)
              .backgroundColor('#FFD700')
              .borderRadius(3.5)
            Column()
              .width(9)
              .layoutWeight(1)
              .linearGradient({ angle: 0, colors: [['#8a6d3b', 0.0], ['#e0c06a', 0.5], ['#8a6d3b', 1.0]] })
              .borderRadius(4.5)
            Row()
              .width(13)
              .height(7)
              .backgroundColor('#FFD700')
              .borderRadius(3.5)
          }
          .alignItems(HorizontalAlign.Center)
          .height(this.panelMinHeight() + 14)
          .translate({ x: -1 * (this.panelRevealWidth / 2 + 6) })
          .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.5)', offsetX: 0, offsetY: 0 })
          .opacity(this.panelShown ? 1 : 0.35)

          Column() {
            Row()
              .width(13)
              .height(7)
              .backgroundColor('#FFD700')
              .borderRadius(3.5)
            Column()
              .width(9)
              .layoutWeight(1)
              .linearGradient({ angle: 0, colors: [['#8a6d3b', 0.0], ['#e0c06a', 0.5], ['#8a6d3b', 1.0]] })
              .borderRadius(4.5)
            Row()
              .width(13)
              .height(7)
              .backgroundColor('#FFD700')
              .borderRadius(3.5)
          }
          .alignItems(HorizontalAlign.Center)
          .height(this.panelMinHeight() + 14)
          .translate({ x: 1 * (this.panelRevealWidth / 2 + 6) })
          .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.5)', offsetX: 0, offsetY: 0 })
          .opacity(this.panelShown ? 1 : 0.35)
        }
        .margin({ top: 16 })

        // 诚心徽章
        Text(`🙏 诚心叩拜 ${this.viewModel.kowtowCount} 次 · 心意已至`)
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .letterSpacing(1)
          .margin({ top: 14 })
          .opacity(this.footerShown ? 1 : 0)
          .translate({ y: this.footerShown ? 0 : 12 })

        // 操作：主按钮独占一排，「返回首页」为下方小字
        Button('🙇  再拜一次')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .backgroundColor('rgba(255, 209, 0, 0.12)')
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.6)', radius: 24 })
          .height(44)
          .padding({ left: 34, right: 34 })
          .margin({ top: 12 })
          .opacity(this.footerShown ? 1 : 0)
          .translate({ y: this.footerShown ? 0 : 12 })
          .onClick(() => this.repeatPrayer())

        Button('返回首页')
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .backgroundColor(Color.Transparent)
          .height(28)
          .margin({ top: 6 })
          .opacity(this.footerShown ? 1 : 0)
          .onClick(() => this.backHome())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      // 底部避让 ≥76vp：短屏上居中内容会向两端溢出，bottom padding 不足会把
      // 「返回首页」压进小艺呼出条区域（约屏底 34vp，2026-10-29 真机反馈）；
      // 顶部 padding 同步减小，整体观感上移
      .padding({ top: 14, bottom: 76 })
    }
    .width('100%')
    .height('100%')
  }
}
