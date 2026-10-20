# 桌面服务卡片设计：每日求签 + 敲木鱼 + 今日主麻神

> 日期：2026-10-02
> 状态：设计已确认（含 review 修订），待实现计划
> 背景：用户希望把 App 功能以「服务卡片」形式放到桌面，实现快速抽签 / 敲木鱼，并引导解签付费。HarmonyOS 服务卡片 = FormExtensionAbility（数据源）+ ArkTS 卡片 UI + form_config.json 声明。

## 1. 目标与范围

新增**三张桌面卡片**（用户可在桌面长按 → 服务卡片里分别添加不同卡片）：

| 卡片 | 尺寸 | 核心交互 |
|---|---|---|
| 每日求签 | 2×2 + 2×4 两档 | 点「抽一签」本地真抽签；点「解签」跳 App 付费解签；点「签录」跳求签页 |
| 敲木鱼 | 2×2（仅此一档） | 点卡片敲一下 → 功德计数 +1（与 App 同一计数）；点「木鱼」跳木鱼页 |
| 今日主麻神 | 2×2（仅此一档） | 静态展示今日主神（姓名/方位/麻将寓意）；点整卡跳祈福页拜主神 |

**关键产品约束**：解签文（interpretation/advice）是付费内容，卡片**绝不展示**，只展示等级 + 签名 + 签诗（在 App 里签诗本免费）。

**不做**：卡片摇晃抽签（卡片无传感器权限，审核也禁后台占传感器）；按次付费；服务端票据校验；主麻神卡做 2×4。

## 2. 架构概览

```
┌─ 卡片渲染服务进程（系统，非本应用、非桌面）──────────────┐
│  SignCard2x2 / SignCard2x4 / MuyuCard2x2 / DeityCard2x2  │
│  纯展示：只渲染 FormBindingData 字段 + postCardAction     │
└───────────┬──────────────────────────────▲───────────────┘
            │ postCardAction message/router │ updateForm
┌───────────▼──────────────────────────────┴───────────────┐
│  FormExtensionAbility（WidgetFormAbility）                │
│  ⚠️ 跑在独立进程 luck.happy.huawei:form（bm dump 实测）    │
│  每次回调可能是新实例 → 每次 new VM + initialize() 读盘    │
└───────────┬──────────────────────────────▲───────────────┘
            │ 读/写 preferences（同一份文件，│ 读
            │ 但各自有进程内缓存！）        │
┌───────────▼──────────────────────────────┴───────────────┐
│  App 主进程：EntryAbility + 各 ViewModel（内存态）        │
│  回前台 reload() 重读盘；变动后经 formId 表推卡片         │
└──────────────────────────────────────────────────────────┘
深链 router → EntryAbility（onCreate / onNewWant）→ AppStorage flag（@Watch）→ MainTabs 切 Tab
```

- **一个 FormExtensionAbility 服务四张卡片**：`onAddForm`/`onUpdateForm`/`onFormEvent`/`onRemoveForm` 里按 `formName`（`sign_2x2` / `sign_2x4` / `muyu_2x2` / `deity_2x2`）分发（⚠️ 删除回调是 `onRemoveForm`，不是 `onDeleteForm`）。
- 卡片 UI 是**纯展示** ArkTS（只渲染 FormBindingData 注入的字段 + `postCardAction` 发交互），不放任何逻辑。

### 2.1 进程模型（决定所有同步设计，务必按此实现）

1. **卡片 UI 跑在系统「卡片渲染服务」进程**，既不在 App 进程也不在桌面进程。因此卡片**看不到** App 内存、AppStorage、Context，一切数据只能由扩展经 `FormBindingData` 注入。
2. ⚠️ **FormExtensionAbility 跑在独立进程 `luck.happy.huawei:form`** —— `bm dump` 实测，系统自动分配，**不是** App 主进程，也不是卡片渲染服务进程。且**每次回调都可能是新实例**（进程随时被回收重建）。所以：
   - ❌ 不能把 ViewModel 缓存在扩展的成员变量里当单例；
   - ✅ 每次事件都 `new XxxViewModel()` + `await initialize(context)` 重新读盘，写完立即 `flush`；
   - ✅ **`preferences` 有进程内缓存**，跨进程读不到对方刚写的值：每次读盘前必须先
     `await preferences.removePreferencesFromCache(context, PREF_NAME)` 再 `getPreferences`，
     否则会把 App 进程刚写入的计数/额度**回滚**（详见 §8）。
