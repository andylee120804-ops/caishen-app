# 打赏五档消耗型商品 · AGC 批量上架/核对清单

> 配套文件：`docs/iap-tip-products.xlsx`（AGC 英文表头导入模板）、`docs/iap-tip-products.csv`（同数据）。
> AGC 商品导入模板为**英文表头**：`productId / productType / status / defaultLanguage / name / description / price / country`。
> `status` 取值 `1`=上架、`0`=下架；`productType`=`consumable`（消耗型）；`country`=CN（鸿蒙 IAP 仅中国大陆）。

## 关键约束

- **商品 ID 已变更**：AGC 商品 ID 不可改名，故原为 `tip_18 / tip_88`，现改为 **`tip_18_2 / tip_88_2`**。
  端侧 `TIP_PRODUCTS` 与云侧 `donation-record` 白名单**已同步**为 `tip_18_2 / tip_88_2`，三方必须一致。
- **类型 = 消耗型（consumable）**：付款后必须 `finishPurchase` 消耗，否则同档再买被 `1001860051` 拦截。
- **名称中性**：仅表达「对开发者的支持」，不得带「香 / 供奉 / 祈福 / 解锁权益」。
- **状态 = 上架（status=1）**。

## 五档商品（与代码当前值一致）

| 商品 ID | 类型 | 价格(CNY) | 商品名称 | 状态 |
|---------|------|-----------|----------|------|
| tip_8 | 消耗型 | 8.00 | 支持 · 心意 | 上架 |
| tip_18_2 | 消耗型 | 18.00 | 祝愿 · 顺遂 | 上架 |
| tip_88_2 | 消耗型 | 88.00 | 福田 · 同行 | 上架 |
| tip_188 | 消耗型 | 188.00 | 殿设 · 聚宝 | 上架 |
| tip_888 | 消耗型 | 888.00 | 至诚 · 厚爱 | 上架 |

商品描述（五档通用）：
> 对开发者的自愿支持，用于应用后续开发与维护（部分将捐赠公益）。不承诺任何祈福效果，也不解锁任何权益。

> `tip_188`（殿设 · 聚宝）对应财神殿「聚宝盆」陈设解锁：购买仅改变殿内视觉效果，不涉及任何祈福效力。

## AGC 批量操作步骤

1. 登录 AGC → **我的项目** → 选择本应用 → **付费分发 / 商品管理（IAP）** → **商品**。
2. 点 **导入** → 先**下载官方模板 .xlsx**（以官方列名为准）。
3. 把 `docs/iap-tip-products.xlsx`「AGC导入模板」表的 5 行数值，按官方模板对应列复制进去（注意 `status` 用数字 `1`，`country` 用 `CN`）。
4. 上传导入；若商品已存在会按 `productId` 覆盖名称/价格。
5. 冒烟：App 内打赏每一档均能拉起华为收银台并消耗成功。

> 若 AGC 官方模板列名与本文不一致，以官方模板为准，本文件仅提供数值来源。
> 旧商品 `tip_18 / tip_88`（无 `_2` 后缀）如仍在 AGC，建议下架/删除，避免混淆。

## 三方一致性自检

- 端侧：`entry/src/main/ets/service/IPaymentService.ets` → `TIP_PRODUCTS`
- 云侧：`cloud/donation-record/handler.js` → `PRODUCT_IDS` 白名单
- AGC：上述 5 个商品（tip_8 / tip_18_2 / tip_88_2 / tip_188 / tip_888）
