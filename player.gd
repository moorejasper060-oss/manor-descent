extends CharacterBody2D
# Manor Descent player controller (M1).
# Built entirely in code (no .tscn) so it can be validated head-less and screenshot-captured.
# Features: accel/friction run, variable-height jump, coyote time, jump buffering,
# a melee swing (the fireplace poker), and a basic ledge-grab + climb.

# ---- tuning knobs (px, px/s, px/s^2, seconds) ----
const HALF_W := 11.0
const HALF_H := 17.0

const RUN_SPEED := 230.0
const ACCEL := 2000.0
const AIR_ACCEL := 1500.0
const FRICTION := 2600.0
const AIR_FRICTION := 600.0

const GRAVITY := 1500.0
const MAX_FALL := 1000.0
const JUMP_VELOCITY := -520.0
const JUMP_CUT := 0.40            # upward velocity kept when jump released early
const COYOTE_TIME := 0.10         # grace to still jump after leaving a ledge
const JUMP_BUFFER := 0.10         # grace to register a jump pressed just before landing

const ATTACK_TIME := 0.18
const ATTACK_COOLDOWN := 0.10

const LEDGE_GRAB_ENABLED := true

# ---- state ----
var facing := 1
var _coyote := 0.0
var _buffer := 0.0
var _attack_t := 0.0
var _cooldown := 0.0
var _hanging := false
var _regrab := 0.0

# ---- code-built nodes ----
var _poker: Polygon2D
var _hitbox: Area2D
var _high_ray: RayCast2D
var _low_ray: RayCast2D

func _ready() -> void:
	# collision body
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HALF_W * 2.0, HALF_H * 2.0)
	col.shape = shape
	add_child(col)

	# visible silhouette (warm parchment so it reads on the dark manor backdrop)
	var body := Polygon2D.new()
	body.polygon = _rect_poly(HALF_W, HALF_H)
	body.color = Color(0.88, 0.82, 0.6)
	add_child(body)

	# the poker (melee weapon), hidden until a swing
	_poker = Polygon2D.new()
	_poker.polygon = PackedVector2Array([
		Vector2(HALF_W, -4), Vector2(HALF_W + 24, -4),
		Vector2(HALF_W + 24, 2), Vector2(HALF_W, 2)])
	_poker.color = Color(0.72, 0.74, 0.82)
	_poker.visible = false
	add_child(_poker)

	# melee hitbox (no enemies yet in M1 — wired up for later milestones)
	_hitbox = Area2D.new()
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	var hcol := CollisionShape2D.new()
	var hshape := RectangleShape2D.new()
	hshape.size = Vector2(30, 28)
	hcol.shape = hshape
	_hitbox.add_child(hcol)
	add_child(_hitbox)

	# ledge-detection rays: a wall at chest height but clear at the head = a grabbable ledge
	_high_ray = RayCast2D.new()
	_high_ray.position = Vector2(0, -HALF_H + 2)
	add_child(_high_ray)
	_low_ray = RayCast2D.new()
	_low_ray.position = Vector2(0, -2)
	add_child(_low_ray)

	_update_facing_nodes()

func _rect_poly(hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_regrab = maxf(0.0, _regrab - delta)
	if _attack_t > 0.0:
		_attack_t -= delta
		if _attack_t <= 0.0:
			_end_attack()

	var input_x := Input.get_axis("move_left", "move_right")
	if input_x > 0.0:
		facing = 1
	elif input_x < 0.0:
		facing = -1
	_update_facing_nodes()

	if _hanging:
		_process_hang(input_x)
		return

	# --- timers ---
	if is_on_floor():
		_coyote = COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer = maxf(0.0, _buffer - delta)

	# --- horizontal movement ---
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var fric := FRICTION if is_on_floor() else AIR_FRICTION
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * RUN_SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	# --- gravity ---
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	# --- jump (buffered + coyote) ---
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
	# variable height: releasing early cuts the rise
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	# --- attack ---
	if Input.is_action_just_pressed("attack") and _cooldown <= 0.0 and _attack_t <= 0.0:
		_start_attack()

	move_and_slide()

	# --- ledge grab (after the move so floor/air state is settled) ---
	if LEDGE_GRAB_ENABLED and not is_on_floor() and velocity.y > 0.0 and _regrab <= 0.0:
		var toward := (input_x > 0.0 and facing == 1) or (input_x < 0.0 and facing == -1)
		if toward and _low_ray.is_colliding() and not _high_ray.is_colliding():
			_grab_ledge()

func _grab_ledge() -> void:
	_hanging = true
	velocity = Vector2.ZERO
	var p := _low_ray.get_collision_point()
	position.x = p.x - facing * (HALF_W + 1.0)

func _process_hang(input_x: float) -> void:
	velocity = Vector2.ZERO
	if Input.is_action_just_pressed("jump"):
		# climb up onto the ledge
		_hanging = false
		_regrab = 0.2
		velocity.y = JUMP_VELOCITY
		velocity.x = facing * RUN_SPEED * 0.6
		position.y -= 6.0
		move_and_slide()
		return
	var away := (input_x > 0.0 and facing == -1) or (input_x < 0.0 and facing == 1)
	if Input.is_action_pressed("down") or away or not _low_ray.is_colliding():
		_hanging = false
		_regrab = 0.2

func _start_attack() -> void:
	_attack_t = ATTACK_TIME
	_cooldown = ATTACK_TIME + ATTACK_COOLDOWN
	_poker.visible = true
	_hitbox.monitoring = true

func _end_attack() -> void:
	_poker.visible = false
	_hitbox.monitoring = false

func _update_facing_nodes() -> void:
	var reach := facing * (HALF_W + 6.0)
	_high_ray.target_position = Vector2(reach, 0)
	_low_ray.target_position = Vector2(reach, 0)
	_hitbox.position = Vector2(facing * 18.0, -2.0)
	_poker.scale.x = float(facing)
