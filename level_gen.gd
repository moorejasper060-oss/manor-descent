extends Node2D
# Procedural manor-floor generator (the Spelunky-style backbone).
#
# Model: the level is a grid of TILE-sized cells, divided into R_ROWS horizontal "bands"
# (each band = one floor of the manor). Every band has a solid floor spanning its width
# with ONE drop-hole carved through it, and the holes are placed along a snaking path from
# the entrance (top) to the exit (bottom). Because each band's floor is continuous apart
# from small jumpable pits, you can always walk/jump to the next hole and drop down -> the
# descent is guaranteed solvable. Floating platforms + treasure + monsters add texture.
#
# Built in code (no .tscn), loads the Kenney atlas via Image.load (no import dependency),
# and builds the TileSet (with per-tile collision) at runtime.

const TILE := 18
const RW := 10          # room/band width in tiles
const RH := 8           # band height in tiles
const R_COLS := 6
const R_ROWS := 5

const SOLID_COORD := Vector2i(4, 0)
const SOLID_ALT := Vector2i(5, 0)

var W := R_COLS * RW    # level width  (tiles)
var H := R_ROWS * RH    # level height (tiles)

# generation outputs (read by main.gd)
var grid: Array = []                 # grid[y][x]: 0 air, 1 solid
var spawn_point := Vector2.ZERO
var exit_pos := Vector2.ZERO
var gem_positions: Array = []        # Array[Vector2]
var monster_spawns: Array = []       # Array[Dictionary] {pos:Vector2, type:String}

var _layer: TileMapLayer
var _atlas_id := 0

func _ready() -> void:
	_build_tileset()

func _tex(path: String) -> Texture2D:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img)

func _build_tileset() -> void:
	var tex := _tex("res://assets/tilemap_packed.png")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	_atlas_id = ts.add_source(src)
	var square := PackedVector2Array([
		Vector2(-9, -9), Vector2(9, -9), Vector2(9, 9), Vector2(-9, 9)])
	for coord in [SOLID_COORD, SOLID_ALT]:
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
	_layer = TileMapLayer.new()
	_layer.tile_set = ts
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.modulate = Color(0.62, 0.64, 0.82)  # tint warm dirt -> cold manor stone
	add_child(_layer)

func tile_center(tx: int, ty: int) -> Vector2:
	return Vector2(tx * TILE + TILE * 0.5, ty * TILE + TILE * 0.5)

func generate(depth: int) -> void:
	# --- blank grid ---
	grid = []
	for y in range(H):
		var row: Array = []
		for x in range(W):
			row.append(0)
		grid.append(row)

	# --- boundary: 2-thick side walls + ceiling ---
	for y in range(H):
		grid[y][0] = 1
		grid[y][1] = 1
		grid[y][W - 2] = 1
		grid[y][W - 1] = 1
	for x in range(W):
		grid[0][x] = 1

	# --- bands: floor + snaking drop-holes + platforms ---
	var entrance_col := randi_range(4, W - 5)
	var cur := entrance_col
	var drop_cols: Array = []
	for b in range(R_ROWS):
		var floor_y: int = (b + 1) * RH - 1
		for x in range(2, W - 2):
			grid[floor_y][x] = 1
		var dcol := cur
		if b < R_ROWS - 1:
			dcol = clampi(cur + randi_range(-14, 14), 4, W - 5)
			for hx in range(dcol - 1, dcol + 2):
				grid[floor_y][clampi(hx, 2, W - 3)] = 0
		drop_cols.append(dcol)
		# floating platforms inside the band (footing + treasure perches)
		for i in range(randi_range(2, 4)):
			var py: int = b * RH + randi_range(2, RH - 3)
			var px := randi_range(3, W - 9)
			for k in range(randi_range(3, 6)):
				grid[py][clampi(px + k, 2, W - 3)] = 1
		cur = dcol

	# --- spawn pocket (band 0) ---
	var sfloor: int = RH - 1
	for yy in range(sfloor - 3, sfloor):
		for xx in range(entrance_col - 1, entrance_col + 2):
			grid[clampi(yy, 1, H - 1)][clampi(xx, 2, W - 3)] = 0
	spawn_point = tile_center(entrance_col, sfloor - 1)

	# --- exit door on the bottom floor ---
	var exit_col := clampi(cur, 3, W - 4)
	exit_pos = tile_center(exit_col, H - 2)

	# --- pick standable cells for gems + monsters ---
	var standable: Array = []
	for y in range(2, H - 1):
		for x in range(3, W - 3):
			if grid[y][x] == 0 and grid[y + 1][x] == 1 and grid[y - 1][x] == 0:
				standable.append(Vector2i(x, y))
	standable.shuffle()

	gem_positions = []
	monster_spawns = []
	var types := ["crawler", "bat", "ghost", "crawler", "bat", "ghost"]
	var gi := 0
	var mi := 0
	for cell in standable:
		var c: Vector2i = cell
		# keep clear of spawn + exit
		if Vector2(c).distance_to(Vector2(entrance_col, sfloor)) < 7.0:
			continue
		if Vector2(c).distance_to(Vector2(exit_col, H - 2)) < 4.0:
			continue
		if gi < 7:
			gem_positions.append(tile_center(c.x, c.y))
			gi += 1
		elif mi < 5 + depth:
			monster_spawns.append({"pos": tile_center(c.x, c.y), "type": types[mi % types.size()]})
			mi += 1
		else:
			break

	_paint()

func _paint() -> void:
	_layer.clear()
	for y in range(H):
		for x in range(W):
			if grid[y][x] == 1:
				var coord := SOLID_COORD
				if randf() < 0.18:
					coord = SOLID_ALT
				_layer.set_cell(Vector2i(x, y), _atlas_id, coord)
