// entry/src/main/ets/pages/MuyuPage.ets
// 电子木鱼：轻触敲击，计数功德。短音复用 kowtow.mp3（DUCK 策略），
// 轻触感复用 VIBRATE 权限（已声明）。高频解压 + 每日打开场景。
// 素材：props/muyu.png = 程序化渲染「寺庙描金」方案（scripts/render-muyu-variants.py）。
// 敲击动画链路与音效/振动/计数隔离（任一侧失败都不影响动画侧）。
import { MuyuViewModel } from '../viewmodels/MuyuViewModel'
import { AudioManager } from '../service/AudioManager'
import { PageBack } from '../components/PageBack'
import { FormSyncService } from '../service/FormSyncService'
import { vibrator } from '@kit.SensorServiceKit'

/** 敲击飘字词池（随机抽取） */
const BLESSING_WORDS: string[] = ['好运 +1', '运气 +1', '福气 +1', '财气 +1', '财气 +1', '静心 +1']

// ── 融合层（复刻求签页 qiu_glow 手法：暖色径向光晕罩住木鱼，晕进深底消除硬边界）──
const MUYU_GLOW_W = 240        // 氛围光晕显示尺寸（vp，方形径向暖光，罩住木鱼主体）
const MUYU_GLOW_DY = -8        // 光晕略上移，罩住木鱼主体中心

@Component
export struct MuyuPage {
  /** 独立模式（EntryShell 从「我的」进入）：返回键并入大标题行；Tab 模式不带 */
  @Prop standalone: boolean = false
  @StorageLink('muyuVM') muyuVM: MuyuViewModel = new MuyuViewModel()
  /** 卡片在 App 后台敲击后，EntryAbility 回前台 reload 完 bump 本值，驱动本页重读计数 */
  @StorageLink('muyuRev') @Watch('onMuyuRev') muyuRev: number = 0
  @State refreshTick: number = 0
  // 木鱼动画：按下→回弹超调→归位
  @State fishScale: number = 1
  @State fishRot: number = 0
  @State fishDy: number = 0
  @State glowA: number = 0        // 金光环透明度
  @State glowScale: number = 1
  // 祝福飘字（单条：立即出现 → 上浮 → 淡出；每敲一次换词重放）
  @State flyText: string = ''
  @State flyA: number = 0
  @State flyY: number = -10
  @State flyScale: number = 1
  private animTimers: number[] = []

