#!/bin/bash
set -e

# Git submodule 초기화 및 업데이트 스크립트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Git submodule 초기화 중..."

# zlib submodule 추가 (아직 추가되지 않은 경우)
if [ ! -f ".gitmodules" ] || ! grep -q "zlib" .gitmodules 2>/dev/null; then
    echo "zlib submodule 추가 중..."
    git submodule add https://github.com/madler/zlib.git libs/zlib
fi

# freetype submodule 추가 (아직 추가되지 않은 경우)
if [ ! -f ".gitmodules" ] || ! grep -q "freetype" .gitmodules 2>/dev/null; then
    echo "freetype submodule 추가 중..."
    git submodule add https://github.com/freetype/freetype.git libs/freetype
fi

# 모든 submodule 초기화 및 업데이트
git submodule update --init --recursive

echo "Submodule 설정 완료!"

