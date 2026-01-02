# The Hollows Engine [Highly Experimental]
A different take on 3D Game Engines, pushing the "Next Gen" of engine design while learning from the existing systems.

### Currently in progress:

- Indexed Spatial Rendering (render pixels directly from a pre-sorted vertex list, sorted by coordinates in world space, no rasterization)

### Initial Roadmap:

- LiCap Framework (see below)
- Indexed Spatial calculations (alternative to RT, to calculate reflections and light bounces, based on the sorted list)
- Live Deferred Editing (a framework for utilizing external apps like Blender and Cascadeur right inside the engine, maps a basic visual interface when needed [Cas's control points] and forwards all the keyboard shortcuts to the relevant software, retrieves the output and applies)
- Curve-Based Neuro Motion (An animation system that makes the body follow a line of action set by the animator, while accounting for body physics and neurological response, is supposed to utilize Cas's auto posing to map the body to its curves)

#### Design Philosophy:
Simple, Powerful, Modular, Optimized

## Build instructions:
This project is written in Odin (Modern C language), currently has build scripts for *Windows* only, but the code itself is cross platform, feel free to contribute a Linux build script

- Grab Odin from the official site (make sure it's in PATH):
https://odin-lang.org/

- Run build_windows.bat
- The exe will be in out/Windows_Speed/HollowsEngine.exe

  

This is the implementation project for the HotWireNine (LiCap FrameWork] Prototype here: https://github.com/ViZeon/licap-framework



Videos and live development [on stream] will be available on this channel: https://www.youtube.com/@ComplexAce/featured
