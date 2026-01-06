/*
 * GLSL to SPIR-V Converter using glslang
 * 
 * 이 프로그램은 GLSL 셰이더 코드를 SPIR-V 바이너리로 변환합니다.
 * glslang 라이브러리의 C API를 사용합니다.
 * 
 * 컴파일:
 *   gcc -o glsl_to_spirv glsl_to_spirv.c -lglslang -lSPIRV -lMachineIndependent -lGenericCodeGen -lOGLCompiler -lOSDependent
 * 
 * 또는 CMake를 사용하여 glslang을 링크하세요.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// glslang C 인터페이스 헤더
#include <glslang/Include/glslang_c_interface.h>
#include <glslang/Public/resource_limits_c.h>

// SPIR-V 바이너리 구조체
typedef struct {
    uint32_t *words;  // SPIR-V 단어 배열
    size_t size;      // SPIR-V 바이너리의 단어 수
} SpirVBinary;

/**
 * GLSL 셰이더를 SPIR-V로 컴파일
 * 
 * @param stage 셰이더 스테이지 (GLSLANG_STAGE_VERTEX, GLSLANG_STAGE_FRAGMENT 등)
 * @param shaderSource GLSL 소스 코드
 * @param fileName 파일 이름 (디버깅용)
 * @return SPIR-V 바이너리 구조체 (실패 시 words는 NULL)
 */
SpirVBinary compile_glsl_to_spirv(glslang_stage_t stage, const char* shaderSource, const char* fileName) {
    SpirVBinary result = {NULL, 0};
    
    // glslang 초기화
    glslang_initialize_process();
    
    // 입력 설정
    const glslang_input_t input = {
        .language = GLSLANG_SOURCE_GLSL,
        .stage = stage,
        .client = GLSLANG_CLIENT_VULKAN,
        .client_version = GLSLANG_TARGET_VULKAN_1_2,
        .target_language = GLSLANG_TARGET_SPV,
        .target_language_version = GLSLANG_TARGET_SPV_1_5,
        .code = shaderSource,
        .default_version = 450,  // GLSL 4.50
        .default_profile = GLSLANG_NO_PROFILE,
        .force_default_version_and_profile = false,
        .forward_compatible = false,
        .messages = GLSLANG_MSG_DEFAULT_BIT,
        .resource = glslang_default_resource()
    };
    
    // 셰이더 생성
    glslang_shader_t* shader = glslang_shader_create(&input);
    if (!shader) {
        fprintf(stderr, "셰이더 생성 실패\n");
        glslang_finalize_process();
        return result;
    }
    
    // 전처리
    if (!glslang_shader_preprocess(shader, &input)) {
        fprintf(stderr, "GLSL 전처리 실패: %s\n", glslang_shader_get_info_log(shader));
        glslang_shader_delete(shader);
        glslang_finalize_process();
        return result;
    }
    
    // 파싱
    if (!glslang_shader_parse(shader, &input)) {
        fprintf(stderr, "GLSL 파싱 실패: %s\n", glslang_shader_get_info_log(shader));
        glslang_shader_delete(shader);
        glslang_finalize_process();
        return result;
    }
    
    // 프로그램 생성 및 셰이더 추가
    glslang_program_t* program = glslang_program_create();
    glslang_program_add_shader(program, shader);
    
    // 링크
    if (!glslang_program_link(program, GLSLANG_MSG_DEFAULT_BIT)) {
        fprintf(stderr, "프로그램 링크 실패: %s\n", glslang_program_get_info_log(program));
        glslang_shader_delete(shader);
        glslang_program_delete(program);
        glslang_finalize_process();
        return result;
    }
    
    // SPIR-V 생성
    glslang_program_SPIRV_generate(program, stage);
    
    // SPIR-V 크기 가져오기
    size_t spirvSize = glslang_program_SPIRV_get_size(program);
    if (spirvSize == 0) {
        fprintf(stderr, "SPIR-V 생성 실패\n");
        glslang_shader_delete(shader);
        glslang_program_delete(program);
        glslang_finalize_process();
        return result;
    }
    
    // SPIR-V 데이터 할당 및 복사
    uint32_t* spirvCode = (uint32_t*)malloc(spirvSize * sizeof(uint32_t));
    if (!spirvCode) {
        fprintf(stderr, "메모리 할당 실패\n");
        glslang_shader_delete(shader);
        glslang_program_delete(program);
        glslang_finalize_process();
        return result;
    }
    
    glslang_program_SPIRV_get(program, spirvCode);
    
    // 리소스 정리
    glslang_shader_delete(shader);
    glslang_program_delete(program);
    glslang_finalize_process();
    
    result.words = spirvCode;
    result.size = spirvSize;
    
    return result;
}

/**
 * SPIR-V 바이너리를 파일로 저장
 * 
 * @param binary SPIR-V 바이너리
 * @param filename 출력 파일 이름
 * @return 성공 시 0, 실패 시 -1
 */
int save_spirv_to_file(const SpirVBinary* binary, const char* filename) {
    if (!binary || !binary->words || binary->size == 0) {
        fprintf(stderr, "유효하지 않은 SPIR-V 바이너리\n");
        return -1;
    }
    
    FILE* file = fopen(filename, "wb");
    if (!file) {
        fprintf(stderr, "파일 열기 실패: %s\n", filename);
        return -1;
    }
    
    size_t written = fwrite(binary->words, sizeof(uint32_t), binary->size, file);
    fclose(file);
    
    if (written != binary->size) {
        fprintf(stderr, "파일 쓰기 실패: %s\n", filename);
        return -1;
    }
    
    printf("SPIR-V 바이너리 저장 완료: %s (%zu words)\n", filename, binary->size);
    return 0;
}

