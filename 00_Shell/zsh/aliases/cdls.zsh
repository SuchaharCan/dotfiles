#                                           目录导航辅助
if [[ "$(uname)" == "Darwin" ]]; then #若OS为 MacOS时 执行此处
    #  英语（美国）排序规则排序; 目录在输出中排在文件之前;自动使用颜色来区分不同类型的文件和目录
    alias ls='gls --color=auto'  # 打印当前路径中 内容
else
    alias ls='ls --color=auto'
fi

alias l.='ls -d .* --color=auto'
# 打印 .开头的隐藏文件&目录
alias al='ls | sed "s:^:`pwd`/:"'
#alias ll='ls -lAh'
alias -- -="cd -"
alias .. =cd ..
alias ...=cd ../..
alias ....=cd ../../..
alias .....=cd ../../../..
alias ......=cd ../../../../..
alias dl="cd ~/Downloads"

# 在 Mac 终端看到带有图标、Git 状态、层级树状图的超硬核文件列表
 alias ll="eza --long --tree --level=2 --git --icons"
