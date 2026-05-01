class_name Cell
extends Sprite2D

const TILE_SIZE = 8
const TILE_COLUMN = 2  # 0-3, pick which style column you want

func _ready() -> void:
	pass

func set_color_index(index: int) -> void:
	#print("set_color_index called: ", index, " texture: ", texture)
	if index <= 0:
		visible = false
		return
	visible = true
	region_rect = Rect2(
		TILE_COLUMN * TILE_SIZE,       # x: which style column
		(index - 1) * TILE_SIZE,       # y: which color row
		TILE_SIZE,                      # width
		TILE_SIZE                       # height
	)
