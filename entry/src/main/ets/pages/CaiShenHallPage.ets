// entry/src/main/ets/pages/CaiShenHallPage.ets
// 财神殿 Tab 主页（常驻，在「祈福」之后）。
//
// v8 布局（2026-10-19 重排）：
//   · 顶部不再放签到/装扮入口，匾额直接落在安全区下方；
//   · 竖向固定分区：匾额 → 弹性舞台（神像 ≤60%/236、空隙、香炉 ≤38%/140）→ 说明 → 四槽位 → 心意值条；
//   · 区块各占各的位置，不再出现 height('100%') + layoutWeight 互相挤压，杜绝重叠；
//   · 四件陈设等宽等高，素材已裁掉透明边 + Contain，永不越框；删除与槽位重复的底部 dock；
//   · 香炉改用空炉素材 censer_empty.png，单支香从炉口插入（下半截被炉身遮住）；
//   · 灵光「常驻/收起」按每件物品独立控制（含宫灯）。
//
// 元素：AI 大殿背景图 / 神像呼吸光晕 / 匾额 / 财神像 / 供桌 / 正中香炉 / 殿内四件真实贴图陈设 /
//       点亮金色辉光 / 落座金光特效 / 心意值条 / 合规说明。
// 交互：上香免费（心意值）、四件陈设付费（复用打赏 tip_8/18/88/188，不新建 AGC 商品）。
// 合规铁律：灯与香绝不售卖，屏幕上看不到「钱换香」的因果链；心意值每日清零、靠每日行为获取。
import { HallViewModel } from '../viewmodels/HallViewModel'
import { DonateDialog } from '../components/DonateDialog'
import { CloudService } from '../service/CloudService'
import { TIP_PRODUCTS, TipProduct } from '../service/IPaymentService'

/** 四件殿内陈设（img 为已裁掉透明边的真实贴图，槽位内统一 Contain） */
interface WareDef {
  key: string
  name: string
  price: number
  img: string
}
const WARES: WareDef[] = [
  { key: 'lamp',  name: '宫灯',   price: 8,   img: 'props/ware_lamp.png' },
  { key: 'vase',  name: '金瓶',   price: 18,  img: 'props/ware_vase.png' },
  { key: 'fresh', name: '鲜花',   price: 88,  img: 'props/ware_flower.png' },
  { key: 'basin', name: '聚宝盆', price: 188, img: 'props/ware_basin.png' }
]

@Component
export struct CaiShenHallPage {
  @StorageLink('hallVM') hallVM: HallViewModel = new HallViewModel()
  @StorageLink('hallRev') @Watch('onRev') hallRev: number = 0

  // 上香状态：香火一旦点上就常驻（当日再次进殿也会保持）
  @State incenseLit: boolean = false
  @State stickDown: boolean = false
  @State emberOn: boolean = false
  @State smokeBob: boolean = false
  private smokeTimer: number = -1
  /** 一次性定时器集合（上香分步动画/飘字），页面销毁时统一清理，避免对已销毁组件写状态 */
  private timers: number[] = []

  // 神像呼吸光晕
  @State glowOn: boolean = false
  private glowTimer: number = -1

  // 飘字 / toast
  @State flyText: string = ''
  @State flyVisible: boolean = false
  @State toastText: string = ''
  @State toastVisible: boolean = false
  private toastTimer: number = -1

  // 落座金光特效（购买/解锁成功时在该槽位爆一圈光）
  @State placingKey: string = ''
  @State placingOn: boolean = false
  private placeTimer: number = -1

  private wishController: CustomDialogController | null = null
  /** 陈设购买弹窗控制器（持有引用，避免弹窗存活期间控制器被回收） */
  private payController: CustomDialogController | null = null

