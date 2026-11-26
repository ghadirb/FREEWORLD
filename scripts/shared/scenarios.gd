extends RefCounted
## جهان‌های آماده (سناریوها): هر سناریو Seed ثابت، حالت بازی، سرمایهٔ آغازین، آب‌وهوا و سازه‌های از پیش‌ساخته دارد.
## هیچ مأموریت اجباری ندارند؛ «ماجراجویی‌های پیشنهادی» فقط متن راهنما هستند.
## داده‌ها خالص‌اند (بدون وابستگی به سرور) تا هم منو و هم سرور و هم تست از آن‌ها استفاده کنند.

const FWConst = preload("res://scripts/core/const.gd")

## مرکز شهر (سلول‌های میدان مرکزی دور آن‌اند؛ سازه‌ها بیرون از میدان ساخته می‌شوند).
const CENTER := 64

const ORDER := ["green_valley", "builder_playground", "god_sandbox", "island_castaway", "medieval_fort", "merchant_city", "frozen_north", "desert_caravan", "space_colony"]

const DEFS := {
	"green_valley": {
		"seed": 102, "premium": false, "creative": false,
		"money": 1500, "items": {"wood": 40, "stone": 20, "dirt": 20, "brick": 8, "glass": 4},
		"hour": 7.0, "weather": "clear", "time_speed": 1.0, "forest_growth": true, "npcs": 4,
		"structures": ["farm_fence", "lamp_street", "windmill", "cottages", "well", "stable", "inn"],
		"trees": 14, "animals": {"sheep": 8, "rabbit": 6},
	},
	"builder_playground": {
		"seed": 66, "premium": false, "creative": true,
		"money": 0, "items": {},
		"hour": 12.0, "weather": "clear", "time_speed": 0.0, "forest_growth": false, "npcs": 2,
		"structures": ["tower", "stairs_arena", "rail_loop", "build_pads", "obelisk", "townhouses"],
		"trees": 4, "animals": {},
	},
	"god_sandbox": {
		"seed": 78, "premium": false, "creative": true,
		"money": 0, "items": {},
		"hour": 9.0, "weather": "clear", "time_speed": 4.0, "forest_growth": true, "npcs": 6,
		"structures": ["stone_circle", "cave_dome", "windmill", "lighthouse", "obelisk", "well", "stable"],
		"trees": 40, "animals": {"sheep": 14, "deer": 12, "rabbit": 14},
	},
	"island_castaway": {
		"seed": 248, "premium": true, "creative": false,
		"money": 50, "items": {"wood": 30, "stone": 6},
		"hour": 6.0, "weather": "clear", "time_speed": 1.0, "forest_growth": true, "npcs": 2,
		"structures": ["campfire", "hut", "stone_circle", "lighthouse", "fisher_hut", "estate_wood@-40,0", "well", "obelisk", "stable"],
		"trees": 12, "animals": {"rabbit": 6},
	},
	"medieval_fort": {
		"seed": 108, "premium": true, "creative": false,
		"money": 800, "items": {"stone": 160, "wood": 60, "brick": 20, "iron": 8, "glass": 6},
		"hour": 17.0, "weather": "fog", "time_speed": 1.0, "forest_growth": false, "npcs": 4,
		"structures": ["ruined_fort", "watch_tower", "cave_dome", "stone_keep", "estate_stone@-40,0", "well", "obelisk", "stable", "inn"],
		"trees": 6, "animals": {"deer": 6},
	},
	"merchant_city": {
		"seed": 43, "premium": true, "creative": false,
		"money": 5000, "items": {"wood": 60, "stone": 60, "brick": 30, "glass": 12, "clay": 20},
		"hour": 8.0, "weather": "clear", "time_speed": 1.0, "forest_growth": false, "npcs": 6,
		"structures": ["market_street", "lamp_street", "fountain_plaza", "warehouse", "manor", "inn", "townhouses", "guild_hall", "estate_stone@-40,0", "well", "stable"],
		"trees": 6, "animals": {"sheep": 6},
	},
	# اقلیم‌های تازه: فقط ظاهر زمین و منابع عوض می‌شود (برف و کاج / شن و نخل)؛ بقیهٔ قوانین همان است.
	"frozen_north": {
		"seed": 297, "premium": true, "creative": false, "climate": "winter",
		"money": 400, "items": {"wood": 80, "stone": 30, "iron": 6, "brick": 6, "glass": 4},
		"hour": 15.0, "weather": "fog", "time_speed": 1.0, "forest_growth": false, "npcs": 4,
		"structures": ["lodge", "campfire", "watch_tower", "igloo", "hall_rooms", "ice_cabins", "estate_wood@-40,0", "well", "obelisk", "stable"],
		"trees": 14, "animals": {"deer": 8, "rabbit": 6},
	},
	"desert_caravan": {
		"seed": 326, "premium": true, "creative": false, "climate": "desert",
		"money": 900, "items": {"clay": 30, "stone": 40, "wood": 30, "glass": 6, "brick": 12},
		"hour": 11.0, "weather": "clear", "time_speed": 1.0, "forest_growth": false, "npcs": 5,
		"structures": ["oasis_camp", "pyramid", "market_street", "caravanserai", "cave_dome_west", "adobe_quarter", "estate_brick@-32,-24", "well", "obelisk", "stable", "inn"],
		"trees": 10, "animals": {"sheep": 6, "rabbit": 8},
	},
	# جهان فضایی (اقلیم moon): خاک خاکستری، ستون‌های بلور به‌جای درخت (همان چوب می‌دهند)، آسمان سیاه؛ بقیهٔ قوانین همان است.
	"space_colony": {
		"seed": 411, "premium": true, "creative": false, "climate": "moon",
		"money": 700, "items": {"stone": 60, "wood": 50, "glass": 30, "iron": 12, "brick": 10},
		"hour": 12.0, "weather": "clear", "time_speed": 1.0, "forest_growth": false, "npcs": 4,
		"structures": ["landing_pad", "rocket", "habitat_dome", "moon_lab", "solar_field", "well", "obelisk"],
		"trees": 8, "animals": {},
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
static func _house(out: Array, cx: int, cz: int, hw: int, hd: int, wall_h: int, wall: String, y0: int = 0, holes: Array = []) -> void:
	for dx in range(-hw, hw + 1):
		for dz in range(-hd, hd + 1):
			if absi(dx) == hw or absi(dz) == hd:
				if dx == 0 and dz == hd and y0 == 0:
					_col(out, cx + dx, cz + dz, y0, 1, "door")
					_col(out, cx + dx, cz + dz, y0 + 1, 1, "door")
					if wall_h > 2:
						_col(out, cx + dx, cz + dz, y0 + 2, wall_h - 2, wall)
				elif (dz == -hd and absi(dx) % 2 == 0 and absi(dx) < hw) or (absi(dx) == hw and dz == 0) or (y0 > 0 and dz == hd and dx == 0):
					_col(out, cx + dx, cz + dz, y0, 1, wall)
					_col(out, cx + dx, cz + dz, y0 + 1, 1, "window")
					if wall_h > 2:
						_col(out, cx + dx, cz + dz, y0 + 2, wall_h - 2, wall)
				else:
					_col(out, cx + dx, cz + dz, y0, wall_h, wall)
			if not holes.has(Vector2i(dx, dz)):
				_col(out, cx + dx, cz + dz, y0 + wall_h, 1, "roof")


## مبلمان ساده داخل خانه‌ای که با _house ساخته شده: تخت دوبلوکی، چراغ، میز و صندلی؛ خانهٔ مقابل در (ستون وسط رو به +z) همیشه آزاد می‌ماند.
static func _furnish_house(out: Array, cx: int, cz: int, hw: int, hd: int) -> void:
	var bx := -(hw - 1)
	var bz := -(hd - 1)
	_col(out, cx + bx, cz + bz, 0, 1, "wood")
	_col(out, cx + bx + 1, cz + bz, 0, 1, "wood")
	_col(out, cx + hw - 1, cz + bz, 0, 1, "lamp")
	_col(out, cx + hw - 1, cz, 0, 1, "wood")
	if hw >= 3:
		_col(out, cx + hw - 2, cz, 0, 1, "stairs")


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



## اتاق‌های داخلی خانهٔ چنداتاقه. هر اتاق از دیوار سمت چپ خودش (دیوار بیرونی یا جداکننده) می‌چیند؛
## فقط دو ردیف عقب (و فقط یک ردیف اگر خانه کوتاه است) پر می‌شود تا ردیف میانی (dz=0، درگاه‌ها) و
## خانهٔ پشت در همیشه آزاد بماند. هر مورد: [ستون از دیوار چپ اتاق, ردیف از دیوار پشتی, ارتفاع, نوع].
const ROOM_ITEMS := {
	"bedroom": [[0, 0, 1, "wood"], [1, 0, 1, "wood"], [2, 0, 1, "lamp"], [0, 1, 1, "wood"]],
	"kitchen": [[0, 0, 1, "stone"], [1, 0, 1, "stone"], [2, 0, 1, "lamp"], [0, 1, 1, "wood"], [1, 1, 1, "stairs"]],
	"library": [[0, 0, 2, "wood"], [1, 0, 2, "wood"], [2, 0, 2, "wood"], [3, 0, 1, "lamp"], [0, 1, 1, "stairs"]],
	"store": [[0, 0, 2, "wood"], [1, 0, 1, "wood"], [0, 1, 1, "wood"], [2, 0, 1, "lamp"]],
	"hall": [[0, 0, 1, "stairs"], [1, 0, 1, "wood"], [2, 0, 1, "stairs"], [3, 0, 1, "lamp"]],
	"hearth": [[0, 0, 3, "stone"], [1, 0, 1, "stone"], [0, 1, 1, "lamp"], [2, 0, 1, "stairs"]],
	"shop": [[0, 0, 2, "wood"], [2, 0, 1, "lamp"], [0, 1, 1, "wood"], [1, 1, 1, "wood"], [2, 1, 1, "wood"]],
}


## خانهٔ چنداتاقه: پوستهٔ _house + دیوار جداکنندهٔ داخلی در هر x از splits (درگاه دوبلوکی در dz=0) + مبلمان هر اتاق.
## rooms.size() باید splits.size()+1 باشد. هیچ جداکننده‌ای روی ستون در (dx=0) نمی‌افتد.
static func _room_house(out: Array, cx: int, cz: int, hw: int, hd: int, wall_h: int, wall: String, splits: Array, rooms: Array) -> void:
	_house(out, cx, cz, hw, hd, wall_h, wall)
	for px in splits:
		for dz in range(-hd + 1, hd):
			if dz == 0:
				continue   # درگاه میان دو اتاق
			_col(out, cx + int(px), cz + dz, 0, wall_h, wall)
	var edges: Array = [-hw] + splits + [hw]
	for i in range(rooms.size()):
		var x0: int = int(edges[i]) + 1
		_furnish(out, cx, cz, x0, int(edges[i + 1]) - x0, -hd + 1, 2 if hd >= 3 else 1, str(rooms[i]), 0)


## مبلمان یک اتاق: x0 ستون چپ (نسبت به cx)، w عرض، z0 ردیف پشتی (نسبت به cz)، y0 تراز کف.
static func _furnish(out: Array, cx: int, cz: int, x0: int, w: int, z0: int, rows: int, kind: String, y0: int) -> void:
	for it in ROOM_ITEMS.get(kind, []):
		if int(it[0]) >= w or int(it[1]) >= rows:
			continue
		_col(out, cx + x0 + int(it[0]), cz + z0 + int(it[1]), y0, int(it[2]), str(it[3]))


## خانهٔ دوطبقه با راه‌پله: اتاق چپ پله‌دار (چهار پلهٔ ۱‌بلوکی روی ردیف پشتی، رو به +x)، اتاق راست با مبلمان؛
## سقف طبقهٔ همکف (دال) روی پله باز است، کنار چاه‌پله نرده می‌خورد، طبقهٔ بالا یک سردرگاه چراغ‌دار و اتاق خواب دارد.
## hw باید ≥ 7 باشد (۶ خانه برای رسیدن/پله/خروج) و split ≥ 0 و ≠ 0 نیست تا درِ جلو آزاد بماند (۱ پیشنهادی).
static func _stair_house(out: Array, cx: int, cz: int, hw: int, hd: int, wall: String, split: int, down_room: String, up_room: String) -> void:
	var start := out.size()
	var sx := -hw + 2          # ستون نخستین پله (خانهٔ -hw+1 جلوی پله برای رسیدن است)
	var z0 := -hd + 1
	var holes: Array = []
	for i in range(4):
		holes.append(Vector2i(sx + i, z0))
	_house(out, cx, cz, hw, hd, 3, wall, 0, holes)                 # همکف + دال سقف (روی پله باز)
	for dz in range(-hd + 1, hd):
		if dz != 0:
			_col(out, cx + split, cz + dz, 0, 3, wall)             # دیوار جداکنندهٔ همکف (درگاه در dz=0)
	for i in range(4):
		if i > 0:
			_col(out, cx + sx + i, cz + z0, 0, i, "wood")
		out.append([cx + sx + i, cz + z0, i, 1, "stairs", 16])     # facing=1: بالا رفتن به سمت +x
	_furnish(out, cx, cz, split + 1, hw - 1 - split, z0, 2 if hd >= 3 else 1, down_room, 0)
	_house(out, cx, cz, hw, hd, 3, wall, 4)                        # طبقهٔ بالا + سقف
	for dz in range(-hd + 1, hd):
		if dz != 0:
			_col(out, cx + split, cz + dz, 4, 3, wall)
	for i in range(4):
		_col(out, cx + sx + i, cz + z0 + 1, 4, 1, "fence")        # نردهٔ لبهٔ چاه‌پله
	_col(out, cx + sx - 1, cz + z0, 4, 1, "fence")
	_col(out, cx + sx + 5, cz + z0, 4, 1, "lamp")                  # چراغ سردرگاه (خانهٔ خروج sx+4 آزاد می‌ماند)
	_furnish(out, cx, cz, split + 1, hw - 1 - split, z0, 2 if hd >= 3 else 1, up_room, 4)
	for dx in [-2, 2]:
		_col(out, cx + dx, cz + hd + 1, 0, 3, "wood")              # ایوان
		_col(out, cx + dx, cz + hd + 1, 3, 1, "lamp")
	# گروه تراز: همهٔ ستون‌ها از یک تراز می‌آیند و زیرسازی ناهمواری زمین را پر می‌کند (ScenarioApply)
	for i in range(start, out.size()):
		if out[i].size() < 6:
			out[i].append(0)
		out[i].append_array([cx, cz, hw + 1, hd + 2])


## همهٔ ستون‌های out از اندیس start به بعد را در یک گروه تراز می‌گذارد (همه از بلندترین زمین مستطیل شروع می‌شوند و زیرشان با خاک پر می‌شود).
static func _level_group(out: Array, start: int, cx: int, cz: int, hw: int, hd: int) -> void:
	for i in range(start, out.size()):
		if out[i].size() < 6:
			out[i].append(0)
		out[i].append_array([cx, cz, hw, hd])


## ستون‌های یک سازه. rng برای سازه‌های ویرانه‌ای (شکستگی) از Seed جهان می‌آید تا قطعی بماند.
static func structure(kind: String, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if kind.begins_with("estate_"):
		# عمارت دوطبقه با راه‌پله: «estate_<جنس>@dx,dz» (جای هر جهان روی زمین تقریباً تخت انتخاب شده؛ زیرسازی خودکار پر می‌شود)
		var parts := kind.split("@")
		var at := (parts[1] if parts.size() > 1 else "-40,0").split(",")
		var wall_t: String = str(parts[0]).trim_prefix("estate_")
		_stair_house(out, CENTER + int(at[0]), CENTER + int(at[1]), 7, 4, wall_t, 1, "hall", "bedroom")
		return out
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
			_furnish_house(out, cx, cz, 2, 2)
			_house(out, cx + 8, cz + 3, 2, 3, 3, "brick")
			_furnish_house(out, cx + 8, cz + 3, 2, 3)
			_house(out, cx, cz + 10, 3, 2, 3, "wood")
			_furnish_house(out, cx, cz + 10, 3, 2)
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
		"cave_dome_west":
			# غار سنگی سمت غرب (برای جهان‌هایی که سمت شرق جا ندارند)
			_dome(out, CENTER - 34, CENTER - 4, [6, 6, 5, 4, 3, 2], "stone", true)
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
			var wx := CENTER - 32
			var wz := CENTER + 26
			_house(out, wx, wz, 5, 3, 3, "brick")
			# صندوق‌های چوبی پشت انبار و چراغ دو طرف
			for dx in [-4, -3, -2, 2, 3, 4]:
				_col(out, wx + dx, wz - 2, 0, 2 if absi(dx) != 3 else 1, "wood")
			_col(out, wx - 4, wz + 1, 0, 1, "lamp")
			_col(out, wx + 4, wz + 1, 0, 1, "lamp")
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
			for c in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-6, 2), Vector2i(6, 2)]:
				_col(out, cx + c.x, cz + c.y, 0, 1, "lamp")
			# نیمکت‌های سنگی کنار دیوار پشتی و بارانداز چوبی دو طرف حیاط
			for dx in [-6, -5, -4, 4, 5, 6]:
				_col(out, cx + dx, cz - 6, 0, 1, "stone")
			for dz in [-1, 0, 1]:
				_col(out, cx - 7, cz + dz, 0, 2, "wood")
				_col(out, cx + 7, cz + dz, 0, 2, "wood")
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if maxi(absi(dx), absi(dz)) == 1:
						_col(out, cx + dx, cz + 1 + dz, 0, 1, "stone")

		"manor":
			# عمارت ۱۳×۹ با سه اتاق واقعی (خواب، تالار، کتابخانه)، درگاه‌های داخلی و چراغ ایوان
			_room_house(out, CENTER, CENTER + 40, 6, 4, 4, "stone", [-2, 2], ["bedroom", "hall", "library"])
			_col(out, CENTER - 2, CENTER + 45, 0, 3, "wood")
			_col(out, CENTER - 2, CENTER + 45, 3, 1, "lamp")
			_col(out, CENTER + 2, CENTER + 45, 0, 3, "wood")
			_col(out, CENTER + 2, CENTER + 45, 3, 1, "lamp")
		"inn":
			# مسافرخانهٔ چوبی با دو اتاق خواب و تالار غذاخوری
			_room_house(out, CENTER - 18, CENTER + 40, 5, 4, 3, "wood", [-2, 1], ["bedroom", "bedroom", "hall"])
			_col(out, CENTER - 18, CENTER + 45, 0, 3, "wood")
			_col(out, CENTER - 18, CENTER + 45, 3, 1, "lamp")
		"townhouses":
			# ردیف سه خانهٔ شهری ۹×۷ با اتاق‌های جدا (خواب/آشپزخانه، انبار/مغازه)
			var kinds: Array = [["bedroom", "kitchen"], ["store", "shop"], ["library", "bedroom"]]
			for k in range(3):
				_room_house(out, CENTER + 18 + k * 10, CENTER + 40, 4, 3, 3, "brick" if k != 1 else "wood", [-1], kinds[k])
		"stone_keep":
			# برج‌خانهٔ سنگی ۱۱×۹ با شومینه، تالار و انبار (قلعه)
			_room_house(out, CENTER + 36, CENTER - 30, 5, 4, 5, "stone", [-2, 2], ["hearth", "hall", "store"])
		"hall_rooms":
			# تالار چوبی بلند زمستانی با شومینهٔ سنگی، تالار و اتاق خواب
			_room_house(out, CENTER + 40, CENTER - 14, 5, 4, 4, "wood", [-2, 2], ["hearth", "hall", "bedroom"])
			_col(out, CENTER + 40, CENTER - 9, 0, 1, "lamp")
		"ice_cabins":
			# دو کلبهٔ چوبی کوچک با دو اتاق (انبار + خواب)
			_room_house(out, CENTER - 40, CENTER - 20, 4, 3, 3, "wood", [-1], ["store", "bedroom"])
			_room_house(out, CENTER - 40, CENTER - 32, 4, 3, 3, "wood", [-1], ["hearth", "bedroom"])
		"fisher_hut":
			# کلبهٔ ماهیگیر با انبار تور و اتاق خواب
			_room_house(out, CENTER + 30, CENTER - 14, 4, 3, 3, "wood", [-1], ["store", "bedroom"])
			_col(out, CENTER + 30, CENTER - 10, 0, 1, "lamp")
		"adobe_quarter":
			# سه خانهٔ آجری صحرایی هر کدام با دو اتاق، پشت‌سر هم کنار کاروانسرا
			var plan: Array = [["bedroom", "kitchen"], ["store", "hall"], ["library", "bedroom"]]
			for k in range(3):
				_room_house(out, CENTER + 44, CENTER - 14 - k * 9, 4, 3, 3, "brick", [-1], plan[k])
		"guild_hall":
			# تالار اصناف: سه اتاق (غرفه، تالار، انبار) با دیوار آجری
			_room_house(out, CENTER - 24, CENTER - 38, 6, 4, 4, "brick", [-2, 2], ["shop", "hall", "store"])
		"well":
			# چاه سنگی با چهار تیرک و سقف کوچک
			var wx := CENTER + 10
			var wz := CENTER + 28
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx != 0 or dz != 0:
						_col(out, wx + dx, wz + dz, 0, 1, "stone")
			for c in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				_col(out, wx + c.x, wz + c.y, 1, 2, "wood")
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_col(out, wx + dx, wz + dz, 3, 1, "roof")
		"obelisk":
			# ستون یادبود: پایهٔ آجری ۳×۳، ستون سنگی بلند و چراغ بالا
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_col(out, CENTER + dx, CENTER - 44 + dz, 0, 2, "brick")
			_col(out, CENTER, CENTER - 44, 2, 8, "stone")
			_col(out, CENTER, CENTER - 44, 10, 1, "lamp")
		"stable":
			# طویلهٔ حصارکشی‌شده با سایبان چوبی نیمهٔ پشتی
			var sx := CENTER + 46
			var sz := CENTER + 30
			for dx in range(-4, 5):
				for dz in range(-3, 4):
					if maxi(absi(dx), absi(dz)) == 4 or absi(dz) == 3:
						if dx == 0 and dz == 3:
							continue   # دروازه
						_col(out, sx + dx, sz + dz, 0, 1, "fence")
			for dx in [-3, 3]:
				_col(out, sx + dx, sz - 2, 0, 2, "wood")
			for dx in range(-3, 4):
				for dz in range(-2, 0):
					_col(out, sx + dx, sz + dz, 2, 1, "roof")
		"landing_pad":
			# سکوی فرود: دو حلقهٔ سنگی هم‌مرکز با چراغ در چهار گوشه (جهان فضایی؛ هم‌تراز با موشک)
			var px := CENTER + 28
			var pz := CENTER + 12
			_ring(out, px, pz, 5, 0, 1, "stone")
			_ring(out, px, pz, 3, 0, 1, "stone")
			for c in [Vector2i(-5, -5), Vector2i(5, -5), Vector2i(-5, 5), Vector2i(5, 5)]:
				_col(out, px + c.x, pz + c.y, 1, 1, "lamp")
			_level_group(out, 0, px, pz, 5, 5)
		"rocket":
			# موشک: بدنهٔ آجری ۳×۳ روی سکوی فرود، چهار باله، دماغهٔ شیشه‌ای و چراغ (جهان فضایی)
			var rx := CENTER + 28
			var rz := CENTER + 12
			_ring(out, rx, rz, 1, 0, 9, "brick")
			for c in [Vector2i(-2, -2), Vector2i(2, -2), Vector2i(-2, 2), Vector2i(2, 2)]:
				_col(out, rx + c.x, rz + c.y, 0, 3, "stone")
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					_col(out, rx + dx, rz + dz, 9, 1, "glass")
			_col(out, rx, rz, 10, 1, "lamp")
			_level_group(out, 0, rx, rz, 5, 5)
		"habitat_dome":
			# زیستگاه: گنبد شیشه‌ای بزرگ با درگاه و چراغ داخل؛ داخلش جا برای باغ و خانه است (جهان فضایی)
			_dome(out, CENTER - 30, CENTER + 6, [8, 8, 7, 6, 5, 4, 3, 2], "glass", true)
		"moon_lab":
			# آزمایشگاه سنگی با کتابخانه، انبار و اتاق خواب (جهان فضایی)
			_room_house(out, CENTER + 38, CENTER - 24, 5, 4, 4, "stone", [-2, 2], ["library", "store", "bedroom"])
			_col(out, CENTER + 38, CENTER - 19, 0, 1, "lamp")
		"solar_field":
			# مزرعهٔ خورشیدی: سه ردیف تیرک با صفحهٔ شیشه‌ای بالای آن (جهان فضایی)
			for row in range(3):
				for k in range(7):
					var sx := CENTER - 50 + k * 2
					var sz := CENTER - 26 + row * 4
					_col(out, sx, sz, 0, 1, "fence")
					_col(out, sx, sz, 1, 1, "glass")
		"build_pads":
			# سه زمین ساخت با حاشیهٔ سنگی ۷×۷ برای تمرین ساخت
			for k in range(3):
				_ring(out, CENTER - 42, CENTER + 12 + k * 10, 3, 0, 1, "stone")

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
