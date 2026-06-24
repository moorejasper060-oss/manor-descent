extends Node2D
# Entry point. Registers input, builds the test level, spawns the player + camera.
# M1 milestone: validate the platformer controller (run / variable-jump / coyote /
# jump-buffer / ledge-grab / melee). Procedural gen + enemies come in later milestones.

const Player = preload("res://player.gd")
const Level = preload("res://level.gd")

func _ready() -> void:
	_register_inputs()
	RenderingServer.set_default_clear_color(Color(0.06, 0.05, 0.08))

	var level := Level.new()
	add_child(level)

	var player: CharacterBody2D = Player.new()
	player.position = level.spawn_point
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	player.add_child(cam)
	cam.make_current()

	_build_hud()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "MANOR DESCENT  —  M1: controller test\n" \
		+ "Move: A/D or ←/→     Jump: Space/W/↑ (hold = higher)\n" \
		+ "Attack: J/X     Ledge: fall into a wall edge; Jump to climb, Down to drop"
	label.position = Vector2(16, 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	layer.add_child(label)

func _register_inputs() -> void:
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_ensure_action("down", [KEY_S, KEY_DOWN])
	_ensure_action("attack", [KEY_J, KEY_X])

func _ensure_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
