extends RefCounted
## مسیریابی NPC روی شبکهٔ سلولی شهر (A*). فقط روی سرور اجرا می‌شود.
## سلول‌های آب و ساختمان‌های مانع، بسته‌اند؛ جاده و چاه آزادند.
## شبکه فقط وقتی دوباره ساخته می‌شود که ساختمانی اضافه/حذف شده باشد (cs.nav_version).

const FWConst = preload("res://scripts/core/const.gd")

var _cs
var _grid: AStarGrid2D = null
var _built_version: int = -1
var _terrain_ok: PackedByteArray = PackedByteArray()


func _init(cs) -> void:
	_cs = cs


func _terrain_walkable(cx: int, cz: int) -> bool:
	if _terrain_ok.is_empty():
		_terrain_ok.resize(FWConst.CITY_CELLS * FWConst.CITY_CELLS)
		for i in range(FWConst.CITY_CELLS):
			for j in range(FWConst.CITY_CELLS):
				var x := (float(i) + 0.5) * FWConst.CELL_SIZE
				var z := (float(j) + 0.5) * FWConst.CELL_SIZE
				_terrain_ok[i * FWConst.CITY_CELLS + j] = 1 if _cs.world.height_at(x, z) >= -0.3 else 0
	return _terrain_ok[cx * FWConst.CITY_CELLS + cz] == 1


func _ensure_grid() -> void:
	if _grid != null and _built_version == _cs.nav_version:
		return
	var n: int = FWConst.CITY_CELLS
	if _grid == null:
		_grid = AStarGrid2D.new()
		_grid.region = Rect2i(0, 0, n, n)
		_grid.cell_size = Vector2(FWConst.CELL_SIZE, FWConst.CELL_SIZE)
		_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_grid.update()
	for i in range(n):
		for j in range(n):
			_grid.set_point_solid(Vector2i(i, j), not _cell_free(i, j))
	_built_version = _cs.nav_version


func _cell_free(cx: int, cz: int) -> bool:
	if not _terrain_walkable(cx, cz):
		return false
	var key := "%d,%d" % [cx, cz]
	if _cs.walled.has(key):
		return false
	if _cs.occupied.has(key):
		var t: String = _cs.buildings[_cs.occupied[key]]["type"]
		return t == "road" or t == "well"
	return true


static func cell_of(p: Vector2) -> Vector2i:
	var n: int = FWConst.CITY_CELLS
	return Vector2i(
		clampi(int(floor(p.x / FWConst.CELL_SIZE)), 0, n - 1),
		clampi(int(floor(p.y / FWConst.CELL_SIZE)), 0, n - 1))


static func center_of(c: Vector2i) -> Vector2:
	return Vector2((float(c.x) + 0.5) * FWConst.CELL_SIZE, (float(c.y) + 0.5) * FWConst.CELL_SIZE)


## نزدیک‌ترین سلول آزاد به c (برای وقتی که مقصد یا مبدأ روی مانع افتاده)؛ (-1,-1) اگر پیدا نشد.
func nearest_free(c: Vector2i, max_radius: int = 6) -> Vector2i:
	_ensure_grid()
	if not _grid.is_point_solid(c):
		return c
	var n: int = FWConst.CITY_CELLS
	for r in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var q := Vector2i(c.x + dx, c.y + dz)
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or _grid.is_point_solid(q):
					continue
				var d := float(dx * dx + dz * dz)
				if d < best_d:
					best_d = d
					best = q
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## مسیر از from تا to به‌صورت فهرست نقاط جهانی (بدون نقطهٔ شروع، با نقطهٔ دقیق مقصد در انتها).
## اگر هیچ مسیری وجود نداشته باشد null برمی‌گرداند (آرایهٔ خالی یعنی «همین‌جا رسیده‌ای»).
func find_path(from: Vector2, to: Vector2):
	_ensure_grid()
	var a := nearest_free(cell_of(from))
	var b := nearest_free(cell_of(to))
	if a.x < 0 or b.x < 0:
		return null
	var ids: Array[Vector2i] = _grid.get_id_path(a, b)
	if ids.is_empty():
		return null
	var pts: Array = []
	for i in range(1, ids.size()):
		pts.append(center_of(ids[i]))
	# مقصد دقیق فقط وقتی آزاد است که در همان سلول مقصد آزاد باشد.
	if cell_of(to) == b:
		pts.append(to)
	return pts
