# Tetris Roguelike — Design Plan (Updated)

> **Goal:** Build a mobile-first Tetris roguelike game in Godot 4.6 as a learning project, with a fully abstracted Tetris engine at its core and pluggable roguelike systems layered on top.

> **Architecture:** A data-driven Tetris engine sits at the center, fully decoupled from rendering and input. Roguelike systems (rounds, buffs, progression, events) interact with this engine through well-defined hook points. Godot is used for the UI shell, asset pipeline, and rendering — the game logic lives in GDScript with Resources as data.

> **Tech Stack:** Godot 4.6, GDScript, Godot Resource (.tres) for game data, mobile-first UI with input abstraction.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Core Tetris Engine](#2-core-tetris-engine)
3. [Roguelike Systems](#3-roguelike-systems)
4. [Input & Mobile Layer](#4-input--mobile-layer)
5. [Rendering & UI](#5-rendering--ui)
6. [Project Structure](#6-project-structure)
7. [Implementation Phases](#7-implementation-phases)
8. [Key Design Decisions](#8-key-design-decisions)
9. [Decisions Made During Development](#9-decisions-made-during-development)

---

## 1. System Overview

```
┌─────────────────────────────────────────────┐
│                   UI Shell                  │
│  (Start Screen / Buff Select / HUD / etc.)  │
├─────────────────────────────────────────────┤
│              Input Abstraction              │
│  (Touch / Swipe / Keyboard / Vibrate)       │
├─────────────────────────────────────────────┤
│              Roguelike Systems              │
│  (Rounds / Events / Buffs / Progression)    │
├─────────────────────────────────────────────┤
│            Tetris Engine (Core)             │
│  (Grid / Pieces / Moves / Clear / Scoring)  │
├─────────────────────────────────────────────┤
│              Rendering Layer                │
│     (Godot Nodes, Animation, Particles)     │
└─────────────────────────────────────────────┘
```

**Layering Rule:** Higher layers can call down to lower layers. Lower layers know nothing about higher layers. The Tetris engine is a pure game-logic library — it must never import or reference roguelike, rendering, or UI code.

**Signal Rule:** Signals flow upward only. The engine emits; renderers and managers listen. Never modify the engine for new roguelike features — use hooks.

---

## 2. Core Tetris Engine

### 2.1 Design Philosophy

The Tetris engine is a **pure simulation** extending `RefCounted`:

- Zero Godot Node dependencies
- Zero rendering code
- Zero input code
- Zero audio code
- Zero UI code

It takes inputs as method calls and produces game state changes as signals.

### 2.2 Grid System (`TetrisGrid`)

```gdscript
class_name TetrisGrid
extends RefCounted

# Cell state constants
const EMPTY     :=  0
const GHOST     := -1
const FROZEN    := -2
const CRUMBLING := -3
# 1..N = locked piece color_index

var width: int
var height: int
var cells: PackedInt32Array  # flat row-major: index = row * width + col
```

**Key methods:**
- `get_cell(col, row) -> int` — returns 0 for out-of-bounds (spawn zone safe)
- `set_cell(col, row, value)` — silently ignores out-of-bounds
- `is_row_full(row) -> bool` — true if every cell > 0
- `clear_row(row)` — zeros a row
- `shift_rows_down(cleared_rows: Array[int])` — two-pointer sweep, bottom-up
- `reset()` — zeros all cells
- `resize_grid(new_w, new_h)` — expands/contracts mid-game, preserves data aligned to bottom-left

### 2.3 Piece Definitions (Data-Driven)

**`Tetromino`** is a template resource (static data, never mutated):

```gdscript
class_name Tetromino
extends Resource

@export var id: String                        # "I", "T", "bomb", etc. — no enum, fully extensible
@export var color_index: int                  # spritesheet row (1-based)
@export var rotations: Array[PackedInt32Array] # 4 rotation states, each a grid_size×grid_size flat array
@export var grid_size: int = 4               # 4×4 default; custom pieces can use 2×2, 5×5, etc.
```

Shapes store color_index directly in filled cells (e.g., `3` for T piece), so each cell value carries both "filled" and "which color" in one integer. The engine treats `value > 0` as filled for collision, and uses the value itself for color lookup.

**`TetrominoInstance`** is the live falling piece:

```gdscript
class_name TetrominoInstance
extends RefCounted

var tetromino: Tetromino  # template reference
var col: int              # left edge on grid
var row: int              # top edge on grid (negative = spawn zone, valid)
var rotation: int = 0     # 0-3

func get_cells() -> Array[Vector2i]  # world-space filled cell positions
```

**`PieceLibrary`** (Autoload): dynamic registry, replaces enum:

```gdscript
# Autoload: PieceLibrary
var _pieces: Dictionary = {}  # id -> Tetromino

func register(piece: Tetromino) -> void
func get_piece(id: String) -> Tetromino
func get_all() -> Array[Tetromino]  # iterate+append, not .values() (typed array limitation)
```

Default 7 pieces registered in `_ready()` via `_register_defaults()`. Buffs call `register()` at runtime to add custom pieces — identical API.

### 2.4 TetrisEngine

```gdscript
class_name TetrisEngine
extends RefCounted

# Signals
signal piece_spawned(instance: TetrominoInstance)
signal piece_moved(instance: TetrominoInstance)
signal piece_rotated(instance: TetrominoInstance)
signal piece_locked(instance: TetrominoInstance)
signal piece_held(instance: TetrominoInstance)
signal lines_cleared(line_indices: Array[int])
signal game_over
signal score_changed(new_score: int)
signal level_changed(new_level: int)  # NOTE: do not shadow with local var named level_changed
```

**Gravity formula:** `interval = (0.8 - (level-1) * 0.007) ^ (level-1)` (Nintendo Standard), multiplied by `gravity_multiplier`. Base clamped to >= 0.01.

**Scoring:** `[0, 100, 300, 500, 800][line_count] * level`. Hard drop: 2pts/row. Soft drop: 1pt/row.

**Level:** `lines_cleared_total / 10 + 1`.

**Lock delay:** 0.5s after piece touches ground. Timer resets if piece moves or rotates successfully.

**7-bag:** Refill when queue < 7 pieces. `get_all()` → shuffle → append.

**Signal order on lock:** `piece_locked` → `lines_cleared` → `piece_spawned`. Never reorder — renderer depends on this sequence.

**Gravity system:** `gravity_multiplier` is a set property with `clampf(0.01, 10.0)`. Setting it emits `gravity_changed(new_interval)`. Buffs/event systems can modify it to slow/speed up gameplay without engine changes. Level changes also emit this signal automatically.

### 2.5 Key Abstraction Points

| What | How Abstracted |
|---|---|
| Piece definitions | `PieceLibrary` registry — runtime extensible |
| Piece identity | String `id`, no enum |
| Grid size | `resize_grid()` — can change mid-game |
| Cell states | Integer constants on `TetrisGrid` |
| Line clearing | Returns list of indices — renderer animates |
| Score calculation | Configurable, emits signal |
| Board modification | `on_board_modified()` hook for buffs |

---

## 3. Roguelike Systems

### 3.1 High-Level Flow

```
Round Start
	│
	├── Tetris gameplay for N lines (or time limit, or board overflow)
	├── Events randomly occur, changing pace of game
	├── Round End screen appears
	│
	└── Buff Selection (choose 1 from 3 random buffs)
		│
		├── Buff applied as modifier stack to engine + player
		├── Stats updated (starting level, etc.)
		│
		└──→ Next Round
```

### 3.2 Buff Architecture

Buffs are Resources — fully declarative, loadable at runtime:

```gdscript
class_name Buff
extends Resource

enum RARITY { COMMON, UNIQUE, LEGENDARY }
@export var buff_id: String
@export var display_name: String
@export var rarity: RARITY
@export var description: String
@export var max_stack: int = 1
var effects: Array[BuffEffect]

func apply_to_engine(engine: TetrisEngine) -> void
```

### 3.3 Buff Categories

| Category | Hook Modified | Example Buffs |
|---|---|---|
| **Piece Mods** | Active piece definition | "Bomb pieces", "Split pieces" |
| **Board Mods** | `on_board_modified()` | "Random clear", "Color filter" |
| **Movement Mods** | Move/rotate logic | "Teleport", "Magnet walls" |
| **Scoring Mods** | Score calculation | "Double score", "Chain bonus" |
| **Spawn Mods** | Piece spawn logic | "Double spawn", "Power piece" |
| **Economy** | Buff selection | "More choices", "Skip event" |

### 3.4 Round & Event System

```gdscript
class RoundManager:
	var current_round: int = 0
	var lines_this_round: int = 0
	var lines_per_round: int = 10
	var active_event: Event
```

Events modify engine parameters mid-round (gravity spike, piece restriction, etc.). Defined as Resources in `event_library/`.

---

## 4. Input & Mobile Layer

### 4.1 Input Actions (registered in Project Settings → Input Map)

| Action | Key |
|---|---|
| `move_left` | Left Arrow |
| `move_right` | Right Arrow |
| `rotate_cw` | Up Arrow |
| `soft_drop` | Down Arrow |
| `hard_drop` | Space |
| `hold` | C |

### 4.2 Touch Controls Layout (future)

```
┌──────────────────────────────┐
│  HUD: Score | Level | Lines  │
├──────────────────────────────┤
│         PLAYFIELD            │
│      (Tetris Grid)           │
├──────────┬───────────┬──────┤
│  ◀ ▶     │  [HOLD]   │  ↻   │
│  (Move)  │ (Preview) │  (R) │
├──────────┴───────────┴──────┤
│           [DROP]             │
│         (Hard Drop)          │
└──────────────────────────────┘
```

`InputMapper` will abstract touch/keyboard into the same action calls.

---

## 5. Rendering & UI

### 5.1 Rendering Strategy

Renderer listens to engine signals — never reads engine state except `ghost_piece` and `grid` for display:

```
TetrisEngine.signals
	├── piece_spawned  → update piece sprite position + color
	├── piece_moved    → update piece sprite position
	├── piece_rotated  → update piece sprite position
	├── piece_locked   → hide piece cells, refresh grid
	├── lines_cleared  → refresh grid (data already updated)
	├── game_over      → trigger end screen
	├── score_changed  → update HUD
	├── level_changed  → update HUD, recompute background tint
	└── gravity_changed → trigger speed indicator flash or meter update
```

### 5.2 Cell Rendering

- **Node type:** `Sprite2D` (not TextureRect — needs `region_rect`)
- **Spritesheet:** `NES - Tetris - Miscellaneous - Block Tiles.png`, 32×80px, 4 columns × 10 rows, 8×8px per tile
- **Scale:** `Vector2(5, 5)` → 40×40px per cell = `CELL_SIZE`
- **`centered = false`** — positions are top-left aligned
- **Column 2** of spritesheet selected (adjustable via `TILE_COLUMN` constant)
- `set_color_index(index)`: sets `region_rect = Rect2(TILE_COLUMN * 8, (index-1) * 8, 8, 8)`

### 5.3 GridRenderer

- Extends `Node2D`, positioned at `Vector2(40, 44)` in game scene
- Background drawn via `_draw()` override using `draw_rect()`
- **Background tint:** `Color(0.1, 0.1, 0.18)` lerp toward `Color(level*0.015, 0.1, 0.18)` each frame — adds red intensity as level increases
- Three cell layers (build order = render order, last = front):
  1. Grid cells (200 nodes, always exist, updated on lock/clear)
  2. Ghost cells (4 nodes, `modulate.a = 0.35`)
  3. Active piece cells (4 nodes, full opacity)
- If grid is resized by a buff: call a `_rebuild()` method to recreate all cell nodes

### 5.4 UI Screens

| Screen | Description |
|---|---|
| **HUD** | Score, level, lines (CanvasLayer, always visible) |
| **Title** | Game title, Start button |
| **Buff Select** | Post-round 3-card pick |
| **Round Start** | "Round N — Event: X" announcement |
| **Game Over** | Final score, rounds, restart |
| **Pause** | Resume / Quit to title |

---

## 6. Project Structure

```
tetrisRL/
├── project.godot
├── scenes/
│   ├── game.tscn              ← Root scene (Node)
│   ├── hud.tscn               ← HUD overlay (CanvasLayer)
│   ├── buff_select.tscn
│   ├── title.tscn
│   ├── game_over.tscn
│   ├── rendering/
│   │   └── grid_renderer.tscn ← Node2D with grid_renderer.gd
│   └── ui/
│       ├── cell.tscn          ← Sprite2D, cell.gd
│       └── button.tscn
├── scripts/
│   ├── game.gd                ← Root scene controller
│   ├── core/
│   │   ├── tetris_engine.gd
│   │   ├── tetris_grid.gd
│   │   ├── tetromino.gd
│   │   ├── tetromino_instance.gd
│   │   └── tetromino_data/
│   │       └── (piece definitions live in piece_library.gd _register_defaults)
│   ├── roguelike/
│   │   ├── buff.gd
│   │   ├── buff_library/
│   │   ├── buff_manager.gd
│   │   ├── round_manager.gd
│   │   ├── event.gd
│   │   └── event_library/
│   ├── rendering/
│   │   ├── grid_renderer.gd
│   │   ├── hud.gd
│   │   └── cell.gd
│   ├── input/
│   │   └── input_mapper.gd
│   └── utils/
│       ├── game_state.gd      ← Autoload: GameState
│       └── math_utils.gd
├── assets/
│   ├── sprites/
│   │   └── NES - Tetris - Miscellaneous - Block Tiles.png
│   ├── audio/
│   └── fonts/
└── docs/
	├── plan.md
	└── AGENTS.md
```

**Autoloads registered:**
- `GameState` → `scripts/utils/game_state.gd`
- `PieceLibrary` → `scripts/core/piece_library.gd`

---

## 7. Implementation Phases

### Phase 1: Tetris Core ✅ COMPLETE

|- [x] Project setup, folder structure, autoloads
|- [x] `TetrisGrid` with resize support and cell state constants
|- [x] `Tetromino` resource class (String id, no enum, grid_size)
|- [x] `TetrominoInstance` with `get_cells()`
|- [x] `PieceLibrary` autoload with all 7 default pieces
|- [x] `TetrisEngine` — full game loop, all mechanics
|- [x] `GridRenderer` — cell nodes, ghost, background
|- [x] `Cell` scene — Sprite2D, spritesheet region
|- [x] Keyboard input (Input Map actions)
|- [x] Project settings (viewport, pixel art filter)
|- [x] **Dynamic gravity** — classic Tetris formula `interval = (0.8 - (level-1) * 0.007) ^ (level-1)`
|- [x] **Clean tick system** — phased: ground check → lock delay → gravity (no duplicated logic)
|- [x] **`gravity_multiplier`** property with set/emit pattern — ready for future buff/event modifiers
|- [x] **`gravity_changed` signal** — fires whenever speed changes (level up, buffs, etc.)
|- [x] **Background tint shift** — `GridRenderer._draw()` lerps red channel based on level (0.05→0.20 red)

**Milestone: Full vanilla Tetris is playable ★**

### Phase 2: HUD & UI Polish 🔄 IN PROGRESS

- [ ] HUD scene (CanvasLayer) — score, level, lines
- [ ] Next piece preview panel
- [ ] Held piece preview panel
- [ ] Title screen
- [ ] Game over screen with final stats
- [ ] Pause menu

**Milestone: Complete UI shell around the playfield**

### Phase 3: Roguelike Foundation

- [ ] `Buff` Resource class and `BuffManager`
- [ ] `Event` Resource class and `RoundManager`
- [ ] Buff selection UI (3-card pick)
- [ ] Round start/end flow
- [ ] Dummy round loop (complete → pick → next)

**Milestone: Full round flow works ◕‿◕**

### Phase 4: First Real Buff

Recommended first buff: **"Wide Board"** — calls `grid.resize_grid(12, 20)` and triggers `GridRenderer._rebuild()`. Simple, tests the extensibility end-to-end with no engine logic changes.

**Milestone: Buff system works end-to-end ✧**

### Phase 5: Mobile Support

- [ ] `InputMapper` — touch, swipe, keyboard abstraction
- [ ] Touch control layout
- [ ] Screen orientation handling
- [ ] Haptic feedback

**Milestone: Fully playable on mobile ♪**

### Phase 6: More Buffs & Events

- [ ] Board modification buffs (random line clear)
- [ ] Piece modification buffs (bomb pieces)
- [ ] Defensive buffs (shield)
- [ ] Multiplier buffs
- [ ] Multiple event types

**Milestone: 15-20 buffs across all categories ★**

### Phase 7: Polish & Audio

- [ ] Line clear animations and particles
- [ ] Screen shake
- [ ] Sound effects and music
- [ ] Score combo system
- [ ] High score persistence (GameState autoload)

**Final Milestone: Complete playable Tetris Roguelike ♪♪♪**

---

## 8. Key Design Decisions

### Resources for Game Data
Godot Resources are native, serializable, editable. Pieces and buffs can be defined as standalone `.tres` files, loaded dynamically, inspected in the editor, and extended by subclassing. Currently pieces are defined in code (`_register_defaults`) — migrating select pieces to `.tres` is a future task when buff-defined pieces need to ship as data files.

### Pure Simulation Layer
- Makes TetrisEngine testable without Godot
- Allows swapping renderers (2D → 3D)
- Enables offline analysis and replay
- Core bugs reproduce identically in simulation and in-game

### Hook System (Signals)
```
engine → "lines_cleared(count, lines)"
RoundManager → applies event effects + checks round complete
```
- Buffs intercept and modify any event
- Add new effects without touching engine code
- **Rule: Never modify the engine for new roguelike features**

### No Enum for Piece Types
`Tetromino.id` is a `String`. This allows buffs to register completely new piece types at runtime with zero engine changes. The `PieceLibrary` autoload is the single source of truth for all piece definitions.

### GridRenderer owns its background
Background is drawn via `_draw()` on the `Node2D` — no separate `ColorRect` child. This ensures the background always matches grid dimensions exactly and will auto-update when `_rebuild()` is called after a grid resize.

### Godot-Specific Patterns
- **`class_name`** → global availability, no imports needed
- **Autoloads** → `GameState`, `PieceLibrary` (global singletons)
- **Signals** → primary upward communication
- **`RefCounted`** → engine and grid (no scene tree, auto memory managed)
- **`CanvasLayer`** → all UI (renders independent of game world)
- **`@onready`** → node references in scene tree
- **`$NodeName`** → shorthand for `get_node("NodeName")`

---

## 9. Decisions Made During Development

| Decision | Reason |
|---|---|
| Swapped Phase 2 (mobile) later in order | Roguelike foundation more valuable to test first |
| Piece shapes defined in `_register_defaults()` not `.tres` | Less friction during engine development; `.tres` migration deferred |
| `Tetromino.id` is String not enum | Enables runtime piece registration by buffs |
| `PieceLibrary.get_all()` iterates+appends | GDScript typed array limitation — `Dictionary.values()` returns untyped `Array` |
| `Array[PackedInt32Array]` assigned via typed var | GDScript 4 requires explicit type annotation on variable before assignment |
| `Sprite2D` chosen over `TextureRect` for Cell | `Sprite2D` has native `region_rect` and `region_enabled`; TextureRect does not |
| `centered = false` on Cell Sprite2D | Positions are top-left aligned to match grid coordinate system |
| Cell scale `Vector2(5,5)` not `Vector2(6,6)` | `8px * 5 = 40px = CELL_SIZE`; 6 caused bleed between cells |
| Background via `_draw()` not `ColorRect` child | `ColorRect` is a Control node and misbehaves inside Node2D trees |
| Ghost cells built before piece cells in `setup()` | Godot renders children in order; ghost must be behind active piece |
| Signal order: `piece_locked` before `lines_cleared` before `piece_spawned` | Renderer depends on this sequence to update visuals correctly |
| `local var did_level_up` not `level_changed` | Avoids shadowing the `level_changed` signal name |
