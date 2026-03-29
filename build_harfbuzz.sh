#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

# --with-freetype / -f: build harfbuzz with freetype interop (needs freetype built first without harfbuzz)
HARFBUZZ_WITH_FREETYPE=false
for arg in "$@"; do
    case "$arg" in
        --with-freetype|-f) HARFBUZZ_WITH_FREETYPE=true ;;
    esac
done

HARFBUZZ_DIR="${SCRIPT_DIR}/libs/harfbuzz"

# Ensure submodule is initialized
if [ ! -f "${HARFBUZZ_DIR}/CMakeLists.txt" ]; then
    echo "Initializing harfbuzz submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive libs/harfbuzz
fi

# Build function (static lib only)
build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "Building: ${TARGET}"
    echo "----------------------------------------"

    BUILD_DIR="${SCRIPT_DIR}/build/harfbuzz/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/harfbuzz/${TARGET}"
    FREETYPE_INSTALL_DIR="${SCRIPT_DIR}/install/freetype-no-harfbuzz/${TARGET}"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"

    cd "${BUILD_DIR}"

    CMAKE_ARGS=(
        "${HARFBUZZ_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DBUILD_SHARED_LIBS=OFF
        -DHB_HAVE_CAIRO=OFF
        -DHB_HAVE_FREETYPE=$([ "$HARFBUZZ_WITH_FREETYPE" = true ] && echo ON || echo OFF)
        -DHB_HAVE_GLIB=OFF
        -DHB_HAVE_ICU=OFF
        -DHB_BUILD_UTILS=OFF
        -DHB_BUILD_SUBSET=ON
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
    )
    if [ "$HARFBUZZ_WITH_FREETYPE" = true ]; then
        CMAKE_ARGS+=(-DCMAKE_PREFIX_PATH="${FREETYPE_INSTALL_DIR}")
    fi

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}") $(GET_SSE4_1_FLAG "${TARGET}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DCMAKE_CXX_FLAGS="${CCFLAGS}"
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
            -DCMAKE_C_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_C_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
            -DCMAKE_CXX_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_CXX_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="--target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
            -DCMAKE_CXX_FLAGS="--target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
        )
    elif [ "$WINDOWS_ONLY" = true ]; then
        # HB_NO_MMAP: avoid FILE*/int mismatch on Windows (clang-cl) in hb-blob.cc mmap path
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang-cl
            -DCMAKE_CXX_COMPILER=clang-cl
            -DCMAKE_C_FLAGS="$(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}") -DHB_NO_MMAP"
            -DCMAKE_CXX_FLAGS="$(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}") -DHB_NO_MMAP"
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
        )
    fi

    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}"))
        CMAKE_ARGS+=(-DCMAKE_CXX_COMPILER=$(GET_ANDROID_CXX "${TARGET}"))
    elif [ "$WINDOWS_ONLY" != true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=clang)
        CMAKE_ARGS+=(-DCMAKE_CXX_COMPILER=clang++)
    fi

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"

    cmake --build . --config Release -j$(nproc)

    cmake --install .

    echo "harfbuzz build done (${TARGET}): ${INSTALL_DIR}"
    echo ""
}

# Build per target
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
