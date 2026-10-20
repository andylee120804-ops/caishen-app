// entry/src/main/ets/model/PrayerTypes.ets

/** 祈福记录 */
export interface PrayerRecord {
  id: string          // UUID，由 @ohos.util.generateRandomUUID(true) 生成
  name: string        // 祈福者名字
  deityId: number     // 当日财神ID (1-5)
  blessing: string    // 祝福语
  kowtowCount: number // 磕头次数
  timestamp: number   // 祈福时间戳
}

/** 用户偏好 */
export interface UserPrefs {
  recentNames: string[]   // 最近5个名字
  totalPrayers: number    // 累计祈福次数
  lastPrayerDate: string  // 上次祈福日期 YYYY-MM-DD
  favoriteDeity: number   // 最常拜的财神ID
}

/** 财神信息 */
export interface DeityInfo {
  id: number
  name: string
  direction: string      // 方位
  features: string       // 特征描述
  color: string          // 代表色
  deityMeaning: string   // 财神寓意（赐财方向）
  lottieFile: string     // Lottie 动画文件名
  soundFile: string      // 专属音效
}

/** 五路财神数据 */
export const FIVE_DEITIES: DeityInfo[] = [
  {
    id: 1, name: '王亥', direction: '中路',
    features: '牛车·华商始祖', color: '#F0C419',
    deityMeaning: '商祖开路，牛转乾坤，通达八方',
    lottieFile: 'deities/wanghai.json',
    soundFile: 'deity_zhonglu.mp3'
  },
  {
    id: 2, name: '比干', direction: '东路',
    features: '文财神·无心公正', color: '#D98C2B',
    deityMeaning: '公道无私，正财稳进，童叟无欺',
    lottieFile: 'deities/bigan.json',
    soundFile: 'deity_donglu.mp3'
  },
  {
    id: 3, name: '关羽', direction: '西路',
    features: '武财神·青龙偃月', color: '#C0392B',
    deityMeaning: '重义守信，镇宅辟邪，合伙共赢',
    lottieFile: 'deities/guanyu.json',
    soundFile: 'deity_xilu.mp3'
  },
  {
    id: 4, name: '柴荣', direction: '南路',
    features: '君王财神·后周世宗', color: '#E8741E',
    deityMeaning: '帝王之气，破局开路，做大做强',
    lottieFile: 'deities/chairong.json',
    soundFile: 'deity_nanlu.mp3'
  },
  {
    id: 5, name: '赵公明', direction: '北路',
    features: '黑面·铁鞭·黑虎', color: '#8A5A1E',
    deityMeaning: '黑虎镇守，驱邪纳福，正财聚宝',
    lottieFile: 'deities/zhaogongming.json',
    soundFile: 'deity_beilu.mp3'
  }
]

/** 祈福流程阶段 */
export enum PrayerPhase {
  IDLE = 'idle',
  INPUT_NAME = 'inputName',
  ANIMATING = 'animating',
  BLESSING = 'blessing'
}

/** 动画阶段 */
export enum AnimStage {
  APPEAR = 'appear',       // 0-1.6s 五神现身（自动）
  INCENSE = 'incense',     // 1.6-4s 进香（自动）
  KOWTOW = 'kowtow',       // 交互阶段：用户按按钮磕头，不自动推进
  BLESSING = 'blessing'    // 完成祈福后五神齐放金光（自动 1.5s）
}

/** 默认磕头次数（达成后解锁"完成祈福"） */
export const DEFAULT_KOWTOW_COUNT = 3

/** 磕头时飘出的祝福语池，围绕拜财神求财纳福，主打狠狠说喜话！循环取用 */
export const BLESSING_PHRASES: string[] = [
  // ── 财神赐福类 ──
  '财神保佑！',
  '财神到！',
  '财神附体！',
  '财神眷顾！',
  '财神开恩！',
  '财神送财！',
  '财神点化！',
  '五路财神到！',
  '财星高照！',
  '财神引路！',
  '财气东来！',
  '紫气东来！',
  // ── 财运亨通类 ──
  '财运亨通！',
  '财运长红！',
  '财源广进！',
  '财源滚滚！',
  '八方来财！',
  '四方进财！',
  '日进斗金！',
  '金玉满堂！',
  '金银满屋！',
  '堆金积玉！',
  '招财进宝！',
  '纳福迎祥！',
  '富贵双全！',
  '一本万利！',
  '点石成金！',
  '腰缠万贯！',
  // ── 求财得财类 ──
  '有求必应！',
  '求财得财！',
  '心诚则灵！',
  '有愿必成！',
  '想啥来啥！',
  '要啥有啥！',
  '缺啥来啥！',
  '吉星高照！',
  '福星临门！',
  '天降横财！',
  '喜从天降！',
  '时来运转！',
  // ── 生意事业类 ──
  '生意兴隆！',
  '财源茂盛！',
  '开门大吉！',
  '开业大吉！',
  '客似云来！',
  '买卖顺遂！',
  '订单不断！',
  '升职加薪！',
  '事业顺遂！',
  '步步高升！',
  '名利双收！',
  '财随运转！',
  // ── 气势类 ──
  '谁也拦不住！',
  '所向披靡！',
  '势如破竹！',
  '旗开得胜！',
  '独占鳌头！',
  '一骑绝尘！',
  '春风得意！',
  '旺到飞起！',
  '鸿运当头！',
  '好运连连！',
  '福气满满！',
  '福寿康宁！',
]

/** 还愿模式（磕头还愿）飘出的答谢语池：表达完成心愿的轻松与祝福（中性化，2026-10-20） */
export const FULFILL_PHRASES: string[] = [
  '谢神恩！',
  '如愿以偿！',
  '有求必应！',
  '心诚则灵！',
  '神恩浩荡！',
  '所愿皆成！',
  '愿望成真！',
  '善愿皆圆！',
  '福泽绵长！',
  '心意已了！',
  '福气常伴！',
  '心诚福至！',
  '时来运转！',
  '财缘绵延！',
  '往后顺遂！',
  '一诺千金！',
  '福缘续延！',
  '愿已酬神！',
]