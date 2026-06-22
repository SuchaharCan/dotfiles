# 架构设计 

> 命名字典规范

| 前缀 | 含义                                                     | 备注         |
| ---- | -------------------------------------------------------- | ------------ |
| 00   | 该配置 影响 范围 系统全局 慎重 单独管理                  | Shell,包管理 |
| 10   | 该配置 影响 半系统全局， 空间管理，窗口管理， 快捷键管理 |              |
|      |                                                          |              |







* 个人开发的 bin/ Script /tools 等 要进行 环境配置， 让shell 中能够导入 ； 
  * cronjobs  定时任务 集合 
  * bin  个人自用 二进制 工具集合
  * script 个人自用 编写的脚本集合 

```zsh
~/dotfiles/
├── bin/                # 你开发的常用 CLI 工具
├── tasks/              # 存放定时任务的集合
│   ├── scripts/        # 实际执行的脚本逻辑
│   │   ├── backup.sh
│   │   └── cleanup.sh
│   └── launchd/        # 存放 .plist 配置文件（macOS 原生方式）
│       ├── com.user.backup.plist
│       └── com.user.cleanup.plist
```

```

```

### 💡 核心建议：

如果这是你个人维护的 `dotfiles`，**建议使用 `tasks/` 或 `cron/`**。

- **使用 `tasks/` 的理由：** 它比 `cron` 更具包容性。除了定时执行（cron），你可能还会包含一些手动触发的任务或依赖系统事件触发的任务。
- **命名习惯：** 在命名内部脚本时，建议使用前缀区分频率，例如：`daily-backup.sh`, `weekly-cleanup.sh`。

### 小贴士：

在 macOS 上，直接把文件放在 `tasks/` 目录下并不会自动生效。你需要将 `launchd` 的 `.plist` 文件软链接（Symlink）到 macOS 的系统路径 `~/Library/LaunchAgents/` 下，这样系统才会读取并执行它们。

你目前的这些定时任务，主要是为了处理**系统清理**、**数据备份**，还是**特定工作流的自动化**？根据用途，我可以帮你写一个简单的安装脚本（installer），帮你自动完成这些任务的注册。



https://github.com/webpro/awesome-dotfiles







## dotfiles 目录结构


```zsh
# update:2026-06-22  Beta1 框架搭建

~/dotfiles/
├── install.sh          # 一键安装脚本（核心：自动链接文件、安装工具）
├── Brewfile            # Homebrew 包列表（管理工具链的核心）
├── zsh/                # Shell 配置
│   ├── zshrc           # 主配置文件
│   ├── aliases         # 别名定义
│   └── exports         # 环境变量
├── git/                # Git 配置
│   ├── gitconfig
│   └── gitignore_global
├── nvim/               # Neovim 配置（或其他编辑器）
├── macos/              # macOS 系统偏好设置脚本 (.macos)
└── scripts/            # 自定义自动化脚本





~/dotfiles/keymaps/
├── README.md           # 记录你的操作逻辑（比如：为什么选择 Leader 键）
├── vim.lua (或 .vim)    # Vim/Neovim 的模态按键规范
├── system.json         # macOS 系统级的全局快捷键定义
├── app-specific/       # 主流应用差异化映射
│   ├── vscode.json
│   ├── iterm2.json
│   └── browser.json
└── common.lua          # 跨平台通用逻辑（如：复制/粘贴/搜索的统一绑定）

```



>  不要直接移动原文件，而是通过 `stow` 或 `ln -s` 命令将 `~/dotfiles` 中的文件**软链接**到目标位置（如 `~/.zshrc`）































### 仓库拉取位置

习惯上，开发者会将 dotfiles 仓库克隆到以下位置：

- **路径：** `~/dotfiles` 或 `~/.dotfiles`
- **做法：**
  1. 在 GitHub 上 fork 一个模版（或创建自己的仓库）。
  2. `git clone https://github.com/yourname/dotfiles.git ~/dotfiles`
  3. 进入目录，运行安装脚本。

###  关键自动化技巧

#### 1. 使用 Brewfile 实现“一键装机”

你可以运行 `brew bundle dump` 生成当前的包列表，保存为 `Brewfile`。下次在新电脑上，只需运行 `brew bundle`，所有工具（如 git, node, python, docker）会自动安装，无需手动安装。

#### 2. 使用 GNU Stow 管理软链接

这是许多资深开发者维护 `dotfiles` 的标准方式。

- 安装：`brew install stow`
- 使用：进入 `~/dotfiles` 目录，执行 `stow zsh`，它会自动将 `zsh/` 下的所有内容链接到 `~/` 目录中。

#### 3. 将 macOS 设置脚本化

可以将所有系统个性化设置（例如：隐藏菜单栏、修改快捷键、设置 Finder 默认路径）编写为 `macos.sh`，直接运行即可一键还原你的工作习惯。







##  Brewfile



```zsh
#pwd: ~/

#install and run
brew bundle --file=~/dotfiles/Brewfile

# create brewfile  仅备份 (Formulae 和 cask)
# 务必排除 Mac App Store 列表
brew bundle dump --describe --force --no-mas

#update brewfile
brew bundle dump --force --file=~/dotfiles/Brewfile
```

