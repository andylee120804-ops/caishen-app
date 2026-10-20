import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AudioManager } from '../service/AudioManager'
import { PrayerViewModel } from '../viewmodels/PrayerViewModel'
import { EnrichViewModel } from '../viewmodels/EnrichViewModel'
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { EntryConfigVM } from '../viewmodels/EntryConfigVM'
import { FortuneViewModel } from '../viewmodels/FortuneViewModel'
import { MuyuViewModel } from '../viewmodels/MuyuViewModel'
import { QiuQianViewModel } from '../viewmodels/QiuQianViewModel'
import { HallViewModel } from '../viewmodels/HallViewModel'
import { IapPaymentService } from '../service/IapPaymentService'
import { ExtraDrawResult } from '../service/IPaymentService'
import { CloudService } from '../service/CloudService'
import { FormSyncService } from '../service/FormSyncService'

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 深链路由（桌面卡片 router 事件）：冷启动走这里，热启动走 onNewWant。
    // 先建键，保证 MainTabs 的 @StorageLink 有默认值可读。
    AppStorage.setOrCreate('pendingRoute', '')
    AppStorage.setOrCreate('pendingOpenUnlock', false)
    // 卡片侧改动 → App 回前台 reload 后 bump，驱动页面重建（@Observed 嵌套变更不通知 UI）
    AppStorage.setOrCreate('qiuRev', 0)
    AppStorage.setOrCreate('muyuRev', 0)
    this.applyDeepLink(want)

    // 预加载音效到 SoundPool
    AudioManager.getInstance().init(this.context).catch((err: Object) => {
      console.error('AudioManager init failed:', JSON.stringify(err))
    })

    // 全局共享的祈福视图模型；各页面通过 @StorageLink('viewModel') 读取，
    // 避免跨路由页面使用 @Provide/@Consume 导致取不到值。
    const viewModel = new PrayerViewModel()
    AppStorage.setOrCreate('viewModel', viewModel)
    viewModel.initialize(this.context).catch((err: Object) => {
      console.error('PrayerViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的增值内容视图模型（黄历/磕头/财神追踪）
    const enrichVM = new EnrichViewModel()
    AppStorage.setOrCreate('enrichViewModel', enrichVM)
    enrichVM.initialize(this.context).catch((err: Object) => {
      console.error('EnrichViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的入口配置（界面定制：Tab 开关与排序）
    const entryConfigVM = new EntryConfigVM()
    AppStorage.setOrCreate('entryConfigVM', entryConfigVM)
    entryConfigVM.initialize(this.context).catch((err: Object) => {
      console.error('EntryConfigVM init failed:', JSON.stringify(err))
    })

    // 全局共享的运势视图模型（星座/属相偏好、神诞收藏）
    const fortuneVM = new FortuneViewModel()
    AppStorage.setOrCreate('fortuneVM', fortuneVM)
    fortuneVM.initialize(this.context).catch((err: Object) => {
      console.error('FortuneViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的电子木鱼计数
    const muyuVM = new MuyuViewModel()
    AppStorage.setOrCreate('muyuVM', muyuVM)
    muyuVM.initialize(this.context).catch((err: Object) => {
      console.error('MuyuViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的求签记录/每日额度（自动记签 + 每日免费 3 签）
    const qiuVM = new QiuQianViewModel()
    AppStorage.setOrCreate('qiuVM', qiuVM)
    // 登记初始化 promise：页面收到卡片深链时先 awaitInit()，避免用未就绪的空额度做付款判断
    const qiuInit: Promise<void> = qiuVM.initialize(this.context)
    QiuQianViewModel.markInit(qiuInit)
    qiuInit.catch((err: Object) => {
      console.error('QiuQianViewModel init failed:', JSON.stringify(err))
    })

    // 全局共享的财神殿视图模型（点灯/上香/装扮，独立 prefs 文件 caishen_hall_prefs）
    const hallVM = new HallViewModel()
    AppStorage.setOrCreate('hallVM', hallVM)
    AppStorage.setOrCreate('hallRev', 0)
    hallVM.initialize(this.context).catch((err: Object) => {
      console.error('HallViewModel init failed:', JSON.stringify(err))
    })

    // 生成或读取设备用户 ID（供 CloudService 匿名标识使用）
    preferences.getPreferences(this.context, 'mashen_user_prefs').then((prefs: preferences.Preferences) => {
      prefs.get('deviceUserId', '').then((val: preferences.ValueType) => {
        let uid: string = val as string
        if (!uid) {
          uid = 'u_' + util.generateRandomUUID(true)
          prefs.put('deviceUserId', uid)
          prefs.flush()
        }
        AppStorage.setOrCreate('deviceUserId', uid)
        // 设备 ID 就绪后启动收支记录云同步（P1：同设备云备份，防本地数据丢失）。
        // enrichVM 在 onCreate 前文已初始化；startCloudSync 幂等，离线时安全跳过。
        enrichVM.startCloudSync().catch((err: Object) => {
          console.error('EnrichViewModel startCloudSync failed:', JSON.stringify(err))
        })

        // 注：qiu_extra（付费加求签次数）补单已随「每日固定 3 签」一并取消，
        // 不再发放额外额度（见 QiuQianViewModel 额度模型注释）。

        // 打赏补单：打赏是纯赠与、没有本地权益，补单只需「云端记账 + 消耗」——
        // 消耗前必须先记账（消耗后订单从 queryPurchases(UNFINISHED) 消失，再无重放机会），
        // 这样即便上次记账失败，这笔打赏也会进公益排行榜。静默执行，失败留下次启动重试。
        const tipService = new IapPaymentService(this.context)
        tipService.recoverTipPending().then(async (owned: ExtraDrawResult | null) => {
          if (owned === null) {
            return
          }
          const recorded: boolean = await CloudService.recordDonation({
            productId: owned.productId,
            purchaseToken: owned.purchaseToken,
            purchaseData: owned.purchaseData,
            orderId: owned.orderId
          })
          if (!recorded) {
            console.error('EntryAbility record donation failed, keep order unfinished')
            return  // 记账没成功 → 保留未完成状态，下次启动还能重试
          }
          tipService.consume(owned).catch((err: Object) => {
            console.error('EntryAbility consume tip pending failed:', JSON.stringify(err))
          })
        }).catch((err: Object) => {
          console.error('IapPaymentService recoverTipPending failed:', JSON.stringify(err))
        })
      })
    })
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // App 前后台状态标记：求签页据此注册/注销加速度计。
    // 审核标准「应用退后台禁止使用传感器」：退后台必须释放传感器占用。
    AppStorage.setOrCreate('appInForeground', true)

    // 沉浸式：内容延伸到状态栏与导航栏区域，系统栏透明，
    // 消除屏幕上下白边，使深色背景铺满全屏。
    const mainWindow = windowStage.getMainWindowSync()
    mainWindow.setWindowLayoutFullScreen(true).then(() => {
      return mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        statusBarContentColor: '#FFD700',
        navigationBarColor: '#00000000',
        navigationBarContentColor: '#FFD700'
      })
    }).catch((err: Object) => {
      console.error('Immersive window setup failed:', JSON.stringify(err))
    })

    // 改为加载 MainTabs（四 Tab 主框架）
    windowStage.loadContent('pages/MainTabs', (err) => {
      if (err.code) {
        console.error('Failed to load content:', JSON.stringify(err))
      }
    })
  }

  /** 热启动深链（桌面卡片 router 事件）：App 已在后台时 onCreate 不会再走 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.applyDeepLink(want)
  }

  /** 冷启动首次 onForeground 无需同步（onCreate 刚读完盘） */
  private static syncCold: boolean = true
  /** 频繁前后台切换节流：2s 内不重复重读盘 + 推卡片 */
  private static lastSyncMs: number = 0

  onForeground(): void {
    // App 回到前台：求签页据此恢复加速度计订阅（仅前台 + 求签 tab 激活时占用传感器）
    AppStorage.setOrCreate('appInForeground', true)
    if (EntryAbility.syncCold) {
      EntryAbility.syncCold = false
      return
    }
    const now: number = Date.now()
    if (now - EntryAbility.lastSyncMs < 2000) {
      return
    }
    EntryAbility.lastSyncMs = now
    // 卡片可能在 App 后台抽签/敲木鱼：回前台必须重读盘再刷 UI 与卡片，否则显示旧值
    this.reloadAndPushCards()
  }

  /** 解析卡片深链参数 → AppStorage。route: qiuqian / muyu / blessing；open: 'unlock' 打开解签 */
  private applyDeepLink(want: Want): void {
    const params = want.parameters
    if (params === undefined || params === null) {
      return
    }
    const route: Object = params['route']
    if (typeof route === 'string' && (route as string) !== '') {
      AppStorage.setOrCreate('pendingRoute', route as string)
    }
    const open: Object = params['open']
    // open:'buy'（求签打赏加购）已随付费下架：深链不再解析（卡片也不再发）
    AppStorage.setOrCreate('pendingOpenUnlock', open === 'unlock')
  }

  /** 重读 VM（卡片侧改过盘）→ 通知页面刷新 → 把最新状态推给所有卡片 */
  private async reloadAndPushCards(): Promise<void> {
    const qiuVM: QiuQianViewModel | undefined = AppStorage.get('qiuVM') as QiuQianViewModel | undefined
    const muyuVM: MuyuViewModel | undefined = AppStorage.get('muyuVM') as MuyuViewModel | undefined
    try {
      // 传 context：先清 preferences 进程缓存，才能读到独立卡片进程写下的最新值
      if (qiuVM !== undefined) {
        await qiuVM.reload(this.context)
      }
      if (muyuVM !== undefined) {
        await muyuVM.reload(this.context)
      }
    } catch (err) {
      console.error('EntryAbility reload failed:', JSON.stringify(err))
    }
    // @Observed VM 的嵌套字段变更不通知 UI：bump 版本号驱动页面重建
    AppStorage.setOrCreate('qiuRev', ((AppStorage.get('qiuRev') as number | undefined) ?? 0) + 1)
    AppStorage.setOrCreate('muyuRev', ((AppStorage.get('muyuRev') as number | undefined) ?? 0) + 1)
    // reload 完成后再推，避免把旧值推给卡片
    FormSyncService.pushAll(this.context).catch((err: Object) => {
      console.error('EntryAbility push cards failed:', JSON.stringify(err))
    })
  }

  onBackground(): void {
    // App 进入后台时停止 BGM
    AudioManager.getInstance().stopBgm()
    // 退后台禁止占用传感器：通知求签页立即注销加速度计订阅
    AppStorage.setOrCreate('appInForeground', false)
  }

  onDestroy(): void {
    // 释放所有音频资源
    AudioManager.getInstance().release()
  }
}
