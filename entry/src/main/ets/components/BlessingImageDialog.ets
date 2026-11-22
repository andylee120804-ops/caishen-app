// entry/src/main/ets/components/BlessingImageDialog.ets
// 财神殿「写下祈福话 → 生成电子祈福图 → 保存到手机」。
// 保存使用系统 SaveButton 安全控件：首次点击由系统授予临时相册写权限，
// 无需在 module.json5 申请 WRITE_IMAGEVIDEO，避免审核额外索权。
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { BlessingCardView } from './BlessingCardView'
import { lunarTextOf } from '../model/LunarCalendar'

const PREVIEW_ID: string = 'hallBlessingCardPreview'

interface TemplateDef {
  id: number
  name: string
  short: string
  bg: string
  fg: string
}

const TEMPLATES: TemplateDef[] = [
  { id: 1, name: '朱砂金榜', short: '朱砂', bg: '#8A1120', fg: '#FFD700' },
  { id: 2, name: '宣纸墨金', short: '宣纸', bg: '#EFE4CA', fg: '#2B2118' },
  { id: 3, name: '黛蓝鎏金', short: '黛蓝', bg: '#172246', fg: '#E6C66A' },
  { id: 4, name: '青绿山水', short: '青绿', bg: '#0F3D2E', fg: '#E0C06A' },
  { id: 5, name: '绛紫祥云', short: '绛紫', bg: '#3B144E', fg: '#E7C873' },
  { id: 6, name: '玄黑鎏金', short: '黑金', bg: '#17130C', fg: '#D9B65A' }
]

function logError(tag: string, err: Object): void {
  try {
    if (err instanceof Error) {
      const e = err as Error
      console.error('[BlessingImage] ' + tag + ': ' + e.message + '\n' + (e.stack || ''))
      return
    }
    console.error('[BlessingImage] ' + tag + ': ' + JSON.stringify(err))
  } catch (e) {
    console.error('[BlessingImage] ' + tag + ': <unserializable error>')
  }
}

/** 把组件截图编码为 JPEG 写入系统相册（调用前 SaveButton 已授予临时权限） */
async function savePixelMapToGallery(ctx: common.UIAbilityContext, pixelMap: image.PixelMap): Promise<void> {
  const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx)
  const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg')
  const packer: image.ImagePacker = image.createImagePacker()
  const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY)
  try {
    const option: image.PackingOption = { format: 'image/jpeg', quality: 95 }
    const data: ArrayBuffer = await packer.packing(pixelMap, option)
    fileIo.writeSync(file.fd, data)
  } finally {
    fileIo.closeSync(file)
    await packer.release()
  }
}

@CustomDialog
export struct BlessingImageDialog {
  controller: CustomDialogController
  deityId: number = 1
  deityName: string = '财神'
  deityDirection: string = ''
  initialTemplate: number = 1
  /** 模板切换回调（页面侧持久化用户选择） */
  onTemplateChange: (template: number) => void = () => {}
  /** 关闭兜底：注入的 controller 可能为 undefined，由创建方用自己的引用关闭 */
  onClose: () => void = () => {}
  /** 弹窗销毁通知：创建方释放控制器引用，允许下次再开 */
  onClosed: () => void = () => {}
  @State words: string = ''
  @State generated: boolean = false
  /** 当前预览模板（1-6） */
  @State template: number = 1
  /** 非 @State：仅做防重入，保存完成后不触发 UI 更新（弹窗可能已被系统回收） */
  private saving: boolean = false

  aboutToAppear(): void {
    this.template = this.clampTemplate(this.initialTemplate)
  }

  aboutToDisappear(): void {
    this.onClosed()
  }

  private clampTemplate(t: number): number {
    return (t >= 1 && t <= 6) ? t : 1
  }

  private templateName(): string {
    for (const t of TEMPLATES) {
      if (t.id === this.template) {
        return t.name
      }
    }
    return TEMPLATES[0].name
  }

  private selectTemplate(t: number): void {
    const next: number = this.clampTemplate(t)
    if (next === this.template) {
      return
    }
    this.template = next
    this.onTemplateChange(next)
  }

