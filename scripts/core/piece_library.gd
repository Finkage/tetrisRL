extends Node

## Piece Library — The Single Source of Truth for All Tetromino Definitions
##
## Purpose: This script is the authoritative registry of every Tetromino shape
## used throughout the Tetris Roguelike. It is loaded as an Autoload (global
## singleton), meaning it exists for the entire lifetime of the game and can
## be referenced from any script using the bare class name `PieceLibrary` —
## no `.new()` or node references required.
##
## Architecture role:
##   - Lower layers (TetrisEngine, TetrisGrid) NEVER import this. It exists
##     at the highest layer because only rendering/UI need to query piece
##     properties (color, shape, grid size).
##   - The engine receives fully-constructed Tetromino objects via the
##     7-bag randomizer and never constructs pieces itself.
##   - If you want to add a new piece type, you add a new `register()` call
##     in `_register_defaults()` — but per architecture rule #4, you should
##     never need to modify the engine for roguelike features.
##
## Data format: Each rotation state is a 4×4 grid flattened into a
## PackedInt32Array of 16 elements in row-major order (index = row * 4 + col).
## A value of 0 means empty; values 1-7 represent the color_index of the
## piece that occupies that cell (used for rendering lookups).

var _pieces: Dictionary = {}  # id string -> Tetromino resource

# ---------------------------------------------------------------------------
# Function: register
# ---------------------------------------------------------------------------
# Purpose: Add a Tetromino to the library's internal registry so that it can
#   be looked up by ID later. This is the only mutation point for `_pieces`.
#
# Parameters:
#   piece — The Tetromino Resource to store. Its `id` property becomes the
#           dictionary key.
func register(piece: Tetromino) -> void:
	# 1: Use the piece's own `id` property as the key and store a reference
	#    to the Tetromino in the internal dictionary. This creates the
	#    id → Tetromino mapping used by all lookup methods.
	_pieces[piece.id] = piece

# ---------------------------------------------------------------------------
# Function: get_piece
# ---------------------------------------------------------------------------
# Purpose: Retrieve a Tetromino by its string identifier. This is the
#   primary public API used by the 7-bag randomizer to request specific
#   piece types (e.g., "I", "O", "T").
#
# Parameters:
#   id — The string identifier of the piece to retrieve (e.g. "I", "J", "Z").
func get_piece(id: String) -> Tetromino:
	# 1: Look up the piece by id using Dictionary.get(), which returns `null`
	#    instead of throwing an error if the key doesn't exist. This is
	#    intentional — a missing piece is an expected edge case during
	#    development (e.g., typos in piece IDs) and should produce a
	#    visible crash (accessing null) rather than a silent corruption.
	return _pieces.get(id, null)

# ---------------------------------------------------------------------------
# Function: get_all
# ---------------------------------------------------------------------------
# Purpose: Return every registered Tetromino as a typed array. This is used
#   by the 7-bag randomizer to build the shuffled bag, because it needs to
#   iterate over the complete set of available pieces and randomly select
#   from all of them.
#
# Returns: Array[Tetromino] — a fresh array containing every registered piece.
func get_all() -> Array[Tetromino]:
	# 1: Create an empty typed array. In GDScript 4, calling Dictionary.values()
	#    returns an untyped Array, so we must build a typed Array[Tetromino]
	#    by iterating and appending — assigning a plain Array to this type
	#    would cause a compile-time error.
	var result: Array[Tetromino] = []
	for piece in _pieces.values():
		# 2: Append each Tetromino one at a time. The typed array system
	#    enforces type safety on each append, so a misconfigured piece
	#    (one that isn't a Tetromino resource) will fail immediately.
		result.append(piece)
	# 3: Return the complete typed array for the caller to consume.
	return result

# ---------------------------------------------------------------------------
# Function: _ready
# ---------------------------------------------------------------------------
# Purpose: Godot's built-in lifecycle callback called once after the Node and
#   all its children have entered the scene tree. Because this script is
#   registered as an Autoload, `_ready()` fires very early in application
#   startup — before any other scene loads.
func _ready() -> void:
	# 1: Run the default registration which populates `_pieces` with the
	#    standard 7 SRS Tetrominoes (I, O, T, S, Z, J, L). After this
	#    call returns, the library is fully populated and ready for use
	#    by the engine and any other system that queries piece data.
	_register_defaults()

