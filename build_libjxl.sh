#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

LIBJXL_DIR="${SCRIPT_DIR}/libs/libjxl"


build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"

    BUILD_DIR="${SCRIPT_DIR}/build/libjxl/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/libjxl/${TARGET}"
    LIBPNG_INSTALL_DIR="${SCRIPT_DIR}/install/libpng/${TARGET}"
    ZLIB_NG_INSTALL_DIR="${SCRIPT_DIR}/install/zlib-ng/${TARGET}"
    BROTLI_INSTALL_DIR="${SCRIPT_DIR}/install/brotli/${TARGET}"
    BROTLI_LIB_EXT=".a"
    if [ "$WINDOWS_ONLY" = true ]; then
        BROTLI_LIB_EXT=".lib"
    fi

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"

    cd "${BUILD_DIR}"

    CMAKE_ARGS=(
        "${LIBJXL_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_TESTING=OFF
        -DJPEGXL_ENABLE_TOOLS=OFF
        -DJPEGXL_ENABLE_DEVTOOLS=OFF
        -DJPEGXL_ENABLE_DOXYGEN=OFF
        -DJPEGXL_ENABLE_MANPAGES=OFF
        -DJPEGXL_ENABLE_BENCHMARK=OFF
        -DJPEGXL_ENABLE_EXAMPLES=OFF
        -DJPEGXL_ENABLE_JNI=OFF
        -DJPEGXL_ENABLE_VIEWERS=OFF
        -DJPEGXL_ENABLE_PLUGINS=OFF
        -DJPEGXL_ENABLE_SJPEG=OFF
        -DJPEGXL_ENABLE_OPENEXR=OFF
        -DJPEGXL_ENABLE_TCMALLOC=OFF
        -DJPEGXL_ENABLE_FUZZERS=OFF
        -DJPEGXL_FORCE_SYSTEM_BROTLI=ON
        # libjxl 번들 libpng/번들 zlib 대신,
        # 외부 libpng(= zlib-ng로 빌드된 libpng)를 사용한다.
        -DJPEGXL_BUNDLE_LIBPNG=OFF
        -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON
        -DCMAKE_PREFIX_PATH="${LIBPNG_INSTALL_DIR};${ZLIB_NG_INSTALL_DIR};${BROTLI_INSTALL_DIR}"
        -DPNG_ROOT="${LIBPNG_INSTALL_DIR}"
        -DZLIB_ROOT="${ZLIB_NG_INSTALL_DIR}"
        -DZLIB_USE_STATIC_LIBS=ON
        -DBROTLI_INCLUDE_DIR="${BROTLI_INSTALL_DIR}/include"
        -DBROTLICOMMON_LIBRARY="${BROTLI_INSTALL_DIR}/lib/brotlicommon${BROTLI_LIB_EXT}"
        -DBROTLIENC_LIBRARY="${BROTLI_INSTALL_DIR}/lib/brotlienc${BROTLI_LIB_EXT}"
        -DBROTLIDEC_LIBRARY="${BROTLI_INSTALL_DIR}/lib/brotlidec${BROTLI_LIB_EXT}"
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="-fPIC --target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}")"

        CXXFLAGS="$CCFLAGS"
        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DCMAKE_CXX_FLAGS="${CXXFLAGS}"
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
            -DCMAKE_C_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_C_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
            -DCMAKE_CXX_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_CXX_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        LW="$(GET_LINUX_CROSS_LINKER_WRAPPER_FLAGS)"
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC --target=${TARGET}"
            -DCMAKE_CXX_FLAGS="-fPIC --target=${TARGET}"
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
            -DCMAKE_CXX_FLAGS="$(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}")"
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
        )
    else
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fPIC"
            -DCMAKE_CXX_FLAGS="-fPIC"
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

    echo "libjxl 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
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
