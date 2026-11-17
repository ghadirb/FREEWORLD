extends RefCounted
## قوانین ساخت‌وساز مشترک: سرور برای تصمیم نهایی و کلاینت برای پیش‌نمایش استفاده می‌کند.

const FWConst = preload("res://scripts/core/const.gd")


static func cell_key(cx: int, cz: int) -> String:
	return "%d,%d" % [cx, cz]


static func footprint(type: String, cx: int, cz: int) -> Array:
	var size: Array = FWConst.building_size(type)
	var cells: Array = []
	for i in range(int(size[0])):
		for j in range(int(size[1])):
			cells.append(Vector2i(cx + i, cz + j))
	return cells


## خطا را به‌صورت کد برمی‌گرداند؛ رشتهٔ خالی یعنی مجاز.
static func check(world, occupied: Dictionary, type: String, cx: int, cz: int, role: String) -> String:
	if not FWConst.BUILDING_TYPES.has(type):
		return "unknown_type"
	var size: Array = FWConst.building_size(type)
	var w := int(size[0])
	var h := int(size[1])
	if cx < 0 or cz < 0 or cx + w > FWConst.CITY_CELLS or cz + h > FWConst.CITY_CELLS:
		return "out_of_bounds"
	for c in footprint(type, cx, cz):
		if occupied.has(cell_key(c.x, c.y)):
			return "occupied"
		if not FWConst.is_admin(role):
			if c.x >= FWConst.PLAZA_MIN and c.x <= FWConst.PLAZA_MAX and c.y >= FWConst.PLAZA_MIN and c.y <= FWConst.PLAZA_MAX:
				return "reserved"
	var lo := INF
	var hi := -INF
	for i in range(w + 1):
		for j in range(h + 1):
			var y: float = world.height_at((cx + i) * FWConst.CELL_SIZE, (cz + j) * FWConst.CELL_SIZE)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	if lo < 0.2:
		return "water"
	if hi - lo > 1.6:
		return "too_steep"
	return ""


## ارتفاع پایهٔ ساختمان (بالاترین نقطهٔ زیربنا).
static func base_height(world, type: String, cx: int, cz: int) -> float:
	var size: Array = FWConst.building_size(type)
	var hi := -INF
	for i in range(int(size[0]) + 1):
		for j in range(int(size[1]) + 1):
			hi = maxf(hi, world.height_at((cx + i) * FWConst.CELL_SIZE, (cz + j) * FWConst.CELL_SIZE))
	return hi
