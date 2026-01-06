# GL Example - GLSL to SPIR-V 변환

이 폴더는 glslang 라이브러리를 사용하여 GLSL 셰이더를 SPIR-V 바이너리로 변환하는 예제 코드를 포함합니다.

## 파일 목록

- **`glsl_to_spirv.c`**: GLSL을 SPIR-V로 변환하는 메인 프로그램
- **`example_shader.vert`**: 버텍스 셰이더 예제
- **`example_shader.frag`**: 프래그먼트 셰이더 예제
- **`GLSL_TO_SPIRV.md`**: 상세한 사용 가이드

## 빠른 시작

### 컴파일

```bash
gcc -o glsl_to_spirv glsl_to_spirv.c \
    -lglslang -lSPIRV -lMachineIndependent \
    -lGenericCodeGen -lOGLCompiler -lOSDependent
```

### 사용

```bash
# 버텍스 셰이더 컴파일
./glsl_to_spirv vertex example_shader.vert shader.vert.spv

# 프래그먼트 셰이더 컴파일
./glsl_to_spirv fragment example_shader.frag shader.frag.spv
```

자세한 내용은 [GLSL_TO_SPIRV.md](GLSL_TO_SPIRV.md)를 참고하세요.
