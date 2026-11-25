extends RefCounted
## تمدن‌سازی (پروتکل ۴۵، حس WorldBox): کشورها، مرزها، رشد جمعیت، جنگ و صلح و اتحاد، قحطی و طاعون.
## همهٔ منطق قطعی و سمت سرور است؛ مدیر فقط «فرمان» می‌دهد و شبیه‌سازی خودش جلو می‌رود.
## این کلاس به بقیهٔ سرور وابسته نیست؛ چیزهای بیرونی (خشکی، مزرعه) با Callable داده می‌شود تا تست‌پذیر بماند.

const MAX_KINGDOMS := 6
const MAX_SETTLEMENTS := 8
const NAME_COUNT := 12
const COLOR_COUNT := 6
const STEP_SECONDS := 5.0           # هر گام شبیه‌سازی (ضرب در سرعت زمان جهان)
const MAX_STEPS_PER_TICK := 6
const START_POP := 12
const POP_PER_SETTLEMENT := 30
const POP_PER_FARM := 12
const MAX_FARM_BONUS := 20          # سقف شمار مزرعه‌هایی که به ظرفیت کمک می‌کنند
const EXPAND_POP := 25              # جمعیت لازم برای هر سکونتگاه برای ساخت سکونتگاه تازه
const SETTLE_RADIUS := 22.0         # شعاع مرز هر سکونتگاه (متر)
const MIN_CAPITAL_GAP := 80.0       # کمترین فاصلهٔ پایتخت تازه تا سکونتگاه‌های دیگر
const SETTLE_SELF_GAP := 15.0
const SETTLE_OTHER_GAP := 40.0
const WAR_RANGE := 120.0            # جنگ فقط وقتی جریان دارد که مرزها این‌قدر به هم نزدیک باشند
const WAR_LOSS := 0.05              # بخشی از جمعیت دشمن که هر گام کشته می‌شود
const COLLAPSE_POP := 3
const EVENT_SECONDS := 40.0         # طول قحطی و طاعون
const PLAGUE_LOSS := 0.12
const FAMINE_LOSS := 0.06
const GROWTH := 0.08
const STARVE_LOSS := 0.10
const LOG_MAX := 20
const PICK_RANGE := SETTLE_RADIUS + 6.0   # فاصلهٔ انتخاب کشور با لمس زمین

const PEACE := 0
const WAR := 1
const ALLY := 2

var items: Dictionary = {}      # id -> {id, n, c, pop, cap, s: [[x, z], ...], plague, famine, starving}
var rel: Dictionary = {}        # "کوچک,بزرگ" -> WAR | ALLY (نبودن کلید = صلح)
var history: Array = []         # [روز، کد، الف، ب] — جدیدترین آخر
var next_id: int = 1
var _acc: float = 0.0


static func pair_key(a: int, b: int) -> String:
	return "%d,%d" % [mini(a, b), maxi(a, b)]


func relation(a: int, b: int) -> int:
	return int(rel.get(pair_key(a, b), PEACE))


## عدد قطعی در [0,1) از سه عدد صحیح (بدون تصادفی).
static func _h(a: int, b: int, c: int) -> float:
	var v: int = absi((a * 73856093) ^ (b * 19349663) ^ (c * 83492791))
	return float(v % 1000) / 1000.0


## رویداد با «شمارهٔ نام» کشورها ثبت می‌شود (نه شناسه) تا بعد از حذف کشور هم نامش در تاریخچه بماند.
func _nm(id: int) -> int:
	return int(items[id]["n"]) if items.has(id) else 0


func _note(day: int, code: String, a: int, b: int = 0) -> void:
	history.append([day, code, _nm(a), _nm(b)])
	if history.size() > LOG_MAX:
		history = history.slice(history.size() - LOG_MAX)


func _land_ok(land: Callable, x: float, z: float) -> bool:
	return bool(land.call(x, z))


## کمترین فاصلهٔ x,z تا سکونتگاه‌های همهٔ کشورها به‌جز except_id.
func _nearest_other(x: float, z: float, except_id: int) -> float:
	var best := 1.0e9
	for id in items:
		if int(id) == except_id:
			continue
		for s in items[id]["s"]:
			best = minf(best, Vector2(float(s[0]), float(s[1])).distance_to(Vector2(x, z)))
	return best