3. **一致性靠「清缓存重读盘 + 写完 flush + App 回前台 reload」**，不存在"同进程天然一致"这种便宜事（详见 §8）。
4. ⚠️ **扩展进程的 `console.*` / `hilog.*` 都抓不到**（实测 hilog 141MB 里 0 条命中）。调试期改用**落盘探针**：把事件内容写进 preferences，从 PC 侧 `hdc shell cat` 读取（见 §13）。

## 3. 文件清单

### 新增

| 文件 | 作用 |
|---|---|
| `entry/src/main/ets/formability/WidgetFormAbility.ets` | 唯一数据源：抽签/敲木鱼/主神、读写额度/功德、生成/刷新 FormBindingData、**串行化写** |
| `entry/src/main/ets/formability/FormIdStore.ets` | **formId 注册表**：`onAddForm` 写 `formId→formName`、`onRemoveForm` 移除，供 App 侧按 id 逐个刷新（见 §7） |
| `entry/src/main/ets/formability/WidgetData.ets` | 扩展与 App 共用的绑定数据构造器（避免两份逻辑）；未知 formName 返回 null 拒绝刷新 |
| `entry/src/main/resources/base/media/muyu.png`、`deity_1~5.png` | 卡片图片（由 rawfile 512×512 缩放至 192×192），走 `$r('app.media.*')`，见 §4.5 |
| `entry/src/main/ets/widget/pages/SignCard2x2.ets` | 求签小卡 UI |
| `entry/src/main/ets/widget/pages/SignCard2x4.ets` | 求签中卡 UI |
| `entry/src/main/ets/widget/pages/MuyuCard2x2.ets` | 木鱼小卡 UI |
| `entry/src/main/ets/widget/pages/DeityCard2x2.ets` | 主麻神小卡 UI |
| `entry/src/main/ets/service/FormSyncService.ets` | App 侧：抽签/敲木鱼后 + 回前台，遍历 `FormIdStore` 把最新状态推到所有卡片 |
| `entry/src/main/resources/base/profile/form_config.json` | 四张卡片的尺寸/名称/刷新策略声明 |

### 修改

| 文件 | 改动 |
|---|---|
| `entry/src/main/module.json5` | 新增 `extensionAbilities`（`type:"form"` + `label`/`description` + metadata 指向 form_config）；当前文件无任何 extensionAbilities / metadata |
| `entry/src/main/ets/entryability/EntryAbility.ets` | `onCreate(want)` 当前声明了 want 但**未解析**，需补解析；新增 `onNewWant(want)`；`onForeground` 里 await reload VM 后再推卡片 |
| `entry/src/main/ets/pages/MainTabs.ets` | `@StorageLink('pendingRoute') + @Watch` 切 Tab（热启动必须靠 @Watch，只靠 aboutToAppear 读一次无效）；目标 Tab 被用户关闭时的降级 |
| `entry/src/main/ets/viewmodels/QiuQianViewModel.ets` | 新增 `reload()`（重读额度/签录）、`bestToday()`（今日最吉签） |
| `entry/src/main/ets/viewmodels/MuyuViewModel.ets` | 新增 `reload()`（重读今日/累计计数）、`knockAsync()`（串行化 knock，见 §5.2） |
| `entry/src/main/ets/model/CultureContent.ets` | **把 `LEVEL_COLOR` 从 `pages/QiuQian.ets` 抽到这里并 export**（卡片不能 import 页面文件，见 §5.1） |
| `entry/src/main/ets/pages/QiuQian.ets` | 深链到站后自动打开解签覆层（`@Watch` 触发）；本地抽签成功后调 `FormSyncService` |
| `entry/src/main/ets/pages/MuyuPage.ets` | 敲击成功后调 `FormSyncService` |
| `entry/src/main/resources/base/element/string.json` | 卡片名/描述 + extension 的 `label`/`description` 文案（现仅 4 条） |

