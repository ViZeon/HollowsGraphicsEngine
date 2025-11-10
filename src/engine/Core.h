#pragma once

#include <SDL3/SDL.h>
#include <SDL3/SDL_properties.h>


#include <EngineFactory.h>
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
