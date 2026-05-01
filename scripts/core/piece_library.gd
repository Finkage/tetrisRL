extends Node

var _pieces: Dictionary = {}  # id -> Tetromino

func register(piece: Tetromino) -> void:
	_pieces[piece.id] = piece

func get_piece(id: String) -> Tetromino:
	return _pieces.get(id, null)

func get_all() -> Array[Tetromino]:
	var result: Array[Tetromino] = []
	for piece in _pieces.values():
		result.append(piece)
	return result

func _ready() -> void:
	_register_defaults()

## -----------------------------------------------------------# SRS tetromino rotation tables.
## Each piece has 4 rotation states (0–3).
## A state is a 4×4 flat PackedInt32Array (1-7 = filled with color, 0 = empty).# Row-major order: index = row * 4 + col.

## Color indices matching Godot's standard Tetris palette:
## 1 = I (cyan), 2 = O (yellow), 3 = T (purple),
## 4 = S (green), 5 = Z (red), 6 = J (blue), 7 = L (orange)
func _register_defaults() -> void:
	## ─── I piece (cyan) ───
	## SRS I-Piece Rotations (4x4 grid)
	var i_piece = Tetromino.new()
	i_piece.id = "I"
	i_piece.color_index = 1
	i_piece.grid_size = 4
	var i_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Horizontal
		PackedInt32Array([0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0]),
		## Rotation 1 — Vertical
		PackedInt32Array([0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0]),
		## Rotation 2 — Horizontal
		PackedInt32Array([0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0]),
		## Rotation 3 — Vertical
		PackedInt32Array([0,1,0,0, 0,1,0,0, 0,1,0,0, 0,1,0,0]),
	]
	i_piece.rotations = i_rotations
	register(i_piece)

	## ─── O piece (yellow) ───
	## SRS O-Piece Rotations (4x4 grid)
	var o_piece = Tetromino.new()
	o_piece.id = "O"
	o_piece.color_index = 2
	o_piece.grid_size = 4
	var o_rotations: Array[PackedInt32Array] = [
		## All 4 rotations identical
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
		PackedInt32Array([0,0,0,0, 0,2,2,0, 0,2,2,0, 0,0,0,0]),
	]
	o_piece.rotations = o_rotations
	register(o_piece)

	## ─── T piece (purple) ───
	## SRS T-Piece Rotations (4x4 grid)
	var t_piece = Tetromino.new()
	t_piece.id = "T"
	t_piece.color_index = 3
	t_piece.grid_size = 4
	var t_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Stem Up
		PackedInt32Array([0,0,0,0, 0,3,0,0, 3,3,3,0, 0,0,0,0]),
		## Rotation 1 — Stem Right
		PackedInt32Array([0,0,0,0, 0,3,0,0, 0,3,3,0, 0,3,0,0]),
		## Rotation 2 — Stem Down
		PackedInt32Array([0,0,0,0, 3,3,3,0, 0,3,0,0, 0,0,0,0]),
		## Rotation 3 — Stem Left
		PackedInt32Array([0,0,0,0, 0,0,3,0, 0,3,3,0, 0,0,3,0]),
	]
	t_piece.rotations = t_rotations
	register(t_piece)

	## ─── S piece (green) ───
	## SRS S-Piece Rotations (4x4 grid)
	var s_piece = Tetromino.new()
	s_piece.id = "S"
	s_piece.color_index = 4
	s_piece.grid_size = 4
	var s_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Flat (S shape)
		PackedInt32Array([0,0,0,0, 0,4,4,0, 4,4,0,0, 0,0,0,0]),
		## Rotation 1 — Vertical
		PackedInt32Array([0,0,0,0, 0,4,0,0, 0,4,4,0, 0,0,4,0]),
		## Rotation 2 — Flat (S shape)
		PackedInt32Array([0,0,0,0, 0,4,4,0, 4,4,0,0, 0,0,0,0]),
		## Rotation 3 — Vertical
		PackedInt32Array([0,0,0,0, 0,4,0,0, 0,4,4,0, 0,0,4,0]),
	]
	s_piece.rotations = s_rotations
	register(s_piece)

	## ─── Z piece (red) ───
	## SRS Z-Piece Rotations (4x4 grid)
	var z_piece = Tetromino.new()
	z_piece.id = "Z"
	z_piece.color_index = 5
	z_piece.grid_size = 4
	var z_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Flat (Z shape)
		PackedInt32Array([0,0,0,0, 5,5,0,0, 0,5,5,0, 0,0,0,0]),
		## Rotation 1 — Vertical
		PackedInt32Array([0,0,0,0, 0,0,5,0, 0,5,5,0, 0,5,0,0]),
		## Rotation 2 — Flat (Z shape)
		PackedInt32Array([0,0,0,0, 5,5,0,0, 0,5,5,0, 0,0,0,0]),
		## Rotation 3 — Vertical
		PackedInt32Array([0,0,0,0, 0,0,5,0, 0,5,5,0, 0,5,0,0]),
	]
	z_piece.rotations = z_rotations
	register(z_piece)

	## ─── J piece (blue) ───
	## SRS J-Piece Rotations (4x4 grid)
	var j_piece = Tetromino.new()
	j_piece.id = "J"
	j_piece.color_index = 6
	j_piece.grid_size = 4
	var j_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Stem Right, Hook Up
		PackedInt32Array([0,0,0,0, 6,0,0,0, 6,6,6,0, 0,0,0,0]),
		## Rotation 1 — Stem Up, Hook Left
		PackedInt32Array([0,0,0,0, 0,0,6,0, 0,0,6,0, 0,6,6,0]),
		## Rotation 2 — Stem Left, Hook Down
		PackedInt32Array([0,0,0,0, 0,6,6,6, 0,0,0,6, 0,0,0,0]),
		## Rotation 3 — Stem Down, Hook Right
		PackedInt32Array([0,0,0,0, 0,6,6,0, 0,6,0,0, 0,6,0,0]),
	]
	j_piece.rotations = j_rotations
	register(j_piece)

	## ─── L piece (orange) ───
	## SRS L-Piece Rotations (4x4 grid)
	var l_piece = Tetromino.new()
	l_piece.id = "L"
	l_piece.color_index = 7
	l_piece.grid_size = 4
	var l_rotations: Array[PackedInt32Array] = [
		## Rotation 0 — Stem Left, Hook Up
		PackedInt32Array([0,0,0,0, 0,0,7,0, 7,7,7,0, 0,0,0,0]),
		## Rotation 1 — Stem Down, Hook Left
		PackedInt32Array([0,0,0,0, 0,7,7,0, 0,0,7,0, 0,0,7,0]),
		## Rotation 2 — Stem Right, Hook Down
		PackedInt32Array([0,0,0,0, 0,7,7,7, 0,7,0,0, 0,0,0,0]),
		## Rotation 3 — Stem Up, Hook Right
		PackedInt32Array([0,0,0,0, 0,7,0,0, 0,7,0,0, 0,7,7,0]),
	]
	l_piece.rotations = l_rotations
	register(l_piece)
