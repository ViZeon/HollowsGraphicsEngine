cmake_minimum_required(VERSION 3.20)

# =========================================================
# Project Setup
# =========================================================
# Prefer Clang, but allow others (MSVC, GCC) if not found.
if(NOT CMAKE_C_COMPILER AND NOT CMAKE_CXX_COMPILER)
    find_program(CLANG_EXE clang++)
    if(CLANG_EXE)
        message(STATUS "🔧 Using Clang as default compiler: ${CLANG_EXE}")
        set(CMAKE_C_COMPILER clang CACHE STRING "C compiler" FORCE)
        set(CMAKE_CXX_COMPILER clang++ CACHE STRING "C++ compiler" FORCE)
    else()
        message(STATUS "🧩 Clang not found, using system default compiler")
    endif()
endif()

project(The_Hollows_Engine LANGUAGES CXX)

# =========================================================
# Global Settings
# =========================================================

# Generate compile_commands.json for clangd / VSCode / Sublime
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# C++23 and safe defaults
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Custom configurations
set(CMAKE_CONFIGURATION_TYPES "Debug;Release;Dist" CACHE STRING "" FORCE)

# Architecture
set(ARCH "x64")
set(OUTPUT_DIR "${CMAKE_BUILD_TYPE}-${CMAKE_SYSTEM_NAME}-${ARCH}")

# Output directories
foreach(TYPE RUNTIME ARCHIVE LIBRARY)
    set(CMAKE_${TYPE}_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR})
endforeach()

# =========================================================
# Include CPM (CMake Package Manager)
# =========================================================
set(CPM_DOWNLOAD_VERSION 0.40.2)
set(CPM_DOWNLOAD_LOCATION "${CMAKE_BINARY_DIR}/cmake/CPM.cmake")

if(NOT EXISTS ${CPM_DOWNLOAD_LOCATION})
    message(STATUS "Downloading CPM.cmake v${CPM_DOWNLOAD_VERSION}")
    file(DOWNLOAD
        https://github.com/cpm-cmake/CPM.cmake/releases/download/v${CPM_DOWNLOAD_VERSION}/CPM.cmake
        ${CPM_DOWNLOAD_LOCATION}
    )
endif()
include(${CPM_DOWNLOAD_LOCATION})

# =========================================================
# Dependencies
# =========================================================
add_compile_definitions(SPDLOG_USE_STD_FORMAT)
CPMAddPackage("gh:gabime/spdlog@1.14.1")
#CPMAddPackage("gh:nicbarker/clay@0.14")
#    Name Clay
#    GITHUB_REPOSITORY nicbarker/clay
#    GIT_TAG 0.14)

# =========================================================
# SDL3 (Git Submodule Integration)
# =========================================================
# If you want static linking (recommended for a single-engine DLL):
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

# If you prefer dynamic linking (optional):
# set(SDL_STATIC OFF CACHE BOOL "" FORCE)
# set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)

# Add SDL3 as a submodule project
add_subdirectory(vendor/lib/SDL)

# SDL3 defines modern CMake targets:
# - SDL3::SDL3 (auto-aliased to static/shared depending on your config)
# - SDL3::SDL3-static
# - SDL3::SDL3-shared
# =========================================================
# Hollows Engine (Shared Library)
# =========================================================
file(GLOB_RECURSE ENGINE_SOURCES
    src/engine/*.cpp
    src/engine/*.c
    src/engine/*.h
)

add_library(Hollows_Engine SHARED ${ENGINE_SOURCES})

target_include_directories(Hollows_Engine
    PUBLIC
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/src/engine
        ${CMAKE_SOURCE_DIR}/vendor/lib/SDL/include
)

target_link_libraries(Hollows_Engine
    SDL3::SDL3
    spdlog::spdlog
    winmm
    imm32
    version
    setupapi
)

target_compile_definitions(Hollows_Engine PRIVATE
    HZ_PLATFORM_WINDOWS
    HZ_BUILD_DLL
    SDL_STATIC_LIB
    $<$<CONFIG:Debug>:HZ_DEBUG>
    $<$<CONFIG:Release>:HZ_RELEASE>
    $<$<CONFIG:Dist>:HZ_DIST>
)

target_compile_options(Hollows_Engine PRIVATE -Wall -Wextra -Wpedantic)

add_custom_command(TARGET Hollows_Engine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR}/Assets
    COMMAND ${CMAKE_COMMAND} -E copy
        $<TARGET_FILE:Hollows_Engine>
        ${CMAKE_SOURCE_DIR}/bin/${OUTPUT_DIR}/Assets
)

# =========================================================
# Assets (Console App)
# =========================================================
file(GLOB_RECURSE ASSET_SOURCES
    src/assets/*.cpp
    src/assets/*.c
    src/assets/*.h
)

add_executable(Assets ${ASSET_SOURCES})
add_dependencies(Assets Hollows_Engine)

target_include_directories(Assets PRIVATE ${CMAKE_SOURCE_DIR}/src/engine)
target_link_libraries(Assets PRIVATE Hollows_Engine spdlog::spdlog)

target_compile_definitions(Assets PRIVATE
    HZ_PLATFORM_WINDOWS
    $<$<CONFIG:Debug>:HZ_DEBUG>
    $<$<CONFIG:Release>:HZ_RELEASE>
    $<$<CONFIG:Dist>:HZ_DIST>
)

target_compile_options(Assets PRIVATE -Wall -Wextra -Wpedantic)