// entry/src/main/ets/widget/pages/SignCard2x4.ets
// 每日求签中卡（2×4）：完整签诗 + 剩余额度；底部两个等宽按钮（抽签 / 解签）。
// 不提供「签录」入口（签录在 App 内查看）。
// 布局：内容从上往下排，中间用 layoutWeight(1) 的占位吸收剩余空间，
// 按钮始终贴在卡片底部内边距之上——之前按钮被挤到边框外就是少了这层弹性占位。
// message 里自带 form：扩展不依赖登记表也能正确处理点击。
let signCard2x4Storage: LocalStorage = new LocalStorage()

@Entry(signCard2x4Storage)
@Component
struct SignCard2x4 {
  @LocalStorageProp('signId') signId: number = 0
  @LocalStorageProp('level') level: string = ''
  @LocalStorageProp('levelColor') levelColor: string = '#9a9a9a'
  @LocalStorageProp('title') title: string = ''
  @LocalStorageProp('poem') poem: string = ''
  @LocalStorageProp('used') used: number = 0
  @LocalStorageProp('max') max: number = 3
  @LocalStorageProp('quota') quota: number = 0
  @LocalStorageProp('hasDrawn') hasDrawn: boolean = false
  @LocalStorageProp('drawOrder') drawOrder: number = 0

  /** 今日额度（每日固定 3 签；旧 binding 无 quota 字段时回退 max） */
  private quotaCell(): number {
    return this.quota > 0 ? this.quota : this.max
  }

  /** 抽签按钮文案（纯展示用；是否真的要付钱一律由 FormExtension 判定，不在这里下结论） */
  private drawButtonText(): string {
    if (this.used === 0) {
      return '抽一签'
    }
    if (this.used < this.quotaCell()) {
      return '再抽一签'
    }
    return '明日再来'
  }

  build() {
    Column() {
      // 已抽：今天第几次抽到的签（短串，12px + emoji 跨机型不截断）
      if (this.hasDrawn) {
        Text('🎋 今日最吉签 · 第' + this.drawOrder + '签')
          .fontSize(12)
          // 顶部渐变最亮（#C51F3A），金色 12sp 小字不足 4.5:1 → 用米色实色
          .fontColor('#fdf6e3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        // 未抽：主文案放大加粗做「引导点击」，副文案补一句怎么操作。
        // 拆成两行而不是塞一行长串——单行放大的话窄机型必然被截断。
        Text('🎋 今天还没抽签')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('点下面的按钮，试试今日运气')
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 3 })
      }

      // 抽到后展示签文（固定紧凑高度；表单不支持 Scroll，靠下方弹性占位把按钮钉在底部）
      if (this.hasDrawn) {
        // 【一行搞定】吉凶等级 + 签名横排：省下一整行垂直空间，卡片不再拥挤，
        // 也给底部按钮腾出了加高加大的余量（之前上下堆叠挤得按钮贴边）。
        Row() {
          // 吉凶等级：等级色徽章（金/绿/蓝/灰/红），深墨字在其上 ≥4.5:1
          if (this.level !== '') {
            Text(this.level)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1a1a0a')
              .backgroundColor(this.levelColor)
              .borderRadius(6)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .flexShrink(0)
          }
          // 签名（签的内容）
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .flexShrink(1)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ top: 10 })

        // 签诗
        Text(this.poem)
          .fontSize(12)
          .fontColor('rgba(253, 246, 227, 0.78)')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 6 })
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      Text('今日已摇 ' + this.used + '/' + this.max + ' 签')
        .fontSize(11)
        .fontColor('rgba(255, 209, 0, 0.7)')
        .margin({ top: 8 })

      // 弹性占位：吸收剩余高度，保证下方按钮组永远落在卡片内（内容已压缩紧凑，不会再被挤没）
      Column()
        .width('100%')
        .layoutWeight(1)

      // 底部两个动作：等宽平分，加高加大更好点按，文案过长自动省略
      Row() {
        this.DrawAction()

        Text('解签')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .borderRadius(20)
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.6)' })
          .height(40)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ left: 10 })
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { route: 'qiuqian', open: 'unlock' }
            })
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .alignItems(HorizontalAlign.Center)
    .linearGradient({ angle: 180, colors: [['#C51F3A', 0.0], ['#A3142A', 0.55], ['#6E0F18', 1.0]] })
  }

  /**
   * 抽签动作按钮：
   *   还有额度 → 发 message draw，由 FormExtension 真抽一签（**当场就把结果刷到卡片上**，
   *             用户在桌面直接看到第 2 签，和 App 里摇出来一样）；
   *   今日 3 签抽完 → 显示「明日再来」置灰（点击重判，跨天自动恢复）。
   */
  @Builder
  DrawAction() {
    if (this.used >= this.quotaCell()) {
      Text('明日再来')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('rgba(253, 246, 227, 0.65)')
        .backgroundColor('rgba(255, 209, 0, 0.08)')
        .border({ width: 1, color: 'rgba(255, 209, 0, 0.18)' })
        .borderRadius(20)
        .height(40)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          postCardAction(this, {
            action: 'message',
            params: { msgAction: 'draw', form: 'sign_2x4' }
          })
        })
    } else {
      Text(this.drawButtonText())
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#FFD700')
        .borderRadius(20)
        .height(40)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => {
          // params 必须是对象，自定义动作键名必须用 msgAction（见 SignCard2x2 注释）
          postCardAction(this, {
            action: 'message',
            params: { msgAction: 'draw', form: 'sign_2x4' }
          })
        })
    }
  }
}
