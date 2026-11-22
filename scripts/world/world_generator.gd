extends RefCounted
## تولید قطعی (Deterministic) زمین از روی Seed.
## یک Seed یکسان همیشه ارتفاع و زیست‌بوم یکسان می‌دهد.

const FWConst = preload("res://scripts/core/const.gd")

var seed_value: int
var _base := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _lake := FastNoiseLite.new()
var _river := FastNoiseLite.new()


func _init(s: int = 12345) -> void:
	seed_value = s
	_base.seed = s
	_base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base.frequency = 0.006
	_base.fractal_octaves = 3
	_detail.seed = s + 101
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.04
	_moist.seed = s + 202
	_moist.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moist.frequency = 0.01
	_lake.seed = s + 303
	_lake.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_lake.frequency = 0.008
	_river.seed = s + 404
	_river.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_river.frequency = 0.0045


## لایهٔ تغییرات ارتفاع (پروتکل ۱۶): کلید = رأس شبکهٔ ۲ متری (ix, iz)، مقدار = جابه‌جایی به واحد ۱/۸ متر.
## زمین پایه همچنان فقط از Seed می‌آید؛ تنها این تفاوت‌ها ذخیره و همگام می‌شوند.
var edits: Dictionary = {}


static func edit_key(ix: int, iz: int) -> String:
	return "%d,%d" % [ix, iz]


func edit_units(ix: int, iz: int) -> int:
	return int(edits.get(edit_key(ix, iz), 0))


## مقدار جدید یک رأس را می‌گذارد (۰ = حذف تغییر). مقدار در بازهٔ مجاز مدیر بریده می‌شود (محدودیت بازیکن عادی در apply_terraform).
func set_edit(ix: int, iz: int, units: int) -> void:
	var u := clampi(units, FWConst.TERRAIN_ADMIN_MIN_UNITS, FWConst.TERRAIN_ADMIN_MAX_UNITS)
	if u == 0:
		edits.erase(edit_key(ix, iz))
	else:
		edits[edit_key(ix, iz)] = u


func height_at(x: float, z: float) -> float:
	var h := base_height_at(x, z)
	if edits.is_empty():
		return h
	var st := FWConst.TERRAIN_EDIT_STEP
	var fx := x / st
	var fz := z / st
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	var tx := fx - float(ix)
	var tz := fz - float(iz)
	var d00 := edit_units(ix, iz)
	var d10 := edit_units(ix + 1, iz)
	var d01 := edit_units(ix, iz + 1)
	var d11 := edit_units(ix + 1, iz + 1)
	if d00 == 0 and d10 == 0 and d01 == 0 and d11 == 0:
		return h
	var top := lerpf(float(d00), float(d10), tx)
	var bot := lerpf(float(d01), float(d11), tx)
	return h + lerpf(top, bot, tz) * FWConst.TERRAIN_UNIT


func base_height_at(x: float, z: float) -> float:
	var half := FWConst.CITY_SIZE * 0.5
	var dist := Vector2(x, z).distance_to(Vector2(half, half))
	var outside := smoothstep(95.0, 220.0, dist)
	var d := _detail.get_noise_2d(x, z)
	var h := 2.0 + d * 0.8
	h += _base.get_noise_2d(x, z) * 28.0 * outside + d * 3.0 * outside
	var lake := maxf(_lake.get_noise_2d(x, z) - 0.35, 0.0) * 40.0 * smoothstep(90.0, 140.0, dist)
	h -= lake
	var rw := river_weight(x, z)
	if rw > 0.0:
		# کانال رودخانه: کف زیر سطح دریا؛ در ارتفاع‌های بلند کم‌رنگ می‌شود تا دره‌های بی‌رحم نسازد.
		h = lerpf(h, -1.4, rw * (1.0 - smoothstep(7.0, 15.0, h)))
	return h


