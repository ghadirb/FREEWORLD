extends RefCounted
## جنگ، عقب‌نشینی و مذاکرهٔ شخصیت‌های هوشمند مستقل (پروتکل ۵۴، مرحلهٔ ۵ تکمیلی). فقط روی سرور.
## جنگ بین دو شخصیت است (نه با بازیکن) و کوچک و کران‌دار طراحی شده: هر شخصیت یک «جان جنگی» جدا دارد
## (`ai["war"]["hp"]`) که با حساب سایه و جان بازیکن کاری ندارد؛ هیچ شخصیتی دائماً نمی‌میرد و بازنده فقط
## عقب می‌نشیند، خراج می‌دهد و آن را به خاطر می‌سپارد. دیوار دفاعی (char_fortify) واقعاً ضربه را کم می‌کند.
##
## ساختار (`ai["war"]`):
##   "foes":  {حساب: {since: روز، ticks: شمارندهٔ گام، agg: آیا اعلام‌کننده بوده}}
##   "hp":    جان جنگی ۰ تا ۱۰۰ (آرام‌آرام بازمی‌گردد)
##   "away":  ثانیه‌های باقی‌ماندهٔ عقب‌نشینی (در این مدت نه می‌جنگد و نه به او حمله می‌شود)
##   "truce": {حساب: روزی که آتش‌بس تمام می‌شود}
## تصمیم‌ها قطعی‌اند (بدون عدد تصادفی) و بر پایهٔ ویژگی‌ها، جان، قدرت، دیوار و متحدها گرفته می‌شوند.

const FWConst = preload("res://scripts/core/const.gd")
const Memory = preload("res://scripts/server/char_memory.gd")
const Fortify = preload("res://scripts/server/char_fortify.gd")

const TICK_SECONDS := 5.0
const FIGHT_RANGE := 14.0          # فاصلهٔ درگیری
const MARCH_RANGE := 120.0         # فقط به دشمن نزدیک لشکر می‌کشد
const HP_MAX := 100.0
const HP_REGEN := 1.5              # در هر گام
const BASE_DAMAGE := 8.0           # ضربهٔ هر دور در قدرت برابر
const RETREAT_SECONDS := 45.0
const FOES_MAX := 2
const WAR_MIN_AGGRESSION := 0.55
const WAR_MIN_BRAVERY := 0.4
const WALL_PROTECTION := 0.35      # دیوار کامل این مقدار از ضربه را کم می‌کند
const WALL_RANGE := 14.0           # فقط نزدیک خانهٔ خودش دیوار کمک می‌کند
const ALLY_BONUS := 0.15
const ALLY_RANGE := 30.0
const TRUCE_DAYS := 2
const MAX_WAR_DAYS := 2            # جنگ بی‌نتیجه بیشتر از این به آتش‌بس اجباری می‌رسد
const TRIBUTE_MAX := 40
const TRIBUTE_SHARE := 0.2


static func fresh() -> Dictionary:
	return {"foes": {}, "hp": HP_MAX, "away": 0.0, "truce": {}}


static func _ai(npc: Dictionary) -> Dictionary:
	return npc["ai"]


static func _w(npc: Dictionary) -> Dictionary:
	return npc["ai"]["war"]


static func _pos(npc: Dictionary) -> Vector2:
	return Vector2(float(npc["x"]), float(npc["z"]))


static func enabled(cs) -> bool:
	return bool(cs.ai_settings.get("war", true))


static func at_war(a: Dictionary, b: Dictionary) -> bool:
	return (_w(a)["foes"] as Dictionary).has(str(b["acct"]))


static func in_war(npc: Dictionary) -> bool:
	return not (_w(npc)["foes"] as Dictionary).is_empty()


static func retreating(npc: Dictionary) -> bool:
	return float(_w(npc)["away"]) > 0.0


static func hp_frac(npc: Dictionary) -> float:
	return clampf(float(_w(npc)["hp"]) / HP_MAX, 0.0, 1.0)


