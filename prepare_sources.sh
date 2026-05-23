#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common_vars.sh"

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
