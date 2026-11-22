// entry/src/main/ets/pages/CaiShenHallPage.ets
// 财神殿 Tab 主页（常驻，在「祈福」之后）。
//
// v9 审核整改（2026-10-27）：
//   · 财神殿付费陈设/装扮入口全部隐藏（实现保留在 DecorPayDialog / HallViewModel，日后方案明确再启用）；
//   · 保留免费上香（心意值），新增「写下祈福话 → 生成电子祈福图 → 保存到手机」；
//   · 页面只保留：匾额 → 神像 → 香炉 → 写祈福话入口 → 心意值/今日上香。
//
// 元素：AI 大殿背景图 / 神像呼吸光晕 / 匾额 / 财神像 / 供桌 / 正中香炉 / 心意值条。
// 合规铁律：灯与香绝不售卖，屏幕上看不到「钱换香」的因果链；心意值每日清零、靠每日行为获取。
import { HallViewModel } from '../viewmodels/HallViewModel'
import { BlessingImageDialog } from '../components/BlessingImageDialog'

@Component
export struct CaiShenHallPage {
  @StorageLink('hallVM') hallVM: HallViewModel = new HallViewModel()
  @StorageLink('hallRev') @Watch('onRev') hallRev: number = 0

  // 上香状态：香火一旦点上就常驻（当日再次进殿也会保持）
  @State incenseLit: boolean = false
  @State stickDown: boolean = false
  @State emberOn: boolean = false
  @State smokePhase: number = 0   // 连续相位 0..35，驱动香烟「升起→消散」单向循环
  private smokeTimer: number = -1
  /** 一次性定时器集合（上香分步动画/飘字），页面销毁时统一清理，避免对已销毁组件写状态 */
  private timers: number[] = []

  // 神像呼吸光晕
  @State glowOn: boolean = false
  private glowTimer: number = -1

  // toast
  @State toastText: string = ''
  @State toastVisible: boolean = false
  private toastTimer: number = -1

