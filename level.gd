extends Node2D
# A hand-built test level for the M1 controller. Just static collision blocks so we can
# feel out movement, jumps, and ledge-grabs. Real procedural room-template gen lands in M3.

var spawn_point := Vector2(120, 470)

func _ready() -> void:
	# ground floor
	_block(Vector2(-200, 600), Vector2(1700, 220), Color(0.12, 0.10, 0.13))
	# left + right boundary walls
	_block(Vector2(-60, -100), Vector2(60, 760), Color(0.16, 0.13, 0.16))
	_block(Vector2(1400, -100), Vector2(60, 760), Color(0.16, 0.13, 0.16))

	# ascending floating platforms (jump test)
	_block(Vector2(300, 480), Vector2(170, 26), Color(0.20, 0.15, 0.13))
	_block(Vector2(560, 380), Vector2(160, 26), Color(0.20, 0.15, 0.13))
	_block(Vector2(820, 300), Vector2(160, 26), Color(0.20, 0.15, 0.13))

	# a low step near spawn
	_block(Vector2(180, 540), Vector2(40, 60), Color(0.17, 0.13, 0.16))

	# a tall block to test ledge-grab: walk/fall into its left edge from above
	_block(Vector2(1080, 220), Vector2(120, 380), Color(0.18, 0.14, 0.18))

func _block(top_left: Vector2, size: Vector2, color: Color) -> void:
	var sb := StaticBody2D.new()
	sb.position = top_left + size / 2.0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([
		Vector2(-size.x / 2.0, -size.y / 2.0), Vector2(size.x / 2.0, -size.y / 2.0),
		Vector2(size.x / 2.0, size.y / 2.0), Vector2(-size.x / 2.0, size.y / 2.0)])
	vis.color = color
	sb.add_child(vis)
	add_child(sb)
