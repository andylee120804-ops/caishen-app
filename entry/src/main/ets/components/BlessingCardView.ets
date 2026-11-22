// entry/src/main/ets/components/BlessingCardView.ets
// 六套电子祈福卡模板（与 blessing-card-preview.html 的 6 套视觉方案一一对应）。
// 卡片固定由外层容器给定尺寸；模板只负责背景、主财神、祈福话与印章的排版。
const CLOUD_PATH: string =
  'M12 40 C12 31 19 24 28 24 C30 13 40 6 52 8 C61 9 68 15 70 23 C78 24 84 30 84 38 C84 47 77 54 68 54 L28 54 C19 54 12 47 12 40 Z'

@Component
export struct BlessingCardView {
  @Prop template: number = 1
  @Prop words: string = ''
  @Prop deityId: number = 1
  @Prop deityName: string = '财神'
  @Prop deityDirection: string = ''
  @Prop dateLabel: string = ''

  // ── 公共：主财神徽章 ──
  @Builder DeityBadge(labelColor: string, nameColor: string, borderColor: string, bgColor: string,
    glowColor: string) {
    Row() {
      Stack() {
        Column()
          .width('100%')
          .height('100%')
          .radialGradient({
            center: ['50%', '40%'],
            radius: '65%',
            colors: [[glowColor, 0.0], ['rgba(0,0,0,0.12)', 1.0]]
          })
        Image($rawfile(`deities/${this.deityId}.png`))
          .width('92%')
          .height('92%')
          .objectFit(ImageFit.Contain)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
      .clip(true)
      .border({ width: 1, color: borderColor })
      .backgroundColor(bgColor)

      Column() {
        Text(`今日主財神 · ${this.deityDirection}`)
          .fontSize(8)
          .fontColor(labelColor)
          .letterSpacing(1)
          .maxLines(1)
        Text(this.deityName)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(nameColor)
          .letterSpacing(1)
          .maxLines(1)
          .margin({ top: 1 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 7 })
    }
    .padding({ left: 5, right: 11, top: 4, bottom: 4 })
    .borderRadius(30)
    .border({ width: 1, color: borderColor })
    .backgroundColor(bgColor)
    .alignItems(VerticalAlign.Center)
  }

  @Builder Divider(gold: string) {
    Row() {
      Row()
        .height(1)
        .layoutWeight(1)
        .backgroundColor(gold)
        .opacity(0.5)
      Text('◆')
        .fontSize(5)
        .fontColor(gold)
        .margin({ left: 6, right: 6 })
      Row()
        .height(1)
        .layoutWeight(1)
        .backgroundColor(gold)
        .opacity(0.5)
    }
    .width('100%')
    .margin({ top: 7, bottom: 7 })
  }

  @Builder BlessingPanel(color: string, bg: string, border: string) {
    Column() {
      Text(this.words)
        .fontSize(17)
        .lineHeight(26)
        .fontColor(color)
        .textAlign(TextAlign.Center)
        .maxLines(5)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 12, bottom: 12 })
    .backgroundColor(bg)
    .border({ width: 1, color: border, radius: 6 })
  }

  @Builder Footer(text: string, color: string) {
    Text(text)
      .fontSize(9)
      .fontColor(color)
      .letterSpacing(3)
      .textAlign(TextAlign.Center)
      .maxLines(1)
  }

  @Builder Brand(color: string) {
    Text('财神保佑 · 电子祈福卡')
      .fontSize(7)
      .fontColor(color)
      .letterSpacing(2)
      .margin({ top: 4 })
  }

  @Builder Seal(text: string, bg: string) {
    Text(text)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FDF6E3')
      .textAlign(TextAlign.Center)
      .width(32)
      .height(32)
      .backgroundColor(bg)
      .border({ width: 1.5, color: '#FDF6E3', radius: 3 })
      .rotate({ angle: -8 })
      .position({ x: 208, y: 296 })
  }

  @Builder CardFrame(gold: string) {
    Column()
      .width('93%')
      .height('94%')
      .border({ width: 0.8, color: gold, radius: 4 })
      .opacity(0.35)
      .hitTestBehavior(HitTestMode.None)
  }

  // ── 方案一：朱砂金榜 ──
  @Builder T1() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '0%'],
          radius: '120%',
          colors: [['#B82333', 0.0], ['#941526', 0.4], ['#5B0711', 0.75], ['#350309', 1.0]]
        })
      Text('福')
        .fontSize(130)
        .fontColor('#E8C25A')
        .opacity(0.055)
        .position({ x: '50%', y: '46%' })
        .translate({ x: '-50%', y: '-50%' })
      Path({ commands: CLOUD_PATH })
        .width(96)
        .height(54)
        .fill('none')
        .stroke('#E8C25A')
        .strokeWidth(1)
        .opacity(0.24)
        .position({ x: -16, y: 22 })
      Path({ commands: CLOUD_PATH })
        .width(110)
        .height(58)
        .fill('none')
        .stroke('#E8C25A')
        .strokeWidth(1)
        .opacity(0.20)
        .position({ x: 176, y: 280 })
        .rotate({ angle: 170 })
      this.CardFrame('#E8C25A')
      Column() {
        this.DeityBadge('#E8C25A', '#FFF8E7', 'rgba(232,194,90,0.45)', 'rgba(0,0,0,0.16)',
          'rgba(255,220,120,0.24)')
        Text('財神賜福')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E8C25A')
          .letterSpacing(5)
          .margin({ top: 6 })
        Text(this.dateLabel)
          .fontSize(8)
          .fontColor('rgba(253,246,227,0.72)')
          .letterSpacing(2)
          .margin({ top: 3 })
        this.Divider('#E8C25A')
        this.BlessingPanel('#FFF8E7', 'rgba(30,0,3,0.30)', 'rgba(232,194,90,0.42)')
        Blank()
        this.Footer('心诚则灵 · 福禄双至', '#E8C25A')
        this.Brand('rgba(253,246,227,0.5)')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 16 })
      .alignItems(HorizontalAlign.Center)
      this.Seal('賜', '#B3261E')
    }
    .width('100%')
    .height('100%')
    .border({ width: 1.5, color: '#E8C25A', radius: 6 })
    .clip(true)
  }

  // ── 方案二：宣纸墨金 ──
  @Builder T2() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#F7F0DF', 0.0], ['#EFE4CA', 0.55], ['#E3D3B4', 1.0]]
        })
      Text('福')
        .fontSize(130)
        .fontColor('#9A6B1F')
        .opacity(0.045)
        .position({ x: '56%', y: '52%' })
        .translate({ x: '-50%', y: '-50%' })
      Circle()
        .width(150)
        .height(150)
        .fill('none')
        .stroke('#2B2118')
        .strokeWidth(1)
        .opacity(0.10)
        .position({ x: 190, y: 160 })
      this.CardFrame('#9A6B1F')
      Column() {
        Row() {
          Blank()
          Column() {
            Text(this.dateLabel)
              .fontSize(8)
              .fontColor('#6B4E22')
              .letterSpacing(1)
            Column() {
              this.DeityBadge('#6B4E22', '#241A10', 'rgba(154,107,31,0.42)', 'rgba(255,255,255,0.35)',
                'rgba(154,107,31,0.18)')
            }
            .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')

        Row() {
          Column() {
            Text('祈').fontSize(30).fontColor('#241A10')
            Text('福').fontSize(30).fontColor('#241A10')
          }
          .width(42)
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 14 })

          Column() {
            Text(this.words)
              .fontSize(17)
              .lineHeight(28)
              .fontColor('#241A10')
              .textAlign(TextAlign.Start)
              .maxLines(5)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .layoutWeight(1)
          .padding({ left: 10 })
          .border({ width: { left: 1.5 }, color: 'rgba(154,107,31,0.45)' })
          .margin({ top: 14 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Blank()
        this.Footer('心诚则灵 · 福禄双至', '#6B4E22')
        this.Brand('rgba(107,78,34,0.62)')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 16 })
      .alignItems(HorizontalAlign.Center)
      this.Seal('福', '#A8322A')
    }
    .width('100%')
    .height('100%')
    .border({ width: 1.5, color: '#9A6B1F', radius: 6 })
    .clip(true)
  }

  // ── 方案三：黛蓝鎏金 ──
  @Builder T3() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '0%'],
          radius: '130%',
          colors: [['#2B3F73', 0.0], ['#172246', 0.42], ['#0B1229', 0.72], ['#050814', 1.0]]
        })
      Column()
        .width(34)
        .height(34)
        .borderRadius(17)
        .radialGradient({
          center: ['36%', '34%'],
          radius: '70%',
          colors: [['#FFF8D8', 0.0], ['#F2DE9F', 0.45], ['#C7A75A', 1.0]]
        })
        .shadow({ radius: 18, color: 'rgba(242,222,159,0.35)' })
        .position({ x: 212, y: 22 })
      Text('✦').fontSize(5).fontColor('#F0D98D').opacity(0.70).position({ x: 36, y: 70 })
      Text('✦').fontSize(4).fontColor('#F0D98D').opacity(0.50).position({ x: 70, y: 44 })
      Text('✦').fontSize(6).fontColor('#F0D98D').opacity(0.65).position({ x: 120, y: 86 })
      Text('✦').fontSize(4).fontColor('#F0D98D').opacity(0.45).position({ x: 180, y: 52 })
      Text('✦').fontSize(5).fontColor('#F0D98D').opacity(0.55).position({ x: 238, y: 96 })
      Path({ commands: 'M34 120 L78 78 L120 104 L176 50 L230 90' })
        .width(240)
        .height(120)
        .fill('none')
        .stroke('#F0D98D')
        .strokeWidth(0.5)
        .opacity(0.28)
        .position({ x: 10, y: 20 })
      Path({ commands: CLOUD_PATH })
        .width(130)
        .height(60)
        .fill('none')
        .stroke('#E6C66A')
        .strokeWidth(1)
        .opacity(0.18)
        .position({ x: -24, y: 280 })
      this.CardFrame('#E6C66A')
      Column() {
        this.DeityBadge('#E6C66A', '#F8F1DD', 'rgba(230,198,106,0.42)', 'rgba(5,9,22,0.35)',
          'rgba(240,217,141,0.20)')
        Text('天官賜福')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E6C66A')
          .letterSpacing(5)
          .margin({ top: 6 })
        Text(this.dateLabel)
          .fontSize(8)
          .fontColor('rgba(207,198,173,0.78)')
          .letterSpacing(2)
          .margin({ top: 3 })
        this.Divider('#E6C66A')
        this.BlessingPanel('#F8F1DD', 'rgba(5,9,22,0.55)', 'rgba(230,198,106,0.42)')
        Blank()
        this.Footer('星月同輝 · 財源廣進', '#E6C66A')
        this.Brand('rgba(207,198,173,0.5)')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 16 })
      .alignItems(HorizontalAlign.Center)
      this.Seal('財', '#9E2B2B')
    }
    .width('100%')
    .height('100%')
    .border({ width: 1.5, color: '#E6C66A', radius: 6 })
    .clip(true)
  }

  // ── 方案四：青绿山水 ──
  @Builder T4() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '0%'],
          radius: '110%',
          colors: [['#195741', 0.0], ['#0F3D2E', 0.38], ['#09291E', 0.68], ['#04150F', 1.0]]
        })
      Column()
        .width(32)
        .height(32)
        .borderRadius(16)
        .radialGradient({
          center: ['40%', '36%'],
          radius: '70%',
          colors: [['#FFF7D2', 0.0], ['#EFD795', 0.45], ['#C7A54E', 1.0]]
        })
        .shadow({ radius: 20, color: 'rgba(239,215,149,0.30)' })
        .position({ x: 34, y: 24 })
      Path({ commands: CLOUD_PATH })
        .width(120)
        .height(54)
        .fill('none')
        .stroke('#E0C06A')
        .strokeWidth(1)
        .opacity(0.20)
        .position({ x: 172, y: 28 })
      Polygon({ width: 260, height: 117 })
        .points([[0, 117], [45, 50], [85, 80], [130, 18], [185, 76], [225, 40], [260, 82], [260, 117]])
        .fill('rgba(224,192,106,0.08)')
        .stroke('#E0C06A')
        .strokeWidth(1)
        .opacity(0.55)
        .position({ x: 0, y: 230 })
      Polygon({ width: 260, height: 77 })
        .points([[0, 77], [55, 30], [110, 60], [170, 12], [220, 50], [260, 28], [260, 77]])
        .fill('rgba(224,192,106,0.10)')
        .stroke('#E0C06A')
        .strokeWidth(0.8)
        .opacity(0.42)
        .position({ x: 0, y: 270 })
      Column()
        .width('100%')
        .height(100)
        .linearGradient({
          angle: 180,
          colors: [['rgba(4,21,15,0)', 0.0], ['rgba(4,21,15,0.72)', 1.0]]
        })
        .position({ x: 0, y: 247 })
        .hitTestBehavior(HitTestMode.None)
      this.CardFrame('#E0C06A')
      Column() {
        this.DeityBadge('#E0C06A', '#F4EFD9', 'rgba(224,192,106,0.42)', 'rgba(3,22,16,0.38)',
          'rgba(224,192,106,0.20)')
        Text('山水納福')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E0C06A')
          .letterSpacing(5)
          .margin({ top: 6 })
        Text(this.dateLabel)
          .fontSize(8)
          .fontColor('rgba(244,239,217,0.72)')
          .letterSpacing(2)
          .margin({ top: 3 })
        this.Divider('#E0C06A')
        this.BlessingPanel('#F4EFD9', 'rgba(3,22,16,0.48)', 'rgba(224,192,106,0.40)')
        Blank()
        this.Footer('山高水長 · 福澤綿長', '#E0C06A')
        this.Brand('rgba(244,239,217,0.5)')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 16 })
      .alignItems(HorizontalAlign.Center)
      this.Seal('吉', '#9E2B2B')
    }
    .width('100%')
    .height('100%')
    .border({ width: 1.5, color: '#E0C06A', radius: 6 })
    .clip(true)
  }

  // ── 方案五：绛紫祥云 ──
  @Builder T5() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '0%'],
          radius: '125%',
          colors: [['#5A2775', 0.0], ['#3B144E', 0.4], ['#220A31', 0.72], ['#100317', 1.0]]
        })
      Circle()
        .width(220)
        .height(220)
        .fill('none')
        .stroke('#E7C873')
        .strokeWidth(1)
        .opacity(0.15)
        .position({ x: 20, y: 66 })
      Circle()
        .width(170)
        .height(170)
        .fill('none')
        .stroke('#E7C873')
        .strokeWidth(0.8)
        .opacity(0.12)
        .position({ x: 45, y: 91 })
      Path({ commands: CLOUD_PATH })
        .width(170)
        .height(74)
        .fill('none')
        .stroke('#E7C873')
        .strokeWidth(1)
        .opacity(0.12)
        .position({ x: 52, y: 142 })
      Path({ commands: CLOUD_PATH })
        .width(110)
        .height(54)
        .fill('none')
        .stroke('#E7C873')
        .strokeWidth(1)
        .opacity(0.20)
        .position({ x: 176, y: 34 })
      this.CardFrame('#E7C873')
      Column() {
        this.DeityBadge('#E7C873', '#F8F0DE', 'rgba(231,200,115,0.42)', 'rgba(24,4,34,0.35)',
          'rgba(231,200,115,0.20)')
        Text('紫氣東來')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#E7C873')
          .letterSpacing(5)
          .margin({ top: 6 })
        Text(this.dateLabel)
          .fontSize(8)
          .fontColor('rgba(248,240,222,0.70)')
          .letterSpacing(2)
          .margin({ top: 3 })
        this.Divider('#E7C873')
        this.BlessingPanel('#F8F0DE', 'rgba(24,4,34,0.50)', 'rgba(231,200,115,0.42)')
        Blank()
        this.Footer('祥雲瑞氣 · 福澤綿長', '#E7C873')
        this.Brand('rgba(248,240,222,0.5)')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 16 })
      .alignItems(HorizontalAlign.Center)
      this.Seal('祥', '#9E2B2B')
    }
    .width('100%')
    .height('100%')
    .border({ width: 1.5, color: '#E7C873', radius: 6 })
    .clip(true)
  }

  // ── 方案六：玄黑鎏金 ──
  @Builder T6() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '0%'],
          radius: '115%',
          colors: [['#2E2719', 0.0], ['#17130C', 0.42], ['#0A0805', 0.74], ['#030302', 1.0]]
        })
      Text('福')
        .fontSize(150)
        .fontColor('#D9B65A')
        .opacity(0.055)
        .position({ x: '50%', y: '52%' })
        .translate({ x: '-50%', y: '-50%' })
      Row() {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], (i: number) => {
          Column()
            .width(6)
            .height(2)
            .backgroundColor('#D9B65A')
            .margin({ right: 7 })
        }, (i: number) => i.toString())
      }
      .width(208)
      .position({ x: 14, y: 12 })
      .opacity(0.32)
      Row() {
        ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14], (i: number) => {
          Column()
            .width(6)
            .height(2)
            .backgroundColor('#D9B65A')
            .margin({ right: 7 })
        }, (i: number) => i.toString())
      }
      .width(208)
      .position({ x: 14, y: 332 })
      .opacity(0.32)
      this.CardFrame('#D9B65A')
      Column() {
        this.DeityBadge('#D9B65A', '#F6EEDB', 'rgba(217,182,90,0.42)', 'rgba(0,0,0,0.22)',
          'rgba(217,182,90,0.18)')
        Text('福')
          .fontSize(44)
          .fontWeight(FontWeight.Bold)
          .fontColor('#D9B65A')
          .margin({ top: 2 })
        Text(this.dateLabel)
          .fontSize(8)
          .fontColor('rgba(246,238,219,0.68)')
          .letterSpacing(2)
          .margin({ top: 2 })
        this.Divider('#D9B65A')
        Text(this.words)
          .fontSize(16)
          .lineHeight(25)
          .fontColor('#F6EEDB')
          .textAlign(TextAlign.Center)
          .maxLines(5)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { top: 1, bottom: 1 }, color: 'rgba(217,182,90,0.42)' })
        Blank()
        this.Footer('心誠則靈 · 福祿雙至', '#D9B65A')
        this.Brand('rgba(246,238,219,0.5)')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 18, right: 18, top: 12, bottom: 14 })
      .alignItems(HorizontalAlign.Center)
      this.Seal('財', '#A52B24')
    }
    .width('100%')
    .height('100%')
    .border({ width: 1.5, color: '#D9B65A', radius: 6 })
    .clip(true)
  }

  build() {
    Stack() {
      if (this.template === 2) {
        this.T2()
      } else if (this.template === 3) {
        this.T3()
      } else if (this.template === 4) {
        this.T4()
      } else if (this.template === 5) {
        this.T5()
      } else if (this.template === 6) {
        this.T6()
      } else {
        this.T1()
      }
    }
    .width('100%')
    .height('100%')
  }
}
