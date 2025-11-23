#pragma once

#include <HotReload.hpp>
#include <engine\LocalIncludes.h>;

#include <iostream>
#include <glad/glad.h>
#include <GL/gl.h>
#include <GLFW/glfw3.h>

//#include <diligentcore/graphics/GraphicsEngine/interface/engineFactoryVk.h>
//#include <diligentcore/graphics/GraphicsEngine/interface/engineFactoryOpenGL.h>

//#ifdef HZ_PLATFORM_WINDOWS
    #ifdef HZ_BUILD_DLL
        #define HOLLOWS_API __declspec(dllexport)
    #else
        #define HOLLOWS_API __declspec(dllimport)
    #endif
//#else
//    #error The Hollows Engine is currently limited to Windows
//    #define HOLLOWS_API
//#endif

namespace Hollows {
    HOLLOWS_API void Print();
}
