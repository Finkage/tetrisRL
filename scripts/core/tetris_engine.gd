class_name TetrisEngine
extends RefCounted

# ── Signals ─────────────────────────────────────────────────
signal piece_spawned(instance: TetrominoInstance)
signal piece_moved(instance: TetrominoInstance)
signal piece_rotated(instance: TetrominoInstance)
signal piece_locked(instance: TetrominoInstance)
signal piece_held(instance: TetrominoInstance)
signal lines_cleared(line_indices: Array[int])
signal game_over
signal score_changed(new_score: int)
signal level_changed(new_level: int)
signal gravity_changed(new_interval: float)

# ── State ────────────────────────────────────────────────────
var grid: TetrisGrid
var active_piece: TetrominoInstance
var ghost_piece: TetrominoInstance
var held_piece: Tetromino
var can_hold: bool = true
var next_pieces: Array[Tetromino] = []
var score: int = 0
var level: int = 1
var lines_cleared_total: int = 0
var game_over_state: bool = false
var is_paused: bool = false

# ── Configuration ────────────────────────────────────────────
var lock_delay: float = 0.5
var soft_drop_speed: float = 0.05
var _drop_timer: float = 0.0
var _lock_timer: float = 0.0
var _is_on_ground: bool = false
var gravity_multiplier: float = 1

# ── Initialization ───────────────────────────────────────────
func _init(grid_width: int = 10, grid_height: int = 20) -> void:
	grid = TetrisGrid.new(grid_width, grid_height)
	

# ── Core Loop ────────────────────────────────────────────────
func tick(delta: float) -> void:
	# primary game tick rate responsible for speed of gameplay
	# 1: check if game is paused or otherwise inactive (gameover)
	# 2: set ground state _is_on_ground by checking if on ground.
	# 3: start _lock_timer tick if on ground.
	# 4: tick gravity and move piece down

	# 1: check if game is paused or otherwise inactive
	if is_paused or game_over_state or active_piece == null:
		return
	
	# 2: set ground state
	_update_ground_state() 

	# 3: start lock tick if on ground
	if _is_on_ground:
		_lock_timer += delta
		if _lock_timer >= lock_delay:
			_lock_piece()
		return
	
	# 4: tick gravity and try to move piece down
	_drop_timer += delta
	if _drop_timer >= _get_drop_interval():
		_drop_timer = 0.0
		_try_move_down()

func start() -> void:
	# Reset game state variables
	score = 0
	level = 1
	lines_cleared_total = 0
	game_over_state = false
	is_paused = false
	can_hold = true
	held_piece = null

	# Clear the grid using the correct method name
	grid.reset()

	# Clear the next pieces queue and refill the bag
	next_pieces.clear()
	_refill_bag()

	# Spawn the first piece
	var first_piece: Tetromino = _get_next_piece()
	_spawn_piece(first_piece)

# ── Actions ──────────────────────────────────────────────────
func move(dir: int) -> bool:
	# dir: -1 for left, 1 for right
	if active_piece == null or game_over_state or is_paused:
		return false
		
	# Calculate the new column
	var new_col: int = active_piece.col + dir

	# Create a test instance with the new column
	var test_instance: TetrominoInstance = TetrominoInstance.new(
		active_piece.tetromino, new_col, active_piece.row
	)
	test_instance.rotation = active_piece.rotation

	# Check if the new position is valid
	if _is_valid_position(test_instance):
		# Apply the move
		active_piece.col = new_col
		_update_ghost()
		emit_signal("piece_moved", active_piece)
		return true
	else:
		return false

func rotate(dir: int) -> bool:
	# dir: -1 for CCW, 1 for CW
	if active_piece == null or game_over_state or is_paused:
		return false
		
	# Calculate the new rotation index
	# +4 ensures the result is positive before modulo
	var new_rotation: int = (active_piece.rotation + dir + 4) % 4

	# Create a test instance with the new rotation
	var test_instance: TetrominoInstance = TetrominoInstance.new(
		active_piece.tetromino, active_piece.col, active_piece.row
	)
	test_instance.rotation = new_rotation

	# Check if the new rotation is valid
	# Note: No wall kicks implemented yet, so if it hits a wall, it fails
	if _is_valid_position(test_instance):
		# Apply the rotation
		active_piece.rotation = new_rotation
		_update_ghost()
		emit_signal("piece_rotated", active_piece)
		return true
	else:
		return false

func hard_drop() -> void:
	# immediately drop active piece down to where ghost piece is
	# and give big score update for the use
	# 1: guard check to make sure there is an active piece and
	# game is running
	# 2: try moving until at ground, counting the rows
	# 3: update score based on number or rows skipped
	# 4: lock the active piece

	# 1: guard check
	if active_piece == null or game_over_state or is_paused:
		return

	# initialize the counting of rows
	var rows_dropped: int = 0

	# 2: Keep moving down until invalid, counting rows
	while _try_move_down():
		rows_dropped += 1

	# 3: update score
	score += rows_dropped * 2
	emit_signal("score_changed", score)

	# 4: Lock immediately
	_lock_piece()