  /** 祈福图弹窗控制器（持有引用，避免弹窗存活期间控制器被回收） */
  private blessingController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.hallVM.checkDaily()
    this.hallVM.refreshTodayDeity()
    // 当天已经上过香 → 直接呈现「香火正旺」
    this.incenseLit = this.hallVM.sticksToday > 0
    if (this.incenseLit) {
      this.stickDown = true
      this.emberOn = true
      this.startSmoke()
    }
    this.glowTimer = setInterval(() => {
      this.glowOn = !this.glowOn
    }, 2250)
  }

  aboutToDisappear(): void {
    if (this.smokeTimer >= 0) {
      clearInterval(this.smokeTimer)
      this.smokeTimer = -1
    }
    if (this.glowTimer >= 0) {
      clearInterval(this.glowTimer)
      this.glowTimer = -1
    }
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
      this.toastTimer = -1
    }
    for (const id of this.timers) {
      clearTimeout(id)
    }
    this.timers = []
  }

  /** 记录一次性定时器，便于页面销毁时统一清理 */
  private later(cb: () => void, ms: number): void {
    this.timers.push(setTimeout(cb, ms))
  }

  onRev(): void {
  }

  // ── 上香 ──
  private onCenser(): void {
    if (this.incenseLit) {
      this.toast('心意正暖 · 财源广进')
      return
    }
    if (!this.hallVM.beginIncense()) {
      this.toast('心意值不足 · 每日进殿可积攒')
      return
    }
    // 心意与支数立即落账，避免中途离开页面丢失回向
    this.hallVM.completeIncense()
    this.incenseLit = true
    this.stickDown = false
    this.emberOn = false
    // 下一帧滑入，避免条件创建时动画被跳过
    this.later(() => {
      this.stickDown = true
    }, 16)
    this.later(() => {
      this.emberOn = true
    }, 260)
    this.later(() => {
      this.startSmoke()
    }, 300)
    this.toast('香已入炉 · 写下祈福话吧')
  }

  private startSmoke(): void {
    if (this.smokeTimer >= 0) {
      return
    }
    this.smokePhase = 0
    this.smokeTimer = setInterval(() => {
      this.smokePhase = (this.smokePhase + 1) % 36
    }, 260)
  }

  /** 第 i 团烟的上升进度 t∈[0,1)：相位错开 1/6，走完一圈回卷到香头（消散后再现，视觉连续） */
  private smokeT(i: number): number {
    return ((this.smokePhase + i * 6) % 36) / 36
  }

  /** 第 i 团烟的可见度：出生淡入 + 顶端消散，两端都为 0 → 回卷瞬间的「上→下」位移全程不可见，不会出现烟往下掉 */
  private smokeOp(i: number): number {
    const t = this.smokeT(i)
    const fadeIn = Math.min(t / 0.10, 1)                // t∈[0,0.10] 淡入
    const fadeOut = Math.max(0, 1 - (t - 0.75) / 0.25)  // t∈[0.75,1] 消散
    return 0.72 * fadeIn * fadeOut
  }

  // ── 财神像 / 祈福按钮 → 写祈福话并生成电子祈福图 ──
  private openBlessingImage(): void {
    if (!this.incenseLit) {
      this.toast('先上一炷香，再写下祈福话')
      return
    }
    // 防叠加：弹窗未关时忽略重复点击，等 onClosed 释放引用后再开
    if (this.blessingController !== null) {
      return
    }
    const dlg = new CustomDialogController({
      builder: BlessingImageDialog({
        deityId: this.hallVM.todayDeity.id,
        deityName: this.hallVM.todayDeity.name,
        deityDirection: this.hallVM.todayDeity.direction,
        initialTemplate: this.hallVM.blessingTemplate,
        onTemplateChange: (t: number): void => {
          this.hallVM.setBlessingTemplate(t)
        },
        onClose: (): void => {
          // 关闭兜底：用本页持有的引用关掉弹窗（该引用必然有效）
          const c = this.blessingController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[Hall] blessing dialog onClose failed')
            }
          }
        },
        onClosed: (): void => {
          this.blessingController = null
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.blessingController = dlg
    dlg.open()
  }

  private toast(msg: string): void {
    this.toastText = msg
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 2200)
  }

  build() {
    Stack() {
      // ══ 背景层：只有背景延伸到状态栏/手势条下，内容保持在安全区内 ══
      Image($rawfile('props/hall_bg.png'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 压暗叠层（增强前景对比）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(20, 4, 6, 0.46)', 0.0],
            ['rgba(20, 4, 6, 0.10)', 0.22],
            ['rgba(20, 4, 6, 0)', 0.46],
            ['rgba(20, 4, 6, 0.16)', 1.0]
          ]
        })
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .hitTestBehavior(HitTestMode.None)

      // 顶部金色光晕（halo）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '10%'],
          radius: '60%',
          colors: [['rgba(255, 209, 0, 0.30)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .hitTestBehavior(HitTestMode.None)

      // ══ 内容：固定分区 + 弹性舞台 ══
      // 沉浸式全屏下页面内容从 y=0 起排，Pura X 内屏前置摄像头为中置挖孔，
      // 必须整体下移避开状态栏/挖孔（与 MyPage/其余 Tab 页同一套 44vp 顶部安全距）。
      Column() {
        // 匾额
        Text('財神殿')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .letterSpacing(8)
          .width(150)
          .height(44)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor('#3c0a10')
          .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.55)' })
          .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.45)' })
          .margin({ top: 12, bottom: 8 })

        // 舞台：神像 58% / 空隙 12% / 香炉 30%，互不侵占（空隙保底：香柱上端 42vp 不触神像）
        Column() {
          // 财神像 + 呼吸光晕（点香后可点，写下祈福话）
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width(260)
              .height('100%')
              .radialGradient({
                center: ['50%', '55%'],
                radius: '58%',
                colors: [['rgba(255, 209, 0, 0.30)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]]
              })
              .opacity(this.glowOn ? 1 : 0.82)
              .animation({ duration: 2250, curve: Curve.EaseInOut })
              .hitTestBehavior(HitTestMode.None)
            Image($rawfile(`deities/${this.hallVM.todayDeity.id}.png`))
              .height('100%')
              .aspectRatio(1)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height('58%')
          .constraintSize({ maxHeight: 220 })
          .onClick(() => this.openBlessingImage())

          Blank()
            .layoutWeight(1)

          // 供桌 + 香炉（整组可点，香从炉口插入）
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              // 香柱：下端插入炉口，炉身图后绘制会盖住下半截
              if (this.incenseLit) {
                Column() {
                  Column()
                    .width(8)
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#FF7B39')
                    .radialGradient({
                      center: ['50%', '45%'],
                      radius: '55%',
                      colors: [
                        ['#fff3c4', 0.0],
                        ['#ffd08a', 0.28],
                        ['#ff7a34', 0.62],
                        ['#b33a1c', 1.0]
                      ]
                    })
                    .shadow({ radius: 6, color: 'rgba(255, 140, 50, 0.75)' })
                    .scale({
                      x: 1 + 0.15 * (1 + Math.sin(this.smokePhase * Math.PI / 18)) / 2,
                      y: 1 + 0.15 * (1 + Math.sin(this.smokePhase * Math.PI / 18)) / 2
                    })
                    .opacity(this.emberOn ? 1 : 0)
                    .animation({ duration: 260, curve: Curve.EaseInOut })
                  Column()
                    .width(4)
                    .height(60)
                    .borderRadius(2)
                    .backgroundColor('#8A5A34')
                }
                .width(10)
                .position({ x: '50%', y: -42 })
                .translate({ x: -5, y: this.stickDown ? 0 : -40 })
                .opacity(this.stickDown ? 1 : 0)
                .animation({ duration: 280, curve: Curve.EaseOut })
              }

              // 空炉（原 incense_burner.png 自带三炷香，已另存空炉素材）
              Image($rawfile('props/censer_empty.png'))
                .height('100%')
                .aspectRatio(327 / 219)
                .objectFit(ImageFit.Contain)

              // 香烟：细烟线 + 6 团烟柱单向上升消散（非来回摆动）
              if (this.incenseLit) {
                // 细烟线：香头上方一缕轻烟，随烟柱周期轻微呼吸
                Column()
                  .width(2)
                  .height(16)
                  .borderRadius(1)
                  .backgroundColor('rgba(255, 255, 255, 0.30)')
                  .position({ x: '50%', y: -56 })
                  .translate({ x: -1 })
                  .opacity(0.42 + 0.18 * Math.sin(this.smokePhase * Math.PI / 18))
                  .animation({ duration: 260, curve: Curve.Linear })
                  .hitTestBehavior(HitTestMode.None)
                // 烟团：6 团相位错开 1/6，每团从香头升起→变大→变淡→消散，走完一圈回卷到香头（消散后再现，视觉连续）
                ForEach([0, 1, 2, 3, 4, 5], (i: number) => {
                  Column()
                    .width(9 + 11 * this.smokeT(i))
                    .height(9 + 11 * this.smokeT(i))
                    .borderRadius((9 + 11 * this.smokeT(i)) / 2)
                    .radialGradient({
                      center: ['50%', '50%'],
                      radius: '50%',
                      colors: [['rgba(255, 255, 255, 0.90)', 0.0], ['rgba(255, 255, 255, 0)', 1.0]]
                    })
                    .opacity(this.smokeOp(i))
                    .position({ x: '50%', y: -50 })
                    .translate({
                      x: 6 * Math.sin(this.smokeT(i) * 2 * Math.PI + i * Math.PI / 3),
                      y: -6 - 56 * this.smokeT(i)
                    })
                    // 动画时长与相位推进间隔(260ms)一致，回卷瞬间两端透明度=0，下移不可见
                    .animation({ duration: 260, curve: Curve.Linear })
                    .hitTestBehavior(HitTestMode.None)
                }, (i: number) => i.toString())
              }
            }
            .width('100%')
            .layoutWeight(1)
            .constraintSize({ maxHeight: 104 })

            // 供桌
            Column()
              .width(300)
              .constraintSize({ maxWidth: '76%' })
              .height(10)
              .borderRadius(4)
              .backgroundColor('#8A1A24')
              .border({ width: { top: 2 }, color: '#C9A24A' })
              .margin({ top: -2 })

            Text(this.incenseLit ? '心意正暖 · 财源广进'
              : (this.hallVM.heart >= 3 ? '上一炷香 · 财源广进' : '心意值不足'))
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.80)')
              .height(16)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height('30%')
          .constraintSize({ maxHeight: 130 })
          .justifyContent(FlexAlign.End)
          .onClick(() => this.onCenser())
        }
        .width('100%')
        .layoutWeight(1)

        // 写下祈福话 → 生成电子祈福图（点香后可用；图片可保存到手机）
        Button('写下祈福话 · 生成祈福图')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1a1a0a')
          .backgroundColor('#FFD700')
          .borderRadius(22)
          .height(44)
          .width('78%')
          .shadow({ radius: 14, color: 'rgba(255, 209, 0, 0.35)', offsetY: 3 })
          .margin({ top: 8, bottom: 4 })
          .onClick(() => this.openBlessingImage())

        Text(this.incenseLit ? '心诚则灵 · 生成的祈福图可保存到手机' : '先点一炷香，再写下祈福话')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.72)')
          .width('100%')
          .height(16)
          .textAlign(TextAlign.Center)
          .margin({ bottom: 4 })

        // 心意值条
        Row() {
          Column() {
            Text(this.hallVM.heart.toString())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD100')
            Text('心意值')
              .fontSize(10)
              .fontColor('rgba(253, 246, 227, 0.68)')
              .margin({ top: 1 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)

          Column() {
            Text(`${this.hallVM.sticksToday} 支`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD100')
            Text('今日上香')
              .fontSize(10)
              .fontColor('rgba(253, 246, 227, 0.68)')
              .margin({ top: 1 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .linearGradient({
          angle: 180,
          colors: [['rgba(20, 4, 6, 0)', 0.0], ['rgba(20, 4, 6, 0.28)', 1.0]]
        })
      }
      .width('100%')
      .height('100%')
      // 顶部 44vp 安全距：匾额下移到状态栏/中置挖孔之下，背景层仍铺满全屏
      .padding({ top: 44 })

      // 轻提示（心意值不足 / 香火已点 / 请先点香等）
      Text(this.toastText)
        .fontSize(13)
        .fontColor('#FFD700')
        .backgroundColor('rgba(0, 0, 0, 0.84)')
        .borderRadius(20)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .constraintSize({ maxWidth: '82%' })
        .position({ x: '50%', y: '82%' })
        .translate({ x: '-50%' })
        .opacity(this.toastVisible ? 1 : 0)
        .animation({ duration: 220 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#100a0c')
  }
}
