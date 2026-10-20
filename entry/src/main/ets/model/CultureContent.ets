// entry/src/main/ets/model/CultureContent.ets
// 内容增强：每日求签（36 签）、财神文化百科、许愿快捷模板、祈福文化栏目。
// 全部为静态内容数据，纯本地，无云端依赖。审核 3.5 项「功能不足」的应对。

/** 签的吉凶等级 */
export enum SignLevel {
  TOP = '上上签',      // 金
  GOOD = '上吉签',     // 绿
  MID_GOOD = '中吉签', // 蓝
  MID = '中平签',      // 灰
  LOW = '下签'         // 红
}

/** 吉凶等级 → 徽章实色（金=上上、绿=上吉、蓝=中吉、灰=中平、红=下）。
 *  作为徽章底色时，深墨 #1a1a0a 文字在其上 ≥4.5:1（7.39/8.35/5.07/6.24/5.03）。
 *  放在模型层而非页面层：卡片 UI 跑在独立渲染进程，不能 import 页面文件，
 *  颜色由 FormExtensionAbility 算成字符串塞进 FormBindingData。 */
export const LEVEL_COLOR: Record<string, string> = {
  '上上签': '#d4a017',
  '上吉签': '#2ecc71',
  '中吉签': '#3a8fd4',
  '中平签': '#9a9a9a',
  '下签': '#f0533f'
}

/** 吉凶等级 → #6F120E 覆层上的文字色（深红底小字 ≥4.5:1）。
 *  同一色无法同时满足「浅签纸」与「深红覆层」两处对比度，故按使用场景拆成三套：
 *  本套（深底文字）/ PAPER_LEVEL_COLOR（浅签纸大字）/ LEVEL_COLOR（徽章底色）。 */
export const LEVEL_TEXT_COLOR: Record<string, string> = {
  '上上签': '#d4a017',   // #6F120E 上 5.00
  '上吉签': '#2ecc71',   // 5.65
  '中吉签': '#5cb9f0',   // 5.46
  '中平签': '#afafaf',   // 5.41
  '下签': '#ff8a7c'     // #6F120E 5.20 / 金 tint 速览卡 4.73（#ff7563 在 tint 上仅 4.11 ✗）
}

/** 吉凶等级 → 浅签纸 #f5e6c8 上的大字色（34sp 大字 ≥3:1）。 */
export const PAPER_LEVEL_COLOR: Record<string, string> = {
  '上上签': '#c01717',   // 5.05
  '上吉签': '#d83a2e',   // 3.73
  '中吉签': '#b74f26',   // 4.10
  '中平签': '#a9783f',   // 3.13
  '下签': '#6a7077'     // 4.06
}

/** 等级吉凶序（越小越吉），用于「今日最吉签」比较 */
export const LEVEL_RANK: Record<string, number> = {
  '上上签': 0,
  '上吉签': 1,
  '中吉签': 2,
  '中平签': 3,
  '下签': 4
}

/** 签运速览：由签的等级 + 序号确定性推导的补充解读（无需为 36 签各写一份文案） */
export interface SignInsight {
  levelBrief: string   // 等级一句话解读
  score: number        // 财运指数 0-100
  luckyDir: string     // 幸运方位
  luckyNum: number     // 幸运数字
  luckyTile: string    // 旺财吉物
  dos: string          // 宜
  donts: string        // 忌
}

const LEVEL_BRIEF: Record<string, string> = {
  '上上签': '百事顺遂，财运冲天，宜乘胜追击',
  '上吉签': '运势上扬，稳中有进，宜顺势而为',
  '中吉签': '平顺偏吉，小有波折，结局向好',
  '中平签': '四平八稳，守成无忧，宜见好就收',
  '下签': '气势偏弱，宜守不宜攻，避开锋芒'
}

const LEVEL_SCORE: Record<string, number> = {
  '上上签': 95,
  '上吉签': 85,
  '中吉签': 72,
  '中平签': 55,
  '下签': 32
}

