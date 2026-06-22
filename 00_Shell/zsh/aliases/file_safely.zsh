#                                    防止针对 文件的读写 误操作
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
# 针对rm 命令的 单独处理 - 避免误删文件
# SIP 系统完整性保护功能 不允许关闭
# 单文件使用trash 删除到 垃圾箱中,便于恢复
# 默认rm 是使用rm-safely包装 删除到内置回收站(非系统回收站)中 

