# AGC 控制台提审前手动操作清单

> 用途：本版本提审前必须在华为 AppGallery Connect 控制台手动完成的核对/操作。
> 代码侧（ZIP、schema 定义、IAP 商品表）已在本地验证，控制台侧需人工同步。
> 日期：2026-10-20。版本：1.0.0（versionCode 1000001，见文末版本号核对）。

## 一、云函数 ZIP 重传（6 个）

本地已用 `node cloud/verify-zips.cjs` 校验通过（handler.js/myHandler、shared/、
agc-credential.json、cloud-server SDK、正斜杠路径、hostOS=Unix、无嵌套 zip）。
控制台「云函数」逐个覆盖上传：

| 函数名 | zip 路径 | 触发器 | 说明 |
|---|---|---|---|
| update-prayer-count | cloud/update-prayer-count/ | HTTP POST + AGC Auth | 还愿计数 |
| get-leaderboard | cloud/get-leaderboard/ | HTTP POST + AGC Auth | 祈福榜（脱敏，不返 uid） |
| wish-wall | cloud/wish-wall/ | HTTP POST + AGC Auth | 心愿墙 |
| game-record-backup | cloud/game-record-backup/ | HTTP POST + AGC Auth | 牌运记录备份 |
| donation-record | cloud/donation-record/ | HTTP POST + AGC Auth | 打赏记账 + 公益榜 |
| jieqian-unlock | cloud/jieqian-unlock/ | HTTP POST + AGC Auth | 解签解锁补单（qiu_extra 已下架，函数保留） |

运行时 Node.js 18、内存 256MB、超时 30s。上传后建议各跑一次 smoke（若保留本地验证）。

## 二、IAP 消耗型商品核对（10 个，2026-10-20 拆分）

客户端 `IPaymentService` 两组商品 = 本表；服务端 donation-record 白名单**只含打赏 tip_***（装扮不进公益榜）：

**打赏（tip_*，5 个 · 纯赠与 · 进公益榜）：**

| 商品 ID | 金额 | 用途 |
|---|---|---|
| tip_8 | ¥8 | 打赏 |
| tip_18_2 | ¥18 | 打赏 |
| tip_88_2 | ¥88 | 打赏 |
| tip_188 | ¥188 | 打赏 |
| tip_888 | ¥888 | 打赏 |

**装扮/陈设（decor_*，5 个 · 只解锁视觉 · 不进公益榜）：**

| 商品 ID | 金额 | 解锁摆件 |
|---|---|---|
| decor_8 | ¥8 | 灯样式（莲灯/琉璃灯）+ 陈设宫灯 |
| decor_18 | ¥18 | 香炉（三足炉/鎏金炉）+ 陈设金瓶 |
| decor_88 | ¥88 | 殿宇主题（金辉殿/夜殿）+ 陈设鲜花 |
| decor_188 | ¥188 | 陈设聚宝盆 |
| decor_888 | ¥888 | 殿宇主题 · 水晶殿（尊享） |

⚠️ decor_888 / decor_188 为本次拆出新生效的装扮商品，确认控制台已创建，
   否则财神殿水晶殿/聚宝盆解锁 `openPay` 会报 1001860007。
⚠️ qiu_extra（¥1 加求签次数）：按 2026-10-05 设计文档「暂时下架」决策 **保留商品不删除**——
    App 内已无购买入口，保留只为已购用户补单保护；勿删，删了也不影响当前版本。

## 三、Cloud DB schema 索引（新增 SignUnlock 索引）

`cloud/agc-clouddb-object-types-jieqian-unlock.json` 已补 indexes：**uid** 与 **purchaseToken**（各 ASC）。
在控制台对 SignUnlock 对象类型应用这两个索引（幂等查询 equalTo('purchaseToken') 与
按 uid 查解锁状态 equalTo('uid') 都需要，缺索引 Cloud DB 会报 3007007）。
Donation 表的 uid/purchaseToken/createdAt 索引已在（agc-clouddb-object-types-donation.json）。

## 四、清理测试数据

提审前清掉开发期造的数据，避免审核员看到脏数据：
- Donation / UserMerit（测试打赏记录与功德）
- Leaderboard（测试还愿榜）
- Wish（测试心愿）
- 各表 `uid` 形如 test123 / u1 / u4 等测试账号记录
（保留少量真实结构数据无碍，但测试账号昵称/金额应清干净。）

## 五、版本号核对 ✅

- `AppScope/app.json5`：**versionCode 1000001 / versionName 1.0.0**（已定，以此为准）
- `docs/review-notes-v1.0.0.md`：提审说明文档，已同步为 1.0.0 / 1000001

两处一致，可直接提交。HarmonyOS 以 app.json5 为准，审核员看到的版本由它决定。

## 六、隐私与合规（提审自检）

- [ ] 「我的」→「联系客服」入口存在，展示客服邮箱（提审要求 11.2）
- [ ] 应用内购买不绑定祈福效果：打赏 UI 明写「自愿赠与 · 不承诺任何效果」
- [ ] 打赏、装扮均不承诺任何祈福效力（迷信类红线）
- [ ] 排行榜不返回原始设备 ID（服务端脱敏 isMe）
- [ ] 云函数可被客户端用 `data` 字段调用（FunctionParams，非 params）
