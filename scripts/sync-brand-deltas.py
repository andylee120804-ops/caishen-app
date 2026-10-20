# caishen-app 品牌与新内容重放脚本：以 mashen 回滚后的 ets 树为基底，重放所有 caishen 专属改动
# 每对替换失败会打印 FAIL，便于核对
import io, os, re

ROOT = 'entry/src/main/ets'
FAIL = []


def rep(path, old, new, count=1):
    p = os.path.join(ROOT, path)
    src = io.open(p, encoding='utf-8').read()
    n = src.count(old)
    if n < count:
        FAIL.append(f'{path} 缺片段({n}<{count}): {old[:60]}')
        return
    src = src.replace(old, new, count)
    io.open(p, 'w', encoding='utf-8', newline='').write(src)


def rep_all(path, old, new):
    rep(path, old, new, 1)  # 全局替换：count 校验为 ≥1
    # 补：多次替换
    p = os.path.join(ROOT, path)
    src = io.open(p, encoding='utf-8').read()
    src = src.replace(old, new)
    io.open(p, 'w', encoding='utf-8', newline='').write(src)


# ── 1. 全局品牌：麻神 → 财神 ──
for dirpath, _, files in os.walk(ROOT):
    for f in files:
        if f.endswith('.ets'):
            p = os.path.join(dirpath, f)
            src = io.open(p, encoding='utf-8').read()
            if '麻神' in src:
                io.open(p, 'w', encoding='utf-8', newline='').write(src.replace('麻神', '财神'))
for f in ['AppScope/resources/base/element/string.json', 'entry/src/main/resources/base/element/string.json']:
    src = io.open(f, encoding='utf-8').read()
    io.open(f, 'w', encoding='utf-8', newline='').write(src.replace('麻神', '财神'))

# ── 2. 新五路财神：PrayerTypes.FIVE_DEITIES ──
rep('model/PrayerTypes.ets',
    """  {
    id: 1, name: '赵公明', direction: '中路',
    features: '黑面·铁鞭·黑虎', color: '#1a1a0a',
    mahjongMeaning: '坐镇牌局，保护手气',
    lottieFile: 'deities/zhaogongming.json',
    soundFile: 'deity_zhonglu.mp3'
  },
  {
    id: 2, name: '萧升', direction: '东路',
    features: '绿袍·宝珠', color: '#2ecc71',
    mahjongMeaning: '招宝入局，好牌连连',
    lottieFile: 'deities/xiaosheng.json',
    soundFile: 'deity_donglu.mp3'
  },
  {
    id: 3, name: '曹宝', direction: '西路',
    features: '棕袍·珍宝', color: '#8B4513',
    mahjongMeaning: '纳珍入库，攒好牌型',
    lottieFile: 'deities/caobao.json',
    soundFile: 'deity_xilu.mp3'
  },
  {
    id: 4, name: '陈九公', direction: '南路',
    features: '红袍·金元宝', color: '#c0392b',
    mahjongMeaning: '招财进宝，胡牌赢钱',
    lottieFile: 'deities/chenjiugong.json',
    soundFile: 'deity_nanlu.mp3'
  },
  {
    id: 5, name: '姚少司', direction: '北路',
    features: '紫袍·如意', color: '#9b59b6',
    mahjongMeaning: '利市亨通，顺风顺水',
    lottieFile: 'deities/yaoshaosi.json',
    soundFile: 'deity_beilu.mp3'
  }""",
    """  {
    id: 1, name: '王亥', direction: '中路',
    features: '牛车·华商始祖', color: '#d4a017',
    mahjongMeaning: '商祖开路，牛转乾坤，稳坐庄家',
    lottieFile: 'deities/wanghai.json',
    soundFile: 'deity_zhonglu.mp3'
  },
  {
    id: 2, name: '比干', direction: '东路',
    features: '文财神·无心公正', color: '#4a90d9',
    mahjongMeaning: '公道无私，正财稳进，童叟无欺',
    lottieFile: 'deities/bigan.json',
    soundFile: 'deity_donglu.mp3'
  },
  {
    id: 3, name: '关羽', direction: '西路',
    features: '武财神·青龙偃月', color: '#2ecc71',
    mahjongMeaning: '重义守信，镇桌驱邪，合伙共赢',
    lottieFile: 'deities/guanyu.json',
    soundFile: 'deity_xilu.mp3'
  },
  {
    id: 4, name: '柴荣', direction: '南路',
    features: '君王财神·后周世宗', color: '#e67e22',
    mahjongMeaning: '帝王之气，破釜沉舟，做大做强',
    lottieFile: 'deities/chairong.json',
    soundFile: 'deity_nanlu.mp3'
  },
  {
    id: 5, name: '赵公明', direction: '北路',
    features: '黑面·铁鞭·黑虎', color: '#1a1a0a',
    mahjongMeaning: '坐镇牌局，保护手气',
    lottieFile: 'deities/zhaogongming.json',
    soundFile: 'deity_beilu.mp3'
  }""")

