extends CharacterBody2D
# Manor Descent player. Tuned for the 18px tile world (camera zoom ~3).
# Uses the Kenney explorer sprite, collides with the generated TileMapLayer, and exposes
# combat hooks (is_attacking / take_damage) that main.gd resolves against monsters.

const HALF_W := 5.0
const HALF_H := 9.0

const RUN_SPEED := 116.0
const ACCEL := 900.0
const AIR_ACCEL := 700.0
const FRICTION := 1100.0
const AIR_FRICTION := 320.0

const GRAVITY := 900.0
const MAX_FALL := 520.0
const JUMP_VELOCITY := -302.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.10

const ATTACK_TIME := 0.18
const ATTACK_COOLDOWN := 0.12
const MAX_HEARTS := 4

var facing := 1
var hearts := MAX_HEARTS
var dead := false

var _coyote := 0.0
var _buffer := 0.0
var _attack_t := 0.0
var _cooldown := 0.0
var _iframes := 0.0
var _t := 0.0
var _anim_t := 0.0
var _walk_frame := false

var _sprite: Sprite2D
var _poker: Polygon2D
var _idle: Texture2D
var _walk: Texture2D

func _ready() -> void:
	z_index = 10
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_W * 2.0, HALF_H * 2.0)
	col.shape = shape
	add_child(col)

	var ctex := _tex("res://assets/tilemap-characters_packed.png")
	_idle = _atlas(ctex, 0, 1)
	_walk = _atlas(ctex, 1, 1)
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = _idle
	_sprite.position = Vector2(0, -3)
	add_child(_sprite)

	# fireplace poker (melee), hidden until a swing
	_poker = Polygon2D.new()
	_poker.polygon = PackedVector2Array([
		Vector2(HALF_W, -3), Vector2(HALF_W + 13, -3),
		Vector2(HALF_W + 13, 1), Vector2(HALF_W, 1)])
	_poker.color = Color(0.78, 0.79, 0.86)
	_poker.visible = false
	add_child(_poker)

	# warm lantern light
	var light := PointLight2D.new()
	light.texture = _make_light_tex(256)
	light.color = Color(1.0, 0.83, 0.52)
	light.energy = 1.35
	light.texture_scale = 1.15
	add_child(light)

func _tex(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img)

func _atlas(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col * 24, row * 24, 24, 24)
	return a

func _make_light_tex(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func reset_full() -> void:
	hearts = MAX_HEARTS
	dead = false
	_iframes = 0.0
	velocity = Vector2.ZERO
	if _sprite:
		_sprite.rotation = 0.0
		_sprite.modulate.a = 1.0

func is_attacking() -> bool:
	return _attack_t > 0.0

func take_damage(amount: int, from_pos: Vector2) -> void:
	if _iframes > 0.0 or dead:
		return
	hearts -= amount
	_iframes = 1.1
	var dir := signf(global_position.x - from_pos.x)
	if dir == 0.0:
		dir = -float(facing)
	velocity.x = dir * 190.0
	velocity.y = -160.0
	if hearts <= 0:
		hearts = 0
		dead = true

func _physics_process(delta: float) -> void:
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	_iframes = maxf(0.0, _iframes - delta)
	if _attack_t > 0.0:
		_attack_t -= delta
		if _attack_t <= 0.0:
			_poker.visible = false

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		move_and_slide()
		_sprite.rotation = lerp_angle(_sprite.rotation, PI * 0.5, 0.1)
		return

	var input_x := Input.get_axis("move_left", "move_right")
	if input_x > 0.0:
		facing = 1
	elif input_x < 0.0:
		facing = -1

	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(0.0, _buffer - delta)

	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var fric := FRICTION if is_on_floor() else AIR_FRICTION
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * RUN_SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	if Input.is_action_just_pressed("attack") and _cooldown <= 0.0 and _attack_t <= 0.0:
		_attack_t = ATTACK_TIME
		_cooldown = ATTACK_TIME + ATTACK_COOLDOWN
		_poker.visible = true

	move_and_slide()
	_animate(input_x, delta)

func _animate(input_x: float, delta: float) -> void:
	_sprite.flip_h = facing < 0
	_poker.scale.x = float(facing)
	# 2-frame walk cycle when moving on the ground
	if is_on_floor() and absf(velocity.x) > 12.0:
		_anim_t += delta
		if _anim_t >= 0.12:
			_anim_t = 0.0
			_walk_frame = not _walk_frame
		_sprite.texture = _walk if _walk_frame else _idle
	elif not is_on_floor():
		_sprite.texture = _walk
	else:
		_sprite.texture = _idle
	# i-frame blink
	if _iframes > 0.0:
		_sprite.modulate.a = 0.35 if int(_t * 20.0) % 2 == 0 else 1.0
	else:
		_sprite.modulate.a = 1.0
