// App 侧主动推卡片：抽签/敲木鱼成功后、以及回前台 reload 完成后调用。
// 系统没有「刷新本应用全部卡片」的接口，只能遍历 FormIdStore 登记的 formId 逐个刷新。
//
// 「付了款卡片还让再付一次」这条链路的日志统一在这里打，排查顺序：
//   ① 有没有 [FormSync] push start forms=N （N=0 说明登记表空，卡片永远收不到新额度）
//   ② 有没有 [FormSync] pushed formId=... （没有就是 updateForm 抛错）
import { FormIdStore } from '../formability/FormIdStore'
import { WidgetData } from '../formability/WidgetData'
import { hilog } from '@kit.PerformanceAnalysisKit'

const LOG_DOMAIN: number = 0xF811
const LOG_TAG: string = 'FormSync'

export class FormSyncService {
  /** 把所有已添加卡片刷新到最新状态（没有卡片时安全空转） */
  static async pushAll(context: Context): Promise<void> {
    try {
      const map: Record<string, string> = await FormIdStore.all(context)
      const ids: string[] = Object.keys(map)
      hilog.info(LOG_DOMAIN, LOG_TAG, `push start forms=${ids.length} map=${JSON.stringify(map)}`)
      if (ids.length === 0) {
        // 登记表为空：卡片被添加后 onAddForm 才登记；进程被杀后重装的卡片
        // 只有下一次 onUpdateForm/onAddForm 才会重新登记，期间推送必然无效
        hilog.warn(LOG_DOMAIN, LOG_TAG, 'no form registered, nothing to push')
        return
      }
      for (const formId of ids) {
        await WidgetData.refresh(context, formId, map[formId], true)
        hilog.info(LOG_DOMAIN, LOG_TAG, `pushed formId=${formId} formName=${map[formId]}`)
      }
    } catch (err) {
      hilog.error(LOG_DOMAIN, LOG_TAG, 'pushAll failed: ' + JSON.stringify(err))
    }
  }
}