# ── 3. 财神百科：CultureContent.DEITY_ENCYCLOPEDIA ──
old_enc = io.open('entry/src/main/ets/model/CultureContent.ets', encoding='utf-8').read()
start = old_enc.index("export const DEITY_ENCYCLOPEDIA")
end = old_enc.index("\n]\n", start)
end = old_enc.index("]", end) + 1
new_enc = """export const DEITY_ENCYCLOPEDIA: DeityEntry[] = [
  {
    id: 1, name: '王亥', title: '华商始祖 · 中路财神', icon: '🐂',
    direction: '中路',
    story: '王亥是商部落的首领，中国历史上第一个驯服野牛、造出牛车的人。他率族人赶着牛车与周边部落以物易物，开启了中国商业的先河——后世称呼做买卖的人为「商人」，正是源于商族。',
    domain: '商业开山、买卖兴隆、经营有道，利所有做生意、做买卖的人',
    worship: '供品宜用谷物牛肉；开业、谈大单前默念商祖之名；心诚则灵，忌无信',
    tile: '🀄 中发白'
  },
  {
    id: 2, name: '比干', title: '文财神 · 无心公正', icon: '⚖️',
    direction: '东路',
    story: '比干是商朝忠臣，《封神演义》中剖心以证忠义。他因「无心」而无私，办事公道、童叟无欺，被后世奉为文财神，专佑上班族、公务员等领正职薪水的人。',
    domain: '正财工资、升职加薪、公正待遇，利领薪水的上班族与公职人员',
    worship: '宜素果清茶；求升职加薪时心中默念所求职位；忌心术不正',
    tile: '🀇 条子'
  },
  {
    id: 3, name: '关羽', title: '武财神 · 义薄云天', icon: '⚔️',
    direction: '西路',
    story: '关二爷红面长髯、手使青龙偃月刀，被尊为「武圣」。他重信守义，明清商帮走南闯北皆奉为保护神，既能镇守门庭驱邪避恶，又能保佑合作顺利、财源广进。',
    domain: '诚信经营、合作共赢、镇宅守财，利创业者与合伙做生意的人',
    worship: '宜燃香献酒；签约、开张前拜之求「义」「信」二字；忌背信弃义',
    tile: '🀈 筒子'
  },
  {
    id: 4, name: '柴荣', title: '君王财神 · 后周世宗', icon: '👑',
    direction: '南路',
    story: '柴荣是五代后周皇帝，少年时弃儒经商，深知民间疾苦。登基后大刀阔斧改革经济、毁佛铸钱以充实国库，被誉为「五代第一明君」。拜他，求的是破釜沉舟的魄力和做大做强的帝王之气。',
    domain: '宏图霸业、做大做强、破局翻身，利企业家与有大志向的人',
    worship: '宜先明志向而后拜，心中默念三年目标；忌小富即安',
    tile: '🀉 万子'
  },
  {
    id: 5, name: '赵公明', title: '正财神 · 玄坛真君', icon: '🐯',
    direction: '北路',
    story: '赵公明黑面骑黑虎、执铁鞭，统领招宝、纳珍、招财、利市四仙官，法力高强，被尊为华夏第一正财神。凡求八方之财、驱邪避灾者，皆可拜他。',
    domain: '八方之财、家宅安宁、驱邪避灾，利所有求财之人',
    worship: '宜用三牲果品、香烛元宝；初一十五上香最佳；心诚则灵，忌心术不正',
    tile: '🀅 发财'
  }
]"""
src = old_enc[:start] + new_enc + old_enc[end:]
io.open('entry/src/main/ets/model/CultureContent.ets', 'w', encoding='utf-8', newline='').write(src)

# ── 4. 五神阵注释 ──
rep('components/DeityArrayView.ets',
    ' * 五路财神弧形阵布局：中路赵公明居中且最大，两侧错落递减形成弧形。',
    ' * 五路财神弧形阵布局：中路王亥居中且最大，两侧错落递减形成弧形。')
