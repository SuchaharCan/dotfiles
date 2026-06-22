# LLVM , Clang, CMake 等 C++编译工具链


# LLVM 核心配置
export LLVM_ROOT="/opt/homebrew/opt/llvm"
export BINUTILS_ROOT="/opt/homebrew/opt/binutils"
export PATH="$LLVM_ROOT/bin:$PATH"
export CC="$LLVM_ROOT/bin/clang"
export CXX="$LLVM_ROOT/bin/clang++"

# 修正 LDFLAGS 和 CPPFLAGS 累加，防止覆盖
# 3. LDFLAGS 累加 (注意：新路径放在最前面)
export LDFLAGS="-L$LLVM_ROOT/lib/c++ -L$LLVM_ROOT/lib/unwind -lunwind $LDFLAGS"
export LDFLAGS="-L$LLVM_ROOT/lib -L$BINUTILS_ROOT/lib -L$RUBY_ROOT/lib $LDFLAGS"

# 4. CPPFLAGS 累加
export CPPFLAGS="-I$LLVM_ROOT/include -I$BINUTILS_ROOT/include -I$RUBY_ROOT/include $CPPFLAGS"
export CPPFLAGS="-D_LIBCPP_DISABLE_AVAILABILITY $CPPFLAGS"


export CMAKE_PREFIX_PATH="$LLVM_ROOT:$CMAKE_PREFIX_PATH"
export VCPKG_ROOT="$HOME/vcpkg"
