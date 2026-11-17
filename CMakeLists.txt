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
