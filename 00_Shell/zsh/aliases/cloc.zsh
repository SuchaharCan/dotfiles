#                                    cloc 代码行数统计
# 官方配置：https://github.com/AlDanial/cloc#optionstxt-configuration-file
# 默认过滤 LLVM/Clang++/GCC/Rust/.NET 等编译中间产物（尤其是 *.d 依赖文件，避免误判为 D 语言）

_CLOC_BIN="${commands[cloc]:-/opt/homebrew/bin/cloc}"
_CLOC_CFG="${HOME}/.config/cloc/options.txt"

# 无配置文件时的回退过滤（与 options.txt 保持一致的核心后缀/目录）
_CLOC_EXCLUDE_EXT='o,obj,a,lib,so,dylib,dll,exe,pdb,ilk,idb,iobj,ipdb,bc,ll,s,d,gch,pch,mod,pcm,rlib,rmeta,pyc,pyo,class,suo,ncb,exp,map,tlog,lastbuildstate,recipe,rsp'
_CLOC_EXCLUDE_DIR='target,build,Build,BUILD,out,Out,bin,obj,Debug,Release,RelWithDebInfo,MinSizeRel,x64,x86,Win32,CMakeFiles,CMakeScripts,cmake-build-debug,cmake-build-release,cmake-build-relwithdebinfo,cmake-build-minsizerel,.deps,.libs,autom4te.cache,DerivedData,.build,Pods,node_modules,.next,dist,coverage,__pycache__,.venv,venv,.gradle,.cache,artifacts,TestResults'

cloc() {
  if [[ ! -x "$_CLOC_BIN" ]] && ! command -v "$_CLOC_BIN" >/dev/null 2>&1; then
    echo "cloc 未找到：请先 brew install cloc" >&2
    return 127
  fi

  # 1) 有官方 options.txt → 走 --config（过滤机制）
  # 2) 否则 → 命令行 --exclude-ext / --exclude-dir 回退
  if [[ -f "$_CLOC_CFG" ]]; then
    "$_CLOC_BIN" --config "$_CLOC_CFG" "$@"
  else
    "$_CLOC_BIN" \
      --exclude-ext="$_CLOC_EXCLUDE_EXT" \
      --exclude-dir="$_CLOC_EXCLUDE_DIR" \
      --fullpath \
      --not-match-d='cmake-build' \
      "$@"
  fi
}
