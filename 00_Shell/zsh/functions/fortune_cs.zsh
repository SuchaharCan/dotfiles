#2026年06月10日
# 功能： 防爆折行、严选护眼相位、哈希去重消费，融入了现代化的实时补全系统
function cs() {
    local fortune_dir="$HOME/00Fortunes/bin"
    local src_dir="$HOME/00Fortunes/src"  # 新增：源码目录变量
    local pool_file="$fortune_dir/.fortune_hash_pool"
    local map_file="$fortune_dir/.fortune_hash_map"
    local temp_output="$fortune_dir/.fortune_current"

# =================================================================
    # ✨ 新增参数解析：支持 --edit 和 --sync（注意 [[ ]] 的空格！）
    # =================================================================
    if [[ "$1" == "--edit" ]]; then
        if [[ -d "$src_dir" ]]; then
            echo "📂 [词库编辑]: 正在前往源码目录..."
            cd "$src_dir" || return 1
        else
            echo "🚨 [路径错误]: 未找到源码目录 $src_dir，正在为你创建..."
            mkdir -p "$src_dir" && cd "$src_dir" || return 1
        fi
        return 0
    elif [[ "$1" == "--sync" ]]; then  # ✅ 修复：在 ]]$ 前面加上了死命令般的空格
        echo "🔄 [词库同步]: 正在为你重新制作词库并强洗哈希桶..."
        fortune-sync

        # 提示重洗成功后可以直接顺便调用一次不带参数的 cs 打印格言，体验极佳
        cs
        return 0
    elif [[ -n "$1" ]]; then
        # 如果输入了其他不认识的参数，给予友好提示
        echo "💡 [使用提示]:
        cs         - 随机读取一条未读格言 (彩虹小牛)
        cs --edit  - 快速跳转至词库源码目录进行编辑
        cs --sync  - 编辑完毕，同步制作词库并重置哈希桶"
        return 1
    fi

    # =================================================================
    # ✨ 严选护眼相位池
    # =================================================================
    local eye_safe_phases=(30 45 60 15 135 150 165 315 330)
    local random_idx=$(( (RANDOM % ${#eye_safe_phases[@]}) + 1 ))
    local chosen_phase=${eye_safe_phases[$random_idx]}

    local md5_cmd="md5"
    ! command -v md5 &>/dev/null && md5_cmd="md5sum"

    # =================================================================
    # 逻辑 1：桶初始化
    # =================================================================
    if [[ ! -f "$pool_file" || ! -s "$pool_file" || ! -f "$map_file" || ! -s "$map_file" ]]; then
        echo "🔄 [哈希重置]: 正在为你的精美词库建立全量唯一哈希索引池..."
        : > "$map_file"
        : > "$pool_file"

        local raw_all=""
        for f in "$fortune_dir"/*; do
            if [[ -f "$f" && "${f:t}" != *.dat && "${f:t}" != .* && "${f:t}" != *.tmp && "${f:t}" != *.pool && "${f:t}" != *.map ]]; then
                raw_all+="$(cat "$f" | tr -d '\r')\n%\n"
            fi
        done

        echo "$raw_all" | awk '
            BEGIN { RS="\n%\n"; block="" }
            {
                clean_block = $0;
                gsub(/^[ \t\n]+|[ \t\n]+$/, "", clean_block);
                if (clean_block != "" && clean_block != "%") {
                    print "---BLOCK_START---"
                    print $0
                    print "---BLOCK_END---"
                }
            }
        ' | while IFS= read -r line; do
            if [[ "$line" == "---BLOCK_START---" ]]; then
                block_content=""
            elif [[ "$line" == "---BLOCK_END---" ]]; then
                local my_hash=$(echo -n "$block_content" | $md5_cmd | awk '{print $1}')
                echo "==HASH:${my_hash}==" >> "$map_file"
                echo "$block_content" >> "$map_file"
                echo "%%" >> "$map_file"
                echo "$my_hash" >> "${pool_file}.raw"
            else
                [[ -z "$block_content" ]] && block_content="$line" || block_content+=$'\n'"$line"
            fi
        done

        if [[ -f "${pool_file}.raw" ]]; then
            shuf "${pool_file}.raw" > "$pool_file"
            : > "${pool_file}.raw"
        fi
    fi

    # =================================================================
    # 逻辑 2：精准消费
    # =================================================================
    local target_hash=$(head -n 1 "$pool_file" | tr -d ' \t\r\n')

    if [[ -n "$target_hash" && -f "$map_file" ]]; then
        : > "$temp_output"
        sed -n "/==HASH:${target_hash}==/,/^%%/p" "$map_file" | sed "1d;/\^%%/d" | sed '/^%%/d' > "$temp_output"

        if [[ -s "$temp_output" ]]; then

            # =========================================================
            # ✨ 【全新护眼抗洪核心】：折行防爆 + 动态方框
            # =========================================================
            (
                # 1. 展开 Tab 键，同时利用 fold 命令限制单行视觉最大显示宽为 90（支持中文智能截断）
                #    这样超长命令会自动换到下一行，绝不会把方框和 lolcat 撑爆！
                local clean_text=$(expand -t 4 "$temp_output" | fold -s -w 90)

                # 2. 动态精准计算截断后的最大列宽
                local max_w=0
                while IFS= read -r line; do
                    local line_w=${(m)#line}
                    (( line_w > max_w )) && max_w=$line_w
                done <<< "$clean_text"

                local padding_x=4
                (( max_w < 24 )) && max_w=24

                echo ""

                # 绘制方框顶部
                printf "  ╭"
                printf '─%.0s' {1..$((max_w + padding_x * 2))}
                printf "╮\n"

                printf "  │"
                printf ' %.0s' {1..$((max_w + padding_x * 2))}
                printf "│\n"

                # 3. 完美包裹折行后的正文
                while IFS= read -r line; do
                    local line_w=${(m)#line}
                    local total_spaces=$((max_w - line_w))

                    printf "  │"
                    printf ' %.0s' {1..$padding_x}
                    printf "%s" "$line"
                    printf ' %.0s' {1..$((total_spaces + padding_x))}
                    printf "│\n"
                done <<< "$clean_text"

                printf "  │"
                printf ' %.0s' {1..$((max_w + padding_x * 2))}
                printf "│\n"

                # 绘制方框底部
                printf "  ╰"
                printf '─%.0s' {1..$((max_w + padding_x * 2))}
                printf "╯\n"
            ) | lolcat -p $chosen_phase -F 0.20 -S 1

            # 4. 灰色小牛独立打印
            echo -e "\033[1;30m         \\   ^__^"
            echo "          \\  (oo)\\_______"
            echo "             (__)\\       )\\/\\"
            echo "                 ||----w |"
            echo "                 ||     ||\033[0m"
            echo ""

            # =========================================================
            # 5. 裁剪哈希桶
            # =========================================================
            local tmp_pool="${pool_file}.tmp"
            tail -n +2 "$pool_file" > "$tmp_pool"
            cat "$tmp_pool" > "$pool_file"
            : > "$tmp_pool"

            # 6. 统计剩余数量
            local remain_count=$(wc -l < "$pool_file" | tr -d ' ')
            echo -e "\033[0;37m📊 [词库统计]: 今日箴言已读。池子里还剩 💡 \033[1;32m$remain_count\033[0;37m 条未读内容。\033[0m"
        else
            fortune "$fortune_dir" | lolcat
        fi
    else
        echo "🚨 [异常触发]: 索引映射发生错位，正在强制重置重洗..."
        : > "$pool_file"
        fortune "$fortune_dir" | lolcat
    fi

    [[ -f "$temp_output" ]] && : > "$temp_output"
}
# ==============================================================================
# ✨ 专属 cs 函数的 Zsh 智能补全脚本（完美适配 zsh-autocomplete / fzf-tab）
# ==============================================================================
_cs_completion() {
    # 核心要点：多个参数之间用换行或空格隔开，绝对不要加逗号！
    # 所有的描述都必须严格包裹在参数后面的 [] 中括号内
    _arguments -s -S \
        '--edit[📂 跳转至词库源码目录进行编辑]' \
        '--sync[🔄 编辑完毕，同步制作词库并重置哈希桶]'
}

# 注册绑定
compdef _cs_completion cs
