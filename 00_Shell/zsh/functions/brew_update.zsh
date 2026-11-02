#!/bin/zsh
#
# 2026年06月08日 重构：解耦约束条件、升级条目、输出信息，支持 --force 强更。
# 修复：解决外层 --force 无法透传导致底层原生 brew 被二次拦截的问题。
# 2026年07月21日：ghcup 按安装方式更新；Xcode 过旧拦截自动 stash 重试；
#               GitHub 关注仓库新鲜度检查（Squirrel / Yabai formula 等）。

# 全局强更标记，默认为 0（不强更）
typeset -g _BREWUP_FORCE_ACTIVE=1

# Xcode 临时 stash（Homebrew 过旧 Xcode 门禁）；映射文件记录「原路径|stash路径」
typeset -g _BREWUP_XCODE_STASH_DIR="/opt/xcode-stash"
typeset -g _BREWUP_XCODE_STASH_MAP="${_BREWUP_XCODE_STASH_DIR}/.brewup_stash_map"
typeset -g _BREWUP_XCODE_SELECT_SAVED=""

# -----------------------------------------------------------------------------
# 关注仓库列表（可继续往下追加）
# 格式: "显示名|kind|owner/repo[|path]"
#   kind=release → 查 GitHub Releases 最新 published_at（API，失败则 releases.atom）
#   kind=commits → 查指定 path 最近 commit（API，失败则 commits/...atom）
# 说明: 原 formulae tap（asmvik/formulae/.../yabai）已 404，改追上游 asmvik/yabai releases。
# -----------------------------------------------------------------------------
typeset -ga BREWUP_WATCH_GITHUB=(
  "Squirrel|release|rime/squirrel"
  "Yabai|release|asmvik/yabai"
)

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
    # valgrind HEAD：若命中「Xcode too outdated」门禁，则 stash → 重试 → 恢复
    echo -e "${BOLD}001b: LouisBrunner/valgrind (fetch-HEAD, Xcode-outdated 可自动重试)${RESET}"
    _brew_with_xcode_outdated_retry upgrade --fetch-HEAD LouisBrunner/valgrind/valgrind

    echo -e "${BOLD}002: update rust${RESET}" | lolcat
    rustup update

    echo -e "${BOLD}002b: update Haskell / ghcup${RESET}" | lolcat
    _execute_ghcup_upgrades

    echo -e "${BOLD}003: update Apple container${RESET}" | lolcat
    sudo /usr/local/bin/update-container.sh

    #_execute_gpk_upgrades  #gpk更新环节
    _execute_system_upgrades  # topgrade 托管升级

    echo -e "${BOLD}005: GitHub 关注仓库新鲜度${RESET}" | lolcat
    _check_github_watch_freshness

    echo "更新完成"
}

# ==========================================
# 模块 1.0a：ghcup / Haskell 更新（按安装方式分支）
# ==========================================
# 检测优先级：
#   1) PATH 上的 ghcup 落在 Homebrew 前缀，或 brew 已装 ghcup formula → brew upgrade
#   2) ~/.ghcup 官方引导安装（或 PATH 指向其中）→ ghcup upgrade（自更新）
#   3) 都找不到 → 跳过并提示
_brewup_detect_ghcup_method() {
    local bin=""
    bin="$(command -v ghcup 2>/dev/null || true)"
    if [[ -z "$bin" && -x "${HOME}/.ghcup/bin/ghcup" ]]; then
        bin="${HOME}/.ghcup/bin/ghcup"
    fi

    local brew_pref=""
    brew_pref="$(command brew --prefix 2>/dev/null || true)"
    local brew_has_formula=0
    if command brew list --formula ghcup &>/dev/null; then
        brew_has_formula=1
    fi

    if [[ -n "$bin" && -n "$brew_pref" && "$bin" == "${brew_pref}/"* ]]; then
        echo "brew"
        return 0
    fi
    if [[ -n "$bin" && "$bin" == *'/.ghcup/'* ]]; then
        echo "official"
        return 0
    fi
    if (( brew_has_formula )); then
        echo "brew"
        return 0
    fi
    if [[ -n "$bin" || -x "${HOME}/.ghcup/bin/ghcup" ]]; then
        echo "official"
        return 0
    fi
    echo "missing"
    return 1
}

