#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

# LUA_SEONGJUN 플래그 설정
LUA_SEONGJUN_FLAG=""
lua_seongjun() {
    if [ "$1" == "-s" ]; then
        LUA_SEONGJUN_FLAG="-DLUA_SEONGJUN"
    fi
}
lua_seongjun "$2"

LUA_DIR="${SCRIPT_DIR}/libs/lua/src"

# CORE 소스 파일 목록
CORE_SRC="lapi lcode lctype ldebug ldo ldump lfunc lgc llex lmem lobject lopcodes lparser lstate lstring ltable ltm lundump lvm lzio"

# LIB 소스 파일 목록
LIB_SRC="lauxlib lbaselib lcorolib ldblib liolib lmathlib loadlib loslib lstrlib ltablib lutf8lib linit"

# BASE_SRC = CORE_SRC + LIB_SRC
BASE_SRC="${CORE_SRC} ${LIB_SRC}"

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET} ${LUA_SEONGJUN_FLAG}"
    echo "----------------------------------------"
    
    INSTALL_DIR="${SCRIPT_DIR}/install/lua/${TARGET}"
    if [ "$LUA_SEONGJUN_FLAG" == "-DLUA_SEONGJUN" ]; then
        INSTALL_DIR="${SCRIPT_DIR}/install/lua_seongjun/${TARGET}"   
    fi
    
    # 설치 디렉토리 생성
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/include"
    mkdir -p "${INSTALL_DIR}/lib"
    
    # 헤더 파일 복사
    cp "${LUA_DIR}/lua.h" "${INSTALL_DIR}/include/"
    cp "${LUA_DIR}/lua.hpp" "${INSTALL_DIR}/include/"
    cp "${LUA_DIR}/luaconf.h" "${INSTALL_DIR}/include/"
    cp "${LUA_DIR}/lauxlib.h" "${INSTALL_DIR}/include/"
    cp "${LUA_DIR}/lualib.h" "${INSTALL_DIR}/include/"

    cd ${LUA_DIR}

    if [ "$ANDROID_ONLY" = true ]; then
        ANDROID_CC=$(GET_ANDROID_CC "${TARGET}")
        ANDROID_AR=$(GET_ANDROID_AR)
        CCFLAGS="${LUA_SEONGJUN_FLAG} -fPIC -O3 -Wall -Wextra $(GET_SSE4_1_FLAG "${TARGET}")"

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
        # 크로스 컴파일 (Linux)
        CCFLAGS="${LUA_SEONGJUN_FLAG} -fPIC -O3 -Wall -Wextra --target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
        
        for file in ${BASE_SRC}; do
            clang -c ${file}.c ${CCFLAGS}
        done

        # 정적 라이브러리 생성
        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        ar rcu liblua.a ${OBJ_FILES}
        ranlib liblua.a
        cp liblua.a "${INSTALL_DIR}/lib/liblua.a"
    elif [ "$WINDOWS_ONLY" = true ]; then
        # Windows build (clang-cl; windows=SSE4.1, windows-arm=--target=arm64-pc-windows-msvc)
        CCFLAGS="${LUA_SEONGJUN_FLAG} -O2 $(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}") -MT"

        for file in ${BASE_SRC}; do
            clang-cl -c ${CCFLAGS} ${file}.c
        done

        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.obj"
        done
        lib /OUT:liblua.lib ${OBJ_FILES}
        cp liblua.lib "${INSTALL_DIR}/lib/liblua.lib"
    else
        # 네이티브 빌드 (Linux)
        CCFLAGS="-DLUA_USE_LINUX ${LUA_SEONGJUN_FLAG} -fPIC -O3 -Wall -Wextra $(GET_SSE4_1_FLAG "${TARGET}")"
        
        for file in ${BASE_SRC}; do
            clang -c ${file}.c ${CCFLAGS}
        done

        # 정적 라이브러리 생성
        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        ar rcu liblua.a ${OBJ_FILES}
        ranlib liblua.a
        cp liblua.a "${INSTALL_DIR}/lib/liblua.a"
    fi

    # 정리
    rm -f *.o *.obj *.a *.lib 2>/dev/null || true

    cd ${SCRIPT_DIR}
    
    echo "lua 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
}

# 각 타겟에 대해 빌드
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
    # Linux 환경에서는 LINUX_TARGETS 사용
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
