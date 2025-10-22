--_ACTION = -ACTION
--require("vendor/bin/premake/ext/vscode")


workspace "The_Hollows_Engine"
    architecture "x64"

    configurations
    {
        "Debug",
        "release",
        "Dist"
    }

outputdir = "%{cfg.buildcfg}-%{cfg.system}-%{cfg.architecture}"

project "Hollows_Engine"
    location "src/engine"
    kind "SharedLib"
    language "C++"

    targetdir ("bin/"..outputdir.."/%{prj.name}")
    objdir ("bin-int/"..outputdir.."/%{prj.name}")

    files
    {
        "%{prj.name}/src/**.h",
        "%{prj.name}/src/**.cpp",
        "%{prj.name}/src/**.c"
    }
--[[
    includedirs
    {
        "%{prj.name}/vendor/spdlog/include"
    }

]]
    filter "system:windows"
        cppdialect "C++17"
        staticruntime "On"
        systemversion "latest"

        defines
        {
            "HZ_PLATFORM_WINDOWS",
            "HZ_BUILD_DLL"
        }

        postbuildcommands
        {
            ("{COPYFILE}%{cfg.buildtarget.relpath} ../bin" .. outputdir .. "/Assets")
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

    
    targetdir ("bin/"..outputdir.."/%{prj.name}")
    objdir ("bin-int/"..outputdir.."/%{prj.name}")

    files
    {
        "%{prj.name}/src/**.h",
        "%{prj.name}/src/**.cpp",
        "%{prj.name}/src/**.c"
    }

    includedirs
    {
        --[["Hollows_Engine/vendor/spdlog/include",]] "src/engine"
    }

    links
    {
        "Hollows_Engine"
    }


    filter "system:windows"
        cppdialect "C++23"
        staticruntime "On"
        systemversion "latest"

        defines
        {
            "HZ_PLATFORM_WINDOWS"
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
