function cmake_bak() {
    local file=""
    local note=""
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # 1. 简单的参数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -file)
                file="$2"
                shift 2
                ;;
            -note)
                note="$2"
                shift 2
                ;;
            *)
                # 处理不带 -file 直接传文件名的情况
                if [[ -z "$file" ]]; then
                    file="$1"
                    shift
                else
                    echo "未知参数: $1"
                    return 1
                fi
                ;;
        esac
    done

    # 2. 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        echo "错误: 找不到文件 '$file'"
        return 1
    fi

    # 3. 构造备份文件名 (例如 CMakeLists.txt.20260512.bak)
    local base_name=$(basename "$file")
    local bak_name="${base_name}.${timestamp}.bak"

    # 4. 执行备份操作
    cp "$file" "$bak_name"

    # 5. 如果有备注，解除锁定后追加（确保备份文件目前是可写的）
    if [[ -n "$note" ]]; then
        # 暂时确保有写权限以追加备注
        chmod +w "$bak_name"
        echo -e "\n# --- Backup Note ---" >> "$bak_name"
        echo "# Date: $(date)" >> "$bak_name"
        echo "# Note: $note" >> "$bak_name"
        echo "# -------------------" >> "$bak_name"
    fi

    # 6. 权限只读化与文件锁定
    chmod 444 "$bak_name"      # 设置权限为只读
    chflags uchg "$bak_name"   # macOS 特有：设置不可更改标志

    echo "✅ 备份成功: $bak_name"
    [[ -n "$note" ]] && echo "📝 备注内容: $note"
    echo "🔒 状态: 已锁定 (Read-only & Immutable)"
}




function cmake_unlock() {
    local file=""

    # 1. 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -file)
                file="$2"
                shift 2
                ;;
            *)
                if [[ -z "$file" ]]; then
                    file="$1"
                    shift
                else
                    echo "未知参数: $1"
                    return 1
                fi
                ;;
        esac
    done

    # 2. 检查文件是否存在
    if [[ ! -f "$file" ]]; then
        echo "错误: 找不到文件 '$file'"
        return 1
    fi

    # 3. 解除 macOS 文件系统锁定标志 (nouchg)
    # 这步最关键，否则即使是 chmod 也会被拒绝
    if chflags nouchg "$file"; then
        # 4. 恢复拥有者的写权限 (u+w)
        chmod u+w "$file"
        echo "🔓 解锁成功: $file"
        echo "状态: 已恢复写权限，可以进行编辑或删除。"
    else
        echo "错误: 无法解除文件锁定标志。请检查是否有足够的权限。"
        return 1
    fi
}