# 该模式适用于很多情况：任何需要你手动添加参数eval "$(tool init zsh)"的.zshrc函数都适合延迟加载
# 都会创建一个新的进程并在启动时评估其输出

kubectl() {
    command kubectl "$@"
    local ret=$?
    if [[ -z $KUBECTL_COMPLETE ]]; then
        source <(command kubectl completion zsh)
        KUBECTL_COMPLETE=1
    fi
    return $ret
}
