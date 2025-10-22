add_executable(SandboxApp main.cpp)

# Link to engine and graphics module
if(TARGET engine)
    target_link_libraries(SandboxApp PRIVATE engine)
endif()
if(TARGET graphics)
    target_link_libraries(SandboxApp PRIVATE graphics)
endif()

target_include_directories(SandboxApp PRIVATE 
    ${CMAKE_SOURCE_DIR}/engine/include
    ${CMAKE_SOURCE_DIR}/modules/graphics/include
)
