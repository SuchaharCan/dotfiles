# 无参函数
# 场景： C++/LLVM 构建系统 构建路径清理 构建内容时使用，检测rm命令是否在 含有 build的路径下，如果不在，则不执行，避免 硬删除 源代码，而非 构建内容


rm_build() {
    set +f # opposite of set -f
    # 获取当前目录的绝对路径 -- 路径检测
    current_dir=$(pwd)
    # 此处获取ls的内容
    current_ls=$(ls)
    # 检查当前目录是否包含 'build' 子字符串
    if [[ "$current_dir" == *"build"* ]]; then
          echo "删除: $@"
          /bin/rm -rf *   # 删除ls下的所有内容
    else
        echo "当前目录路径中不包含 'build'，不执行 rm 命令。"
    fi
}

