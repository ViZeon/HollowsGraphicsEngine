cmake_minimum_required(VERSION 3.20)

# =========================================================
# Compiler Setup (BEFORE project() call)
# =========================================================
if(NOT DEFINED CMAKE_C_COMPILER)
    find_program(CLANG_EXE clang)
    if(CLANG_EXE)
        set(CMAKE_C_COMPILER ${CLANG_EXE})
    endif()
endif()

if(NOT DEFINED CMAKE_CXX_COMPILER)
    find_program(CLANGXX_EXE clang++)
    if(CLANGXX_EXE)
        set(CMAKE_CXX_COMPILER ${CLANGXX_EXE})
    endif()
endif()

message(STATUS "🔧 Compiler Configuration:")
message(STATUS "   C Compiler: ${CMAKE_C_COMPILER}")
message(STATUS "   C++ Compiler: ${CMAKE_CXX_COMPILER}")

# =========================================================
# Project Setup
# =========================================================
project(The_Hollows_Engine LANGUAGES CXX C)

# =========================================================
# Global Settings
# =========================================================
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_CONFIGURATION_TYPES "Debug;Release;Dist" CACHE STRING "" FORCE)

set(ARCH "x64")
set(OUTPUT_DIR "${CMAKE_BUILD_TYPE}-${CMAKE_SYSTEM_NAME}-${ARCH}")

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

# =========================================================
# Auto-fetch and update all git submodules (recursive)
# =========================================================
if(EXISTS "${CMAKE_SOURCE_DIR}/.git")
    message(STATUS "🔁 Ensuring all git submodules are up to date...")
    execute_process(
        COMMAND git submodule update --init --recursive
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        RESULT_VARIABLE GIT_SUBMODULE_RESULT
#        OUTPUT_QUIET ERROR_QUIET
    )
    if(NOT GIT_SUBMODULE_RESULT EQUAL 0)
        message(WARNING "⚠️ Failed to auto-update git submodules (you may need to run it manually).")
    endif()
endif()

# =========================================================
# Major Dependencies (need special handling)
# =========================================================
# SDL
if(EXISTS "${CMAKE_SOURCE_DIR}/vendor/lib/SDL/CMakeLists.txt")
    message(STATUS "🎮 Adding SDL3")
    set(SDL_SHARED OFF CACHE BOOL "" FORCE)
    set(SDL_STATIC ON CACHE BOOL "" FORCE)
    add_subdirectory(vendor/lib/SDL EXCLUDE_FROM_ALL)
endif()

# Diligent Engine
if(EXISTS "${CMAKE_SOURCE_DIR}/vendor/lib/DiligentEngine/CMakeLists.txt")
    message(STATUS "🎨 Adding Diligent Engine")
    add_subdirectory(vendor/lib/DiligentEngine EXCLUDE_FROM_ALL)
endif()

# =========================================================
# Auto-Add Other Submodules (excluding SDL and Diligent)
# =========================================================
set(VENDOR_LIB_DIR "${CMAKE_SOURCE_DIR}/vendor/lib")
set(AUTO_LINK_TARGETS "")
set(SKIP_SUBMODULES "SDL;DiligentEngine")

if(EXISTS ${VENDOR_LIB_DIR})
    file(GLOB SUBMODULE_DIRS RELATIVE ${VENDOR_LIB_DIR} ${VENDOR_LIB_DIR}/*)
    foreach(SUBMOD ${SUBMODULE_DIRS})
        # Skip already-added submodules
        if(SUBMOD IN_LIST SKIP_SUBMODULES)
            continue()
        endif()
        
        set(SUBMOD_PATH "${VENDOR_LIB_DIR}/${SUBMOD}")
        if(EXISTS "${SUBMOD_PATH}/CMakeLists.txt")
            message(STATUS "🧩 Adding submodule: ${SUBMOD}")
            add_subdirectory(${SUBMOD_PATH} EXCLUDE_FROM_ALL)

            # Capture targets added by the submodule
            get_property(NEW_TARGETS DIRECTORY ${SUBMOD_PATH} PROPERTY BUILDSYSTEM_TARGETS)
            if(NEW_TARGETS)
                list(APPEND AUTO_LINK_TARGETS ${NEW_TARGETS})
                message(STATUS "   ↳ Found targets: ${NEW_TARGETS}")
            endif()
        endif()
    endforeach()
endif()

list(REMOVE_DUPLICATES AUTO_LINK_TARGETS)

# =========================================================
# Hollows Engine (Shared Library)
# =========================================================
file(GLOB_RECURSE ENGINE_SOURCES
    src/engine/*.cpp
    src/engine/*.c
    src/engine/*.hpp
    src/engine/*.h
)

add_library(Hollows_Engine SHARED ${ENGINE_SOURCES})

target_include_directories(Hollows_Engine
    PUBLIC
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/src/engine
        ${CMAKE_SOURCE_DIR}/vendor/lib
)

# Link automatically detected submodule targets
foreach(TGT ${AUTO_LINK_TARGETS})
    message(STATUS "🔗 Auto-linking submodule target: ${TGT}")
    target_link_libraries(Hollows_Engine PRIVATE ${TGT})
endforeach()

# Also link manual external libs
target_link_libraries(Hollows_Engine PRIVATE
    spdlog::spdlog
    SDL3::SDL3-static
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