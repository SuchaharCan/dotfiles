# 创建和输入 （创建目录并进入该目录）
# eg. take projects/new-thing
take() {
  mkdir -p "$1" && cd "$1"
}

# 拆解任何物品
extract() {
  case $1 in
    *.tar.gz|*.tgz)    tar -xzf "$1";;
    *.tar.bz2|*.tbz2)  tar -xjf "$1";;
    *.tar.xz|*.txz)    tar -xJf "$1";;
    *.zip)             unzip "$1";;
    *.7z)              7z x "$1";;
    *.rar)             unrar x "$1";;
    *.gz)              gunzip "$1";;
    *.bz2)             bunzip2 "$1";;
    *)                 echo "Unknown format: $1";;
  esac
}
# zoxide 将其集成到系统中cd，使其成为一个透明的备用方案
# cd src无论你最常用的源代码目录位于目录树的哪个位置，输入命令都能直接跳转到该目录。几个月后，你甚至不再关心文件在哪里了。
cd() {
  [ -z "$*" ] && builtin cd && return
  [ -d "$*" ] && builtin cd "$*" && return
  [ "$*" = "-" ] && builtin cd "$*" && return
  case "$*" in
    ..) builtin cd ..; return;;
    .) builtin cd .; return;;
  esac
  z "$*" || builtin cd "$*"
}

