class_name Tetromino
extends Resource

@export var id: String          # "I", "T", "bomb", "wide_I" — anything
@export var color_index: int    # spritesheet row
@export var rotations: Array[PackedInt32Array]
@export var grid_size: int = 4  # 4×4 by default, but a 5×5 piece is valid
