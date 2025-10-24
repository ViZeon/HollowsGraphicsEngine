--require("conandeps")


--[[newoption {
    trigger = "conan-profile",
    value = "PROFILE",
    description = "Conan profile to use"
}

local profile = _OPTIONS["conan-profile"] or "default"
os.execute("conan install . --profile=" .. profile .. " --build=missing")
]]
workspace "The_Hollows_Engine"
    architecture "x64"

    configurations
    {
        "Debug",
        "Release",
        "Dist"
    }
    
    include "vendor/lib/SDL"

outputdir = "%{cfg.buildcfg}-%{cfg.system}-%{cfg.architecture}"

project "Hollows_Engine"
    location "src/engine"
    kind "SharedLib"
    language "C++"

    targetdir ("bin/" .. outputdir .. "/%{prj.name}")
    objdir ("bin-int/" .. outputdir .. "/%{prj.name}")
    
    -- Add this line to specify import library location
    implibdir ("bin/" .. outputdir .. "/%{prj.name}")

    files
    {
        "src/engine/**.h",
        "src/engine/**.cpp",
        "src/engine/**.c"
    }

    filter "system:windows"
        cppdialect "C++23"
        staticruntime "On"
        systemversion "latest"

        defines
        {
            "HZ_PLATFORM_WINDOWS",
            "HZ_BUILD_DLL",
            "SDL_STATIC_LIB"
        }
        
        links { "SDL3-static", "winmm", "imm32", "version", "setupapi" }
        includedirs { "vendor/lib/SDL/include" }
        libdirs { "vendor/lib/SDL/build/%{cfg.buildcfg}" }

        postbuildcommands
        {
            ("{MKDIR} ../../bin/" .. outputdir .. "/Assets"),
            ("{COPY} %{cfg.buildtarget.relpath} ../../bin/" .. outputdir .. "/Assets")
        }

    filter "configurations:Debug"
        defines "HZ_DEBUG"
        symbols "On"

    filter "configurations:Release"
        defines "HZ_RELEASE"
        optimize "On"

    filter "configurations:Dist"
        defines "HZ_DIST"
        optimize "On"


project "Assets"
    location "src/assets"
    kind "ConsoleApp"
    language "C++"

    targetdir ("bin/" .. outputdir .. "/%{prj.name}")
    objdir ("bin-int/" .. outputdir .. "/%{prj.name}")

    dependson { "Hollows_Engine" } -- ensures engine builds first

    files {
        "src/assets/**.h",
        "src/assets/**.cpp",
        "src/assets/**.c"
    }

    includedirs {
        "src/engine" -- includes test.h etc.
    }

    links {
        "Hollows_Engine"
    }

    filter "system:windows"
        cppdialect "C++23"
        staticruntime "On"
        systemversion "latest"
        defines {
            "HZ_PLATFORM_WINDOWS" -- ❌ do NOT define HZ_BUILD_DLL here
        }

    filter "configurations:Debug"
        defines "HZ_DEBUG"
        symbols "On"

    filter "configurations:Release"
        defines "HZ_RELEASE"
        optimize "On"

    filter "configurations:Dist"
        defines "HZ_DIST"
        optimize "On"