// entry/src/main/ets/components/CaiShenHallIcon.ets
// 财神殿入口图标：金线自绘中国古建筑殿堂（飞檐屋顶 + 正脊宝顶 + 殿身 + 门洞 + 须弥座），
// 替代 emoji 🏯（实为日式天守阁），贴合民俗财神殿主题。金色 #FFD700 与底部 Tab 图标同色系。
@Component
export struct CaiShenHallIcon {
  @Prop iconSize: number = 24

  // 飞檐屋顶：两端上翘的中文殿宇轮廓（非日式城堡的方塔顶）
  private roofCmd(): string {
    const s = this.iconSize
    return 'M' + (0.07 * s) + ' ' + (0.42 * s) +
      ' Q' + (0.28 * s) + ' ' + (0.20 * s) + ' ' + (0.50 * s) + ' ' + (0.18 * s) +
      ' Q' + (0.72 * s) + ' ' + (0.20 * s) + ' ' + (0.93 * s) + ' ' + (0.42 * s) +
      ' L' + (0.86 * s) + ' ' + (0.50 * s) +
      ' Q' + (0.72 * s) + ' ' + (0.34 * s) + ' ' + (0.50 * s) + ' ' + (0.32 * s) +
      ' Q' + (0.28 * s) + ' ' + (0.34 * s) + ' ' + (0.14 * s) + ' ' + (0.50 * s) +
      ' Z'
  }

  build() {
    Stack() {
      // 屋顶
      Path()
        .width(this.iconSize)
        .height(this.iconSize)
        .commands(this.roofCmd())
        .fill('#FFD700')
      // 正脊宝顶
      Rect()
        .width(this.iconSize * 0.12)
        .height(this.iconSize * 0.07)
        .borderRadius(this.iconSize * 0.03)
        .fill('#FFD700')
        .position({ x: this.iconSize * 0.44, y: this.iconSize * 0.10 })
      // 殿身
      Rect()
        .width(this.iconSize * 0.48)
        .height(this.iconSize * 0.27)
        .fill('#FFD700')
        .position({ x: this.iconSize * 0.26, y: this.iconSize * 0.50 })
      // 门洞（深色，体现殿宇纵深）
      Rect()
        .width(this.iconSize * 0.16)
        .height(this.iconSize * 0.21)
        .fill('#6E0F18')
        .position({ x: this.iconSize * 0.42, y: this.iconSize * 0.56 })
      // 须弥座：两层台基
      Rect()
        .width(this.iconSize * 0.66)
        .height(this.iconSize * 0.07)
        .fill('#FFD700')
        .position({ x: this.iconSize * 0.17, y: this.iconSize * 0.79 })
      Rect()
        .width(this.iconSize * 0.82)
        .height(this.iconSize * 0.06)
        .fill('#FFD700')
        .position({ x: this.iconSize * 0.09, y: this.iconSize * 0.87 })
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }
}
