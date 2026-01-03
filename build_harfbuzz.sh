#!/bin/bash
set -e

# harfbuzz 크로스 빌드 스크립트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARFBUZZ_DIR="${SCRIPT_DIR}/libs/harfbuzz"

# 네이티브 빌드 옵션 확인
NATIVE_ONLY=false
if [ "$1" == "--native" ] || [ "$1" == "-n" ]; then
    NATIVE_ONLY=true
    echo "네이티브 빌드 모드로 실행합니다."
fi

# 빌드할 타겟 아키텍처 목록
if [ "$NATIVE_ONLY" = true ]; then
    # 네이티브 빌드만 (현재 시스템 아키텍처)
    TARGETS=("native")
else
    # 크로스 빌드
    TARGETS=(
        "aarch64-linux-gnu"
        "riscv64-linux-gnu"
        "x86_64-linux-gnu"
        "i386-linux-gnu"
    )
fi

# harfbuzz 디렉토리 확인
if [ ! -d "${HARFBUZZ_DIR}" ]; then
    echo "Error: harfbuzz submodule이 없습니다. 'git submodule update --init --recursive'를 실행하세요."
    exit 1
fi

# 빌드 함수
build_target() {
    local TARGET=$1
    local BUILD_TYPE=$2  # "shared" or "static"
    local BUILD_SHARED=$3  # "ON" or "OFF"
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET} (${BUILD_TYPE})"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/harfbuzz/${TARGET}-${BUILD_TYPE}"
    INSTALL_DIR="${SCRIPT_DIR}/install/harfbuzz/${TARGET}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # CMake 설정
    CMAKE_ARGS=(
        "${HARFBUZZ_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DBUILD_SHARED_LIBS="${BUILD_SHARED}"
        -DHB_HAVE_FREETYPE=OFF
        -DHB_HAVE_GLIB=OFF
        -DHB_HAVE_GOBJECT=OFF
        -DHB_HAVE_ICU=OFF
        -DHB_HAVE_CORETEXT=OFF
    )
    
    # 크로스 컴파일 설정
    # Windows가 아닐 때만 clang 설정 (Windows에서는 MSVC 사용)
    if [ "$TARGET" != "native" ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
            -DCMAKE_CXX_COMPILER=clang++
            -DCMAKE_C_FLAGS="--target=${TARGET}"
            -DCMAKE_CXX_FLAGS="--target=${TARGET}"
        )
    elif [ "${OS}" != "Windows_NT" ] && [ -z "${MSYSTEM}" ]; then
        # Windows가 아닐 때만 clang 설정
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
            -DCMAKE_CXX_COMPILER=clang++
        )
    fi
    
    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "harfbuzz 빌드 완료 (${TARGET}, ${BUILD_TYPE}): ${INSTALL_DIR}"
    echo ""
}

# 각 타겟에 대해 빌드
for TARGET in "${TARGETS[@]}"; do
    echo "=========================================="
    echo "타겟: ${TARGET}"
    echo "=========================================="
    
    # 공유 라이브러리 빌드
    build_target "${TARGET}" "shared" "ON"
    
    # 정적 라이브러리 빌드
    build_target "${TARGET}" "static" "OFF"
done

echo "=========================================="
echo "모든 타겟 빌드 완료!"
echo "=========================================="
