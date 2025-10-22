# CPM.cmake bootstrap file
# Download CPM.cmake automatically if not present
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/CPM.cmake")
    message(STATUS "Downloading CPM.cmake...")
    file(DOWNLOAD
        "https://github.com/cpm-cpm/cpm.cmake/releases/latest/download/CPM.cmake"
        "${CMAKE_CURRENT_LIST_DIR}/CPM.cmake"
    )
endif()
include("${CMAKE_CURRENT_LIST_DIR}/CPM.cmake")