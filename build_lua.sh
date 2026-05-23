#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

LUA_DIR="${SCRIPT_DIR}/libs/lua"

# CORE sources
CORE_SRC="lapi lcode lctype ldebug ldo ldump lfunc lgc llex lmem lobject lopcodes lparser lstate lstring ltable ltm lundump lvm lzio"

# LIB sources
LIB_SRC="lauxlib lbaselib lcorolib ldblib liolib lmathlib loadlib loslib lstrlib ltablib lutf8lib linit"

BASE_SRC="${CORE_SRC} ${LIB_SRC}"

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"

    INSTALL_DIR="${SCRIPT_DIR}/install/lua/${TARGET}"

    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/include"
    mkdir -p "${INSTALL_DIR}/lib"

    cp "${LUA_DIR}/lua.h" "${INSTALL_DIR}/include/"
    if [ -f "${LUA_DIR}/lua.hpp" ]; then
        cp "${LUA_DIR}/lua.hpp" "${INSTALL_DIR}/include/"
    fi
    cp "${LUA_DIR}/luaconf.h" "${INSTALL_DIR}/include/"
    cp "${LUA_DIR}/lauxlib.h" "${INSTALL_DIR}/include/"
    cp "${LUA_DIR}/lualib.h" "${INSTALL_DIR}/include/"

    cd "${LUA_DIR}"

    if [ "$ANDROID_ONLY" = true ]; then
        ANDROID_CC=$(GET_ANDROID_CC "${TARGET}")
        ANDROID_AR=$(GET_ANDROID_AR)
        CCFLAGS="-fPIC -O3 -Wall -Wextra $(GET_SSE4_1_FLAG "${TARGET}")"

        for file in ${BASE_SRC}; do
            "${ANDROID_CC}" -c ${file}.c ${CCFLAGS}
        done

        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        "${ANDROID_AR}" rcu liblua.a ${OBJ_FILES}
        "${NDK_TOOLCHAIN_DIR}/bin/llvm-ranlib" liblua.a
        cp liblua.a "${INSTALL_DIR}/lib/liblua.a"
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        CCFLAGS="-fPIC -O3 -Wall -Wextra --target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"

        for file in ${BASE_SRC}; do
            clang -c ${file}.c ${CCFLAGS}
        done

        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        ar rcu liblua.a ${OBJ_FILES}
        ranlib liblua.a
        cp liblua.a "${INSTALL_DIR}/lib/liblua.a"
    elif [ "$WINDOWS_ONLY" = true ]; then
        CCFLAGS="-O2 $(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}") -MT"

        for file in ${BASE_SRC}; do
            clang-cl -c ${CCFLAGS} ${file}.c
        done

        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.obj"
        done
        llvm-lib /OUT:liblua.lib ${OBJ_FILES}
        cp liblua.lib "${INSTALL_DIR}/lib/liblua.lib"
    else
        CCFLAGS="-DLUA_USE_LINUX -fPIC -O3 -Wall -Wextra $(GET_SSE4_1_FLAG "${TARGET}")"

        for file in ${BASE_SRC}; do
            clang -c ${file}.c ${CCFLAGS}
        done

        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        ar rcu liblua.a ${OBJ_FILES}
        ranlib liblua.a
        cp liblua.a "${INSTALL_DIR}/lib/liblua.a"
    fi

    rm -f *.o *.obj *.a *.lib 2>/dev/null || true

    cd "${SCRIPT_DIR}"

    echo "lua 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
}

if [ "$ANDROID_ONLY" = true ]; then
    for i in "${!ANDROIDS[@]}"; do
        TARGET="${ANDROIDS[$i]}"
        echo "=========================================="
        echo "타겟: ${TARGET} ${ANDROID_ARCH[$i]}"
        echo "=========================================="

        build_target "${TARGET}" "${ANDROID_ARCH[$i]}"
    done
elif [ "$WINDOWS_ONLY" = true ]; then
    echo "=========================================="
    echo "타겟: ${WINDOWS_TARGET}"
    echo "=========================================="
    build_target "${WINDOWS_TARGET}" ""
else
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="

        build_target "${TARGET}" ""
    done
fi

echo "=========================================="
echo "모든 타겟 설치 완료!"
echo "=========================================="
