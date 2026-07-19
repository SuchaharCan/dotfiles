# NVM, Node

# NVM & Node
# nvm 可能是最臭名昭著的 shell 启动杀手；
# 它频繁启动很容易增加半秒钟的延迟。但我不需要在每个 shell 中都使用 nvm，
# 我只需要在输入命令时使用它nvm。所以我把它封装在一个函数中，该函数会在首次使用时替换自身
# 第一次nvm调用会删除存根，加载真正的内容（--no-use这样它也不会解析节点版本），并转发参数
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh" --no-use
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
  nvm "$@"


}
