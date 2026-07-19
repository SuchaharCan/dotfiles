# 基础路径 (bin, local/bin)

# 基础路径
export PATH="$HOME/bin:$HOME/.local/bin:/opt/homebrew/bin:$PATH"

# 常用 CLI 工具路径
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/ccache/libexec:$PATH"
export PATH="/opt/homebrew/opt/make/libexec/gnubin:$PATH"
#export PATH="/opt/homebrew/opt/binutils/bin:$PATH"
export PATH="$HOME/.cache/lm-studio/bin:$PATH"

# 镜像源设置

export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"


#终端文本处理工具 （Linux版本的awk, Mac自带awk古老）
PATH="/opt/homebrew/opt/gawk/libexec/gnubin:$PATH"


# 一个轻量级的 C/C++ 构建和工作流工具 Craft
export PATH="$HOME/.craft/bin:$PATH"
# https://gitlab.com/malkhuzanie/lyric-tui  的终端用户界面 (TUI)，用于从您喜爱的音乐播放器中获取和显示歌词
export PATH="$HOME/.cargo/bin:$PATH"

# Fortunes - 谮言  自己培养
# 1. 定义私有箴言库路径 Fortune 个人本地谮言 - 同步到 坚果云
export MY_FORTUNE_BIN="$HOME/00Fortunes/bin"
# 2. 定义一键同步函数
function fortune-sync() {
    (cd "$HOME/00Fortunes" && make)
}
# 3. 劫持 fortune 命令
# 加上 -e 参数可以将所有文件视为同等权重，或者直接指定目录
alias fortune='/opt/homebrew/bin/fortune $MY_FORTUNE_BIN'

# Ollama  精细化控制
# export OLLAMA_NUM_PARALLEL=1 # 并行处理的数量，可能影响处理请求的速度
# export OLLAMA_NUM_CTX=8192
# export OLLAMA_NUM_PREDICT=4096




export VCPKG_ROOT="$HOME/vcpkg"
PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
# ===========Homebrew配置
export HOMEBREW_CURL_RETRIES=5
export HOMEBREW_CURL_TIMEOUT=300
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_REQUIRE_TAP_TRUST=1
export HOMEBREW_CACHE="$HOME/Library/Caches/Homebrew"


# 语言配置
export LC_ALL="en_US.UTF-8"
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"

# What The Fork 一款可视化编译时间的工具
wtf() {
    "/Applications/What The Fork.app/Contents/Resources/wtf" "$@"
}




if command -v neofetch >/dev/null; then
  export DOTFILES_MOTD_CMD='neofetch'
fi

# Set fortune command
if command -v fortune >/dev/null 2>&1; then
  export DOTFILES_FORTUNE_CMD='fortune'
fi

# 需要确保同一个别名在不同的操作系统上使用不同的命令都能正常工作。我发现最好的方法是使用 if 语句来检查命令的输出uname -s
# macOS-style `say` command on Linux using espeak
if [[ "$(uname -s)" == "Linux" ]] && command -v espeak >/dev/null; then
  alias say='espeak -s 160 -p 60 -v en-us+f2'
fi

# 🖇 Clipboard alias setup for Bash/Zsh
# Detect OS via uname and set up clip/paste aliases accordingly
case "$(uname -s)" in
    Darwin)
        # macOS
        alias clip='pbcopy'
        alias paste='pbpaste'
        ;;

    Linux)
        # Linux (assumes xclip is installed)
        if command -v xclip >/dev/null 2>&1; then
            alias clip='xclip -selection clipboard'
            alias paste='xclip -selection clipboard -o'
        elif command -v xsel >/dev/null 2>&1; then
            # fallback to xsel if xclip is missing
            alias clip='xsel --clipboard --input'
            alias paste='xsel --clipboard --output'
        else
            echo "[WARN] No clipboard tool found (install xclip or xsel for clip/paste aliases)"
        fi
        ;;

    *)
        echo "[INFO] Clipboard aliases not set: unsupported OS ($(uname -s))"
        ;;
esac