  aboutToDisappear(): void {
    for (const t of this.animTimers) {
      clearTimeout(t)
    }
    this.animTimers = []
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
      // 标题（独立模式返回键并入同行，木鱼图+标题整组居中，右侧配平占位与返回键等宽；
      // Tab 模式不带返回，整组保持左对齐）
      Row() {
        if (this.standalone) {
          PageBack()
        }
        Row() {
          Image($rawfile('props/muyu.png'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
          Text('电子木鱼')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD100')
            .margin({ left: 8 })
        }
        .layoutWeight(1)
        .justifyContent(this.standalone ? FlexAlign.Center : FlexAlign.Start)
        if (this.standalone) {
          Text(' ')
            .fontSize(14)
            .width(76)
        }
      }
      .width('100%')
      .padding({ left: this.standalone ? 6 : 20, top: 44, bottom: 8 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 计数
      Column() {
        Text(`今日 ${this.muyuVM.todayCount} 下`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
        Text(`累计静心 ${this.muyuVM.totalCount}`)
          .fontSize(12)
          .fontColor('rgba(255, 209, 0, 0.7)')
          .margin({ top: 4 })
      }
      .margin({ top: 18 })

      // 木鱼主体：地面投影 + 氛围光晕 + 金光环 + 木鱼 + 祝福飘字
      Stack() {
        // 柔边地面投影（高斯圆斑，无矩形边框）
        Image($rawfile('props/muyu_shadow.png'))
          .width(180)
          .height(180)
          .objectFit(ImageFit.Contain)
          .opacity(0.9)
          .translate({ y: 56 })

        // 氛围光晕（复刻求签页 qiu_glow）：暖色径向光晕罩住木鱼，晕进深底消除硬边界
        Image($rawfile('props/qiu_glow.png'))
          .width(MUYU_GLOW_W)
          .height(MUYU_GLOW_W)
          .objectFit(ImageFit.Contain)
          .translate({ y: MUYU_GLOW_DY })

        // 点击金光环（随敲击闪现扩散）
        Row()
          .width(192)
          .height(192)
          .borderRadius(96)
          .border({ width: 3, color: 'rgba(255, 209, 0, 0.8)' })
          .opacity(this.glowA)
          .scale({ x: this.glowScale, y: this.glowScale })

        // 木鱼主体（高清插值，柔化放大后的边缘锯齿）
        Image($rawfile('props/muyu.png'))
          .width(166)
          .height(166)
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
          .scale({ x: this.fishScale, y: this.fishScale })
          .rotate({ angle: this.fishRot })
          .translate({ y: this.fishDy })

        Text('轻触木鱼 · 静心 +1')
          .fontSize(13)
          .fontColor('rgba(253, 246, 227, 0.6)')
          .translate({ y: 96 })

        // 祝福词：敲击瞬间即出现于木鱼上方，随后上浮淡出
        if (this.flyText !== '') {
          Text(this.flyText)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD100')
            .opacity(this.flyA)
            .translate({ y: this.flyY })
            .scale({ x: this.flyScale, y: this.flyScale })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .onClick(() => this.knock())
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#D23B2E', 0.0], ['#A51D16', 0.55], ['#6F120E', 1.0]] })
    .overlay(this.GlowOverlay)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  private knock(): void {
    // ① 动画/飘字（纯状态 + 定时器，不做任何可能抛错的调用）
    this.playKnockAnim()
    this.boostFly()
    // ② 计数、音效、振动各自隔离，失败不影响动画
    try {
      this.muyuVM.knock()
      // 敲击后把最新功德数推给桌面卡片（未添加卡片时安全空转）
      const ctx = this.getUIContext().getHostContext()
      if (ctx !== undefined && ctx !== null) {
        FormSyncService.pushAll(ctx).catch((err: Object) => {
          console.error('[MuyuPage] push cards failed:', JSON.stringify(err))
        })
      }
    } catch (err) {
      console.error('[MuyuPage] count failed:', JSON.stringify(err))
    }
    try {
      AudioManager.getInstance().playSound('kowtow')
    } catch (err) {
      console.error('[MuyuPage] sound failed:', JSON.stringify(err))
    }
    this.vibrate()
  }

  /** 卡片敲击后回前台：@Observed 嵌套变更不通知 UI，bump @State 触发重建重读计数 */
  onMuyuRev(): void {
    this.refreshTick = this.refreshTick + 1
  }

  /** 木鱼压扁回弹 + 金光环（显式 animateTo） */
  private playKnockAnim(): void {
    for (const t of this.animTimers) {
      clearTimeout(t)
    }
    this.animTimers = []
    const ctx = this.getUIContext()
    try {
      // ① 按下
      ctx.animateTo({ duration: 110, curve: Curve.EaseOut }, () => {
        this.fishScale = 0.84
        this.fishRot = -8
        this.fishDy = 16
        this.glowA = 1
        this.glowScale = 0.9
      })
      // ② 回弹超调
      this.animTimers.push(setTimeout(() => {
        ctx.animateTo({ duration: 120, curve: Curve.EaseOut }, () => {
          this.fishScale = 1.12
          this.fishRot = 6
          this.fishDy = -12
          this.glowA = 0.3
          this.glowScale = 1.25
        })
      }, 150))
      // ③ 回落贴地
      this.animTimers.push(setTimeout(() => {
        ctx.animateTo({ duration: 90, curve: Curve.EaseOut }, () => {
          this.fishScale = 0.97
          this.fishRot = 0
          this.fishDy = 0
        })
      }, 330))
      // ④ 归位熄光
      this.animTimers.push(setTimeout(() => {
        ctx.animateTo({ duration: 110, curve: Curve.EaseOut }, () => {
          this.fishScale = 1
          this.glowA = 0
          this.glowScale = 1
        })
      }, 460))
    } catch (err) {
      console.error('[MuyuPage] anim failed:', JSON.stringify(err))
    }
  }

  /** 祝福词：立即在木鱼上方显示（不依赖任何延时），再分两段上浮淡出 */
  private boostFly(): void {
    // 先清掉上一轮的推进计时器，避免串扰
    const ctx = this.getUIContext()
    const word = BLESSING_WORDS[Math.floor(Math.random() * BLESSING_WORDS.length)]
    try {
      // 本帧直接可见（从木鱼上方弹出）
      this.flyText = word
      this.flyA = 1
      this.flyY = -30
      this.flyScale = 0.9
      // 上浮第一段（显式动画保证过渡）
      this.animTimers.push(setTimeout(() => {
        ctx.animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
          this.flyY = -90
          this.flyScale = 1.08
        })
      }, 60))
      // 上浮第二段：飘得更高 + 淡出
      this.animTimers.push(setTimeout(() => {
        ctx.animateTo({ duration: 260, curve: Curve.Linear }, () => {
          this.flyY = -165
          this.flyA = 0
        })
      }, 520))
      // 复位（文字清空，下次敲击重新出现）
      this.animTimers.push(setTimeout(() => {
        this.flyText = ''
        this.flyA = 0
        this.flyY = -30
        this.flyScale = 1
      }, 860))
    } catch (err) {
      console.error('[MuyuPage] fly failed:', JSON.stringify(err))
    }
  }

  private vibrate(): void {
    try {
      vibrator.startVibration({
        type: 'time',
        duration: 18
      }, { id: 0, usage: 'unknown' })
    } catch (err) {
      console.error('[MuyuPage] vibrate failed:', JSON.stringify(err))
    }
  }
}
