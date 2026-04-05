#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

OPUS_DIR="${SCRIPT_DIR}/libs/opus"

if [ ! -f "${OPUS_DIR}/CMakeLists.txt" ]; then
    echo "Initializing opus submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive libs/opus
fi

# 빌드 함수
build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/opus/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/opus/${TARGET}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # CMake 설정
    CMAKE_ARGS=(
        "${OPUS_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DOPUS_BUILD_TESTING=OFF
        -DOPUS_BUILD_PROGRAMS=OFF
        -DOPUS_BUILD_SHARED_LIBRARY=OFF
    )
    # opus는 런타임 CPU capability detection을 사용하므로
    # 타겟별 SIMD 컴파일 플래그(예: -msse4.1)를 강제로 주지 않는다.

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="-fPIC --target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CMAKE_ARGS+=(
                -DCOMPILER_SUPPORT_NEON=ON
                -DOPUS_MAY_HAVE_NEON=ON
            )   
        fi

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
            -DCMAKE_C_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_C_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        LW="$(GET_LINUX_CROSS_LINKER_WRAPPER_FLAGS)"
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC --target=${TARGET}"
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${LW}"
            -DCMAKE_CXX_LINKER_WRAPPER_FLAG="${LW}"
            -DCMAKE_EXE_LINKER_FLAGS="${LW}"
            -DCMAKE_SHARED_LINKER_FLAGS="${LW}"
            -DCMAKE_MODULE_LINKER_FLAGS="${LW}"
        )
    elif [ "$WINDOWS_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang-cl
            -DCMAKE_CXX_COMPILER=clang-cl
            -DCMAKE_C_FLAGS="$(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}")"
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
        )

        if [ "$TARGET" = "windows-arm" ]; then
            # clang-cl + ARM64 Windows에서는 RTCD(__emit 경로)가 깨질 수 있어
            # NEON을 가정하고 런타임 감지를 비활성화한다.
            CMAKE_ARGS+=(
                -DOPUS_MAY_HAVE_NEON=OFF
                -DOPUS_PRESUME_NEON=ON
            )
        fi
    else
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC"
        )
    fi
    
    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}"))
    elif [ "$WINDOWS_ONLY" != true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=clang)
    fi

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "opus 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
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
