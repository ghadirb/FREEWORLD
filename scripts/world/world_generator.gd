extends RefCounted
## تولید قطعی (Deterministic) زمین از روی Seed.
## یک Seed یکسان همیشه ارتفاع و زیست‌بوم یکسان می‌دهد.

const FWConst = preload("res://scripts/core/const.gd")

var seed_value: int
var _base := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _lake := FastNoiseLite.new()


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


func height_at(x: float, z: float) -> float:
	var half := FWConst.CITY_SIZE * 0.5
	var dist := Vector2(x, z).distance_to(Vector2(half, half))
	var outside := smoothstep(95.0, 220.0, dist)
	var d := _detail.get_noise_2d(x, z)
	var h := 2.0 + d * 0.8
	h += _base.get_noise_2d(x, z) * 28.0 * outside + d * 3.0 * outside
	var lake := maxf(_lake.get_noise_2d(x, z) - 0.35, 0.0) * 40.0 * smoothstep(90.0, 140.0, dist)
	return h - lake


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
			elif roll < 0.27 and h >= FWConst.GOLD_MIN_HEIGHT:
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