## وزن رودخانه در [0,1]: ۱ در محور کانال. فقط بیرون از شهر؛ قطعی از Seed.
func river_weight(x: float, z: float) -> float:
	var half := FWConst.CITY_SIZE * 0.5
	var dist := Vector2(x, z).distance_to(Vector2(half, half))
	if dist < FWConst.RIVER_MIN_DIST:
		return 0.0
	var edge := 1.0 - smoothstep(0.0, FWConst.RIVER_WIDTH, absf(_river.get_noise_2d(x, z)))
	return edge * smoothstep(FWConst.RIVER_MIN_DIST, FWConst.RIVER_MIN_DIST + 25.0, dist)


func moisture_at(x: float, z: float) -> float:
	return _moist.get_noise_2d(x, z)


## زیست‌بوم از روی ارتفاع و رطوبت از پیش محاسبه‌شده (برای تولید سریع چانک).
func biome_from(h: float, moisture: float) -> String:
	if h < FWConst.SEA_LEVEL:
		return "water"
	if h < 0.9:
		return "beach"
	if h > 14.0:
		return "mountain"
	if moisture > 0.15:
		return "forest"
	return "plain"


func biome_at(x: float, z: float) -> String:
	return biome_from(height_at(x, z), moisture_at(x, z))


func is_outside_city(x: float, z: float) -> bool:
	var half := FWConst.CITY_SIZE * 0.5
	return Vector2(x, z).distance_to(Vector2(half, half)) > 100.0


## هش صحیح قطعی (مستقل از پلتفرم) در بازهٔ [0,1).
func _h01(rx: int, rz: int, salt: int) -> float:
	var v: int = (rx * 73856093) ^ (rz * 19349663) ^ (salt * 83492791) ^ (seed_value * 2654435761)
	v = (v ^ (v >> 13)) * 1274126177
	v = (v ^ (v >> 16)) & 0x7fffffff
	return float(v % 100000) / 100000.0


## گرهٔ منبع قابل برداشت (درخت، سنگ، خاک رس) در خانهٔ ۴×۴ متری (rx, rz). فقط بیرون از شهر.
## خروجی خالی = چیزی نیست. کاملاً قطعی؛ سرور و کلاینت یک نتیجه می‌گیرند.
func resource_in_cell(rx: int, rz: int) -> Dictionary:
	var cs := FWConst.RESOURCE_CELL
	var x := (float(rx) + 0.15 + _h01(rx, rz, 1) * 0.7) * cs
	var z := (float(rz) + 0.15 + _h01(rx, rz, 2) * 0.7) * cs
	if not is_outside_city(x, z):
		return {}
	if near_village(x, z, FWConst.VILLAGE_RADIUS - 1.0):
		return {}
	var h := height_at(x, z)
	if h < 0.2:
		return {}
	var biome := biome_from(h, moisture_at(x, z))
	var roll := _h01(rx, rz, 3)
	var kind := ""
	match biome:
		"forest":
			if roll < 0.30:
				kind = "tree"
			elif roll < 0.33:
				kind = "rock"
		"plain":
			if roll < 0.05:
				kind = "tree"
			elif roll < 0.08:
				kind = "rock"
		"mountain":
			if roll < 0.22:
				kind = "rock"
			elif roll < 0.255:
				kind = "iron_ore"
			elif roll < 0.285 and h >= FWConst.GOLD_MIN_HEIGHT:
				kind = "gold_ore"
		"beach":
			if roll < 0.12:
				kind = "clay"
	# گنج پنهان: بسیار نادر، در هر زیست‌بوم خشکی (قطعی از Seed).
	if kind == "" and _h01(rx, rz, 7) < 0.0025:
		kind = "chest"
	if kind == "":
		return {}
	var def: Dictionary = FWConst.RESOURCES[kind]
	var n: int = int(def["min"]) + int(_h01(rx, rz, 4) * float(int(def["max"]) - int(def["min"]) + 1))
	return {"kind": kind, "x": x, "z": z, "y": h, "n": mini(n, int(def["max"])),
		"rot": _h01(rx, rz, 5) * TAU, "s": 0.8 + _h01(rx, rz, 6) * 0.7}


