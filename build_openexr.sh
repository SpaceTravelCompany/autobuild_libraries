#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

OPENEXR_DIR="${SCRIPT_DIR}/libs/openexr"

# 빌드 함수 (static only)
build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/openexr/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/openexr/${TARGET}"
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
            -DBUILD_SHARED_LIBS=OFF
        )
    else
        CMAKE_ARGS+=(
            -DBUILD_SHARED_LIBS=OFF
        )
    fi
    
    if [ "$ANDROID_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=$(GET_ANDROID_CC "${TARGET}")
            -DCMAKE_CXX_COMPILER=$(GET_ANDROID_CXX "${TARGET}")
        )
    elif [ "$WINDOWS_ONLY" = true ]; then
        CMAKE_ARGS+=(
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
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
    
    echo "openexr 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
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
    for TARGET in "${WINDOWS_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        build_target "${TARGET}" ""
    done
else
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        build_target "${TARGET}" ""
    done
fi
