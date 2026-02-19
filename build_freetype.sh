#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

FREETYPE_DIR="${SCRIPT_DIR}/libs/freetype"


# 빌드 함수
build_target() {
    local TARGET=$1
    local BUILD_TYPE=$2  # "shared" or "static"
    local ANDROID_ARCH=$3
    
    BUILD_SHARED_STATIC="OFF"
    if [ "$BUILD_TYPE" = "shared" ]; then
        BUILD_SHARED_STATIC="ON" 
    fi

    echo "----------------------------------------"
    echo "빌드 중: ${TARGET} (${BUILD_TYPE})"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/freetype/${TARGET}-${BUILD_TYPE}"
    INSTALL_DIR="${SCRIPT_DIR}/install/freetype/${TARGET}-${BUILD_TYPE}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # 의존성 라이브러리 경로 설정
    ZLIB_LIB_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/lib"
    BZIP2_LIB_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/lib"
    BROTLI_LIB_DIR="${SCRIPT_DIR}/install/brotli/${TARGET}/lib"
    
    # CMake 설정
    CMAKE_ARGS=(
        "${FREETYPE_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DFT_DYNAMIC_HARFBUZZ=FALSE
        -DFT_DISABLE_ZLIB=OFF
        -DFT_DISABLE_BZIP2=OFF
        -DFT_DISABLE_PNG=ON
        -DFT_DISABLE_HARFBUZZ=ON
        -DFT_DISABLE_BROTLI=OFF
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CMAKE_C_LINKER_WRAPPER_FLAG+=" -Wl,-z,max-page-size=16384"
        fi

        # Android일 때는 정적 라이브러리만 사용
        if [ -d "${ZLIB_LIB_DIR}" ]; then
            CMAKE_ARGS+=(
                -DZLIB_LIBRARY="${ZLIB_LIB_DIR}/libz.a"
                -DZLIB_INCLUDE_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/include"
            )
        fi
        if [ -d "${BZIP2_LIB_DIR}" ]; then
            CMAKE_ARGS+=(
                -DBZIP2_LIBRARIES="${BZIP2_LIB_DIR}/libbz2_static.a"
                -DBZIP2_INCLUDE_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/include"
            )
        fi
        if [ -d "${BROTLI_LIB_DIR}" ]; then
            CMAKE_ARGS+=(
                -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlidec-static.a"
                -DBROTLIENC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlienc-static.a"
                -DBROTLICOMMON_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlicommon-static.a"
                -DBROTLIDEC_INCLUDE_DIRS="${SCRIPT_DIR}/install/brotli/${TARGET}/include"
            )
        fi

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
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
                    -DBZIP2_LIBRARIES="${BZIP2_LIB_DIR}/libbz2_static.a"
                    -DBZIP2_INCLUDE_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/include"
                )
            fi
            if [ -d "${BROTLI_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlidec-static.a"
                    -DBROTLIENC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlienc-static.a"
                    -DBROTLICOMMON_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlicommon-static.a"
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
                    -DBZIP2_LIBRARIES="${BZIP2_LIB_DIR}/bz2_static.lib"
                    -DBZIP2_INCLUDE_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/include"
                )
            fi
            if [ -d "${BROTLI_LIB_DIR}" ]; then
                CMAKE_ARGS+=(
                    -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/brotlidec-static.lib"
                    -DBROTLIENC_LIBRARIES="${BROTLI_LIB_DIR}/brotlienc-static.lib"
                    -DBROTLICOMMON_LIBRARIES="${BROTLI_LIB_DIR}/brotlicommon-static.lib"
                    -DBROTLIDEC_INCLUDE_DIRS="${SCRIPT_DIR}/install/brotli/${TARGET}/include"
                )
            fi
        fi

        if [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
            CMAKE_ARGS+=(
                -DCMAKE_C_FLAGS="--target=${TARGET}"
            )
        fi
        CMAKE_ARGS+=(
            -DBUILD_SHARED_LIBS=${BUILD_SHARED_STATIC}
        )
    fi

    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}"))
    else
        CMAKE_ARGS+=(-DCMAKE_C_COMPILER=clang)
    fi

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "freetype 빌드 완료 (${TARGET}, ${BUILD_TYPE}): ${INSTALL_DIR}"
    echo ""
}

# 각 타겟에 대해 빌드
if [ "$ANDROID_ONLY" = true ]; then
    for i in "${!ANDROIDS[@]}"; do
        TARGET="${ANDROIDS[$i]}"
        echo "=========================================="
        echo "타겟: ${TARGET} ${ANDROID_ARCH[$i]}"
        echo "=========================================="
        
        # Android일 때는 static만 빌드
        build_target "${TARGET}" "static" "${ANDROID_ARCH[$i]}"
    done
elif [ "$WINDOWS_ONLY" = true ]; then
    # Windows 환경에서는 WINDOWS_TARGETS 사용
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
    # Linux 환경에서는 LINUX_TARGETS 사용
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

echo "=========================================="
echo "모든 타겟 빌드 완료!"
echo "=========================================="

