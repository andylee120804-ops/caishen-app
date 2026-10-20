// entry/src/main/ets/widget/pages/KowtowCard2x2.ets
// 磕头小卡（2×2）：顶部今日财神圆头像+名；中间小人为主体（站立帧+伏地帧叠加）；
// 点击即时切伏地帧（快速拜倒）+ 飘财运喜话；计数回传后交叉淡入回站立帧（起身）。
// 底部打赏入口跳 App（route: mine + tip=1）。
//
// ── 真实帧切换（非 scaleY 变形）──
// kowtow_stand.png / kowtow_bow.png 由 rawfile 960×960 序列帧(01站立/51伏地)裁剪人物
// alpha bbox、底部对齐到同一画布。脚不动、头从 43% 降到 56%，opacity 交叉淡入淡出
// 时观感是「上身拜下去」，比 scaleY 均匀压扁更像真人磕头。
//
// ── 卡片动画约束（同 MuyuCard2x2）──
// 1) 无 setTimeout，无法延时分段；
// 2) 同状态同帧两次赋值会合并 → 起始态必须不带动画；
// 3) 单次动效 ≤1000ms，不支持 delay/tempo/iterations。
// → 两段动画分落两帧：
//    · onClick：立即落地「伏地帧 + 祝福话出现」起始态（不加动画）；
//    · onCountRefreshed（@Watch 计数回传）：才 animateTo 交叉淡入回站立帧 + 祝福话上浮淡出。
//
// 卡片模块对外部 import 解析受限（其他卡片均零 import 自包含），祝福话内联于此。
const CARD_BLESSINGS: string[] = [
  '招财进宝！', '日进斗金！', '财源广进！', '金玉满堂！', '富贵吉祥！', '鸿运当头！',
  '财神附体！', '八方来财！', '金银满屋！', '生意兴隆！', '财运亨通！', '好运连连！'
]

let kowtowCard2x2Storage: LocalStorage = new LocalStorage()

@Entry(kowtowCard2x2Storage)
@Component
struct KowtowCard2x2 {
  @LocalStorageProp('deityId') deityId: number = 1
  @LocalStorageProp('deityName') deityName: string = ''
  @LocalStorageProp('todayKowtow') @Watch('onCountRefreshed') todayKowtow: number = 0
  @LocalStorageProp('totalKowtow') totalKowtow: number = 0
  // —— 真实帧 opacity（站立帧 / 伏地帧交叉淡入淡出）——
  @State standOpacity: number = 1     // 站立帧可见度
  @State bowOpacity: number = 0       // 伏地帧可见度
  // —— 飘祝福话 ——
  @State blessingOpacity: number = 0
  @State blessingY: number = 8
  @State blessingScale: number = 0.7
  @State blessingText: string = '招财进宝！'
  @State pending: boolean = false     // 是否有一次磕头在等计数回传收尾

