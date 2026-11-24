extends RefCounted
## جهان‌های آماده (سناریوها): هر سناریو Seed ثابت، حالت بازی، سرمایهٔ آغازین، آب‌وهوا و سازه‌های از پیش‌ساخته دارد.
## هیچ مأموریت اجباری ندارند؛ «ماجراجویی‌های پیشنهادی» فقط متن راهنما هستند.
## داده‌ها خالص‌اند (بدون وابستگی به سرور) تا هم منو و هم سرور و هم تست از آن‌ها استفاده کنند.

const FWConst = preload("res://scripts/core/const.gd")

## مرکز شهر (سلول‌های میدان مرکزی دور آن‌اند؛ سازه‌ها بیرون از میدان ساخته می‌شوند).
const CENTER := 64

const ORDER := ["green_valley", "builder_playground", "god_sandbox", "island_castaway", "medieval_fort", "merchant_city", "frozen_north", "desert_caravan"]

const DEFS := {
	"green_valley": {
		"seed": 102, "premium": false, "creative": false,
		"money": 1500, "items": {"wood": 40, "stone": 20, "dirt": 20, "brick": 8, "glass": 4},
		"hour": 7.0, "weather": "clear", "time_speed": 1.0, "forest_growth": true, "npcs": 4,
		"structures": ["farm_fence", "lamp_street", "windmill", "cottages"],
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
		"structures": ["campfire", "hut", "stone_circle", "lighthouse"],
		"trees": 12, "animals": {"rabbit": 6},
	},
	"medieval_fort": {
		"seed": 108, "premium": true, "creative": false,
		"money": 800, "items": {"stone": 160, "wood": 60, "brick": 20, "iron": 8, "glass": 6},
		"hour": 17.0, "weather": "fog", "time_speed": 1.0, "forest_growth": false, "npcs": 4,
		"structures": ["ruined_fort", "watch_tower", "cave_dome"],
		"trees": 6, "animals": {"deer": 6},
	},
	"merchant_city": {
		"seed": 43, "premium": true, "creative": false,
		"money": 5000, "items": {"wood": 60, "stone": 60, "brick": 30, "glass": 12, "clay": 20},
		"hour": 8.0, "weather": "clear", "time_speed": 1.0, "forest_growth": false, "npcs": 6,
		"structures": ["market_street", "lamp_street", "fountain_plaza", "warehouse"],
		"trees": 6, "animals": {"sheep": 6},
	},
	# اقلیم‌های تازه: فقط ظاهر زمین و منابع عوض می‌شود (برف و کاج / شن و نخل)؛ بقیهٔ قوانین همان است.
	"frozen_north": {
		"seed": 297, "premium": true, "creative": false, "climate": "winter",
		"money": 400, "items": {"wood": 80, "stone": 30, "iron": 6, "brick": 6, "glass": 4},
		"hour": 15.0, "weather": "fog", "time_speed": 1.0, "forest_growth": false, "npcs": 4,
		"structures": ["lodge", "campfire", "watch_tower", "igloo"],
		"trees": 14, "animals": {"deer": 8, "rabbit": 6},
	},
	"desert_caravan": {
		"seed": 326, "premium": true, "creative": false, "climate": "desert",
		"money": 900, "items": {"clay": 30, "stone": 40, "wood": 30, "glass": 6, "brick": 12},
		"hour": 11.0, "weather": "clear", "time_speed": 1.0, "forest_growth": false, "npcs": 5,
		"structures": ["oasis_camp", "pyramid", "market_street", "caravanserai"],
		"trees": 10, "animals": {"sheep": 6, "rabbit": 8},
	},
}


static func ids() -> Array:
	return ORDER.duplicate()


static func has(id: String) -> bool:
	return DEFS.has(id)


static func def(id: String) -> Dictionary:
	return DEFS.get(id, {})


## اقلیم جهان آماده (temperate اگر ذکر نشده باشد یا شناسه ناشناخته باشد).
static func climate(id: String) -> String:
	var c := str(DEFS.get(id, {}).get("climate", "temperate"))
	return c if FWConst.CLIMATES.has(c) else "temperate"


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