### 待确认引用

- `docs/common/wcag-contrast.md`：**该文件不存在**（仅 docs 中几处提及）。实现前先补建，或把 §9/§12 的引用改到实际位置。

## 4. 卡片 UI

沿用现有深底 `#1a1a0a` 与金/米色调。文字对比度遵守 WCAG 规则（正文米色 alpha≥0.5 / 金色≥0.6，等级徽章用 `LEVEL_COLOR` 实色）。

### 4.0 卡片页硬性样板（四张卡都要）

ArkTS 卡片页必须用 `LocalStorage`，且**禁止** `setTimeout` / `setInterval`（卡片不支持）、禁止非白名单 API、禁止 import 任何页面/含 UI 依赖的文件。

⚠️ **四张卡片页会被打进同一个 `widgets.abc`**：`LocalStorage` 变量名在 bundle 内是全局作用域，四张卡都用 `storage` 会报 `Cannot redeclare block-scoped variable`，必须各自唯一（build 已验证）。

```ts
let signCard2x2Storage: LocalStorage = new LocalStorage()
@Entry(signCard2x2Storage)
@Component
struct SignCard2x2 {
  @LocalStorageProp('level') level: string = ''
  @LocalStorageProp('levelColor') levelColor: string = '#9a9a9a'
  // ...只渲染，不做逻辑
  build() { /* Text / Row / Column / Stack */ }
}
```

> 卡片不支持断点调试与 Hot Reload：逻辑全部下沉到扩展，先在 App 内自测逻辑再套卡片壳（见 §12）。

### 4.1 每日求签 2×2

```
┌───────────────────┐
│ 🎋 每日求签 · 第X签 │
│     上上签(金)      │
│     金榜题名        │
│  [ 抽一签 ] [ 解签 ] │
└───────────────────┘
```
- 「抽一签」→ `message { msgAction:'draw', form:'sign_2x2' }`（本地刷新，不出 App）
- 「解签」→ `router { route:'qiuqian', open:'unlock' }`
- **不显示签诗**（2×2 实际约 180×180 vp，塞不下；完整签诗留给 2×4）。用户明确要求小卡"简单高效"，只保留 标题 + 等级徽章 + 签名 + 两个按钮。
- 两个按钮用 `layoutWeight(1)` 等宽平分 + 固定高度，避免文案长度变化导致溢出。

### 4.2 每日求签 2×4

```
┌─────────────────────────────────┐
│ 🎋 每日求签 · 第X签               │
│  [上上签] 金榜题名                │
│  寒窗十载终不负，金榜题名天下知    │
│  今日已抽 1/3                     │
│                                  │
│  [   再抽一签   ] [   解签   ]    │
└─────────────────────────────────┘
```
- 信息更全：完整签诗 + 剩余额度提示；底部两个等宽按钮（**再抽一签 / 解签**）。
- **不提供「签录」入口**（用户要求）：签录在 App 内查看，卡片只留两个动作。
- ⚠️ **布局坑**：早期版本底部按钮被挤出卡片边框。修法是内容自上而下排，**中间插一个 `layoutWeight(1)` 的弹性占位**，按钮组就永远落在卡片内边距之上。不要靠 `justifyContent(Center)` + 固定 margin 排。

### 4.3 敲木鱼 2×2

```
┌───────────────────┐
│      [木鱼图]       │
│  今日功德 12        │
│  累计功德 3456      │
└───────────────────┘
```
- 整卡点击 → `message { msgAction:'knock', form:'muyu_2x2' }` → 今日+1、累计+1（与 App 同一计数）
- 右上角小「木鱼」→ `router { route:'muyu' }`
- 不显示「点我敲一下 · 咚」提示文案（用户要求精简），图片本身即点击暗示。
- 反馈动效：卡片不支持 `setTimeout`，只能用受限的属性动画/显式动画（动态卡片才支持）。

### 4.4 今日主麻神 2×2

