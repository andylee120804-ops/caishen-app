import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'

/**
 * 祈福 Tab 顶部主神牌：今日主财神（名号大字 + 方位寓意）为主体，
 * 黄历简信息（农历周 + 宜忌 + 吉位）压缩为一行小字。无 emoji。
 * 尺寸刻意收紧（宽度 86%、内边距 6、名号 20）：顶部卡片过高会挤占下方五神阵。
 */
@Component
export struct DailyAlmanac {
  @Link enrichVM: EnrichViewModel
  @StorageLink('viewModel') viewModel: PrayerViewModel = new PrayerViewModel()

  build() {
    Column() {
      Text('— 今日主财神 —')
        .fontSize(10)
        .fontColor('rgba(255, 209, 0, 0.8)')
        .letterSpacing(3)
        .margin({ bottom: 2 })

      Text(this.viewModel.todayDeity.name)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')

      Text(`${this.viewModel.todayDeity.direction} · ${this.viewModel.todayDeity.deityMeaning}`)
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.7)')
        .margin({ top: 2 })

      Divider()
        .strokeWidth(1)
        .color('rgba(255, 209, 0, 0.25)')
        .margin({ top: 5, bottom: 4 })

      Text(`${this.getLunarDate()}·${this.getWeekday()}｜宜${this.enrichVM.getAlmanac().suitable}·忌${this.enrichVM.getAlmanac().avoid}｜吉位${this.enrichVM.getAlmanac().direction}`)
        .fontSize(10)
        .fontColor('rgba(253, 246, 227, 0.55)')
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('82%')
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    // 底色与祈福页一致（#1a1a0a）：不再是一块发红的实心卡，只留一圈细描边
    .backgroundColor('#580E15')
    .border({ width: 1, color: 'rgba(255, 209, 0, 0.2)', radius: 8 })
    // 卡片整体收窄（字号/内边距同步下调），避免顶部卡片压到下方五神阵
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