func soft_drop() -> void:
	# quickly move active piece down and increase score for the attempt
	# 1: guard check that there is an active piece or game actions can
	# be taken
	# 2: move down and delay gravity

	# 1: guard check
	if active_piece == null or game_over_state or is_paused:
		return

	# move down and delay gravity
	if _try_move_down():
		# Add 1 point for soft drop
		score += 1
		emit_signal("score_changed", score)
		# Reset drop timer to prevent immediate gravity drop
		_drop_timer = 0.0

func hold() -> void:
	# 1. Return if can_hold is false
	if not can_hold or active_piece == null or game_over_state or is_paused:
		return

	# 2. Set can_hold to false
	can_hold = false

	var current_piece: Tetromino = active_piece.tetromino

	if held_piece == null:
		# 3. If no held piece, store current and spawn next
		held_piece = current_piece
		var next_piece: Tetromino = _get_next_piece()
		_spawn_piece(next_piece)
	else:
		# 4. If held piece exists, swap
		var temp_piece: Tetromino = held_piece
		held_piece = current_piece
		_spawn_piece(temp_piece)

	# 5. Emit signal
	emit_signal("piece_held")

# ── Internal ─────────────────────────────────────────────────
func _spawn_piece(tetromino: Tetromino) -> void:
	# Calculate spawn position: centered horizontally, starting at row 0
	# grid_size is typically 4 for most pieces, but we use the specific piece's size
	var spawn_col: int = (grid.width / 2) - (tetromino.grid_size / 2)
	var spawn_row: int = 0

	# Create the new instance
	var new_instance: TetrominoInstance = TetrominoInstance.new(tetromino, spawn_col, spawn_row)

	# Check if the spawn position is valid
	# If not, it means the board is full (blocks stacked to the top)
	if not _is_valid_position(new_instance):
		game_over_state = true
		emit_signal("game_over")
		return

	# Assign to active piece
	active_piece = new_instance

	# Update the ghost piece to reflect the new active piece's position
	_update_ghost()

	# Emit signal so the UI/Renderer can display the new piece
	emit_signal("piece_spawned", active_piece)

func _lock_piece() -> void:
	# 1. Write each cell from the active piece into the grid
	if active_piece != null:
		var cells: Array[Vector2i] = active_piece.get_cells()
		var color_index: int = active_piece.tetromino.color_index

		for cell in cells:
			# Only set cells that are within the grid bounds (y >= 0)
			# Cells above the grid (negative y) should not be locked into the grid
			if cell.y >= 0:
				grid.set_cell(cell.x, cell.y, color_index)

	# 2. Reset can_hold so the player can hold the next piece
	can_hold = true

	# 3. Clear active and ghost pieces
	active_piece = null
	ghost_piece = null

	# 4. Emit signal
	emit_signal("piece_locked")

	# 5. Check for cleared lines
	_check_lines()

	# 6. Spawn the next piece
	var next_piece: Tetromino = _get_next_piece()
	_spawn_piece(next_piece)

func _check_lines() -> void:
	# 1. Loop through every row in the grid to find full rows
	var full_rows: Array[int] = []
	for row_index in range(grid.height):
		if grid.is_row_full(row_index):
			full_rows.append(row_index)
	
	# 2. If no lines are full, return early
	if full_rows.is_empty():
		return

	# 3. Clear the full rows in the grid
	for row_index in full_rows:
		grid.clear_row(row_index)

	# 4. Shift the remaining rows down to fill the gaps
	grid.shift_rows_down(full_rows)

	# 5. Update total lines cleared
	var line_count: int = full_rows.size()
	lines_cleared_total += line_count

	# 6. Calculate score
	# Standard scoring: 100, 300, 500, 800 for 1, 2, 3, 4 lines respectively
	var points: Array[int] = [0, 100, 300, 500, 800]
	if line_count >= 0 and line_count <= 4:
		score += points[line_count] * level
	else:
		# Fallback for unexpected line counts (e.g., > 4)
		score += points[4] * level

	# 7. Check for level up
	# Standard Tetris: Level increases every 10 lines cleared
	var new_level: int = (lines_cleared_total / 10) + 1
	var did_level_up: bool = false

	if new_level > level:
		level = new_level
		did_level_up = true

	# 8. Emit signals
	emit_signal("lines_cleared", full_rows)
	emit_signal("score_changed", score)

	if did_level_up:
		emit_signal("level_changed", level)
		gravity_changed.emit(_get_drop_interval())