const LEVEL_DOS: Record<string, string> = {
  '上上签': '主动出击 · 抢先机 · 谋大利',
  '上吉签': '顺势加码 · 稳扎稳打',
  '中吉签': '耐心等待 · 中局发力',
  '中平签': '稳守为主 · 见好就收',
  '下签': '量力而行 · 稳字当头'
}

const LEVEL_DONTS: Record<string, string> = {
  '上上签': '犹豫失机 · 过度保守',
  '上吉签': '贪大求全 · 恋战不休',
  '中吉签': '急躁冒进 · 频繁换打法',
  '中平签': '顺势而为 · 平心静气',
  '下签': '见好就收 · 及时止损'
}

const DIR_TABLE: string[] = ['正东', '东南', '正南', '西南', '正西', '西北', '正北', '东北']
const LUCKY_ITEM_TABLE: string[] = ['元宝', '铜钱', '聚宝盆', '金如意', '玉貔貅']

/** 由签确定性推导签运速览（同一签结果恒定，便于复看一致） */
export function signInsightOf(sign: SignEntry): SignInsight {
  const base: number = LEVEL_SCORE[sign.level]
  const jitter: number = (sign.id % 5) - 2
  return {
    levelBrief: LEVEL_BRIEF[sign.level],
    score: Math.max(10, Math.min(99, base + jitter)),
    luckyDir: DIR_TABLE[(sign.id * 3 + LEVEL_RANK[sign.level]) % DIR_TABLE.length],
    luckyNum: (sign.id * 7) % 9 + 1,
    luckyTile: LUCKY_ITEM_TABLE[sign.id % LUCKY_ITEM_TABLE.length],
    dos: LEVEL_DOS[sign.level],
    donts: LEVEL_DONTS[sign.level]
  }
}

/** 确定性每日签：同一天全用户同签（卡片默认展示 / 今日无记录时的兜底） */
export function dailySignOfToday(): SignEntry {
  const now = new Date()
  const startOfYear = new Date(now.getFullYear(), 0, 1)
  const dayOfYear = Math.floor((now.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24)) + 1
  return SIGN_TABLE[dayOfYear % SIGN_TABLE.length]
}

/** 每日求签条目 */
export interface SignEntry {
  id: number          // 1-36
  level: SignLevel    // 吉凶等级
  title: string       // 四字签名
  poem: string        // 签诗（两句）
  interpretation: string // 解签（财运/财运/事业）
  advice: string      // 行事建议
}

/** 求签记录条目（揭晓即自动记入，存本机 preferences，保留最近 100 条） */
export interface QiuRecord {
  recId: string       // 记录唯一 id（时间戳+随机）
  ts: number          // 求签时间戳
  sign: SignEntry     // 完整签快照（可回看签诗/解签/建议）
}

/** 财神百科条目 */
export interface DeityEntry {
  id: number            // 与 FIVE_DEITIES.id 一致
  name: string          // 财神名
  title: string         // 神职封号
  icon: string          // 图标
  direction: string     // 方位
  story: string         // 来历传说
  domain: string        // 掌管领域
  worship: string       // 祭拜要点
  tile: string          // 旺财吉物
}

/** 文化栏目短文 */
export interface CultureArticle {
  id: string
  title: string
  icon: string
  content: string
}

/** 许愿快捷模板（求财纳福短句） */
export const WISH_TEMPLATES: string[] = [
  '想啥来啥',
  '财源广进',
  '财运亨通',
  '财气长红',
  '缺啥来啥',
  '好运连连',
  '旗开得胜'
]

