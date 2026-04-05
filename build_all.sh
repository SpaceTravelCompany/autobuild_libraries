#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "모든 라이브러리 빌드 시작"
echo "=========================================="
echo ""

# 빌드 인자
BUILD_ARG="$1"

# 1. libz, bzip2, brotli 빌드 (freetype 의존)
"${SCRIPT_DIR}/build_libz.sh" "${BUILD_ARG}"
"${SCRIPT_DIR}/build_bzip2.sh" "${BUILD_ARG}"
"${SCRIPT_DIR}/build_brotli.sh" "${BUILD_ARG}"

# 2. freetype 빌드 (harfbuzz 없이, harfbuzz가 freetype 필요)
"${SCRIPT_DIR}/build_freetype.sh" "${BUILD_ARG}" --no-harfbuzz

# 3. harfbuzz 빌드 (freetype 연동)
"${SCRIPT_DIR}/build_harfbuzz.sh" "${BUILD_ARG}" --with-freetype

# 4. freetype 재빌드 (harfbuzz 연동)
"${SCRIPT_DIR}/build_freetype.sh" "${BUILD_ARG}"

# 5. cmark 빌드
"${SCRIPT_DIR}/build_cmark.sh" "${BUILD_ARG}"

# 6. plutovg 빌드
"${SCRIPT_DIR}/build_plutovg.sh" "${BUILD_ARG}"

# 7. ogg 빌드
"${SCRIPT_DIR}/build_ogg.sh" "${BUILD_ARG}"

# 8. opus 빌드
"${SCRIPT_DIR}/build_opus.sh" "${BUILD_ARG}"

# 9. vorbis 빌드 (ogg 의존)
"${SCRIPT_DIR}/build_vorbis.sh" "${BUILD_ARG}"

# 10. opusfile 빌드 (opus 의존)
"${SCRIPT_DIR}/build_opusfile.sh" "${BUILD_ARG}"

# 11. miniaudio 빌드 (vorbis, opusfile, ogg, opus 의존)
"${SCRIPT_DIR}/build_miniaudio.sh" "${BUILD_ARG}"

# 12. webp 빌드
"${SCRIPT_DIR}/build_webp.sh" "${BUILD_ARG}"

# 13. lua 빌드
"${SCRIPT_DIR}/build_lua.sh" "${BUILD_ARG}"

echo ""
echo "=========================================="
echo "모든 라이브러리 빌드 완료!"
echo "=========================================="
