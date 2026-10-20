// entry/src/main/ets/widget/pages/SignCard2x2.ets
// 每日求签小卡（2×2）：只渲染 FormBindingData 注入的字段 + postCardAction 发交互。
// 卡片跑在系统「卡片渲染服务」进程：无 AppStorage、无 Context、无定时器、不能 import 页面文件。
// 小卡只给「标题 + 等级 + 签名 + 两个动作」，不塞签诗（2×2 放不下，交给 2×4）。
// message 里自带 form：扩展不依赖登记表也能正确处理点击。
// 抽签按钮：有额度走 message draw（扩展真抽）；额度用完显示「明日再来」（付费加购已下架）。
let signCard2x2Storage: LocalStorage = new LocalStorage()

@Entry(signCard2x2Storage)
@Component
struct SignCard2x2 {
  @LocalStorageProp('signId') signId: number = 0
  @LocalStorageProp('level') level: string = ''
  @LocalStorageProp('levelColor') levelColor: string = '#9a9a9a'
  @LocalStorageProp('title') title: string = ''
  @LocalStorageProp('used') used: number = 0
  @LocalStorageProp('max') max: number = 3
  @LocalStorageProp('quota') quota: number = 0
  @LocalStorageProp('hasDrawn') hasDrawn: boolean = false
  @LocalStorageProp('drawOrder') drawOrder: number = 0

  /** 今日额度（每日固定 3 签；旧 binding 无 quota 字段时回退 max） */
  private quotaCell(): number {
    return this.quota > 0 ? this.quota : this.max
  }

  /** 抽签按钮文案（纯展示；是否真的要付钱由 FormExtension 判定） */
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
        // 未抽：主文案 12px 加粗（此前 10px 太小，起不到引导作用）
        Text('🎋 今天还没抽签')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('试试今日运气')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.85)')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }

      // 未抽不剧透：等级徽章 / 签名只在今天抽过之后才显示
      if (this.hasDrawn) {
        if (this.level !== '') {
          Text(this.level)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor(this.levelColor)
            .borderRadius(8)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .margin({ top: 8 })
        }

        Text(this.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fdf6e3')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8 })
      }

      Row() {
        // 还有额度：发给 FormExtension 真抽一签，结果直接刷回卡片（桌面即刻看到第 2 签）
        this.DrawAction()

        Text('解签')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFD700')
          .borderRadius(14)
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.6)' })
          .height(30)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ left: 8 })
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: 'EntryAbility',
              params: { route: 'qiuqian', open: 'unlock' }
            })
          })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .linearGradient({ angle: 180, colors: [['#C51F3A', 0.0], ['#A3142A', 0.55], ['#6E0F18', 1.0]] })
  }

  /**
   * 抽签动作按钮：有额度 → 发 message draw，扩展真抽并把结果刷回卡片（桌面直接看到签）；
   * 今日 3 签抽完 → 置灰「明日再来」（点击仍发 message，由扩展重判，跨天自动恢复）。
   */
  @Builder
  DrawAction() {
    if (this.used >= this.quotaCell()) {
      Text('明日再来')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('rgba(253, 246, 227, 0.65)')
        .backgroundColor('rgba(255, 209, 0, 0.08)')
        .border({ width: 1, color: 'rgba(255, 209, 0, 0.18)' })
        .borderRadius(14)
        .height(30)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: 'message',
            params: { msgAction: 'draw', form: 'sign_2x2' }
          })
        })
    } else {
      Text(this.drawButtonText())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1a1a0a')
        .backgroundColor('#FFD700')
        .borderRadius(14)
        .height(30)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          // params 必须是对象；自定义动作键名必须用 msgAction（系统合并 JSON 的坑，见卡片注释）
          postCardAction(this, {
            action: 'message',
            params: { msgAction: 'draw', form: 'sign_2x2' }
          })
        })
    }
  }
}
