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
# Automatic Submodule Detection and Configuration
# =========================================================
set(VENDOR_LIB_DIR "${CMAKE_SOURCE_DIR}/vendor/lib")
set(ALL_SUBMODULE_TARGETS "")

# Function to filter targets - keeps libraries and excludes test/sample executables
function(filter_linkable_targets TARGET_LIST OUTPUT_VAR)
    set(FILTERED "")
    foreach(TGT ${TARGET_LIST})
        if(NOT TARGET ${TGT})
            continue()
        endif()

        get_target_property(TGT_TYPE ${TGT} TYPE)
        
        # Include static/shared/interface libraries
        if(TGT_TYPE MATCHES "STATIC_LIBRARY|SHARED_LIBRARY|INTERFACE_LIBRARY|MODULE_LIBRARY")
            list(APPEND FILTERED ${TGT})
        # Exclude executables that look like tests/samples/examples
        elseif(TGT_TYPE STREQUAL "EXECUTABLE")
            string(TOLOWER ${TGT} TGT_LOWER)
            if(NOT (TGT_LOWER MATCHES "test|sample|example|demo|tutorial"))
                list(APPEND FILTERED ${TGT})
            endif()
        endif()
    endforeach()
    set(${OUTPUT_VAR} ${FILTERED} PARENT_SCOPE)
endfunction()

if(EXISTS ${VENDOR_LIB_DIR})
    file(GLOB SUBMODULE_DIRS ${VENDOR_LIB_DIR}/*)

    foreach(SUBMOD_PATH ${SUBMODULE_DIRS})
        if(NOT IS_DIRECTORY ${SUBMOD_PATH})
            continue()
        endif()
        
        get_filename_component(SUBMOD_NAME ${SUBMOD_PATH} NAME)
        
        if(EXISTS "${SUBMOD_PATH}/CMakeLists.txt")
            message(STATUS "🧩 Adding submodule: ${SUBMOD_NAME}")
            
            # Configure known submodules with their specific options BEFORE adding them
            if(SUBMOD_NAME STREQUAL "SDL")
                set(SDL_SHARED OFF CACHE BOOL "" FORCE)
                set(SDL_STATIC ON CACHE BOOL "" FORCE)
                set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
            elseif(SUBMOD_NAME STREQUAL "DiligentCore")
                set(DILIGENT_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
                set(DILIGENT_BUILD_UNITY_PLUGIN OFF CACHE BOOL "" FORCE)
                set(DILIGENT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
                set(DILIGENT_TREAT_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)
            endif()
            
            add_subdirectory(${SUBMOD_PATH} EXCLUDE_FROM_ALL)
            
            # Aggressive fix: Remove /WX and /W2 from all DiligentCore SPIRV-Tools targets
            if(SUBMOD_NAME STREQUAL "DiligentCore")
                get_property(ALL_DILIGENT_TARGETS DIRECTORY ${SUBMOD_PATH} PROPERTY BUILDSYSTEM_TARGETS)
                foreach(TGT ${ALL_DILIGENT_TARGETS})
                    if(TARGET ${TGT} AND TGT MATCHES "SPIRV-Tools")
                        # Remove /WX from compile options
                        get_target_property(COMPILE_OPTS ${TGT} COMPILE_OPTIONS)
                        if(COMPILE_OPTS)
                            list(REMOVE_ITEM COMPILE_OPTS /WX /W2)
                            set_target_properties(${TGT} PROPERTIES COMPILE_OPTIONS "${COMPILE_OPTS}")
                        endif()
                        
                        # Add /W0 to suppress all warnings for this target
                        target_compile_options(${TGT} PRIVATE /W0)
                        message(STATUS "   ↳ Patched ${TGT} to remove /WX")
                    endif()
                endforeach()
            endif()
            
            # Now, find the targets to link against
            if(SUBMOD_NAME STREQUAL "DiligentCore")
                # For DiligentCore, automatic detection is unreliable. Use a manual list.
                set(DILIGENT_TARGETS
                    Diligent-GraphicsEngineD3D12-static
                    Diligent-GraphicsEngineVk-static
                    Diligent-GraphicsEngineOpenGL-static
                    Diligent-GraphicsTools
                    Diligent-Common
                )
                message(STATUS "   ↳ Manually adding linkable targets: ${DILIGENT_TARGETS}")
                list(APPEND ALL_SUBMODULE_TARGETS ${DILIGENT_TARGETS})
            else()
                # For all other submodules, use the automatic detection method.
                get_property(SUBMOD_TARGETS DIRECTORY ${SUBMOD_PATH} PROPERTY BUILDSYSTEM_TARGETS)
                if(SUBMOD_TARGETS)
                    filter_linkable_targets("${SUBMOD_TARGETS}" FILTERED_TARGETS)
                    if(FILTERED_TARGETS)
                        message(STATUS "   ↳ Auto-detected linkable targets: ${FILTERED_TARGETS}")
                        list(APPEND ALL_SUBMODULE_TARGETS ${FILTERED_TARGETS})
                    else()
                        message(STATUS "   ↳ No linkable targets found")
                    endif()
                else()
                    message(STATUS "   ↳ No targets detected")
                endif()
            endif()
        endif()
    endforeach()
endif()

# Remove duplicates
if(ALL_SUBMODULE_TARGETS)
    list(REMOVE_DUPLICATES ALL_SUBMODULE_TARGETS)
endif()

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

# Link additional system/external dependencies
target_link_libraries(Hollows_Engine PRIVATE
    SDL3::SDL3
    spdlog::spdlog
    
    # Auto-link Diligent if it was found
    ${DILIGENT_TARGETS}
    
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

# Set compiler options based on the detected compiler
foreach(target Hollows_Engine Assets)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        message(STATUS "Applying MSVC compile options to ${target}")
        target_compile_options(${target} PRIVATE /W4 /permissive- /EHsc)

    elseif (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        message(STATUS "Applying Clang/GCC compile options to ${target}")
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)

    else()
        message(WARNING "Unknown compiler: ${CMAKE_CXX_COMPILER_ID}. No specific compile options set for ${target}.")
    endif()
endforeach()