```
┌───────────────────┐
│     [主神图]        │
│    赵公明           │
│    中路             │
│   坐镇牌局 保护手气  │
└───────────────────┘
```
- 纯静态（无 `message` 交互），主神名金色 `#f9ca24`、方位/寓意米色小字（deity.color 里赵公明 `#1a1a0a` 极暗，不用于文字）。
- 整卡点击 → `router { route:'blessing' }`（跳祈福首页拜主神）。

### 4.5 卡片图片方案（实测结论）

⚠️ **不要用官方「formImages + memory://」的 fd 方案**。它要求扩展进程把 `RawFileDescriptor` 跨进程传给卡片渲染服务，真机上**静默失败**（图片全白，无任何报错）。

✅ **用 media 资源 + `$r()`**：把图放进 `entry/src/main/resources/base/media/`，卡片 UI 直接引用。

```ts
Image($r('app.media.muyu'))        // 木鱼卡
Image($r('app.media.deity_1'))     // 麻神卡，按 deityId 分支选 1~5（$r 不能动态拼接）
```

- 图片随**卡片包**一起加载，不依赖 fd 传递，也不用每次 `updateForm` 重传。
- 扩展只下发 `deityId`，由卡片自己按 id 选图。
- 现有素材：木鱼 `rawfile/props/muyu.png`、五神 `rawfile/deities/1~5.png`（均 512×512）。
  已用 PIL 缩到 192×192 生成 `base/media/muyu.png` / `deity_1~5.png`（23–58KB），卡片上显示 66–74vp 足够。
- 命名规范：media 文件名只能用小写字母/数字/下划线。

## 5. 数据层与抽取/敲击/主神规则

### 5.0 两条实现红线

1. **卡片拿不到 `LEVEL_COLOR`**：它当前定义在 `pages/QiuQian.ets:21` 且**未 export**，而该文件 import 了传感器/动画等 UI 依赖，卡片（独立渲染进程）**绝不能 import 页面文件**。
   → 颜色由**扩展侧算好、以字符串塞进 FormBindingData**（`levelColor: '#d4a017'`），卡片零 import；同时把 `LEVEL_COLOR` 抽到 `model/CultureContent.ets` 并 export 供 App 复用。
2. **构造 FormBindingData 必须手工裁剪字段**：`addRecord(sign)` 存的是**完整 `SignEntry`（含 interpretation / advice）**。只允许放 `{ id, level, title, poem, levelColor, used, remaining }`，**严禁** `JSON.stringify(record)` 或整签透传。

### 5.1 求签

- **默认展示（今日未抽）**：确定性每日签 `SIGN_TABLE[dayOfYear % 36]`（全用户同一天同签）。
- **抽过后**：展示今日已抽中最吉利签 —— `QiuQianViewModel.bestToday()`（新增）：
  - 按 `QiuRecord.sign.level` 排序，等级序 `上上 > 上吉 > 中吉 > 中平 > 下`（`SignLevel` 值即中文：`'上上签'`…）；
  - 同级取最新（`QiuRecord.ts` 最大者）；
  - **按 `ts` 的本地日期过滤"今日"**，不能用 `Date.now()` 直接比（`QiuRecord = { recId, ts, sign }`）；
  - 容错：`daily.count > 0` 但 `records` 为空（App 动画中途退出会"扣了额度没记录"）时回退到默认每日签。
- **卡片抽签 = 真抽签**：`onFormEvent` 收到 draw → 复用 `QiuQianViewModel`：
  1. `canDraw()` 判断额度（用已 export 的 `MAX_DAILY_QIU`，别硬编码 3），满 3 则更新卡片为「已满 3 签」态
  2. `sign = SIGN_TABLE[floor(random*36)]`
  3. `consumeDraw()` 扣额度 + `addRecord(sign)` 写签录（同一份 `mashen_qiuqian_prefs`，键 `qiuDaily`/`qiuRecords`）
  4. `updateForm` 刷新卡片（新签 + 剩余额度）
- 等级→颜色：上上 `#d4a017`、上吉 `#2ecc71`、中吉 `#3a8fd4`、中平 `#9a9a9a`、下 `#f0533f`（由扩展注入，见 §5.0）。

