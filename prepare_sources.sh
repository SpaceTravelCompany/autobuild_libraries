#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="${SCRIPT_DIR}/patches"

apply_patches() {
    local REPO_DIR="$1"
    local PATCH_PREFIX="$2"
    local PATCH_FILE

    shopt -s nullglob
    local patches=(
        "${PATCH_DIR}/${PATCH_PREFIX}"-*.patch
    )
    shopt -u nullglob

    for PATCH_FILE in "${patches[@]}"; do
        if patch -p1 -d "${REPO_DIR}" -N --forward --ignore-whitespace --dry-run -i "${PATCH_FILE}" >/dev/null 2>&1; then
            patch -p1 -d "${REPO_DIR}" -N --forward --ignore-whitespace -i "${PATCH_FILE}"
            echo "Applied: $(basename "${PATCH_FILE}")"
        elif patch -p1 -d "${REPO_DIR}" -N --reverse --dry-run --ignore-whitespace -i "${PATCH_FILE}" >/dev/null 2>&1; then
            echo "Skipped (already applied): $(basename "${PATCH_FILE}")"
        else
            echo "ERROR: $(basename "${PATCH_FILE}") does not apply to ${PATCH_PREFIX}" >&2
            exit 1
        fi
    done
}

apply_patches "${SCRIPT_DIR}/libs/libogg" "libogg"
apply_patches "${SCRIPT_DIR}/libs/libvorbis" "libvorbis"
apply_patches "${SCRIPT_DIR}/libs/flac" "flac"
apply_patches "${SCRIPT_DIR}/libs/harfbuzz" "harfbuzz"
apply_patches "${SCRIPT_DIR}/libs/bzip2" "bzip2"
apply_patches "${SCRIPT_DIR}/libs/cmark" "cmark"
