#!/bin/bash
set -e

# freetype 크로스 빌드 스크립트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FREETYPE_DIR="${SCRIPT_DIR}/libs/freetype"

# 빌드할 타겟 아키텍처 목록
TARGETS=(
    "aarch64-linux-gnu"
    "riscv64-linux-gnu"
    "x86_64-linux-gnu"
    "i386-linux-gnu"
)

# freetype 디렉토리 확인
if [ ! -d "${FREETYPE_DIR}" ]; then
    echo "Error: freetype submodule이 없습니다. 'git submodule update --init --recursive'를 실행하세요."
    exit 1
fi

# 각 타겟에 대해 빌드
for TARGET in "${TARGETS[@]}"; do
    echo "=========================================="
    echo "빌드 중: ${TARGET}"
    echo "=========================================="
    
    BUILD_DIR="${SCRIPT_DIR}/build/freetype/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/freetype/${TARGET}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # CMake 설정 (Clang 명시적 지정 및 --target 추가)
    cmake "${FREETYPE_DIR}" \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DBUILD_SHARED_LIBS=ON \
        -DFT_DISABLE_ZLIB=OFF \
        -DFT_DISABLE_BZIP2=OFF \
        -DFT_DISABLE_PNG=OFF \
        -DFT_DISABLE_HARFBUZZ=OFF \
        -DCMAKE_C_FLAGS="--target=${TARGET}" \
        -DCMAKE_CXX_FLAGS="--target=${TARGET}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "freetype 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
    echo ""
done

echo "=========================================="
echo "모든 타겟 빌드 완료!"
echo "=========================================="

