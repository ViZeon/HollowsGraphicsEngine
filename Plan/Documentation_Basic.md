# Hollows Graphics Engine

## Overview
Experimental CPU-based software renderer in Odin. Raylib is the temporary display layer only — not the final renderer. All rendering logic is CPU-driven via a fragment shader pipeline backed by a hierarchical spatial structure.

---

## Architecture

### Core Rules
- Data and logic never in the same file or module
- All procs are stateless — everything passed explicitly, no hidden state
- No pointer reliance — everything communicates via `i32` index refs
- One flat array per type in `data_editor.odin`, everything indexes into it
- Hot reload aware — no proc-level statics except where explicitly marked
- No package-level variables outside `data` package

### Packages
| Package | Role |
|---|---|
| `_data` | Types and live storage only. No logic. |
| `core/modules/model` | Raw glTF loading → `[]Vertex` |
| `core/modules/render` | OpenGL compute pipeline (dormant) |
| `core/modules/window` | GLFW window init |
| `core/testing` | Active sandbox — wiring, spatial ops, render logic |

---

## Base Types (`_data` package)

### `Ref`
```
index:      i32
generation: u32
```
Universal handle. Points into a flat array. `REF_INVALID = {-1, 0}`. Generation tracking not yet active.

### `DataPoint`
```
pos:    vec3
normal: vec3
type:   DataPointType  // which array the ref points into
ref:    Ref
```
Base primitive. Fixed shape, never extended. Custom data lives in external arrays indexed by `ref`.

### `Field`
```
bits:   [dynamic]u32            // occupancy bitfield
refs:   [dynamic][dynamic]i32   // datapoint index refs per finest-level cell
bounds: Bounds                  // local to owner, scale agnostic
levels: int                     // octree depth
```
Hierarchical spatial structure. Always local to its owner. Normalized to owner bounds — scale agnostic.

---

## File Conventions
| Prefix | Meaning |
|---|---|
| `type_` | Type definition only |
| `data_editor.odin` | Runtime flat arrays |
| `_v1`, `_v2` | Versioned replacement of existing file |
| `render_raylib` | Raylib-specific, temporary |
| no prefix | Logic, named by operation |

---

## Active Pipeline
```
load_model(path)
  → []Vertex (raw, no scale)

load_model(path)  [testing]
  → datapoints, bounds, center
  → field_create(bounds, levels)
  → field_populate(field, datapoints)

cpu_fragment_shader(pixel)
  → pixel_to_world_fov()
  → field_query(field, x, y)
  → red if hit, black if miss
```

---

## Known Limitations / TODO
- Multi-mesh loading not implemented (loads mesh[0] only)
- `SCALE_FACTOR` still in data, model handling system TBD
- `Vertex` type kept as cgltf intermediary, will be replaced by `DataPoint`
- Screen resolution hardcoded in `data` (TEMPORARY)
- Generation tracking on flat arrays not yet implemented
- OpenGL compute pipeline dormant
- Raylib layer (`render_raylib.odin`) fully temporary

---

## Open Design Questions
- **World Field** — world-level `Field` of models, each model a `DataPoint`. Query descends world → model → vertex.
- **Nesting** — `Field` containing `Field`s at arbitrary depth. May need early implementation to support world structure.
- **Prepass** — purpose and structure TBD. Candidates: depth prepass, visibility prepass, or combined world traversal before per-pixel shading.
- **Render pipeline** — what replaces raylib. CPU buffer → custom window layer, or GPU compute path.