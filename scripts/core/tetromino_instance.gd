class_name TetrominoInstance
extends RefCounted

var tetromino: Tetromino   # the template
var col: int               # left edge position on the grid
var row: int               # top edge position on the grid
var rotation: int = 0      # current rotation index (0-3)

func _init(t: Tetromino, start_col: int, start_row: int) -> void:
	tetromino = t
	col = start_col
	row = start_row
	rotation = 0

func get_current_rotation() -> PackedInt32Array:
	return tetromino.rotations[rotation]

func get_cells() -> Array[Vector2i]:
	# Returns grid positions of all filled cells in world space
	var result: Array[Vector2i] = []
	var shape = get_current_rotation()
	var size = tetromino.grid_size
	for r in range(size):
		for c in range(size):
			if shape[r * size + c] > 0:
				result.append(Vector2i(col + c, row + r))
	return result
