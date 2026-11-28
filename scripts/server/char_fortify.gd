extends RefCounted
## شخصیت‌های هوشمند مستقل (مرحلهٔ ۲): دیوار دفاعی، برج‌های قلعه و تعمیر آن‌ها.
## هیچ حالت جدیدی ذخیره نمی‌شود: هر بار هدف از روی بلوک‌های واقعی جهان محاسبه می‌شود؛
## پس بعد از بارگذاری یا تخریب (مثلاً توسط مدیر) خودبه‌خود ادامه یا تعمیر می‌شود.
## بلوک‌ها از همان `place_block` بازیکن می‌گذرند: مالکیت، محدوده، تکیه‌گاه، نرخ و سنگِ واقعی.

const FWConst = preload("res://scripts/core/const.gd")

const WALL_H := 2
const TOWER_H := 4
const MARGIN := 2          # فاصلهٔ دیوار از خانه (بلوک)
const PER_STEP := 4        # حداکثر بلوک در هر گام ساخت
const REACH := 6.0
const STONE_GATHERS := 4
const WALL_BLOCK := "stone"


static func wants_towers(ai: Dictionary) -> bool:
	var t: Dictionary = ai["traits"]
	return float(t["ambition"]) >= 0.7 and float(t["aggression"]) >= 0.5


static func house_of(cs, acct: String) -> Dictionary:
	var best: Dictionary = {}
	for id in cs.buildings:
		var b: Dictionary = cs.buildings[id]
		if str(b["owner"]) == acct and str(b["type"]) == "house":
			if best.is_empty() or int(b["id"]) < int(best["id"]):
				best = b
	return best


## همهٔ بلوک‌های دلخواه (پایین به بالا). دروازه: دو بلوک جلوی در باز می‌ماند.
static func target_cells(cs, house: Dictionary, towers: bool) -> Array:
	var size: Array = FWConst.building_size("house")
	var x0: int = int(house["cx"]) * 2
	var z0: int = int(house["cz"]) * 2
	var lo := Vector2i(x0 - MARGIN - 1, z0 - MARGIN - 1)
	var hi := Vector2i(x0 + int(size[0]) * 2 + MARGIN, z0 + int(size[1]) * 2 + MARGIN)
	var gate_x: int = x0 + int(size[0])
	var columns: Dictionary = {}   # Vector2i -> ارتفاع
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			if x != lo.x and x != hi.x and z != lo.y and z != hi.y:
				continue
			if z == hi.y and (x == gate_x - 1 or x == gate_x):
				continue
			columns[Vector2i(x, z)] = WALL_H
	if towers:
		for cx in [lo.x, hi.x - 1]:
			for cz in [lo.y, hi.y - 1]:
				for ox in 2:
					for oz in 2:
						columns[Vector2i(cx + ox, cz + oz)] = TOWER_H
	var cells: Array = []
	for col in columns:
		var h: float = cs.world.height_at(float(col.x) + 0.5, float(col.y) + 0.5)
		if h < 0.2:
			continue   # روی آب دیوار نمی‌سازد
		var lv: int = maxi(0, int(floor(h)))
		for dy in int(columns[col]):
			cells.append(Vector3i(col.x, lv + dy, col.y))
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and (a.x < b.x or (a.x == b.x and a.z < b.z))))
	return cells


## بلوک‌های هنوز ساخته‌نشده‌ای که همین حالا مجاز و قابل ساخت‌اند. اول دیوار، بعد برج‌ها (برای تیپ‌های جاه‌طلب و جنگجو).
static func missing(cs, npc: Dictionary) -> Array:
	var house: Dictionary = house_of(cs, str(npc["acct"]))
	if house.is_empty():
		return []
	var role: String = cs.role_of(str(npc["acct"]))
	for towers in ([false, true] if wants_towers(npc["ai"]) else [false]):
		var out: Array = []
		for v in target_cells(cs, house, towers):
			if cs.blocks.has(v):
				continue
			if cs.check_block(role, v.x, v.y, v.z, WALL_BLOCK) == "":
				out.append(v)
		if not out.is_empty():
			return out
	return []


static func priority(ai: Dictionary) -> float:
	var t: Dictionary = ai["traits"]
	var p: float = 0.15 + 0.4 * float(t["caution"]) + 0.3 * float(t["aggression"]) + 0.15 * float(t["ambition"])
	return snappedf(p * pow(0.5, float(int(ai["fails"].get("fortify:wall", 0)))), 0.01)


## شخصیتی که هنوز دیوارش ناقص است، سنگش را نمی‌فروشد.
static func keeps_stone(cs, npc: Dictionary) -> bool:
	return not missing(cs, npc).is_empty()


static func stone_of(cs, npc: Dictionary) -> int:
	return int(cs.accounts[str(npc["acct"])]["inv"].get("stone", 0))


## برنامه: اگر سنگ کم است چند تخته‌سنگ واقعی را برمی‌دارد، سپس می‌سازد.
static func plan(cs, npc: Dictionary, gather_step: Callable) -> Array:
	var cells: Array = missing(cs, npc)
	if cells.is_empty():
		return []
	var steps: Array = []
	if not cs.creative and stone_of(cs, npc) < mini(cells.size(), 24):
		var pos := Vector2(float(npc["x"]), float(npc["z"]))
		var used := {}
		for i in STONE_GATHERS:
			var r: Dictionary = gather_step.call(cs, npc, pos, used)
			if r.is_empty():
				break
			used[r["key"]] = true
			steps.append({"t": "gather", "rx": r["rx"], "rz": r["rz"], "x": r["x"], "z": r["z"], "tool": r["tool"], "key": r["key"]})
			pos = Vector2(r["x"], r["z"])
		if steps.is_empty() and stone_of(cs, npc) == 0:
			return []   # نه سنگی دارد و نه سنگی پیدا می‌شود
	steps.append({"t": "wall"})
	return steps


## یک گام ساخت. خروجی: {"done": bool, "placed": int, "error": String}
static func build_step(cs, npc: Dictionary, dt: float, move: Callable) -> Dictionary:
	var ai: Dictionary = npc["ai"]
	var cells: Array = missing(cs, npc)
	if cells.is_empty():
		return {"done": true, "placed": 0, "error": ""}
	var v: Vector3i = cells[0]
	if not move.call(Vector2(float(v.x) + 0.5, float(v.z) + 0.5), REACH - 2.0):
		return {"done": false, "placed": 0, "error": ""}
	npc["state"] = "work"
	ai["w"] = float(ai["w"]) + dt
	if float(ai["w"]) < 0.8:
		return {"done": false, "placed": 0, "error": ""}
	ai["w"] = 0.0
	var placed := 0
	var last_err := ""
	var pos := Vector2(float(npc["x"]), float(npc["z"]))
	for c in cells:
		if placed >= PER_STEP:
			break
		if pos.distance_to(Vector2(float(c.x) + 0.5, float(c.z) + 0.5)) > REACH:
			continue
		var res: Dictionary = cs.place_block(str(npc["acct"]), 0, c.x, c.y, c.z, WALL_BLOCK, 0, false)
		if bool(res["ok"]):
			placed += 1
			cs.ai_events.append({"kind": "block", "x": c.x, "y": c.y, "z": c.z, "type": WALL_BLOCK, "color": 0})
		else:
			last_err = str(res["error"])
			if last_err == "no_items":
				break
	if placed > 0:
		return {"done": false, "placed": placed, "error": ""}
	return {"done": last_err == "no_items", "placed": 0, "error": last_err if last_err != "no_items" else ""}
