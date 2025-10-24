--require("conandeps")


newoption {
    trigger = "conan-profile",
    value = "PROFILE",
    description = "Conan profile to use"
}

local profile = _OPTIONS["conan-profile"] or "default"
os.execute("conan install . --profile=" .. profile .. " --build=missing")

workspace "The_Hollows_Engine"
    architecture "x64"

    include "vendor/SDL"
    configurations
    {
        "Debug",
        "Release",
        "Dist"
    }

outputdir = "%{cfg.buildcfg}-%{cfg.system}-%{cfg.architecture}"

project "Hollows_Engine"
    location "src/engine"
    kind "SharedLib"
    language "C++"

    targetdir ("bin/" .. outputdir .. "/%{prj.name}")
    objdir ("bin-int/" .. outputdir .. "/%{prj.name}")

    files
    {
        "src/engine/**.h",
        "src/engine/**.cpp",
        "src/engine/**.c"
    }

    conan_basic_setup()

    filter "system:windows"
        cppdialect "C++17"
        staticruntime "On"
        systemversion "latest"

        defines
        {
            "Z",
            "HZ_BUILD_DLL"
        }

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

    files
    {
        "src/assets/**.h",
        "src/assets/**.cpp",
        "src/assets/**.c"
    }

    conan_basic_setup()

    includedirs
    {
        "src/engine"
    }

    links
    {
        "Hollows_Engine"
    }

    filter "system:windows"
        cppdialect "C++17"
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