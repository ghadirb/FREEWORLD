extends RefCounted
## میدان‌های ساخته‌شده توسط بازیکن (لایهٔ سازنده، حس Roblox): بازیکن یک میدان «سکه‌یاب» با نام، شعاع،
## تعداد سکه، زمان و جایزهٔ هر سکه می‌سازد؛ بقیه می‌توانند داخل آن بازی کنند و رکورد جدا دارند.
## جایزه را سازنده از پول خودش می‌دهد (در جهان خلاقانه بدون سکه). این ماژول فقط تعریف میدان‌ها،
## اعتبارسنجی و چیدمان قطعی سکه‌ها را دارد؛ اجرای دور در minigame.gd و پرداخت در city_state.gd است.

const FWConst = preload("res://scripts/core/const.gd")

var items: Dictionary = {}   # شناسه ← {id, name, owner, x, z, r, coins, time, reward}
var next_id: int = 1


static func clean_name(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		if ch.unicode_at(0) >= 32:
			out += ch
	return out.substr(0, FWConst.ARENA_NAME_MAX).strip_edges()


## نوع میدان: «coins» (سکه‌یاب) یا «parkour» (ایستگاه‌ها به ترتیب)؛ هر مقدار ناشناخته سکه‌یاب است.
static func clean_kind(raw: Variant) -> String:
	return "parkour" if str(raw) == "parkour" else "coins"


static func clamp_count(kind: String, n: int) -> int:
	var hi: int = FWConst.ARENA_PARKOUR_MAX if kind == "parkour" else FWConst.ARENA_COINS_MAX
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


## اهداف دور بر اساس نوع میدان: سکه‌های پخش‌شده یا ایستگاه‌های مرتب.
static func make_targets(world, seed_value: int, player_name: String, counter: int, a: Dictionary) -> Array:
	if clean_kind(a.get("kind", "coins")) == "parkour":
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
func validate_edit(world, seed_value: int, who: String, is_admin: bool, id: int, arena_name: String, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0) -> Dictionary:
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
		"id": id, "name": nm, "owner": old["owner"], "x": old["x"], "z": old["z"], "kind": kd, "win": clampi(win_pct, 0, FWConst.ARENA_WIN_MAX),
		"r": clampf(radius, FWConst.ARENA_R_MIN, FWConst.ARENA_R_MAX),
		"coins": clamp_count(kd, coins),
		"time": clampf(time, FWConst.ARENA_TIME_MIN, FWConst.ARENA_TIME_MAX),
		"reward": clampi(reward, 0, FWConst.ARENA_REWARD_MAX),
	}
	var pos := Vector2(float(a["x"]), float(a["z"]))
	for oid in items:
		if int(oid) == id:
			continue
		var o: Dictionary = items[oid]
		if Vector2(float(o["x"]), float(o["z"])).distance_to(pos) < float(o["r"]) + float(a["r"]) + FWConst.ARENA_SPACING:
			return {"ok": false, "error": "arena_close"}
	if make_targets(world, seed_value, str(a["owner"]), 0, a).size() < mini(int(a["coins"]), FWConst.ARENA_COINS_MIN):
		return {"ok": false, "error": "arena_land"}
	return {"ok": true, "arena": a}


func apply_edit(a: Dictionary) -> void:
	items[int(a["id"])] = a


## بررسی یک میدان جدید؛ خروجی {ok, arena} یا {ok: false, error}.
func validate_new(world, seed_value: int, owner: String, arena_name: String, pos: Vector2, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0) -> Dictionary:
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
		"id": 0, "name": nm, "owner": owner, "x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1), "kind": kd, "win": clampi(win_pct, 0, FWConst.ARENA_WIN_MAX),
		"r": clampf(radius, FWConst.ARENA_R_MIN, FWConst.ARENA_R_MAX),
		"coins": clamp_count(kd, coins),
		"time": clampf(time, FWConst.ARENA_TIME_MIN, FWConst.ARENA_TIME_MAX),
		"reward": clampi(reward, 0, FWConst.ARENA_REWARD_MAX),
	}
	for id in items:
		var o: Dictionary = items[id]
		var gap: float = Vector2(float(o["x"]), float(o["z"])).distance_to(pos)
		if gap < float(o["r"]) + float(a["r"]) + FWConst.ARENA_SPACING:
			return {"ok": false, "error": "arena_close"}
	if world.height_at(pos.x, pos.y) < 0.5:
		return {"ok": false, "error": "arena_land"}
	if make_targets(world, seed_value, owner, 0, a).size() < mini(int(a["coins"]), FWConst.ARENA_COINS_MIN):
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


## حذف: فقط سازنده یا مدیر. خروجی: رشتهٔ خطا یا «».
func remove(who: String, id: int, is_admin: bool) -> String:
	if not items.has(id):
		return "arena_missing"
	if str(items[id]["owner"]) != who and not is_admin:
		return "not_owner"
	items.erase(id)
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
			"coins": a["coins"], "time": a["time"], "reward": a["reward"], "kind": clean_kind(a.get("kind", "coins")), "win": int(a.get("win", 0)),
			"top": [top_name, top_score], "best_time": [best_name, best_time]})
	return rows


func to_dict() -> Dictionary:
	return {"next_id": next_id, "items": items.duplicate(true)}


func load_dict(d: Variant) -> void:
	items.clear()
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
				"kind": kd, "win": clampi(int(v.get("win", 0)), 0, FWConst.ARENA_WIN_MAX),
				"id": id, "name": nm, "owner": str(v.get("owner", "")).substr(0, 32),
				"x": float(v.get("x", 0.0)), "z": float(v.get("z", 0.0)),
				"r": clampf(float(v.get("r", FWConst.ARENA_R_MIN)), FWConst.ARENA_R_MIN, FWConst.ARENA_R_MAX),
				"coins": clamp_count(kd, int(v.get("coins", FWConst.ARENA_COINS_MIN))),
				"time": clampf(float(v.get("time", FWConst.ARENA_TIME_MIN)), FWConst.ARENA_TIME_MIN, FWConst.ARENA_TIME_MAX),
				"reward": clampi(int(v.get("reward", 0)), 0, FWConst.ARENA_REWARD_MAX),
			}
			next_id = maxi(next_id, id + 1)
	next_id = maxi(next_id, int(d.get("next_id", 1)))
