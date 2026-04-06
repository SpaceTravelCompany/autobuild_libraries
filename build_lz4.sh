#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

LZ4_DIR="${SCRIPT_DIR}/libs/lz4"
LZ4_CMAKE_DIR="${LZ4_DIR}/build/cmake"

if [ ! -f "${LZ4_CMAKE_DIR}/CMakeLists.txt" ]; then
    echo "Initializing lz4 submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive libs/lz4
fi

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"

    BUILD_DIR="${SCRIPT_DIR}/build/lz4/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/lz4/${TARGET}"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"

    cd "${BUILD_DIR}"

    CMAKE_ARGS=(
        "${LZ4_CMAKE_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="-fPIC --target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}") $(GET_SSE4_1_FLAG "${TARGET}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DBUILD_STATIC_LIBS=ON
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
            -DCMAKE_C_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_C_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        LW="$(GET_LINUX_CROSS_LINKER_WRAPPER_FLAGS)"
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC --target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
            -DBUILD_STATIC_LIBS=ON
            -DBUILD_SHARED_LIBS=ON
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
            -DCMAKE_C_FLAGS="$(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}")"
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
            -DBUILD_STATIC_LIBS=ON
            -DBUILD_SHARED_LIBS=ON
        )
    else
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC $(GET_SSE4_1_FLAG "${TARGET}")"
            -DBUILD_STATIC_LIBS=ON
            -DBUILD_SHARED_LIBS=ON
        )
    fi

    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}"))
    elif [ "$WINDOWS_ONLY" != true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=clang)
    fi

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"
    cmake --build . --config Release -j$(nproc)
    cmake --install .

    echo "lz4 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
    echo ""
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