/**
 * SPIR-V 바이너리 메모리 해제
 */
void free_spirv_binary(SpirVBinary* binary) {
    if (binary && binary->words) {
        free(binary->words);
        binary->words = NULL;
        binary->size = 0;
    }
}

/**
 * 파일에서 GLSL 소스 코드 읽기
 * 
 * @param filename 파일 이름
 * @return 읽은 문자열 (호출자가 free 해야 함), 실패 시 NULL
 */
char* read_file(const char* filename) {
    FILE* file = fopen(filename, "rb");
    if (!file) {
        fprintf(stderr, "파일 열기 실패: %s\n", filename);
        return NULL;
    }
    
    // 파일 크기 확인
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    if (size < 0) {
        fclose(file);
        return NULL;
    }
    
    // 메모리 할당
    char* buffer = (char*)malloc(size + 1);
    if (!buffer) {
        fclose(file);
        return NULL;
    }
    
    // 파일 읽기
    size_t read = fread(buffer, 1, size, file);
    fclose(file);
    
    buffer[read] = '\0';
    return buffer;
}

/**
 * 셰이더 스테이지 문자열을 glslang_stage_t로 변환
 */
glslang_stage_t get_shader_stage(const char* stage_str) {
    if (strcmp(stage_str, "vertex") == 0 || strcmp(stage_str, "vert") == 0) {
        return GLSLANG_STAGE_VERTEX;
    } else if (strcmp(stage_str, "fragment") == 0 || strcmp(stage_str, "frag") == 0) {
        return GLSLANG_STAGE_FRAGMENT;
    } else if (strcmp(stage_str, "compute") == 0 || strcmp(stage_str, "comp") == 0) {
        return GLSLANG_STAGE_COMPUTE;
    } else if (strcmp(stage_str, "geometry") == 0 || strcmp(stage_str, "geom") == 0) {
        return GLSLANG_STAGE_GEOMETRY;
    } else if (strcmp(stage_str, "tesscontrol") == 0 || strcmp(stage_str, "tesc") == 0) {
        return GLSLANG_STAGE_TESSCONTROL;
    } else if (strcmp(stage_str, "tesseval") == 0 || strcmp(stage_str, "tese") == 0) {
        return GLSLANG_STAGE_TESSEVALUATION;
    }
    return GLSLANG_STAGE_VERTEX;  // 기본값
}

/**
 * 사용법 출력
 */
void print_usage(const char* program_name) {
    printf("사용법: %s <셰이더_스테이지> <입력_파일> [출력_파일]\n", program_name);
    printf("\n");
    printf("셰이더 스테이지:\n");
    printf("  vertex, vert    - 버텍스 셰이더\n");
    printf("  fragment, frag  - 프래그먼트 셰이더\n");
    printf("  compute, comp   - 컴퓨트 셰이더\n");
    printf("  geometry, geom  - 지오메트리 셰이더\n");
    printf("  tesscontrol, tesc - 테셀레이션 컨트롤 셰이더\n");
    printf("  tesseval, tese    - 테셀레이션 평가 셰이더\n");
    printf("\n");
    printf("예제:\n");
    printf("  %s vertex shader.vert shader.spv\n", program_name);
    printf("  %s fragment shader.frag\n", program_name);
}

/**
 * 메인 함수
 */
int main(int argc, char* argv[]) {
    if (argc < 3) {
        print_usage(argv[0]);
        return 1;
    }
    
    const char* stage_str = argv[1];
    const char* input_file = argv[2];
    const char* output_file = (argc >= 4) ? argv[3] : NULL;
    
    // 셰이더 스테이지 결정
    glslang_stage_t stage = get_shader_stage(stage_str);
    
    // GLSL 소스 코드 읽기
    char* shader_source = read_file(input_file);
    if (!shader_source) {
        return 1;
    }
    
    printf("GLSL 파일 읽기 완료: %s\n", input_file);
    printf("셰이더 스테이지: %s\n", stage_str);
    
    // SPIR-V로 컴파일
    SpirVBinary binary = compile_glsl_to_spirv(stage, shader_source, input_file);
    
    // 소스 코드 메모리 해제
    free(shader_source);
    
    if (!binary.words || binary.size == 0) {
        fprintf(stderr, "컴파일 실패\n");
        return 1;
    }
    
    printf("컴파일 성공: %zu words 생성\n", binary.size);
    
    // 출력 파일 이름 결정
    if (!output_file) {
        // 입력 파일 이름에서 확장자 변경
        const char* ext = strrchr(input_file, '.');
        if (ext) {
            size_t base_len = ext - input_file;
            output_file = (char*)malloc(base_len + 5);  // .spv + null
            if (output_file) {
                strncpy((char*)output_file, input_file, base_len);
                strcpy((char*)output_file + base_len, ".spv");
            }
        }
        if (!output_file) {
            output_file = "output.spv";
        }
    }
    
    // 파일로 저장
    int result = save_spirv_to_file(&binary, output_file);
    
    // 메모리 해제
    free_spirv_binary(&binary);
    
    if (result != 0) {
        return 1;
    }
    
    return 0;
}
