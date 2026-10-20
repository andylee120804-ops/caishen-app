// entry/src/main/ets/formability/WidgetFormAbility.ets
// 桌面卡片数据源：sign_2x2 / sign_2x4 / muyu_2x2 / 每日主财神 deity_2x2，
// 以及四路固定财神 deity_east_2x2(比干) / deity_west_2x2(关羽) / deity_south_2x2(柴荣) / deity_north_2x2(赵公明)。
//
// 进程模型约束（决定下面的写法）：
// 1) 卡片 UI 跑在系统「卡片渲染服务」，看不到 App 内存/AppStorage，一切数据只能经
//    FormBindingData 注入；
// 2) 本扩展跑在独立进程 caishen.blessing.huawei:form（bm dump 实测，不是主进程），且每次回调
//    都可能是新实例 → 不能把 ViewModel 缓存在成员变量里，每次都 new + initialize() 重读盘，
//    且要清 preferences 进程缓存，否则会互相读到旧值；
// 3) 敲木鱼天然连点 → 两个 onFormEvent 并发会造成 read-modify-write 丢计数，必须串行
//    （静态任务队列跨实例存活）；
// 4) 队列中的单个任务若 I/O 悬挂会把后续所有点击堵死 → 每任务加超时保护；
// 5) console.* 在该进程打不进 hilog，必须用 hilog API 才能抓到日志。
import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit'
import { Want } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { QiuQianViewModel } from '../viewmodels/QiuQianViewModel'
import { MuyuViewModel } from '../viewmodels/MuyuViewModel'
import { KowtowViewModel } from '../viewmodels/KowtowViewModel'
import { SIGN_TABLE } from '../model/CultureContent'
import { DeityRotator } from '../engine/DeityRotator'
import { FIVE_DEITIES, DeityInfo } from '../model/PrayerTypes'
import { FormIdStore } from './FormIdStore'
import { WidgetData } from './WidgetData'

/** 卡片 message 事件支持的动作 */
const ACTION_DRAW: string = 'draw'
const ACTION_KNOCK: string = 'knock'
const ACTION_KOWTOW: string = 'kowtow'
/** 单任务超时（ms）：超时即放行下一个任务，避免一次 I/O 悬挂让卡片永久无响应 */
const TASK_TIMEOUT_MS: number = 8000
const LOG_DOMAIN: number = 0xF811
const LOG_TAG: string = 'WidgetForm'

/** message 解析结果 */
interface CardMessage {
  action: string
  form: string
}

