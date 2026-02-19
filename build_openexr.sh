#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

OPENEXR_DIR="${SCRIPT_DIR}/libs/openexr"

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
    
    BUILD_DIR="${SCRIPT_DIR}/build/openexr/${TARGET}-${BUILD_TYPE}"
    INSTALL_DIR="${SCRIPT_DIR}/install/openexr/${TARGET}-${BUILD_TYPE}"
    IMATH_INCLUDE="${SCRIPT_DIR}/install/Imath/${TARGET}/include/Imath"
    IMATH_INSTALL_LIB="${SCRIPT_DIR}/install/Imath/${TARGET}/lib/libImath-3_2.a"
    if [ "$WINDOWS_ONLY" = true ]; then
        IMATH_INSTALL_LIB="${SCRIPT_DIR}/install/Imath/${TARGET}/lib/Imath-3_2.lib"
    fi
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # CMake 설정
    CMAKE_ARGS=(
        "${OPENEXR_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DOPENEXR_BUILD_TOOLS=OFF
        -DBUILD_TESTING=OFF
        -DOPENEXR_BUILD_EXAMPLES=OFF
        -DBUILD_WEBSITE=OFF
        -DOPENEXR_BUILD_PYTHON=OFF
        -DOPENEXR_FORCE_INTERNAL_DEFLATE=ON
        -DOPENEXR_FORCE_INTERNAL_OPENJPH=ON
        -DOPENEXR_FORCE_INTERNAL_IMATH=ON
		-DOPENEXR_ENABLE_THREADING=OFF # if set on, you need modify script for windows with llvm clang
        -DIMATH_LIB="${IMATH_INSTALL_LIB}"
        -DIMATH_INCLUDE="${IMATH_INCLUDE}"
    )

    if [ "$ANDROID_ONLY" = true ]; then
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        $(GET_ANDROID_INCLUDE_PATHS "${ANDROID_ARCH}")"

        CMAKE_C_LINKER_WRAPPER_FLAG="${ANDROID_C_LIBS}${ANDROID_CXX_LIBS} \
        $(GET_ANDROID_LIB_PATHS "${ANDROID_ARCH}")"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CMAKE_C_LINKER_WRAPPER_FLAG+=" -Wl,-z,max-page-size=16384"
        fi

        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="${CCFLAGS}"
            -DCMAKE_CXX_FLAGS="${CCFLAGS}"
            -DBUILD_SHARED_LIBS=OFF
            -DCMAKE_C_LINKER_WRAPPER_FLAG="${CMAKE_C_LINKER_WRAPPER_FLAG}"
        )
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="--target=${TARGET}"
            -DCMAKE_CXX_FLAGS="--target=${TARGET}"
            -DBUILD_SHARED_LIBS="${BUILD_SHARED_STATIC}"
        )
    elif [ "$WINDOWS_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="-fms-runtime-lib=static"
            -DCMAKE_CXX_FLAGS="-fms-runtime-lib=static"
            -DBUILD_SHARED_LIBS="${BUILD_SHARED_STATIC}"
        )
    else
        CMAKE_ARGS+=(
            -DBUILD_SHARED_LIBS="${BUILD_SHARED_STATIC}"
        )
    fi
    
    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}")
            -DCMAKE_CXX_COMPILER=$(GET_ANDROID_CXX "${TARGET}")
        )
    else
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
            -DCMAKE_CXX_COMPILER=clang++
        )
    fi

    CMAKE_ARGS=(-G "Ninja" "${CMAKE_ARGS[@]}")

    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "openexr 빌드 완료 (${TARGET}, ${BUILD_TYPE}): ${INSTALL_DIR}"
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
