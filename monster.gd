extends CharacterBody2D
# Manor monsters. Three behaviours sharing one script; set `type` + `player` before add_child.
#  - crawler: walks the floors, turns at walls and ledges (gravity, collides with tiles)
#  - bat:     flies straight at the player with a sine bob (ignores terrain)
#  - ghost:   drifts slowly toward the player THROUGH walls, translucent
# main.gd resolves combat: player melee -> die(); contact -> player.take_damage().

var type := "crawler"
var player: Node2D
var alive := true

const GRAV := 900.0
const SPEED := {"crawler": 50.0, "bat": 48.0, "ghost": 34.0}

var _dir := 1
var _t := 0.0
var _sprite: Sprite2D
var _frames: Array = []
var _wall: RayCast2D
var _ledge: RayCast2D

func _ready() -> void:
	z_index = 5
	_t = randf() * TAU
	_dir = 1 if randf() < 0.5 else -1

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(13, 14)
	col.shape = shape
	add_child(col)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	var ctex := _tex("res://assets/tilemap-characters_packed.png")
	match type:
		"crawler":
			_frames = [_atlas(ctex, 0, 0), _atlas(ctex, 1, 0)]
			_sprite.texture = _frames[0]
			_sprite.modulate = Color(0.55, 0.8, 0.45)
			collision_layer = 0
			collision_mask = 1
			_wall = RayCast2D.new()
			add_child(_wall)
			_ledge = RayCast2D.new()
			add_child(_ledge)
		"bat":
			_sprite.texture = _atlas(ctex, 6, 2)
			_sprite.modulate = Color(0.42, 0.36, 0.55)
			collision_layer = 0
			collision_mask = 0
		"ghost":
			_sprite.texture = _atlas(ctex, 0, 1)
			_sprite.modulate = Color(0.85, 0.92, 1.0, 0.5)
			collision_layer = 0
			collision_mask = 0

func _tex(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img)

func _atlas(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col * 24, row * 24, 24, 24)
	return a

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	match type:
		"crawler":
			_wall.target_position = Vector2(_dir * 11.0, 0)
			_ledge.target_position = Vector2(_dir * 9.0, 15.0)
			_wall.force_raycast_update()
			_ledge.force_raycast_update()
			if _wall.is_colliding() or not _ledge.is_colliding():
				_dir = -_dir
			velocity.x = _dir * SPEED["crawler"]
			velocity.y = minf(velocity.y + GRAV * delta, 600.0)
			move_and_slide()
			_sprite.flip_h = _dir < 0
			_sprite.texture = _frames[int(_t * 6.0) % 2]
		"bat":
			if is_instance_valid(player):
				var to := (player.global_position - global_position).normalized()
				velocity = to * SPEED["bat"]
				velocity.y += sin(_t * 7.0) * 34.0
				global_position += velocity * delta
				_sprite.flip_h = velocity.x < 0
		"ghost":
			if is_instance_valid(player):
				var to := (player.global_position - global_position).normalized()
				global_position += to * SPEED["ghost"] * delta
				_sprite.flip_h = player.global_position.x < global_position.x
			_sprite.position.y = sin(_t * 2.0) * 2.0

func die() -> void:
	if not alive:
		return
	alive = false
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.1, 0.1), 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
