extends RefCounted
## جهان‌های آماده (سناریوها): هر سناریو Seed ثابت، حالت بازی، سرمایهٔ آغازین، آب‌وهوا و سازه‌های از پیش‌ساخته دارد.
## هیچ مأموریت اجباری ندارند؛ «ماجراجویی‌های پیشنهادی» فقط متن راهنما هستند.
## داده‌ها خالص‌اند (بدون وابستگی به سرور) تا هم منو و هم سرور و هم تست از آن‌ها استفاده کنند.

const FWConst = preload("res://scripts/core/const.gd")

## مرکز شهر (سلول‌های میدان مرکزی دور آن‌اند؛ سازه‌ها بیرون از میدان ساخته می‌شوند).
const CENTER := 64

const ORDER := ["green_valley", "builder_playground", "god_sandbox", "island_castaway", "medieval_fort", "merchant_city"]

const DEFS := {
	"green_valley": {
		"seed": 102, "premium": false, "creative": false,
		"money": 1500, "items": {"wood": 40, "stone": 20, "dirt": 20, "brick": 8, "glass": 4},
		"hour": 7.0, "weather": "clear", "time_speed": 1.0, "forest_growth": true, "npcs": 4,
		"structures": ["farm_fence", "lamp_street"],
		"trees": 14, "animals": {"sheep": 8, "rabbit": 6},
	},
	"builder_playground": {
		"seed": 66, "premium": false, "creative": true,
		"money": 0, "items": {},
		"hour": 12.0, "weather": "clear", "time_speed": 0.0, "forest_growth": false, "npcs": 2,
		"structures": ["tower", "stairs_arena", "rail_loop"],
		"trees": 4, "animals": {},
	},
	"god_sandbox": {
		"seed": 78, "premium": false, "creative": true,
		"money": 0, "items": {},
		"hour": 9.0, "weather": "clear", "time_speed": 4.0, "forest_growth": true, "npcs": 6,
		"structures": ["stone_circle"],
		"trees": 40, "animals": {"sheep": 14, "deer": 12, "rabbit": 14},
	},
	"island_castaway": {
		"seed": 248, "premium": true, "creative": false,
		"money": 50, "items": {"wood": 30, "stone": 6},
		"hour": 6.0, "weather": "clear", "time_speed": 1.0, "forest_growth": true, "npcs": 2,
		"structures": ["campfire", "hut", "stone_circle"],
		"trees": 12, "animals": {"rabbit": 6},
	},
	"medieval_fort": {
		"seed": 108, "premium": true, "creative": false,
		"money": 800, "items": {"stone": 160, "wood": 60, "brick": 20, "iron": 8, "glass": 6},
		"hour": 17.0, "weather": "fog", "time_speed": 1.0, "forest_growth": false, "npcs": 4,
		"structures": ["ruined_fort", "watch_tower"],
		"trees": 6, "animals": {"deer": 6},
	},
	"merchant_city": {
		"seed": 43, "premium": true, "creative": false,
		"money": 5000, "items": {"wood": 60, "stone": 60, "brick": 30, "glass": 12, "clay": 20},
		"hour": 8.0, "weather": "clear", "time_speed": 1.0, "forest_growth": false, "npcs": 6,
		"structures": ["market_street", "lamp_street"],
		"trees": 6, "animals": {"sheep": 6},
	},
}


static func ids() -> Array:
	return ORDER.duplicate()


static func has(id: String) -> bool:
	return DEFS.has(id)


static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func is_premium(id: String) -> bool:
	return bool(DEFS.get(id, {}).get("premium", false))


## سرمایهٔ آغازین حساب تازه در این جهان (بدون سناریو: مقدار پیش‌فرض بازی).
static func start_money(id: String) -> int:
	if not DEFS.has(id):
		return FWConst.START_MONEY
	return int(DEFS[id]["money"])


static func start_items(id: String) -> Dictionary:
	if not DEFS.has(id):
		return FWConst.START_ITEMS.duplicate()
	var out: Dictionary = {}
	for k in DEFS[id]["items"]:
		out[str(k)] = int(DEFS[id]["items"][k])
	return out


# ---------------- سازه‌ها ----------------
# هر سازه فهرستی از ستون‌هاست: [x, z, ارتفاع‌شروع_نسبی, تعداد, نوع]
# بلوک‌ها از سطح زمینِ همان ستون به بالا چیده می‌شوند (پس روی شیب هم می‌نشینند).
# y_off: فاصلهٔ اولین بلوک از سطح زمین؛ n: تعداد بلوک روی هم.

static func _col(out: Array, x: int, z: int, y_off: int, n: int, type: String) -> void:
	out.append([x, z, y_off, n, type])


static func _ring(out: Array, cx: int, cz: int, r: int, y_off: int, n: int, type: String, gap_every: int = 0) -> void:
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if maxi(absi(dx), absi(dz)) != r:
				continue
			if gap_every > 0 and (absi(dx) + absi(dz)) % gap_every == 0 and absi(dx) != absi(dz):
				continue
			_col(out, cx + dx, cz + dz, y_off, n, type)


