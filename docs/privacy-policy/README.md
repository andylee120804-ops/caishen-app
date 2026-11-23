# 隐私政策托管与 AGC 填报指南

> 本文配套 `privacy-policy.html`（网页版源文件）与 `../privacy-policy-full.md`（正文源稿）。
> 目标：把隐私政策发布到**网页**（可访问的网址），再填进 AGC **系统**（AppGallery Connect 控制台）。

## 一、三个版本的关系（必须一字不差）

| 位置 | 文件 / 字段 | 说明 |
|------|-------------|------|
| App 内（系统） | `entry/src/main/ets/components/PrivacyDialog.ets` → `getPrivacyContent()` | 首次启动弹窗 + 「我的」→「隐私政策」复阅 |
| 网页（托管网址） | `docs/privacy-policy/privacy-policy.html` | AGC「隐私政策网址」字段指向的页面 |
| 根地址冗余页 | `docs/index.html` | GitHub Pages 根地址（`/caishen-app/`）也提供完整政策，防止控制台误填根网址时被判「未说明」；与网页版逐字一致 |
| 源稿 | `docs/privacy-policy-full.md` | 上述三份的同源稿，改动必须同步 |

> ⚠️ 四份正文必须一致。已核对项（2026-11-23）：
> 加速度传感器披露：正文开头独立「加速度传感器使用说明（目的 / 方式 / 范围）」段落 +
> 「一、收集的信息」+「三、权限说明」+「四、信息保护」，逐项对应审核建议的目的/方式/范围；
> 2026-09/2026-11 反复拒因，2026-11-23 四份均含且正文一致；
> 支持作者 / 公益排行榜披露（「一、二、四」三条）—— 四份均含。
> 改任何一份，其余两份必须同步，否则 AGC 复检会以「信息收集未披露」拒绝。
>
> **复检前必做**：控制台「隐私政策网址」必须是本次部署后的页面（手机浏览器直接打开核对
> 「加速度传感器数据」两句在不在），并且国内网络可访问。GitHub Pages 在国内访问不稳定，
> 若无法访问华为审核环境会判「网址未说明」——优选 AGC 标准化隐私声明托管服务（见问题 2）。

## 二、把网页发布到 GitHub Pages（推荐，免费 HTTPS）

前提：项目已推送到 GitHub（见 `../github-setup.md`）。仓库名假设为 `caishen-app`。

1. 打开仓库页面 → **Settings** → 左侧 **Pages**。
2. **Source** 选 **Deploy from a branch**，Branch 选 **main**，目录选 **/docs**，点 **Save**。
3. 等待约 1 分钟，页面顶部出现你的网址：
   `https://<你的GitHub用户名>.github.io/caishen-app/`
4. 隐私政策网址即为：
   `https://<你的GitHub用户名>.github.io/caishen-app/privacy-policy/privacy-policy.html`
5. 手机 / 浏览器打开验证：六节正文齐全（尤其「支持作者记录」三条与「加速度传感器」三条），样式正常。
   **必须用手机流量（非公司/家庭网络）打开一次**，确认华为审核环境可访问；打不开就换托管。

> **托管选择（2026-11-22 教训）**：GitHub Pages 在国内访问不稳定，可能被华为审核环境判定为
> 「隐私政策网址未说明」。优先顺序：
> 1. **AGC「标准化隐私声明托管服务」**（审核问题 2 官方推荐，见下方链接）——最稳，且自动同步合规项；
> 2. 华为云 OBS 静态网站托管 / Gitee Pages 等国内可稳定访问的 HTTPS 托管；
> 3. GitHub Pages（当前方案，需自行验证国内可达性）。
>
> 标准化隐私声明托管服务：https://developer.huawei.com/consumer/cn/doc/app/agc-help-privacy-policy-faq-000000234231562

## 三、把网址填进 AGC 系统（控制台）

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/jrg-agnc/) → **我的项目** → 选择本项目。
2. **我的应用** → 选择「财神保佑」→ **应用信息**。
3. 找到 **隐私政策网址** 字段 → 粘贴第二步的 `privacy-policy.html` 完整网址 → 保存。
4. **隐私标签**（同一页 / 用户与权限 → 隐私标签）按 `../privacy-label-checklist.md` 勾选：
   - ✅ 设备标识符（匿名）、昵称、文本内容（心愿）、操作记录
   - ✅ 传感器数据：**若控制台存在该类目必须勾选**，用途填「摇晃求签动作识别，仅本机即时处理、不上传、不共享、不存储」
   - ❌ 不勾：位置、通讯录、相册、相机、麦克风、生物识别、健康、财务、身份、日志
5. 提交提审时，「版本说明」引用 `../review-notes-v1.8.0.md`，其中已含客服邮箱、付费披露与加速度传感器说明自检。

## 四、更新流程（改了隐私政策后）

1. 改 `docs/privacy-policy-full.md`（源稿）。
2. 同步 `privacy-policy.html`（正文六节）、根冗余页 `docs/index.html` 与 `PrivacyDialog.ets` 的 `getPrivacyContent()`。
3. `git add -A && git commit`，`git push` —— GitHub Pages 自动重新部署（约 1 分钟）。
4. AGC 控制台无需改动（网址不变），但复检前必须用手机流量打开核对新段落。

## 五、自检清单

- [ ] `privacy-policy.html` 与根地址 `docs/index.html` 均可公网访问（HTTPS）
- [ ] 六节正文与 App 内弹窗一字不差（含开头独立「加速度传感器使用说明」段落、支持作者 ×3）
- [ ] AGC「应用信息 → 隐私政策网址」已填写并保存
- [ ] AGC「隐私标签」已如实勾选（见 privacy-label-checklist.md）
- [ ] 客服邮箱 `andyli0912@petalmail.com` 出现在政策文末