## خانهٔ ساده: دیوار، در رو به +z، پنجره در دیوار پشتی و دو طرف؛ سقف ردیف‌به‌ردیف (هر بلوک به همسایه‌اش تکیه می‌کند).
static func _house(out: Array, cx: int, cz: int, hw: int, hd: int, wall_h: int, wall: String) -> void:
	for dx in range(-hw, hw + 1):
		for dz in range(-hd, hd + 1):
			if absi(dx) == hw or absi(dz) == hd:
				if dx == 0 and dz == hd:
					_col(out, cx + dx, cz + dz, 0, 1, "door")
					_col(out, cx + dx, cz + dz, 1, 1, "door")
					if wall_h > 2:
						_col(out, cx + dx, cz + dz, 2, wall_h - 2, wall)
				elif (dz == -hd and absi(dx) % 2 == 0 and absi(dx) < hw) or (absi(dx) == hw and dz == 0):
					_col(out, cx + dx, cz + dz, 0, 1, wall)
					_col(out, cx + dx, cz + dz, 1, 1, "window")
					if wall_h > 2:
						_col(out, cx + dx, cz + dz, 2, wall_h - 2, wall)
				else:
					_col(out, cx + dx, cz + dz, 0, wall_h, wall)
			_col(out, cx + dx, cz + dz, wall_h, 1, "roof")