## ستون‌های یک سازه. rng برای سازه‌های ویرانه‌ای (شکستگی) از Seed جهان می‌آید تا قطعی بماند.
static func structure(kind: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	match kind:
		"farm_fence":
			# زمین کشاورزی حصارکشی‌شده با دروازه، سمت غرب میدان
			var cx := CENTER - 26
			var cz := CENTER + 6
			for dx in range(-6, 7):
				for dz in range(-5, 6):
					if absi(dx) == 6 or absi(dz) == 5:
						if dx == 0 and dz == 5:
							continue
						_col(out, cx + dx, cz + dz, 0, 1, "fence")
		"lamp_street":
			# خیابان چراغ‌دار شرقی-غربی جنوب میدان
			var z := CENTER + 14
			for x in range(CENTER - 22, CENTER + 23):
				_col(out, x, z, 0, 1, "road")
				if (x - (CENTER - 22)) % 7 == 0:
					_col(out, x, z + 1, 0, 3, "wood")
					_col(out, x, z + 1, 3, 1, "lamp")
		"tower":
			# برج پارکور ۱۲ طبقه با پلکان مارپیچ
			var cx := CENTER + 22
			var cz := CENTER - 22
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					if maxi(absi(dx), absi(dz)) == 2:
						_col(out, cx + dx, cz + dz, 0, 12, "stone")
			for i in range(12):
				var a: Vector2i = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)][i % 8]
				_col(out, cx + a.x, cz + a.y, i, 1, "wood")
			_col(out, cx, cz, 12, 1, "lamp")
		"stairs_arena":
			# تپهٔ پله‌ای برای تمرین ساخت و پرش
			var cx := CENTER - 22
			var cz := CENTER - 22
			for step in range(6):
				for dx in range(-(6 - step), 7 - step):
					for dz in range(-(6 - step), 7 - step):
						if maxi(absi(dx), absi(dz)) == 6 - step:
							_col(out, cx + dx, cz + dz, step, 1, "brick")
		"rail_loop":
			# حلقهٔ ریل ۱۶×۱۶ برای قطار خودکار
			var cx := CENTER + 24
			var cz := CENTER + 24
			for i in range(-8, 9):
				_col(out, cx + i, cz - 8, 0, 1, "rail")
				_col(out, cx + i, cz + 8, 0, 1, "rail")
				if i > -8 and i < 8:
					_col(out, cx - 8, cz + i, 0, 1, "rail")
					_col(out, cx + 8, cz + i, 0, 1, "rail")
		"stone_circle":
			# دایرهٔ سنگی باستانی (ستون‌هایی با ارتفاع متفاوت)
			var cx := CENTER + 20
			var cz := CENTER + 20
			for i in range(12):
				var a := TAU * float(i) / 12.0
				_col(out, cx + int(round(cos(a) * 7.0)), cz + int(round(sin(a) * 7.0)), 0, 2 + rng.randi_range(0, 3), "stone")
		"campfire":
			var cx := CENTER + 16
			var cz := CENTER - 12
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if maxi(absi(dx), absi(dz)) == 1:
						_col(out, cx + dx, cz + dz, 0, 1, "stone")
			_col(out, cx, cz, 0, 1, "lamp")
		"hut":
			# کلبهٔ کوچک ۵×۵ با در و پنجره
			var cx := CENTER + 12
			var cz := CENTER + 22
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var edge := maxi(absi(dx), absi(dz)) == 2
					if edge:
						if dx == 0 and dz == 2:
							_col(out, cx + dx, cz + dz, 0, 1, "door")
							_col(out, cx + dx, cz + dz, 1, 1, "door")
						elif dz == -2 and dx == 0:
							_col(out, cx + dx, cz + dz, 0, 1, "wood")
							_col(out, cx + dx, cz + dz, 1, 1, "window")
						else:
							_col(out, cx + dx, cz + dz, 0, 2, "wood")
					_col(out, cx + dx, cz + dz, 2, 1, "roof")
		"ruined_fort":
			# حصار ۲۱×۲۱ با دیوارهای شکسته و چهار برج گوشه؛ شکستگی‌ها قطعی‌اند
			var cx := CENTER - 30
			var cz := CENTER - 30
			for dx in range(-10, 11):
				for dz in range(-10, 11):
					if maxi(absi(dx), absi(dz)) != 10:
						continue
					if dx == 0 and dz == 10:
						continue   # دروازه
					var corner := absi(dx) == 10 and absi(dz) == 10
					var h := 7 if corner else 2 + rng.randi_range(0, 3)
					if not corner and rng.randf() < 0.18:
						h = 1
					_col(out, cx + dx, cz + dz, 0, h, "stone")
			_col(out, cx, cz, 0, 1, "lamp")
		"watch_tower":
			var cx := CENTER + 26
			var cz := CENTER - 26
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if maxi(absi(dx), absi(dz)) == 1:
						_col(out, cx + dx, cz + dz, 0, 8, "stone")
			_col(out, cx, cz, 8, 1, "lamp")
		"market_street":
			# خیابان بازار شمالی با غرفه‌های چوبی؛ ردیف دکه‌ها دو طرف جاده
			var z := CENTER - 14
			for x in range(CENTER - 24, CENTER + 25):
				_col(out, x, z, 0, 1, "road")
			for k in range(6):
				var sx := CENTER - 20 + k * 8
				for dz in [-3, 3]:
					_col(out, sx, z + dz, 0, 2, "wood")
					_col(out, sx + 2, z + dz, 0, 2, "wood")
					for dxx in range(0, 3):
						_col(out, sx + dxx, z + dz, 2, 1, "roof")
	return out


## یک مجموعه ستون برای سناریو: همهٔ سازه‌ها با یک rng قطعی از Seed.
static func columns(id: String) -> Array:
	var d: Dictionary = def(id)
	if d.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"]) * 7919 + 17
	var out: Array = []
	for kind in d["structures"]:
		out.append_array(structure(str(kind), rng))
	return out
