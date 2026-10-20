// entry/src/main/ets/components/GoldGlyph.ets
// 金色吉物底托：主题金底 + 深金边，让 💰🧧 等深色 emoji 在深色背景上高对比可见（emoji 自身颜色不可靠）。
// 金色取项目主题金 #FFD700——白色在中国祈福文化中不宜作主色，金才合「敬财神」语境；
// emoji 自身多为白色或浅色底，落在金底上依旧清晰。
// 尺寸/圆角/投影随 tileSize 缩放，小尺寸用于行内点缀，大尺寸用于百科卡片。

@Component
export struct GoldGlyph {
  @Prop icon: string = '💰'
  @Prop tileSize: number = 44

  private tileRadius(): number {
    return Math.max(4, Math.floor(this.tileSize * 0.18))
  }

  build() {
    Stack() {
      Text(this.icon)
        .fontSize(Math.floor(this.tileSize * 0.62))
        .textAlign(TextAlign.Center)
    }
    .width(this.tileSize)
    .height(this.tileSize)
    .backgroundColor('#FFD700')
    // 深金描边：金底上再用金边会糊成一片，用深琥珀色给出图形轮廓
    .border({ width: 1, color: 'rgba(166, 116, 0, 0.75)', radius: this.tileRadius() })
    .shadow({ radius: Math.max(2, Math.floor(this.tileSize * 0.09)), color: 'rgba(0, 0, 0, 0.35)', offsetY: 2 })
  }
}