## بازیابی ایمن از فایل ذخیره: مقادیر خراب اصلاح می‌شود، ذخیره‌های قدیمی (بدون جنگ) سالم لود می‌شوند.
static func load_war(raw: Variant) -> Dictionary:
	var w := fresh()
	if not (raw is Dictionary):
		return w
	w["hp"] = clampf(float(raw.get("hp", HP_MAX)), 0.0, HP_MAX)
	w["away"] = clampf(float(raw.get("away", 0.0)), 0.0, RETREAT_SECONDS)
	var rf: Variant = raw.get("foes", {})
	if rf is Dictionary:
		for k in rf:
			var e: Variant = rf[k]
			if str(k).begins_with("ai:") and e is Dictionary and (w["foes"] as Dictionary).size() < FOES_MAX:
				w["foes"][str(k)] = {"since": maxi(0, int(e.get("since", 0))), "ticks": clampi(int(e.get("ticks", 0)), 0, 100000), "agg": bool(e.get("agg", false))}
	var rt: Variant = raw.get("truce", {})
	if rt is Dictionary:
		for k in rt:
			if str(k).begins_with("ai:") and (w["truce"] as Dictionary).size() < 12:
				w["truce"][str(k)] = maxi(0, int(rt[k]))
	return w


# ---------------- قدرت و دیوار ----------------

## موقعیت خانهٔ شخصیت؛ اگر خانه ندارد، میدان شهر.
static func home_of(cs, npc: Dictionary) -> Vector2:
	var house: Dictionary = Fortify.house_of(cs, str(npc["acct"]))
	if house.is_empty():
		return Vector2(FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5 - 4.0)
	var size: Array = FWConst.building_size("house")
	return Vector2(float(house["cx"]) + float(size[0]) * 0.5, float(house["cz"]) + float(size[1]) * 0.5)


## چند درصد دیوار (و برج) واقعاً در جهان ساخته شده؛ ۰ تا ۱.
static func wall_intact(cs, npc: Dictionary) -> float:
	var house: Dictionary = Fortify.house_of(cs, str(npc["acct"]))
	if house.is_empty():
		return 0.0
	var cells: Array = Fortify.target_cells(cs, house, Fortify.wants_towers(_ai(npc)))
	if cells.is_empty():
		return 0.0
	var built := 0
	for v in cells:
		if cs.blocks.has(v):
			built += 1
	return float(built) / float(cells.size())


## ضریب ضربهٔ دریافتی: دیوار فقط وقتی کار می‌کند که مدافع نزدیک خانهٔ خودش باشد.
static func damage_taken_factor(cs, npc: Dictionary) -> float:
	if _pos(npc).distance_to(home_of(cs, npc)) > WALL_RANGE:
		return 1.0
	return 1.0 - WALL_PROTECTION * wall_intact(cs, npc)


## متحدهای نزدیکی که با دشمنِ این شخصیت جنگ ندارند و کمک می‌کنند.
static func ally_support(cs, npc: Dictionary, foe: Dictionary) -> float:
	var n := 0
	for other in cs.npcs:
		if other == npc or other == foe or not (other.get("ai", null) is Dictionary):
			continue
		if not (_ai(npc)["allies"] as Dictionary).has(str(other["acct"])):
			continue
		if _pos(other).distance_to(_pos(npc)) <= ALLY_RANGE and not retreating(other):
			n += 1
	return 1.0 + ALLY_BONUS * float(mini(n, 2))


static func power(cs, npc: Dictionary, foe: Dictionary) -> float:
	var t: Dictionary = _ai(npc)["traits"]
	var gear: Dictionary = cs.accounts[str(npc["acct"])].get("gear", {})
	var kit: float = 1.0 + 0.1 * float(int(gear.get("weapon", 0)) + int(gear.get("armor", 0)))
	return maxf(1.0, float(_w(npc)["hp"])) * (0.6 + 0.4 * float(t["bravery"])) * kit * ally_support(cs, npc, foe)


## آستانهٔ عقب‌نشینی (جان جنگی): شجاع دیرتر، محتاط زودتر عقب می‌نشیند.
static func retreat_threshold(npc: Dictionary) -> float:
	var t: Dictionary = _ai(npc)["traits"]
	return clampf(0.55 - 0.4 * float(t["bravery"]) + 0.25 * float(t["caution"]), 0.15, 0.7) * HP_MAX


# ---------------- اعلام جنگ ----------------

