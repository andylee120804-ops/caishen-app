/**
 * 宫灯造型组件：上金盖 + 红底金字灯身 + 下金盖，可选底部流苏。
 * 纯展示组件，不含动画 —— 入场/摇摆/上升动画由使用方驱动，
 * 同一组件不同属性（translate/rotate/scale）可分别动画互不覆盖。
 *
 * 用法：
 * - 中央大灯笼：LanternView({ char: '福', bodyWidth: 96, bodyHeight: 104, fontSize: 42, withTassel: false })
 * - 上升小灯笼：由下方 RisingLantern 包装使用
 */

/**
 * 上升宫灯：自屏底升至屏顶外的常驻氛围动画。
 *
 * 上升用 setInterval 手动循环（重置到屏外起点 -> 单程 animateTo 升顶），
 * 与已在真机验证过的 FloatingBlessing 同构的可靠模式 —— **不要**改成
 * `@State 数组元素 + animateTo({iterations:-1})` 驱动：该组合在部分真机
 * 上不生效，灯笼会瞬移到屏外直接消失（2026-10-29 真机踩坑）。
 * 起终点均在屏外，循环重置无跳变感。
 *
 * 摇摆为增强层（iterations:-1 Alternate 作用于基础类型 @State）：
 * 即使平台不支持也只是静止，不影响上升主动画。
 */
@Component
export struct RisingLantern {
  @Prop x: number
  @Prop char: string = '福'
  @Prop scaleVal: number = 0.7
  @Prop durationMs: number = 12000
  @Prop delayMs: number = 0
  @State riseY: number = 0
  @State rot: number = -3.5
  private cycleTimerId: number = -1
  private firstTimerId: number = -1

  aboutToAppear(): void {
    // 摇摆（增强层，失败无害）
    this.getUIContext().animateTo({
      duration: 3600,
      curve: Curve.EaseInOut,
      playMode: PlayMode.Alternate,
      iterations: -1
    }, () => {
      this.rot = 3.5
    })

    // 上升（保底层）：首轮延迟起跑，之后按单程时长循环
    const launch: () => void = () => {
      this.getUIContext().animateTo({ duration: this.durationMs, curve: Curve.Linear }, () => {
        this.riseY = -1200
      })
    }
    this.firstTimerId = setTimeout(() => {
      launch()
      this.cycleTimerId = setInterval(() => {
        this.riseY = 0   // 瞬移回屏外起点（屏外，无跳变感）
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
    Column() {
      LanternView({
        char: this.char,
        bodyWidth: 62,
        bodyHeight: 66,
        fontSize: 26,
        withTassel: true
      })
    }
    .position({ x: this.x, y: 870 })
    .translate({ y: this.riseY })
    .rotate({ angle: this.rot })
    .scale({ x: this.scaleVal, y: this.scaleVal })
    .hitTestBehavior(HitTestMode.None)
  }
}

@Component
export struct LanternView {
  @Prop char: string = '福'
  @Prop bodyWidth: number = 62
  @Prop bodyHeight: number = 66
  @Prop fontSize: number = 26
  @Prop withTassel: boolean = true

  build() {
    Column() {
      // 上盖
      Row()
        .width(this.bodyWidth * 0.42)
        .height(7)
        .backgroundColor('#FFD700')
        .borderRadius(2)

      // 灯身：红底金字，椭圆感圆角
      Stack({ alignContent: Alignment.Center }) {
        Text(this.char)
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
      }
      .width(this.bodyWidth)
      .height(this.bodyHeight)
      .margin({ top: -1 })
      .radialGradient({
        center: ['50%', '40%'],
        radius: '75%',
        colors: [['#e0514a', 0.0], ['#c0392b', 0.72]]
      })
      .border({ width: 1.5, color: 'rgba(255,209,0,0.6)', radius: this.bodyWidth * 0.46 })
      .shadow({ radius: 18, color: 'rgba(255,120,80,0.4)', offsetX: 0, offsetY: 0 })

      // 下盖
      Row()
        .width(this.bodyWidth * 0.32)
        .height(6)
        .margin({ top: -1 })
        .backgroundColor('#FFD700')
        .borderRadius(2)

      // 流苏：金线 + 末端金结
      if (this.withTassel) {
        Column() {
          Row()
            .width(2)
            .height(22)
            .backgroundColor('#FFD700')
          Row()
            .width(7)
            .height(11)
            .margin({ top: -1 })
            .backgroundColor('#FFD700')
            .borderRadius(2)
        }
      }
    }
  }
}
