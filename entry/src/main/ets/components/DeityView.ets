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

      // 财神名号（加柔影，确保在更亮的红底上清晰可读、与背景协调）
      Text(this.deity.name)
        .fontSize(this.isHighlight ? 18 : 14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.35)' })
        .margin({ top: 8 })
        .opacity(this.deityOpacity)

      // 方位标签（装饰符包裹，与寓意分层避免长行随意断行）
      Text(`· ${this.deity.direction} ·`)
        .fontSize(10)
        .fontColor('rgba(255, 209, 0, 0.6)')
        .margin({ top: 4 })
        .opacity(this.deityOpacity)

      // 财神寓意：四字逗号处换行，两行齐整排列
      Text(this.deity.deityMeaning.replace('，', '\n'))
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.5)')
        .textAlign(TextAlign.Center)
        .lineHeight(15)
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
