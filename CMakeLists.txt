cmake_minimum_required(VERSION 3.16)

project(fuzzy_k_mer_counter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(SEQAN3_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/deps/seqan3/include")

# SeqAn3 is vendored as a git submodule; fetch it if it has not been pulled yet.
if(NOT EXISTS "${SEQAN3_INCLUDE_DIR}/seqan3/version.hpp")
    find_package(Git QUIET)
    if(GIT_FOUND AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
        message(STATUS "SeqAn3 headers missing; running 'git submodule update --init'")
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" submodule update --init --recursive
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE FKM_SUBMODULE_RESULT
            OUTPUT_VARIABLE FKM_SUBMODULE_OUTPUT
            ERROR_VARIABLE FKM_SUBMODULE_ERROR
        )
        if(NOT FKM_SUBMODULE_RESULT EQUAL 0)
            message(FATAL_ERROR
                "git submodule update --init failed (${FKM_SUBMODULE_RESULT}):\n"
                "${FKM_SUBMODULE_OUTPUT}${FKM_SUBMODULE_ERROR}")
        endif()
    endif()
endif()

if(NOT EXISTS "${SEQAN3_INCLUDE_DIR}/seqan3/version.hpp")
    message(FATAL_ERROR
        "SeqAn3 headers not found at ${SEQAN3_INCLUDE_DIR}.\n"
        "Fetch the dependencies with: git submodule update --init")
endif()

find_package(ZLIB REQUIRED)

# Xcode Command Line Tools are supposed to provide the C++ standard library
# headers, but they are missing or stale on some machines (typically after a
# macOS upgrade), which makes every build fail with e.g.
#   fatal error: 'cstring' file not found
# Detect that here, patch around it, and tell the user loudly. This is a
# workaround for a broken local toolchain, not a project requirement.
# The result is deliberately not cached, so the workaround goes away again
# once the toolchain is repaired.
if(APPLE AND NOT CMAKE_CXX_FLAGS MATCHES "c\\+\\+/v1")
    include(CMakePushCheckState)
    include(CheckCXXSourceCompiles)
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_QUIET ON)
    check_cxx_source_compiles("#include <cstring>\nint main(){return 0;}"
        FKM_STDLIB_HEADERS_CHECK)
    set(fkm_headers_ok "${FKM_STDLIB_HEADERS_CHECK}")
    unset(FKM_STDLIB_HEADERS_CHECK CACHE)
    if(NOT fkm_headers_ok)
        # The headers come with the macOS SDK: <sdk>/usr/include/c++/v1.
        execute_process(COMMAND xcrun --show-sdk-path
            OUTPUT_VARIABLE FKM_SDK_PATH OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET)
        if(FKM_SDK_PATH AND EXISTS "${FKM_SDK_PATH}/usr/include/c++/v1/cstring")
            add_compile_options("-isystem" "${FKM_SDK_PATH}/usr/include/c++/v1")
            set(CMAKE_REQUIRED_FLAGS "-isystem ${FKM_SDK_PATH}/usr/include/c++/v1")
            check_cxx_source_compiles("#include <cstring>\nint main(){return 0;}"
                FKM_STDLIB_HEADERS_FIXED)
            set(fkm_headers_fixed "${FKM_STDLIB_HEADERS_FIXED}")
            unset(FKM_STDLIB_HEADERS_FIXED CACHE)
            if(fkm_headers_fixed)
                message(WARNING
                    "The C++ standard library headers were not found by the\n"
                    "compiler, which usually means the Xcode Command Line Tools\n"
                    "are missing or stale. fkm_count worked around this by adding\n"
                    "  -isystem ${FKM_SDK_PATH}/usr/include/c++/v1\n"
                    "to the include path. Please fix your Command Line Tools\n"
                    "(xcode-select --install) so this workaround is not needed.")
            else()
                message(FATAL_ERROR
                    "The C++ standard library headers could not be found even\n"
                    "after adding the macOS SDK include path. Please (re)install\n"
                    "the Xcode Command Line Tools: xcode-select --install")
            endif()
        else()
            message(FATAL_ERROR
                "Cannot find the macOS SDK C++ headers. Please (re)install the\n"
                "Xcode Command Line Tools: xcode-select --install")
        endif()
    endif()
    cmake_pop_check_state()
endif()

# AppleClang has no OpenMP support of its own, so a separate libomp is needed.
# FindOpenMP only looks on the default search paths, where conda-forge's
# llvm-openmp and Homebrew's keg-only libomp are not installed. Point the
# search at the usual locations; -DOpenMP_ROOT overrides these.
if(APPLE AND NOT OpenMP_CXX_FOUND AND NOT OpenMP_ROOT AND NOT "$ENV{OpenMP_ROOT}")
    set(FKM_OMP_PREFIXES "$ENV{CONDA_PREFIX}" /opt/homebrew/opt/libomp /usr/local/opt/libomp)
    foreach(fkm_omp_prefix IN LISTS FKM_OMP_PREFIXES)
        if(fkm_omp_prefix AND NOT OpenMP_libomp_LIBRARY
           AND EXISTS "${fkm_omp_prefix}/lib/libomp.dylib")
            set(OpenMP_libomp_LIBRARY "${fkm_omp_prefix}/lib/libomp.dylib")
            if(NOT OpenMP_CXX_INCLUDE_DIR AND EXISTS "${fkm_omp_prefix}/include/omp.h")
                set(OpenMP_CXX_INCLUDE_DIR "${fkm_omp_prefix}/include")
            endif()
        endif()
    endforeach()
    unset(FKM_OMP_PREFIXES)
    unset(fkm_omp_prefix)
endif()

find_package(OpenMP QUIET)

add_executable(fkm_count count.cpp)

target_include_directories(fkm_count PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${SEQAN3_INCLUDE_DIR}"
)

# bzip2 support is not wanted, even though seqan3 would enable it when bzlib.h is present.
target_compile_definitions(fkm_count PRIVATE SEQAN3_HAS_BZIP2=0)

if(OpenMP_CXX_FOUND)
    target_link_libraries(fkm_count PRIVATE OpenMP::OpenMP_CXX)
else()
    message(WARNING "OpenMP not found; building without multithreading support.")
endif()

target_link_libraries(fkm_count PRIVATE ZLIB::ZLIB)

install(TARGETS fkm_count RUNTIME DESTINATION bin)
