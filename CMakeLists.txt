#https://github.com/meemknight/cmakeSetup
#Version 1.1.0

cmake_minimum_required(VERSION 3.16)

set(ENGINE_TARGET "Hollows_Engine")
set(CLIENT_TARGET "Assets")


set(CMAKE_CXX_STANDARD 20)
SET(CMAKE_EXPORT_COMPILE_COMMANDS ON)
#-DCMAKE_GENERATOR_PLATFORM=x64

#add_compile_options("$<$<CONFIG:Debug>:/ZI>")


# Where to put executables
set(OUTPUT_BIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/out/bin")
# Where to put libraries
set(OUTPUT_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/out/lib")

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
add_compile_definitions(UNICODE _UNICODE)

endif()

project(The_Hollows_Engine)

# =========================================================
# Dependencies Configuration
# =========================================================

set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(GLFW_INSTALL OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

add_compile_definitions(SPDLOG_USE_STD_FORMAT)

# =========================================================
# Add Dependencies
# =========================================================
add_subdirectory(vendor/lib/spdlog)

add_subdirectory(vendor/lib/glfw-3.4)			#window oppener
add_subdirectory(vendor/lib/glad)				#opengl loader
#add_subdirectory(vendor/lib/enet-1.3.17)		#networking
add_subdirectory(vendor/lib/glm)				#math
#add_subdirectory(vendor/lib/gl2d)				#rendering
#add_subdirectory(vendor/lib/efsw)
add_subdirectory(vendor/lib/hotreload)
add_subdirectory(vendor/bin/blink)


# =========================================================
# Hollows_Engine (Shared Library)
# =========================================================

# ENGINE_SOURCES is defined to be a list of all the source files for the engine
# DON'T ADD THE SOURCES BY HAND, they are already added with this macro
file(GLOB_RECURSE ENGINE_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/*.cpp")

add_library(${ENGINE_TARGET} SHARED)

set_property(TARGET ${ENGINE_TARGET} PROPERTY CXX_STANDARD 20)

target_compile_definitions(${ENGINE_TARGET} PRIVATE HZ_BUILD_DLL) 
target_compile_definitions(${ENGINE_TARGET} PUBLIC GLFW_INCLUDE_NONE=1)

if(PRODUCTION_BUILD)
	# setup the ASSETS_PATH macro to be in the root folder of your exe
	target_compile_definitions(${ENGINE_TARGET} PUBLIC RESOURCES_PATH="./resources/") 

	# remove the option to debug asserts.
	target_compile_definitions(${ENGINE_TARGET} PUBLIC PRODUCTION_BUILD=1) 
	target_compile_definitions(${ENGINE_TARGET} PUBLIC DEVELOPMENT_BUILD=0) 

else()
	# This is useful to get an ASSETS_PATH in your IDE during development
	target_compile_definitions(${ENGINE_TARGET} PUBLIC RESOURCES_PATH="${CMAKE_CURRENT_SOURCE_DIR}/resources/")
	target_compile_definitions(${ENGINE_TARGET} PUBLIC PRODUCTION_BUILD=0) 
	target_compile_definitions(${ENGINE_TARGET} PUBLIC DEVELOPMENT_BUILD=1) 

endif()

target_sources(${ENGINE_TARGET} PRIVATE ${ENGINE_SOURCES})

#if(MSVC) # If using the VS compiler...

#	target_compile_definitions("${CMAKE_PROJECT_NAME}" PUBLIC _CRT_SECURE_NO_WARNINGS)

#	set_target_properties("${CMAKE_PROJECT_NAME}" PROPERTIES LINK_FLAGS "/SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup") #no console
	
#endif()

#force remove unicode
if (WIN32)
#	target_compile_options("${CMAKE_PROJECT_NAME}" PRIVATE /UUNICODE /U_UNICODE)
endif()

target_include_directories(${ENGINE_TARGET} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/")
target_include_directories(${ENGINE_TARGET} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/")

target_link_libraries(${ENGINE_TARGET} PUBLIC 
	glm glfw 
	glad
    spdlog::spdlog
	hotreload::session
)
# For the engine DLL
set_target_properties(${ENGINE_TARGET} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_BIN_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${OUTPUT_BIN_DIR}/Debug"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${OUTPUT_BIN_DIR}/Release"
    LIBRARY_OUTPUT_DIRECTORY "${OUTPUT_LIB_DIR}"
    ARCHIVE_OUTPUT_DIRECTORY "${OUTPUT_LIB_DIR}"
)


# =========================================================
# Assets (Executable)
# =========================================================

project(Client)

# ASSET_SOURCES is defined to be a list of all the source files for assets
file(GLOB_RECURSE ASSET_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/client/*.cpp")
message("ASSET_SOURCES = ${ASSET_SOURCES}")

add_executable(${CLIENT_TARGET} ${ASSET_SOURCES})

set_property(TARGET ${CLIENT_TARGET} PROPERTY CXX_STANDARD 20)

target_compile_definitions(${CLIENT_TARGET} PUBLIC GLFW_INCLUDE_NONE=1) 

if(PRODUCTION_BUILD)
	target_compile_definitions(${CLIENT_TARGET} PUBLIC RESOURCES_PATH="./resources/") 
	target_compile_definitions(${CLIENT_TARGET} PUBLIC PRODUCTION_BUILD=1) 
	target_compile_definitions(${CLIENT_TARGET} PUBLIC DEVELOPMENT_BUILD=0) 

else()
	target_compile_definitions(${CLIENT_TARGET} PUBLIC RESOURCES_PATH="${CMAKE_CURRENT_SOURCE_DIR}/resources/")
	target_compile_definitions(${CLIENT_TARGET} PUBLIC PRODUCTION_BUILD=0) 
	target_compile_definitions(${CLIENT_TARGET} PUBLIC DEVELOPMENT_BUILD=1) 

endif()

target_sources(${CLIENT_TARGET} PRIVATE ${ASSET_SOURCES})

if(MSVC)
	target_compile_definitions(${CLIENT_TARGET} PUBLIC _CRT_SECURE_NO_WARNINGS)
	set_target_properties(${CLIENT_TARGET} PROPERTIES LINK_FLAGS "/SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup")
endif()

if (WIN32)
#	target_compile_options("${CMAKE_PROJECT_NAME}" PRIVATE /UUNICODE /U_UNICODE)
    # Add the resource file for the .exe icon
    set(ICON_RC "${CMAKE_CURRENT_SOURCE_DIR}/resources/icon.rc")
    target_sources(${CLIENT_TARGET} PRIVATE ${ICON_RC})
endif()

target_include_directories(${CLIENT_TARGET} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/")
target_include_directories(${CLIENT_TARGET} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src/engine/")

target_link_libraries(${CLIENT_TARGET} PRIVATE Hollows_Engine spdlog::spdlog)

# For the Assets exe
set_target_properties(${CLIENT_TARGET} PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_BIN_DIR}"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${OUTPUT_BIN_DIR}/Debug"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${OUTPUT_BIN_DIR}/Release"
)

add_custom_command(TARGET ${ENGINE_TARGET} PRE_BUILD
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_BINARY_DIR}/.hotreload_cache
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/.hotreload_cache
)