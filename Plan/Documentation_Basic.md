
# Hollows Graphics Engine

## Overview
Experimental software renderer built in Odin. CPU-based fragment shader pipeline with a hierarchical spatial structure (octree via bitfield) for model rendering. Raylib used as display layer only — not the final renderer.

---

## Architecture

### Core Rules
- Data and logic never in the same file or module
- All procs are stateless — no hidden state, everything passed explicitly
- No pointer reliance — everything communicates via `i32` index refs
- One flat array per type in `data_editor.odin`, everything indexes into it
- Hot reload aware — no proc-local statics, no closures

### Packages
| Package | Role |
|---|---|
| `data` | Types and live storage only. No logic. |
| `core/modules/model` | Raw glTF loading → `[]Vertex` |
| `core/modules/render` | OpenGL compute pipeline (dormant) |
| `core/modules/window` | GLFW window init |
| `core/testing` | Active development sandbox. Wiring, rendering logic, spatial ops. |

---

## Base Types (`data` package)

### `Ref`
```
index:      i32
generation: u32
```
Universal handle. Points into a flat array. `REF_INVALID = {-1, 0}`.

### `DataPoint`
```
pos:    vec3
normal: vec3
type:   DataPointType  // which array the ref points into
ref:    Ref
```
Base primitive. Always this shape, never extended.

### `Field`
```
bits:   [dynamic]u32        // occupancy bitfield
refs:   [dynamic][dynamic]i32  // vertex index refs per cell
bounds: Bounds              // local to owner
levels: int                 // octree depth
```
Hierarchical spatial structure. Local to its owner (model, world node, etc).

---

## File Conventions
| Prefix | Meaning |
|---|---|
| `type_` | Type definition only |
| `live_` / `data_editor` | Runtime flat arrays |
| `_v1`, `_v2` | Versioned replacement of existing file |
| no prefix | Logic, named by operation |

---

## Active Pipeline
```
load_model(path)
  → []Vertex (raw, no scale)

load_model_v1(path)  [testing]
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
- `Vertex` type kept as cgltf intermediary, will be replaced
- Screen resolution hardcoded in `data` (TEMPORARY)
- Generation tracking on flat arrays not yet implemented
- OpenGL compute pipeline dormant