_execute_ghcup_upgrades() {
    local BOLD="\e[1m"
    local RESET="\e[0m"
    local method
    method="$(_brewup_detect_ghcup_method)" || true

    case "$method" in
        brew)
            echo -e "检测到 ghcup 安装方式: ${BOLD}Homebrew formula${RESET} → brew upgrade ghcup"
            command brew upgrade ghcup || echo "brew upgrade ghcup 失败（可稍后重试）"
            ;;
        official)
            local bin="${HOME}/.ghcup/bin/ghcup"
            command -v ghcup &>/dev/null && bin="$(command -v ghcup)"
            echo -e "检测到 ghcup 安装方式: ${BOLD}官方 ~/.ghcup（引导脚本）${RESET} → ghcup upgrade"
            # 自更新 ghcup；失败时给出官方重装提示（不自动 curl | sh）
            if ! "$bin" upgrade; then
                echo "ghcup upgrade 失败。若为 macOS 动态链接问题，可参考官方："
                echo "  curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=yes BOOTSTRAP_HASKELL_MINIMAL=yes sh"
            fi
            # 顺带刷新已安装工具元数据视图（list 会拉元数据；不强制装新 GHC）
            "$bin" list >/dev/null 2>&1 || true
            ;;
        *)
            echo "未检测到 ghcup，跳过 Haskell 工具链更新。"
            ;;
    esac
}

# ==========================================
# 模块 1.0b：Homebrew「Xcode too outdated」门禁
# 根因（见 suchaharcan 博客）：Homebrew 用 mdfind + bundle id 找 Xcode，
# 即便 xcode-select 已指向 CLT，旧 Xcode.app 仍会被扫到并 fatal。
# 对策：命中特征文案 → 移入永不索引的 /opt/xcode-stash → 重试 brew → 恢复。
# 判定绝不写死 Xcode/系统版本号，只认错误文案特征。
# ==========================================
_brew_error_is_outdated_xcode() {
    local log="$1"
    # 官方提示里的稳定锚点（版本号可变，文案结构相对稳定）
    if [[ "$log" == *"Xcode can be updated from"* ]]; then
        return 0
    fi
    if [[ "$log" == *"is too outdated"* && "$log" == *"Xcode"* ]]; then
        return 0
    fi
    if [[ "$log" == *"Please update to Xcode"* ]]; then
        return 0
    fi
    if [[ "$log" == *"Your Xcode"* && "$log" == *"or delete it"* ]]; then
        return 0
    fi
    return 1
}

_brew_xcode_list_apps() {
    # Spotlight 按 bundle id；再并上 /Applications 下名称匹配（不依赖版本数字）
    local -a found=()
    local p
    while IFS= read -r p; do
        [[ -n "$p" && -d "$p" ]] && found+=("$p")
    done < <(mdfind 'kMDItemCFBundleIdentifier == "com.apple.dt.Xcode"' 2>/dev/null)

    for p in /Applications/Xcode*.app(N); do
        [[ -d "$p" ]] || continue
        local dup=0
        local f
        for f in "${found[@]}"; do
            [[ "$f" == "$p" ]] && dup=1 && break
        done
        (( dup == 0 )) && found+=("$p")
    done

    print -l -- "${found[@]}"
}

