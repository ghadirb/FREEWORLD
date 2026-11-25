extends RefCounted
## میدان‌های ساخته‌شده توسط بازیکن (لایهٔ سازنده، حس Roblox): بازیکن یک میدان «سکه‌یاب» با نام، شعاع،
## تعداد سکه، زمان و جایزهٔ هر سکه می‌سازد؛ بقیه می‌توانند داخل آن بازی کنند و رکورد جدا دارند.
## جایزه را سازنده از پول خودش می‌دهد (در جهان خلاقانه بدون سکه). این ماژول فقط تعریف میدان‌ها،
## اعتبارسنجی و چیدمان قطعی سکه‌ها را دارد؛ اجرای دور در minigame.gd و پرداخت در city_state.gd است.

const FWConst = preload("res://scripts/core/const.gd")

var items: Dictionary = {}   # شناسه ← {id, name, owner, x, z, r, coins, time, reward}
var next_id: int = 1
const PROP_TYPES := ["bonus", "hazard"]

var ratings: Dictionary = {}   # شناسهٔ میدان ← {نام بازیکن ← ستاره ۱ تا ۵} (پروتکل ۳۸)


static func clean_name(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		if ch.unicode_at(0) >= 32:
			out += ch
	return out.substr(0, FWConst.ARENA_NAME_MAX).strip_edges()


## نوع میدان: «coins» (سکه‌یاب)، «parkour» (ایستگاه‌ها به ترتیب) یا «race» (مسابقهٔ ماشین: دروازه‌های ترتیبی روی پیست حلقه‌ای)؛
## هر مقدار ناشناخته سکه‌یاب است.
static func clean_kind(raw: Variant) -> String:
	var k := str(raw)
	return k if k == "parkour" or k == "race" or k == "football" or k == "survival" else "coins"


## کمینهٔ تعداد هدف لازم برای ساخت: فوتبال فقط یک دروازه دارد.
static func need_targets(kind: String, coins: int) -> int:
	return 1 if kind == "football" or kind == "survival" else mini(coins, FWConst.ARENA_COINS_MIN)


## دروازهٔ فوتبال: یک نقطهٔ قطعی روی خشکی نزدیک لبهٔ میدان (۷۰ تا ۸۰٪ شعاع)؛ خروجی آرایهٔ تک‌عضوی یا خالی.
static func make_football_goal(world, seed_value: int, a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:goal:%d" % [seed_value, int(a.get("id", 0))])
	var center := Vector2(float(a["x"]), float(a["z"]))
	var r: float = float(a["r"])
	var base: float = rng.randf() * TAU
	for i in 8:
		var ang: float = base + TAU * float(i) / 8.0
		var c := center + Vector2(cos(ang), sin(ang)) * r * 0.75
		var h: float = world.height_at(c.x, c.y)
		if h >= 0.5 and h <= FWConst.MINIGAME_MAX_HEIGHT:
			return [Vector2(snappedf(c.x, 0.1), snappedf(c.y, 0.1))]
	return []


## نوع‌هایی که هدف‌هایشان به ترتیب ظاهر می‌شود (پارکور و مسابقه).
static func is_ordered(kind: String) -> bool:
	return kind == "parkour" or kind == "race"


## مانع متحرک فقط در پارکور (پروتکل ۳۹).
static func clamp_obs(kind: String, n: int) -> int:
	return clampi(n, 0, FWConst.ARENA_OBS_MAX) if kind == "parkour" else 0


## موانع متحرک: هر مانع روی یک پاره‌خط مماس بر حلقهٔ میدان با سرعت و فازِ قطعی (از Seed و شناسه) رفت‌وبرگشت می‌کند.
## هر مانع [ax, az, bx, bz, سرعت, فاز] است؛ موقعیتش فقط تابعی از ساعت دور است، پس کلاینت هم می‌تواند بکشدش.
static func make_obstacles(seed_value: int, a: Dictionary) -> Array:
	var n: int = int(a.get("obs", 0))
	var out: Array = []
	if n <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:obs:%d:%d" % [seed_value, int(a.get("id", 0)), n])
	var center := Vector2(float(a["x"]), float(a["z"]))
	var r: float = float(a["r"])
	for i in n:
		var ang: float = TAU * (float(i) + rng.randf() * 0.6) / float(n)
		var mid := center + Vector2(cos(ang), sin(ang)) * r * lerpf(0.4, 0.8, rng.randf())
		var tangent := Vector2(-sin(ang), cos(ang)) * minf(r * 0.35, 4.0)
		var p0 := mid - tangent
		var p1 := mid + tangent
		out.append([snappedf(p0.x, 0.1), snappedf(p0.y, 0.1), snappedf(p1.x, 0.1), snappedf(p1.y, 0.1),
			snappedf(lerpf(0.8, 1.7, rng.randf()), 0.01), snappedf(rng.randf() * TAU, 0.01)])
	return out


## موقعیت مانع در ساعت دور clock (ثانیه).
static func obstacle_pos(d: Array, clock: float) -> Vector2:
	var k: float = 0.5 + 0.5 * sin(clock * float(d[4]) + float(d[5]))
	return Vector2(lerpf(float(d[0]), float(d[2]), k), lerpf(float(d[1]), float(d[3]), k))


## اشیای سفارشی: [نوع, x, z] داخل دایرهٔ میدان؛ نوع ناشناخته، بیرون از میدان یا بیش از سقف حذف می‌شود.
static func clean_props(raw: Variant, a: Dictionary) -> Array:
	var out: Array = []
	if not (raw is Array):
		return out
	var center := Vector2(float(a["x"]), float(a["z"]))
	for p in raw:
		if out.size() >= FWConst.ARENA_PROPS_MAX:
			break
		if not (p is Array) or p.size() != 3 or not PROP_TYPES.has(str(p[0])):
			continue
		var x := float(p[1])
		var z := float(p[2])
		if not (is_finite(x) and is_finite(z)) or Vector2(x, z).distance_to(center) > float(a["r"]):
			continue
		out.append([str(p[0]), x, z])
	return out


## کد اشتراک میدان: «FWA1:» + Base64 یک JSON کوچک. اشیا نسبت به مرکز میدان ذخیره می‌شوند تا هر جا قابل ساخت باشد.
static func export_code(a: Dictionary) -> String:
	var center := Vector2(float(a["x"]), float(a["z"]))
	var props: Array = []
	for p in (a.get("props", []) as Array):
		props.append([str(p[0]), snappedf(float(p[1]) - center.x, 0.1), snappedf(float(p[2]) - center.y, 0.1)])
	var d := {"v": 1, "n": str(a["name"]), "k": clean_kind(a.get("kind", "coins")), "r": float(a["r"]), "c": int(a["coins"]),
		"t": float(a["time"]), "x": int(a["reward"]), "w": int(a.get("win", 0)), "o": int(a.get("obs", 0)), "p": props}
	return "FWA1:" + Marshalls.raw_to_base64(JSON.stringify(d).to_utf8_buffer())


## رمزگشایی کد اشتراک (ورودی نامطمئن): فقط مقادیر پاک‌سازی‌شده برمی‌گردد. خروجی {ok, def} یا {ok: false, error: "arena_code"}.
static func parse_code(code: String) -> Dictionary:
	var bad := {"ok": false, "error": "arena_code"}
	var txt := code.strip_edges()
	if txt.length() > FWConst.ARENA_CODE_MAX or not txt.begins_with("FWA1:"):
		return bad
	var raw := Marshalls.base64_to_raw(txt.substr(5))
	if raw.is_empty():
		return bad
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary) or int(parsed.get("v", 0)) != 1:
		return bad
	var nm := clean_name(str(parsed.get("n", "")))
	if nm.is_empty():
		return bad
	var props: Array = []
	var praw: Variant = parsed.get("p", [])
	if praw is Array:
		for p in praw:
			if props.size() >= FWConst.ARENA_PROPS_MAX:
				break
			if p is Array and p.size() == 3 and PROP_TYPES.has(str(p[0])) and (p[1] is float or p[1] is int) and (p[2] is float or p[2] is int):
				var dx := float(p[1])
				var dz := float(p[2])
				if is_finite(dx) and is_finite(dz) and absf(dx) <= FWConst.ARENA_R_MAX and absf(dz) <= FWConst.ARENA_R_MAX:
					props.append([str(p[0]), dx, dz])
	for k in ["r", "t"]:
		var v: Variant = parsed.get(k, 0)
		if not ((v is float or v is int) and is_finite(float(v))):
			return bad
	var kd := clean_kind(parsed.get("k", "coins"))
	return {"ok": true, "def": {"name": nm, "kind": kd, "r": float(parsed["r"]), "coins": int(parsed.get("c", FWConst.ARENA_COINS_MIN)),
		"time": float(parsed["t"]), "reward": int(parsed.get("x", 0)), "win": int(parsed.get("w", 0)), "obs": int(parsed.get("o", 0)), "props": props}}


static func clamp_count(kind: String, n: int) -> int:
	if kind == "football":
		return clampi(n, 1, FWConst.FOOT_GOALS_MAX)
	if kind == "survival":
		return clampi(n, 3, FWConst.SURV_COUNT_MAX)
	var hi: int = FWConst.ARENA_PARKOUR_MAX if is_ordered(kind) else FWConst.ARENA_COINS_MAX
	return clampi(n, FWConst.ARENA_COINS_MIN, hi)


## ایستگاه‌های پارکور: دور میدان به ترتیب زاویه، با فاصلهٔ متغیر از مرکز تا مسیر موج‌دار شود. قطعی از Seed و شناسه.
static func make_checkpoints(world, seed_value: int, a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:parkour:%d:%d" % [seed_value, int(a.get("id", 0)), int(a["coins"])])
	var center := Vector2(float(a["x"]), float(a["z"]))
	var r: float = float(a["r"])
	var n: int = int(a["coins"])
	var out: Array = []
	for i in n:
		for attempt in 4:
			var ang: float = TAU * (float(i) + rng.randf() * 0.4) / float(n)
			var dist: float = lerpf(r * 0.45, r * 0.95, rng.randf())
			var c := center + Vector2(cos(ang), sin(ang)) * dist
			var h: float = world.height_at(c.x, c.y)
			if h < 0.5 or h > FWConst.MINIGAME_MAX_HEIGHT:
				continue
			out.append(Vector2(snappedf(c.x, 0.1), snappedf(c.y, 0.1)))
			break
	return out


## دروازه‌های مسابقهٔ ماشین: یک پیست حلقه‌ای تقریباً گرد با فاصلهٔ ثابت از مرکز (نه موج‌دار مثل پارکور) تا با ماشین
## روان رانده شود. هر دروازه بر یک زاویهٔ مرتب با کمی انحراف قطعی از Seed می‌افتد؛ دروازهٔ روی آب یا کوه رد می‌شود.
static func make_race_gates(world, seed_value: int, a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:race:%d:%d" % [seed_value, int(a.get("id", 0)), int(a["coins"])])
	var center := Vector2(float(a["x"]), float(a["z"]))
	var r: float = float(a["r"])
	var n: int = int(a["coins"])
	var out: Array = []
	for i in n:
		var ang: float = TAU * (float(i) + rng.randf() * 0.2) / float(n)
		var dist: float = r * lerpf(0.72, 0.86, rng.randf())
		var c := center + Vector2(cos(ang), sin(ang)) * dist
		var h: float = world.height_at(c.x, c.y)
		if h < 0.5 or h > FWConst.MINIGAME_MAX_HEIGHT:
			continue
		out.append(Vector2(snappedf(c.x, 0.1), snappedf(c.y, 0.1)))
	return out


## نقطه‌های زایش دشمن در مبارزه و بقا: ۸ نقطهٔ قطعی روی حلقهٔ ۸۵٪ شعاع که روی خشکی‌اند.
static func make_survival_spawns(world, seed_value: int, a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:surv:%d" % [seed_value, int(a.get("id", 0))])
	var center := Vector2(float(a["x"]), float(a["z"]))
	var base: float = rng.randf() * TAU
	var out: Array = []
	for i in 8:
		var ang: float = base + TAU * float(i) / 8.0
		var c := center + Vector2(cos(ang), sin(ang)) * float(a["r"]) * 0.85
		var h: float = world.height_at(c.x, c.y)
		if h >= 0.5 and h <= FWConst.MINIGAME_MAX_HEIGHT:
			out.append(Vector2(snappedf(c.x, 0.1), snappedf(c.y, 0.1)))
	return out


## اهداف دور بر اساس نوع میدان: سکه‌های پخش‌شده، ایستگاه‌های مرتب یا دروازه‌های پیست.
static func make_targets(world, seed_value: int, player_name: String, counter: int, a: Dictionary) -> Array:
	var kd := clean_kind(a.get("kind", "coins"))
	if kd == "football":
		return make_football_goal(world, seed_value, a)
	if kd == "survival":
		return make_survival_spawns(world, seed_value, a)
	if kd == "race":
		return make_race_gates(world, seed_value, a)
	if kd == "parkour":
		return make_checkpoints(world, seed_value, a)
	return make_coins(world, seed_value, player_name, counter, a)


## چیدمان قطعی سکه‌ها درون دایرهٔ میدان، فقط روی خشکی کم‌ارتفاع.
static func make_coins(world, seed_value: int, player_name: String, counter: int, a: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d:%d" % [seed_value, player_name, counter, int(a.get("id", 0))])
	var center := Vector2(float(a["x"]), float(a["z"]))
	var r: float = float(a["r"])
	var want: int = int(a["coins"])
	var out: Array = []
	var tries := 0
	while out.size() < want and tries < 600:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := lerpf(1.5, r, sqrt(rng.randf()))
		var c := center + Vector2(cos(ang), sin(ang)) * dist
		var h: float = world.height_at(c.x, c.y)
		if h < 0.5 or h > FWConst.MINIGAME_MAX_HEIGHT:
			continue
		out.append(Vector2(snappedf(c.x, 0.1), snappedf(c.y, 0.1)))
	return out


## ویرایش میدان موجود (مکان ثابت می‌ماند): فقط سازنده یا مدیر. فاصله با میدان‌های دیگر و جای سکه‌ها دوباره
## بررسی می‌شود. خروجی {ok, arena} (میدان جدید، هنوز اعمال نشده) یا {ok: false, error}.
func validate_edit(world, seed_value: int, who: String, is_admin: bool, id: int, arena_name: String, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0, obstacles: int = 0) -> Dictionary:
	if not items.has(id):
		return {"ok": false, "error": "arena_missing"}
	var old: Dictionary = items[id]
	if str(old["owner"]) != who and not is_admin:
		return {"ok": false, "error": "not_owner"}
	var nm := clean_name(arena_name)
	if nm.is_empty():
		return {"ok": false, "error": "arena_name"}
	if not (is_finite(radius) and is_finite(time)):
		return {"ok": false, "error": "arena_bounds"}
	var kd := clean_kind(kind)
	var a := {
		"id": id, "name": nm, "owner": old["owner"], "x": old["x"], "z": old["z"], "kind": kd, "win": clampi(win_pct, 0, FWConst.ARENA_WIN_MAX), "obs": clamp_obs(kd, obstacles),
		"r": clampf(radius, FWConst.ARENA_R_MIN, FWConst.ARENA_R_MAX),
		"coins": clamp_count(kd, coins),
		"time": clampf(time, FWConst.ARENA_TIME_MIN, FWConst.ARENA_TIME_MAX),
		"reward": clampi(reward, 0, FWConst.ARENA_REWARD_MAX),
	}
	a["props"] = clean_props(old.get("props", []), a)
	var pos := Vector2(float(a["x"]), float(a["z"]))
	for oid in items:
		if int(oid) == id:
			continue
		var o: Dictionary = items[oid]
		if Vector2(float(o["x"]), float(o["z"])).distance_to(pos) < float(o["r"]) + float(a["r"]) + FWConst.ARENA_SPACING:
			return {"ok": false, "error": "arena_close"}
	if make_targets(world, seed_value, str(a["owner"]), 0, a).size() < need_targets(kd, int(a["coins"])):
		return {"ok": false, "error": "arena_land"}
	return {"ok": true, "arena": a}


## افزودن/برداشتن شیء سفارشی در موقعیت سازنده؛ op: prop_bonus | prop_hazard | prop_undo. خروجی: رشتهٔ خطا یا «».
func prop_op(world, who: String, is_admin: bool, id: int, op: String, pos: Vector2) -> String:
	if not items.has(id):
		return "arena_missing"
	var a: Dictionary = items[id]
	if str(a["owner"]) != who and not is_admin:
		return "not_owner"
	var props: Array = (a.get("props", []) as Array).duplicate(true)
	if op == "prop_undo":
		if props.is_empty():
			return "prop_empty"
		props.pop_back()
		a["props"] = props
		return ""
	var kind := op.substr(5)
	if not PROP_TYPES.has(kind):
		return "arena_missing"
	if props.size() >= FWConst.ARENA_PROPS_MAX:
		return "prop_limit"
	if not (is_finite(pos.x) and is_finite(pos.y)) or pos.distance_to(Vector2(float(a["x"]), float(a["z"]))) > float(a["r"]) - 0.5:
		return "prop_far"
	if world.height_at(pos.x, pos.y) < 0.5:
		return "arena_land"
	for p in props:
		if Vector2(float(p[1]), float(p[2])).distance_to(pos) < FWConst.ARENA_PROP_SPACING:
			return "prop_close"
	props.append([kind, snappedf(pos.x, 0.1), snappedf(pos.y, 0.1)])
	a["props"] = props
	return ""


func apply_edit(a: Dictionary) -> void:
	items[int(a["id"])] = a


## بررسی یک میدان جدید؛ خروجی {ok, arena} یا {ok: false, error}.
func validate_new(world, seed_value: int, owner: String, arena_name: String, pos: Vector2, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0, obstacles: int = 0) -> Dictionary:
	var nm := clean_name(arena_name)
	if nm.is_empty():
		return {"ok": false, "error": "arena_name"}
	if not (is_finite(pos.x) and is_finite(pos.y) and is_finite(radius) and is_finite(time)):
		return {"ok": false, "error": "arena_bounds"}
	var lo: float = -FWConst.WORLD_LIMIT
	var hi: float = FWConst.CITY_SIZE + FWConst.WORLD_LIMIT
	if pos.x < lo or pos.x > hi or pos.y < lo or pos.y > hi:
		return {"ok": false, "error": "arena_bounds"}
	if items.size() >= FWConst.ARENA_MAX_TOTAL or count_of(owner) >= FWConst.ARENA_MAX_PER_PLAYER:
		return {"ok": false, "error": "arena_limit"}
	var kd := clean_kind(kind)
	var a := {
		"id": 0, "name": nm, "owner": owner, "x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1), "kind": kd, "win": clampi(win_pct, 0, FWConst.ARENA_WIN_MAX), "obs": clamp_obs(kd, obstacles),
		"r": clampf(radius, FWConst.ARENA_R_MIN, FWConst.ARENA_R_MAX),
		"coins": clamp_count(kd, coins),
		"time": clampf(time, FWConst.ARENA_TIME_MIN, FWConst.ARENA_TIME_MAX),
		"reward": clampi(reward, 0, FWConst.ARENA_REWARD_MAX), "props": [],
	}
	for id in items:
		var o: Dictionary = items[id]
		var gap: float = Vector2(float(o["x"]), float(o["z"])).distance_to(pos)
		if gap < float(o["r"]) + float(a["r"]) + FWConst.ARENA_SPACING:
			return {"ok": false, "error": "arena_close"}
	if world.height_at(pos.x, pos.y) < 0.5:
		return {"ok": false, "error": "arena_land"}
	if make_targets(world, seed_value, owner, 0, a).size() < need_targets(kd, int(a["coins"])):
		return {"ok": false, "error": "arena_land"}
	return {"ok": true, "arena": a}


func add(a: Dictionary) -> Dictionary:
	a["id"] = next_id
	next_id += 1
	items[int(a["id"])] = a
	return a


func count_of(owner: String) -> int:
	var n := 0
	for id in items:
		if str(items[id]["owner"]) == owner:
			n += 1
	return n


## امتیازدهی ۱ تا ۵ ستاره: فقط بازیکنی که این میدان را دست‌کم یک بار بازی کرده (has_played) و سازنده نیست؛
## هر بازیکن یک رأی دارد و می‌تواند عوضش کند. خروجی: رشتهٔ خطا یا «».
func rate(who: String, id: int, stars: int, has_played: bool) -> String:
	if not items.has(id):
		return "arena_missing"
	if str(items[id]["owner"]) == who:
		return "arena_rate_own"
	if not has_played:
		return "arena_rate_unplayed"
	if stars < 1 or stars > 5:
		return "arena_rate_bad"
	var row: Dictionary = ratings.get(id, {})
	if row.size() >= 500 and not row.has(who):
		return "arena_rate_full"
	row[who] = stars
	ratings[id] = row
	return ""


## میانگین و تعداد رأی؛ بدون رأی: [0.0, 0].
func rating_of(id: int) -> Array:
	var row: Variant = ratings.get(id, {})
	if not (row is Dictionary) or row.is_empty():
		return [0.0, 0]
	var sum := 0
	for k in row:
		sum += int(row[k])
	return [snappedf(float(sum) / float(row.size()), 0.1), row.size()]


## حذف: فقط سازنده یا مدیر. خروجی: رشتهٔ خطا یا «».
func remove(who: String, id: int, is_admin: bool) -> String:
	if not items.has(id):
		return "arena_missing"
	if str(items[id]["owner"]) != who and not is_admin:
		return "not_owner"
	items.erase(id)
	ratings.erase(id)
	return ""


## فهرست قابل ارسال؛ top برای هر میدان [نام, امتیاز] بهترین رکورد است (از minigame.arena_scores).
func list_public(arena_scores: Dictionary, arena_times: Dictionary = {}) -> Array:
	var rows: Array = []
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = items[id]
		var top_name := ""
		var top_score := 0
		var sc: Variant = arena_scores.get(int(id), {})
		if sc is Dictionary:
			for k in sc:
				if int(sc[k]) > top_score or (int(sc[k]) == top_score and top_score > 0 and str(k) < top_name):
					top_score = int(sc[k])
					top_name = str(k)
		var best_name := ""
		var best_time := 0.0
		var tm: Variant = arena_times.get(int(id), {})
		if tm is Dictionary:
			for k in tm:
				var tv: float = float(tm[k])
				if tv > 0.0 and (best_time <= 0.0 or tv < best_time or (tv == best_time and str(k) < best_name)):
					best_time = tv
					best_name = str(k)
		rows.append({"id": int(id), "name": a["name"], "owner": a["owner"], "x": a["x"], "z": a["z"], "r": a["r"],
			"coins": a["coins"], "time": a["time"], "reward": a["reward"], "kind": clean_kind(a.get("kind", "coins")), "win": int(a.get("win", 0)), "obs": int(a.get("obs", 0)), "props": a.get("props", []),
			"top": [top_name, top_score], "best_time": [best_name, best_time], "rating": rating_of(int(id))})
	return rows


func to_dict() -> Dictionary:
	return {"next_id": next_id, "items": items.duplicate(true), "ratings": ratings.duplicate(true)}


func load_dict(d: Variant) -> void:
	items.clear()
	ratings.clear()
	next_id = 1
	if not (d is Dictionary):
		return
	var src: Variant = d.get("items", {})
	if src is Dictionary:
		for k in src:
			var v: Variant = src[k]
			if not (v is Dictionary) or items.size() >= FWConst.ARENA_MAX_TOTAL:
				continue
			var id := int(k)
			var nm := clean_name(str(v.get("name", "")))
			if id <= 0 or nm.is_empty():
				continue
			var kd := clean_kind(v.get("kind", "coins"))
			items[id] = {
				"kind": kd, "win": clampi(int(v.get("win", 0)), 0, FWConst.ARENA_WIN_MAX), "obs": clamp_obs(kd, int(v.get("obs", 0))),
				"id": id, "name": nm, "owner": str(v.get("owner", "")).substr(0, 32),
				"x": float(v.get("x", 0.0)), "z": float(v.get("z", 0.0)),
				"r": clampf(float(v.get("r", FWConst.ARENA_R_MIN)), FWConst.ARENA_R_MIN, FWConst.ARENA_R_MAX),
				"coins": clamp_count(kd, int(v.get("coins", FWConst.ARENA_COINS_MIN))),
				"time": clampf(float(v.get("time", FWConst.ARENA_TIME_MIN)), FWConst.ARENA_TIME_MIN, FWConst.ARENA_TIME_MAX),
				"reward": clampi(int(v.get("reward", 0)), 0, FWConst.ARENA_REWARD_MAX),
			}
			items[id]["props"] = clean_props(v.get("props", []), items[id])
			next_id = maxi(next_id, id + 1)
	var rs: Variant = d.get("ratings", {})
	if rs is Dictionary:
		for k in rs:
			var row: Variant = rs[k]
			if row is Dictionary and items.has(int(k)):
				var clean: Dictionary = {}
				for pn in row:
					if clean.size() < 500:
						clean[str(pn)] = clampi(int(row[pn]), 1, 5)
				ratings[int(k)] = clean
	next_id = maxi(next_id, int(d.get("next_id", 1)))