func found(x: float, z: float, land: Callable, day: int) -> Dictionary:
	if not (is_finite(x) and is_finite(z)):
		return {"ok": false, "error": "bad_request"}
	if items.size() >= MAX_KINGDOMS:
		return {"ok": false, "error": "civ_full"}
	if not _land_ok(land, x, z):
		return {"ok": false, "error": "bad_place"}
	if _nearest_other(x, z, 0) < MIN_CAPITAL_GAP:
		return {"ok": false, "error": "civ_too_close"}
	var used := {}
	for id in items:
		used[int(items[id]["n"])] = true
	var nm := next_id % NAME_COUNT
	for i in range(NAME_COUNT):
		if not used.has(i):
			nm = i
			break
	var id := next_id
	next_id += 1
	items[id] = {"id": id, "n": nm, "c": id % COLOR_COUNT, "pop": START_POP, "cap": POP_PER_SETTLEMENT,
		"s": [[snappedf(x, 0.1), snappedf(z, 0.1)]], "plague": 0.0, "famine": 0.0, "starving": false}
	_note(day, "founded", id)
	return {"ok": true, "id": id}


## کشوری که مرزش روی نقطهٔ لمس‌شده است (نزدیک‌ترین)؛ 0 اگر هیچ‌کدام.
func kingdom_at(x: float, z: float) -> int:
	var best := 0
	var best_d := PICK_RANGE
	for id in items:
		for s in items[id]["s"]:
			var d := Vector2(float(s[0]), float(s[1])).distance_to(Vector2(x, z))
			if d <= best_d:
				best_d = d
				best = int(id)
	return best


func set_relation(a: int, b: int, r: int, day: int) -> String:
	if a == b or not items.has(a) or not items.has(b):
		return "civ_no_target"
	if r != PEACE and r != WAR and r != ALLY:
		return "bad_request"
	var cur := relation(a, b)
	if cur == r:
		return "civ_same"
	# جنگ و اتحاد مستقیم به هم تبدیل نمی‌شوند؛ ابتدا صلح.
	if cur != PEACE and r != PEACE:
		return "civ_need_peace"
	if r == PEACE:
		rel.erase(pair_key(a, b))
		_note(day, "peace", a, b)
		return ""
	rel[pair_key(a, b)] = r
	if r == WAR:
		_note(day, "war", a, b)
		# متحدها وارد جنگ می‌شوند (مگر با دشمن هم متحد باشند).
		_allies_join(a, b, day)
		_allies_join(b, a, day)
	else:
		_note(day, "alliance", a, b)
	return ""


func _allies_join(side: int, enemy: int, day: int) -> void:
	for id in items.keys():
		var k := int(id)
		if k == side or k == enemy:
			continue
		if relation(k, side) == ALLY and relation(k, enemy) == PEACE:
			rel[pair_key(k, enemy)] = WAR
			_note(day, "ally_joined", k, enemy)


func trigger(id: int, kind: String, day: int) -> String:
	if not items.has(id):
		return "civ_no_target"
	if kind == "plague":
		items[id]["plague"] = EVENT_SECONDS
	elif kind == "famine":
		items[id]["famine"] = EVENT_SECONDS
	else:
		return "bad_request"
	_note(day, kind, id)
	return ""


func remove(id: int, day: int) -> bool:
	if not items.has(id):
		return false
	_note(day, "removed", id)
	items.erase(id)
	for key in rel.keys():
		var parts: PackedStringArray = str(key).split(",")
		if int(parts[0]) == id or int(parts[1]) == id:
			rel.erase(key)
	return true


## ظرفیت: هر سکونتگاه جا برای ۳۰ نفر دارد و هر مزرعه داخل مرز ۱۲ نفر دیگر را سیر می‌کند.
func capacity_of(k: Dictionary, farms: Callable) -> int:
	var f := 0
	for s in k["s"]:
		f += int(farms.call(float(s[0]), float(s[1]), SETTLE_RADIUS))
	return k["s"].size() * POP_PER_SETTLEMENT + mini(f, MAX_FARM_BONUS) * POP_PER_FARM