## آیا a می‌تواند به b اعلام جنگ کند؟ فقط دشمن، پرخاشگر و شجاع، سالم، بدون آتش‌بس و بدون اتحاد.
static func can_declare(cs, a: Dictionary, b: Dictionary) -> bool:
	if not enabled(cs) or a == b or at_war(a, b):
		return false
	var wa: Dictionary = _w(a)
	var kb := str(b["acct"])
	if (wa["foes"] as Dictionary).size() >= FOES_MAX or (_w(b)["foes"] as Dictionary).size() >= FOES_MAX:
		return false
	if int(wa["truce"].get(kb, -1)) > cs.day_count or int((_w(b)["truce"] as Dictionary).get(str(a["acct"]), -1)) > cs.day_count:
		return false
	if (_ai(a)["allies"] as Dictionary).has(kb) or retreating(a) or hp_frac(a) < 0.6:
		return false
	if Memory.stance(_ai(a), kb, cs.day_count) != "enemy":
		return false
	var t: Dictionary = _ai(a)["traits"]
	var betrayed: bool = Memory.remembers(_ai(a), kb, "betray")
	return (float(t["aggression"]) >= WAR_MIN_AGGRESSION or betrayed) and float(t["bravery"]) >= WAR_MIN_BRAVERY


## اعلام جنگ بین دو شخصیت دشمن؛ اول پرخاشگرتر. true اگر جنگی شروع شد.
static func try_declare(cs, a: Dictionary, b: Dictionary) -> bool:
	var first: Dictionary = a
	var second: Dictionary = b
	if float(_ai(b)["traits"]["aggression"]) > float(_ai(a)["traits"]["aggression"]):
		first = b
		second = a
	for pair in [[first, second], [second, first]]:
		var agg: Dictionary = pair[0]
		var tgt: Dictionary = pair[1]
		if can_declare(cs, agg, tgt):
			var day: int = cs.day_count
			_w(agg)["foes"][str(tgt["acct"])] = {"since": day, "ticks": 0, "agg": true}
			_w(tgt)["foes"][str(agg["acct"])] = {"since": day, "ticks": 0, "agg": false}
			Memory.record(_ai(agg), "war", str(tgt["acct"]), 0.6, day)
			Memory.record(_ai(tgt), "war", str(agg["acct"]), 0.8, day)
			_ai(agg)["stats"]["wars"] = int(_ai(agg)["stats"].get("wars", 0)) + 1
			_ai(tgt)["stats"]["wars"] = int(_ai(tgt)["stats"].get("wars", 0)) + 1
			_note(cs, agg, "war:" + str(tgt["name"]))
			_note(cs, tgt, "war_on_me:" + str(agg["name"]))
			cs.ai_events.append({"kind": "war", "a": str(agg["name"]), "b": str(tgt["name"])})
			return true
	return false


# ---------------- حرکت: لشکرکشی و عقب‌نشینی ----------------

## گام «لشکرکشی» برای اعلام‌کننده‌ای که دشمن نزدیکی دارد و هنوز به او نرسیده. خالی = کاری ندارد.
static func march_plan(cs, npc: Dictionary) -> Array:
	if not enabled(cs) or retreating(npc) or hp_frac(npc) < 0.7:
		return []
	var foes: Dictionary = _w(npc)["foes"]
	for k in foes:
		if not bool(foes[k]["agg"]):
			continue
		for other in cs.npcs:
			if str(other.get("acct", "")) != str(k) or not (other.get("ai", null) is Dictionary):
				continue
			var d: float = _pos(npc).distance_to(_pos(other))
			if d > FIGHT_RANGE * 0.6 and d <= MARCH_RANGE:
				return [{"t": "march", "x": float(other["x"]), "z": float(other["z"]), "k": str(k)}]
	return []


static func retreat_step(cs, npc: Dictionary) -> Dictionary:
	var h: Vector2 = home_of(cs, npc)
	return {"t": "retreat", "x": h.x, "z": h.y}


# ---------------- چرخهٔ جنگ ----------------

static func _find(cs, acct: String) -> Dictionary:
	for n in cs.npcs:
		if str(n.get("acct", "")) == acct and n.get("ai", null) is Dictionary:
			return n
	return {}


