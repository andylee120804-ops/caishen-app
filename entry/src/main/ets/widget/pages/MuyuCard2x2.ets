// entry/src/main/ets/widget/pages/MuyuCard2x2.ets
// 敲木鱼小卡（2×2）：木鱼图片 + 今日/累计功德小字；整卡点击敲一下（message）。
// 图片走 media 资源 $r('app.media.muyu')：随卡片包加载，不依赖 fd 跨进程传递。
// 整卡点击层与跳转按钮层是 Stack 的兄弟节点，避免点击穿透/双触发。
//
// ── 点击 "+1" 反馈的实现约束（ArkTS 卡片）──
// 1) 卡片里 **没有 setTimeout**（普适限制），无法用延时做「按下 → 回弹 → 飘字」分段；
// 2) 同一个状态在同一帧里写两次会被合并：先赋起始值再 animateTo 到终值 →
//    动画起点会被吃掉（例如透明度只能写成不透明度变化感觉不出来），所以必须
//    **每帧只写一次**同一个状态；
// 3) 卡片动效上限：duration ≤ 1000ms，且不支持 delay / tempo / iterations。
// → 方案：两段动画分别落在两个不同帧上。
//    · 按下帧（onClick）：立即落地「按下 + '+1' 出现」的起始态（不加动画）；
//    · 收尾帧（onCountRefreshed）：updateForm 把最新计数回传后（@Watch 捕捉），
//      此刻才 animateTo 完成木鱼回弹熄光 + '+1' 上浮淡出。
//    数字一般 1 秒内回来，观感就是「按一下 → 飘一个 +1 上去」。
let muyuCard2x2Storage: LocalStorage = new LocalStorage()

@Entry(muyuCard2x2Storage)
@Component
struct MuyuCard2x2 {
  @LocalStorageProp('todayCount') @Watch('onCountRefreshed') todayCount: number = 0
  @LocalStorageProp('totalCount') totalCount: number = 0
  // —— 纯视觉状态（不参与计数，只做点击反馈）——
  @State fishScale: number = 1        // 木鱼按压
  @State glowOpacity: number = 0      // 金光环透明度
  @State glowScale: number = 0.7      // 金光环缩放
  @State plusOpacity: number = 0      // "+1" 透明度
  @State plusY: number = 6            // "+1" 上浮位移
  @State plusScale: number = 0.7      // "+1" 缩放
  @State pending: boolean = false     // 是否有一次敲击在等计数回传收尾

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ① 整卡敲击区
      Column() {
        Stack() {
          // 常驻暖金氛围光：紧贴木鱼一圈柔光托住红漆主体，不外扩
          Row()
            .width(84)
            .height(84)
            .borderRadius(42)
            .backgroundColor('rgba(249, 202, 36, 0.12)')

          // 敲击金光环（木鱼下层）
          Row()
            .width(90)
            .height(90)
            .borderRadius(45)
            .border({ width: 2, color: 'rgba(249, 202, 36, 0.7)' })
            .opacity(this.glowOpacity)
            .scale({ x: this.glowScale, y: this.glowScale })

          Image($r('app.media.muyu'))
            .width(74)
            .height(74)
            .objectFit(ImageFit.Contain)
            .scale({ x: this.fishScale, y: this.fishScale })

          // 敲击飘出的「+1」
          Text('+1')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#f9ca24')
            .textShadow({ radius: 8, color: 'rgba(249, 202, 36, 0.6)', offsetX: 0, offsetY: 0 })
            .opacity(this.plusOpacity)
            .translate({ y: this.plusY })
            .scale({ x: this.plusScale, y: this.plusScale })
        }
        .width('100%')
        .height(96)

        Text('今日静心 ' + this.todayCount)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
          .margin({ top: 2 })

        Text('累计静心 ' + this.totalCount)
          .fontSize(11)
          .fontColor('rgba(249, 202, 36, 0.7)')
          .margin({ top: 3 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({ angle: 180, colors: [['#2B1A0E', 0.0], ['#1C1109', 0.5], ['#100A05', 1.0]] })
      .onClick(() => {
        this.knock()
      })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 敲一下：先即时给反馈（按下 + "+1" 出现），再下发计数。
   * 起始态必须落在这一帧且不带动画，否则与收尾帧的赋值合并导致动画丢失。
   */
  private knock(): void {
    this.fishScale = 0.86
    this.glowOpacity = 0.9
    this.glowScale = 0.72
    this.plusOpacity = 1
    this.plusY = 6
    this.plusScale = 0.7
    this.pending = true
    // params 必须是对象，自定义动作键名必须用 msgAction（见 SignCard2x2 注释）
    postCardAction(this, {
      action: 'message',
      params: { msgAction: 'knock', form: 'muyu_2x2' }
    })
  }

  /**
   * 计数回传（updateForm 更新 todayCount）：此刻已是新的一帧，才做收尾动画。
   * 非敲击触发的更新（首次加载 / 定时刷新）pending 为 false，直接忽略。
   */
  onCountRefreshed(): void {
    if (!this.pending) {
      return
    }
    this.pending = false
    try {
      // 木鱼回弹 + 金光扩散熄灭
      animateTo({ duration: 380, curve: Curve.EaseOut }, (): void => {
        this.fishScale = 1
        this.glowOpacity = 0
        this.glowScale = 1.25
      })
      // "+1" 上浮淡出（卡片单次动画上限 1000ms）
      animateTo({ duration: 900, curve: Curve.EaseOut }, (): void => {
        this.plusOpacity = 0
        this.plusY = -40
        this.plusScale = 1.25
      })
    } catch (err) {
      console.error('[MuyuCard] knock anim failed: ' + JSON.stringify(err))
    }
  }
}
