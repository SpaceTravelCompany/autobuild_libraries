# GLSL to SPIR-V 변환 가이드

이 문서는 glslang 라이브러리를 사용하여 GLSL 셰이더를 SPIR-V 바이너리로 변환하는 방법을 설명합니다.

## 개요

`glsl_to_spirv.c`는 glslang의 C API를 사용하여 GLSL 셰이더 코드를 SPIR-V 바이너리로 컴파일하는 프로그램입니다.

## 필요한 라이브러리

- **glslang**: Khronos Group의 GLSL 컴파일러/검증 도구
  - GitHub: https://github.com/KhronosGroup/glslang
  - 필요한 라이브러리:
    - `libglslang`
    - `libSPIRV`
    - `libMachineIndependent`
    - `libGenericCodeGen`
    - `libOGLCompiler`
    - `libOSDependent`

## 컴파일 방법

### 방법 1: 직접 컴파일

```bash
gcc -o glsl_to_spirv glsl_to_spirv.c \
    -lglslang -lSPIRV -lMachineIndependent \
    -lGenericCodeGen -lOGLCompiler -lOSDependent
```

### 방법 2: CMake 사용

```cmake
cmake_minimum_required(VERSION 3.10)
project(glsl_to_spirv)

find_package(glslang REQUIRED)

add_executable(glsl_to_spirv glsl_to_spirv.c)
target_link_libraries(glsl_to_spirv 
    glslang::glslang
    glslang::SPIRV
    glslang::MachineIndependent
    glslang::GenericCodeGen
    glslang::OGLCompiler
    glslang::OSDependent
)
```

### 방법 3: pkg-config 사용 (가능한 경우)

```bash
gcc -o glsl_to_spirv glsl_to_spirv.c $(pkg-config --cflags --libs glslang)
```

## 사용 방법

### 기본 사용법

```bash
./glsl_to_spirv <셰이더_스테이지> <입력_파일> [출력_파일]
```

### 셰이더 스테이지

- `vertex` 또는 `vert` - 버텍스 셰이더
- `fragment` 또는 `frag` - 프래그먼트 셰이더
- `compute` 또는 `comp` - 컴퓨트 셰이더
- `geometry` 또는 `geom` - 지오메트리 셰이더
- `tesscontrol` 또는 `tesc` - 테셀레이션 컨트롤 셰이더
- `tesseval` 또는 `tese` - 테셀레이션 평가 셰이더

### 예제

```bash
# 버텍스 셰이더 컴파일
./glsl_to_spirv vertex example_shader.vert shader.vert.spv

# 프래그먼트 셰이더 컴파일 (출력 파일명 자동 생성)
./glsl_to_spirv fragment example_shader.frag

# 컴퓨트 셰이더 컴파일
./glsl_to_spirv compute compute_shader.comp compute.spv
```

## 코드 구조

### 주요 함수

1. **`compile_glsl_to_spirv()`**
   - GLSL 소스 코드를 SPIR-V 바이너리로 컴파일
   - 파라미터:
     - `stage`: 셰이더 스테이지
     - `shaderSource`: GLSL 소스 코드 문자열
     - `fileName`: 파일 이름 (디버깅용)
   - 반환: `SpirVBinary` 구조체

2. **`save_spirv_to_file()`**
   - SPIR-V 바이너리를 파일로 저장
   - 파라미터:
     - `binary`: SPIR-V 바이너리 구조체
     - `filename`: 출력 파일 이름
   - 반환: 성공 시 0, 실패 시 -1

3. **`free_spirv_binary()`**
   - SPIR-V 바이너리 메모리 해제

4. **`read_file()`**
   - 파일에서 GLSL 소스 코드 읽기
   - 반환: 읽은 문자열 (호출자가 free 해야 함)

## 컴파일 프로세스

1. **초기화**: `glslang_initialize_process()` 호출
2. **셰이더 생성**: `glslang_shader_create()`로 셰이더 객체 생성
3. **전처리**: `glslang_shader_preprocess()`로 GLSL 전처리
4. **파싱**: `glslang_shader_parse()`로 GLSL 파싱
5. **프로그램 생성**: `glslang_program_create()`로 프로그램 객체 생성
6. **링크**: `glslang_program_link()`로 프로그램 링크
7. **SPIR-V 생성**: `glslang_program_SPIRV_generate()`로 SPIR-V 생성
8. **데이터 추출**: `glslang_program_SPIRV_get()`로 SPIR-V 바이너리 추출
9. **정리**: 모든 리소스 해제 및 `glslang_finalize_process()` 호출

## 예제 셰이더

프로젝트에 포함된 예제 셰이더:

- `example_shader.vert`: 버텍스 셰이더 예제
- `example_shader.frag`: 프래그먼트 셰이더 예제

### 예제 실행

```bash
# 버텍스 셰이더 컴파일
./glsl_to_spirv vertex example_shader.vert example_shader.vert.spv

# 프래그먼트 셰이더 컴파일
./glsl_to_spirv fragment example_shader.frag example_shader.frag.spv
```

## 대안: glslangValidator 명령줄 도구

glslang 라이브러리 대신 `glslangValidator` 명령줄 도구를 사용할 수도 있습니다:

```bash
# Vulkan용 SPIR-V 생성
glslangValidator -V -o output.spv input.vert

# 셰이더 스테이지 자동 감지
glslangValidator -V shader.vert -o shader.vert.spv
glslangValidator -V shader.frag -o shader.frag.spv
```

### glslangValidator 옵션

- `-V`: Vulkan용 SPIR-V 생성
- `-o <file>`: 출력 파일 지정
- `-S <stage>`: 셰이더 스테이지 지정 (vert, frag, comp 등)
- `--target-env vulkan1.2`: 타겟 환경 지정

## 문제 해결

### glslang 라이브러리를 찾을 수 없음

```bash
# Ubuntu/Debian
sudo apt-get install libglslang-dev

# 또는 소스에서 빌드
git clone https://github.com/KhronosGroup/glslang.git
cd glslang
mkdir build && cd build
cmake ..
make
sudo make install
```

### 링크 오류

필요한 모든 라이브러리가 링크되었는지 확인하세요:

```bash
# 라이브러리 위치 확인
ldconfig -p | grep glslang
```

### 컴파일 오류

GLSL 버전과 Vulkan 버전이 호환되는지 확인하세요. 예제 코드는 GLSL 4.50과 Vulkan 1.2를 사용합니다.

## 참고 자료

- [glslang GitHub](https://github.com/KhronosGroup/glslang)
- [SPIR-V Specification](https://www.khronos.org/spir/)
- [Vulkan Shader Documentation](https://www.khronos.org/registry/vulkan/specs/1.3-extensions/html/vkspec.html#shaders)
