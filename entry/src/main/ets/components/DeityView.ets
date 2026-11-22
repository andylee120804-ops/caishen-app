import { DeityInfo } from '../model/PrayerTypes'

/**
 * 单个财神展示：代表色光晕/描边 + 形象 + 名号 + 方位。
 * 由 DeityArrayView 在五神阵中复用，也可单独使用（如 HomePage 主位）。
 *
 * - iconSize：形象尺寸（px），体现主次（避开基类 .size() 通用属性）
 * - isHighlight：主位高亮，光晕更强、名号更大
 * - blessingProgress：祝福阶段光晕脉动放大（0-1）
 */
@Component
export struct DeityView {
  @Prop deity: DeityInfo
  @Prop deityScale: number = 1.0
  @Prop deityOpacity: number = 1.0
  @Prop iconSize: number = 80
  @Prop isHighlight: boolean = false
  @Prop blessingProgress: number = 0

  private haloSize(): number {
    return this.iconSize * 1.5 * (1 + this.blessingProgress * 0.3)
  }

  private haloAlpha(): number {
    const base = this.isHighlight ? 0.28 : 0.10
    return Math.min(1, base * this.deityOpacity * (1 + this.blessingProgress * 0.7))
  }

  private hexToRgba(hex: string, alpha: number): string {
    const h = hex.replace('#', '')
    const r = parseInt(h.substring(0, 2), 16)
    const g = parseInt(h.substring(2, 4), 16)
    const b = parseInt(h.substring(4, 6), 16)
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  // 代表色光晕：各路财神以其代表色发光（取代原统一金色光晕）
  private haloColor(): string {
    return this.hexToRgba(this.deity.color, this.haloAlpha())
  }

  build() {
    Column() {
      // 代表色光晕（取代原金色光晕：各路财神以其代表色发光，与红底更协调且各有辨识）
      Circle({ width: this.haloSize(), height: this.haloSize() })
        .fill(this.haloColor())
        .position({ x: '50%', y: '50%' })
        .translate({ x: '-50%', y: '-50%' })

      // 财神形象 + 代表色描边圆环
      Stack() {
        Circle({ width: this.iconSize + 12, height: this.iconSize + 12 })
          .fill('rgba(0, 0, 0, 0)')
          .stroke(this.deity.color)
          .strokeWidth(3)
        Image($rawfile(`deities/${this.deity.id}.png`))
          .width(this.iconSize)
          .height(this.iconSize)
          .objectFit(ImageFit.Contain)
      }
      .width(this.iconSize + 12)
      .height(this.iconSize + 12)
      .scale({ x: this.deityScale, y: this.deityScale })
      .opacity(this.deityOpacity)

      // 财神名号 + 方位（同处一行：名号加粗、方位小字随其后）
      // 原「名号」「方位」各占一行，阵型垂直占用过大导致主位圈压上方财神小字；
      // 合并成一行后省出一行高度，信息不丢。
      Text() {
        Span(this.deity.name)
          .fontSize(this.isHighlight ? 18 : 14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
        Span(` · ${this.deity.direction}`)
          .fontSize(8)
          .fontColor('rgba(255, 209, 0, 0.65)')
      }
      .margin({ top: 8 })
      .opacity(this.deityOpacity)

      // 财神寓意：逗号处换行成两行齐整排列。
      // 主位财神字号 10；其余财神像更小（宽 76~86vp），字号降到 8 才能让第二行 9 字完整放下，
      // 避免最后一个字被挤到第三行（maxLines 2 + 省略号兜底）。
      Text(this.deity.deityMeaning.replace('，', '\n'))
        .fontSize(this.isHighlight ? 10 : 8)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .textAlign(TextAlign.Center)
        .lineHeight(this.isHighlight ? 15 : 13)
        .margin({ top: 2 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .opacity(this.deityOpacity)
    }
    .width(this.iconSize * 1.6)
    .alignItems(HorizontalAlign.Center)
    .animation({
      duration: 200,
      curve: Curve.EaseOut
    })
  }
}
