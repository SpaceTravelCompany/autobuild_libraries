# Auto Build Libraries

여러 라이브러리를 자동으로 빌드하는 프로젝트입니다.

## 지원하는 라이브러리

- **freetype**: FreeType은 자유 소프트웨어로, 폰트 렌더링 라이브러리입니다.

## 시작하기

### 1. Git Submodule 설정

프로젝트를 클론한 후, submodule을 초기화합니다:

```bash
# 방법 1: 자동 스크립트 사용
chmod +x setup_submodules.sh
./setup_submodules.sh

# 방법 2: 수동으로 실행
git submodule update --init --recursive
```

### 2. 라이브러리 빌드

#### freetype 빌드

**크로스 빌드 (기본)**:
```bash
chmod +x build_freetype.sh
./build_freetype.sh
```

다음 타겟 아키텍처에 대해 크로스 빌드를 수행하며, 각 타겟마다 **공유 라이브러리**와 **정적 라이브러리**를 모두 빌드합니다:
- `aarch64-linux-gnu`
- `riscv64-linux-gnu`
- `x86_64-linux-gnu`
- `i386-linux-gnu`

**네이티브 빌드만**:
```bash
./build_freetype.sh --native
# 또는
./build_freetype.sh -n
```

현재 시스템 아키텍처에 대해서만 네이티브 빌드를 수행합니다.

빌드된 라이브러리는 각 타겟별로 `install/freetype/<target>/` 디렉토리에 설치되며, 공유 라이브러리와 정적 라이브러리가 모두 포함됩니다.

## GitHub Actions

이 프로젝트는 GitHub Actions를 사용하여 자동으로 빌드합니다:

- **트리거**: push, pull request, 또는 수동 실행
- **플랫폼**: Ubuntu, macOS, Windows
- **아티팩트**: 빌드된 라이브러리가 자동으로 업로드됩니다

## 프로젝트 구조

```
autobuild_libraries/
├── libs/                    # Git submodule로 관리되는 라이브러리 소스
│   └── freetype/
├── build/                   # 빌드 중간 파일들 (gitignore)
│   └── freetype/
│       ├── <target>-shared/
│       ├── <target>-static/
│       ├── aarch64-linux-gnu-shared/
│       ├── aarch64-linux-gnu-static/
│       └── ...
├── install/                 # 빌드된 라이브러리 설치 위치 (gitignore)
│   └── freetype/
│       ├── <target>/
│       ├── aarch64-linux-gnu/
│       └── ...
├── .github/
│   └── workflows/
│       └── build.yml        # GitHub Actions 워크플로우
├── build_freetype.sh        # freetype 빌드 스크립트
├── setup_submodules.sh      # Submodule 설정 스크립트
└── README.md
```

## 새로운 라이브러리 추가하기

1. `libs/` 디렉토리에 submodule로 라이브러리 추가:
   ```bash
   git submodule add <repository-url> libs/<library-name>
   ```

2. 빌드 스크립트 작성: `build_<library-name>.sh`

3. GitHub Actions 워크플로우에 새 라이브러리 빌드 작업 추가

## 요구사항

- CMake 3.10 이상
- C/C++ 컴파일러 (GCC, Clang, MSVC)
- Git

### Linux
```bash
sudo apt-get install build-essential cmake libpng-dev zlib1g-dev libbz2-dev
```

### macOS
```bash
brew install cmake libpng zlib bzip2
```

### Windows
```bash
choco install cmake
```