func _update_ghost() -> void:
	# If there is no active piece, there is no ghost to update
	if active_piece == null:
		ghost_piece = null
		return

	# Create a copy of the active piece at the same position and rotation
	var ghost: TetrominoInstance = TetrominoInstance.new(
		active_piece.tetromino, active_piece.col, active_piece.row
	)
	# Ensure the ghost matches the active piece's rotation
	ghost.rotation = active_piece.rotation

	# Move the ghost down until it hits an obstacle or the floor
	var current_row: int = ghost.row

	while true:
		# Try moving down one row
		current_row += 1
		
		# Create a temporary instance to test the position
		var test_ghost: TetrominoInstance = TetrominoInstance.new(
			active_piece.tetromino, active_piece.col, current_row
		)
		# Ensure the test ghost matches the active piece's rotation
		test_ghost.rotation = active_piece.rotation
		
		if not _is_valid_position(test_ghost):
			# The position is invalid, so the previous row was the last valid one
			break
			
		# If valid, continue moving down
		ghost = test_ghost
	
	# Assign the final ghost position
	ghost_piece = ghost

func _is_valid_position(instance: TetrominoInstance) -> bool:
	# Retrieve the world-space coordinates of all filled cells for the current piece rotation
	var cells: Array[Vector2i] = instance.get_cells()
	
	for cell in cells:
		var x: int = cell.x
		var y: int = cell.y
		
		# Check horizontal bounds: reject if outside left or right walls
		# The grid width is typically 10, so valid x indices are 0 to 9
		if x < 0 or x >= grid.width:
			return false
			
		# Check vertical lower bound: reject if below the grid floor
		# Valid y indices are 0 to grid.height - 1.
		# Note: Negative y values (above the grid) are VALID for spawning.
		if y >= grid.height:
			return false
			
		# Check occupancy: if the cell is within the vertical grid bounds,
		# ensure it is not already occupied by a locked piece.
		# We only check occupancy if y >= 0 to avoid accessing invalid grid indices.
		if y >= 0:
			if grid.get_cell(x, y) > 0:
				return false
				
	# If all cells pass the checks, the position is valid
	return true

func _refill_bag() -> void:
	# Get all available tetromino types from the library
	# Assuming PieceLibrary is a singleton or static class with a get_all_pieces() method
	var all_pieces: Array[Tetromino] = PieceLibrary.get_all()

	# Shuffle the list to randomize the order
	all_pieces.shuffle()

	# Append the shuffled pieces to the next_pieces queue
	next_pieces.append_array(all_pieces)

func _get_next_piece() -> Tetromino:
	# Refill the bag if we are running low on pieces.
	# We refill when fewer than 7 pieces remain to ensure a smooth preview queue.
	if next_pieces.size() < 7:
		_refill_bag()

	# Pull the first piece from the queue
	var piece: Tetromino = next_pieces.pop_front()

	return piece

func _get_drop_interval() -> float:
	# Standard Tetris gravity formula:
	# interval = (0.8 - (level - 1) * 0.007) ^ (level - 1)
	# This results in ~1.0s at level 1, getting faster as level increases.

	var base: float = 0.8 - (level - 1) * 0.007
	var exponent: float = level - 1

	# Clamp base to avoid negative values or zero which could cause issues with pow()
	# Although standard formula doesn't clamp, in practice level caps prevent base < 0.
	# At level 115, base becomes 0. We clamp to a small positive number to avoid 0^0 or negative bases.
	if base < 0.01:
		base = 0.01

	var interval: float = pow(base, exponent)

	return interval * gravity_multiplier

func _update_ground_state() -> void:
	# ground checker. creates a false tetromino instance one tick ahead 
	# and sees if it is in a valid position. if not then we are on ground

	# gather information on curent tetromino and incriment info by one tick
	var new_row: int = active_piece.row + 1
	var test: TetrominoInstance = TetrominoInstance.new(active_piece.tetromino, active_piece.col, new_row)
	test.rotation = active_piece.rotation

	# check if this is a valid position and set _is_on_ground to true or
	# false based on the opposite
	_is_on_ground = not _is_valid_position(test)

func _try_move_down() -> bool:
	# tries to move active piece down.
	# 1: gather info of next tick of active piece
	# 2: check if next tick is a valid position
	# and move active piece down if it is and return true
	# 3: return false if not

	# 1: gather info about next tick of active piece
	var new_row = active_piece.row + 1
	var test: TetrominoInstance = TetrominoInstance.new(active_piece.tetromino, active_piece.col, new_row)
	test.rotation = active_piece.rotation

	# 2: check if next tick is a valid position and move piece down
	if _is_valid_position(test):
		active_piece.row = new_row
		_is_on_ground = false
		_lock_timer = 0.0 # any downward movement cancels lock delay
		_update_ghost()
		emit_signal("piece_moved", active_piece)
		return true
	
	# 3: return false if not
	return false

func set_gravity(gravity: float) -> void:
	gravity_multiplier = gravity
	gravity_changed.emit(_get_drop_interval())