rep('components/DeityArrayView.ets', '// 中路·赵公明（主位·弧底，约屏幕26%）', '// 中路·王亥（主位·弧底，约屏幕26%）')
rep('components/DeityArrayView.ets', '// 东路·萧升', '// 东路·比干')
rep('components/DeityArrayView.ets', '// 西路·曹宝', '// 西路·关羽')
rep('components/DeityArrayView.ets', '// 南路·陈九公', '// 南路·柴荣')
rep('components/DeityArrayView.ets', '// 北路·姚少司', '// 北路·赵公明')

# ── 5. DeityRotator 注释 ──
rep('engine/DeityRotator.ets',
    '   * 今日主神站中央主位（锚点1），赵公明暂代主神原方位锚点，其余三路财神守本方位。',
    '   * 今日主神站中央主位（锚点1），中路财神（id1）暂代主神原方位锚点，其余三路财神守本方位。')

# ── 6. EnrichViewModel：收支记录注释 + 新神名表 ──
rep('viewmodels/EnrichViewModel.ets', '/** 牌局记录变更代次：每次记一笔 +1。', '/** 收支记录变更代次：每次记一笔 +1。')
rep('viewmodels/EnrichViewModel.ets', '/** 全量推送本地牌局记录到云端；', '/** 全量推送本地收支记录到云端；')
rep('viewmodels/EnrichViewModel.ets',
    "const names: Record<number, string> = { 1: '赵公明', 2: '萧升', 3: '曹宝', 4: '陈九公', 5: '姚少司' }",
    "const names: Record<number, string> = { 1: '王亥', 2: '比干', 3: '关羽', 4: '柴荣', 5: '赵公明' }")

# ── 7. 收支记录改名（UI+注释） ──
rep_all('components/GameRecordCard.ets', "Text('记录牌局')", "Text('记收支')")
rep('components/GameRecordCard.ets', '「记录牌局」记一笔', '「记收支」记一笔')
rep('components/GameRecordCard.ets', '记录牌局页明细就在下方', '收支记录页明细就在下方')
rep('components/GameRecordCard.ets', '// 记录牌局按钮（赢/输必填金额，平免金额也记一笔）', '// 记收支按钮（赢/输必填金额，平免金额也记一笔）')
rep('components/GameRecordCard.ets', '// 记录牌局弹窗', '// 记收支弹窗')
rep('components/GameRecordCard.ets', '/** 查看每笔明细 → 记录牌局完整页 */', '/** 查看每笔明细 → 收支记录完整页 */')
rep('pages/GameRecordPage.ets', '// 记录牌局：可配置底部 Tab 的完整内容页', '// 收支记录：可配置底部 Tab 的完整内容页')
rep('pages/GameRecordPage.ets', "Text('🎲 记录牌局')", "Text('🎲 收支记录')")
rep('pages/GameRecordPage.ets', "'☁ 联网后自动备份牌局记录，防丢失'", "'☁ 联网后自动备份收支记录，防丢失'")
rep('components/GameRecordDetailList.ets', '// 记录牌局·每笔明细：按日期分组', '// 收支记录·每笔明细：按日期分组')
rep('components/GameRecordDetailList.ets', '（记录牌局 Tab / 独立页）渲染', '（收支记录 Tab / 独立页）渲染')
rep('components/PrivacyDialog.ets', '• 牌局记录内容：您在牌局记录功能中录入的每局胜负结果', '• 收支记录内容：您在收支记录功能中录入的每局胜负结果')
rep('components/PrivacyDialog.ets', '• 牌局记录会上传至华为云服务器（AppGallery Connect 云服务）进行备份', '• 收支记录会上传至华为云服务器（AppGallery Connect 云服务）进行备份')
rep('components/PrivacyDialog.ets', '• 网络权限：用于访问排行榜、心愿墙、牌局记录云备份等云端功能。', '• 网络权限：用于访问排行榜、心愿墙、收支记录云备份等云端功能。')
rep('components/PrivacyDialog.ets', '• 牌局记录云备份仅关联设备匿名标识符', '• 收支记录云备份仅关联设备匿名标识符')
rep('components/ConfirmDialog.ets', '// 供牌局记录删除、祈福记录删除/清空等确认场景复用。', '// 供收支记录删除、祈福记录删除/清空等确认场景复用。')
rep('viewmodels/EntryConfigVM.ets', '记录牌局在「我的」页置顶固定展示', '收支记录在「我的」页置顶固定展示')
rep('viewmodels/EntryConfigVM.ets', "title: '记录牌局'", "title: '收支记录'")
rep('viewmodels/EntryConfigVM.ets', '// 💡 不占用祈福固定 Tab 的 🀄 字形，避免两处同形混淆', '// 💡 与祈福固定 Tab（金元宝自绘 PNG，见 MainTabs TabBarBuilder）区分，避免入口同形混淆')
rep('pages/MainTabs.ets', '// 记录牌局：与「我的」页置顶卡片共用同一份数据', '// 收支记录：与「我的」页置顶卡片共用同一份数据')
rep('pages/MyPage.ets', '即使「记录牌局」被设为底部 Tab 也不隐藏', '即使「收支记录」被设为底部 Tab 也不隐藏')
rep('pages/MyPage.ets', '每笔明细在记录牌局页（下方入口跳转，数据同一份）', '每笔明细在收支记录页（下方入口跳转，数据同一份）')
rep('pages/EntryShell.ets', '// 记录牌局：汇总 + 每笔明细', '// 收支记录：汇总 + 每笔明细')
rep('service/CloudService.ets', '/** 拉取本人云端牌局记录备份。', '/** 拉取本人云端收支记录备份。')
rep('service/CloudService.ets', '/** 全量推送牌局记录到云端备份', '/** 全量推送收支记录到云端备份')
rep('service/CloudService.ets', '/** 删除云端牌局记录（按日期，仅本人）', '/** 删除云端收支记录（按日期，仅本人）')
rep('entryability/EntryAbility.ets', '启动牌局记录云同步', '启动收支记录云同步')

