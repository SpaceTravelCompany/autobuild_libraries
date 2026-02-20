cmake_minimum_required(VERSION 3.20)
project(clipper2c LANGUAGES CXX)

set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CLIPPER2_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/vendor/Clipper2")
set(CLIPPER2_CPP_DIR "${CLIPPER2_ROOT}/CPP")

set(CLIPPER2_UTILS OFF)
set(CLIPPER2_EXAMPLES OFF)
set(CLIPPER2_TESTS OFF)
set(CLIPPER2_USINGZ "OFF" CACHE STRING "Preempt cache default of USINGZ (only binding 2d)")
add_definitions(-D_HAS_EXCEPTIONS=0) # disable exceptions for STL

option(BUILD_SHARED_LIBS OFF)
if (NOT WIN32)
    add_compile_options(-fPIC)
endif()

add_subdirectory(${CLIPPER2_CPP_DIR} ${CMAKE_BINARY_DIR}/Clipper2_build)

# C Bindings
file(GLOB_RECURSE SOURCE_FILES src/*.cpp)
add_library(clipper2c ${SOURCE_FILES})

target_link_libraries(clipper2c PRIVATE Clipper2)
target_include_directories(clipper2c PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_compile_features(clipper2c PRIVATE cxx_std_17)

# Install for use as replacement in autobuild_libraries
install(TARGETS clipper2c
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
  RUNTIME DESTINATION bin)
install(DIRECTORY include/
  DESTINATION include
  FILES_MATCHING PATTERN "*.h")