## با سرعت زمان جهان جلو می‌رود (سرعت صفر = توقف). برمی‌گرداند: آیا چیزی تغییر کرد.
func step(delta: float, time_speed: float, land: Callable, farms: Callable, day: int) -> bool:
	if items.is_empty() or time_speed <= 0.0:
		return false
	_acc += delta * time_speed
	var changed := false
	var n := 0
	while _acc >= STEP_SECONDS and n < MAX_STEPS_PER_TICK:
		_acc -= STEP_SECONDS
		n += 1
		step_once(land, farms, day)
		changed = true
	if _acc > STEP_SECONDS * MAX_STEPS_PER_TICK:
		_acc = 0.0
	return changed


func step_once(land: Callable, farms: Callable, day: int) -> void:
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		var k: Dictionary = items[id]
		var pop: int = int(k["pop"])
		var cap: int = capacity_of(k, farms)
		k["cap"] = cap
		if float(k["plague"]) > 0.0:
			pop -= maxi(1, int(pop * PLAGUE_LOSS))
			k["plague"] = maxf(0.0, float(k["plague"]) - STEP_SECONDS)
		if float(k["famine"]) > 0.0:
			pop -= maxi(1, int(pop * FAMINE_LOSS))
			k["famine"] = maxf(0.0, float(k["famine"]) - STEP_SECONDS)
		elif pop < cap:
			pop = mini(cap, pop + maxi(1, int(pop * GROWTH)))
		elif pop > int(cap * 1.2):
			pop -= maxi(1, int(pop * STARVE_LOSS))
		pop = maxi(pop, 0)
		var starving: bool = pop > cap and cap > 0
		if starving and not bool(k["starving"]):
			_note(day, "starving", int(id))
		k["starving"] = starving
		k["pop"] = pop
		_expand(k, land, day)
	_wars(day)
	_collapse(day)


func _expand(k: Dictionary, land: Callable, day: int) -> void:
	var count: int = k["s"].size()
	if count >= MAX_SETTLEMENTS or int(k["pop"]) < EXPAND_POP * count:
		return
	var base: Array = k["s"][count - 1]
	for t in range(8):
		var ang := TAU * _h(int(k["id"]), count, t)
		var dist := 18.0 + 12.0 * _h(int(k["id"]), count + 31, t)
		var x := float(base[0]) + cos(ang) * dist
		var z := float(base[1]) + sin(ang) * dist
		if not _land_ok(land, x, z):
			continue
		var near_own := false
		for s in k["s"]:
			if Vector2(float(s[0]), float(s[1])).distance_to(Vector2(x, z)) < SETTLE_SELF_GAP:
				near_own = true
				break
		if near_own or _nearest_other(x, z, int(k["id"])) < SETTLE_OTHER_GAP:
			continue
		k["s"].append([snappedf(x, 0.1), snappedf(z, 0.1)])
		_note(day, "grew", int(k["id"]))
		return


func min_distance(a: int, b: int) -> float:
	var best := 1.0e9
	for sa in items[a]["s"]:
		for sb in items[b]["s"]:
			best = minf(best, Vector2(float(sa[0]), float(sa[1])).distance_to(Vector2(float(sb[0]), float(sb[1]))))
	return best


func _wars(_day: int) -> void:
	var loss := {}
	for key in rel:
		if int(rel[key]) != WAR:
			continue
		var parts: PackedStringArray = str(key).split(",")
		var a := int(parts[0])
		var b := int(parts[1])
		if not items.has(a) or not items.has(b) or min_distance(a, b) > WAR_RANGE:
			continue
		loss[a] = int(loss.get(a, 0)) + maxi(1, int(int(items[b]["pop"]) * WAR_LOSS))
		loss[b] = int(loss.get(b, 0)) + maxi(1, int(int(items[a]["pop"]) * WAR_LOSS))
	for id in loss:
		items[id]["pop"] = maxi(0, int(items[id]["pop"]) - int(loss[id]))


