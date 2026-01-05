#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

OPUSFILE_DIR="${SCRIPT_DIR}/libs/opusfile"


# 빌드 함수
build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/opusfile/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/opusfile/${TARGET}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    
    # CMake 설정
    CMAKE_ARGS=(
        "${OPUSFILE_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DOP_DISABLE_HTTP=ON
        -DOP_DISABLE_EXAMPLES=ON
        -DOP_DISABLE_DOCS=ON
        -DBUILD_SHARED_LIBS=OFF
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1 \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1/${ANDROID_ARCH} \
        -L${NDK_TOOLCHAIN_DIR}/sysroot/usr/lib/${ANDROID_ARCH} \
        -L${NDK_TOOLCHAIN_DIR}/sysroot/usr/lib/${ANDROID_ARCH}/35 \
        -lc -lm -ldl -llog -landroid"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CCFLAGS+=" -Wl,-z,max-page-size=16384"   
        fi

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
        )
    elif [ "$TARGET" != "native" ]; then
        if [ "${OS}" == "Windows_NT" ]; then
            CMAKE_ARGS+=(
                -DCMAKE_C_FLAGS="-MACHINE:${TARGET}"
            )
        else
            CMAKE_ARGS+=(
                -DCMAKE_C_FLAGS="--target=${TARGET}"
            )
        fi
    fi
    
    if [ "${OS}" == "Windows_NT" ]; then
        # Windows에서는 MSVC 사용, /MT 플래그 추가
        CMAKE_ARGS+=(
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
        )
    else
        # Windows가 아닐 때만 clang 설정
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
        )
    fi
    
    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "opusfile 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
    echo ""
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
elif [ "${OS}" == "Windows_NT" ] || [ -n "${MSYSTEM}" ]; then
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
