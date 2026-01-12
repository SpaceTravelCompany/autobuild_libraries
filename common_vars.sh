#!/bin/bash
# 공통 변수 설정 파일
# 이 파일은 모든 빌드 스크립트에서 공통으로 사용되는 변수들을 정의합니다.
# 주의: 이 파일을 source하기 전에 각 스크립트에서 SCRIPT_DIR을 먼저 정의해야 합니다.

# NDK 설정
NDK_TOOLCHAIN_DIR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/"
NDK_API_LEVEL="35"

# 빌드 모드 플래그 (명령줄 인자로 설정됨)
NATIVE_ONLY=false
ANDROID_ONLY=false
WINDOWS_ONLY=false

# Linux 빌드 타겟 목록
LINUX_TARGETS=(
    "aarch64-linux-gnu"
    "riscv64-linux-gnu"
    "x86_64-linux-gnu"
)

# Windows 빌드 타겟 목록
WINDOWS_TARGETS=(
    "native-windows"
)

# Android 타겟 목록
ANDROIDS=(
    "aarch64-linux-android35"
    "riscv64-linux-android35"
    "x86_64-linux-android35"
    "i686-linux-android35"
    "armv7a-linux-androideabi35"
)

# Android 아키텍처 목록 (ANDROIDS 배열과 인덱스가 일치)
ANDROID_ARCH=(
    "aarch64-linux-android"
    "riscv64-linux-android"
    "x86_64-linux-android"
    "i686-linux-android"
    "arm-linux-androideabi"
)

GET_ANDROID_LIB_PATHS() {
    local __ANDROID_ARCH=$1
    echo "-L${NDK_TOOLCHAIN_DIR}/sysroot/usr/lib/${__ANDROID_ARCH} \
    -L${NDK_TOOLCHAIN_DIR}/sysroot/usr/lib/${__ANDROID_ARCH}/${NDK_API_LEVEL}"
}

GET_ANDROID_INCLUDE_PATHS() {
    local __ANDROID_ARCH=$1
    echo "-I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include \
    -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1 \
    -I${NDK_TOOLCHAIN_DIR}/sysroot/usr/include/c++/v1/${__ANDROID_ARCH}"
}

ANDROID_C_LIBS="-lc -lm -ldl -llog -landroid "
ANDROID_CXX_LIBS="-lc++_static -lc++abi "

# 명령줄 인자 파싱 함수
parse_build_args() {
    if [ "$1" == "--native" ] || [ "$1" == "-n" ]; then
        NATIVE_ONLY=true
        echo "네이티브 빌드 모드로 실행합니다."
        LINUX_TARGETS=("native")
    elif [ "$1" == "--android" ] || [ "$1" == "-a" ]; then
        ANDROID_ONLY=true
        echo "Android 빌드 모드로 실행합니다."
    elif [ "$1" == "--windows" ] || [ "$1" == "-w" ]; then
        echo "Windows 빌드 모드로 실행합니다."
        WINDOWS_ONLY=true
    elif [ -n "$1" ]; then
        echo "오류: 알 수 없는 플래그: $1" >&2
        exit 1
    fi
}
