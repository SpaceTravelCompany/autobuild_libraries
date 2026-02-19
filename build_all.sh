#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "모든 라이브러리 빌드 시작"
echo "=========================================="
echo ""

# 빌드 인자
BUILD_ARG="$1"

# 15. clipper2 빌드
"${SCRIPT_DIR}/build_clipper2.sh" "${BUILD_ARG}"

# 5. ogg 빌드
"${SCRIPT_DIR}/build_ogg.sh" "${BUILD_ARG}"

# 6. opus 빌드
"${SCRIPT_DIR}/build_opus.sh" "${BUILD_ARG}"

# 7. vorbis 빌드 (ogg 의존)
"${SCRIPT_DIR}/build_vorbis.sh" "${BUILD_ARG}"

# 8. opusfile 빌드 (opus 의존)
"${SCRIPT_DIR}/build_opusfile.sh" "${BUILD_ARG}"

# 9. miniaudio 빌드 (vorbis, opusfile, ogg, opus 의존)
"${SCRIPT_DIR}/build_miniaudio.sh" "${BUILD_ARG}"

# 1. libz 빌드
"${SCRIPT_DIR}/build_libz.sh" "${BUILD_ARG}"

# 2. bzip2 빌드
"${SCRIPT_DIR}/build_bzip2.sh" "${BUILD_ARG}"

# 3. brotli 빌드
"${SCRIPT_DIR}/build_brotli.sh" "${BUILD_ARG}"

# 4. freetype 빌드 (libz, bzip2, brotli 의존)
"${SCRIPT_DIR}/build_freetype.sh" "${BUILD_ARG}"

# 10. webp 빌드
"${SCRIPT_DIR}/build_webp.sh" "${BUILD_ARG}"

# 11. lua 빌드
"${SCRIPT_DIR}/build_lua.sh" "${BUILD_ARG}"

# 12. lua 빌드(본인 용도로 수정)
"${SCRIPT_DIR}/build_lua.sh" "${BUILD_ARG}" "-s"

echo ""
echo "=========================================="
echo "모든 라이브러리 빌드 완료!"
echo "=========================================="
