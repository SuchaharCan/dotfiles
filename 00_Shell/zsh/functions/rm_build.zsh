# 无参/通配清理构建产物
# 场景：C++/CMake 构建目录清理。仅当「当前路径」含 build 子串时才删除
# （如 .../build、.../build.ninja），避免误删源码树。
# 更新位置：~/dotfiles/00_Shell/zsh/functions/rm_build.zsh → 同步到 ~/.zsh/functions/

rm_build() {
  set +f # opposite of set -f（alias rmbuild 侧会先 set -f 传入字面量 *）
  setopt local_options null_glob

  local current_dir
  current_dir="${PWD:A}"

  # 路径须含 build（目录名 build、build.ninja、mybuild 等均符合）
  if [[ "$current_dir" != *build* ]]; then
    print -u2 "当前目录路径中不包含 'build'（例如 .../build、.../build.ninja），不执行删除。"
    return 1
  fi

  local -a items
  if (( $# == 0 )) || { (( $# == 1 )) && [[ "$1" == '*' ]]; }; then
    items=( * )
  else
    items=( "$@" )
  fi

  if (( ${#items} == 0 )); then
    echo "无可删除的构建产物。"
    return 0
  fi

  echo "删除:"
  local item
  for item in "${items[@]}"; do
    echo "$item"
  done
  /bin/rm -rf -- "${items[@]}"
}
