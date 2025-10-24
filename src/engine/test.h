#pragma once

#ifdef HZ_PLATFORM_WINDOWS
    #ifdef HZ_BUILD_DLL
        #define HOLLOWS_API __declspec(dllexport)
    #else
        #define HOLLOWS_API __declspec(dllimport)
    #endif
#else
    #define HOLLOWS_API
#endif

namespace Hollows {
    HOLLOWS_API void Print();
}