## کشور تقریباً نابودشده: اگر دشمنی نزدیک باشد فتح می‌شود، وگرنه از بین می‌رود.
func _collapse(day: int) -> void:
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		if not items.has(id):
			continue
		var k: Dictionary = items[id]
		if int(k["pop"]) > COLLAPSE_POP:
			continue
		var winner := 0
		var best_pop := -1
		for other in items:
			if int(other) == int(id) or relation(int(id), int(other)) != WAR or min_distance(int(id), int(other)) > WAR_RANGE:
				continue
			if int(items[other]["pop"]) > best_pop:
				best_pop = int(items[other]["pop"])
				winner = int(other)
		if winner > 0:
			var w: Dictionary = items[winner]
			for s in k["s"]:
				if w["s"].size() < MAX_SETTLEMENTS:
					w["s"].append(s)
			w["pop"] = int(w["pop"]) + 5
			_note(day, "conquered", winner, int(id))
			remove(int(id), day)
			history.pop_back()   # «حذف» در فهرست رویدادها تکراری است
		elif int(k["pop"]) <= 0:
			_note(day, "extinct", int(id))
			remove(int(id), day)
			history.pop_back()


func public() -> Dictionary:
	var kl: Array = []
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		var k: Dictionary = items[id]
		kl.append([int(id), int(k["n"]), int(k["c"]), int(k["pop"]), int(k["cap"]),
			1 if float(k["plague"]) > 0.0 else 0, 1 if float(k["famine"]) > 0.0 else 0, k["s"].duplicate(true)])
	var rl: Array = []
	for key in rel:
		var parts: PackedStringArray = str(key).split(",")
		rl.append([int(parts[0]), int(parts[1]), int(rel[key])])
	return {"k": kl, "rel": rl, "log": history.duplicate(true)}


func to_dict() -> Dictionary:
	var out := {}
	for id in items:
		var k: Dictionary = items[id]
		out[str(id)] = {"n": int(k["n"]), "c": int(k["c"]), "pop": int(k["pop"]), "s": k["s"].duplicate(true),
			"plague": snappedf(float(k["plague"]), 0.1), "famine": snappedf(float(k["famine"]), 0.1)}
	return {"next": next_id, "items": out, "rel": rel.duplicate(), "log": history.duplicate(true)}


func load_dict(d: Variant) -> void:
	items.clear()
	rel.clear()
	history.clear()
	next_id = 1
	_acc = 0.0
	if not (d is Dictionary):
		return
	next_id = maxi(1, int(d.get("next", 1)))
	var src: Variant = d.get("items", {})
	if src is Dictionary:
		for key in src:
			var v: Variant = src[key]
			var id := int(key)
			if not (v is Dictionary) or id <= 0 or items.size() >= MAX_KINGDOMS:
				continue
			var sl: Array = []
			for s in v.get("s", []):
				if s is Array and s.size() >= 2 and is_finite(float(s[0])) and is_finite(float(s[1])) and sl.size() < MAX_SETTLEMENTS:
					sl.append([float(s[0]), float(s[1])])
			if sl.is_empty():
				continue
			items[id] = {"id": id, "n": clampi(int(v.get("n", 0)), 0, NAME_COUNT - 1), "c": clampi(int(v.get("c", 0)), 0, COLOR_COUNT - 1),
				"pop": clampi(int(v.get("pop", START_POP)), 0, 100000), "cap": POP_PER_SETTLEMENT, "s": sl,
				"plague": clampf(float(v.get("plague", 0.0)), 0.0, EVENT_SECONDS), "famine": clampf(float(v.get("famine", 0.0)), 0.0, EVENT_SECONDS),
				"starving": false}
			next_id = maxi(next_id, id + 1)
	var rs: Variant = d.get("rel", {})
	if rs is Dictionary:
		for key in rs:
			var parts: PackedStringArray = str(key).split(",")
			if parts.size() != 2:
				continue
			var a := int(parts[0])
			var b := int(parts[1])
			var r := int(rs[key])
			if a < b and items.has(a) and items.has(b) and (r == WAR or r == ALLY):
				rel[pair_key(a, b)] = r
	var hl: Variant = d.get("log", [])
	if hl is Array:
		for e in hl:
			if e is Array and e.size() >= 4 and history.size() < LOG_MAX:
				history.append([int(e[0]), str(e[1]).substr(0, 16), int(e[2]), int(e[3])])
