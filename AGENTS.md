# AGENTS.md — Tetris Roguelike Project Guide

This file is for AI agents assisting with this project. Read it fully before answering any questions or suggesting any code.

---

## Project Identity

- **Name:** Tetris Roguelike
- **Engine:** Godot 4.6 (GDScript only, no C#)
- **Goal:** A mobile-first Tetris game with roguelike progression (rounds, buffs, events)
- **Developer:** First-time Godot user — explanations should be clear and educational, not just functional
- **Current Phase:** Phase 2 — HUD & UI Polish (Phase 1 complete)

See `docs/plan.md` for the full design document.

---

## Your Role

You are a **patient technical guide and pair programmer**, not a code generator. Your job is to:

1. **Explain concepts** before asking the developer to implement them
2. **Give tasks**, not complete solutions — the developer writes the code
3. **Review code** the developer shares and give specific, actionable feedback
4. **Catch bugs** and explain why they occur, not just how to fix them
5. **Answer questions** about Godot, GDScript, and game architecture

Do not write complete implementations unless explicitly asked. Prefer showing structure/signatures and letting the developer fill in the body.

---

## Architecture Rules (NEVER violate these)

These are hard constraints. Do not suggest code that breaks them.

1. **Layering rule:** Higher layers call down; lower layers never reference higher layers.
   - `TetrisEngine` must never import or call Roguelike, Rendering, or UI code
   - `TetrisGrid` must never reference `TetrisEngine`
   - Renderers listen to signals — they never push state into the engine

2. **Signal direction:** Signals flow upward only. Engine emits → renderer/manager listens.

3. **Never modify the engine for roguelike features.** All roguelike effects must go through hook signals (`on_board_modified`, `lines_cleared`, etc.) or by modifying engine configuration properties from outside.

4. **No enums for extensible types.** Piece types use `String id`. Buff rarities may use enums (closed set). Any system that buffs need to extend must use strings or resource registries.

5. **PieceLibrary is the single source of truth** for all piece definitions. Never hardcode piece lookups anywhere else.

---

## Godot 4.6 Patterns Used in This Project

### Class system
- `class_name Foo` at top of file = globally available, no import needed
- `extends RefCounted` = pure logic class, no scene tree (engine, grid, instance)
- `extends Node` = autoload singletons (GameState, PieceLibrary)
- `extends Node2D` = game world rendering (GridRenderer)
- `extends CanvasLayer` = UI that renders over everything (HUD)
- `extends Resource` = data objects (Tetromino, Buff, Event)

### Autoloads (global singletons)
Registered in Project → Project Settings → Autoload:
- `GameState` → `scripts/utils/game_state.gd`
- `PieceLibrary` → `scripts/core/piece_library.gd`

Access anywhere as `GameState.score`, `PieceLibrary.get_piece("I")`, etc.

### Node references
```gdscript
@onready var label: Label = $VBoxContainer/ScoreLabel  # scene-tree child
```
`$Name` is shorthand for `get_node("Name")`. `@onready` assigns after `_ready()` runs.

### Signals
```gdscript
# Define
signal piece_locked(instance: TetrominoInstance)

# Emit
emit_signal("piece_locked", active_piece)
# or: piece_locked.emit(active_piece)

# Connect
engine.piece_locked.connect(_on_piece_locked)
```

### Typed arrays (important GDScript 4 gotcha)
```gdscript
# WRONG — untyped Array, won't assign to Array[Tetromino]
var pieces = some_dict.values()

# RIGHT — must iterate and append
var pieces: Array[Tetromino] = []
for p in some_dict.values():
    pieces.append(p)

# WRONG — literal array not inferred as typed
piece.rotations = [PackedInt32Array([...]), ...]

# RIGHT — declare type explicitly first
var rots: Array[PackedInt32Array] = [PackedInt32Array([...]), ...]
piece.rotations = rots
```

### Drawing in Node2D
```gdscript
func _draw() -> void:
    draw_rect(Rect2(0, 0, width, height), Color(0.1, 0.1, 0.18))
```
Do NOT use `ColorRect` inside `Node2D` trees — it's a Control node and uses a different coordinate system.

### Sprite2D for spritesheet tiles
```gdscript
region_enabled = true
centered = false  # top-left origin, matches grid coords
region_rect = Rect2(col * TILE_SIZE, row * TILE_SIZE, TILE_SIZE, TILE_SIZE)
```

---

## File & Class Reference

| File | Class | Type | Purpose |
|---|---|---|---|
| `scripts/core/tetris_grid.gd` | `TetrisGrid` | RefCounted | Grid data structure, cell operations |
| `scripts/core/tetris_engine.gd` | `TetrisEngine` | RefCounted | Pure Tetris simulation |
| `scripts/core/tetromino.gd` | `Tetromino` | Resource | Piece template (shape, color, rotations) |
| `scripts/core/tetromino_instance.gd` | `TetrominoInstance` | RefCounted | Live falling piece (position, rotation) |
| `scripts/core/piece_library.gd` | — | Autoload Node | Piece registry, default 7 pieces |
| `scripts/rendering/grid_renderer.gd` | `GridRenderer` | Node2D | Visual grid, piece cells, ghost cells |
| `scripts/rendering/cell.gd` | `Cell` | Sprite2D | Single block tile from spritesheet |
| `scripts/rendering/hud.gd` | `HUD` | CanvasLayer | Score/level/lines display |
| `scripts/utils/game_state.gd` | — | Autoload Node | Global run state (score, round, etc.) |
| `scripts/game.gd` | — | Node | Root scene controller |

---

## TetrisGrid API

```gdscript
# Constants
TetrisGrid.EMPTY      # 0
TetrisGrid.GHOST      # -1
TetrisGrid.FROZEN     # -2
TetrisGrid.CRUMBLING  # -3
# 1..N = color_index of locked piece

# Constructor
TetrisGrid.new(width: int, height: int)

# Cell access
get_cell(col, row) -> int       # returns 0 if out of bounds
set_cell(col, row, value: int)  # silently ignores out of bounds

# Row operations
is_row_full(row) -> bool
clear_row(row)
shift_rows_down(cleared_rows: Array[int])  # two-pointer, bottom-up

# Utility
reset()                              # zero all cells
resize_grid(new_w, new_h)           # preserves data, bottom-left aligned
```

---

## TetrisEngine API

```gdscript
# Constructor
TetrisEngine.new(grid_width: int = 10, grid_height: int = 20)

# Lifecycle
start()               # resets everything, spawns first piece
tick(delta: float)    # call every _process frame

# Actions (call from input handler)
move(dir: int) -> bool    # -1 = left, 1 = right
rotate(dir: int) -> bool  # -1 = CCW, 1 = CW
hard_drop()
soft_drop()
hold()

# State (read-only from outside)
grid: TetrisGrid
active_piece: TetrominoInstance
ghost_piece: TetrominoInstance
held_piece: Tetromino
next_pieces: Array[Tetromino]
score: int
level: int
lines_cleared_total: int
game_over_state: bool
is_paused: bool

# Gravity (configurable for buffs)
var gravity_multiplier: float  # set property, emits gravity_changed on change
var base_gravity_multiplier: float # starting value, default 1.0

# Signals emitted (in order on piece lock):
# piece_locked → lines_cleared → piece_spawned
# Other signals: piece_moved, piece_rotated, piece_held,
#                score_changed, level_changed, gravity_changed, game_over

# Tick phases (call order in tick()):
# 1. _update_ground_state() — check if piece can fall further
# 2. Lock delay if on ground — _lock_timer accumulates
```

---

## Tetromino & Instance API

```gdscript
# Tetromino (template)
tetromino.id: String
tetromino.color_index: int          # 1-based spritesheet row
tetromino.grid_size: int            # 4 for standard pieces
tetromino.rotations: Array[PackedInt32Array]

# TetrominoInstance (live)
instance.tetromino: Tetromino
instance.col: int
instance.row: int                   # negative = above grid (valid spawn zone)
instance.rotation: int              # 0-3
instance.get_cells() -> Array[Vector2i]  # world-space filled positions
instance.get_current_rotation() -> PackedInt32Array
```

---

## Rendering Architecture

```
game.tscn (Node)
├── GridRenderer (Node2D)  ← positioned at Vector2(40, 44)
│   ├── [background via _draw()]
│   ├── 200 Cell nodes (grid)
│   ├── 4 Cell nodes (ghost, modulate.a = 0.35)
│   └── 4 Cell nodes (active piece)
└── HUD (CanvasLayer)
	└── VBoxContainer
		├── ScoreLabel
		├── LevelLabel
		└── LinesLabel
```

**CELL_SIZE = 40** (8px tile × scale 5)
**Spritesheet:** 32×80px, 4 columns × 10 rows, 8×8px tiles

GridRenderer signal → handler mapping:
```
piece_spawned  → _on_piece_spawned(instance)   → _on_piece_updated
piece_moved    → _on_piece_updated(instance)
piece_rotated  → _on_piece_updated(instance)
piece_locked   → _on_piece_locked()            → hide cells, _refresh_grid()
lines_cleared  → _on_lines_cleared(lines)      → _refresh_grid()
game_over      → _on_game_over()
```

---

## Current game.gd

```gdscript
extends Node

var engine: TetrisEngine
@onready var renderer: GridRenderer = $GridRenderer
@onready var hud: HUD = $HUD

func _ready() -> void:
	engine = TetrisEngine.new()
	renderer.setup(engine)
	hud.setup(engine)
	engine.start()

func _process(delta: float) -> void:
	engine.tick(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):  engine.move(-1)
	if event.is_action_pressed("move_right"): engine.move(1)
	if event.is_action_pressed("rotate_cw"):  engine.rotate(1)
	if event.is_action_pressed("soft_drop"):  engine.soft_drop()
	if event.is_action_pressed("hard_drop"):  engine.hard_drop()
	if event.is_action_pressed("hold"):       engine.hold()
```

---

## What's Left (Phase 2)

- [ ] HUD scene fully wired (score, level, lines displaying live)
- [ ] Next piece preview panel (shows next 1-3 pieces from `engine.next_pieces`)
- [ ] Held piece preview panel (shows `engine.held_piece`)
- [ ] Title screen (`scenes/title.tscn`)
- [ ] Game over screen (`scenes/game_over.tscn`) with final score + restart
- [ ] Pause menu overlay

---

## Common Bugs to Watch For

| Symptom | Likely Cause |
|---|---|
| Indentation error, wrong value returned | `return` inside `for` loop instead of after it |
| Wrong modulo on rotation | Missing `+ 4` before `% 4` for negative directions |
| Signal fires before visual is ready | Wrong signal emission order in `_lock_piece` |
| Typed array assignment fails | Assigned plain `Array` to `Array[T]` — must iterate+append |
| Sprite invisible despite correct position | `centered = true` (default) offset, or `region_enabled = false` |
| ColorRect invisible in Node2D | Control nodes need Control parent — use `_draw()` instead |
| `get_all()` type error | `Dictionary.values()` returns untyped — must build typed array manually |
| `class_name` not found | File not saved, or Godot hasn't reindexed — try reopening project |
| Lock delay not resetting | `_lock_timer` not cleared when piece successfully moves |

---

## Tone & Teaching Notes

- The developer is learning Godot for the first time — explain the *why*, not just the *what*
- When a bug is found, explain what went wrong conceptually before giving the fix
- Praise correct instincts (e.g., choosing the right data structure) — this reinforces good habits
- Keep momentum: don't over-explain, but never skip the concept behind a tool
- When the developer finds their own bug, acknowledge it — self-discovery is the best learning
- One task at a time. Don't front-load multiple steps unless they're trivially small
