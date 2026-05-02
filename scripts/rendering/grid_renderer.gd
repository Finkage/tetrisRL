class_name GridRenderer
extends Node2D
 
const CELL_SIZE = 40  # 8px tile * 6 scale
const CellScene = preload("res://scenes/ui/cell.tscn")
const MAX_LEVEL_TINT: float = 20.0 # level 20+ = full tint

var engine: TetrisEngine
var level: int = 1

# 2D array [row][col] of Cell nodes representing the static grid
var _grid_cells: Array = []       
# Array of 4 Cell nodes for the active piece
var _piece_cells: Array[Cell] = [] 
# Array of 4 Cell nodes for the ghost piece
var _ghost_cells: Array[Cell] = [] 

func setup(tetris_engine: TetrisEngine) -> void:
	engine = tetris_engine
	_build_grid()
	# Build ghost cells first so they render behind the active piece
	_build_ghost_cells()  
	# Build piece cells second so they render in front
	_build_piece_cells()  
	_connect_signals()

## Instantiates one Cell scene per grid position.
## Positions each cell at Vector2(col * CELL_SIZE, row * CELL_SIZE).
## Stores in _grid_cells as a 2D array.
func _build_grid() -> void:
	# Get grid dimensions from the engine
	var width = engine.grid.width
	var height = engine.grid.height
	
	# Initialize the 2D array structure
	_grid_cells.resize(height)
	for r in range(height):
		_grid_cells[r] = []
		_grid_cells[r].resize(width)
		
		for c in range(width):
			# Instantiate the cell scene
			var cell = CellScene.instantiate()
			add_child(cell)
			
			# Position the cell based on grid coordinates
			cell.position = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			
			# Note: set_color_index(0) handles visibility, so no need to set visible = false here
			
			# Store in the 2D array
			_grid_cells[r][c] = cell


func _draw() -> void:
	var tint_ratio: float = clampf(level / MAX_LEVEL_TINT, 0.0, 1.0)
	var background_red: float = 0.05 + (tint_ratio * 0.15) 
	
	var background_color: Color = Color(background_red, 0.1, 0.18)
	draw_rect(
		Rect2(0, 0, engine.grid.width * CELL_SIZE, engine.grid.height * CELL_SIZE),
		background_color
	)


## Instantiates 4 Cell nodes for the active piece.
## Adds them as children. They are not positioned yet.
func _build_piece_cells() -> void:
	for i in range(4):
		var cell = CellScene.instantiate()
		add_child(cell)
		#print("piece cell added, child count: ", get_child_count())
		# No move_child needed; adding last ensures it renders on top of previously added nodes
		_piece_cells.append(cell)

## Instantiates 4 Cell nodes for the ghost piece.
## Sets reduced opacity to distinguish them visually.
func _build_ghost_cells() -> void:
	for i in range(4):
		var cell = CellScene.instantiate()
		add_child(cell)
		# Set reduced opacity for ghost effect
		cell.modulate.a = 0.35
		# No move_child needed
		_ghost_cells.append(cell)

## Connects engine signals to corresponding handler methods.
func _connect_signals() -> void:
	engine.piece_spawned.connect(_on_piece_spawned)
	engine.piece_moved.connect(_on_piece_updated)
	engine.piece_rotated.connect(_on_piece_updated)
	engine.piece_locked.connect(_on_piece_locked)
	engine.lines_cleared.connect(_on_lines_cleared)
	engine.game_over.connect(_on_game_over)
	engine.level_changed.connect(_on_level_changed)

## Handles piece updates (move/rotate).
## Updates position and color for active piece cells.
## Also refreshes ghost cells.
func _on_piece_updated(instance: TetrominoInstance) -> void:
	# Get the current cells for the active piece
	#print("updating piece cells, count: ", _piece_cells.size())
	var cells = instance.get_cells()
	#print("piece cells positions: ", cells)
	
	# Update active piece cells
	for i in range(_piece_cells.size()):
		if i < cells.size():
			var cell = _piece_cells[i]
			var pos = cells[i]
			
			# Position the cell
			cell.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
			
			# Set the color based on the piece's color index
			cell.set_color_index(instance.tetromino.color_index)
		else:
			# Hide extra cells if piece has fewer than 4 blocks
			_piece_cells[i].visible = false

	# Update ghost piece cells
	if engine.ghost_piece != null:
		var ghost_cells = engine.ghost_piece.get_cells()
		for i in range(_ghost_cells.size()):
			if i < ghost_cells.size():
				var cell = _ghost_cells[i]
				var pos = ghost_cells[i]
				
				# Position the ghost cell
				cell.position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
				
				# Set the color, same as active piece
				cell.set_color_index(engine.ghost_piece.tetromino.color_index)
			else:
				_ghost_cells[i].visible = false
	else:
		# Hide ghost cells if no ghost piece exists
		for cell in _ghost_cells:
			cell.visible = false

## Handles piece spawn.
## Same logic as _on_piece_updated.
func _on_piece_spawned(instance: TetrominoInstance) -> void:
	#print("piece spawned signal received: ", instance.tetromino.id)
	_on_piece_updated(instance)

## Handles piece lock.
## Hides all piece and ghost cells, then refreshes the grid.
func _on_piece_locked() -> void:
	# Hide active piece cells
	for cell in _piece_cells:
		cell.visible = false
		
	# Hide ghost piece cells
	for cell in _ghost_cells:
		cell.visible = false
		
	# Refresh the static grid to show the locked piece
	_refresh_grid()

## Refreshes the static grid.
## Loops every row and col, calls engine.grid.get_cell(col, row)
## and passes that value to the corresponding Cell's set_color_index().
func _refresh_grid() -> void:
	var width = engine.grid.width
	var height = engine.grid.height
	
	for r in range(height):
		for c in range(width):
			# Get the cell value from the engine's grid
			var color_index = engine.grid.get_cell(c, r)
			
			# Update the corresponding grid cell node
			if r < _grid_cells.size() and c < _grid_cells[r].size():
				_grid_cells[r][c].set_color_index(color_index)

## Handles lines cleared.
## Just calls _refresh_grid() since the grid data is already updated by the engine.
## Fixed type mismatch: signal emits Array[int]
func _on_lines_cleared(lines: Array[int]) -> void:
	_refresh_grid()
	

func _on_level_changed(new_level: int) -> void:
	level = new_level
	queue_redraw()


## Handles game over.
func _on_game_over() -> void:
	print("game over")
