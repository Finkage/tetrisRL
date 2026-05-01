class_name TetrisGrid
extends RefCounted
## Pure data structure representing the Tetris playfield.
## Stores locked piece cells in a flat array (row-major order).
## Zero Godot dependencies — pure simulation data, as per the architecture rule.
##
## Cell values:
##   0  → empty space
##   1..N → locked block (material/index identifier)
##  -1  → ghost
##  -2  → frozen
##  -3  → crumbling
##  -n  → additional unique states
const EMPTY    :=  0
const GHOST    := -1
const FROZEN   := -2
const CRUMBLING:= -3
## Playfield dimensions (default 10×20)
var width: int = 10
var height: int = 20
## Flat cell storage in row-major order.
## Index calculation: index = row * width + col
var cells: PackedInt32Array


## ── Initialization ──────────────────────────────────────────────────────────
## Create a new grid with the specified width and height.
## Fills all cells with EMPTY.
func _init(w: int, h: int) -> void:
	width = w
	height = h
	cells.resize(width * height)
	cells.fill(EMPTY)


## ── Cell Access ─────────────────────────────────────────────────────────────
## Retrieve the cell value at a given column and row.
## Returns 0 if the coordinates fall outside the grid bounds.
func get_cell(col: int, row: int) -> int:
	## Bounds-check: silently return empty if out of range
	if col < 0 or col >= width or row < 0 or row >= height:
		return 0
	return cells[row * width + col]
## Set the value of a cell at the specified column and row.
## Silently ignores the operation if coordinates are out of bounds.
func set_cell(col: int, row: int, value: int) -> void:
	if col < 0 or col >= width or row < 0 or row >= height:
		return
	cells[row * width + col] = value


## ── Row Operations ──────────────────────────────────────────────────────────
## Check whether a given row is completely filled.
## A row is full when every cell in it has a value > 0.
func is_row_full(row: int) -> bool:
	## Check for out of bounds
	if row < 0 or row >= height:
		return false
	## Check if a cell in row is empty. If no cell is empty, return true.
	var row_start: int = row * width
	for c in range(width):
		if cells[row_start + c] == EMPTY:
			return false
	return true


## Clear all cells in a row, setting each to EMPTY.
func clear_row(row: int) -> void:
	if row < 0 or row >= height:
		return
	var row_start: int = row * width
	for c in range(width):
		cells[row_start + c] = EMPTY


## Shift unlocked rows downward to fill gaps left by cleared rows.
## Processes from bottom-to-top to avoid overwriting data we still need.
func shift_rows_down(cleared_rows: Array[int]) -> void:
	if cleared_rows.is_empty():
		return
	## Use a Dictionary for fast O(1) lookup and automatic duplicate removal
	var cleared_set: Dictionary = {}
	for r in cleared_rows:
		cleared_set[r] = true
	## Two-pointer sweep: write from the bottom up
	var write_row: int = height - 1
	for read_row in range(height - 1, -1, -1):
		## Only copy unlocked rows down
		if not cleared_set.has(read_row):
			for c in range(width):
				cells[write_row * width + c] = cells[read_row * width + c]
			write_row -= 1
	## Everything above the final write position is now empty/needs clearing
	while write_row >= 0:
		clear_row(write_row)
		write_row -= 1


## ── Modify Grid ─────────────────────────────────────────────────────────────
func resize_grid(new_w: int, new_h: int) -> void:
	var new_cells = PackedInt32Array()
	new_cells.resize(new_w * new_h)
	new_cells.fill(EMPTY)
	# Copy existing data into new grid, aligned to bottom-left
	var col_count = mini(width, new_w)
	var row_offset = new_h - height  # shift rows down if height grew
	for row in range(height):
		var new_row = row + row_offset
		if new_row < 0 or new_row >= new_h:
			continue
		for col in range(col_count):
			new_cells[new_row * new_w + col] = cells[row * width + col]
	width = new_w
	height = new_h
	cells = new_cells


## ── Reset ───────────────────────────────────────────────────────────────────
## Clear the entire grid by filling every cell with EMPTY.
func reset() -> void:
	cells.fill(EMPTY)
