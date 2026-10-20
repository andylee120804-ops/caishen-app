# GitHub 仓库创建与推送指南

> 状态：2026-10-20 已在本地完成 `git init`（main 分支）+ 首次提交 `bd2db01`。
> 接下来只需要：**① 在 GitHub 网页创建空仓库 → ② 加 remote → ③ 推送**。
> 签名凭据（build-profile.json5、*.p12/*.p7b/*.cer）与 AGC 凭证（cloud/agc-credential.json）
> 已通过 .gitignore 排除，不会上传。

## 一、在 GitHub 网页创建空仓库（约 2 分钟）

1. 打开 https://github.com 并登录（没有账号先注册）。
2. 右上角 **+** → **New repository**。
3. 填写：
   - **Repository name**：`caishen-app`（与本地文件夹同名即可）
   - **Description**（可选）：`财神保佑 · HarmonyOS 应用（祈福 / 求签 / 还愿 / 心愿墙 / 打赏公益榜）+ AGC 云函数`
   - **Visibility**：选 **Private**（私密，推荐——应用未上架前先私有，含业务代码）
   - ⚠️ **不要勾选** "Add a README"、"Add .gitignore"、"Add a license"——本地已有一切，勾了会造成合并冲突。
4. 点 **Create repository**。

## 二、把本地代码推上去（复制粘贴执行）

把下面命令里的 `你的用户名` 换成你的 GitHub 用户名：

```bash
git remote add origin https://github.com/你的用户名/caishen-app.git
git push -u origin main
```

完成后刷新网页，应能看到全部源码。验证命令：

```bash
git status          # 应为 "working tree clean"
git log --oneline   # 应看到 bd2db01 初始化提交
```

> 推送时若提示输入用户名/密码：用户名填你的 GitHub 用户名；密码不是登录密码，
> 而是一个 **Personal Access Token**（PAT）——创建方法见下方「附：个人访问令牌」。

## 三、（可选）启用 GitHub Pages 托管隐私政策

隐私政策网页 `docs/privacy-policy/privacy-policy.html` 用 GitHub Pages 托管后，
把网址填进 AGC 控制台「应用信息 → 隐私政策网址」。步骤：

1. 仓库 → **Settings** → 左侧 **Pages**。
2. **Source** = **Deploy from a branch**，**Branch** = `main`，目录 = `/docs`，**Save**。
3. 等约 1 分钟，隐私政策网址即：
   `https://你的用户名.github.io/caishen-app/privacy-policy/privacy-policy.html`
4. 更详细说明见 [`docs/privacy-policy/README.md`](./privacy-policy/README.md)。

## 四、（可选）以后想用命令直接建仓库

安装 GitHub 官方 CLI（winget 或从 https://cli.github.com 下载），登录后即可一键建仓推送：

```bash
winget install GitHub.cli
gh auth login
gh repo create caishen-app --private --source=. --push
```

## 附：个人访问令牌（PAT）创建

推送/拉取需要令牌（替代密码），创建一次即可：

1. GitHub → 右上角头像 → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)** → **Generate new token (classic)**。
2. 勾选 **repo** 权限（完整勾选 `repo` 分类），有效期建议 **90 天**，生成后复制 `ghp_...`。
3. 推送时密码框粘贴该令牌即可；Windows 会通过凭据管理器记住，之后无需再输。