### 5.2 敲木鱼

- 复用 `MuyuViewModel`：跨日清零今日、今日+1、累计+1，写 `mashen_muyu_prefs`（键 `todayDate`/`todayCount`/`totalCount`）。
- **必须串行化**：敲木鱼天然连点，两个 `onFormEvent` 并发 → 各自 new VM 读盘 +1 + flush = 经典 read-modify-write **必现丢计数**（不是"极低概率"）。
  → 扩展内用 Promise 串行队列包裹，或新增 `MuyuViewModel.knockAsync()`：`await` 化的 `get → +1 → put → flush`，由扩展侧排队调用。
- 卡片与 App 共用同一计数，敲一下两处会话一致（以盘为准）。

### 5.3 今日主麻神

- 复用 `DeityRotator.getTodayDeity()`（已存在，`((dayOfYear-1) % 5) + 1` 确定性轮换），读 `DeityInfo` 的 name/direction/features/mahjongMeaning。
- 纯只读、无状态，无持久化，跨天自动变化；onAddForm/onUpdateForm 时现算。

## 6. 交互路由

### 6.1 卡片内（message，不出 App）

```ts
// 求签
postCardAction(this, { action: 'message', params: { msgAction: 'draw', form: 'sign_2x2' } })
// 木鱼
postCardAction(this, { action: 'message', params: { msgAction: 'knock', form: 'muyu_2x2' } })
```

⚠️⚠️ **两个实测踩坑（"点击没反应"的真正根因）**：

1. **`params` 必须是对象，不能是 `JSON.stringify(...)` 字符串**。传字符串会被系统再包一层，`onFormEvent` 里 `JSON.parse` 得到的是 string 而非 object。
2. **自定义动作的键名绝不能叫 `action`**。系统会把 `postCardAction` 的 `action:'message'` 与 `params` 内容**合并进同一个 JSON 对象**，同名键后者覆盖前者。实测 `onFormEvent` 收到的 message 是：

   ```json
   {"action":"draw","form":"sign_2x2",
    "params":{"action":"draw","form":"sign_2x2"},
    "action":"message"}          ← action 重复，'message' 覆盖 'draw'
   ```

   结果 `msg.action` 恒等于 `'message'`，动作分支永远不进 → 表现为"点击完全没反应"。

   ✅ 统一用 **`msgAction`** 作自定义动作键；扩展侧优先解析 `params` 内层，再回退外层（`form` 键不与系统冲突，可直接用；实测能正确取到）。

- 主麻神：无 message 交互。

### 6.2 跳 App（router + 深链）

- `postCardAction({ action:'router', abilityName:'EntryAbility', params: { route:'qiuqian', open:'unlock' } })`（解签）
- `params: { route:'qiuqian' }`（签录/再抽）
- `params: { route:'muyu' }`（木鱼页）
- `params: { route:'blessing' }`（主麻神卡 → 祈福首页拜主神）
- App 侧：`EntryAbility.onCreate(want)` / `onNewWant(want)` → 读 `want.parameters.route/open` → 写 AppStorage `pendingRoute` / `pendingOpenUnlock`。

**落地机制（原设计缺失，必须补）**：

1. **热启动必须靠 `@Watch`**：`onNewWant` 触发时 MainTabs 已存活，"起来后读一次"不生效。MainTabs 需 `@StorageLink('pendingRoute') @Watch('onPendingRoute')`，QiuQian 页同理监听 `pendingOpenUnlock`。
2. **消费后必须清空 flag**（`pendingRoute=''`、`pendingOpenUnlock=false`），否则下次回前台/切 Tab 会重复弹付费。
3. **Tab 不存在的降级**：MainTabs 的 Tab 是动态的（`entryConfigVM.getTabEntries()`，用户可在「我的→定制」关掉求签/木鱼入口，`MAX_TABS=3`）。深链目标入口被关闭时 → 落回 `blessing` Tab + toast 提示，不要静默失败。
4. **未抽签就点「解签」**：QiuQian 页此时没有当前签 → 取 `bestToday()`；仍无则打开签录列表，不要弹空覆层。

