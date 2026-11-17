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


func biome_at(x: float, z: float) -> String:
	var h := height_at(x, z)
	if h < FWConst.SEA_LEVEL:
		return "water"
	if h < 0.9:
		return "beach"
	if h > 14.0:
		return "mountain"
	if _moist.get_noise_2d(x, z) > 0.15:
		return "forest"
	return "plain"


func is_outside_city(x: float, z: float) -> bool:
	var half := FWConst.CITY_SIZE * 0.5
	return Vector2(x, z).distance_to(Vector2(half, half)) > 100.0


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
