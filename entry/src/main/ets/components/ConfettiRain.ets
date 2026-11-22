/**
 * 彩纸雨：金/红双色小纸片自屏顶持续旋转飘落的氛围层。
 *
 * 每片彩纸是独立子组件：setInterval 手动循环（重置到屏外起点 -> 单程
 * animateTo 落底），与已在真机验证过的 FloatingBlessing 同构的可靠模式 ——
 * **不要**改回 `@State 数组元素 + animateTo({iterations:-1})` 驱动：该组合
 * 在部分真机上不生效，彩纸会瞬移消失（2026-10-29 真机踩坑）。
 *
 * 父组件用 if(this.isActive) 挂载彩纸列表：isActive 置 true 时创建子组件，
 * aboutToAppear 届时才执行动画启动（若在子组件内 if 判断，首次挂载时
 * isActive=false 会导致动画永远不启动）。
 */

interface ConfettiSpec {
  x: number          // 水平位置（vp）
  width: number      // 纸片宽
  height: number      // 纸片高
  color: string
  durationMs: number // 单程下落时长（循环相位由 duration 差异自然漂移）
  delayMs: number     // 首轮起跑延迟
}

const CONFETTI_SPECS: ConfettiSpec[] = [
  { x: 26, width: 4, height: 13, color: '#FFD700', durationMs: 5500, delayMs: 0 },
  { x: 74, width: 5, height: 14, color: '#e0514a', durationMs: 6800, delayMs: 2600 },
  { x: 122, width: 4, height: 12, color: '#FFD700', durationMs: 4900, delayMs: 1400 },
  { x: 171, width: 5, height: 13, color: '#e0514a', durationMs: 7400, delayMs: 4200 },
  { x: 216, width: 4, height: 14, color: '#FFD700', durationMs: 5200, delayMs: 600 },
  { x: 262, width: 5, height: 12, color: '#e0514a', durationMs: 6200, delayMs: 3300 },
  { x: 309, width: 4, height: 13, color: '#FFD700', durationMs: 5800, delayMs: 1900 },
  { x: 352, width: 5, height: 13, color: '#e0514a', durationMs: 6500, delayMs: 900 },
  { x: 30, width: 4, height: 12, color: '#e0514a', durationMs: 7200, delayMs: 5000 },
  { x: 340, width: 4, height: 14, color: '#FFD700', durationMs: 6000, delayMs: 4700 }
]

/** 单片彩纸：位置屏外顶部，translate 下落 + rotate 旋转，循环往复 */
@Component
struct ConfettiPiece {
  @Prop x: number
  @Prop w: number
  @Prop h: number
  @Prop color: string
  @Prop durationMs: number
  @Prop delayMs: number
  @State fallY: number = 0
  @State spin: number = 0
  private cycleTimerId: number = -1
  private firstTimerId: number = -1

  aboutToAppear(): void {
    const launch: () => void = () => {
      this.getUIContext().animateTo({ duration: this.durationMs, curve: Curve.Linear }, () => {
        this.fallY = 920
        this.spin = 680
      })
    }
    this.firstTimerId = setTimeout(() => {
      launch()
      this.cycleTimerId = setInterval(() => {
        this.fallY = 0   // 瞬移回屏外起点（屏外，无跳变感）
        this.spin = 0
        launch()
      }, this.durationMs)
    }, this.delayMs)
  }

  aboutToDisappear(): void {
    if (this.firstTimerId !== -1) {
      clearTimeout(this.firstTimerId)
      this.firstTimerId = -1
    }
    if (this.cycleTimerId !== -1) {
      clearInterval(this.cycleTimerId)
      this.cycleTimerId = -1
    }
  }

  build() {
    Row()
      .width(this.w)
      .height(this.h)
      .backgroundColor(this.color)
      .borderRadius(1)
      .position({ x: this.x, y: -30 })
      .translate({ y: this.fallY })
      .rotate({ angle: this.spin })
      .opacity(0.9)
  }
}

@Component
export struct ConfettiRain {
  @Prop isActive: boolean = false

  build() {
    if (this.isActive) {
      Stack() {
        ForEach(CONFETTI_SPECS, (spec: ConfettiSpec, idx: number) => {
          ConfettiPiece({
            x: spec.x,
            w: spec.width,
            h: spec.height,
            color: spec.color,
            durationMs: spec.durationMs,
            delayMs: spec.delayMs
          })
        }, (spec: ConfettiSpec, idx: number) => 'cf' + idx.toString())
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
    }
  }
}