  build() {
    // 根 Stack：打赏胶囊作为「兄弟节点」盖在整卡点击层之上（ClickEvent 无 stopPropagation，
    // 嵌套 onClick 会同时触发磕头；兄弟节点命中测试天然遮断下层，点胶囊只走 router）。
    Stack({ alignContent: Alignment.Bottom }) {
      // ── 整卡磕头点击层 ──
      Column() {
        // ① 顶部今日财神：30px 圆头像（金环）+ 名字胶囊
        Row() {
          // 五神各自一张 media 资源，$r 不能动态拼接，按 id 分支（同 DeityCard2x2）
          if (this.deityId === 2) {
            Image($r('app.media.deity_2'))
              .width(30).height(30).borderRadius(15).objectFit(ImageFit.Cover)
              .border({ width: 1.5, color: 'rgba(255, 215, 0, 0.6)' })
          } else if (this.deityId === 3) {
            Image($r('app.media.deity_3'))
              .width(30).height(30).borderRadius(15).objectFit(ImageFit.Cover)
              .border({ width: 1.5, color: 'rgba(255, 215, 0, 0.6)' })
          } else if (this.deityId === 4) {
            Image($r('app.media.deity_4'))
              .width(30).height(30).borderRadius(15).objectFit(ImageFit.Cover)
              .border({ width: 1.5, color: 'rgba(255, 215, 0, 0.6)' })
          } else if (this.deityId === 5) {
            Image($r('app.media.deity_5'))
              .width(30).height(30).borderRadius(15).objectFit(ImageFit.Cover)
              .border({ width: 1.5, color: 'rgba(255, 215, 0, 0.6)' })
          } else {
            Image($r('app.media.deity_1'))
              .width(30).height(30).borderRadius(15).objectFit(ImageFit.Cover)
              .border({ width: 1.5, color: 'rgba(255, 215, 0, 0.6)' })
          }

          Text(this.deityName === '' ? '今日财神' : this.deityName)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .backgroundColor('rgba(255, 215, 0, 0.14)')
            .border({ width: 0.5, color: 'rgba(255, 215, 0, 0.55)' })
            .borderRadius(8)
            .margin({ left: 6 })
        }
        .height(34)
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.Center)

        // ② 中间小人（主体）：站立帧 + 伏地帧叠加，opacity 交叉淡入淡出。
        // 尺寸必须显式钉死（35×56，源帧 235×378 同比缩）：不写尺寸时 Image 会撑满
        // layoutWeight 的整块弹性区（约 90vp 高），小人盖到底部打赏胶囊上。
        Stack() {
          // 财神红底上的柔金光晕，托住磕头小人、增强聚焦与层次（同 MuyuCard 氛围光）
          Row()
            .width(70)
            .height(84)
            .borderRadius(42)
            .backgroundColor('rgba(255, 215, 0, 0.10)')

          Image($r('app.media.kowtow_stand'))
            .width(35)
            .height(56)
            .objectFit(ImageFit.Contain)
            .opacity(this.standOpacity)

          Image($r('app.media.kowtow_bow'))
            .width(35)
            .height(56)
            .objectFit(ImageFit.Contain)
            .opacity(this.bowOpacity)

          // 磕头飘出的祝福话（替原 +1），置于两帧之上
          Text(this.blessingText)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD700')
            .textShadow({ radius: 8, color: 'rgba(255, 215, 0, 0.6)', offsetX: 0, offsetY: 0 })
            .opacity(this.blessingOpacity)
            .translate({ y: this.blessingY })
            .scale({ x: this.blessingScale, y: this.blessingScale })
        }
        .width('100%')
        .layoutWeight(1)
        .alignContent(Alignment.Center)

        // ③ 计数小字（最底部，打赏下方）
        Row() {
          Text('今日 ' + this.todayKowtow)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor('#fdf6e3')
            .maxLines(1)
          Text('累计 ' + this.totalKowtow)
            .fontSize(9)
            .fontColor('rgba(255, 215, 0, 0.8)')
            .maxLines(1)
            .margin({ left: 5 })
        }
        .height(16)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 8, right: 8, top: 8, bottom: 6 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .linearGradient({ angle: 180, colors: [['#C51F3A', 0.0], ['#A3142A', 0.55], ['#6E0F18', 1.0]] })
      .onClick(() => {
        this.kowtow()
      })

      // ④ 打赏入口（兄弟节点，置于计数上方；命中测试遮断下层磕头）→ route: mine + tip=1
      Text('♥ 打赏')
        .fontSize(9)
        .fontColor('rgba(255, 215, 0, 0.85)')
        .maxLines(1)
        .padding({ left: 8, right: 8, top: 1.5, bottom: 1.5 })
        .border({ width: 0.5, color: 'rgba(255, 215, 0, 0.5)' })
        .borderRadius(9)
        .margin({ bottom: 24 })
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: 'EntryAbility',
            params: { route: 'mine', tip: '1' }
          })
        })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 磕一下：即时切到伏地帧（快速拜倒）+ 祝福话出现，再下发计数。
   * 起始态必须落在这一帧且不带动画，否则与收尾帧赋值合并导致动画丢失。
   */
  private kowtow(): void {
    this.blessingText = CARD_BLESSINGS[Math.floor(Math.random() * CARD_BLESSINGS.length)]
    // 即时落地伏地帧（不加动画）+ 祝福话起始态
    this.standOpacity = 0
    this.bowOpacity = 1
    this.blessingOpacity = 1
    this.blessingY = 8
    this.blessingScale = 0.7
    this.pending = true
    postCardAction(this, {
      action: 'message',
      params: { msgAction: 'kowtow', form: 'kowtow_2x2' }
    })
  }

  /**
   * 计数回传（updateForm 更新 todayKowtow）：此刻已是新的一帧，才做收尾动画。
   * 交叉淡入回站立帧（起身）+ 祝福话上浮淡出。
   * 非磕头触发的更新（首次加载 / 定时刷新）pending 为 false，直接忽略。
   */
  onCountRefreshed(): void {
    if (!this.pending) {
      return
    }
    this.pending = false
    try {
      // 交叉淡入回站立帧（起身），420ms
      animateTo({ duration: 420, curve: Curve.EaseOut }, (): void => {
        this.standOpacity = 1
        this.bowOpacity = 0
      })
      // 祝福话上浮淡出（卡片单次动画上限 1000ms）
      animateTo({ duration: 900, curve: Curve.EaseOut }, (): void => {
        this.blessingOpacity = 0
        this.blessingY = -34
        this.blessingScale = 1.25
      })
    } catch (err) {
      console.error('[KowtowCard] kowtow anim failed: ' + JSON.stringify(err))
    }
  }
}
