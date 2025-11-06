#https://github.com/meemknight/cmakeSetup
#Version 1.1.0

cmake_minimum_required(VERSION 3.16)

set(CMAKE_CXX_STANDARD 23)

#! ! ! ! ! ! !
#set this to ON instead of OFF to ship the game!
#basically this will change the RESOURCES_PATH to be the local path
#! ! ! ! ! ! !
set(PRODUCTION_BUILD OFF CACHE BOOL "Make this a production build" FORCE)
#delete the out folder after changing if visual studio doesn recognize the change!

set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Release>:Release>")
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

#may give problems on linux
if(PRODUCTION_BUILD)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE) #link time optimization
else()
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION FALSE)
endif()

if(MSVC) 
add_compile_options(/arch:AVX2) #make sure SIMD optimizations take place
endif()

project(The_Hollows_Engine)

# =========================================================
# Dependencies Configuration
# =========================================================
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)

set(DILIGENT_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
set(DILIGENT_BUILD_UNITY_PLUGIN OFF CACHE BOOL "" FORCE)
set(DILIGENT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(DILIGENT_TREAT_WARNINGS_AS_ERRORS OFF CACHE BOOL "" FORCE)

set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

add_compile_definitions(SPDLOG_USE_STD_FORMAT)

# =========================================================
# Add Dependencies
# =========================================================
add_subdirectory(vendor/lib/SDL)
add_subdirectory(vendor/lib/DiligentCore)
add_subdirectory(vendor/lib/spdlog)

# =========================================================
# Hollows_Engine (Shared Library)
# =========================================================

# ENGINE_SOURCES is defined to be a list of all the source files for the engine
# DON'T ADD THE SOURCES BY HAND, they are already added with this macro
file(GLOB_RECURSE ENGINE_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/*.cpp")

add_library(Hollows_Engine SHARED)

set_property(TARGET Hollows_Engine PROPERTY CXX_STANDARD 23)

target_compile_definitions(Hollows_Engine PUBLIC GLFW_INCLUDE_NONE=1) 

if(PRODUCTION_BUILD)
	# setup the ASSETS_PATH macro to be in the root folder of your exe
	target_compile_definitions(Hollows_Engine PUBLIC RESOURCES_PATH="./resources/") 

	# remove the option to debug asserts.
	target_compile_definitions(Hollows_Engine PUBLIC PRODUCTION_BUILD=1) 
	target_compile_definitions(Hollows_Engine PUBLIC DEVELOPMENT_BUILD=0) 

else()
	# This is useful to get an ASSETS_PATH in your IDE during development
	target_compile_definitions(Hollows_Engine PUBLIC RESOURCES_PATH="${CMAKE_CURRENT_SOURCE_DIR}/resources/")
	target_compile_definitions(Hollows_Engine PUBLIC PRODUCTION_BUILD=0) 
	target_compile_definitions(Hollows_Engine PUBLIC DEVELOPMENT_BUILD=1) 

endif()

target_sources(Hollows_Engine PRIVATE ${ENGINE_SOURCES})

if(MSVC) # If using the VS compiler...

	target_compile_definitions(Hollows_Engine PUBLIC _CRT_SECURE_NO_WARNINGS)

	set_target_properties(Hollows_Engine PROPERTIES LINK_FLAGS "/SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup") #no console
	
endif()

#force remove unicode
if (WIN32)
	target_compile_options(Hollows_Engine PRIVATE /UUNICODE /U_UNICODE)
endif()

target_include_directories(Hollows_Engine PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/")
target_include_directories(Hollows_Engine PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/")

target_link_libraries(Hollows_Engine PRIVATE 
    SDL3::SDL3
    spdlog::spdlog
    Diligent-GraphicsEngineD3D12-static
    Diligent-GraphicsEngineVk-static
    Diligent-GraphicsEngineOpenGL-static
    Diligent-GraphicsTools
    Diligent-Common
)

# =========================================================
# Assets (Executable)
# =========================================================

# ASSET_SOURCES is defined to be a list of all the source files for assets
file(GLOB_RECURSE ASSET_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/assets/*.cpp")

add_executable(Assets)

set_property(TARGET Assets PROPERTY CXX_STANDARD 23)

target_compile_definitions(Assets PUBLIC GLFW_INCLUDE_NONE=1) 

if(PRODUCTION_BUILD)
	target_compile_definitions(Assets PUBLIC RESOURCES_PATH="./resources/") 
	target_compile_definitions(Assets PUBLIC PRODUCTION_BUILD=1) 
	target_compile_definitions(Assets PUBLIC DEVELOPMENT_BUILD=0) 

else()
	target_compile_definitions(Assets PUBLIC RESOURCES_PATH="${CMAKE_CURRENT_SOURCE_DIR}/resources/")
	target_compile_definitions(Assets PUBLIC PRODUCTION_BUILD=0) 
	target_compile_definitions(Assets PUBLIC DEVELOPMENT_BUILD=1) 

endif()

target_sources(Assets PRIVATE ${ASSET_SOURCES})

if(MSVC)
	target_compile_definitions(Assets PUBLIC _CRT_SECURE_NO_WARNINGS)
	set_target_properties(Assets PROPERTIES LINK_FLAGS "/SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup")
endif()

if (WIN32)
	target_compile_options(Assets PRIVATE /UUNICODE /U_UNICODE)
endif()

target_include_directories(Assets PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/")

target_link_libraries(Assets PRIVATE Hollows_Engine spdlog::spdlog)