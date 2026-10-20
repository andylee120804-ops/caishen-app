// entry/src/main/ets/pages/DonationDetailPage.ets
// 公益明细说明页（打赏弹窗「公益明细 ›」进入）。
// 用途：把「打赏的钱去了哪里」讲清楚 —— 渠道分成 / 开发维护 / 公益捐赠三段，
// 并给出公益捐赠渠道与公示方式。这是打赏功能的合规与信任基础，文案改动请谨慎：
// · 必须写明打赏为自愿赠与、**不解锁任何权益**（否则易被判为购买祈福效果而拒审）；
// · 公益部分写明通过官方渠道捐赠，并明确「本应用与受赠机构无隶属/赞助关系」，
//   避免构成不实背书（就这样为用户着想，也保护上架审核）。
import { SUPPORT_EMAIL } from '../components/ContactSupportDialog'

@Entry
@Component
struct DonationDetailPage {  @Builder
  GlowOverlay() {
    Column()
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      .radialGradient({ center: ['50%', '12%'], radius: '58%', colors: [['rgba(255, 209, 0, 0.40)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]] })
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
        Text('公益明细')
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

      Scroll() {
        Column() {
          // 公益排行榜入口：打赏流水实时汇总，谁的支持最多一目了然（昵称脱敏）
          Row() {
            Row() {
              Text('♡')
                .fontSize(15)
                .fontColor('#FFD700')
            }
            .width(34)
            .height(34)
            .justifyContent(FlexAlign.Center)
            .borderRadius(17)
            .backgroundColor('rgba(255, 209, 0, 0.10)')
            .border({ width: 1, color: 'rgba(255, 209, 0, 0.45)' })
            .margin({ right: 12 })

            Column() {
              Text('公益排行榜')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor('#fdf6e3')
                .width('100%')
              Text('看看都有谁在支持作者与公益')
                .fontSize(11)
                .fontColor('rgba(253, 246, 227, 0.55)')
                .width('100%')
                .margin({ top: 3 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Text('›')
              .fontSize(22)
              .fontColor('rgba(255, 209, 0, 0.7)')
          }
          .width('90%')
          .alignItems(VerticalAlign.Center)
          .padding(14)
          .backgroundColor('rgba(255, 209, 0, 0.07)')
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.22)', radius: 10 })
          .margin({ top: 6, bottom: 14 })
          .onClick((): void => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/DonationBoardPage' })
          })

          Text('打赏去了哪里')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
            .width('90%')
            .margin({ bottom: 10 })

          // ① 渠道费
          this.SectionCard('应用商店渠道费', '华为应用市场会按规则收取一定比例的服务费，并代扣相关税费。这也是打赏到账的第一道扣除。', '渠')

          // ② 开发与维护
          this.SectionCard('后续开发和维护', '余下部分用于本应用的服务器、接口与内容更新、机型适配与日常维护，让「财神保佑」能持续更新下去。', '维')

          // ③ 公益捐赠
          this.SectionCard('公益捐赠', '打赏所得的一部分，将以本应用名义通过联合国儿童基金会（UNICEF）官方渠道捐赠，用于儿童保护、营养、教育与紧急救助相关项目。', '益')

          // 公示方式
          Column() {
            Text('捐赠公示')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD700')
              .width('100%')
              .margin({ bottom: 6 })
            Text('每笔公益捐赠均保留官方渠道出具的捐赠凭证。我们按半年为周期汇总捐赠时间、金额与凭证编号，并在本页更新；未达到起捐额度的月份顺延到下一周期。')
              .fontSize(12)
              .fontColor('rgba(253, 246, 227, 0.6)')
              .width('100%')
          }
          .width('90%')
          .padding(14)
          .backgroundColor('rgba(255, 209, 0, 0.07)')
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.22)', radius: 10 })
          .margin({ bottom: 12 })

          // 免责与答疑
          Column() {
            Text('两点说明')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD700')
              .width('100%')
              .margin({ bottom: 6 })
            Text('1. 打赏是你对开发者的自愿赠与，不承诺任何祈福效果、也不改变签文的随机结果；打赏不解锁任何次数或权益（求签每日固定免费 3 次，解签全文免费）。退款请联系华为应用市场的支付客服渠道。')
              .fontSize(12)
              .fontColor('rgba(253, 246, 227, 0.6)')
              .width('100%')
              .margin({ bottom: 6 })
            Text('2. 本应用与联合国儿童基金会（UNICEF）不存在隶属、赞助或官方合作关系，捐赠为开发者以应用名义作出的单向赠与。')
              .fontSize(12)
              .fontColor('rgba(253, 246, 227, 0.6)')
              .width('100%')
              .margin({ bottom: 6 })
            Text(`对公益明细有疑问？欢迎随时联系我们：${SUPPORT_EMAIL}`)
              .fontSize(12)
              .fontColor('rgba(255, 209, 0, 0.85)')
              .width('100%')
              .copyOption(CopyOptions.LocalDevice)
          }
          .width('90%')
          .padding(14)
          .backgroundColor('rgba(253, 246, 227, 0.04)')
          .border({ width: 1, color: 'rgba(253, 246, 227, 0.12)', radius: 10 })
          .margin({ bottom: 20 })
        }
        .width('100%')
        .padding({ bottom: 28 })
      }
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 180, colors: [['#D23B2E', 0.0], ['#A51D16', 0.55], ['#6F120E', 1.0]] })
    .overlay(this.GlowOverlay)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
  }

  /** 三段去向卡片：标题 + 说明，左侧单字圆形徽标做视觉锚点（不用 emoji，避免字形差异） */
  @Builder
  SectionCard(title: string, desc: string, glyph: string) {
    Row() {
      Row() {
        Text(glyph)
          .fontSize(16)
          .fontColor('#FFD700')
      }
      .width(34)
      .height(34)
      .justifyContent(FlexAlign.Center)
      .borderRadius(17)
      .backgroundColor('rgba(255, 209, 0, 0.10)')
      .border({ width: 1, color: 'rgba(255, 209, 0, 0.45)' })
      .margin({ right: 12 })

      Column() {
        Text(title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
          .width('100%')
        Text(desc)
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.55)')
          .width('100%')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('90%')
    .alignItems(VerticalAlign.Center)
    .padding(14)
    .backgroundColor('rgba(255, 209, 0, 0.05)')
    .border({ width: 1, color: 'rgba(255, 209, 0, 0.12)', radius: 10 })
    .margin({ bottom: 10 })
  }
}