## 7. 刷新策略

- form_config：`updateEnabled:true`、`updateDuration:1`（30 分钟兜底）、`scheduledUpdateTime:"00:05"`（跨天轮换）。
  - ⚠️ 两者同时配置时以谁为准需 build 阶段核对；且系统省电/进程被杀会跳过定时 → **已知边界：跨天最多滞后 30 分钟**，spec 不承诺"跨天即时轮换"。
- 卡片交互（draw/knock）→ `message` → 即时 `updateForm`。
- **App 侧推卡片（原设计不可实现，已修正）**：`formProvider` **没有"刷新本应用全部卡片"的公开 API**，`updateForm(formId, data)` 必须传 formId。
  → 新增 `FormIdStore`：`onAddForm` 持久化 `formId→formName`（新 preferences `mashen_form_prefs`，**支持同一张卡多个实例**、区分 2×2/2×4），`onRemoveForm` 移除；`FormSyncService` 遍历该表逐个 `updateForm`（无卡则空转）。
- `onForeground` 推送顺序：`await qiuVM.reload(this.context)` / `await muyuVM.reload(this.context)`（**必须传 context 才会清缓存**，见 §8）**完成后**再推，否则推的是旧值。
- `onForeground` 有节流：跳过冷启动首次，且 2s 内不重复（频繁切后台不做无谓 I/O 与页面重建）。
- 主麻神卡跨天靠 30 分钟兜底 + 点卡进入 App 时顺带刷新。

## 8. 同步一致性（重写：进程模型决定的坑及对策）

| 场景 | 风险 | 对策 |
|---|---|---|
| 卡片 UI 读数据 | 卡片在渲染服务进程，**看不到 App 内存/AppStorage** | 一切经 FormBindingData 注入；卡片零逻辑 |
| **跨进程 preferences 缓存** | 扩展在 `luck.happy.huawei:form` 独立进程，`getPreferences` 返回**进程内缓存实例**：App 敲到 10、卡片进程缓存还是 8 → +1 写回 9，**计数被回滚**；App 侧也会一直读到空的 formId 表 | 每次读盘前 `await preferences.removePreferencesFromCache(context, PREF_NAME)` 再 `getPreferences`。已在 `QiuQianVM/MuyuVM.initialize()`、`reload(context)`、`FormIdStore.all()` 落实 |
| 扩展回调 | **每次回调可能是新实例**，成员变量缓存的 VM 会失效/读到陈旧值 | 每次 `new VM + await initialize(context)` 重新读盘 |
| App 后台时卡片抽签/敲击 | App 内存仍是旧额度/旧功德 | `onForeground` → `reload()` 重读盘（已列修改项） |
| App 侧变动 | 卡片停留在旧快照 | `FormSyncService` 遍历 `FormIdStore` 逐个 `updateForm` |
| 卡片连点（敲木鱼） | **必现** read-modify-write 丢计数 | 扩展内 Promise 串行队列 / `knockAsync()`（§5.2） |
| App 前台敲 + 卡片敲并发 | 概率低的并发写 | v1 接受；同上串行化可一并覆盖 |
| 跨天 | 定时刷新可能被跳过；App 长驻前台跨天不敲 → 今日数不归零（`rollDayIfNeeded` 只在 `initialize`/`knock` 调用） | 已知边界：最多滞后 30 分钟；`reload()` 里补一次 `rollDayIfNeeded` |

> 结论：**一致性只能靠"清缓存重读盘 + 写完 flush + App 回前台 reload + 串行写"四件套**，不存在"同进程天然一致"——扩展实测跑在独立进程。

## 9. 付费与合规 / WCAG

- 卡片只放免费内容（等级/签名/签诗/功德数/主神信息），interpretation/advice 绝不进卡片（实现红线见 §5.0 第 2 条）。
- 解签必须进 App 走消耗型 IAP（`jieqian_unlock`，现有的 `unlockJieqian()` 流程）。
- 深底卡片文字对比度按 `docs/common/wcag-contrast.md` 阈值（**该文件待补建或改引用**），等级徽章用 `LEVEL_COLOR` 实色，正文米色 alpha≥0.5；主麻神卡不用过暗的 deity.color 做文字。
- 合规：卡片纯本地数据、不新增权限（摇晃抽签已排除），隐私清单无需变更。

