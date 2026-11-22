import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'

/**
 * 祈福 Tab 顶部主神牌：今日主财神（名号大字 + 方位寓意）为主体，
 * 黄历简信息（农历周 + 宜忌 + 吉位）压缩为一行小字。无 emoji。
 * 视觉方案「拱门神龛」：月洞门式拱形深漆红卡 + 顶部金匾（刻「今日主财神」），
 * 神名金字 + 朱红「財」印，回到整页「红底金字」语言，与下方五神弧形阵呼应。
 * 神龛底图（金匾刻字 + 挂绳 + 金色双描边 + 弧形云纹分隔）为预渲染 PNG
 * （props/deity_arch.png，比例 340:138），随容器拉伸；
 * 神名/方位寓意/黄历行仍是动态 Text 叠加，逐日轮换。
 */
@Component
export struct DailyAlmanac {
  @Link enrichVM: EnrichViewModel
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()

  build() {
    Stack() {
      // 神龛底图：含金匾（刻「今日主财神」）、挂绳、金色双描边、弧形云纹分隔
      Image($rawfile('props/deity_arch.png'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .hitTestBehavior(HitTestMode.None)

      // 文字内容（拱腹之内，自上而下：神名+朱印 / 方位寓意 / 黄历行）
      Column() {
        Row() {
          Text(this.viewModel.todayDeity.name)
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
            .letterSpacing(2)
            .lineHeight(26)
          // 朱红「財」印：书法落款式随名，神牌惯用元素
          Column() {
            Text('財')
              .fontSize(9)
              .fontColor('#fdf6e3')
          }
          .width(16)
          .height(16)
          .borderRadius(3)
          .backgroundColor('#C0392B')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ left: 6 })
        }
        .alignItems(VerticalAlign.Center)

        Text(`${this.viewModel.todayDeity.direction} · ${this.viewModel.todayDeity.deityMeaning}`)
          .fontSize(11)
          .fontColor('rgba(255, 209, 0, 0.85)')
          .lineHeight(15)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })

        Text(`${this.getLunarDate()}·${this.getWeekday()}｜宜${this.enrichVM.getAlmanac().suitable}·忌${this.enrichVM.getAlmanac().avoid}｜吉位${this.enrichVM.getAlmanac().direction}`)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.72)')
          .lineHeight(13)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 17 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Center)
      // 左右 16 让文字行宽不超过拱腹金边内沿（窄屏上黄历行省略号恰好在金边前截断）
      .padding({ top: 38, left: 16, right: 16 })
    }
    .width('88%')
    .height(132)
    .position({ x: '50%', y: 46 }) // 避开沉浸式状态栏（时间/电量区域）
    .translate({ x: '-50%', y: '0' })
  }

  private getLunarDate(): string {
    const d: Date = new Date()
    const months: string[] = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月']
    const days: string[] = ['初一', '初二', '初三', '初四', '初五', '初六', '初七', '初八', '初九', '初十',
      '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十',
      '廿一', '廿二', '廿三', '廿四', '廿五', '廿六', '廿七', '廿八', '廿九', '三十']
    const m: number = ((d.getMonth() + 11) % 12)
    const day: number = ((d.getDate() + 30) % 30)
    return `${months[m]}${days[day]}`
  }

  private getWeekday(): string {
    const days: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    return days[new Date().getDay()]
  }
}