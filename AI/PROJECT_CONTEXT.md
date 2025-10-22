# HollowsGraphicsEngine AI Context

## Design Philosophy
- Modular, Hazel/Cherno-inspired architecture
- Core engine and feature modules (graphics, audio, etc.)
- Public headers in `include/`, source in `src/`
- Prefer dynamic/shared libraries, allow static if needed
- Minimal, readable CMake files; use target properties, avoid global variables
- CPM.cmake for dependency management
- Cross-platform: Windows, Linux, macOS; auto-detect compilers
- "Clone and run" setup: no manual config edits, one-click build

## Project Structure
- `engine/` — core engine
- `modules/` — feature modules (e.g., graphics)
- `vendor/` — dependency manager (CPM)
- `doc/` — Doxygen config and docs
- `AI/` — instructions, decisions, and context for AI assistant
- `README.md` — quickstart and build instructions

## Build Workflow
- Top-level `CMakeLists.txt` auto-discovers modules and engine
- CPM fetches dependencies automatically
- Doxygen integration for documentation
- No manual config edits required
- Universal build command for all platforms
- Optional: VS Code task for one-click build

## Documentation
- Doxygen + Graphviz for code documentation and diagrams
- `cmake --build . --target doc` generates docs if Doxygen is installed

## Decision Log
- Workspace must remain uncluttered and minimal
- All instructions and decisions are stored in `AI/` for reference
- Any new requirement or change will be added here for clarity

---
This file is the single source of truth for project requirements and decisions. Update as needed with new instructions or changes.