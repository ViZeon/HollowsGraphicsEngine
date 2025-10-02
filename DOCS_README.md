Doxygen documentation
=====================

How to generate documentation for this project:

1. Install Doxygen (and Graphviz for class/call graphs).
2. Create a build directory and run CMake:

```powershell
mkdir build; cd build
cmake .. -G "NMake Makefiles"  # or your generator of choice
cmake --build . --target doc
```

3. Generated HTML will appear under `build/docs` (or the `OUTPUT_DIRECTORY` specified in `doc/Doxyfile.in`).

If Doxygen is not found when configuring, the `doc` target won't be created. Install Doxygen and re-run CMake.