## یک گام دوره‌ای برای همهٔ جنگ‌ها. dt ثانیه از گام قبلی.
static func tick(cs, dt: float) -> void:
	cs.war_t = float(cs.war_t) + dt
	if float(cs.war_t) < TICK_SECONDS:
		return
	var step: float = float(cs.war_t)
	cs.war_t = 0.0
	if not enabled(cs):
		_stand_down(cs)
		return
	var fought := {}
	var seen := {}
	for a in cs.npcs:
		if not (a.get("ai", null) is Dictionary) or not (_ai(a).get("war", null) is Dictionary):
			continue
		var wa: Dictionary = _w(a)
		wa["away"] = maxf(0.0, float(wa["away"]) - step)
		for kb in (wa["foes"] as Dictionary).keys():
			var b: Dictionary = _find(cs, str(kb))
			if b.is_empty() or not cs.accounts.has(str(a["acct"])) or not cs.accounts.has(str(kb)):
				(wa["foes"] as Dictionary).erase(kb)       # حریف دیگر وجود ندارد
				continue
			var pair_key: String = str(a["acct"]) + "|" + str(kb) if str(a["acct"]) < str(kb) else str(kb) + "|" + str(a["acct"])
			if seen.has(pair_key):
				continue
			seen[pair_key] = true
			_war_step(cs, a, b, fought)
	# جان جنگی کم‌کم برمی‌گردد (کسی که درگیر نبوده)
	for n in cs.npcs:
		if n.get("ai", null) is Dictionary and _ai(n).get("war", null) is Dictionary and not fought.has(str(n["acct"])):
			_w(n)["hp"] = minf(HP_MAX, float(_w(n)["hp"]) + HP_REGEN * (2.0 if _pos(n).distance_to(home_of(cs, n)) <= WALL_RANGE else 1.0))


static func _war_step(cs, a: Dictionary, b: Dictionary, fought: Dictionary) -> void:
	var ka := str(a["acct"])
	var kb := str(b["acct"])
	var ea: Dictionary = _w(a)["foes"][kb]
	ea["ticks"] = int(ea["ticks"]) + 1
	if _w(b)["foes"].has(ka):
		_w(b)["foes"][ka]["ticks"] = int(ea["ticks"])
	# درگیری فقط وقتی نزدیک‌اند و هیچ‌کدام در حال عقب‌نشینی نیست
	if not retreating(a) and not retreating(b) and _pos(a).distance_to(_pos(b)) <= FIGHT_RANGE:
		var pa: float = power(cs, a, b)
		var pb: float = power(cs, b, a)
		var ra: float = pa / (pa + pb)
		var dmg_b: float = BASE_DAMAGE * 2.0 * ra * damage_taken_factor(cs, b)
		var dmg_a: float = BASE_DAMAGE * 2.0 * (1.0 - ra) * damage_taken_factor(cs, a)
		_w(b)["hp"] = maxf(0.0, float(_w(b)["hp"]) - dmg_b)
		_w(a)["hp"] = maxf(0.0, float(_w(a)["hp"]) - dmg_a)
		fought[ka] = true
		fought[kb] = true
		for pair in [[a, b], [b, a]]:
			var me: Dictionary = pair[0]
			var foe: Dictionary = pair[1]
			if float(_w(me)["hp"]) <= retreat_threshold(me):
				_retreat(cs, me, foe)
	_negotiate(cs, a, b)


static func _retreat(cs, npc: Dictionary, foe: Dictionary) -> void:
	_w(npc)["away"] = RETREAT_SECONDS
	_ai(npc)["plan"] = [retreat_step(cs, npc)]
	_ai(npc)["active"] = {}
	_ai(npc)["w"] = 0.0
	_ai(npc)["stats"]["retreats"] = int(_ai(npc)["stats"].get("retreats", 0)) + 1
	_note(cs, npc, "retreat:" + str(foe["name"]))
	cs.ai_events.append({"kind": "retreat", "a": str(npc["name"]), "b": str(foe["name"])})


# ---------------- مذاکره و صلح ----------------

## میل به صلح (۰ تا حدود ۱٫۵): زخمی، محتاط، همکارجو و خسته‌شده بیشتر؛ پرخاشگر و جاه‌طلب کمتر.
static func peace_desire(npc: Dictionary, ticks: int) -> float:
	var t: Dictionary = _ai(npc)["traits"]
	var d: float = (1.0 - hp_frac(npc)) * 0.8 + 0.3 * float(t["caution"]) + 0.3 * float(t["cooperation"]) \
		- 0.4 * float(t["aggression"]) - 0.1 * float(t["ambition"]) + 0.5 * minf(1.0, float(ticks) / 120.0)
	if retreating(npc):
		d += 0.4
	return d


