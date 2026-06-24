extends Node2D
# Manor Descent — game orchestrator.
# Generates a manor floor, spawns the (persistent) player + camera, populates monsters/gems/
# exit, runs combat + pickups + the descend loop, and the candle-lit atmosphere + HUD.

const Player = preload("res://player.gd")
const Monster = preload("res://monster.gd")
const Level = preload("res://level_gen.gd")

var depth := 1
var gems_collected := 0
var state := "playing"  # "playing" | "dead"
var _spawn_cd := 0.0

var _level: Node2D
var _entities: Node2D
var _player: CharacterBody2D
var _cam: Camera2D
var _tile_tex: Texture2D

var _monsters: Array = []
var _gems: Array = []
var _door: Sprite2D

# HUD
var _heart_rects: Array = []
var _heart_full: Texture2D
var _heart_empty: Texture2D
var _info: Label
var _gameover: Label

func _ready() -> void:
	_register_inputs()
	RenderingServer.set_default_clear_color(Color(0.05, 0.045, 0.075))
	_tile_tex = _tex("res://assets/tilemap_packed.png")

	var cmod := CanvasModulate.new()
	cmod.color = Color(0.5, 0.48, 0.64)  # haunted-manor ambient darkness
	add_child(cmod)

	_level = Level.new()
	add_child(_level)
	_entities = Node2D.new()
	add_child(_entities)

	_build_hud()
	new_game()

# ---------------------------------------------------------------- helpers
func _tex(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img)

func _icon(col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = _tile_tex
	a.region = Rect2(col * 18, row * 18, 18, 18)
	return a

func _make_icon_node(col: int, row: int, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture = _icon(col, row)
	s.position = pos
	return s

# ---------------------------------------------------------------- flow
func new_game() -> void:
	depth = 1
	gems_collected = 0
	state = "playing"
	_ensure_player()
	_player.reset_full()
	_gameover.visible = false
	start_level()

func _ensure_player() -> void:
	if _player != null:
		return
	_player = Player.new()
	add_child(_player)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(3, 3)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	_player.add_child(_cam)
	_cam.make_current()

func start_level() -> void:
	_level.generate(depth)
	for c in _entities.get_children():
		c.queue_free()
	_monsters.clear()
	_gems.clear()
	_door = null

	_ensure_player()
	_player.global_position = _level.spawn_point
	_player.velocity = Vector2.ZERO

	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = _level.W * _level.TILE
	_cam.limit_bottom = _level.H * _level.TILE
	_cam.reset_smoothing()

	_door = _make_icon_node(9, 7, _level.exit_pos)
	_door.z_index = 2
	_entities.add_child(_door)

	for gp in _level.gem_positions:
		var g := _make_icon_node(7, 3, gp)
		g.z_index = 3
		_entities.add_child(g)
		_gems.append(g)

	for ms in _level.monster_spawns:
		var m = Monster.new()
		m.type = ms["type"]
		m.player = _player
		m.position = ms["pos"]
		_entities.add_child(m)
		_monsters.append(m)

	_spawn_cd = 0.5
	_update_hud()

# ---------------------------------------------------------------- loop
func _physics_process(delta: float) -> void:
	if state == "dead":
		if Input.is_action_just_pressed("restart"):
			new_game()
		return

	_spawn_cd = maxf(0.0, _spawn_cd - delta)

	# melee kills
	if _player.is_attacking():
		for m in _monsters:
			if is_instance_valid(m) and m.alive:
				var rel: Vector2 = m.global_position - _player.global_position
				if absf(rel.y) < 15.0 and rel.x * _player.facing >= -4.0 and absf(rel.x) < 28.0:
					m.die()

	# contact damage
	for m in _monsters:
		if is_instance_valid(m) and m.alive:
			if m.global_position.distance_to(_player.global_position) < 13.0:
				_player.take_damage(1, m.global_position)

	# gem pickups
	for g in _gems:
		if is_instance_valid(g) and g.visible:
			if g.global_position.distance_to(_player.global_position) < 12.0:
				g.queue_free()
				gems_collected += 1

	# descend through the exit door
	if _spawn_cd <= 0.0 and _door != null and is_instance_valid(_door):
		if _player.global_position.distance_to(_door.global_position) < 13.0:
			depth += 1
			start_level()
			return

	if _player.dead and state == "playing":
		state = "dead"
		_gameover.visible = true

	_update_hud()

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	_heart_full = _icon(2, 2)
	_heart_empty = _icon(4, 2)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var hb := HBoxContainer.new()
	hb.position = Vector2(12, 10)
	hb.add_theme_constant_override("separation", 4)
	layer.add_child(hb)
	for i in range(Player.MAX_HEARTS):
		var r := TextureRect.new()
		r.texture = _heart_full
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.custom_minimum_size = Vector2(40, 40)
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hb.add_child(r)
		_heart_rects.append(r)

	_info = Label.new()
	_info.position = Vector2(12, 56)
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_color", Color(0.9, 0.88, 0.78))
	layer.add_child(_info)

	_gameover = Label.new()
	_gameover.text = "YOU PERISHED\nPress R to descend anew"
	_gameover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gameover.anchors_preset = Control.PRESET_CENTER
	_gameover.position = Vector2(440, 300)
	_gameover.add_theme_font_size_override("font_size", 40)
	_gameover.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
	_gameover.visible = false
	layer.add_child(_gameover)

func _update_hud() -> void:
	for i in range(_heart_rects.size()):
		_heart_rects[i].texture = _heart_full if i < _player.hearts else _heart_empty
	_info.text = "DEPTH %d    GEMS %d" % [depth, gems_collected]

# ---------------------------------------------------------------- input
func _register_inputs() -> void:
	_ensure_action("move_left", [KEY_A, KEY_LEFT])
	_ensure_action("move_right", [KEY_D, KEY_RIGHT])
	_ensure_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_ensure_action("down", [KEY_S, KEY_DOWN])
	_ensure_action("attack", [KEY_J, KEY_X])
	_ensure_action("restart", [KEY_R])

func _ensure_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
