// entry/src/main/ets/pages/DonationBoardPage.ets
// 公益排行榜（从「公益明细」页进入）：按累计打赏金额排名 —— 打赏支持作者的一份心意，
// 同时记进这张公益榜；打赏所得的一部分会捐赠给联合国儿童基金会（UNICEF）。
// 数据源：云函数 donation-record action=board（服务端已做昵称脱敏，昵称形如「好友 3f2a」）。
// 排名约定与祈福榜一致：rank > 0 为上榜名次；rank === 0 表示我没进前 50，单列「我的位置」。
import { CloudService } from '../service/CloudService'
import { DonationBoard, DonationEntry } from '../model/EnrichTypes'

@Entry
@Component
struct DonationBoardPage {
  @State board: DonationBoard = { entries: [], summary: { donorCount: 0, totalAmount: 0 } }
  @State entries: DonationEntry[] = []
  @State myEntry: DonationEntry = { isMe: true, nickname: '', amount: 0, count: 0, rank: 0 }
  @State hasMyEntry: boolean = false
  @State loading: boolean = false

  aboutToAppear(): void {
    this.loadBoard()
  }

  async loadBoard(): Promise<void> {
    this.loading = true
    try {
      const data: DonationBoard = await CloudService.getDonationBoard()
      this.board = data
      this.entries = data.entries.filter((e: DonationEntry): boolean => e.rank > 0)
      const me: DonationEntry | undefined = data.entries.find((e: DonationEntry): boolean => e.rank === 0)
      if (me) {
        this.myEntry = me
        this.hasMyEntry = true
      } else {
        this.hasMyEntry = false
      }
    } catch (err) {
      console.error('[DonationBoard] load failed:', JSON.stringify(err))
    } finally {
      this.loading = false
    }
  }

  build() {
    Column() {
      // 返回头（与其它子页同一套：← 返回 / 标题居中 / 右侧配平占位）
      Row() {
        Text('← 返回')
          .fontSize(14)
          .fontColor('#FFD700')
          .onClick((): void => {
            this.getUIContext().getRouter().back()
          })
        Blank()
        Text('公益排行榜')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
        Blank()
        Text(' ')
          .fontSize(14)
          .width(60)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 44, bottom: 6 })
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      // 汇总：累计打赏金额 + 参与人数
      Row() {
        Column() {
          Text(`¥${this.board.summary.totalAmount}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
          Text('累计打赏支持')
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Text(`${this.board.summary.donorCount}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
          Text('位好友同行')
            .fontSize(10)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
      }
      .width('90%')
      .padding({ top: 12, bottom: 12 })
      .backgroundColor('rgba(255, 209, 0, 0.07)')
      .border({ width: 1, color: 'rgba(255, 209, 0, 0.22)', radius: 12 })
      .margin({ bottom: 8 })

      Text('其中一部分已转为公益捐赠 · 明细见「公益明细」')
        .fontSize(10)
        .fontColor('rgba(255, 209, 0, 0.7)')
        .margin({ bottom: 10 })

      if (this.loading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color('#FFD700')
          .margin({ top: 40 })
      } else if (this.entries.length === 0 && !this.hasMyEntry) {
        Column() {
          Text('♡')
            .fontSize(34)
            .fontColor('rgba(255, 209, 0, 0.6)')
            .margin({ bottom: 8 })
          Text('还没有人打赏')
            .fontSize(14)
            .fontColor('#fdf6e3')
          Text('成为第一位支持作者、也支持公益的好友')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.5)')
            .margin({ top: 6 })
        }
        .width('90%')
        .padding({ top: 40, bottom: 40 })
        .backgroundColor('rgba(253, 246, 227, 0.04)')
        .border({ width: 1, color: 'rgba(253, 246, 227, 0.1)', radius: 12 })
      } else {
        Scroll() {
          Column() {
            ForEach(this.entries, (item: DonationEntry) => {
              this.BoardRow(item, item.isMe)
            }, (item: DonationEntry) => 'r' + item.rank)

            if (this.hasMyEntry) {
              Column() {
                Row()
                  .width('100%')
                  .height(1)
                  .backgroundColor('rgba(255, 209, 0, 0.18)')
                  .margin({ bottom: 6 })
                Text('我的位置')
                  .fontSize(10)
                  .fontColor('rgba(255, 209, 0, 0.7)')
                  .margin({ bottom: 4 })
                this.BoardRow(this.myEntry, true)
              }
              .width('100%')
              .margin({ top: 8 })
            }
          }
          .width('90%')
          .padding({ bottom: 28 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#D23B2E', 0.0], ['#A51D16', 0.55], ['#6F120E', 1.0]] })
    .overlay(this.OverlayBg)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  /** overlay 顶部光晕 */
  @Builder
  OverlayBg() {
    Column()
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .radialGradient({ center: ['50%', '12%'], radius: '58%', colors: [['rgba(255, 209, 0, 0.40)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]] })
  }

  /** 榜单行：排名 / 昵称 / 金额 / 笔数 */
  @Builder
  BoardRow(entry: DonationEntry, isMe: boolean) {
    Row() {
      Text(this.getRankText(entry.rank))
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getRankColor(entry.rank))
        .width(40)
        .textAlign(TextAlign.Center)

      Text(isMe ? '我' : entry.nickname)
        .fontSize(14)
        .fontColor('#fdf6e3')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`¥${entry.amount}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFD700')
        .margin({ right: 12 })

      Text(`${entry.count}笔`)
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.55)')
    }
    .width('100%')
    // 排名(16)/昵称(14)/金额(14)/笔数(11) 字号不同，底对齐保证文本基线一致
    .alignItems(VerticalAlign.Bottom)
    .padding(12)
    .backgroundColor(isMe ? 'rgba(255, 209, 0, 0.12)' : 'transparent')
    .border({ width: { bottom: 0.5 }, color: 'rgba(255, 209, 0, 0.08)' })
    .borderRadius(isMe ? 8 : 0)
  }

  private getRankText(rank: number): string {
    if (rank <= 0) {
      return '···'
    }
    if (rank === 1) {
      return '🥇'
    }
    if (rank === 2) {
      return '🥈'
    }
    if (rank === 3) {
      return '🥉'
    }
    return `${rank}`
  }

  private getRankColor(rank: number): string {
    if (rank === 1) {
      return '#FFD700'
    }
    if (rank === 2) {
      return '#c0c0c0'
    }
    if (rank === 3) {
      return '#cd7f32'
    }
    return 'rgba(253, 246, 227, 0.5)'
  }
}
