# Jai 编译工具链

# ---------------------------------------------------------------------------
# 背景（Mac27 / 2026-07-17）
# - Jai Leak 版，解压即用；macOS 可执行文件 jai-macos（bin/jai 已链）
# - 链接硬编码：-syslibroot .../Xcode.app/.../MacOSX.sdk
#   仅设 MACOS_SDK_PATH 不能消除 library not found for -lc
# - 已卸 Xcode-beta：默认用 Command Line Tools SDK 做过渡软链
# - 正式 Xcode.app 装好后：自动检测并跳过软链，不干扰官方安装
# - 详解：$Jai_ROOT/macOS_环境配置说明.md
# ---------------------------------------------------------------------------

export Jai_ROOT="/Users/songhoujin/Jai"
export PATH="$Jai_ROOT/bin:$PATH"

# Jai 硬编码期望的 SDK 路径（链接阶段真正用这个）
export JAI_SYSLIBROOT="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
# 我们造的「假 Xcode.app」标记文件（正式版不会有这个）
JAI_SDK_STUB_MARKER="/Applications/Xcode.app/.jai-sdk-stub"

# 是否已安装「真正的」正式/完整 Xcode.app（有 xcodebuild 即视为真）
jai_has_real_xcode() {
  [[ -x /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild ]]
}

# 默认 SDK 源：CLT（xcrun）；可用环境变量覆盖
# 例：JAI_SDK_SOURCE=/path/to/MacOSX.sdk
JAI_SDK_SOURCE="${JAI_SDK_SOURCE:-$(xcrun --show-sdk-path 2>/dev/null)}"

# ---------------------------------------------------------------------------
# 【方案 B·过渡】无正式 Xcode 时，把 CLT SDK 软链到 Jai 硬编码路径
# 正式 Xcode 存在时整段跳过 → 不影响后续 Mac27 正式版
# ---------------------------------------------------------------------------
if jai_has_real_xcode; then
  # 正式 Xcode 已在位：不创建/不改写软链
  :
elif [[ -n "$JAI_SDK_SOURCE" && -d "$JAI_SDK_SOURCE" ]]; then
  # 目标缺失，或软链已断（例如卸了 Xcode-beta）→ 重建
  if [[ ! -e "$JAI_SYSLIBROOT" ]]; then
    mkdir -p "$(dirname "$JAI_SYSLIBROOT")" 2>/dev/null && \
      ln -sfn "$JAI_SDK_SOURCE" "$JAI_SYSLIBROOT" 2>/dev/null && \
      touch "$JAI_SDK_STUB_MARKER" 2>/dev/null
  fi
fi

# bindings / 生成脚本用；链接仍看 JAI_SYSLIBROOT
if [[ -e "$JAI_SYSLIBROOT" ]]; then
  export MACOS_SDK_PATH="${MACOS_SDK_PATH:-$JAI_SYSLIBROOT}"
else
  export MACOS_SDK_PATH="${MACOS_SDK_PATH:-$(xcrun --show-sdk-path 2>/dev/null)}"
fi

# 手动重建软链：jai-sdk-link [可选 SDK 源路径]
# 正式 Xcode 在位时拒绝改写，避免破坏官方树
jai-sdk-link() {
  local target_dir source
  if jai_has_real_xcode; then
    echo "[jai-sdk-link] 检测到正式 Xcode.app，跳过软链（无需方案 B）" >&2
    echo "[jai-sdk-link] SDK: $(xcrun --show-sdk-path 2>/dev/null)"
    return 0
  fi
  target_dir="$(dirname "$JAI_SYSLIBROOT")"
  source="${1:-$JAI_SDK_SOURCE}"
  if [[ ! -d "$source" ]]; then
    echo "[jai-sdk-link] SDK 源不存在: $source" >&2
    return 1
  fi
  mkdir -p "$target_dir" || {
    echo "[jai-sdk-link] mkdir 失败，可试: sudo mkdir -p $target_dir" >&2
    return 1
  }
  ln -sfn "$source" "$JAI_SYSLIBROOT" || {
    echo "[jai-sdk-link] ln 失败，可试: sudo ln -sfn $source $JAI_SYSLIBROOT" >&2
    return 1
  }
  touch "$JAI_SDK_STUB_MARKER" 2>/dev/null || true
  echo "[jai-sdk-link] $JAI_SYSLIBROOT -> $source"
  ls -la "$JAI_SYSLIBROOT"
}

# 卸掉我们造的假 Xcode.app 骨架（装正式版前执行）
# 用法：jai-sdk-unstub
jai-sdk-unstub() {
  if jai_has_real_xcode; then
    echo "[jai-sdk-unstub] 当前是正式 Xcode，拒绝删除" >&2
    return 1
  fi
  if [[ ! -e "$JAI_SDK_STUB_MARKER" && ! -L "$JAI_SYSLIBROOT" ]]; then
    echo "[jai-sdk-unstub] 未发现 .jai-sdk-stub 标记，请手动确认后再删 /Applications/Xcode.app" >&2
    return 1
  fi
  echo "[jai-sdk-unstub] 删除方案 B 骨架: /Applications/Xcode.app"
  rm -rf /Applications/Xcode.app
  echo "[jai-sdk-unstub] OK。然后安装正式 Xcode，并执行:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
}

# ---------------------------------------------------------------------------
# 【方案 A·正式 Xcode 发布后】（一次性，不要放进每次 source）
#   jai-sdk-unstub          # 若仍是方案 B 骨架
#   # 再安装 App Store / 开发者站正式 Xcode.app
#   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
#   sudo xcodebuild -license accept
# 之后本文件方案 B 会因 jai_has_real_xcode 自动跳过，无需改 PATH/Jai_ROOT
# ---------------------------------------------------------------------------
