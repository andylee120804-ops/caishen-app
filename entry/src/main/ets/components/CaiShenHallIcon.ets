// entry/src/main/ets/components/CaiShenHallIcon.ets
// 财神殿入口图标：方孔铜钱·財（金圆 + 深金内圈压边 + 方形孔 + 米色「財」字铸文），
// 替代 emoji 🏯（实为日式天守阁）。圆形方孔是中国古钱最经典形态，一眼即「钱」，
// 且与祈福 Tab 的金元宝区分开。金色 #FFD700 与底部 Tab 图标同色系；
// 方孔用 #6E0F18 深红，与底栏红底融合成通透孔洞，米色「財」字印于孔上如古钱铸文。
@Component
export struct CaiShenHallIcon {
  @Prop iconSize: number = 24

  build() {
    Stack() {
      // 外圆（金）
      Circle()
        .width(this.iconSize * 0.94)
        .height(this.iconSize * 0.94)
        .fill('#FFD700')
      // 内圈凸边（深金，营造古钱压印的层次感）
      Circle()
        .width(this.iconSize * 0.76)
        .height(this.iconSize * 0.76)
        .fillOpacity(0)
        .stroke('#C8A53A')
        .strokeWidth(this.iconSize * 0.04)
      // 方形孔（深红，与底栏红色背景融合成通透孔洞）
      Rect()
        .width(this.iconSize * 0.26)
        .height(this.iconSize * 0.26)
        .borderRadius(this.iconSize * 0.03)
        .fill('#6E0F18')
      // 「財」字（米色，印于方孔之上，如古钱铸文）
      Text('財')
        .fontSize(this.iconSize * 0.30)
        .fontColor('#FDF6E3')
        .fontWeight(FontWeight.Bold)
    }
    .width(this.iconSize)
    .height(this.iconSize)
  }
}