## 10. 注册细节（待 build 对照已装 SDK 校准）

- `module.json5` 新增 `extensionAbilities`（当前无此节点、无 metadata），项含：
  - `name:"WidgetFormAbility"`（必须与 `formConfigAbility:"ability://WidgetFormAbility"` 完全一致）
  - `srcEntry:"./ets/formability/WidgetFormAbility.ets"`
  - `type:"form"`
  - **`label` / `description`**（`$string:`，官方样板要求，原设计遗漏）
  - `metadata:[{ name:"ohos.extension.form", resource:"$profile:form_config" }]` —— **已 build 验证：新 SDK 用的是单数 `ohos.extension.form`**，写成 `ohos.extensions.form` 会报 `00303224 Configuration Error`
- `form_config.json` 的 `forms` 数组四项：`sign_2x2`（`["2*2"]`，`isDefault:true`）、`sign_2x4`（`["2*4"]`）、`muyu_2x2`（`["2*2"]`）、`deity_2x2`（`["2*2"]`），每项统一：
  - **`src`**：`"./ets/widget/pages/XxxCard.ets"`（原设计遗漏，必填）
  - **`isDynamic:true`** —— 静态卡片（`isDynamic:false`）**不支持 `postCardAction`**，draw/knock 会全废
  - **`window:{ designWidth:720, autoDesignWidth:true }`**（卡片布局基准，原设计遗漏）
  - `uiSyntax:"arkts"`、`formConfigAbility:"ability://WidgetFormAbility"`
  - `updateEnabled:true`、`updateDuration:1`、`scheduledUpdateTime:"00:05"`
- ArkTS 卡片 UI 只用白名单基础组件（Text/Row/Column/Stack 等），不引动画（除受限属性动画）、传感器、`setTimeout`、非白名单 API。
- 卡片页**不要**加进 `main_pages.json`（卡片不参与路由）。

## 11. 明确不做（YAGNI）

- 卡片摇晃抽签
- 卡片直接展示解签付费内容 / 卡片内完成付费
- 微卡 1×2、大卡 4×4；主麻神卡/木鱼卡做 2×4
- 服务端票据校验、跨设备同步
- 卡片定时频繁刷新（沿用 30 分钟兜底 + 事件驱动）

## 12. 测试方案

1. 构建：`hvigorw assembleApp`（--mode project，参照 build 环境 memory）。
2. 调试提示：卡片**不支持断点调试与 Hot Reload** → 先在 App 内自测 `bestToday()` / `knockAsync()` / 字段裁剪等纯逻辑，再套卡片壳验证渲染。
3. 真机 USB 验证（本机模拟器起不来）：
   - 桌面长按 → 服务卡片列表出现「每日求签」「敲木鱼」「今日主麻神」三张，可分别添加
   - 求签卡：点抽一签 → 卡片出签 + 额度-1 → 满 3 后变「已满」→ 解签跳 App 付费 → 签录跳求签页
   - 求签卡跨天：默认签轮换（允许滞后 30 分钟）
   - 木鱼卡：点一下 +1 → 打开 App 木鱼页计数一致 → App 敲后回桌面卡片同步
   - **木鱼卡连点 10 次 → 计数正好 +10（验证 §5.2 串行化，这是必现 bug 点）**
   - 主麻神卡：显示今日主神 → 跨天自动换 → 点卡进祈福页
   - App 后台时卡片抽签/敲击 → App 回前台额度/功德已刷新
   - 深链冷启/热启两条路径（onCreate / onNewWant）都切对 Tab、解签自动弹付费；**弹一次后 flag 已清空，再回前台不重复弹**
   - **目标入口被用户在「我的→定制」关掉后，深链降级不崩**
   - **卡片移除后再添加、添加多个同款实例、应用进程被杀后点卡片**（验证 formId 表增删与重建）
   - 卸载/覆盖升级后 formId 表残留清理
   - WCAG：真机截图 + 对比度复查（阈值文档见 §9）