_brew_xcode_stash() {
    local BOLD="\e[1m"
    local RESET="\e[0m"
    local clt="/Library/Developer/CommandLineTools"

    if [[ ! -d "$clt" ]]; then
        echo -e "${BOLD}无法 stash Xcode：未找到 Command Line Tools（$clt）${RESET}"
        return 1
    fi

    echo -e "${BOLD}[Xcode-stash] 临时移开 Spotlight 可见的 Xcode，以绕过 Homebrew 过旧检查…${RESET}"
    echo "参考: https://suchaharcan.github.io/02Engineer_blog_Debug/homebrew-xcode-early-macos/"

    sudo mkdir -p "${_BREWUP_XCODE_STASH_DIR}"
    sudo touch "${_BREWUP_XCODE_STASH_DIR}/.metadata_never_index"
    # 清空映射表（本次 stash 会话）
    print -n '' | sudo tee "${_BREWUP_XCODE_STASH_MAP}" >/dev/null

    _BREWUP_XCODE_SELECT_SAVED="$(xcode-select -p 2>/dev/null || true)"

    local app base dest i=0
    while IFS= read -r app; do
        [[ -d "$app" ]] || continue
        # 已在 stash 目录内则跳过
        [[ "$app" == "${_BREWUP_XCODE_STASH_DIR}/"* ]] && continue
        base="$(basename "$app")"
        dest="${_BREWUP_XCODE_STASH_DIR}/${base}"
        # 目标已存在则加序号，避免覆盖
        while [[ -e "$dest" ]]; do
            i=$((i + 1))
            dest="${_BREWUP_XCODE_STASH_DIR}/${base%.app}-$i.app"
        done
        echo "  stash: $app → $dest"
        if ! sudo mv "$app" "$dest"; then
            echo "  移动失败: $app"
            continue
        fi
        echo "${app}|${dest}" | sudo tee -a "${_BREWUP_XCODE_STASH_MAP}" >/dev/null
    done < <(_brew_xcode_list_apps)

    sudo xcode-select -s "$clt"

    # 验收：mdfind 应为空；若仍有残留，提示人工处理
    local leftover
    leftover="$(mdfind 'kMDItemCFBundleIdentifier == "com.apple.dt.Xcode"' 2>/dev/null || true)"
    if [[ -n "$leftover" ]]; then
        echo -e "${BOLD}[Xcode-stash] 警告：mdfind 仍能看到 Xcode：${RESET}"
        echo "$leftover"
        echo "可尝试: sudo mdutil -E ${_BREWUP_XCODE_STASH_DIR}"
        return 1
    fi
    echo "[Xcode-stash] mdfind 已空；xcode-select → $clt"
    return 0
}

