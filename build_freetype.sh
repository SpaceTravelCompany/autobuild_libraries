#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

# --no-harfbuzz / -nh: build freetype without harfbuzz (for bootstrap; harfbuzz needs freetype first)
FREETYPE_NO_HARFBUZZ=false
for arg in "$@"; do
    case "$arg" in
        --no-harfbuzz|-nh) FREETYPE_NO_HARFBUZZ=true ;;
    esac
done

FREETYPE_DIR="${SCRIPT_DIR}/libs/freetype"

# Ensure submodule is initialized
if [ ! -f "${FREETYPE_DIR}/CMakeLists.txt" ]; then
    echo "Initializing freetype submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive libs/freetype
fi

# 빌드 함수 (static only)
build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/freetype/${TARGET}"
    if [ "$FREETYPE_NO_HARFBUZZ" = true ]; then
        INSTALL_DIR="${SCRIPT_DIR}/install/freetype-no-harfbuzz/${TARGET}"
    else
        INSTALL_DIR="${SCRIPT_DIR}/install/freetype/${TARGET}"
    fi
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # Dependency paths
    ZLIB_LIB_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/lib"
    BZIP2_LIB_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/lib"
    BROTLI_LIB_DIR="${SCRIPT_DIR}/install/brotli/${TARGET}/lib"
    HARFBUZZ_INSTALL_DIR="${SCRIPT_DIR}/install/harfbuzz/${TARGET}"

    # CMake config (harfbuzz on/off via FREETYPE_NO_HARFBUZZ)
    CMAKE_ARGS=(
        "${FREETYPE_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DFT_DISABLE_ZLIB=OFF
        -DFT_DISABLE_BZIP2=OFF
        -DFT_DISABLE_PNG=ON
        -DFT_DISABLE_BROTLI=OFF
        -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON
    )
    if [ "$FREETYPE_NO_HARFBUZZ" = true ]; then
        CMAKE_ARGS+=(
            -DFT_DISABLE_HARFBUZZ=ON
        )
    else
        CMAKE_ARGS+=(
            -DCMAKE_PREFIX_PATH="${HARFBUZZ_INSTALL_DIR}"
            -DFT_DYNAMIC_HARFBUZZ=FALSE
            -DFT_DISABLE_HARFBUZZ=OFF
            -DFT_REQUIRE_HARFBUZZ=TRUE
        )
    fi

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}") $(GET_SSE4_1_FLAG "${TARGET}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        # Android일 때는 정적 라이브러리만 사용
        if [ -d "${ZLIB_LIB_DIR}" ]; then
            CMAKE_ARGS+=(
                -DZLIB_LIBRARY="${ZLIB_LIB_DIR}/libz.a"
                -DZLIB_INCLUDE_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/include"
            )
        fi
        if [ -d "${BZIP2_LIB_DIR}" ]; then
            CMAKE_ARGS+=(
                -DBZIP2_LIBRARY="${BZIP2_LIB_DIR}/libbz2_static.a"
                -DBZIP2_LIBRARIES="${BZIP2_LIB_DIR}/libbz2_static.a"
                -DBZIP2_INCLUDE_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/include"
            )
        fi
        if [ -d "${BROTLI_LIB_DIR}" ]; then
            CMAKE_ARGS+=(
                -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlidec-static.a"
                -DBROTLIDEC_INCLUDE_DIRS="${SCRIPT_DIR}/install/brotli/${TARGET}/include"
            )
        fi

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
            -DCMAKE_C_COMPILER_AR="$(GET_ANDROID_AR)"
            -DCMAKE_C_COMPILER_RANLIB="$(GET_ANDROID_RANLIB)"
        )
    else
        # 의존성 라이브러리 경로 추가
        if [ "${OS}" != "Windows_NT" ] && [ -z "${MSYSTEM}" ]; then
            if [ -d "${ZLIB_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DZLIB_LIBRARY="${ZLIB_LIB_DIR}/libz.so"
                    -DZLIB_INCLUDE_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/include"
                )
            fi
            if [ -d "${BZIP2_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DBZIP2_LIBRARY="${BZIP2_LIB_DIR}/libbz2_static.a"
                    -DBZIP2_LIBRARIES="${BZIP2_LIB_DIR}/libbz2_static.a"
                    -DBZIP2_INCLUDE_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/include"
                )
            fi
            if [ -d "${BROTLI_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlidec-static.a"
                    -DBROTLIDEC_INCLUDE_DIRS="${SCRIPT_DIR}/install/brotli/${TARGET}/include"
                )
            fi
        else
            if [ -d "${ZLIB_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DZLIB_LIBRARY="${ZLIB_LIB_DIR}/zs.lib"
                    -DZLIB_INCLUDE_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/include"
                )
            fi
            if [ -d "${BZIP2_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DBZIP2_LIBRARY="${BZIP2_LIB_DIR}/bz2_static.lib"
                    -DBZIP2_LIBRARIES="${BZIP2_LIB_DIR}/bz2_static.lib"
                    -DBZIP2_INCLUDE_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/include"
                )
            fi
            if [ -d "${BROTLI_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/brotlidec-static.lib"
                    -DBROTLIDEC_INCLUDE_DIRS="${SCRIPT_DIR}/install/brotli/${TARGET}/include"
                )
            fi
        fi

        if [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
            CMAKE_ARGS+=(
                -DCMAKE_C_FLAGS="--target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"
            )
        elif [ "$WINDOWS_ONLY" = true ]; then
            CMAKE_ARGS+=(
                -DCMAKE_C_COMPILER=clang-cl
                -DCMAKE_CXX_COMPILER=clang-cl
                -DCMAKE_C_FLAGS="$(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}")"
                -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
            )
        fi
        CMAKE_ARGS+=( -DBUILD_SHARED_LIBS=OFF )
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
    
    echo "freetype 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
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
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        build_target "${TARGET}" ""
    done
fi

echo "=========================================="
echo "모든 타겟 빌드 완료!"
echo "=========================================="

