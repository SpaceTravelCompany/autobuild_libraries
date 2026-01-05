#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

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
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    INSTALL_DIR="${SCRIPT_DIR}/install/lua/${TARGET}"
    
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
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1 \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1/${ANDROID_ARCH} \
        -DLUA_USE_LINUX \
        -fPIC -O2 -Wall -Wextra -lc -lm -ldl -llog -landroid"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CCFLAGS+=" -Wl,-z,max-page-size=16384"
        fi

        # 모든 소스 파일 컴파일
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
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        # 크로스 컴파일 (Linux)
        CCFLAGS="-DLUA_USE_LINUX -fPIC -O2 -Wall -Wextra --target=${TARGET}"
        
        # 모든 소스 파일 컴파일
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
        # Windows 빌드
        CCFLAGS="-DLUA_BUILD_AS_DLL -O2 -MT"
        
        # 모든 소스 파일 컴파일
        for file in ${BASE_SRC}; do
            cl -c ${CCFLAGS} ${file}.c
        done

        # 정적 라이브러리 생성
        OBJ_FILES=""
        for file in ${BASE_SRC}; do
            OBJ_FILES="${OBJ_FILES} ${file}.obj"
        done
        lib /OUT:liblua.lib ${OBJ_FILES}
        cp liblua.lib "${INSTALL_DIR}/lib/liblua.lib"
    else
        # 네이티브 빌드 (Linux)
        CCFLAGS="-DLUA_USE_LINUX -fPIC -O2 -Wall -Wextra"
        
        # 모든 소스 파일 컴파일
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
    # Windows 환경에서는 WINDOWS_TARGETS 사용
    for TARGET in "${WINDOWS_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        
        build_target "${TARGET}" ""
    done
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
