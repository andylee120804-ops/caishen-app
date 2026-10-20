// entry/src/main/ets/widget/pages/DeityCard2x2.ets
// 今日主财神小卡（2×2）：主神图片 + 姓名/方位/财神寓意小字；整卡点击跳祈福页拜主神。
// 图片走 media 资源 $r('app.media.deity_N')：随卡片包加载，由扩展下发的 deityId 选定。

let deityCard2x2Storage: LocalStorage = new LocalStorage()

@Entry(deityCard2x2Storage)
@Component
struct DeityCard2x2 {
  @LocalStorageProp('deityId') deityId: number = 1
  @LocalStorageProp('deityName') deityName: string = ''
  @LocalStorageProp('deityDirection') deityDirection: string = ''
  @LocalStorageProp('deityMeaning') deityMeaning: string = ''

  build() {
    Column() {
      // 五神各自一张 media 资源，$r 不能动态拼接，按 id 分支选择
      Stack() {
        if (this.deityId === 2) {
          Image($r('app.media.deity_2'))
            .width(90)
            .height(90)
            .objectFit(ImageFit.Contain)
        } else if (this.deityId === 3) {
          Image($r('app.media.deity_3'))
            .width(90)
            .height(90)
            .objectFit(ImageFit.Contain)
        } else if (this.deityId === 4) {
          Image($r('app.media.deity_4'))
            .width(90)
            .height(90)
            .objectFit(ImageFit.Contain)
        } else if (this.deityId === 5) {
          Image($r('app.media.deity_5'))
            .width(90)
            .height(90)
            .objectFit(ImageFit.Contain)
        } else {
          Image($r('app.media.deity_1'))
            .width(90)
            .height(90)
            .objectFit(ImageFit.Contain)
        }
      }
      .width(100)
      .height(100)

      Text(this.deityName === '' ? '财神' : this.deityName)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 4 })

      if (this.deityDirection !== '') {
        Text(this.deityDirection)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.7)')
          .margin({ top: 1 })
      }

      if (this.deityMeaning !== '') {
        Text(this.deityMeaning)
          .fontSize(8)
          .fontColor('rgba(253, 246, 227, 0.55)')
          .width('100%')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .linearGradient({ angle: 180, colors: [['#C51F3A', 0.0], ['#A3142A', 0.55], ['#6E0F18', 1.0]] })
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { route: 'blessing' }
      })
    })
  }
}
