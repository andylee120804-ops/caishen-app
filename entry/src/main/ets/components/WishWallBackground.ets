// entry/src/main/ets/components/WishWallBackground.ets
/**
 * 还愿页背景：许愿墙底图 + 上下压暗 + 上升的愿火光点。
 * 墙面 / 檐口 / 灯笼 / 祈愿牌均由 props/wish_wall.jpg 提供（Q版卡通 · 正面平视 · 中段留空），
 * 这里只负责：把图铺满、压暗保证文字可读、加一点会飘的暖光让画面不死板。
 * 由 mashen-app 许愿墙背景搬入，金色调调整为 caishen 财神主题（#FFD700）。
 */

/** 愿火光点配置（8 颗，错峰上升） */
interface SparkConf {
  delayMs: number
  durationMs: number
  rise: number
  dotSize: number
  peakOpacity: number
}

const SPARKS: SparkConf[] = [
  { delayMs: 0, durationMs: 5200, rise: 190, dotSize: 3, peakOpacity: 0.8 },
  { delayMs: 900, durationMs: 6100, rise: 165, dotSize: 2, peakOpacity: 0.45 },
  { delayMs: 1700, durationMs: 4700, rise: 210, dotSize: 4, peakOpacity: 0.55 },
  { delayMs: 2400, durationMs: 6600, rise: 150, dotSize: 2, peakOpacity: 0.4 },
  { delayMs: 3200, durationMs: 5500, rise: 220, dotSize: 3, peakOpacity: 0.7 },
  { delayMs: 1200, durationMs: 6300, rise: 180, dotSize: 2, peakOpacity: 0.5 },
  { delayMs: 2800, durationMs: 5800, rise: 195, dotSize: 3, peakOpacity: 0.62 },
  { delayMs: 3800, durationMs: 6900, rise: 155, dotSize: 2, peakOpacity: 0.42 }
]

/** 一颗向上飘的愿火光点：淡入上升 → 淡出 → 循环 */
@Component
struct WishSpark {
  delayMs: number = 0
  durationMs: number = 5200
  rise: number = 200
  dotSize: number = 3
  peakOpacity: number = 0.7
  @State offsetY: number = 0
  @State dotOpacity: number = 0
  private alive: boolean = true

  aboutToAppear(): void {
    this.fly()
  }

  aboutToDisappear(): void {
    this.alive = false
  }

  private fly(): void {
    if (!this.alive) {
      return
    }
    this.offsetY = 0
    this.dotOpacity = 0
    this.getUIContext().animateTo({
      duration: Math.round(this.durationMs * 0.4),
      delay: this.delayMs,
      curve: Curve.EaseOut,
      onFinish: () => {
        if (!this.alive) {
          return
        }
        this.getUIContext().animateTo({
          duration: Math.round(this.durationMs * 0.6),
          curve: Curve.Linear,
          onFinish: () => {
            this.fly()
          }
        }, () => {
          this.offsetY = this.rise
          this.dotOpacity = 0
        })
      }
    }, () => {
      this.offsetY = Math.round(this.rise * 0.4)
      this.dotOpacity = this.peakOpacity
    })
  }

  build() {
    Circle()
      .width(this.dotSize)
      .height(this.dotSize)
      .fill('rgba(255, 209, 0, 0.95)')
      .translate({ y: -this.offsetY })
      .opacity(this.dotOpacity)
  }
}

/** 还愿页背景：底图铺满 + 上下压暗 + 愿火光点 */
@Component
export struct WishWallBackground {
  build() {
    Stack({ alignContent: Alignment.Top }) {
      // 许愿墙底图：居中顶部对齐、Cover 铺满（底部被 Tab 栏 / 内容压住，不露白）
      Image($rawfile('props/wish_wall.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 上下压暗 + 中段留亮：顶部给标题压暗、底部给提示压暗，中段尽量透出红墙，
      // 让 Q 版卡通红墙 + 檐口双灯笼清晰可见（仅做轻度压暗保证心愿牌文字可读）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(0, 0, 0, 0.30)', 0.0],
            ['rgba(0, 0, 0, 0.02)', 0.34],
            ['rgba(0, 0, 0, 0.10)', 0.62],
            ['rgba(0, 0, 0, 0.45)', 1.0]
          ]
        })

      // 愿火光点：贴底向上飘
      Row() {
        ForEach(SPARKS, (conf: SparkConf, index: number) => {
          WishSpark({
            delayMs: conf.delayMs,
            durationMs: conf.durationMs,
            rise: conf.rise,
            dotSize: conf.dotSize,
            peakOpacity: conf.peakOpacity
          })
        }, (conf: SparkConf, index: number) => index.toString())
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Bottom)
      .justifyContent(FlexAlign.SpaceEvenly)
      .padding({ bottom: 26 })
    }
    .width('100%')
    .height('100%')
  }
}
