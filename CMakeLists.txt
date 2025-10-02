cmake_minimum_required(VERSION 3.20)
project(HollowsGraphicsEngine LANGUAGES CXX)

set(BUILD_SHARED_LIBS ON CACHE BOOL "Build shared libraries by default")

# Attempt to prefer clang++ on PATH when available
find_program(CLANGPP clang++)
if(CLANGPP)
    set(CMAKE_CXX_COMPILER ${CLANGPP} CACHE FILEPATH "C++ compiler" FORCE)
    message(STATUS "Using Clang++: ${CLANGPP}")
endif()

# CPM bootstrap (optional - kept minimal)
if(EXISTS "${CMAKE_SOURCE_DIR}/vendor/CPM/CPM.cmake")
    include(${CMAKE_SOURCE_DIR}/vendor/CPM/CPM.cmake)
endif()

# Add any engine/modules if present
if(EXISTS "${CMAKE_SOURCE_DIR}/engine/CMakeLists.txt")
    add_subdirectory(engine)
endif()
if(EXISTS "${CMAKE_SOURCE_DIR}/modules")
    file(GLOB children RELATIVE ${CMAKE_SOURCE_DIR}/modules ${CMAKE_SOURCE_DIR}/modules/*)
    foreach(child ${children})
        if(IS_DIRECTORY "${CMAKE_SOURCE_DIR}/modules/${child}" AND EXISTS "${CMAKE_SOURCE_DIR}/modules/${child}/CMakeLists.txt")
            add_subdirectory("modules/${child}")
        endif()
    endforeach()
endif()

# Doxygen integration: create a 'doc' target that generates documentation if doxygen is found
find_package(Doxygen QUIET)
if(DOXYGEN_FOUND)
    set(DOXYGEN_IN ${CMAKE_CURRENT_SOURCE_DIR}/doc/Doxyfile.in)
    set(DOXYGEN_OUT ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile)
    if(EXISTS ${DOXYGEN_IN})
        configure_file(${DOXYGEN_IN} ${DOXYGEN_OUT} @ONLY)
        add_custom_target(doc
            COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYGEN_OUT}
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            COMMENT "Generating API documentation with Doxygen"
            VERBATIM
        )
    else()
        message(STATUS "Doxyfile.in not found; doc target not created")
    endif()
else()
    message(STATUS "Doxygen not found. Install Doxygen to enable the 'doc' target.")
endif()

# Add Sandbox app as a separate executable
if(EXISTS "${CMAKE_SOURCE_DIR}/Sandbox/CMakeLists.txt")
    add_subdirectory(Sandbox)
endif()
