import { DeityInfo } from '../model/PrayerTypes'
import { DeityView } from './DeityView'
import { DeityRotator } from '../engine/DeityRotator'

/** 单个财神在弧形阵中的位置/尺寸/现身延迟（相对容器百分比 + px + 0-1） */
interface DeityLayout {
  x: string
  y: string
  size: number
  delay: number
}

/**
 * 五路财神弧形阵布局：中路王亥居中且最大，两侧错落递减形成弧形。
 * 对应五路方位语义，主位（highlightId）光晕更强。
 * 布局对象预建为常量表，避免动画期间每次 build 重复分配（16ms/帧 × 5 神 × 3 处调用）。
 */
const DEITY_LAYOUTS: Record<number, DeityLayout> = {
  1: { x: '50%', y: '52%', size: 100, delay: 0.00 }, // 中路·王亥（主位·弧底，放大）
  2: { x: '22%', y: '38%', size: 60, delay: 0.12 }, // 东路·比干（内收避免名称被屏幕边缘裁切）
  3: { x: '78%', y: '38%', size: 60, delay: 0.18 }, // 西路·关羽
  4: { x: '39%', y: '12%', size: 52, delay: 0.24 }, // 南路·柴荣（略内收避开主位头顶）
  5: { x: '61%', y: '12%', size: 52, delay: 0.30 }, // 北路·赵公明
}
const DEFAULT_DEITY_LAYOUT: DeityLayout = { x: '50%', y: '40%', size: 70, delay: 0 }

function getDeityLayout(id: number): DeityLayout {
  const layout = DEITY_LAYOUTS[id]
  return layout !== undefined ? layout : DEFAULT_DEITY_LAYOUT
}

/**
 * 五神齐聚弧形阵。
 * - appearProgress 0->1 驱动各神按 delay 依次绽放现身
 * - blessingProgress 0->1 驱动光晕脉动放大（祝福阶段）
 */
@Component
export struct DeityArrayView {
  @Prop deities: DeityInfo[]
  @Prop todayId: number = 1
  @Prop highlightId: number = 1
  @Prop appearProgress: number = 0
  @Prop blessingProgress: number = 0

  private layoutOf(id: number): DeityLayout {
    // 先做「神 → 锚点」对调映射，再查固定锚点表；
    // 锚点表的坐标/尺寸/现身 delay 不变 → 主位（锚点1）恒先现身、最大；
    // 光晕由 highlightId 单独驱动（调用方需保证 highlightId 与 todayId 指向同一神）
    return getDeityLayout(DeityRotator.anchorOf(id, this.todayId))
  }

  // 经 delay 偏移后的现身进度（EaseOut），0->1
  private appearOf(id: number): number {
    const layout = this.layoutOf(id)
    const span = 1 - layout.delay
    if (span <= 0) return 1
    const raw = (this.appearProgress - layout.delay) / span
    const clamped = Math.max(0, Math.min(1, raw))
    return 1 - Math.pow(1 - clamped, 3)
  }

  build() {
    Stack() {
      ForEach(this.deities, (deity: DeityInfo) => {
        DeityView({
          deity: deity,
          iconSize: this.layoutOf(deity.id).size,
          isHighlight: deity.id === this.highlightId,
          deityScale: this.appearOf(deity.id),
          deityOpacity: this.appearOf(deity.id),
          blessingProgress: this.blessingProgress
        })
          .position({ x: this.layoutOf(deity.id).x, y: this.layoutOf(deity.id).y })
          .translate({ x: '-50%', y: '-50%' })
      }, (deity: DeityInfo) => deity.id.toString())
    }
    .width('100%')
    .height('100%')
  }
}