## گنبد توخالی با ورودی رو به +z (غار یا ایگلو). لایه‌به‌لایه از پایین و از بیرون به داخل ساخته می‌شود تا هر بلوک تکیه‌گاه داشته باشد.
## outer = شعاع بیرونی هر لایه؛ ضخامت دیوار ۲؛ لایهٔ آخر دیسک پر است. درگاه ۳ بلوک عرض و ۳ بلوک بلندی دارد.
static func _dome(out: Array, cx: int, cz: int, outer: Array, type: String, lamps: bool) -> void:
	for y in range(outer.size()):
		var top := y == outer.size() - 1
		var r_out: int = int(outer[y])
		var r_in: int = 0 if top else maxi(r_out - 2, 0)
		for r in range(r_out, r_in - 1, -1):
			for dx in range(-r, r + 1):
				for dz in range(-r, r + 1):
					if maxi(absi(dx), absi(dz)) != r:
						continue
					if y <= 2 and dz > 0 and absi(dx) <= 1:
						continue   # درگاه
					_col(out, cx + dx, cz + dz, y, 1, type)
	if lamps:
		var rr := int(outer[0]) - 3
		for c in [Vector2i(-rr, -rr), Vector2i(rr, -rr), Vector2i(0, -rr)]:
			_col(out, cx + c.x, cz + c.y, 0, 1, "lamp")



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
		"lodge":
			# کلبهٔ بزرگ چوبی ۹×۷ با پنجره، در و دودکش سنگی بیرون دیوار (جهان زمستانی)
			var cx := CENTER + 14
			var cz := CENTER - 22
			for dx in range(-4, 5):
				for dz in range(-3, 4):
					if absi(dx) == 4 or absi(dz) == 3:
						if dx == 0 and dz == 3:
							_col(out, cx + dx, cz + dz, 0, 1, "door")
							_col(out, cx + dx, cz + dz, 1, 1, "door")
							_col(out, cx + dx, cz + dz, 2, 1, "wood")
						elif dz == -3 and absi(dx) % 2 == 0:
							_col(out, cx + dx, cz + dz, 0, 1, "wood")
							_col(out, cx + dx, cz + dz, 1, 1, "window")
							_col(out, cx + dx, cz + dz, 2, 1, "wood")
						else:
							_col(out, cx + dx, cz + dz, 0, 3, "wood")
					_col(out, cx + dx, cz + dz, 3, 1, "roof")
			_col(out, cx + 5, cz - 1, 0, 6, "stone")
			_col(out, cx, cz + 4, 0, 1, "lamp")
		"oasis_camp":
			# سه چادر (چهار تیرک و سقف ۳×۳) دور آتش اردوگاه (جهان صحرا)
			var cx := CENTER - 22
			var cz := CENTER + 16
			for t in range(3):
				var tx := cx + (t - 1) * 6
				var tz := cz + (2 if t == 1 else 0)
				for dx in [-1, 1]:
					for dz in [-1, 1]:
						_col(out, tx + dx, tz + dz, 0, 2, "fence")
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						_col(out, tx + dx, tz + dz, 2, 1, "roof")
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if maxi(absi(dx), absi(dz)) == 1:
						_col(out, cx + dx, cz + 6 + dz, 0, 1, "stone")
			_col(out, cx, cz + 6, 0, 1, "lamp")
		"pyramid":
			# هرم پله‌ای ۱۳×۱۳ از آجر؛ ارتفاع هر ستون از کناره به مرکز بیشتر می‌شود (جهان صحرا)
			var cx := CENTER + 22
			var cz := CENTER - 32
			for dx in range(-6, 7):
				for dz in range(-6, 7):
					_col(out, cx + dx, cz + dz, 0, 7 - maxi(absi(dx), absi(dz)), "brick")
			_col(out, cx, cz, 7, 1, "lamp")
		"windmill":
			# آسیاب بادی: برج سنگی ۵×۵ با سقف و پرهٔ چوبی صلیبی پشت برج (جهان دره)
			var cx := CENTER - 30
			var cz := CENTER - 16
			_house(out, cx, cz, 2, 2, 5, "stone")
			_col(out, cx, cz - 3, 1, 7, "wood")
			for k in range(1, 4):
				_col(out, cx - k, cz - 3, 4, 1, "wood")
				_col(out, cx + k, cz - 3, 4, 1, "wood")
			_col(out, cx, cz, 6, 1, "lamp")
		"cottages":
			# سه خانهٔ روستایی با اندازه و جنس متفاوت کنار هم
			var cx := CENTER + 32
			var cz := CENTER + 4
			_house(out, cx, cz, 2, 2, 3, "wood")
			_house(out, cx + 8, cz + 3, 2, 3, 3, "brick")
			_house(out, cx, cz + 10, 3, 2, 3, "wood")
			_col(out, cx + 4, cz + 8, 0, 3, "wood")
			_col(out, cx + 4, cz + 8, 3, 1, "lamp")
		"lighthouse":
			# فانوس دریایی: پایهٔ آجری، برج سنگی توخالی، سقف و چراغ بلند (جهان جزیره)
			var cx := CENTER - 12
			var cz := CENTER - 30
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					if maxi(absi(dx), absi(dz)) == 2:
						_col(out, cx + dx, cz + dz, 0, 1, "brick")
			_house(out, cx, cz, 1, 1, 9, "stone")
			_col(out, cx, cz, 9, 1, "lamp")
			_col(out, cx, cz, 10, 1, "lamp")
		"cave_dome":
			# غار سنگی: گنبد توخالی ۱۳×۱۳ با درگاه رو به جنوب و چراغ داخل
			_dome(out, CENTER + 34, CENTER - 4, [6, 6, 5, 4, 3, 2], "stone", true)
		"igloo":
			# ایگلوی شیشه‌ای کوچک (جهان زمستانی)
			_dome(out, CENTER - 26, CENTER + 8, [4, 4, 3, 2], "glass", false)
		"fountain_plaza":
			# میدانچهٔ فواره: حلقهٔ جاده، حوض سنگی و ستون شیشه‌ای با چراغ (جهان تاجران)
			var cx := CENTER + 32
			var cz := CENTER + 6
			for dx in range(-5, 6):
				for dz in range(-5, 6):
					var r := maxi(absi(dx), absi(dz))
					if r >= 4:
						_col(out, cx + dx, cz + dz, 0, 1, "road")
					elif r == 3:
						_col(out, cx + dx, cz + dz, 0, 1, "stone")
			_col(out, cx, cz, 0, 3, "glass")
			_col(out, cx, cz, 3, 1, "lamp")
		"warehouse":
			# انبار بزرگ آجری ۱۱×۷
			_house(out, CENTER - 32, CENTER + 26, 5, 3, 3, "brick")
		"caravanserai":
			# کاروانسرا: حیاط ۱۷×۱۷ با دیوار گلی، برج‌های گوشه و دروازهٔ جنوبی (جهان صحرا)
			var cx := CENTER + 34
			var cz := CENTER + 10
			for dx in range(-8, 9):
				for dz in range(-8, 9):
					if maxi(absi(dx), absi(dz)) != 8:
						continue
					if dz == 8 and absi(dx) <= 1:
						continue   # دروازه
					var corner := absi(dx) == 8 and absi(dz) == 8
					_col(out, cx + dx, cz + dz, 0, 5 if corner else 3, "brick")
			for c in [Vector2i(-3, -3), Vector2i(3, -3)]:
				_col(out, cx + c.x, cz + c.y, 0, 1, "lamp")
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if maxi(absi(dx), absi(dz)) == 1:
						_col(out, cx + dx, cz + 1 + dz, 0, 1, "stone")

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