/** 每日求签 36 签：按日期轮换，一日一签 */
export const SIGN_TABLE: SignEntry[] = [
  // ── 上上签（4）──
  { id: 1, level: SignLevel.TOP, title: '龙行天下', poem: '金龙出海风云起，万里鹏程任翱翔', interpretation: '财气如虹，财运冲天。今日诸事顺遂，财星高照，宜大胆出手、乘胜追击。', advice: '该出手时就出手，切勿犹豫；乘胜追击，一鼓作气。' },
  { id: 2, level: SignLevel.TOP, title: '五福临门', poem: '福星高照门庭旺，五路财神入梦来', interpretation: '百事顺心，八方来财。今日不仅财运亨通，事业生活亦多贵人相助。', advice: '广结善缘，谦逊待人；见好即收，福报自长。' },
  { id: 3, level: SignLevel.TOP, title: '紫气东来', poem: '紫气东来盈满室，祥云瑞霭护君身', interpretation: '气运正盛，所向披靡。今日运势为全年高峰之一，宜把握重要决策。', advice: '静待时机，一举定局；稳中求进，大器晚成。' },
  { id: 4, level: SignLevel.TOP, title: '金榜题名', poem: '寒窗十载终不负，金榜题名天下知', interpretation: '付出终有回报，今日宜考试、签约、谈合作，皆大有可为。', advice: '厚积薄发，一鸣惊人；功成之日，勿忘初心。' },
  // ── 上吉签（6）──
  { id: 5, level: SignLevel.GOOD, title: '顺水行舟', poem: '顺水行舟千帆过，乘风破浪正当时', interpretation: '运势上扬，事半功倍。今日求财财气平稳偏旺，财运渐进。', advice: '顺势而为，不逆不抢；稳扎稳打，自有进账。' },
  { id: 6, level: SignLevel.GOOD, title: '锦上添花', poem: '锦上添花花更艳，春风得意马蹄轻', interpretation: '已有之利将更上一层，今日适合加大投入、拓展人脉。', advice: '趁势加码，小试牛刀；人情往来，多为加分。' },
  { id: 7, level: SignLevel.GOOD, title: '鸿运当头', poem: '鸿运当头花正发，青云直上不须愁', interpretation: '今日运势上佳，求财易有收获，财运有意外之喜。', advice: '把握先机，速战速决；见好就收，落袋为安。' },
  { id: 8, level: SignLevel.GOOD, title: '鱼跃龙门', poem: '鱼跃龙门腾空起，一朝风云际会时', interpretation: '瓶颈将破，转机将至。今日宜尝试新思路、新方法。', advice: '破旧立新，敢想敢干；贵人相助，更上层楼。' },
  { id: 9, level: SignLevel.GOOD, title: '春暖花开', poem: '春暖花开香满径，蜂飞蝶舞自怡然', interpretation: '运势回暖，心情舒畅。今日人际和谐，贵人相处愉快，财运稳中向好。', advice: '和气生财，广结善缘；随缘而安，静待花开。' },
  { id: 10, level: SignLevel.GOOD, title: '万事亨通', poem: '万事亨通皆顺意，四方通达乐逍遥', interpretation: '诸事皆宜，无往不利。今日办事顺利，财运财气俱佳。', advice: '宜行大事，宜赴约谈；日行一善，福报绵长。' },
  // ── 中吉签（10）──
  { id: 11, level: SignLevel.MID_GOOD, title: '云开见日', poem: '云开雾散见晴日，柳暗花明又一村', interpretation: '前路渐明，转机在望。今日虽有小波折，结局向好。', advice: '再坚持一刻，转机即现；勿因小挫而乱阵脚。' },
  { id: 12, level: SignLevel.MID_GOOD, title: '枯木逢春', poem: '枯木逢春犹再发，人逢喜事精神爽', interpretation: '旧事可成，故人重逢。今日宜处理遗留问题、修复旧关系。', advice: '回访旧友，重启旧约；用心经营，必有所获。' },
  { id: 13, level: SignLevel.MID_GOOD, title: '步步高升', poem: '步步登高望远景，层层向上见新天', interpretation: '运势稳步上升，今日宜学习、积累、布局长远。', advice: '脚踏实地，步步为营；今日之勤，明日之果。' },
  { id: 14, level: SignLevel.MID_GOOD, title: '月朗星稀', poem: '月朗星稀清辉照，心地坦然福自来', interpretation: '心静则明，明则通。今日宜独处思考、复盘得失。', advice: '少说多做，静观其变；心平气和，自有答案。' },
  { id: 15, level: SignLevel.MID_GOOD, title: '一帆风顺', poem: '一帆风顺千里行，百事如意万年春', interpretation: '行运平稳，无大波折。今日求财小有盈余，办事顺遂。', advice: '按部就班，无需激进；细水长流，福泽绵长。' },
  { id: 16, level: SignLevel.MID_GOOD, title: '春风化雨', poem: '春风化雨润无声，润物细物含深情', interpretation: '以柔克刚，润物无声。今日宜以德服人、以静制动。', advice: '温柔处事，耐心待人；不争一时，赢在长远。' },
  { id: 17, level: SignLevel.MID_GOOD, title: '梅开二度', poem: '梅开二度香如故，老树新花别样红', interpretation: '旧事重启，别有天地。今日宜复盘再战，旧事或有转机。', advice: '不弃旧局，重燃信心；二度开花，香更胜初。' },
  { id: 18, level: SignLevel.MID_GOOD, title: '喜鹊登枝', poem: '喜鹊登枝报喜讯，好事临门不久时', interpretation: '佳音将至，喜事可期。今日宜关注消息、留意机会。', advice: '耳听八方，眼观六路；机会来时，当机立断。' },
  { id: 19, level: SignLevel.MID_GOOD, title: '金蝉脱壳', poem: '金蝉脱壳身轻健，留得青山任我行', interpretation: '断舍离而后生。今日宜放下包袱、轻装上阵。', advice: '弃车保帅，当断则断；留得青山，何愁柴烧。' },
  { id: 20, level: SignLevel.MID_GOOD, title: '水滴石穿', poem: '水滴石穿非一日，铁杵成针有恒心', interpretation: '坚持即胜利。今日宜持之以恒，勿因进度缓慢而放弃。', advice: '日拱一卒，功不唐捐；恒心所至，金石为开。' },
  // ── 中平签（10）──
  { id: 21, level: SignLevel.MID, title: '平湖秋月', poem: '平湖秋月空明净，波澜不惊自安然', interpretation: '运势平平，宜守不宜攻。今日求财不亏不赚，办事中规中矩。', advice: '以守为攻，不追不逃；平淡是真，安稳是福。' },
  { id: 22, level: SignLevel.MID, title: '守株待兔', poem: '守株待兔终非计，坐等天缘不如耕', interpretation: '被动等待难成事，今日宜主动出击、主动联络。', advice: '主动破局，勿空等待；行动之始，运之转也。' },
  { id: 23, level: SignLevel.MID, title: '邯郸学步', poem: '邯郸学步失其本，回归初心方得安', interpretation: '勿盲目模仿他人做法，今日宜回归自己的节奏。', advice: '做自己，走自己的路；适合的才是最好的。' },
  { id: 24, level: SignLevel.MID, title: '按部就班', poem: '按部就班循序进，不疾不徐自有成', interpretation: '一切照旧，平稳过渡。今日无大运亦无大厄，按计划行事即可。', advice: '维持节奏，勿生枝节；按部就班，水到渠成。' },
  { id: 25, level: SignLevel.MID, title: '雾里看花', poem: '雾里看花终隔纱，拨云见日待明时', interpretation: '当下局势不明，不宜轻举妄动。今日宜观望、调研、收集信息。', advice: '少下结论，多察实情；迷雾散尽，真相自现。' },
  { id: 26, level: SignLevel.MID, title: '塞翁失马', poem: '塞翁失马焉非福，祸福相依莫计较', interpretation: '得失不必挂怀，今日之失或为明日之得。', advice: '看淡输赢，放宽心态；祸福相依，泰然处之。' },
  { id: 27, level: SignLevel.MID, title: '三思后行', poem: '三思而后行无咎，谋定而动少悔恨', interpretation: '今日宜谨慎决策，求财宜慢不宜急，办事宜细不宜粗。', advice: '谋定而后动，动则有章；宁慢勿错，宁稳勿躁。' },
  { id: 28, level: SignLevel.MID, title: '安居乐业', poem: '安居乐业心常泰，淡泊明志福自长', interpretation: '平淡是真，安稳为福。今日不宜折腾，守成即胜。', advice: '守好本分，护好家人；平淡日子，也是福气。' },
  { id: 29, level: SignLevel.MID, title: '螳螂捕蝉', poem: '螳螂捕蝉雀在后，收敛锋芒免是非', interpretation: '谨防算计与口舌，今日宜低调行事、少露锋芒。', advice: '财不露白，话不伤人；退一步海阔天空。' },
  { id: 30, level: SignLevel.MID, title: '隔岸观火', poem: '隔岸观火莫轻入，置身事外自安闲', interpretation: '他人纠纷勿卷入，今日宜置身事外、独善其身。', advice: '不站队，不掺和；明哲保身，静观其变。' },
  // ── 下签（6）──
  { id: 31, level: SignLevel.LOW, title: '逆水行舟', poem: '逆水行舟用力撑，一篙松劲退千寻', interpretation: '今日运势低迷，求财易失手，宜小额试探、谨慎行事。', advice: '量力而行，小额为宜；稳住心态，明日再战。' },
  { id: 32, level: SignLevel.LOW, title: '风急浪高', poem: '风急浪高舟难渡，暂泊港湾待天晴', interpretation: '时运不济，不宜冒进。今日宜休整、避风头、养精蓄锐。', advice: '停一停，歇一歇；避过风头，再启征程。' },
  { id: 33, level: SignLevel.LOW, title: '明珠暗投', poem: '明珠暗投无人识，且待明主觅真珍', interpretation: '怀才不遇是暂时的，今日不宜强求认同，做好自己即可。', advice: '沉住气，蓄实力；真金不怕火炼，早晚发光。' },
  { id: 34, level: SignLevel.LOW, title: '节外生枝', poem: '节外生枝事多变，谨言慎行避是非', interpretation: '今日易生意外变故，求财宜防破耗，办事宜留余地。', advice: '话到嘴边留三分，事到临头留一手。' },
  { id: 35, level: SignLevel.LOW, title: '镜花水月', poem: '镜花水月空欢喜，脚踏实地见真章', interpretation: '表象虚浮，不宜轻信。今日投资、承诺宜再三核实。', advice: '不信画饼，不贪便宜；脚踏实地，方有真成。' },
  { id: 36, level: SignLevel.LOW, title: '雨后初霁', poem: '雨后初霁彩虹现，否极泰来不久时', interpretation: '最难的时刻将过，黎明就在眼前。今日虽有小挫，转机已近。', advice: '咬牙坚持，再走一程；风雨过后，必有彩虹。' }
]

