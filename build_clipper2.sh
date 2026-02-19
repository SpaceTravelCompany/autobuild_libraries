#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

CLIPPER2_DIR="${SCRIPT_DIR}/libs/Clipper2/CPP"

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "Building: ${TARGET}"
    echo "----------------------------------------"

    BUILD_DIR="${SCRIPT_DIR}/build/clipper2/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/clipper2/${TARGET}"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"

    cd "${BUILD_DIR}"

    CMAKE_ARGS=(
        "${CLIPPER2_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DCLIPPER2_UTILS=OFF
        -DCLIPPER2_EXAMPLES=OFF
        -DCLIPPER2_TESTS=OFF
        -DBUILD_SHARED_LIBS=OFF
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}") $(GET_SSE4_1_FLAG "${TARGET}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS}${ANDROID_CXX_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        CMAKE_ARGS+=(
            -DANDROID=ON
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DCMAKE_CXX_FLAGS="${CCFLAGS}"
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="--target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
            -DCMAKE_CXX_FLAGS="--target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
        )
    elif [ "$WINDOWS_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang-cl
            -DCMAKE_CXX_COMPILER=clang-cl
            -DCMAKE_C_FLAGS="-msse4.1 -fms-runtime-lib=static"
            -DCMAKE_CXX_FLAGS="-msse4.1 -fms-runtime-lib=static /EHsc" # /EHsc is MSVC exception handling flag
        )
    fi

    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}")
            -DCMAKE_CXX_COMPILER=$(GET_ANDROID_CXX "${TARGET}")
        )
    elif [ "$WINDOWS_ONLY" != true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
            -DCMAKE_CXX_COMPILER=clang++
        )
    fi

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"
    cmake --build . --config Release -j$(nproc)
    cmake --install .

    echo "Clipper2 build done (${TARGET}): ${INSTALL_DIR}"
    echo ""
}

if [ "$ANDROID_ONLY" = true ]; then
    for i in "${!ANDROIDS[@]}"; do
        TARGET="${ANDROIDS[$i]}"
        echo "=========================================="
        echo "Target: ${TARGET} ${ANDROID_ARCH[$i]}"
        echo "=========================================="
        build_target "${TARGET}" "${ANDROID_ARCH[$i]}"
    done
elif [ "$WINDOWS_ONLY" = true ]; then
    for TARGET in "${WINDOWS_TARGETS[@]}"; do
        echo "=========================================="
        echo "Target: ${TARGET}"
        echo "=========================================="
        build_target "${TARGET}" ""
    done
else
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "Target: ${TARGET}"
        echo "=========================================="
        build_target "${TARGET}" ""
    done
fi
