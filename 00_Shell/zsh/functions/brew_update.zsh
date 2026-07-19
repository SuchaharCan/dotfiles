#!/bin/zsh
#
# 2026年06月08日 重构：解耦约束条件、升级条目、输出信息，支持 --force 强更。
# 修复：解决外层 --force 无法透传导致底层原生 brew 被二次拦截的问题。

# 全局强更标记，默认为 0（不强更）
typeset -g _BREWUP_FORCE_ACTIVE=1

# ==========================================
# 模块 1：升级条目 (Core Upgrade Logic)
# ==========================================
_execute_brew_upgrades() {
    clear
    local BOLD="\e[1m"
    local RESET="\e[0m"

    # 清理历史记录
    cd $HOME && echo "" > $HOME/.zsh_history && history -c

    echo -e "${BOLD}001: update brew (core, formulate, tap)${RESET}"
   brew update  # 此时由于全局变量已激活，此处不会被拦截
    yes | brew upgrade --formula
    yes | brew upgrade --cask --greedy
     brew upgrade --fetch-HEAD LouisBrunner/valgrind/valgrind  # 2026-06-19 暂时屏蔽，因为还不支持Mac27

    echo -e "${BOLD}002: update rust${RESET}" | lolcat
    rustup update

    echo -e "${BOLD}003: update Apple container${RESET}" | lolcat
    sudo /usr/local/bin/update-container.sh

    #_execute_gpk_upgrades  #gpk更新环节
    _execute_system_upgrades  # topgrade 托管升级
    echo "Squirrel 是否有更新 - https://github.com/rime/squirrel/releases " | lolcat
    echo "Yabai 是否有更新 - https://github.com/asmvik/formulae/tree/master/yabai" | lolcat
    echo "更新完成"
}

# ==========================================
# 模块 2：可选的输出信息 (Feedback / Countdown Logic)
# ==========================================
_print_brew_blocked_info() {
    local current_week=$1
    local current_day=$2
    local current_hour=$3
    local target_ts=$4
    local now_ts=$5

    local BOLD="\e[1m"
    local RESET="\e[0m"

    # 计算倒计时
    local diff=$((target_ts - now_ts))
    local diff_hour=$((diff / 3600))
    local diff_min=$(((diff % 3600) / 60))

    # 输出拦截状态
    echo -e "${BOLD}❌ 操作拦截：当前不在放行时段。${RESET}"
    echo -e "1. 当前周数: ${current_week} ($([[ $((10#$current_week % 2)) -eq 0 ]] && echo "双周" || echo "单周"))"
    echo -e "2. 当前时间: 周${current_day} ${current_hour}时"
    echo -e "\n${BOLD}提示：仅在 [双周] 的 [周一 20:00~23:59] 开放更新（或追加 --force 参数强制更新）。${RESET}"
    echo -e "------------------------------------------------"
    printf "⏳ 距离下次放行窗口还有: ${BOLD}%02d 小时 %02d 分钟${RESET}\n" "$diff_hour" "$diff_min"
    echo -e "------------------------------------------------"
}