_brew_xcode_restore() {
    local BOLD="\e[1m"
    local RESET="\e[0m"

    if [[ ! -f "${_BREWUP_XCODE_STASH_MAP}" ]]; then
        return 0
    fi

    echo -e "${BOLD}[Xcode-restore] 将 Xcode 移回原路径…${RESET}"
    local line orig dest
    # 倒序恢复更稳妥
    local -a lines=("${(@f)$(<"${_BREWUP_XCODE_STASH_MAP}" 2>/dev/null)}")
    local idx
    for (( idx=${#lines[@]}; idx>=1; idx-- )); do
        line="${lines[$idx]}"
        [[ -z "$line" || "$line" != *"|"* ]] && continue
        orig="${line%%|*}"
        dest="${line#*|}"
        if [[ -d "$dest" ]]; then
            echo "  restore: $dest → $orig"
            sudo mkdir -p "$(dirname "$orig")"
            sudo mv "$dest" "$orig" || echo "  恢复失败: $dest"
        fi
    done

    if [[ -n "${_BREWUP_XCODE_SELECT_SAVED}" && -d "${_BREWUP_XCODE_SELECT_SAVED}" ]]; then
        sudo xcode-select -s "${_BREWUP_XCODE_SELECT_SAVED}" || true
    elif [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer || true
    fi

    sudo rm -f "${_BREWUP_XCODE_STASH_MAP}"
    _BREWUP_XCODE_SELECT_SAVED=""
    echo "[Xcode-restore] 完成；当前: $(xcode-select -p 2>/dev/null)"
}

# 运行 brew 子命令；若日志命中「过旧 Xcode」门禁则 stash → 重试一次 → 始终 restore
_brew_with_xcode_outdated_retry() {
    local BOLD="\e[1m"
    local RESET="\e[0m"
    local log
    log="$(mktemp -t brewup_xcode)"
    local rc=0
    local stashed=0

    # 必须走 command brew，避免递归进本文件的 brew() 包装
    setopt local_options pipefail 2>/dev/null || true
    command brew "$@" 2>&1 | tee "$log"
    rc=${pipestatus[1]:-$?}

    if (( rc != 0 )) && _brew_error_is_outdated_xcode "$(cat "$log")"; then
        echo -e "${BOLD}检测到 Homebrew「Xcode 过旧」拦截（文案特征匹配，未写死版本号）。${RESET}"
        if _brew_xcode_stash; then
            stashed=1
            # 中断时也尽量恢复
            trap '_brew_xcode_restore; trap - EXIT INT TERM' EXIT INT TERM
            echo -e "${BOLD}重试: brew $*${RESET}"
            command brew "$@"
            rc=$?
            _brew_xcode_restore
            stashed=0
            trap - EXIT INT TERM
        else
            echo "stash 未成功，跳过重试。请按博客手动处理后再执行。"
        fi
    fi

    rm -f "$log"
    return $rc
}

# ==========================================
# 模块 1.0c：GitHub 关注仓库「距今天数」
# ==========================================
_brewup_parse_iso_to_epoch() {
    # 输入: 2024-01-15T12:34:56Z 或带偏移；输出 unix epoch（macOS date）
    local iso="$1"
    iso="${iso%Z}"
    iso="${iso%%+*}"
    iso="${iso%%.*}"
    # 2024-01-15T12:34:56 → 替换 T 为空格
    local norm="${iso/T/ }"
    date -j -u -f "%Y-%m-%d %H:%M:%S" "$norm" +%s 2>/dev/null || \
        date -j -u -f "%Y-%m-%d %H:%M:%S" "${norm}:00" +%s 2>/dev/null || \
        echo 0
}

_brewup_github_atom_timestamp() {
    # Atom 回退（无 API token / 遇 403 时）
    local kind="$1"
    local repo="$2"
    local repo_path="${3:-}"
    local curl_bin="${_BREWUP_CURL_BIN:-/usr/bin/curl}"
    local -a urls=()
    local url xml ts

    case "$kind" in
        release)
            urls+=("https://github.com/${repo}/releases.atom")
            ;;
        commits)
            if [[ -n "$repo_path" ]]; then
                urls+=(
                    "https://github.com/${repo}/commits/master/${repo_path}.atom"
                    "https://github.com/${repo}/commits/main/${repo_path}.atom"
                    "https://github.com/${repo}/commits/master/${repo_path}.rb.atom"
                    "https://github.com/${repo}/commits/main/${repo_path}.rb.atom"
                )
            else
                urls+=(
                    "https://github.com/${repo}/commits/master.atom"
                    "https://github.com/${repo}/commits/main.atom"
                )
            fi
            ;;
        *)
            return 1
            ;;
    esac

    for url in "${urls[@]}"; do
        xml="$("$curl_bin" -fsSL -A 'brew_update.zsh' "$url" 2>/dev/null)" || continue
        ts="$(print -r -- "$xml" | grep -oE '<updated>[^<]+</updated>' | head -n 1 | sed -E 's/<\/?updated>//g')"
        if [[ -n "$ts" ]]; then
            print -r -- "$ts"
            return 0
        fi
    done
    return 1
}

_brewup_github_latest_timestamp() {
    # stdout: ISO 时间；参数: kind owner/repo [repo_path]
    local kind="$1"
    local repo="$2"
    local repo_path="${3:-}"
    local url json ts="" http_body
    local curl_bin="${_BREWUP_CURL_BIN:-/usr/bin/curl}"
    [[ -x "$curl_bin" ]] || curl_bin=/usr/bin/curl
    local jq_bin="${_BREWUP_JQ_BIN:-jq}"
    local -a auth_hdr=()
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    [[ -n "$token" ]] && auth_hdr=(-H "Authorization: Bearer ${token}")

    case "$kind" in
        release)
            url="https://api.github.com/repos/${repo}/releases/latest"
            json="$("$curl_bin" -fsSL -A 'brew_update.zsh' \
                -H 'Accept: application/vnd.github+json' \
                "${auth_hdr[@]}" "$url" 2>/dev/null)" || json=""
            if [[ -n "$json" ]]; then
                ts="$(print -r -- "$json" | "$jq_bin" -r '.published_at // .created_at // empty' 2>/dev/null)"
            fi
            ;;
        commits)
            if [[ -n "$repo_path" ]]; then
                url="https://api.github.com/repos/${repo}/commits?path=${repo_path}&per_page=1"
            else
                url="https://api.github.com/repos/${repo}/commits?per_page=1"
            fi
            json="$("$curl_bin" -fsSL -A 'brew_update.zsh' \
                -H 'Accept: application/vnd.github+json' \
                "${auth_hdr[@]}" "$url" 2>/dev/null)" || json=""
            if [[ -n "$json" ]]; then
                ts="$(print -r -- "$json" | "$jq_bin" -r '.[0].commit.committer.date // .[0].commit.author.date // empty' 2>/dev/null)"
            fi
            ;;
        *)
            return 1
            ;;
    esac

    if [[ -z "$ts" || "$ts" == "null" ]]; then
        ts="$(_brewup_github_atom_timestamp "$kind" "$repo" "$repo_path")" || return 1
    fi
    print -r -- "$ts"
}

