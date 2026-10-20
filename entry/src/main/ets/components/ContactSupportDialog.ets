// entry/src/main/ets/components/ContactSupportDialog.ets
// 联系客服弹窗（审核问题1整改：应用内含付费项目，需在应用内提供客服联系方式）。
// 邮箱以「信息卡」呈现（地址可长按复制，卡内右侧「复制」胶囊 = pasteboard 本机复制），
// 单一主行动「发送邮件」（startAbilityByType("mail") 拉起系统邮件应用，预填收件人/主题/正文）。
// 风格沿用 PrivacyDialog（深底 #1a1a0a + 金色描边 + 金色标题 + 米色正文），
// 文字对比度与 PrivacyDialog 同底同色，已过既有审核（见 wcag-contrast 规则）。
import { common } from '@kit.AbilityKit'
import { pasteboard, BusinessError } from '@kit.BasicServicesKit'

/** 客服邮箱：审核公开联系渠道，必须为真实可收件地址 */
export const SUPPORT_EMAIL: string = 'andyli0912@petalmail.com'

@CustomDialog
export struct ContactSupportDialog {
  controller: CustomDialogController
  /** 关闭兜底：注入的 controller 可能为 undefined，由创建方用自己持有的引用关闭 */
  onClose: () => void = () => {}

  /**
   * 关闭弹窗。⚠️ 闪退修复（2026-10-20）：Pura X 实测注入的 this.controller 可能为 undefined
   * —— 未判空直接 close 会闪退；只判空又「点了没反应」。① 优先注入的 controller；② 否则走 onClose。
   */
  private closeDialog(): void {
    const c = this.controller
    if (c !== undefined && c !== null) {
      try {
        c.close()
        return
      } catch (err) {
        const msg = (err instanceof Error) ? err.message : JSON.stringify(err)
        console.error('[ContactSupport] controller.close failed: ' + msg)
      }
    }
    this.onClose()
  }

  /** 复制客服邮箱到剪贴板（setDataSync 同步写，失败立即 catch，成功后才 toast） */
  private copyEmail(): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, SUPPORT_EMAIL)
      pasteboard.getSystemPasteboard().setDataSync(data)
      this.getUIContext().getPromptAction().showToast({ message: '客服邮箱已复制 📋' })
    } catch (err) {
      console.error('[ContactSupport] copy email failed:', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '复制失败，请重试' })
    }
  }

  /** 拉起系统邮件应用，预填收件人/主题/正文 */
  private sendEmail(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const wantParam: Record<string, Object> = {
        'sceneType': 1,                                    // 1 = 发送邮件意图（文档默认值）
        'email': [encodeURI(SUPPORT_EMAIL)],               // 收件人（数组元素需 URL 编码）
        'subject': encodeURI('财神保佑 · 用户反馈'),
        'body': encodeURI('您好，\n\n我想反馈一个问题：\n\n（请在此描述您遇到的问题，谢谢）\n\n——财神保佑用户')
      }
      context.startAbilityByType('mail', wantParam, {
        onError: (code: number, name: string, message: string): void => {
          console.error('[ContactSupport] 拉起邮件应用失败 code=' + code + ' name=' + name + ' msg=' + message)
          this.getUIContext().getPromptAction().showToast({ message: '暂未检测到邮件应用，可点击「复制邮箱」后手动发送' })
        },
        onResult: (result: common.AbilityResult): void => {
          console.info('[ContactSupport] 邮件应用返回: ' + JSON.stringify(result))
        }
      }, (err: BusinessError): void => {
        // 起 mail 类型能力失败（如系统无邮件应用）：@since 11 回调式（兼容更广设备）
        if (err) {
          console.error('[ContactSupport] startAbilityByType callback err: ' + JSON.stringify(err))
          this.getUIContext().getPromptAction().showToast({ message: '暂未检测到邮件应用，可点击「复制邮箱」后手动发送' })
        }
      })
    } catch (err) {
      console.error('[ContactSupport] send email failed:', JSON.stringify(err))
      this.getUIContext().getPromptAction().showToast({ message: '暂未检测到邮件应用，可点击「复制邮箱」后手动发送' })
    }
  }

  // 排版：去掉 emoji，改为「大标题 + 邮箱卡 + 单主行动 + 描边关闭」四段式，
  // 层级更少、留白更规整，与深色金描边主题一致（对比度要求同 PrivacyDialog）。
  build() {
    Column() {
      // ── 顶部装饰条 ──
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#D23B2E')

      // ── 标题区 ──
      Text('客服中心')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .letterSpacing(4)
        .margin({ top: 20, bottom: 6 })

      Text('有问题尽管说，财神给您指条明路')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 16 })

      // ── 邮箱卡：地址 + 右侧行内「复制」胶囊，长按亦可复制 ──
      Row() {
        Column() {
          Text('客服邮箱')
            .fontSize(11)
            .fontColor('rgba(255, 209, 0, 0.8)')
            .width('100%')
          Text(SUPPORT_EMAIL)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#fdf6e3')
            .width('100%')
            .margin({ top: 4 })
            .copyOption(CopyOptions.LocalDevice)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text('复制')
            .fontSize(11)
            .fontColor('#FFD700')
        }
        .height(28)
        .padding({ left: 12, right: 12 })
        .borderRadius(14)
        .backgroundColor('rgba(255, 209, 0, 0.10)')
        .border({ width: 1, color: 'rgba(255, 209, 0, 0.35)' })
        .margin({ left: 10 })
        .onClick(() => {
          this.copyEmail()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 10, top: 10, bottom: 10 })
      .backgroundColor('rgba(255, 209, 0, 0.06)')
      .border({ width: 1, color: 'rgba(255, 209, 0, 0.18)', radius: 12 })
      .margin({ bottom: 14 })

      // ── 主行动 ──
      Button('发送邮件')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1a1a0a')
        .backgroundColor('#FFD700')
        .borderRadius(21)
        .height(42)
        .width('100%')
        .onClick(() => {
          this.sendEmail()
        })

      Text('工作日 48 小时内回复 · 感谢您的支持')
        .fontSize(11)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .textAlign(TextAlign.Center)
        .width('100%')
        .margin({ top: 12, bottom: 12 })

      Button('关闭')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFD700')
        .backgroundColor(Color.Transparent)
        .border({ width: 1, color: 'rgba(255, 209, 0, 0.4)' })
        .borderRadius(20)
        .height(34)
        .padding({ left: 28, right: 28 })
        .margin({ bottom: 12 })
        .onClick(() => {
          this.closeDialog()
        })
    }
    .width('80%')
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}
