#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

WEBP_DIR="${SCRIPT_DIR}/libs/libwebp"

# 빌드 함수
build_target() {
    local TARGET=$1
    local BUILD_TYPE=$2
    local ANDROID_ARCH=$3

    BUILD_SHARED_STATIC="OFF"
    if [ "$BUILD_TYPE" = "shared" ]; then
        BUILD_SHARED_STATIC="ON" 
    fi
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/webp/${TARGET}-${BUILD_TYPE}"
    INSTALL_DIR="${SCRIPT_DIR}/install/webp/${TARGET}-${BUILD_TYPE}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"

    
    # CMake 설정
    CMAKE_ARGS=(
        "${WEBP_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DWEBP_BUILD_ANIM_UTILS=OFF
        -DWEBP_BUILD_CWEBP=OFF
        -DWEBP_BUILD_DWEBP=OFF
        -DWEBP_BUILD_GIF2WEBP=OFF
        -DWEBP_BUILD_IMG2WEBP=OFF
        -DWEBP_BUILD_VWEBP=OFF
        -DWEBP_BUILD_WEBPMUX=OFF
        -DWEBP_BUILD_WEBPINFO=OFF
        -DWEBP_BUILD_EXTRAS=OFF
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CMAKE_C_LINKER_WRAPPER_FLAG+=" -Wl,-z,max-page-size=16384"
        fi

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="--target=${TARGET}"
            -DBUILD_SHARED_LIBS=${BUILD_SHARED_STATIC}
        )
    else
        CMAKE_ARGS+=(
            -DBUILD_SHARED_LIBS=${BUILD_SHARED_STATIC}
        )
    fi
    
    # Use Clang on all platforms (Linux and Windows)
    CMAKE_ARGS+=(
        -DCMAKE_C_COMPILER=clang
    )

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "libwebp 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
    echo ""
}

# 각 타겟에 대해 빌드
if [ "$ANDROID_ONLY" = true ]; then
    for i in "${!ANDROIDS[@]}"; do
        TARGET="${ANDROIDS[$i]}"
        echo "=========================================="
        echo "타겟: ${TARGET} ${ANDROID_ARCH[$i]}"
        echo "=========================================="
        
        build_target "${TARGET}" "static" "${ANDROID_ARCH[$i]}"
    done
elif [ "$WINDOWS_ONLY" = true ]; then
    for TARGET in "${WINDOWS_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        
        # 공유 라이브러리 빌드
        build_target "${TARGET}" "shared" ""
        
        # 정적 라이브러리 빌드
        build_target "${TARGET}" "static" ""
    done
else
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        
         # 공유 라이브러리 빌드
        build_target "${TARGET}" "shared" ""
        
        # 정적 라이브러리 빌드
        build_target "${TARGET}" "static" ""
    done
fi
