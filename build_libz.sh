#!/bin/bash
set -e

# libz (zlib) 크로스 빌드 스크립트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZLIB_DIR="${SCRIPT_DIR}/libs/zlib"

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

# zlib 디렉토리 확인
if [ ! -d "${ZLIB_DIR}" ]; then
    echo "Error: zlib submodule이 없습니다. 'git submodule update --init --recursive'를 실행하세요."
    exit 1
fi

# 빌드 함수
build_target() {
    local TARGET=$1
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET} (${BUILD_TYPE})"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/libz/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/libz/${TARGET}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # CMake 설정
    CMAKE_ARGS=(
        "${ZLIB_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DZLIB_BUILD_TESTING=OFF
    )
    
    # 크로스 컴파일 설정
    # Windows가 아닐 때만 clang 설정 (Windows에서는 MSVC 사용)
    if [ "$TARGET" != "native" ]; then
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
            -DCMAKE_C_FLAGS="--target=${TARGET}"
        )
    elif [ "${OS}" != "Windows_NT" ] && [ -z "${MSYSTEM}" ]; then
        # Windows가 아닐 때만 clang 설정
        CMAKE_ARGS+=(
            -DCMAKE_C_COMPILER=clang
        )
    else
        # Windows에서는 MSVC 사용, /MT 플래그 추가
        CMAKE_ARGS+=(
            -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
        )
    fi
    
    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "libz 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
    echo ""
}

# 각 타겟에 대해 빌드
for TARGET in "${TARGETS[@]}"; do
    echo "=========================================="
    echo "타겟: ${TARGET}"
    echo "=========================================="
    
    build_target "${TARGET}"
done

echo "=========================================="
echo "모든 타겟 빌드 완료!"
echo "=========================================="