/** 财神百科（与 FIVE_DEITIES 对齐） */
export const DEITY_ENCYCLOPEDIA: DeityEntry[] = [
  {
    id: 1, name: '王亥', title: '华商始祖 · 中路财神', icon: '🐂',
    direction: '中路',
    story: '王亥是商部落的首领，中国历史上第一个驯服野牛、造出牛车的人。他率族人赶着牛车与周边部落以物易物，开启了中国商业的先河——后世称呼做买卖的人为「商人」，正是源于商族。',
    domain: '商业开山、买卖兴隆、经营有道，利所有做生意、做买卖的人',
    worship: '供品宜用谷物牛肉；开业、谈大单前默念商祖之名；心诚则灵，忌无信',
    tile: '🐂 牛车通商'
  },
  {
    id: 2, name: '比干', title: '文财神 · 无心公正', icon: '⚖️',
    direction: '东路',
    story: '比干是商朝忠臣，《封神演义》中剖心以证忠义。他因「无心」而无私，办事公道、童叟无欺，被后世奉为文财神，专佑上班族、公务员等领正职薪水的人。',
    domain: '正财工资、升职加薪、公正待遇，利领薪水的上班族与公职人员',
    worship: '宜素果清茶；求升职加薪时心中默念所求职位；忌心术不正',
    tile: '💰 元宝'
  },
  {
    id: 3, name: '关羽', title: '武财神 · 义薄云天', icon: '⚔️',
    direction: '西路',
    story: '关二爷红面长髯、手使青龙偃月刀，被尊为「武圣」。他重信守义，明清商帮走南闯北皆奉为保护神，既能镇守门庭驱邪避恶，又能保佑合作顺利、财源广进。',
    domain: '诚信经营、合作共赢、镇宅守财，利创业者与合伙做生意的人',
    worship: '宜燃香献酒；签约、开张前拜之求「义」「信」二字；忌背信弃义',
    tile: '🪙 铜钱'
  },
  {
    id: 4, name: '柴荣', title: '君王财神 · 后周世宗', icon: '👑',
    direction: '南路',
    story: '柴荣是五代后周皇帝，少年时弃儒经商，深知民间疾苦。登基后大刀阔斧改革经济、毁佛铸钱以充实国库，被誉为「五代第一明君」。拜他，求的是破釜沉舟的魄力和做大做强的帝王之气。',
    domain: '宏图霸业、做大做强、破局翻身，利企业家与有大志向的人',
    worship: '宜先明志向而后拜，心中默念三年目标；忌小富即安',
    tile: '🧧 聚宝盆'
  },
  {
    id: 5, name: '赵公明', title: '正财神 · 玄坛真君', icon: '🐯',
    direction: '北路',
    story: '赵公明黑面骑黑虎、执铁鞭，统领招宝、纳珍、招财、利市四仙官，法力高强，被尊为华夏第一正财神。凡求八方之财、驱邪避灾者，皆可拜他。',
    domain: '八方之财、家宅安宁、驱邪避灾，利所有求财之人',
    worship: '宜用三牲果品、香烛元宝；初一十五上香最佳；心诚则灵，忌心术不正',
    tile: '🐯 黑虎镇财'
  }
]

