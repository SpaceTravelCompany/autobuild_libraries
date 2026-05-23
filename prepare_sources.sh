#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_DIR="${SCRIPT_DIR}/patches"

apply_submodule_patches() {
    local REPO_DIR="$1"
    local PATCH_PREFIX="${2:-$(basename "${REPO_DIR}")}"
    local PATCH_FILE

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

echo "=========================================="
echo "Preparing sources - applying patches"
echo "=========================================="

apply_submodule_patches "${SCRIPT_DIR}/libs/libogg"
apply_submodule_patches "${SCRIPT_DIR}/libs/libvorbis"
apply_submodule_patches "${SCRIPT_DIR}/libs/flac"
apply_submodule_patches "${SCRIPT_DIR}/libs/harfbuzz"
apply_submodule_patches "${SCRIPT_DIR}/libs/bzip2"
apply_submodule_patches "${SCRIPT_DIR}/libs/cmark"

echo "=========================================="
echo "Source preparation complete!"
echo "=========================================="
