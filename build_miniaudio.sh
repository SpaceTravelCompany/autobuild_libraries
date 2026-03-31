#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

MINIAUDIO_DIR="${SCRIPT_DIR}/libs/miniaudio"
MA_OPUS_DECODER="${MINIAUDIO_DIR}/extras/decoders/libopus"
MA_VORBIS_DECODER="${MINIAUDIO_DIR}/extras/decoders/libvorbis"

if [ ! -f "${MINIAUDIO_DIR}/miniaudio.h" ]; then
    echo "Initializing miniaudio submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive libs/miniaudio
fi

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"

    INSTALL_DIR="${SCRIPT_DIR}/install/miniaudio/${TARGET}"

    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}/include"
    mkdir -p "${INSTALL_DIR}/include/extras/decoders/libopus"
    mkdir -p "${INSTALL_DIR}/include/extras/decoders/libvorbis"
    mkdir -p "${INSTALL_DIR}/lib"

    cp "${MINIAUDIO_DIR}/miniaudio.h" "${INSTALL_DIR}/include/"
    cp "${MA_OPUS_DECODER}/miniaudio_libopus.h" "${INSTALL_DIR}/include/extras/decoders/libopus/"
    cp "${MA_VORBIS_DECODER}/miniaudio_libvorbis.h" "${INSTALL_DIR}/include/extras/decoders/libvorbis/"

    cd "${MINIAUDIO_DIR}"

    VORBIS_INCLUDE_DIR="${SCRIPT_DIR}/install/vorbis/${TARGET}/include"
    OPUSFILE_INCLUDE_DIR="${SCRIPT_DIR}/libs/opusfile/include"
    OGG_INCLUDE_DIR="${SCRIPT_DIR}/install/ogg/${TARGET}/include"
    OPUS_INCLUDE_DIR="${SCRIPT_DIR}/install/opus/${TARGET}/include/opus"

    if [ "$ANDROID_ONLY" = true ]; then
        ANDROID_CC=$(GET_ANDROID_CC "${TARGET}")
        ANDROID_AR=$(GET_ANDROID_AR)
        CCFLAGS="-I${OGG_INCLUDE_DIR} -I${OPUS_INCLUDE_DIR} -I${VORBIS_INCLUDE_DIR} -I${OPUSFILE_INCLUDE_DIR} -fPIC -O3 $(GET_SSE4_1_FLAG "${TARGET}")"

        "${ANDROID_CC}" -c miniaudio.c ${CCFLAGS}
        "${ANDROID_AR}" r libminiaudio.a miniaudio.o
        "${ANDROID_CC}" -c "${MA_OPUS_DECODER}/miniaudio_libopus.c" ${CCFLAGS}
        "${ANDROID_AR}" r libminiaudio_libopus.a miniaudio_libopus.o
        "${ANDROID_CC}" -c "${MA_VORBIS_DECODER}/miniaudio_libvorbis.c" ${CCFLAGS}
        "${ANDROID_AR}" r libminiaudio_libvorbis.a miniaudio_libvorbis.o

        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
        cp libminiaudio_libopus.a "${INSTALL_DIR}/lib/libminiaudio_libopus.a"
        cp libminiaudio_libvorbis.a "${INSTALL_DIR}/lib/libminiaudio_libvorbis.a"
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        SSE4=$(GET_SSE4_1_FLAG "${TARGET}")
        clang -c miniaudio.c -fPIC -O3 --target=${TARGET} ${SSE4}
        ar r libminiaudio.a miniaudio.o
        clang -c "${MA_OPUS_DECODER}/miniaudio_libopus.c" -fPIC -O3 -I"${OGG_INCLUDE_DIR}" -I"${OPUS_INCLUDE_DIR}" -I"${OPUSFILE_INCLUDE_DIR}" --target=${TARGET} ${SSE4}
        ar r libminiaudio_libopus.a miniaudio_libopus.o
        clang -c "${MA_VORBIS_DECODER}/miniaudio_libvorbis.c" -fPIC -O3 -I"${OGG_INCLUDE_DIR}" -I"${VORBIS_INCLUDE_DIR}" --target=${TARGET} ${SSE4}
        ar r libminiaudio_libvorbis.a miniaudio_libvorbis.o

        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
        cp libminiaudio_libopus.a "${INSTALL_DIR}/lib/libminiaudio_libopus.a"
        cp libminiaudio_libvorbis.a "${INSTALL_DIR}/lib/libminiaudio_libvorbis.a"
    elif [ "$WINDOWS_ONLY" = true ]; then
        CCFLAGS="-O2 $(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}") -MT"
        clang-cl -c ${CCFLAGS} miniaudio.c
        llvm-lib /OUT:miniaudio.lib miniaudio.obj
        clang-cl -c ${CCFLAGS} "${MA_OPUS_DECODER}/miniaudio_libopus.c" -I"${OGG_INCLUDE_DIR}" -I"${OPUS_INCLUDE_DIR}" -I"${OPUSFILE_INCLUDE_DIR}"
        llvm-lib /OUT:miniaudio_libopus.lib miniaudio_libopus.obj
        clang-cl -c ${CCFLAGS} "${MA_VORBIS_DECODER}/miniaudio_libvorbis.c" -I"${OGG_INCLUDE_DIR}" -I"${VORBIS_INCLUDE_DIR}"
        llvm-lib /OUT:miniaudio_libvorbis.lib miniaudio_libvorbis.obj

        cp miniaudio.lib "${INSTALL_DIR}/lib/miniaudio.lib"
        cp miniaudio_libopus.lib "${INSTALL_DIR}/lib/miniaudio_libopus.lib"
        cp miniaudio_libvorbis.lib "${INSTALL_DIR}/lib/miniaudio_libvorbis.lib"
    else
        clang -c miniaudio.c -fPIC -O3
        ar r libminiaudio.a miniaudio.o
        clang -c "${MA_OPUS_DECODER}/miniaudio_libopus.c" -fPIC -O3 -I"${OGG_INCLUDE_DIR}" -I"${OPUS_INCLUDE_DIR}" -I"${OPUSFILE_INCLUDE_DIR}"
        ar r libminiaudio_libopus.a miniaudio_libopus.o
        clang -c "${MA_VORBIS_DECODER}/miniaudio_libvorbis.c" -fPIC -O3 -I"${OGG_INCLUDE_DIR}" -I"${VORBIS_INCLUDE_DIR}"
        ar r libminiaudio_libvorbis.a miniaudio_libvorbis.o

        cp libminiaudio.a "${INSTALL_DIR}/lib/libminiaudio.a"
        cp libminiaudio_libopus.a "${INSTALL_DIR}/lib/libminiaudio_libopus.a"
        cp libminiaudio_libvorbis.a "${INSTALL_DIR}/lib/libminiaudio_libvorbis.a"
    fi

    rm -f *.o *.obj *.a *.lib 2>/dev/null || true

    cd "${SCRIPT_DIR}"

    echo "miniaudio 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
}

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
echo "모든 타겟 설치 완료!"
echo "=========================================="
