#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

MINIAUDIO_DIR="${SCRIPT_DIR}/libs/miniaudio"

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
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        clang -c miniaudio.c miniaudio_libopus.c miniaudio_libvorbis.c \
        -I"${OGG_INCLUDE_DIR}" \
        -I"${OPUS_INCLUDE_DIR}" \
        -I"${VORBIS_INCLUDE_DIR}" \
        -I"${OPUSFILE_INCLUDE_DIR}" \
        -fPIC -O3 --target=${TARGET}
        ar r libminiaudio.a miniaudio.o miniaudio_libopus.o miniaudio_libvorbis.o
        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
    elif [ "$WINDOWS_ONLY" = true ]; then
        cl -c -O2 -MT miniaudio.c miniaudio_libopus.c miniaudio_libvorbis.c \
        -I"${OGG_INCLUDE_DIR}" \
        -I"${OPUS_INCLUDE_DIR}" \
        -I"${VORBIS_INCLUDE_DIR}" \
        -I"${OPUSFILE_INCLUDE_DIR}"
        lib /OUT:libminiaudio.lib miniaudio.obj miniaudio_libopus.obj miniaudio_libvorbis.obj
        cp libminiaudio.lib "${INSTALL_DIR}/lib/libminiaudio.lib"
    else
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
elif [ "$WINDOWS_ONLY" = true ]; then
    # Windows 환경에서는 WINDOWS_TARGETS 사용
    for TARGET in "${WINDOWS_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        
        build_target "${TARGET}" ""
    done
else
    # Linux 환경에서는 LINUX_TARGETS 사용
    for TARGET in "${LINUX_TARGETS[@]}"; do
        echo "=========================================="
        echo "타겟: ${TARGET}"
        echo "=========================================="
        
        build_target "${TARGET}" ""
    done
fi

echo "=========================================="
echo "모든 타겟 설치 완료!"
echo "=========================================="