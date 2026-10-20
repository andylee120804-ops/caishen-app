// entry/src/main/ets/formability/WidgetData.ets
// 卡片数据快照：FormExtensionAbility 与 App 侧 FormSyncService 共用，避免落盘/取值逻辑两份。
// 每次调用都 new ViewModel + initialize 重新读盘（扩展每次回调可能是新实例，不能依赖内存态）。
//
// 卡片图片：不放 fd，改为卡片 UI 直接引用 media 资源 $r('app.media.muyu')。
// 原因：扩展跑在独立进程（caishen.blessing.huawei:form），formImages + memory:// 的 fd 传递在
// 真机上不可靠；而 media 资源随卡片包一起加载，稳定且不用每次 updateForm 重传。
import { formBindingData, formProvider } from '@kit.FormKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { QiuQianViewModel, FREE_DAILY_QIU } from '../viewmodels/QiuQianViewModel'
import { MuyuViewModel } from '../viewmodels/MuyuViewModel'
import { KowtowViewModel, KowtowDaily } from '../viewmodels/KowtowViewModel'
import { DeityRotator } from '../engine/DeityRotator'
import { SignEntry, LEVEL_COLOR, dailySignOfToday } from '../model/CultureContent'
import { FIVE_DEITIES, DeityInfo } from '../model/PrayerTypes'

const LOG_DOMAIN: number = 0xF811
const LOG_TAG: string = 'WidgetData'

/** 财神卡短寓意：2×2 卡片单行完整放下（完整文案在 App 内主神牌/五神阵展示） */
const SHORT_MEANING: Record<number, string> = {
  1: '商祖开路·牛转乾坤',
  2: '公道无私·正财稳进',
  3: '重义守信·镇宅辟邪',
  4: '帝王之气·破局开路',
  5: '黑虎镇守·驱邪纳福'
}

export class WidgetData {
  /** 按 formName 生成卡片绑定数据（只放免费字段，绝不塞 interpretation/advice） */
  static async build(context: Context, formName: string, mainProcess: boolean = false): Promise<formBindingData.FormBindingData | null> {
    if (formName === 'kowtow_2x2') {
      // 统一磕头计数（App 祈福 + 卡片直磕），由 KowtowViewModel 负责播种/跨日/进程纪律
      const daily: KowtowDaily = await KowtowViewModel.load(context, mainProcess)
      const deity = DeityRotator.getTodayDeity()
      hilog.info(LOG_DOMAIN, LOG_TAG,
        `kowtow today=${daily.today} total=${daily.total} deity=${deity.name}`)
      return formBindingData.createFormBindingData({
        'deityId': deity.id,
        'deityName': deity.name,
        'todayKowtow': daily.today,
        'totalKowtow': daily.total
      })
    }

    if (formName === 'muyu_2x2') {
      const muyuVM = new MuyuViewModel()
      await muyuVM.initialize(context)
      hilog.info(LOG_DOMAIN, LOG_TAG, `muyu today=${muyuVM.todayCount} total=${muyuVM.totalCount}`)
      return formBindingData.createFormBindingData({
        'todayCount': muyuVM.todayCount,
        'totalCount': muyuVM.totalCount
      })
    }

    if (formName === 'deity_2x2') {
      return WidgetData.deityBinding(DeityRotator.getTodayDeity())
    }
    if (formName === 'deity_east_2x2') {
      return WidgetData.deityBinding(WidgetData.deityById(2))
    }
    if (formName === 'deity_west_2x2') {
      return WidgetData.deityBinding(WidgetData.deityById(3))
    }
    if (formName === 'deity_south_2x2') {
      return WidgetData.deityBinding(WidgetData.deityById(4))
    }
    if (formName === 'deity_north_2x2') {
      return WidgetData.deityBinding(WidgetData.deityById(5))
    }

    if (formName !== 'sign_2x2' && formName !== 'sign_2x4') {
      // 未知 / 缺失 formName：宁可不刷新（卡片保留上一次正确快照），
      // 也不能把木鱼卡 / 主财神卡错渲染成求签卡
      hilog.error(LOG_DOMAIN, LOG_TAG, 'unknown formName: ' + formName)
      return null
    }
    const qiuVM = new QiuQianViewModel()
    await qiuVM.initialize(context)
    const used: number = qiuVM.usedToday()
    const best: SignEntry | null = qiuVM.bestToday()
    // 今日已抽 → 展示最吉签；未抽 → 确定性每日签
    const sign: SignEntry = best === null ? dailySignOfToday() : best
    // 已抽时取该最吉签是今天第几次抽到的（1-N），用于卡片标题「今天第 X 签」
    const drawOrder: number = best === null ? 0 : qiuVM.bestDrawOrder()
    const quota: number = qiuVM.quotaToday()
    hilog.info(LOG_DOMAIN, LOG_TAG,
      `sign snapshot used=${used} quota=${quota} hasDrawn=${best !== null} form=${formName}`)
    return formBindingData.createFormBindingData({
      'signId': sign.id,
      'level': sign.level,
      'levelColor': LEVEL_COLOR[sign.level],
      'title': sign.title,
      'poem': sign.poem,
      'used': used,
      'max': FREE_DAILY_QIU,
      // 今日额度：每天固定 FREE_DAILY_QIU（3）签，卡片据此启用/禁用「再抽一签」
      'quota': quota,
      // 今日最吉签是第几次抽到的（与签池 id 无关，仅表示当日第几签）
      'drawOrder': drawOrder,
      'hasDrawn': best !== null
    })
  }

  /** 取指定 id 的财神（未命中回退首位） */
  private static deityById(id: number): DeityInfo {
    return FIVE_DEITIES.find((d: DeityInfo): boolean => d.id === id) ?? FIVE_DEITIES[0]
  }

  /** 财神卡统一绑定数据：图片由卡片按 id 取 $r('app.media.deity_N')，这里只下发 id */
  private static deityBinding(deity: DeityInfo): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData({
      'deityId': deity.id,
      'deityName': deity.name,
      'deityDirection': deity.direction,
      'deityMeaning': SHORT_MEANING[deity.id] ?? deity.deityMeaning
    })
  }

  /** 刷新单张卡片（formName 无法识别时跳过，不破坏卡片现有内容） */
  static async refresh(context: Context, formId: string, formName: string, mainProcess: boolean = false): Promise<void> {
    if (formId === '') {
      return
    }
    try {
      const binding: formBindingData.FormBindingData | null = await WidgetData.build(context, formName, mainProcess)
      if (binding === null) {
        return
      }
      await formProvider.updateForm(formId, binding)
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'refresh failed: ' + JSON.stringify(err))
    }
  }
}