  aboutToAppear(): void {
    this.hallVM.checkDaily()
    this.hallVM.refreshTodayDeity()
    // 当天已经上过香 → 直接呈现「香火正旺」
    this.incenseLit = this.hallVM.sticksToday > 0
    if (this.incenseLit) {
      this.stickDown = true
      this.emberOn = true
      this.startSmoke()
    }
    this.glowTimer = setInterval(() => {
      this.glowOn = !this.glowOn
    }, 2250)
  }

  aboutToDisappear(): void {
    if (this.smokeTimer >= 0) {
      clearInterval(this.smokeTimer)
      this.smokeTimer = -1
    }
    if (this.glowTimer >= 0) {
      clearInterval(this.glowTimer)
      this.glowTimer = -1
    }
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
      this.toastTimer = -1
    }
    if (this.placeTimer >= 0) {
      clearTimeout(this.placeTimer)
      this.placeTimer = -1
    }
    for (const id of this.timers) {
      clearTimeout(id)
    }
    this.timers = []
  }

  /** 记录一次性定时器，便于页面销毁时统一清理 */
  private later(cb: () => void, ms: number): void {
    this.timers.push(setTimeout(cb, ms))
  }

  onRev(): void {
  }

  // ── 宫灯（长明灯）：灵光独立开关；当日首次点亮仍走心意值/连续点亮逻辑 ──
  private onLamp(): void {
    if (this.hallVM.isWareLit('lamp')) {
      // 收起灵光：不影响当日已点亮的灯与连续天数
      this.hallVM.toggleWareLit('lamp')
      this.toast('宫灯 · 已收起')
      return
    }
    const r = this.hallVM.lightLamp()
    if (r === 'noheart') {
      this.toast('心意值不足 · 每日进殿可积攒')
      return
    }
    this.hallVM.toggleWareLit('lamp')
    if (r === 'ok') {
      this.fly('长明灯亮')
    } else {
      // 当日已点亮过：再次点开只是恢复常驻，不再扣心意值
      this.toast('宫灯 · 灵光常驻')
    }
  }

  // ── 上香 ──
  private onCenser(): void {
    if (this.incenseLit) {
      this.toast('心意正暖 · 财源广进')
      return
    }
    if (!this.hallVM.beginIncense()) {
      this.toast('心意值不足 · 每日进殿可积攒')
      return
    }
    // 心意与支数立即落账，避免中途离开页面丢失回向
    this.hallVM.completeIncense()
    this.incenseLit = true
    this.stickDown = false
    this.emberOn = false
    // 下一帧滑入，避免条件创建时动画被跳过
    this.later(() => {
      this.stickDown = true
    }, 16)
    this.later(() => {
      this.emberOn = true
    }, 260)
    this.later(() => {
      this.startSmoke()
    }, 300)
    this.toast('香已入炉 · 财源广进')
  }

  private startSmoke(): void {
    if (this.smokeTimer >= 0) {
      return
    }
    this.smokeBob = false
    this.smokeTimer = setInterval(() => {
      this.smokeBob = !this.smokeBob
    }, 900)
  }

  // ── 财神像点击 → 写心愿 ──
  private openWish(): void {
    // 防叠加：连续点财神像会在已有弹窗没关的情况下再叠一个（实测 07:35:43 那次闪退
    // 前 4 秒内叠了 15 个弹窗）。已有一个时忽略本次点击，等它关掉（aboutToDisappear
    // → onClosed 释放引用）后再开。
    if (this.wishController !== null) {
      return
    }
    // 每次新建：跨天轮换主财神后，弹窗里的 deityId 必须取当天值
    const dlg = new CustomDialogController({
      builder: WishDialog({
        deityId: this.hallVM.todayDeity.id,
        onSubmit: (content: string): void => {
          this.submitWish(content)
        },
        onClose: (): void => {
          // 关闭兜底：用本页持有的 wishController 引用关掉心愿弹窗（该引用必然有效）
          const c = this.wishController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[Hall] wish dialog onClose failed')
            }
          }
        },
        onClosed: (): void => {
          this.wishController = null
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.wishController = dlg
    dlg.open()
  }

  private submitWish(content: string): void {
    const text = content.trim()
    if (text === '') {
      this.toast('写点什么再记下吧')
      return
    }
    CloudService.createWish(text, this.hallVM.todayDeity.id).then((ok: boolean) => {
      this.toast(ok ? '心愿已记下 · 财神见证' : '心愿稍后重试')
    }).catch(() => {
      this.toast('心愿稍后重试')
    })
  }

  // ── 殿内四件陈设：未拥有 → 购买；已拥有 → 只切换该件自己的灵光 ──
  private onWare(item: string): void {
    if (!this.hallVM.isWareOwned(item)) {
      this.openWarePay(item)
      return
    }
    if (item === 'lamp') {
      this.onLamp()
      return
    }
    this.hallVM.toggleWareLit(item)
    const def = WARES.find((d: WareDef): boolean => d.key === item)
    if (def !== undefined) {
      this.toast(`${def.name} · ${this.hallVM.isWareLit(item) ? '灵光常驻' : '已收起'}`)
    }
  }

  /** 未拥有 → 直接按对应档位（¥8/18/88/188）拉起打赏支付，成功后解锁该陈设 */
  private openWarePay(item: string): void {
    const target = WARES.find((d: WareDef): boolean => d.key === item)
    if (target === undefined) {
      return
    }
    const product = TIP_PRODUCTS.find((p: TipProduct): boolean => p.amount === target.price) as TipProduct
    const dlg = new CustomDialogController({
      builder: DonateDialog({
        locked: product,
        lockTitle: `财神殿陈设 · ${target.name}`,
        onClose: (): void => {
          // 关闭兜底：用本页持有的 payController 引用关掉打赏弹窗（该引用必然有效）
          const c = this.payController
          if (c !== undefined && c !== null) {
            try {
              c.close()
            } catch (err) {
              console.error('[Hall] donate dialog onClose failed')
            }
          }
        },
        onSuccess: (p: TipProduct): void => {
          // 必须按「实际付款档位」定位陈设，不能用点击时捕获的 target：
          // 补单路径（上次已付款但没消耗完）回调的是历史订单档位，固定解 target
          // 会出现「¥8 补单却解锁 ¥188 聚宝盆」的越档解锁。
          const paid = WARES.find((d: WareDef): boolean => d.price === p.amount)
          if (paid === undefined) {
            console.error('[Hall] paid tier has no matching ware: amount=' + p.amount)
            return
          }
          this.hallVM.setWareOwned(paid.key, true)
          // 新陈设默认灵光常驻；宫灯保持「首次点亮走心意值」的既有逻辑
          if (paid.key !== 'lamp' && !this.hallVM.isWareLit(paid.key)) {
            this.hallVM.toggleWareLit(paid.key)
          }
          this.playPlace(paid.key)
          // 注意：不要在这里 dlg.close()——DonateDialog 拉起收银台前已自行关闭，
          // 重复 close 会命中已销毁的弹窗（闪退）。
        }
      }),
      autoCancel: true,
      alignment: DialogAlignment.Center,
      customStyle: true
    })
    this.payController = dlg
    dlg.open()
  }

  /** 播放落座金光特效：该槽位爆一圈金光并轻微放大后恢复 */
  private playPlace(key: string): void {
    this.placingKey = key
    this.placingOn = true
    if (this.placeTimer >= 0) {
      clearTimeout(this.placeTimer)
    }
    this.placeTimer = setTimeout(() => {
      this.placingOn = false
    }, 700)
  }

  // ── 四槽位（等宽等高，唯一购买/陈列入口）──
  @Builder
  WareCell(def: WareDef) {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.hallVM.isWareOwned(def.key)) {
        // 已拥有：独立金色灵光 + 真实贴图 + 名称条（Contain 保证不越框）
        Stack()
          .width('80%')
          .aspectRatio(1)
          .margin({ bottom: 26 })
          .radialGradient({
            center: ['50%', '55%'],
            radius: '60%',
            colors: [['rgba(255, 220, 120, 0.55)', 0.0], ['rgba(255, 220, 120, 0)', 1.0]]
          })
          .opacity(this.hallVM.isWareLit(def.key) ? 1 : 0)
          .animation({ duration: 400 })
          .hitTestBehavior(HitTestMode.None)

        Image($rawfile(def.img))
          .width('82%')
          .height('76%')
          .margin({ bottom: 22 })
          .objectFit(ImageFit.Contain)
          .brightness(this.hallVM.isWareLit(def.key) ? 1.12 : 1)

        Text(def.name)
          .width('100%')
          .height(22)
          .textAlign(TextAlign.Center)
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.86)')
          .linearGradient({
            angle: 180,
            colors: [['rgba(24, 4, 6, 0)', 0.0], ['rgba(24, 4, 6, 0.78)', 1.0]]
          })

        if (this.hallVM.isWareLit(def.key)) {
          Column()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor('#FFD700')
            .position({ x: '100%', y: 7 })
            .translate({ x: -13 })
            .hitTestBehavior(HitTestMode.None)
        }
      } else {
        // 未拥有：虚线占位（＋ + 名称 + 价格），点击走打赏购买
        Column() {
          Text('＋')
            .fontSize(20)
            .lineHeight(22)
            .fontColor('rgba(255, 209, 0, 0.85)')
          Text(def.name)
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.78)')
            .margin({ top: 4 })
          Text(`¥${def.price}`)
            .fontSize(10)
            .fontColor('rgba(255, 209, 0, 0.85)')
            .margin({ top: 2 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // 落座金光：刚解锁的陈设爆一圈金色辉光
      Stack()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '50%'],
          radius: '70%',
          colors: [['rgba(255, 220, 120, 0.95)', 0.0], ['rgba(255, 220, 120, 0)', 1.0]]
        })
        .opacity(this.placingOn && this.placingKey === def.key ? 1 : 0)
        .animation({ duration: 600, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.None)
    }
    .layoutWeight(1)
    .height('100%')
    .margin({ left: 4, right: 4 })
    .borderRadius(14)
    .clip(true)
    .backgroundColor(this.hallVM.isWareOwned(def.key) ? 'rgba(60, 10, 16, 0.42)' : 'rgba(60, 10, 16, 0.26)')
    .radialGradient({
      center: ['50%', '42%'],
      radius: '72%',
      colors: this.hallVM.isWareOwned(def.key)
        ? [['rgba(120, 60, 12, 0.35)', 0.0], ['rgba(40, 8, 10, 0.42)', 1.0]]
        : [['rgba(60, 10, 16, 0.0)', 0.0], ['rgba(60, 10, 16, 0.0)', 1.0]]
    })
    .border({
      width: 1.5,
      color: this.hallVM.isWareOwned(def.key) ? 'rgba(255, 209, 0, 0.50)' : 'rgba(255, 209, 0, 0.42)',
      style: this.hallVM.isWareOwned(def.key) ? BorderStyle.Solid : BorderStyle.Dashed
    })
    .scale({
      x: this.placingOn && this.placingKey === def.key ? 1.06 : 1,
      y: this.placingOn && this.placingKey === def.key ? 1.06 : 1
    })
    .animation({ duration: 220, curve: Curve.EaseOut })
    .onClick(() => this.onWare(def.key))
  }

  // ── 飘字 / toast ──
  private fly(text: string): void {
    this.flyText = text
    this.flyVisible = false
    this.later(() => {
      this.flyVisible = true
    }, 16)
    this.later(() => {
      this.flyVisible = false
    }, 1200)
  }

  private toast(msg: string): void {
    this.toastText = msg
    this.toastVisible = true
    if (this.toastTimer >= 0) {
      clearTimeout(this.toastTimer)
    }
    this.toastTimer = setTimeout(() => {
      this.toastVisible = false
    }, 2200)
  }

  build() {
    Stack() {
      // ══ 背景层：只有背景延伸到状态栏/手势条下，内容保持在安全区内 ══
      Image($rawfile('props/hall_bg.png'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])

      // 压暗叠层（增强前景对比）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(20, 4, 6, 0.46)', 0.0],
            ['rgba(20, 4, 6, 0.10)', 0.22],
            ['rgba(20, 4, 6, 0)', 0.46],
            ['rgba(20, 4, 6, 0.16)', 1.0]
          ]
        })
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .hitTestBehavior(HitTestMode.None)

      // 顶部金色光晕（halo）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '10%'],
          radius: '60%',
          colors: [['rgba(255, 209, 0, 0.30)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .hitTestBehavior(HitTestMode.None)

      // 宫灯灵光常驻后的暖光
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '58%'],
          radius: '55%',
          colors: [['rgba(255, 190, 70, 0.30)', 0.0], ['rgba(255, 190, 70, 0)', 1.0]]
        })
        .opacity(this.hallVM.isWareLit('lamp') ? 0.12 : 0)
        .animation({ duration: 1000 })
        .expandSafeArea([SafeAreaType.SYSTEM],
          [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM, SafeAreaEdge.START, SafeAreaEdge.END])
        .hitTestBehavior(HitTestMode.None)

      // ══ 内容：固定分区 + 弹性舞台 ══
      // 沉浸式全屏下页面内容从 y=0 起排，Pura X 内屏前置摄像头为中置挖孔，
      // 必须整体下移避开状态栏/挖孔（与 MyPage/其余 Tab 页同一套 44vp 顶部安全距）。
      Column() {
        // 匾额
        Text('財神殿')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .letterSpacing(8)
          .width(150)
          .height(44)
          .textAlign(TextAlign.Center)
          .borderRadius(8)
          .backgroundColor('#3c0a10')
          .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.55)' })
          .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.45)' })
          .margin({ top: 12, bottom: 8 })

        // 舞台：神像 60% / 空隙 2% / 香炉 38%，互不侵占
        Column() {
          // 财神像 + 呼吸光晕（可点写心愿）
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width(260)
              .height('100%')
              .radialGradient({
                center: ['50%', '55%'],
                radius: '58%',
                colors: [['rgba(255, 209, 0, 0.30)', 0.0], ['rgba(255, 209, 0, 0)', 1.0]]
              })
              .opacity(this.glowOn ? 1 : 0.82)
              .animation({ duration: 2250, curve: Curve.EaseInOut })
              .hitTestBehavior(HitTestMode.None)
            Image($rawfile(`deities/${this.hallVM.todayDeity.id}.png`))
              .height('100%')
              .aspectRatio(1)
              .objectFit(ImageFit.Contain)
          }
          .width('100%')
          .height('60%')
          .constraintSize({ maxHeight: 236 })
          .onClick(() => this.openWish())

          Blank()
            .layoutWeight(1)

          // 供桌 + 香炉（整组可点，香从炉口插入）
          Column() {
            Stack({ alignContent: Alignment.Center }) {
              // 香柱：下端插入炉口，炉身图后绘制会盖住下半截
              if (this.incenseLit) {
                Column() {
                  Column()
                    .width(8)
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor('#FF7B39')
                    .radialGradient({
                      center: ['50%', '45%'],
                      radius: '55%',
                      colors: [
                        ['#fff3c4', 0.0],
                        ['#ffd08a', 0.28],
                        ['#ff7a34', 0.62],
                        ['#b33a1c', 1.0]
                      ]
                    })
                    .shadow({ radius: 6, color: 'rgba(255, 140, 50, 0.75)' })
                    .scale({ x: this.smokeBob ? 1.18 : 1, y: this.smokeBob ? 1.18 : 1 })
                    .opacity(this.emberOn ? 1 : 0)
                    .animation({ duration: 300, curve: Curve.EaseInOut })
                  Column()
                    .width(4)
                    .height(44)
                    .borderRadius(2)
                    .backgroundColor('#8A5A34')
                }
                .width(10)
                .position({ x: '50%', y: -28 })
                .translate({ x: -5, y: this.stickDown ? 0 : -40 })
                .opacity(this.stickDown ? 1 : 0)
                .animation({ duration: 280, curve: Curve.EaseOut })
              }

              // 空炉（原 incense_burner.png 自带三炷香，已另存空炉素材）
              Image($rawfile('props/censer_empty.png'))
                .height('100%')
                .aspectRatio(327 / 219)
                .objectFit(ImageFit.Contain)

              // 香烟
              if (this.incenseLit) {
                ForEach([0, 1, 2], (i: number) => {
                  Column()
                    .width(10)
                    .height(10)
                    .borderRadius(5)
                    .radialGradient({
                      center: ['50%', '50%'],
                      radius: '50%',
                      colors: [['rgba(255, 255, 255, 0.65)', 0.0], ['rgba(255, 255, 255, 0)', 1.0]]
                    })
                    .opacity(this.smokeBob ? 0.22 : 0.55)
                    .position({ x: '50%', y: -32 })
                    .translate({
                      x: (i - 1) * 10 - 4,
                      y: this.smokeBob ? -46 - i * 8 : -24 - i * 8
                    })
                    .animation({ duration: 900, curve: Curve.Linear })
                    .hitTestBehavior(HitTestMode.None)
                }, (i: number) => i.toString())
              }
            }
            .width('100%')
            .layoutWeight(1)
            .constraintSize({ maxHeight: 110 })

            // 供桌
            Column()
              .width(300)
              .constraintSize({ maxWidth: '76%' })
              .height(10)
              .borderRadius(4)
              .backgroundColor('#8A1A24')
              .border({ width: { top: 2 }, color: '#C9A24A' })
              .margin({ top: -2 })

            Text(this.incenseLit ? '心意正暖 · 财源广进'
              : (this.hallVM.heart >= 3 ? '上一炷香 · 财源广进' : '心意值不足'))
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.80)')
              .height(16)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .height('38%')
          .constraintSize({ maxHeight: 140 })
          .justifyContent(FlexAlign.End)
          .onClick(() => this.onCenser())
        }
        .width('100%')
        .layoutWeight(1)

        // 合规说明（仅视觉效果，不承诺任何祈福效力）
        Text('✦ 定制陈设 · 布置自己的财神殿 · 仅视觉效果 ✦')
          .fontSize(10)
          .fontColor('rgba(253, 246, 227, 0.72)')
          .width('100%')
          .height(16)
          .textAlign(TextAlign.Center)
          .margin({ top: 6, bottom: 4 })

        // 四件陈设：等宽等高，唯一购买/陈列入口
        Row() {
          ForEach(WARES, (def: WareDef) => {
            this.WareCell(def)
          }, (def: WareDef) => def.key)
        }
        .width('100%')
        .height(124)
        .padding({ left: 14, right: 14 })

        // 心意值条
        Row() {
          Column() {
            Text(this.hallVM.heart.toString())
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD100')
            Text('心意值')
              .fontSize(10)
              .fontColor('rgba(253, 246, 227, 0.68)')
              .margin({ top: 1 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)

          Column() {
            Text(`${this.hallVM.sticksToday} 支`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD100')
            Text('今日上香')
              .fontSize(10)
              .fontColor('rgba(253, 246, 227, 0.68)')
              .margin({ top: 1 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)

          Column() {
            Text(`${this.hallVM.lampStreak} 天`)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFD100')
            Text('连续点亮')
              .fontSize(10)
              .fontColor('rgba(253, 246, 227, 0.68)')
              .margin({ top: 1 })
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .height(44)
        .padding({ left: 16, right: 16 })
        .linearGradient({
          angle: 180,
          colors: [['rgba(20, 4, 6, 0)', 0.0], ['rgba(20, 4, 6, 0.28)', 1.0]]
        })
      }
      .width('100%')
      .height('100%')
      // 顶部 44vp 安全距：匾额下移到状态栏/中置挖孔之下，背景层仍铺满全屏
      .padding({ top: 44 })

      // 飘字
      Text(this.flyText)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD100')
        .shadow({ radius: 6, color: 'rgba(0, 0, 0, 0.6)', offsetY: 1 })
        .position({ x: '50%', y: '52%' })
        .translate({ x: '-50%' })
        .opacity(this.flyVisible ? 1 : 0)
        .scale({ x: this.flyVisible ? 1 : 0.9, y: this.flyVisible ? 1 : 0.9 })
        .animation({ duration: 260, curve: Curve.EaseOut })
        .hitTestBehavior(HitTestMode.None)

      // 轻提示（心意值不足 / 已陈设 / 香火已点等）
      Text(this.toastText)
        .fontSize(13)
        .fontColor('#FFD700')
        .backgroundColor('rgba(0, 0, 0, 0.84)')
        .borderRadius(20)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .constraintSize({ maxWidth: '82%' })
        .position({ x: '50%', y: '82%' })
        .translate({ x: '-50%' })
        .opacity(this.toastVisible ? 1 : 0)
        .animation({ duration: 220 })
        .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#100a0c')
  }
}

// 写心愿弹窗（复用 CloudService.createWish）
@CustomDialog
struct WishDialog {
  controller: CustomDialogController
  deityId: number = 1
  onSubmit: (content: string) => void = () => {}
  /** 弹窗被关闭（按钮 / 点外 / 系统回收）时通知页面释放控制器引用，允许下次再开 */
  onClosed: () => void = () => {}
  /** 关闭兜底：注入的 controller 可能为 undefined，由创建方用自己持有的引用关闭（同 DonateDialog） */
  onClose: () => void = () => {}
  @State text: string = ''

  /**
   * 关闭弹窗。⚠️ 闪退修复（2026-10-20）：Pura X 实测注入的 this.controller 可能为 undefined
   * —— 未判空直接 .close() 会 "Cannot read property close of undefined" 闪退；只判空又「点了没反应」。
   * 因此：① 优先用注入的 controller；② 注入缺失/close 抛错时走 onClose 由创建方关闭（必然有效）。
   */
  private closeDialog(): void {
    const c = this.controller
    if (c !== undefined && c !== null) {
      try {
        c.close()
        return
      } catch (err) {
        const msg = (err instanceof Error) ? err.message : JSON.stringify(err)
        console.error('[WishDialog] controller.close failed: ' + msg)
      }
    }
    this.onClose()
  }

  aboutToDisappear(): void {
    this.onClosed()
  }

  build() {
    Column() {
      Text('写下今日心愿')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .margin({ bottom: 10 })
      TextInput({ placeholder: '财神见证，记一笔心愿', text: this.text })
        .onChange((v: string) => {
          this.text = v
        })
        .width('100%')
        .height(44)
        .backgroundColor('rgba(255, 255, 255, 0.08)')
        .fontColor('#fdf6e3')
      Row() {
        Button('取消')
          .fontSize(13)
          .backgroundColor(Color.Transparent)
          .fontColor('#FFD700')
          .border({ width: 1, color: 'rgba(255, 209, 0, 0.4)' })
          .onClick(() => {
            this.closeDialog()
          })
        Button('记下')
          .fontSize(13)
          .backgroundColor('#FFD700')
          .fontColor('#1a1a0a')
          .onClick(() => {
            this.onSubmit(this.text)
            this.closeDialog()
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 14 })
    }
    .width('84%')
    .padding(18)
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .clip(true)
  }
}
