cmake_minimum_required(VERSION 3.16)

project(fuzzy_k_mer_counter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(ZLIB REQUIRED)
find_package(OpenMP QUIET)

add_executable(fkm_count count.cpp)

target_include_directories(fkm_count PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/deps/seqan3/include"
)

if(OpenMP_CXX_FOUND)
    target_link_libraries(fkm_count PRIVATE OpenMP::OpenMP_CXX)
else()
    message(WARNING "OpenMP not found; building without multithreading support.")
endif()

target_link_libraries(fkm_count PRIVATE ZLIB::ZLIB)

install(TARGETS fkm_count RUNTIME DESTINATION bin)
