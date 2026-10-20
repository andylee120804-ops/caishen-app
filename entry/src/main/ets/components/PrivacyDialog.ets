import { common } from '@kit.AbilityKit'
import { SUPPORT_EMAIL } from './ContactSupportDialog'

@CustomDialog
export struct PrivacyDialog {
  controller: CustomDialogController
  onAgree?: () => void
  /** 复阅模式：首次同意后从「我的」页再次打开，不提供退出应用按钮 */
  reviewOnly?: boolean = false
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
        console.error('[PrivacyDialog] controller.close failed: ' + msg)
      }
    }
    this.onClose()
  }

  private agreeAndClose(): void {
    this.closeDialog()
    if (this.onAgree) {
      this.onAgree()
    }
  }

  private exitApp(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      context.terminateSelf()
    } catch (err) {
      console.error('[PrivacyDialog] Failed to exit:', JSON.stringify(err))
    }
  }

  build() {
    Column() {
      // ── 顶部红色装饰条 ──
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#D23B2E')

      // ── 标题区 ──
      Text('📜  隐私政策')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFD700')
        .letterSpacing(2)
        .margin({ top: 22, bottom: 6 })

      Text(this.reviewOnly ? '请仔细阅读隐私政策' : '请仔细阅读并同意隐私政策')
        .fontSize(12)
        .fontColor('rgba(253, 246, 227, 0.75)')
        .fontStyle(FontStyle.Italic)
        .margin({ bottom: 16 })

      // ── 分隔线 ──
      Row()
        .width('60%')
        .height(1)
        .backgroundColor('rgba(255, 209, 0, 0.25)')
        .margin({ bottom: 16 })

      // ── 隐私政策正文（可滚动）──
      Scroll() {
        Column() {
          Text(this.getPrivacyContent())
            .fontSize(13)
            .fontColor('rgba(253, 246, 227, 0.8)')
            .lineHeight(22)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 4, right: 4 })
      }
      .width('100%')
      .height(260)
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .margin({ bottom: 16 })

      // ── 分隔线 ──
      Row()
        .width('60%')
        .height(1)
        .backgroundColor('rgba(255, 209, 0, 0.25)')
        .margin({ bottom: 20 })

      // ── 按钮组（复阅模式只保留关闭）──
      Row() {
        if (this.reviewOnly) {
          Button('我知道了')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#FFD700')
            .borderRadius(22)
            .height(42)
            .padding({ left: 28, right: 28 })
            .shadow({ radius: 10, color: 'rgba(255, 209, 0, 0.35)', offsetY: 2 })
            .onClick(() => this.closeDialog())
        } else {
          Button('不同意')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(253, 246, 227, 0.75)')
            .backgroundColor('rgba(255, 255, 255, 0.05)')
            .border({ width: 1, color: 'rgba(253, 246, 227, 0.2)', radius: 22 })
            .height(42)
            .padding({ left: 28, right: 28 })
            .onClick(() => this.exitApp())

          Button('同意并继续')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#FFD700')
            .borderRadius(22)
            .height(42)
            .padding({ left: 28, right: 28 })
            .shadow({ radius: 10, color: 'rgba(255, 209, 0, 0.35)', offsetY: 2 })
            .onClick(() => this.agreeAndClose())
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ bottom: 12 })
    }
    .width('82%')
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }

  private getPrivacyContent(): string {
    return `感谢您使用「财神保佑」应用（以下简称"本应用"）。我们深知个人信息对您的重要性，本隐私政策将帮助您了解我们如何收集、使用和保护您的信息。

一、我们收集的信息
• 祈福者姓名：您在祈福时输入的名称。上传云端时仅展示脱敏昵称（首字 + ***，如"张***"），不展示完整姓名。
• 设备匿名标识符：应用首次启动时随机生成的匿名 ID（不包含设备型号、序列号等可识别设备的信息），用于区分不同用户的祈福记录与心愿归属。
• 祈福行为数据：祈福次数、磕头次数、连续签到天数，用于生成祈福排行榜。
• 传感器运动数据：为识别「摇晃求签」动作，应用会短暂读取加速度传感器数据，但仅在本机即时处理、不存储不上传，不构成对您信息的收集（详见「三、权限说明」）。
• 心愿内容：您在心愿墙发布的文字内容，将公开展示给所有用户。
• 收支记录内容：您在收支记录功能中录入的每笔盈亏结果、幅度与备注，用于财运回顾；经您同意后自动上传至华为云服务器备份，仅本人可见，用于防止本地数据丢失。
• 打赏记录：您自愿打赏作者时，应用会将打赏档位、金额、脱敏昵称与订单标识符上传至华为云服务器，用于生成公益排行榜并公开展示；不包含您的真实姓名或华为账号信息。
• 本地记录：祈福历史、最近使用名称、签到记录、求签记录、日记便签、成就徽章等，仅存储在您的设备本地。

二、信息的使用方式
• 祈福统计、脱敏昵称与设备匿名标识符会上传至华为云服务器（AppGallery Connect 云服务），用于生成并展示祈福排行榜。
• 心愿内容会上传至华为云服务器，并在心愿墙向所有用户公开展示，用于实现许愿 / 还愿功能。
• 收支记录会上传至华为云服务器（AppGallery Connect 云服务）进行备份，仅本人通过设备匿名标识符可访问，用于防止本地记录意外丢失。
• 打赏记录会上传至华为云服务器（AppGallery Connect 云服务），用于生成公益排行榜并向所有用户公开展示打赏金额与脱敏昵称。
• 除上述云服务功能外，其余记录仅存储在您的设备本地，用于为您展示历史回顾与提升输入体验。
• 本应用不接入任何广告、统计或第三方数据分析 SDK，不会将您的信息用于广告营销或提供给其他第三方。

三、权限说明
• 网络权限：用于访问排行榜、心愿墙、收支记录云备份等云端功能。
• 振动权限：用于祈福叩拜时的触觉反馈，提升仪式感。
• 加速度传感器（摇动数据）：目的为检测摇晃手机的动作以完成求签；仅在您进入求签页且应用处于前台时实时读取；摇动数据在设备本地即时判断后即丢弃，不上传、不存储，退出求签页即停止读取。
• 音频权限：用于播放祈福背景音乐和音效。

四、信息保护
• 云端数据存储于华为云服务器，受华为云安全措施保护。
• 收支记录云备份仅关联设备匿名标识符，不包含姓名等可识别身份的信息，且不向其他用户公开展示。
• 公益排行榜仅公开展示打赏档位、金额与脱敏昵称，不展示您的真实姓名或华为账号等可识别身份的信息。
• 您可以在心愿墙删除自己发布的心愿，删除后云端记录将一并移除。
• 您可以在应用中随时清除本地历史记录。
• 卸载应用将自动删除设备本地数据。

五、您的权利
• 您有权随时清除祈福历史等本地记录。
• 您有权删除自己发布的心愿。
• 您有权拒绝提供姓名，仅影响排行榜与心愿墙的展示效果。
• 如对本隐私政策有任何疑问，请联系客服：${SUPPORT_EMAIL}。

六、更新说明
我们可能会适时更新本隐私政策，更新后的政策将在应用内公示。

本政策自发布之日起生效。`;
  }
}