## آیا این دو الآن صلح می‌کنند؟ یک طرف پیشنهاد می‌دهد (میل ≥ ۰٫۴۵) و طرف دیگر می‌پذیرد (میل ≥ ۰٫۲۵).
static func peace_accepted(a: Dictionary, b: Dictionary, ticks: int) -> bool:
	var da: float = peace_desire(a, ticks)
	var db: float = peace_desire(b, ticks)
	return (maxf(da, db) >= 0.45 and minf(da, db) >= 0.25)


static func _negotiate(cs, a: Dictionary, b: Dictionary) -> void:
	var ticks: int = int(_w(a)["foes"][str(b["acct"])]["ticks"])
	var stale: bool = cs.day_count - int(_w(a)["foes"][str(b["acct"])]["since"]) >= MAX_WAR_DAYS
	if stale or peace_accepted(a, b, ticks):
		make_peace(cs, a, b)


## پایان جنگ: برنده خراج می‌گیرد (پول فقط بین دو کیف جابه‌جا می‌شود)، هر دو به خاطر می‌سپارند، آتش‌بس شروع می‌شود.
static func make_peace(cs, a: Dictionary, b: Dictionary) -> void:
	var ka := str(a["acct"])
	var kb := str(b["acct"])
	var day: int = cs.day_count
	var winner: Dictionary = a if hp_frac(a) >= hp_frac(b) else b
	var loser: Dictionary = b if winner == a else a
	var tribute := 0
	var gap: float = absf(hp_frac(a) - hp_frac(b))
	if gap >= 0.15:    # برد روشن؛ در تساوی خراجی نیست
		var la: Dictionary = cs.accounts[str(loser["acct"])]
		tribute = mini(TRIBUTE_MAX, int(floor(float(int(la["money"])) * TRIBUTE_SHARE)))
		if tribute > 0:
			la["money"] = int(la["money"]) - tribute
			cs._gain(cs.accounts[str(winner["acct"])], tribute)
		Memory.record(_ai(winner), "war_win", str(loser["acct"]), 0.7, day)
		Memory.record(_ai(loser), "war_loss", str(winner["acct"]), 0.8, day)
		Memory.learn(_ai(winner), true, _base(winner))
		Memory.learn(_ai(loser), false, _base(loser))
		_ai(winner)["stats"]["won"] = int(_ai(winner)["stats"].get("won", 0)) + 1
		_ai(loser)["stats"]["lost"] = int(_ai(loser)["stats"].get("lost", 0)) + 1
	Memory.record(_ai(a), "peace", kb, 0.6, day)
	Memory.record(_ai(b), "peace", ka, 0.6, day)
	(_w(a)["foes"] as Dictionary).erase(kb)
	(_w(b)["foes"] as Dictionary).erase(ka)
	_w(a)["truce"][kb] = day + TRUCE_DAYS
	_w(b)["truce"][ka] = day + TRUCE_DAYS
	for n in [a, b]:
		_clear_war_plan(n)
		_note(cs, n, "peace:" + str((b if n == a else a)["name"]))
	cs.ai_events.append({"kind": "peace", "a": str(winner["name"]), "b": str(loser["name"]), "tribute": tribute})


static func _base(npc: Dictionary) -> Dictionary:
	var Personality = load("res://scripts/server/char_personality.gd")
	return Personality.traits_for(str(_ai(npc)["arch"]), int(npc["id"]))


static func _clear_war_plan(npc: Dictionary) -> void:
	var plan: Array = _ai(npc)["plan"]
	if not plan.is_empty() and str(plan[0].get("t", "")) in ["march", "retreat"]:
		_ai(npc)["plan"] = []
		_ai(npc)["w"] = 0.0


## جنگ غیرفعال شد (تنظیمات): همهٔ جنگ‌ها بدون خراج و خاطره پایان می‌یابند.
static func _stand_down(cs) -> void:
	for n in cs.npcs:
		if n.get("ai", null) is Dictionary and _ai(n).get("war", null) is Dictionary and in_war(n):
			(_w(n)["foes"] as Dictionary).clear()
			_w(n)["away"] = 0.0
			_clear_war_plan(n)


static func _note(cs, npc: Dictionary, what: String) -> void:
	var log: Array = _ai(npc)["log"]
	log.append("d%d %s" % [cs.day_count, what])
	while log.size() > 12:
		log.pop_front()
