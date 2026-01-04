#!/bin/bash
set -e

# miniaudio는 단일 헤더 라이브러리이므로 빌드할 필요가 없지만,
# 의존성 라이브러리들(ogg, opus, vorbis, opusfile)을 빌드하는 스크립트입니다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIAUDIO_DIR="${SCRIPT_DIR}/libs/miniaudio"

# 네이티브 빌드 옵션 확인
NATIVE_ONLY=false
if [ "$1" == "--native" ] || [ "$1" == "-n" ]; then
    NATIVE_ONLY=true
    echo "네이티브 빌드 모드로 실행합니다."
fi

NDK_TOOLCHAIN_DIR="${SCRIPT_DIR}/ndk/29.0.14206865/toolchains/llvm/prebuilt/linux-x86_64/"
NDK_API_LEVEL="35"

ANDROID_ONLY=false
if [ "$1" == "--android" ] || [ "$1" == "-a" ]; then
    ANDROID_ONLY=true
    echo "Android 빌드 모드로 실행합니다."
fi

ANDROIDS=()

# 빌드할 타겟 아키텍처 목록
if [ "$NATIVE_ONLY" = true ]; then
    # 네이티브 빌드만 (현재 시스템 아키텍처)
    TARGETS=("native")
else
    TARGETS=(
        "aarch64-linux-gnu"
        "riscv64-linux-gnu"
        "x86_64-linux-gnu"
    )
    ANDROIDS=(
        "aarch64-linux-android35"
        "riscv64-linux-android35"
        "x86_64-linux-android35"
        "i686-linux-android35"
        "armv7a-linux-androideabi35"
    )
    ANDROID_ARCH=(
        "aarch64-linux-android"
        "riscv64-linux-android"
        "x86_64-linux-android"
        "i686-linux-android"
        "arm-linux-androideabi"
    )
fi

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2
    
    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"
    
    INSTALL_DIR="${SCRIPT_DIR}/install/miniaudio/${TARGET}"
    
    # 설치 디렉토리 생성
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/include"
    mkdir -p "${INSTALL_DIR}/lib"
    
    # 헤더 파일 복사
    cp "${MINIAUDIO_DIR}/miniaudio.h" "${INSTALL_DIR}/include/"
    cp "${MINIAUDIO_DIR}/miniaudio_libopus.h" "${INSTALL_DIR}/include/"
    cp "${MINIAUDIO_DIR}/miniaudio_libvorbis.h" "${INSTALL_DIR}/include/"

    cd ${MINIAUDIO_DIR}

    # 의존성 라이브러리 경로 설정
    VORBIS_INCLUDE_DIR="${SCRIPT_DIR}/install/vorbis/${TARGET}/include"
    OPUSFILE_INCLUDE_DIR="${SCRIPT_DIR}/libs/opusfile/include"
    OGG_INCLUDE_DIR="${SCRIPT_DIR}/install/ogg/${TARGET}/include"
    OPUS_INCLUDE_DIR="${SCRIPT_DIR}/install/opus/${TARGET}/include/opus"

    if [ "$ANDROID_ONLY" = true ]; then
        # Android 빌드
        CCFLAGS="--target=${TARGET} --sysroot=${NDK_TOOLCHAIN_DIR}/sysroot \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1 \
        -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1/${ANDROID_ARCH} \
        -I${OGG_INCLUDE_DIR} \
        -I${OPUS_INCLUDE_DIR} \
        -I${VORBIS_INCLUDE_DIR} \
        -I${OPUSFILE_INCLUDE_DIR} \
        -fPIC -O3 -lc -lm -ldl -llog -landroid"

        if [ "$TARGET" == "aarch64-linux-android35" ]; then
            CCFLAGS+=" -Wl,-z,max-page-size=16384"
        fi

        clang -c miniaudio.c miniaudio_libopus.c miniaudio_libvorbis.c ${CCFLAGS}
        ar r libminiaudio.a miniaudio.o miniaudio_libopus.o miniaudio_libvorbis.o
        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
    elif [ "${OS}" == "Windows_NT" ] || [ -n "${MSYSTEM}" ]; then
        cl -c -O2 -MT miniaudio.c miniaudio_libopus.c miniaudio_libvorbis.c \
        -I"${OGG_INCLUDE_DIR}" \
        -I"${OPUS_INCLUDE_DIR}" \
        -I"${VORBIS_INCLUDE_DIR}" \
        -I"${OPUSFILE_INCLUDE_DIR}"
        lib /OUT:libminiaudio.lib miniaudio.obj miniaudio_libopus.obj miniaudio_libvorbis.obj
        cp libminiaudio.lib "${INSTALL_DIR}/lib/libminiaudio.lib"
    elif [ "$TARGET" != "native" ]; then
        # 크로스 컴파일 (Linux)
        clang -c miniaudio.c miniaudio_libopus.c miniaudio_libvorbis.c \
        -I"${OGG_INCLUDE_DIR}" \
        -I"${OPUS_INCLUDE_DIR}" \
        -I"${VORBIS_INCLUDE_DIR}" \
        -I"${OPUSFILE_INCLUDE_DIR}" \
        -fPIC -O3 --target=${TARGET}
        ar r libminiaudio.a miniaudio.o miniaudio_libopus.o miniaudio_libvorbis.o
        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
    else
        # 네이티브 빌드 (Linux)
        clang -c miniaudio.c miniaudio_libopus.c miniaudio_libvorbis.c \
        -I"${OGG_INCLUDE_DIR}" \
        -I"${OPUS_INCLUDE_DIR}" \
        -I"${VORBIS_INCLUDE_DIR}" \
        -I"${OPUSFILE_INCLUDE_DIR}" \
        -fPIC -O3
        ar r libminiaudio.a miniaudio.o miniaudio_libopus.o miniaudio_libvorbis.o
        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
    fi

    # 정리
    rm -f *.o *.obj *.a *.lib 2>/dev/null || true

    cd ${SCRIPT_DIR}
    
    echo "miniaudio 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
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
else
    for TARGET in "${TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        
        build_target "${TARGET}" ""
    done
fi

echo "=========================================="
echo "모든 타겟 설치 완료!"
echo "=========================================="