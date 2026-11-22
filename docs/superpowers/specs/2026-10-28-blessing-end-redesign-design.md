# 祝福画面重设计 · 万灯结彩（方案二）设计稿

日期：2026-10-28　状态：已选定待实现
预览稿：`blessing-end-preview.html`（?v=3 单看方案二）

## 背景

祈福结束后的祝福画面（`pages/BlessingCard.ets`）现行版问题：
1. 受福人姓名只出现在祝福语正文开头，无视觉地位
2. 入场 1.1s 后画面基本静止，缺乏祝福气息

用户选定方案二「万灯结彩 · 喜庆民俗」，修正点：**「返回首页」不放主按钮同排，放下方小字**（与现行 App 两层按钮一致）。

## 数据来源（全部已有，无新数据流）

- 受福人：`viewModel.userName`（@StorageLink 'viewModel'）
- 祝福语：`viewModel.blessing`（模板已内嵌姓名；实现时 `indexOf(userName)` 定位姓名区间，逐字渲染时姓名二字金色高亮）
- 心愿：`viewModel.wish`（2026-10-29 新增，NameCard 许愿框内容随 `confirmWish` 写入；云端愿望墙照旧走 `CloudService.createWish`，本地仅会话态不进 PrayerRecord）
- 财神：`viewModel.activeDeity()`（name/direction）
- 磕头数：`viewModel.kowtowCount`

## 视觉结构（自上而下，Column 流式居中）

| 区块 | 内容 | 动效 |
|------|------|------|
| 顶栏 | ✦ 万灯结彩 · 福星高照 ✦（13px 金） | 入场淡入上移 |
| 财神徽章 | 🧧 北路财神 · 赵公明 坐镇（12px 米白.85） | 次序入场 |
| 大灯笼 | LanternView 96×104，福字 42px | 落下入场 + ±3.5° 悬摆（4.6s 交替循环） |
| 挂穗线 ×2 | 2×26 金线 | 随名牌入场 |
| 名牌 | 「受福之人」+ userName 34px 米白金字光 | scale 弹入 |
| 祝福面板 | **古书卷轴金榜**（2026-10-29 三改：加左右铜金卷轴杆——杆贴开卷边缘随 panelRevealWidth 同步从中缝滚向两侧，杆身横向渐变模拟圆柱光影、两端 #FFD700 金轴头；面板双线金框 = 外 2px 亮金 + 内 1px 暗金，预览稿已同步）+ 逐字蹦出祝福语（20px，姓名金色）+ **心愿区**（2026-10-29 四改：祝福语蹦完后接「心 之 所 愿」金字 label + 用户许愿框原文逐字蹦出，18px 浅金 #ffe9a0 于面板底 12.1 ✓，无心愿整段隐藏）+ 尾联「红灯高照 · 福运绵长」 | 开卷 = **裁剪容器宽度 30→322 动画**（首版 scaleX 近似被否——框体压扁、内容滞后；面板固定 322vp 零变形，文字在场随中缝露出，逐字蹦出与开卷叠加，与预览稿 clip-path inset 完全等效）；祝福语与心愿共用 visibleChars 计数顺序蹦出；逐字区按字数预留行高，开卷时框体已是最终尺寸 |
| 磕头徽章 | 🙏 诚心叩拜 N 次 · 心意已至 | 次序入场 |
| 按钮 | 「🙇 再拜一次」主按钮；「返回首页」下方 12px 小字 | 次序入场 |
| 常驻层 | 6 盏小灯笼上升（11-16s 循环，0.5-0.8 缩放，摇摆）+ 彩纸雨 10 片 + 烟花/金点（现有 ParticleCanvas） | **子组件 setInterval 循环**（2026-10-29 真机返工：首版「@State 数组元素 + animateTo iterations:-1」真机不生效——灯笼瞬移屏外整体消失，彩纸同理；改为 RisingLantern/ConfettiPiece 独立子组件 + 基础类型 @State + setInterval 手动循环，与 FloatingBlessing 同构的真机验证模式。摇摆保留 iterations:-1 作增强层，失败只是静止无灾难。**2026-10-29 三改：灯笼入场提前，delayMs 0~2800ms 错峰**——原 1000~9000ms 用户嫌首灯出现太晚） |

## 入场排期（AGC 点击完成时延预算内，按钮 ~1s 即可操作）

0ms 顶栏/徽章 → 150ms 烟花彩纸灯笼启动（灯笼首轮 delay 0~2800ms 错峰）→ 200ms 大灯笼落 → 500ms 名牌 → 750ms 金榜开卷（500ms）→ 800ms 起逐字（与开卷叠加）→ 1050ms 徽章+按钮（不等逐字）。

ArkTS 无 clip-path 动画，开卷用等效实现：面板固定 322vp，外层裁剪容器 `.clip(true)` 宽度 30→322 动画；文字在场随中缝露出，逐字蹦出与开卷叠加（预览稿同款时序）。左右卷轴杆 translate 跟随 panelRevealWidth 同步滚开。

## 再拜一次的姓名保留（2026-10-29 真机修复）

`repeatPrayer()` 原样调 `resetPrayer()` 会清空 userName —— repeat 模式跳过 NameCard，重拜完成后 `getBlessing(id, '')` 把模板【祈福者】替换成空串、名牌回退「善信」，与输入框内容不吻合。修复：再拜前暂存姓名/选神/心愿，reset 后 `confirmName(name)` + `selectDeity(deity)` + `confirmWish(wish)` 恢复；祝福语由 onAnimationComplete 重新随机生成（每次祈福换一条，符合原设计）。

## 新组件

1. `components/LanternView.ets` — LanternView 纯灯笼造型（上盖/红底金字灯身/下盖/可选流苏）+ RisingLantern 上升宫灯（子组件 setInterval 自驱循环）
2. `components/ConfettiRain.ets` — ConfettiPiece 单片彩纸（setInterval 循环）×10；父组件 `if(isActive)` 挂载（激活时才 aboutToAppear 启动动画）
3. 古书卷轴杆为 BlessingCard 内 @Builder（ScrollRod），不单独成文件

## 对比度（已按 WCAG 规范实测）

米白 #fdf6e3 于红底 7.49 ✓；金字 #FFD700 于红底 5.76 ✓；小字均用 rgba(253,246,227,.85)=5.73 ✓；灯身福字米白实色于 #c0392b 5.04 ✓。

## 保留不动

- 返回首页/再拜一次的导航与音频逻辑（resetPrayer / stopBgm / router.clear）
- FIREWORK/GOLD 粒子层、背景红渐变（色值更新为预览稿暖红 #b82333→#580e15）
- PrayerCard 跳转链路、还愿模式分支（不经过本页）

## 验收

- hvigor debug 构建通过
- 浏览器预览稿与 ArkTS 实现布局一致（预览稿已过几何审计：无越界/居中/按钮两行）