export default class WidgetFormAbility extends FormExtensionAbility {
  /** 静态任务队列：扩展每次回调可能是新实例，实例级队列起不到串行作用 */
  private static queue: Promise<void> = Promise.resolve()

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId: string = WidgetFormAbility.paramOf(want, formInfo.FormParam.IDENTITY_KEY)
    const formName: string = WidgetFormAbility.paramOf(want, formInfo.FormParam.NAME_KEY)
    hilog.info(LOG_DOMAIN, LOG_TAG, `onAddForm formId=${formId} formName=${formName}`)
    // onAddForm 必须同步返回：先给占位快照，随后在同一个串行队列里登记 formId 并拉真实数据
    WidgetFormAbility.enqueue(async (): Promise<void> => {
      await FormIdStore.add(this.context, formId, formName)
      await WidgetData.refresh(this.context, formId, formName)
    })
    const ph: DeityInfo = WidgetFormAbility.placeholderDeity(formName)
    return formBindingData.createFormBindingData({
      'signId': 0,
      'level': '',
      'levelColor': '#9a9a9a',
      'title': '财神保佑',
      'poem': '',
      'used': 0,
      'max': 3,
      'hasDrawn': false,
      'todayCount': 0,
      'totalCount': 0,
      'deityId': ph.id,
      'deityName': ph.name,
      'deityDirection': ph.direction,
      'deityMeaning': ph.deityMeaning,
      'todayKowtow': 0,
      'totalKowtow': 0
    })
  }

  onUpdateForm(formId: string): void {
    WidgetFormAbility.enqueue(async (): Promise<void> => {
      const map: Record<string, string> = await FormIdStore.all(this.context)
      const formName: string = map[formId] === undefined ? '' : map[formId]
      hilog.info(LOG_DOMAIN, LOG_TAG, `onUpdateForm formId=${formId} formName=${formName}`)
      await WidgetData.refresh(this.context, formId, formName)
    })
  }

  onFormEvent(formId: string, message: string): void {
    const msg: CardMessage = WidgetFormAbility.parseMessage(message)
    hilog.info(LOG_DOMAIN, LOG_TAG, `onFormEvent formId=${formId} action=${msg.action} form=${msg.form}`)
    WidgetFormAbility.enqueue(async (): Promise<void> => {
      // 优先用卡片自带的 form（不依赖登记表），登记表仅作兜底：
      // 一旦 FormIdStore 读不到（跨进程缓存 / 数据丢失），点击也不会变成"没反应"
      let formName: string = msg.form
      if (formName === '') {
        const map: Record<string, string> = await FormIdStore.all(this.context)
        formName = map[formId] === undefined ? '' : map[formId]
      }

      if (msg.action === ACTION_DRAW && (formName === 'sign_2x2' || formName === 'sign_2x4')) {
        // 真抽签：与 App 同一份 preferences（mashen_qiuqian_prefs）。
        // 抽不动说明卡片那边的 used/quota 快照已经滞后，这里刷新后卡片会自行切成付款入口。
        const qiuVM = new QiuQianViewModel()
        await qiuVM.initialize(this.context)
        const usedNow: number = qiuVM.usedToday()
        const quotaNow: number = qiuVM.quotaToday()
        if (qiuVM.canDraw()) {
          const sign = SIGN_TABLE[Math.floor(Math.random() * SIGN_TABLE.length)]
          await qiuVM.consumeDraw()
          await qiuVM.addRecord(sign)
          hilog.info(LOG_DOMAIN, LOG_TAG, `draw signId=${sign.id} used=${usedNow}->${usedNow + 1} quota=${quotaNow}`)
        } else {
          hilog.info(LOG_DOMAIN, LOG_TAG, `draw rejected: quota used up used=${usedNow} quota=${quotaNow}`)
        }
      } else if (msg.action === ACTION_KNOCK && formName === 'muyu_2x2') {
        const muyuVM = new MuyuViewModel()
        await muyuVM.initialize(this.context)
        await muyuVM.knockAsync()
        hilog.info(LOG_DOMAIN, LOG_TAG, `knock today=${muyuVM.todayCount} total=${muyuVM.totalCount}`)
      } else if (msg.action === ACTION_KOWTOW && formName === 'kowtow_2x2') {
        // 磕头卡直磕：统一计数 +1（App 祈福也并入同一份，见 KowtowViewModel）
        await KowtowViewModel.bump(this.context, 1, false)
      }

      await WidgetData.refresh(this.context, formId, formName)
    })
  }

  onRemoveForm(formId: string): void {
    FormIdStore.remove(this.context, formId).catch((err: Object) => {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'FormIdStore.remove failed: ' + JSON.stringify(err))
    })
  }

  /** 串行执行：上一次任务完成（成功/失败/超时）后才跑下一个，杜绝并发读改写 */
  private static enqueue(task: () => Promise<void>): void {
    WidgetFormAbility.queue = WidgetFormAbility.queue.then((): Promise<void> => {
      return WidgetFormAbility.withTimeout(task)
    }).catch((err: Object): void => {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'task failed: ' + JSON.stringify(err))
    })
  }

  /** 超时保护：单个任务悬挂不能堵死整条队列（否则卡片点击永久无响应） */
  private static withTimeout(task: () => Promise<void>): Promise<void> {
    let timer: number = -1
    const timeout: Promise<void> = new Promise<void>((resolve: () => void): void => {
      timer = setTimeout((): void => {
        hilog.error(LOG_DOMAIN, LOG_TAG, 'task timeout, skip to next')
        resolve()
      }, TASK_TIMEOUT_MS)
    })
    return Promise.race([task(), timeout]).then((): void => {
      clearTimeout(timer)
    })
  }

  private static paramOf(want: Want, key: string): string {
    const params = want.parameters
    if (params === undefined || params === null) {
      return ''
    }
    const value: Object = params[key]
    if (value === undefined || value === null) {
      return ''
    }
    return String(value)
  }

  /** onAddForm 同步占位快照用的财神：固定卡直接给对应财神，每日卡/兜底给当天主神 */
  private static placeholderDeity(formName: string): DeityInfo {
    let id: number = DeityRotator.getTodayDeity().id
    if (formName === 'deity_east_2x2') {
      id = 2
    } else if (formName === 'deity_west_2x2') {
      id = 3
    } else if (formName === 'deity_south_2x2') {
      id = 4
    } else if (formName === 'deity_north_2x2') {
      id = 5
    }
    return FIVE_DEITIES.find((d: DeityInfo): boolean => d.id === id) ?? FIVE_DEITIES[0]
  }

  /** 把任意值安全转成 Record（非对象一律当空表） */
  private static asRecord(value: Object): Record<string, Object> {
    if (typeof value === 'object' && value !== null) {
      return value as Record<string, Object>
    }
    return {}
  }

  /** message 解析：params 内层优先，键名 msgAction / form */
  private static parseMessage(message: string): CardMessage {
    const empty: CardMessage = { action: '', form: '' }
    try {
      let parsed: Object = JSON.parse(message) as Object
      // 兜底：若卡片把 params 传成了 JSON 字符串，系统会再包一层，
      // 这里 parse 出来是 string，需要再解析一次才能拿到 action
      if (typeof parsed === 'string') {
        parsed = JSON.parse(parsed as string) as Object
      }
      const root: Record<string, Object> = parsed as Record<string, Object>
      // 系统会把 postCardAction 的 action('message') 与 params 内容合并进同一层，
      // 实测 message 形如：{"action":"draw",...,"params":{...},"action":"message"}
      // —— 同名键后者覆盖前者，自定义动作绝不能叫 action，统一用 msgAction，并优先取 params 内层。
      const inner: Record<string, Object> = WidgetFormAbility.asRecord(root['params'])
      const action: Object = inner['msgAction'] === undefined ? root['msgAction'] : inner['msgAction']
      const form: Object = inner['form'] === undefined ? root['form'] : inner['form']
      empty.action = typeof action === 'string' ? action as string : ''
      empty.form = typeof form === 'string' ? form as string : ''
      return empty
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'bad message: ' + message)
      return empty
    }
  }
}
