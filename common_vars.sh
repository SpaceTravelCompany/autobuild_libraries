#!/bin/bash
# 공통 변수 설정 파일
# 이 파일은 모든 빌드 스크립트에서 공통으로 사용되는 변수들을 정의합니다.
# 주의: 이 파일을 source하기 전에 각 스크립트에서 SCRIPT_DIR을 먼저 정의해야 합니다.

# NDK settings (host-agnostic: use prebuilt dir that exists)
if [ -n "${ANDROID_NDK_HOME}" ]; then
    if [ -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64" ]; then
        NDK_TOOLCHAIN_DIR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64"
    elif [ -d "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64" ]; then
        NDK_TOOLCHAIN_DIR="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64"
    else
        NDK_PREBUILT=$(find "${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
        NDK_TOOLCHAIN_DIR="${NDK_PREBUILT}"
    fi
else
    NDK_TOOLCHAIN_DIR=""
fi
NDK_API_LEVEL="35"

# Return path to NDK clang for the given Android target (e.g. aarch64-linux-android35)
GET_ANDROID_CC() { echo "${NDK_TOOLCHAIN_DIR}/bin/$1-clang"; }
GET_ANDROID_CXX() { echo "${NDK_TOOLCHAIN_DIR}/bin/$1-clang++"; }
GET_ANDROID_AR() { echo "${NDK_TOOLCHAIN_DIR}/bin/llvm-ar"; }
GET_ANDROID_RANLIB() { echo "${NDK_TOOLCHAIN_DIR}/bin/llvm-ranlib"; }

# SSE4.1 flag: only for x86/x64 targets. "windows" = -msse4.1, "windows-arm" = no SSE.
GET_SSE4_1_FLAG() {
    local TARGET=$1
    case "$TARGET" in
        x86_64-*|i686-*|windows) echo "-msse4.1" ;;
        *) echo "" ;;
    esac
}

# Windows clang-cl CFLAGS by target: SSE only for "windows", empty for "windows-arm".
GET_WINDOWS_CLANG_CFLAGS() {
    GET_SSE4_1_FLAG "$1"
}

# When building for windows-arm (cross to ARM64): pass clang target triple.
GET_WINDOWS_CLANG_TARGET_FLAG() {
    if [ "$1" = "windows-arm" ]; then
        echo "--target=aarch64-windows-msvc"
    else
        echo "--target=x86_64-windows-msvc"
    fi
}

# Linux cross: pass to CMAKE_{C,CXX}_LINKER_WRAPPER_FLAG so clang uses lld (avoids cross-ld + LLVMgold.so).
GET_LINUX_CROSS_LINKER_WRAPPER_FLAGS() { echo "-fuse-ld=lld"; }

# 빌드 모드 플래그 (명령줄 인자로 설정됨)
NATIVE_ONLY=false
ANDROID_ONLY=false
WINDOWS_ONLY=false

# Linux 빌드 타겟 목록
LINUX_TARGETS=(
    "aarch64-linux-gnu"
    "riscv64-linux-gnu"
    "x86_64-linux-gnu"
    "i686-linux-gnu"
	"arm-linux-gnueabihf"
)

# Windows 빌드 타겟 목록 (windows = x64, windows-arm = ARM64)
WINDOWS_TARGETS=(
    "windows"
    "windows-arm"
)
# Windows: single target only (windows = x64, windows-arm = ARM64)
WINDOWS_TARGET=""

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

# Apply git patches from patches/<prefix>-*.patch and patches/<prefix>/*.patch.
# REPO_DIR: submodule root (e.g. "${SCRIPT_DIR}/libs/flac").
# PATCH_PREFIX: optional; defaults to the basename of REPO_DIR (e.g. "flac").
# Requires SCRIPT_DIR to be set by the calling build script.
apply_submodule_patches() {
    local REPO_DIR="$1"
    local PATCH_PREFIX="${2:-$(basename "${REPO_DIR}")}"
    local PATCH_DIR="${SCRIPT_DIR}/patches"
    local PATCH_FILE

    if [ -z "${SCRIPT_DIR}" ]; then
        echo "ERROR: SCRIPT_DIR must be set before calling apply_submodule_patches" >&2
        exit 1
    fi

    if [ ! -d "${REPO_DIR}" ]; then
        echo "ERROR: Submodule directory not found: ${REPO_DIR}" >&2
        exit 1
    fi

    shopt -s nullglob
    local patches=(
        "${PATCH_DIR}/${PATCH_PREFIX}"-*.patch
        "${PATCH_DIR}/${PATCH_PREFIX}"/*.patch
    )
    shopt -u nullglob

    if [ ${#patches[@]} -eq 0 ]; then
        return 0
    fi

    while IFS= read -r PATCH_FILE; do
        [ -z "${PATCH_FILE}" ] && continue

        if git -C "${REPO_DIR}" apply --check --ignore-whitespace "${PATCH_FILE}" 2>/dev/null; then
            git -C "${REPO_DIR}" apply --ignore-whitespace "${PATCH_FILE}"
            echo "Applied patch: $(basename "${PATCH_FILE}") -> ${PATCH_PREFIX}"
        elif git -C "${REPO_DIR}" apply --reverse --check --ignore-whitespace "${PATCH_FILE}" 2>/dev/null; then
            echo "Skipped (already applied): $(basename "${PATCH_FILE}")"
        else
            echo "ERROR: Patch $(basename "${PATCH_FILE}") does not apply cleanly to ${PATCH_PREFIX}" >&2
            exit 1
        fi
    done < <(printf '%s\n' "${patches[@]}" | LC_ALL=C sort -u)
}

# Command-line argument parsing
parse_build_args() {
    if [ "$1" == "--native" ] || [ "$1" == "-n" ]; then
        NATIVE_ONLY=true
        echo "네이티브 빌드 모드로 실행합니다."
        LINUX_TARGETS=("native")
    elif [ "$1" == "--android" ] || [ "$1" == "-a" ]; then
        ANDROID_ONLY=true
        echo "Android 빌드 모드로 실행합니다."
    elif [ "$1" == "--windows" ] || [ "$1" == "-w" ]; then
        WINDOWS_ONLY=true
        WINDOWS_TARGET="windows"
        echo "Windows 빌드 모드로 실행합니다. (x64)"
    elif [ "$1" == "--windows-arm" ] || [ "$1" == "-wa" ]; then
        WINDOWS_ONLY=true
        WINDOWS_TARGET="windows-arm"
        echo "Windows ARM 빌드 모드로 실행합니다."
    elif [ -n "$1" ]; then
        echo "오류: 알 수 없는 플래그: $1" >&2
        exit 1
    fi
}
