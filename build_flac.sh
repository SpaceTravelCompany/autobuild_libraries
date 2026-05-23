#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

FLAC_DIR="${SCRIPT_DIR}/libs/flac"

if [ ! -f "${FLAC_DIR}/CMakeLists.txt" ]; then
    echo "Initializing flac submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive libs/flac
fi

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "Building: ${TARGET}"
    echo "----------------------------------------"

    BUILD_DIR="${SCRIPT_DIR}/build/flac/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/flac/${TARGET}"
    OGG_INSTALL_DIR="${SCRIPT_DIR}/install/ogg/${TARGET}"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"

    cd "${BUILD_DIR}"

    CMAKE_ARGS=(
        "${FLAC_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_TESTING=OFF
        -DBUILD_PROGRAMS=OFF
        -DBUILD_EXAMPLES=OFF
        -DBUILD_CXXLIBS=OFF
        -DBUILD_DOCS=OFF
        -DBUILD_DOXYGEN=OFF
        -DBUILD_UTILS=OFF
        -DWITH_OGG=ON
        -DINSTALL_MANPAGES=OFF
        -DCMAKE_PREFIX_PATH="${OGG_INSTALL_DIR}"
        -DOGG_ROOT="${OGG_INSTALL_DIR}"
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="-fPIC --target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}") $(GET_SSE4_1_FLAG "${TARGET}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
            -DCMAKE_C_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_C_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        LW="$(GET_LINUX_CROSS_LINKER_WRAPPER_FLAGS)"
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC --target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
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
        )
    else
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC $(GET_SSE4_1_FLAG "${TARGET}")"
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

    echo "flac build complete (${TARGET}): ${INSTALL_DIR}"
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
    echo "=========================================="
    echo "Target: ${WINDOWS_TARGET}"
    echo "=========================================="
    build_target "${WINDOWS_TARGET}" ""
else
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "Target: ${TARGET}"
        echo "=========================================="

        build_target "${TARGET}" ""
    done
fi
