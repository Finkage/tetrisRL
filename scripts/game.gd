extends Node

var engine: TetrisEngine
@onready var renderer: GridRenderer = $GridRenderer



func _ready() -> void:
	engine = TetrisEngine.new()
	renderer.position = Vector2(40, 44)  # centered horizontally, room for HUD at top
	renderer.setup(engine)
	engine.start()

func _process(delta: float) -> void:
	engine.tick(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		engine.move(-1)
	if event.is_action_pressed("move_right"):
		engine.move(1)
	if event.is_action_pressed("rotate_cw"):
		engine.rotate(1)
	if event.is_action_pressed("soft_drop"):
		engine.soft_drop()
	if event.is_action_pressed("hard_drop"):
		engine.hard_drop()
	if event.is_action_pressed("hold"):
		engine.hold()