## 13. 真机实测结论与调试手段（2026-10-02 真机验证后补充）

### 13.1 扩展进程的日志抓不到 —— 用「落盘探针」代替

⚠️ `console.*` 与 `hilog.info/error` 在 `luck.happy.huawei:form` 进程**都进不了 hilog**（141MB 日志 0 命中，`hilog -b D` 也无效）。所以"日志没输出"**不能**推断"回调没执行"。

可行办法：把诊断信息写进 preferences，从 PC 侧直接读（`hdc` 在 `C:\Program Files\Huawei\DevEco\sdk\default\openharmony\toolchains\hdc.exe`）：

```
hdc shell cat /data/app/el2/100/base/luck.happy.huawei/haps/entry/preferences/mashen_form_prefs
```

另一路零成本证据：看 preferences 文件的**修改时间**判断是否被调用
（例：`mashen_muyu_prefs` 的 mtime 没变 → `knock()` 一定没执行）。

> 探针属调试代码，**打 release 包前必须删除**。

### 13.2 实测踩坑清单

| # | 现象 | 根因 | 修法 |
|---|---|---|---|
| 1 | 构建报 `00303224 Configuration Error` | metadata 名写成 `ohos.extensions.form` | 新 SDK 用**单数** `ohos.extension.form` |
| 2 | 卡片编译报 `Cannot redeclare block-scoped variable 'storage'` | 四张卡打进同一个 `widgets.abc`，`LocalStorage` 变量在 bundle 内是全局作用域 | 变量名各自唯一（`signCard2x2Storage` 等） |
| 3 | `arkts-no-delete` | ArkTS 不支持 `delete` 运算符 | 重建一份排除该 key 的 map |
| 4 | 卡片图片全白、无任何报错 | `formImages` + `memory://` 的 fd 需跨进程传给渲染服务，真机**静默失败** | 改用 `$r('app.media.*')` media 资源（§4.5） |
| 5 | **点击完全没反应**（`tapSeq` 证明事件已到） | ① `params` 传了 `JSON.stringify` 字符串；② 自定义动作键名 `action` 被系统的 `'message'` 覆盖 | `params` 传对象 + 键名改 `msgAction`（§6.1） |
| 6 | 卡片敲完 App 侧计数被回滚 | 扩展在独立进程，`preferences` 进程内缓存 | 读盘前 `removePreferencesFromCache`（§8） |
| 7 | 2×4 底部按钮超出卡片边框 | 用 `justifyContent(Center)` + 固定 margin 排，内容一多就溢出 | 中间插 `layoutWeight(1)` 弹性占位（§4.2） |
| 8 | 打包停在 `spawn java ENOENT` | PATH 里没有 JDK | 把 `C:\Program Files\Huawei\DevEco\jbr\bin` 加进 PATH（或设 `JAVA_HOME`） |

### 13.3 发布相关

- **版本号**：`AppScope/app.json5` 的 `versionCode` 必须递增（本次 1000006 → 1000007，`versionName` 1.4.0 → 1.5.0）。
- **release 签名**：`build-release.bat` 走 `-p product=release -p buildMode=release`。
  ⚠️ `hvigorfile.ts` 里的 `RELEASE_SIGNING` 常量必须与 `build-profile.json5` 中 signingConfig 的**实际名字一致**（我们是 `releasekey`，插件原本写的是 `release`，会误报 "cert not configured, build unsigned"）。
  校验签名是否真的生效：看构建日志里 `SignApp` 任务的输入是否含 `mashen.p12` / `mashenRelease.p7b` / `mashen.cer`。
- **release 包不要 sideload 真机**：发布 profile 通常不含调试设备 UDID，会装不上。真机继续用 debug 包，release 包只用于上传 AGC。
- **卡片不新增任何权限**（纯本地 preferences，无网络/传感器/后台任务），AGC 权限声明维持原 4 项即可。
- **待确认**：AGC 后台是否接受 `targetSdkVersion 6.1.0(23)`。