# ---------------------------------------------------------------------------
# Function: _register_defaults
# ---------------------------------------------------------------------------
# Purpose: Define and register all 7 standard Tetromino pieces with their
#   SRS (Super Rotation System) rotation state data. Each piece is defined
#   with its ID, spritesheet color index, grid size, and four rotation
#   states — one for each 90° orientation (0°, 90°, 180°, 270°).
#
#   SRS rotation states are encoded as 4×4 grids flattened into row-major
#   PackedInt32Arrays. The grid size is always 4 for standard Tetris pieces,
#   even though some pieces could theoretically use a smaller bounding box.
#   Using a uniform 4×4 simplifies rotation arithmetic across all pieces.
#
#   Color indices follow the classic Nintendo Tetris Guideline palette:
#     1 = I (cyan),  2 = O (yellow), 3 = T (purple)
#     4 = S (green), 5 = Z (red),     6 = J (blue)
#     7 = L (orange)
#
#   In a future version, this data could be replaced by loading from
#   external JSON or CSV files to avoid recompiling the engine when
#   tweaking piece shapes. For now, hardcoding is fine — we have 7 pieces.
func _register_defaults() -> void:
	## ─── I piece (cyan) ───
	## SRS I-Piece Rotations (4×4 grid)
	## The I piece is special: its horizontal and vertical orientations reuse
	## the same PackedInt32Array because the shape doesn't change between
	## those states (only its position in the 4×4 grid shifts, which is handled
	## by wall-kick offsets at runtime).
	# 1: Create a new Tetromino resource. Resource.new() produces a blank
	#    object; all properties must be set manually before registration.
	var i_piece = Tetromino.new()
	# 2: Set the unique identifier. The engine's 7-bag randomizer will
	#    request pieces by this string — it must match exactly across
	#    all systems (engine, renderer, HUD, etc.).
	i_piece.id = "I"
	# 3: Set the color index (1 = cyan). This references row 1 in the
	#    10-row spritesheet used by GridRenderer for drawing blocks.
	i_piece.color_index = 1
	# 4: Set the bounding grid size. All 7 pieces use 4×4 for uniformity,
	#    even though the I piece occupies a 1×4 or 4×1 area in practice.
	i_piece.grid_size = 4
	# 5: Define all four rotation states. Each is a 4×4 row-major
	#    PackedInt32Array where 1s mark filled cells and 0s are empty.
	var i_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Horizontal I bar centered on row 1
		PackedInt32Array([0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0]),
		## Rotation 1 — Vertical I bar centered on column 1
		PackedInt32Array([0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0]),
		## Rotation 2 — Horizontal I bar (same as rotation 0, position differs)
		PackedInt32Array([0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0]),
		## Rotation 3 — Vertical I bar (same as rotation 1, position differs)
		PackedInt32Array([0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0]),
	]
	# 6: Assign the rotation table and register the piece. After this call,
	#    "I" is available for lookup via get_piece("I").
	i_piece.rotations = i_rotations
	register(i_piece)

	## ─── O piece (yellow) ───
	## SRS O-Piece Rotations (4×4 grid)
	## The O piece (square) is unique: all four rotation states are visually
	## and data-identical. It never actually rotates in-game — the rotation
	## is called for consistency of game loop flow even though the shape
	## state doesn't change.
	# 1: Create a new Tetromino resource for the O piece.
	var o_piece = Tetromino.new()
	o_piece.id = "O"
	# 2: Set color index 2 = yellow, grid 4×4 as with all pieces.
	o_piece.color_index = 2
	o_piece.grid_size = 4
	# 3: Define four identical rotation states — the square looks the same
	#    rotated by any multiple of 90°. The grid positions the 2×2 block
	#    into the center column (rows 2–3, columns 2–3 of the 4×4 grid).
	var o_rotations: Array[PackedInt32Array] = [
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
	]
	o_piece.rotations = o_rotations
	register(o_piece)

	## ─── T piece (purple) ───
	## SRS T-Piece Rotations (4×4 grid)
	var t_piece = Tetromino.new()
	t_piece.id = "T"
	t_piece.color_index = 3
	t_piece.grid_size = 4
	var t_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — T with stem pointing upward
		PackedInt32Array([0,0,0,0, 0,3,0,0, 3,3,3,0, 0,0,0,0]),
		## Rotation 1 — T with stem pointing right
		PackedInt32Array([0,0,0,0, 0,3,0,0, 0,3,3,0, 0,3,0,0]),
		## Rotation 2 — T with stem pointing down (standard play state)
		PackedInt32Array([0,0,0,0, 3,3,3,0, 0,3,0,0, 0,0,0,0]),
		## Rotation 3 — T with stem pointing left
		PackedInt32Array([0,0,0,0, 0,0,3,0, 0,3,3,0, 0,0,3,0]),
	]
	t_piece.rotations = t_rotations
	register(t_piece)

	## ─── S piece (green) ───
	## SRS S-Piece Rotations (4×4 grid)
	var s_piece = Tetromino.new()
	s_piece.id = "S"
	s_piece.color_index = 4
	s_piece.grid_size = 4
	var s_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Flat S shape (top blocks shifted right)
		PackedInt32Array([0,0,0,0, 0,4,4,0, 4,4,0,0, 0,0,0,0]),
		## Rotation 1 — Vertical S (top block shifted left)
		PackedInt32Array([0,0,0,0, 0,4,0,0, 0,4,4,0, 0,0,4,0]),
		## Rotation 2 — Flat S shape (identical grid to rotation 0)
		PackedInt32Array([0,0,0,0, 0,4,4,0, 4,4,0,0, 0,0,0,0]),
		## Rotation 3 — Vertical S (identical grid to rotation 1)
		PackedInt32Array([0,0,0,0, 0,4,0,0, 0,4,4,0, 0,0,4,0]),
	]
	s_piece.rotations = s_rotations
	register(s_piece)

	## ─── Z piece (red) ───
	## SRS Z-Piece Rotations (4×4 grid)
	var z_piece = Tetromino.new()
	z_piece.id = "Z"
	z_piece.color_index = 5
	z_piece.grid_size = 4
	var z_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Flat Z shape (top blocks shifted left)
		PackedInt32Array([0,0,0,0, 5,5,0,0, 0,5,5,0, 0,0,0,0]),
		## Rotation 1 — Vertical Z (top block shifted right)
		PackedInt32Array([0,0,0,0, 0,0,5,0, 0,5,5,0, 0,5,0,0]),
		## Rotation 2 — Flat Z shape (identical grid to rotation 0)
		PackedInt32Array([0,0,0,0, 5,5,0,0, 0,5,5,0, 0,0,0,0]),
		## Rotation 3 — Vertical Z (identical grid to rotation 1)
		PackedInt32Array([0,0,0,0, 0,0,5,0, 0,5,5,0, 0,5,0,0]),
	]
	z_piece.rotations = z_rotations
	register(z_piece)

	## ─── J piece (blue) ───
	## SRS J-Piece Rotations (4×4 grid)
	## The J piece is the mirror of L. In all SRS rotation tables:
	##   - Rotation 0 is the "standard" orientation (stem to the right)
	##   - Rotations progress clockwise from there
	var j_piece = Tetromino.new()
	j_piece.id = "J"
	j_piece.color_index = 6
	j_piece.grid_size = 4
	var j_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Stem pointing right, hook at bottom-left
		PackedInt32Array([0,0,0,0, 6,0,0,0, 6,6,6,0, 0,0,0,0]),
		## Rotation 1 — Stem pointing up, hook at bottom-left
		PackedInt32Array([0,0,0,0, 0,0,6,0, 0,0,6,0, 0,6,6,0]),
		## Rotation 2 — Stem pointing left, hook at top-right
		PackedInt32Array([0,0,0,0, 0,6,6,6, 0,0,0,6, 0,0,0,0]),
		## Rotation 3 — Stem pointing down, hook at top-right
		PackedInt32Array([0,0,0,0, 0,6,6,0, 0,6,0,0, 0,6,0,0]),
	]
	j_piece.rotations = j_rotations
	register(j_piece)

	## ─── L piece (orange) ───
	## SRS L-Piece Rotations (4×4 grid)
	## The L piece is the mirror of J. Same rotation progression as J but
	## with the hook on the opposite side.
	var l_piece = Tetromino.new()
	l_piece.id = "L"
	l_piece.color_index = 7
	l_piece.grid_size = 4
	var l_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Stem pointing left, hook at bottom-right
		PackedInt32Array([0,0,0,0, 0,0,7,0, 7,7,7,0, 0,0,0,0]),
		## Rotation 1 — Stem pointing down, hook at top-right
		PackedInt32Array([0,0,0,0, 0,7,7,0, 0,0,7,0, 0,0,7,0]),
		## Rotation 2 — Stem pointing right, hook at top-left
		PackedInt32Array([0,0,0,0, 0,7,7,7, 0,7,0,0, 0,0,0,0]),
		## Rotation 3 — Stem pointing up, hook at top-left
		PackedInt32Array([0,0,0,0, 0,7,0,0, 0,7,0,0, 0,7,7,0]),
	]
	l_piece.rotations = l_rotations
	register(l_piece)
