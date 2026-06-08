#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"
parse_build_args "$1"

LIBTESS2_DIR="${SCRIPT_DIR}/libs/libtess2"

SRC_FILES="bucketalloc dict geom mesh priorityq sweep tess"
INCLUDE_FLAGS="-I${LIBTESS2_DIR}/Include -I${LIBTESS2_DIR}/Source"

build_target() {
    local TARGET=$1
    local ANDROID_ARCH=$2

    echo "----------------------------------------"
    echo "빌드 중: ${TARGET}"
    echo "----------------------------------------"

    BUILD_DIR="${SCRIPT_DIR}/build/libtess2/${TARGET}"
    INSTALL_DIR="${SCRIPT_DIR}/install/libtess2/${TARGET}"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${INSTALL_DIR}/include"
    mkdir -p "${INSTALL_DIR}/lib"

    cp "${LIBTESS2_DIR}/Include/tesselator.h" "${INSTALL_DIR}/include/"

    cd "${BUILD_DIR}"

    if [ "$ANDROID_ONLY" = true ]; then
        ANDROID_CC=$(GET_ANDROID_CC "${TARGET}")
        ANDROID_AR=$(GET_ANDROID_AR)
        CCFLAGS="-fPIC -O3 -Wall -Wextra -DNDEBUG $(GET_SSE4_1_FLAG "${TARGET}")"

        for file in ${SRC_FILES}; do
            "${ANDROID_CC}" -c "${LIBTESS2_DIR}/Source/${file}.c" -o "${file}.o" ${CCFLAGS} ${INCLUDE_FLAGS}
        done

        OBJ_FILES=""
        for file in ${SRC_FILES}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        "${ANDROID_AR}" rcu libtess2.a ${OBJ_FILES}
        "$(GET_ANDROID_RANLIB)" libtess2.a
        cp libtess2.a "${INSTALL_DIR}/lib/libtess2.a"
    elif [ "$TARGET" != "native" ] && [ "$WINDOWS_ONLY" = false ]; then
        CCFLAGS="-fPIC -O3 -Wall -Wextra -DNDEBUG --target=${TARGET} $(GET_SSE4_1_FLAG "${TARGET}")"

        for file in ${SRC_FILES}; do
            clang -c "${LIBTESS2_DIR}/Source/${file}.c" -o "${file}.o" ${CCFLAGS} ${INCLUDE_FLAGS}
        done

        OBJ_FILES=""
        for file in ${SRC_FILES}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        ar rcu libtess2.a ${OBJ_FILES}
        ranlib libtess2.a
        cp libtess2.a "${INSTALL_DIR}/lib/libtess2.a"
    elif [ "$WINDOWS_ONLY" = true ]; then
        CCFLAGS="-O2 -DNDEBUG $(GET_WINDOWS_CLANG_TARGET_FLAG "${TARGET}") $(GET_WINDOWS_CLANG_CFLAGS "${TARGET}") -MT"

        for file in ${SRC_FILES}; do
            clang-cl -c "${LIBTESS2_DIR}/Source/${file}.c" -o "${file}.obj" ${CCFLAGS} ${INCLUDE_FLAGS}
        done

        OBJ_FILES=""
        for file in ${SRC_FILES}; do
            OBJ_FILES="${OBJ_FILES} ${file}.obj"
        done
        llvm-lib /OUT:libtess2.lib ${OBJ_FILES}
        cp libtess2.lib "${INSTALL_DIR}/lib/libtess2.lib"
    else
        CCFLAGS="-fPIC -O3 -Wall -Wextra -DNDEBUG $(GET_SSE4_1_FLAG "${TARGET}")"

        for file in ${SRC_FILES}; do
            clang -c "${LIBTESS2_DIR}/Source/${file}.c" -o "${file}.o" ${CCFLAGS} ${INCLUDE_FLAGS}
        done

        OBJ_FILES=""
        for file in ${SRC_FILES}; do
            OBJ_FILES="${OBJ_FILES} ${file}.o"
        done
        ar rcu libtess2.a ${OBJ_FILES}
        ranlib libtess2.a
        cp libtess2.a "${INSTALL_DIR}/lib/libtess2.a"
    fi

    echo "libtess2 빌드 완료 (${TARGET}): ${INSTALL_DIR}"
    echo ""
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
