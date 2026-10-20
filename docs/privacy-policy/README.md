# 隐私政策托管与 AGC 填报指南

> 本文配套 `privacy-policy.html`（网页版源文件）与 `../privacy-policy-full.md`（正文源稿）。
> 目标：把隐私政策发布到**网页**（可访问的网址），再填进 AGC **系统**（AppGallery Connect 控制台）。

## 一、三个版本的关系（必须一字不差）

| 位置 | 文件 / 字段 | 说明 |
|------|-------------|------|
| App 内（系统） | `entry/src/main/ets/components/PrivacyDialog.ets` → `getPrivacyContent()` | 首次启动弹窗 + 「我的」→「隐私政策」复阅 |
| 网页（托管网址） | `docs/privacy-policy/privacy-policy.html` | AGC「隐私政策网址」字段指向的页面 |
| 源稿 | `docs/privacy-policy-full.md` | 上述两者的同源稿，改动必须同步 |

> ⚠️ 三份正文必须一致。已核对项（2026-10-20）：
> 加速度传感器披露（「一、收集的信息」+「三、权限说明」）—— 2026-09 拒因，三份均含；
> 打赏 / 公益排行榜披露（「一、二、四」三条）—— 2026-10-20 同步，三份均含。
> 改任何一份，其余两份必须同步，否则 AGC 复检会以「信息收集未披露」拒绝。

## 二、把网页发布到 GitHub Pages（推荐，免费 HTTPS）

前提：项目已推送到 GitHub（见 `../github-setup.md`）。仓库名假设为 `caishen-app`。

1. 打开仓库页面 → **Settings** → 左侧 **Pages**。
2. **Source** 选 **Deploy from a branch**，Branch 选 **main**，目录选 **/docs**，点 **Save**。
3. 等待约 1 分钟，页面顶部出现你的网址：
   `https://<你的GitHub用户名>.github.io/caishen-app/`
4. 隐私政策网址即为：
   `https://<你的GitHub用户名>.github.io/caishen-app/privacy-policy/privacy-policy.html`
5. 手机 / 浏览器打开验证：六节正文齐全（尤其「打赏记录」三条与「加速度传感器」两条），样式正常。

> 不想用 GitHub Pages？可选：
> - 华为 AGC「隐私声明」托管服务（AGC 控制台内有入口，上传网页 zip）；
> - 任意静态托管（Vercel / Netlify / 自己的服务器），只要 HTTPS 且国内可访问。

## 三、把网址填进 AGC 系统（控制台）

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/jrg-agnc/) → **我的项目** → 选择本项目。
2. **我的应用** → 选择「财神保佑」→ **应用信息**。
3. 找到 **隐私政策网址** 字段 → 粘贴第二步的 `privacy-policy.html` 完整网址 → 保存。
4. **隐私标签**（同一页 / 用户与权限 → 隐私标签）按 `../privacy-label-checklist.md` 勾选：
   - ✅ 设备标识符（匿名）、昵称、文本内容（心愿）、操作记录
   - ❌ 不勾：位置、通讯录、相册、相机、麦克风、生物识别、健康、财务、身份、日志、传感器
5. 提交提审时，「版本说明」引用 `../review-notes-v1.0.0.md`，其中已含客服邮箱与付费披露自检。

## 四、更新流程（改了隐私政策后）

1. 改 `docs/privacy-policy-full.md`（源稿）。
2. 同步 `privacy-policy.html`（正文六节）与 `PrivacyDialog.ets` 的 `getPrivacyContent()`。
3. `git add -A && git commit`，`git push` —— GitHub Pages 自动重新部署（约 1 分钟）。
4. AGC 控制台无需改动（网址不变）。

## 五、自检清单

- [ ] `privacy-policy.html` 可公网访问（HTTPS）
- [ ] 六节正文与 App 内弹窗一字不差（含打赏 ×3、加速度传感器 ×2）
- [ ] AGC「应用信息 → 隐私政策网址」已填写并保存
- [ ] AGC「隐私标签」已如实勾选（见 privacy-label-checklist.md）
- [ ] 客服邮箱 `andyli0912@petalmail.com` 出现在政策文末