## ---------------- ورودی معدن ----------------
## در هر خانهٔ MINE_CELL_WORLD متری حداکثر یک ورودی روی کوه (زمین پایه، نه تغییرات بازیکن)،
## بیرون از شهر و رودخانه. کاملاً قطعی؛ سرور و کلاینت یک فهرست می‌گیرند.
var _mine_list: Array = []
var _mine_by_id: Dictionary = {}
var _mine_built: bool = false


func mine_entrances() -> Array:
	if not _mine_built:
		_build_mine_entrances()
	return _mine_list


## ورودی با شناسهٔ "mx,mz" یا دیکشنری خالی.
func mine_entrance(id: String) -> Dictionary:
	if id.begins_with("h"):
		return house_site(id)
	if not _mine_built:
		_build_mine_entrances()
	return _mine_by_id.get(id, {})


func nearest_mine_entrance(x: float, z: float, max_dist: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_dist
	for e in mine_entrances():
		var d := Vector2(x, z).distance_to(Vector2(float(e["x"]), float(e["z"])))
		if d <= best_d:
			best_d = d
			best = e
	return best


## آیا نقطه نزدیک یک ورودی معدن است؟ (برای ممنوعیت ساخت و تغییر زمین)
func near_mine_entrance(x: float, z: float, radius: float) -> bool:
	return not nearest_mine_entrance(x, z, radius).is_empty()


func _build_mine_entrances() -> void:
	_mine_built = true
	_mine_list = []
	_mine_by_id = {}
	var cell := FWConst.MINE_CELL_WORLD
	var lo := int(floor(-FWConst.WORLD_LIMIT / cell))
	var hi := int(floor((FWConst.CITY_SIZE + FWConst.WORLD_LIMIT) / cell))
	var half := FWConst.CITY_SIZE * 0.5
	for mz in range(lo, hi + 1):
		for mx in range(lo, hi + 1):
			for attempt in range(10):
				var x := (float(mx) + 0.08 + _h01(mx, mz, 20 + attempt * 2) * 0.84) * cell
				var z := (float(mz) + 0.08 + _h01(mx, mz, 21 + attempt * 2) * 0.84) * cell
				if x < -FWConst.WORLD_LIMIT + 14.0 or z < -FWConst.WORLD_LIMIT + 14.0 or x > FWConst.CITY_SIZE + FWConst.WORLD_LIMIT - 14.0 or z > FWConst.CITY_SIZE + FWConst.WORLD_LIMIT - 14.0:
					continue
				if Vector2(x, z).distance_to(Vector2(half, half)) < 130.0:
					continue
				var h := base_height_at(x, z)
				if h < FWConst.MINE_MIN_HEIGHT or h > FWConst.MINE_MAX_HEIGHT or river_weight(x, z) > 0.0:
					continue
				# جلوی ورودی: سمتی که زمین پایین‌تر است.
				var best_dir := Vector2(0, 1)
				var best_h := INF
				for k in range(8):
					var a := float(k) * TAU / 8.0
					var dv := Vector2(sin(a), cos(a))
					var hh := base_height_at(x + dv.x * 6.0, z + dv.y * 6.0)
					if hh < best_h:
						best_h = hh
						best_dir = dv
				var ex := x + best_dir.x * 3.5
				var ez := z + best_dir.y * 3.5
				var id := "%d,%d" % [mx, mz]
				var e := {"id": id, "mx": mx, "mz": mz, "x": x, "z": z, "y": h,
					"yaw": atan2(best_dir.x, best_dir.y), "ex": ex, "ez": ez}
				_mine_list.append(e)
				_mine_by_id[id] = e
				break


## ---------------- روستاها (پروتکل ۱۹) ----------------
## در هر خانهٔ VILLAGE_CELL متری حداکثر یک روستا روی زمین هموار، بیرون از شهر، دور از آب و رودخانه.
## هر روستا: چاه در مرکز و ۴ تا ۷ خانهٔ ۵×۵ متری که در به سمت مرکز دارد. قطعی از Seed.
var _villages: Array = []
var _village_by_key: Dictionary = {}
var _village_built: bool = false


func villages() -> Array:
	if not _village_built:
		_build_villages()
	return _villages


## خانه با شناسهٔ "h<vx>,<vz>,<i>": در قالب ورودی (x,z = در؛ ex,ez = نقطهٔ بیرون در) یا دیکشنری خالی.
func house_site(id: String) -> Dictionary:
	if not _village_built:
		_build_villages()
	var parts: PackedStringArray = id.substr(1).split(",")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	var v: Dictionary = _village_by_key.get("%s,%s" % [parts[0], parts[1]], {})
	var i := int(parts[2])
	if v.is_empty() or i < 0 or i >= v["houses"].size():
		return {}
	return v["houses"][i]


## نزدیک‌ترین در خانه‌ای در برد max_dist.
func nearest_house_door(x: float, z: float, max_dist: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_dist
	for v in villages():
		if Vector2(x, z).distance_to(Vector2(float(v["x"]), float(v["z"]))) > FWConst.VILLAGE_RADIUS + max_dist:
			continue
		for h in v["houses"]:
			var d := Vector2(x, z).distance_to(Vector2(float(h["x"]), float(h["z"])))
			if d <= best_d:
				best_d = d
				best = h
	return best


## نزدیک‌ترین ورودی از هر نوع (معدن یا خانهٔ روستا).
func nearest_site(x: float, z: float, max_dist: float) -> Dictionary:
	var m := nearest_mine_entrance(x, z, max_dist)
	var h := nearest_house_door(x, z, minf(max_dist, FWConst.HOUSE_ENTER_RANGE))
	if m.is_empty():
		return h
	if h.is_empty():
		return m
	var dm := Vector2(x, z).distance_to(Vector2(float(m["x"]), float(m["z"])))
	var dh := Vector2(x, z).distance_to(Vector2(float(h["x"]), float(h["z"])))
	return h if dh < dm else m


func near_village(x: float, z: float, radius: float) -> bool:
	for v in villages():
		if Vector2(x, z).distance_to(Vector2(float(v["x"]), float(v["z"]))) <= radius:
			return true
	return false


## آیا نقطه داخل یک خانه یا چاه روستا (با حاشیه) است؟ برای عبور، ساخت و کندن زمین.
func village_solid_at(x: float, z: float, margin: float = 0.0) -> bool:
	var reach := FWConst.VILLAGE_RADIUS + 4.0 + margin
	for v in villages():
		var vx: float = float(v["x"])
		var vz: float = float(v["z"])
		if absf(x - vx) > reach or absf(z - vz) > reach:
			continue
		var hh := FWConst.HOUSE_HALF + margin
		for h in v["houses"]:
			if absf(x - float(h["cx"])) <= hh and absf(z - float(h["cz"])) <= hh:
				return true
		if Vector2(x, z).distance_to(Vector2(vx, vz)) <= 1.0 + margin:
			return true
	return false


func _village_flat(x: float, z: float, half: float, lo_h: float, spread: float) -> float:
	# ارتفاع بالاترین گوشه یا -1 اگر زمین مناسب نیست.
	var lo := INF
	var hi := -INF
	for sx in [-half, 0.0, half]:
		for sz in [-half, 0.0, half]:
			var px: float = x + sx
			var pz: float = z + sz
			if river_weight(px, pz) > 0.0:
				return -1.0
			var hh := base_height_at(px, pz)
			lo = minf(lo, hh)
			hi = maxf(hi, hh)
	if lo < lo_h or hi - lo > spread:
		return -1.0
	return hi


func _build_villages() -> void:
	_village_built = true
	_villages = []
	_village_by_key = {}
	var cell := FWConst.VILLAGE_CELL
	var lo := int(floor(-FWConst.WORLD_LIMIT / cell))
	var hi := int(floor((FWConst.CITY_SIZE + FWConst.WORLD_LIMIT) / cell))
	var half := FWConst.CITY_SIZE * 0.5
	var edge := FWConst.WORLD_LIMIT - 40.0
	for vz in range(lo, hi + 1):
		for vx in range(lo, hi + 1):
			for attempt in range(24):
				var cx := (float(vx) + 0.15 + _h01(vx, vz, 300 + attempt * 2) * 0.7) * cell
				var cz := (float(vz) + 0.15 + _h01(vx, vz, 301 + attempt * 2) * 0.7) * cell
				if absf(cx - half) > edge or absf(cz - half) > edge:
					continue
				if Vector2(cx, cz).distance_to(Vector2(half, half)) < FWConst.VILLAGE_MIN_CITY_DIST:
					continue
				# مرکز و حلقهٔ بیرونی باید هموار و خشک باشد.
				var cy := _village_flat(cx, cz, 7.0, FWConst.VILLAGE_MIN_H, 4.5)
				if cy < 0.0 or cy > FWConst.VILLAGE_MAX_H:
					continue
				var v := _make_village(vx, vz, cx, cz)
				if v["houses"].size() >= 3:
					_villages.append(v)
					_village_by_key["%d,%d" % [vx, vz]] = v
					break


func _make_village(vx: int, vz: int, cx: float, cz: float) -> Dictionary:
	var houses: Array = []
	var want := 4 + int(_h01(vx, vz, 60) * 4.0)
	var wy := base_height_at(cx, cz)
	var half := FWConst.HOUSE_HALF
	for k in range(want * 10):
		if houses.size() >= want:
			break
		var a := _h01(vx, vz, 100 + k * 3) * TAU
		var r := 9.0 + _h01(vx, vz, 101 + k * 3) * 9.0
		var hx := snappedf(cx + cos(a) * r, 0.5)
		var hz := snappedf(cz + sin(a) * r, 0.5)
		var hy := _village_flat(hx, hz, half, FWConst.VILLAGE_MIN_H, 1.6)
		if hy < 0.0:
			continue
		var ok := true
		for o in houses:
			if maxf(absf(hx - float(o["cx"])), absf(hz - float(o["cz"]))) < 7.5:
				ok = false
				break
		if not ok:
			continue
		# در به سمت مرکز: محور غالب.
		var dx := cx - hx
		var dz := cz - hz
		var dir := Vector2(signf(dx), 0.0) if absf(dx) > absf(dz) else Vector2(0.0, signf(dz))
		var door := Vector2(hx, hz) + dir * half
		var out := Vector2(hx, hz) + dir * (half + 1.9)
		if river_weight(out.x, out.y) > 0.0 or base_height_at(out.x, out.y) < 0.6:
			continue
		var idx := houses.size()
		houses.append({"id": "h%d,%d,%d" % [vx, vz, idx], "cx": hx, "cz": hz, "y": hy,
			"x": door.x, "z": door.y, "ex": out.x, "ez": out.y, "yaw": atan2(dir.x, dir.y),
			"tone": int(_h01(vx, vz, 200 + idx) * 4.0)})
	return {"id": "%d,%d" % [vx, vz], "x": cx, "z": cz, "y": wy, "houses": houses}


static func biome_color(biome: String) -> Color:
	match biome:
		"water":
			return Color("2f6f9f")
		"beach":
			return Color("e0d29a")
		"mountain":
			return Color("8a8a8a")
		"forest":
			return Color("3f8f4f")
		_:
			return Color("7fbf5a")
