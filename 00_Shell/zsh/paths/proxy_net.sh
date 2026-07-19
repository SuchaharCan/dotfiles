# homebrew / vcpkg / curl 拉 GitHub 时走本机 Clash HTTP 代理
# 端口：系统设置 → 网络 → 详细信息 → 代理（M4 mini 当前为 17890）

# vcpkg 构建归档需要系统 ar（勿用 Homebrew binutils 的 GNU ar）
export AR=/usr/bin/ar
export VCPKG_ROOT="${VCPKG_ROOT:-$HOME/vcpkg}"

# Clash mixed 端口是 HTTP 代理，不是 SOCKS5。
# 切勿再设 all_proxy=socks5://127.0.0.1:17890 —— 与 http_proxy 并存时
#curl/vcpkg 会 SSL timeout（curl 35 / 28）。
#
#
# export http_proxy=http://127.0.0.1:17890
# export https_proxy=http://127.0.0.1:17890
# export HTTP_PROXY=http://127.0.0.1:17890
# export HTTPS_PROXY=http://127.0.0.1:17890
# export all_proxy=http://127.0.0.1:17890
# export ALL_PROXY=http://127.0.0.1:17890

# 本机回环不走代理
# export no_proxy=127.0.0.1,::1,localhost
# export NO_PROXY=127.0.0.1,::1,localhost
