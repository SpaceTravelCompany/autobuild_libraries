#!/bin/bash
set -e

# freetype 크로스 빌드 스크립트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FREETYPE_DIR="${SCRIPT_DIR}/libs/freetype"

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

# freetype 디렉토리 확인
if [ ! -d "${FREETYPE_DIR}" ]; then
    echo "Error: freetype submodule이 없습니다. 'git submodule update --init --recursive'를 실행하세요."
    exit 1
fi

# freetype CMakeLists.txt 패치: BZip2::BZip2를 직접 라이브러리 경로로 대체
FREETYPE_CMAKE="${FREETYPE_DIR}/CMakeLists.txt"
if [ -f "${FREETYPE_CMAKE}" ]; then
    # 백업 생성
    if [ ! -f "${FREETYPE_CMAKE}.backup" ]; then
        cp "${FREETYPE_CMAKE}" "${FREETYPE_CMAKE}.backup"
    fi
    
    # BZip2::BZip2를 직접 라이브러리 경로로 대체
    awk '
    /target_link_libraries\(freetype PRIVATE BZip2::BZip2\)/ {
        print "  target_link_libraries(freetype PRIVATE ${BZIP2_LIBRARIES})"
        print "  target_include_directories(freetype PRIVATE ${BZIP2_INCLUDE_DIR})"
        next
    }
    { print }
    ' "${FREETYPE_CMAKE}" > "${FREETYPE_CMAKE}.tmp" && mv "${FREETYPE_CMAKE}.tmp" "${FREETYPE_CMAKE}"
    
    echo "freetype CMakeLists.txt 패치 완료"
fi

# 빌드 함수
build_target() {
    local TARGET=$1
    local BUILD_TYPE=$2  # "shared" or "static"
    local BUILD_SHARED=$3  # "ON" or "OFF"
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET} (${BUILD_TYPE})"
    echo "----------------------------------------"
    
    BUILD_DIR="${SCRIPT_DIR}/build/freetype/${TARGET}-${BUILD_TYPE}"
    INSTALL_DIR="${SCRIPT_DIR}/install/freetype/${TARGET}"
    
    # 빌드 디렉토리 생성
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}"
    
    cd "${BUILD_DIR}"
    
    # 의존성 라이브러리 경로 설정
    ZLIB_LIB_DIR="${SCRIPT_DIR}/install/libz/${TARGET}/lib"
    BZIP2_LIB_DIR="${SCRIPT_DIR}/install/bzip2/${TARGET}/lib"
    BROTLI_LIB_DIR="${SCRIPT_DIR}/install/brotli/${TARGET}/lib"
    HARFBUZZ_LIB_DIR="${SCRIPT_DIR}/install/harfbuzz/${TARGET}/lib"
    
    # CMake 설정
    CMAKE_ARGS=(
        "${FREETYPE_DIR}"
        -DCMAKE_BUILD_TYPE=Release
        -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
        -DBUILD_SHARED_LIBS="${BUILD_SHARED}"
        -DFT_DYNAMIC_HARFBUZZ=FALSE
        -DFT_DISABLE_ZLIB=OFF
        -DFT_DISABLE_BZIP2=OFF
        -DFT_DISABLE_PNG=ON
        -DFT_DISABLE_HARFBUZZ=OFF
        -DFT_DISABLE_BROTLI=OFF
    )
    
    # 의존성 라이브러리 경로 추가
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
            -DBROTLIDEC_LIBRARIES="${BROTLI_LIB_DIR}/libbrotlidec.a"
            -DBROTLIDEC_INCLUDE_DIRS="${SCRIPT_DIR}/install/brotli/${TARGET}/include"
        )
    fi
    if [ -d "${HARFBUZZ_LIB_DIR}" ]; then
        CMAKE_ARGS+=(
            -DHarfBuzz_LIBRARIES="${HARFBUZZ_LIB_DIR}/libharfbuzz.a"
            -DHarfBuzz_INCLUDE_DIR="${SCRIPT_DIR}/install/harfbuzz/${TARGET}/include"
        )
    fi
    
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
    else
        # Windows에서는 MSVC 사용, /MT 플래그 추가
        CMAKE_ARGS+=(
            -DCMAKE_C_FLAGS="/MT"
            -DCMAKE_CXX_FLAGS="/MT"
        )
    fi
    
    cmake "${CMAKE_ARGS[@]}"
    
    # 빌드
    cmake --build . --config Release -j$(nproc)
    
    # 설치
    cmake --install .
    
    echo "freetype 빌드 완료 (${TARGET}, ${BUILD_TYPE}): ${INSTALL_DIR}"
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

