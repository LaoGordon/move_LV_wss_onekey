# GitHub上传指南

## 前置条件

- 已有GitHub账号
- 已完成Git初始化和提交（已完成）
- 已安装Git

## 方法一：通过GitHub网页创建仓库（推荐）

### 1. 在GitHub上创建新仓库

1. 访问 [GitHub](https://github.com) 并登录
2. 点击右上角的 `+` 图标，选择 `New repository`
3. 填写仓库信息：
   - **Repository name**: `LV` 或 `fastlivo2-ros2-workspace`
   - **Description**: `FAST-LIVO2 ROS2 workspace with Livox LiDAR drivers`
   - **Public/Private**: 根据需要选择
   - **⚠️ 不要勾选** "Initialize this repository with a README"（因为我们已经有了）
4. 点击 `Create repository`

### 2. 推送到GitHub

创建仓库后，GitHub会显示推送命令。根据你的选择执行：

**如果仓库是空的（推荐）:**
```bash
# 将本地仓库推送到GitHub
git remote add origin https://github.com/你的用户名/仓库名.git
git branch -M main
git push -u origin main
```

**如果仓库已经包含文件（如README）:**
```bash
# 先拉取GitHub仓库的内容
git remote add origin https://github.com/你的用户名/仓库名.git
git pull origin main --allow-unrelated-histories
# 解决冲突后推送
git push -u origin main
```

### 3. 示例

假设你的GitHub用户名是 `longkang`，仓库名是 `LV`：

```bash
git remote add origin https://github.com/longkang/LV.git
git branch -M main
git push -u origin main
```

第一次推送时，系统会要求输入GitHub的用户名和密码（或Personal Access Token）。

## 方法二：通过GitHub CLI（更便捷）

### 1. 安装GitHub CLI

```bash
# Ubuntu/Debian
sudo apt install gh

# 或者从官网下载: https://github.com/cli/cli/releases
```

### 2. 登录GitHub

```bash
gh auth login
```

按提示选择：
- `GitHub.com`
- `HTTPS`
- `Login with a web browser`
- 复制并打开显示的URL，授权登录

### 3. 创建仓库并推送

```bash
# 在当前目录执行
gh repo create LV --public --source=. --remote=origin --push
```

选项说明：
- `--public`: 公开仓库（使用 `--private` 创建私有仓库）
- `--source=.`: 使用当前目录
- `--remote=origin`: 远程仓库名
- `--push`: 自动推送

## 方法三：使用SSH密钥（无需密码）

### 1. 生成SSH密钥

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

按回车使用默认路径，可以设置密码或直接回车。

### 2. 启动ssh-agent并添加密钥

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 3. 将SSH公钥添加到GitHub

1. 复制公钥：
```bash
cat ~/.ssh/id_ed25519.pub
```

2. 访问 GitHub SSH Keys 设置页面
3. 点击 `New SSH key`
4. 粘贴公钥内容，点击 `Add SSH key`

### 4. 使用SSH URL推送

```bash
git remote add origin git@github.com:你的用户名/仓库名.git
git branch -M main
git push -u origin main
```

## 常见问题

### 问题1: 推送时要求输入密码

GitHub不再支持使用密码推送，需要使用Personal Access Token：

1. 访问 [GitHub Token设置](https://github.com/settings/tokens)
2. 点击 `Generate new token` → `Generate new token (classic)`
3. 勾选 `repo` 权限
4. 点击 `Generate token`
5. 复制生成的token（只显示一次，务必保存）
6. 推送时用token代替密码

**推荐使用SSH方式（方法三）避免此问题。**

### 问题2: fatal: remote origin already exists

```bash
# 重新设置远程仓库URL
git remote set-url origin https://github.com/你的用户名/仓库名.git
```

### 问题3: 推送失败 - refused to update

```bash
# 强制推送（谨慎使用）
git push -f origin main
```

### 问题4: 文件太大被拒绝

GitHub单个文件最大100MB。如果遇到此问题：

```bash
# 检查大文件
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '/^blob/ {print substr($0,6)}' | sort -nk2 | tail -n 10

# 使用Git LFS（大文件存储）
git lfs install
git lfs track "*.tar.gz"
git add .gitattributes
git commit -m "Add Git LFS"
git push
```

### 问题5: .gitignore未生效

如果文件已经被提交到Git，需要先删除：

```bash
# 从Git中删除，但保留本地文件
git rm --cached -r 文件夹路径
git commit -m "Remove tracked files"
git push
```

## 验证上传

推送成功后：

1. 访问GitHub仓库页面
2. 检查文件列表是否完整
3. 查看提交历史
4. 确认README.md显示正常

## 后续使用

### 克隆到新电脑

```bash
git clone https://github.com/你的用户名/仓库名.git
cd 仓库名
./build_all_workspaces.sh
```

### 更新代码

```bash
# 查看修改
git status

# 添加修改
git add .

# 提交修改
git commit -m "描述你的修改"

# 推送到GitHub
git push
```

### 从GitHub拉取更新

```bash
git pull origin main
```

## 总结

最简单的流程（推荐方法一）：

```bash
# 1. 在GitHub网页创建空仓库
# 2. 推送代码
git remote add origin https://github.com/你的用户名/仓库名.git
git branch -M main
git push -u origin main
```

## 相关链接

- [GitHub文档](https://docs.github.com)
- [Git文档](https://git-scm.com/doc)
- [Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