# ==========================================
# 模块 3：条件约束 (Validation & Guard Logic)
# ==========================================
brew_update() {
    # 3.1 检查是否存在 --force 参数
    local force_flag=0
    for arg in "$@"; do
        if [[ "$arg" == "--force" ]]; then
            force_flag=1
            break
        fi
    done

    # 3.2 如果有 --force，激活全局强更标记，跳过时间校验
    if [[ $force_flag -eq 1 ]]; then
        _BREWUP_FORCE_ACTIVE=1
        _execute_brew_upgrades
        _BREWUP_FORCE_ACTIVE=0 # 执行完后重置
        return 0
    fi

    # 3.3 时间窗口校验
    local current_day=$(date +%u)
    local current_hour=$(date +%H)
    local current_week=$(date +%V)
    local now_ts=$(date +%s)

    # 判定：双周(偶数周) && 周一(1) && 20点-23点
    if [[ $((10#$current_week % 2)) -eq 0 ]] && \
       [[ "$current_day" -eq 1 ]] && \
       [[ "$current_hour" -ge 20 && "$current_hour" -le 23 ]]; then

        # 满足条件：直接通过
        _execute_brew_upgrades
    else
        # 不满足条件：计算下一个窗口并调用【输出模块】
        local check_ts=$now_ts
        local found=0
        local target_ts=0

        while [ $found -eq 0 ]; do
            local d_ok=$(date -r $check_ts +%u)
            local w_ok=$(date -r $check_ts +%V)

            if [[ "$d_ok" -eq 1 && "$((10#$w_ok % 2))" -eq 0 ]]; then
                local target_date_str=$(date -r $check_ts "+%Y-%m-%d 20:00:00")
                target_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$target_date_str" +%s)

                if [ $target_ts -le $now_ts ]; then
                    check_ts=$((check_ts + 86400 * 7))
                else
                    found=1
                fi
            else
                check_ts=$((check_ts + 86400))
            fi
        done

        # 触发拦截输出
        _print_brew_blocked_info "$current_week" "$current_day" "$current_hour" "$target_ts" "$now_ts"
        return 1
    fi
}

# 接管原生的 brew outdated 和 upgrade 命令
brew() {
    local cmd="$1"

    # 核心修复点：如果全局强更标记激活，或者当前命令本身带了 --force，直接放行原生命令
    local has_force=$_BREWUP_FORCE_ACTIVE
    if [[ $has_force -eq 0 ]]; then
        for arg in "$@"; do
            if [[ "$arg" == "--force" ]]; then
                has_force=1
                break
            fi
        done
    fi

    if [[ "$cmd" == "outdated" || "$cmd" == "upgrade" || "$cmd" == "update" ]]; then
        # 如果有任何强更信号，剔除参数中的 --force（防止传给不支持该参数的子命令）并调用原生 brew
        if [[ $has_force -eq 1 ]]; then
            local args=()
            for arg in "$@"; do
                [[ "$arg" != "--force" ]] && args+=("$arg")
            done
            command brew "${args[@]}"
        else
            # 没带 --force，走正常的时间窗口拦截逻辑
            local now=$(date +%s)
            local day_of_week=$(date +%u)
            local hour=$(date +%H)
            local week_num=$(date +%V)

            if [[ "$day_of_week" -eq 1 && "$((10#$week_num % 2))" -eq 0 && "$hour" -ge 20 && "$hour" -le 23 ]]; then
                command brew "$@"
            else
                # 计算倒计时并拦截
                local check_date=$now
                local found=0
                local target_ts=0
                while [ $found -eq 0 ]; do
                    local d_ok=$(date -r $check_date +%u)
                    local w_ok=$(date -r $check_date +%V)
                    if [[ "$d_ok" -eq 1 && "$((10#$w_ok % 2))" -eq 0 ]]; then
                        local target_date_str=$(date -r $check_date "+%Y-%m-%d 20:00:00")
                        target_ts=$(date -j -f "%Y-%m-%d %H:%M:%S" "$target_date_str" +%s)
                        if [ $target_ts -le $now ]; then
                            check_date=$((check_date + 86400 * 7))
                        else
                            found=1
                        fi
                    else
                        check_date=$((check_date + 86400))
                    fi
                done

                # 调用模块2的输出
                _print_brew_blocked_info "$week_num" "$day_of_week" "$hour" "$target_ts" "$now"
                return 1
            fi
        fi
    else
        # 其他 brew 命令（如 install, search 等）不受限制
        command brew "$@"
    fi
}


# ==========================================
# 模块 1.1：GPK 升级条目 (GPK Upgrade Logic)
# ==========================================
_execute_gpk_upgrades() {
    local BOLD="\e[1m"
    local RESET="\e[0m"

    echo -e "\n${BOLD}004: update gpk & specific managers (gem, npm, cargo, nuget)${RESET}" | lolcat

    # 1. 尝试更新 gpk 本身（忽略可能发生的 403 报错）
    gpk update 2>/dev/null

    # 2. 检索待升级内容并过滤出指定 SOURCE (gem, npm, cargo, nuget) 的包名
    # 使用 awk 匹配第三列为指定源的行，并打印第一列的包名
    local target_packages
    target_packages=($(gpk outdated 2>/dev/null | awk '$2 ~ /^(gem|cargo|nuget)$/ {print $1}'))

    # 3. 如果有满足条件的包，则执行批量升级
    if [[ ${#target_packages[@]} -gt 0 ]]; then
        echo -e "发现以下待升级包: ${BOLD}${target_packages[*]}${RESET}"
        # 使用 yes 命令自动确认 'Proceed? [y/N]' 提示
        yes y | gpk upgrade "${target_packages[@]}"
    else
        echo "没有发现需要更新的 gem, npm, cargo 或 nuget 包。"
    fi
}



# ==========================================
# 模块 1.1：Topgrade 统一升级 (已修复参数格式)
# ==========================================
_execute_system_upgrades() {
    local BOLD="\e[1m"
    local RESET="\e[0m"

    echo -e "\n${BOLD}004: 启动 Topgrade 托管升级 (Gem/Npm/Cargo/Pipx)${RESET}"

    # 1. 检查并安装 topgrade
    if ! command -v topgrade &>/dev/null; then
        echo "未检测到 topgrade，正在通过 brew 自动安装..."
        command brew install topgrade
    fi

    # 2. 执行精准升级
    # 注意：在 topgrade 中，多个 --only 需要分开写
    # node 对应 npm 生态，ruby_gems 对应 gem 生幕
    topgrade \
        --only ruby_gems \
        --only node \
        --only cargo \
        --only pipx
}