# ── 8. 祈福 Tab 金元宝 ──
rep('pages/MainTabs.ets',
    """      } else {
        Text(def.icon)""",
    """      } else if (def.id === 'blessing') {
        // 祈福入口：金元宝自绘图（emoji 无元宝字形，贴合财神保佑主题）
        Image($rawfile('props/yuanbao.png'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      } else {
        Text(def.icon)""")
rep('pages/CustomizePage.ets', "private dragIcon: string = '🀄'", "private dragIcon: string = '🏮'")
rep('pages/CustomizePage.ets',
    """          Text('🀄 祈福（固定首位）')
            .fontSize(11)
            .fontColor('rgba(253, 246, 227, 0.6)')""",
    """          Row() {
            Image($rawfile('props/yuanbao.png'))
              .width(14)
              .height(14)
              .objectFit(ImageFit.Contain)
            Text(' 祈福（固定首位）')
              .fontSize(11)
              .fontColor('rgba(253, 246, 227, 0.6)')
          }""")

# ── 9. QiuQian 新素材注释 ──
rep('pages/QiuQian.ets',
    '// 签筒画面直接用用户提供的参考图素材（props/qiu_art.png，透明底，272×483），\n// 动画（俯身/摇摆/出签）在整图上做，不再程序化重绘签筒。',
    '// 签筒画面使用 Qwen-Image 生成的高清签筒图（props/qiu_art.png，透明底，544×966，\n// 与 272:483 同比例），动画（俯身/摇摆/出签）在整图上做，不再程序化重绘签筒。')
rep('pages/QiuQian.ets',
    '// 弹出签素材：直接从求签素材裁出的「筒内同款」单签（13×100 原图，\n// 红漆身 #ff0000 + 金竖高光，scripts/crop-qiu-stick.py 生成）',
    '// 弹出签素材：红漆身+金冠头单签程序化高清重绘（28×216 原图，scripts/gen-qiu-stick.py）')
rep('pages/QiuQian.ets',
    '/** 求签舞台画面：直接使用用户提供的签筒素材（props/qiu_art.png，透明底）。',
    '/** 求签舞台画面：使用高清签筒素材（props/qiu_art.png，透明底，544×966）。')
rep('pages/QiuQian.ets',
    '  *  （props/qiu_stick_pick.png，13×100，红漆身+金竖高光），非程序化重绘 */',
    '  *  （props/qiu_stick_pick.png，28×216，程序化高清重绘）*/')

# ── 10. MuyuPage 素材注释 ──
rep('pages/MuyuPage.ets',
    '// 素材：props/muyu.png = 用户参考轮廓程序化上色（scripts/render-muyu-variants.py v2 描金）。',
    '// 素材：props/muyu.png = Qwen-Image 生成 + rembg 抠图（scripts/gen-muyu-v2.mjs / rembg-muyu-v2.py）。')

print('FAILED:' if FAIL else 'ALL OK')
for f in FAIL:
    print(' -', f)