/** 祈福文化栏目 */
export const CULTURE_ARTICLES: CultureArticle[] = [
  {
    id: 'incense_ritual', title: '上香礼仪', icon: '🪔',
    content: '上香前先净手，表示诚敬。三炷香代表「戒、定、慧」或「天、地、人」三才。插香时香须直立，香与香之间保持一指宽，谓之「香不过寸」。拜神时宜心无杂念，默念姓名与所求，忌喧哗嬉笑。'
  },
  {
    id: 'fortune_time', title: '求财时机', icon: '📅',
    content: '传统上，正月初五「迎财神」是一年求财最重要的日子，谓之「破五」——破除旧日晦气，迎接财神进门。日常求财则宜选逢五、逢十的吉日，或每日卯时（5-7 点）财气初升之时上香。'
  },
  {
    id: 'mahjong_culture', title: '财神祈福习俗', icon: '🧧',
    content: '民间素有「拜财神」之说：正月初五迎财神、初一十五上香，谓之「接财气」；上香前先净手净心，默念姓名与所求，谓之「诚则灵」。本应用取五路财神庇佑财运之意，祈福后出门求财，愿您财运亨通、日进斗金。'
  },
  {
    id: 'kowtow_meaning', title: '磕头祈福的讲究', icon: '🙏',
    content: '磕头又称「叩首」，一叩首表敬意，三叩首表诚心，九叩首表至诚。俗谚「磕得响，福到堂」，磕头时心中默念所愿，额头触地时屏息凝神，起身后双手合十谢神。虔诚叩拜，自有回响。'
  }
]