_check_github_watch_freshness() {
    local BOLD="\e[1m"
    local RESET="\e[0m"
    local now_ts entry name kind repo repo_path iso epoch days
    local curl_bin=""
    local jq_bin=""

    # 勿用局部变量名 path（zsh 中 path 与 PATH 联动）
    if [[ -x /usr/bin/curl ]]; then
        curl_bin=/usr/bin/curl
    elif command -v curl &>/dev/null; then
        curl_bin="$(command -v curl)"
    else
        echo "需要 curl，跳过 GitHub 新鲜度检查。"
        return 1
    fi

    if command -v jq &>/dev/null; then
        jq_bin="$(command -v jq)"
    elif [[ -x /opt/homebrew/bin/jq ]]; then
        jq_bin=/opt/homebrew/bin/jq
    elif [[ -x /usr/local/bin/jq ]]; then
        jq_bin=/usr/local/bin/jq
    else
        echo "需要 jq，跳过 GitHub 新鲜度检查（brew install jq）。"
        return 1
    fi

    typeset -g _BREWUP_CURL_BIN="$curl_bin"
    typeset -g _BREWUP_JQ_BIN="$jq_bin"

    now_ts="$(date +%s)"
    echo -e "${BOLD}仓库最新活动距今（天）${RESET}"
    printf "%-18s %-10s %-28s %s\n" "名称" "方式" "最新时间(UTC)" "距今天数"
    printf "%-18s %-10s %-28s %s\n" "------------------" "----------" "----------------------------" "--------"

    for entry in "${BREWUP_WATCH_GITHUB[@]}"; do
        name="${entry%%|*}"
        local rest="${entry#*|}"
        kind="${rest%%|*}"
        rest="${rest#*|}"
        repo="${rest%%|*}"
        if [[ "$rest" == *"|"* ]]; then
            repo_path="${rest#*|}"
        else
            repo_path=""
        fi

        if ! iso="$(_brewup_github_latest_timestamp "$kind" "$repo" "$repo_path")"; then
            printf "%-18s %-10s %-28s %s\n" "$name" "$kind" "(查询失败)" "-"
            echo "  → https://github.com/${repo}${repo_path:+/tree/master/${repo_path}}"
            continue
        fi
        epoch="$(_brewup_parse_iso_to_epoch "$iso")"
        if [[ "$epoch" -eq 0 ]]; then
            days="?"
        else
            days=$(( (now_ts - epoch) / 86400 ))
        fi
        printf "%-18s %-10s %-28s %s\n" "$name" "$kind" "$iso" "${days} 天"
        case "$kind" in
            release) echo "  → https://github.com/${repo}/releases" ;;
            commits) echo "  → https://github.com/${repo}${repo_path:+/tree/master/${repo_path}}" ;;
        esac
    done
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