  private closeDialog(): void {
    const c = this.controller
    if (c !== undefined && c !== null) {
      try {
        c.close()
        return
      } catch (err) {
        logError('controller.close failed', err as Object)
      }
    }
    this.onClose()
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2200 })
    } catch (err) {
      logError('toast failed', err as Object)
    }
  }

  private generate(): void {
    const text: string = this.words.trim()
    if (text === '') {
      this.toast('先写一句祈福话吧')
      return
    }
    this.words = text
    this.generated = true
  }

  private async saveToGallery(result: SaveButtonOnClickResult): Promise<void> {
    if (result !== SaveButtonOnClickResult.SUCCESS) {
      this.toast('保存授权未通过，请重试')
      return
    }
    if (this.saving) {
      return
    }
    this.saving = true
    // UIContext 属于 Ability 窗口：保存期间弹窗若被系统回收，toast 仍可用
    const ui = this.getUIContext()
    const toast = (msg: string): void => {
      try {
        ui.getPromptAction().showToast({ message: msg, duration: 2200 })
      } catch (e) {
        logError('toast failed', e as Object)
      }
    }
    try {
      const pixelMap: image.PixelMap = await ui.getComponentSnapshot().get(PREVIEW_ID)
      const ctx: common.UIAbilityContext = ui.getHostContext() as common.UIAbilityContext
      if (ctx === undefined || ctx === null) {
        await pixelMap.release()
        toast('保存环境未就绪，请重试')
        return
      }
      await savePixelMapToGallery(ctx, pixelMap)
      await pixelMap.release()
      toast('祈福图已保存到相册')
    } catch (err) {
      const be: BusinessError = err as BusinessError
      logError('save failed: code=' + (be.code ?? -1), err as Object)
      toast('保存失败，请重试')
    } finally {
      this.saving = false
    }
  }

  private dateLabel(): string {
    const d: Date = new Date()
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0')
    const day: string = d.getDate().toString().padStart(2, '0')
    const lunar: string = lunarTextOf(`${d.getFullYear()}-${m}-${day}`)
    return lunar !== '' ? lunar : `${d.getFullYear()}年${d.getMonth() + 1}月${d.getDate()}日`
  }

  @Builder
  TemplateChip(t: TemplateDef) {
    Column() {
      Stack() {
        Column()
          .width(32)
          .height(32)
          .backgroundColor(t.bg)
          .borderRadius(8)
          .border({
            width: this.template === t.id ? 2 : 1,
            color: this.template === t.id ? '#FFD700' : 'rgba(255, 209, 0, 0.28)'
          })
        Text(t.id.toString())
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(t.fg)
      }
      .width(32)
      .height(32)

      Text(t.short)
        .fontSize(8)
        .fontColor(this.template === t.id ? '#FFD700' : 'rgba(253, 246, 227, 0.62)')
        .margin({ top: 3 })
    }
    .width(44)
    .margin({ right: 6 })
    .onClick(() => {
      this.selectTemplate(t.id)
    })
  }

  build() {
    Column() {
      Row()
        .width('100%')
        .height(4)
        .backgroundColor('#A01124')

      if (!this.generated) {
        Text('写下祈福话')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .letterSpacing(2)
          .margin({ top: 18, bottom: 6 })

        Text('点香之后，把心里的话写下来')
          .fontSize(11)
          .fontColor('rgba(253, 246, 227, 0.75)')
          .fontStyle(FontStyle.Italic)
          .margin({ bottom: 14 })

        TextInput({ placeholder: '愿家人平安顺遂，财源广进', text: this.words })
          .onChange((v: string) => {
            this.words = v
          })
          .maxLength(50)
          .width('100%')
          .height(44)
          .backgroundColor('rgba(255, 255, 255, 0.08)')
          .fontColor('#fdf6e3')
          .placeholderColor('rgba(253, 246, 227, 0.7)')
          .caretColor('#FFD700')

        Row() {
          Button('取消')
            .fontSize(13)
            .backgroundColor(Color.Transparent)
            .fontColor('#FFD700')
            .border({ width: 1, color: 'rgba(255, 209, 0, 0.4)' })
            .onClick(() => {
              this.closeDialog()
            })
          Button('生成祈福图')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .backgroundColor('#FFD700')
            .fontColor('#1a1a0a')
            .onClick(() => {
              this.generate()
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 14 })
      } else {
        Text('专属祈福图')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFD700')
          .letterSpacing(2)
          .margin({ top: 14, bottom: 10 })

        Column() {
          BlessingCardView({
            template: this.template,
            words: this.words,
            deityId: this.deityId,
            deityName: this.deityName,
            deityDirection: this.deityDirection,
            dateLabel: this.dateLabel()
          })
        }
        .id(PREVIEW_ID)
        .width(260)
        .height(347)
        .constraintSize({ maxWidth: '100%' })
        .backgroundColor('#580E15')

        Scroll() {
          Row() {
            ForEach(TEMPLATES, (t: TemplateDef) => {
              this.TemplateChip(t)
            }, (t: TemplateDef) => t.id.toString())
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(50)
        .margin({ top: 8 })

        Text('左右滑动选择模板 · 当前：' + this.templateName())
          .fontSize(9)
          .fontColor('rgba(253, 246, 227, 0.65)')
          .margin({ top: 1, bottom: 2 })

        Row() {
          SaveButton({
            icon: SaveIconStyle.FULL_FILLED,
            text: SaveDescription.SAVE_IMAGE,
            buttonType: ButtonType.Capsule
          })
            .width('100%')
            .height(42)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1a1a0a')
            .backgroundColor('#FFD700')
            .onClick((event: ClickEvent, result: SaveButtonOnClickResult) => {
              this.saveToGallery(result).catch((err: Object) => {
                logError('save rejected', err)
              })
            })
        }
        .width('86%')
        .margin({ top: 8 })

        Row() {
          Button('重新填写')
            .fontSize(12)
            .fontColor('#FFD700')
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: 'rgba(255, 209, 0, 0.4)' })
            .onClick(() => {
              this.generated = false
            })
          Button('关闭')
            .fontSize(12)
            .fontColor('rgba(253, 246, 227, 0.75)')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.closeDialog()
            })
        }
        .width('86%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 10, bottom: 4 })
      }
    }
    .width('88%')
    .padding({ left: 16, right: 16, bottom: 14 })
    .backgroundColor('#580E15')
    .borderRadius(16)
    .border({ width: 1.5, color: 'rgba(255, 209, 0, 0.3)' })
    .shadow({ radius: 30, color: 'rgba(0, 0, 0, 0.6)', offsetY: 6 })
    .clip(true)
  }
}
