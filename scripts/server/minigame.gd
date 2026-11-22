extends RefCounted
## مینی‌بازی «سکه‌یاب»: هر بازیکن یک دور ۶۰ ثانیه‌ای دارد و باید ۲۰ سکهٔ پخش‌شده دور خود را جمع کند.
## همهٔ منطق (چیدمان سکه‌ها، جمع‌آوری، زمان، جایزه، جدول امتیاز) در سرور است؛ کلاینت فقط نمایش می‌دهد.
## دورهای در حال اجرا ذخیره نمی‌شوند؛ فقط بهترین امتیاز هر بازیکن (جدول امتیاز) ذخیره می‌شود.

const FWConst = preload("res://scripts/core/const.gd")
const Arenas = preload("res://scripts/server/arenas.gd")

var runs: Dictionary = {}    # نام بازیکن ← {"t": float, "score": int, "coins": Array[Vector2]}
var scores: Dictionary = {}  # نام بازیکن ← بهترین امتیاز
var plays: Dictionary = {}   # نام بازیکن ← {"day": int, "n": int} تعداد دورهای جایزه‌دار امروز
var arena_scores: Dictionary = {}   # شناسهٔ میدان ← {نام بازیکن ← بهترین امتیاز}
var _counter: int = 0


func is_running(player_name: String) -> bool:
	return runs.has(player_name)


## چیدمان قطعی سکه‌ها دور pos روی خشکی. هر دور شمارندهٔ جدا دارد تا چیدمان تکراری نشود.
func _make_coins(world, seed_value: int, player_name: String, pos: Vector2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:%d" % [seed_value, player_name, _counter])
	var out: Array = []
	var tries := 0
	while out.size() < FWConst.MINIGAME_COINS and tries < 400:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := lerpf(FWConst.MINIGAME_MIN_DIST, FWConst.MINIGAME_RADIUS, sqrt(rng.randf()))
		var c := pos + Vector2(cos(ang), sin(ang)) * dist
		var h: float = world.height_at(c.x, c.y)
		if h < 0.5 or h > FWConst.MINIGAME_MAX_HEIGHT:
			continue
		out.append(Vector2(snappedf(c.x, 0.1), snappedf(c.y, 0.1)))
	return out


func start(world, seed_value: int, player_name: String, pos: Vector2) -> Dictionary:
	if runs.has(player_name):
		return {"ok": false, "error": "mg_running"}
	_counter += 1
	var coins := _make_coins(world, seed_value, player_name, pos)
	if coins.size() < 5:
		return {"ok": false, "error": "mg_no_space"}
	runs[player_name] = {"t": FWConst.MINIGAME_TIME, "score": 0, "coins": coins}
	return {"ok": true}


## شروع دور در میدان ساخته‌شدهٔ بازیکن؛ ظرف، زمان و جایزه از تعریف میدان می‌آید.
func start_arena(world, seed_value: int, player_name: String, arena: Dictionary) -> Dictionary:
	if runs.has(player_name):
		return {"ok": false, "error": "mg_running"}
	_counter += 1
	var coins := Arenas.make_coins(world, seed_value, player_name, _counter, arena)
	if coins.size() < FWConst.ARENA_COINS_MIN:
		return {"ok": false, "error": "mg_no_space"}
	runs[player_name] = {"t": float(arena["time"]), "score": 0, "coins": coins, "arena": int(arena["id"]),
		"total": coins.size(), "owner": str(arena["owner"]), "per_coin": int(arena["reward"])}
	return {"ok": true}


## میدان حذف شد: رکوردها پاک و دورهای در حال اجرای آن لغو می‌شوند.
func arena_removed(id: int) -> void:
	arena_scores.erase(id)
	for nm in runs.keys():
		if int(runs[nm].get("arena", 0)) == id:
			runs.erase(nm)


func cancel(player_name: String) -> void:
	runs.erase(player_name)


## زمان را جلو می‌برد و سکه‌های نزدیک بازیکنان را برمی‌دارد. positions فقط بازیکنان آنلاین را دارد.
## رویدادها: {"name", "kind": "coin"} یا {"name", "kind": "end", "score", "best", "new_best", "reward"}.
## جایزه را خود cs (که حساب‌ها را دارد) از رویداد پایان می‌پردازد؛ این‌جا فقط محاسبه می‌شود.
func step(dt: float, positions: Dictionary, day: int) -> Array:
	var events: Array = []
	for player_name in runs.keys():
		if not positions.has(player_name):
			runs.erase(player_name)   # بازیکن خارج شد؛ دور بی‌جایزه لغو می‌شود
			continue
		var run: Dictionary = runs[player_name]
		run["t"] = float(run["t"]) - dt
		var pos: Vector2 = positions[player_name]
		var coins: Array = run["coins"]
		var i := coins.size() - 1
		while i >= 0:
			if pos.distance_to(coins[i]) <= FWConst.MINIGAME_PICK_RANGE:
				coins.remove_at(i)
				run["score"] = int(run["score"]) + 1
				events.append({"name": player_name, "kind": "coin"})
			i -= 1
		if float(run["t"]) <= 0.0 or coins.is_empty():
			events.append(_finish(player_name, day))
	return events


func _finish(player_name: String, day: int) -> Dictionary:
	var run: Dictionary = runs[player_name]
	runs.erase(player_name)
	var score: int = int(run["score"])
	if run.has("arena"):
		return _finish_arena(player_name, run)
	var best: int = int(scores.get(player_name, 0))
	var new_best := score > best
	if new_best:
		scores[player_name] = score
		best = score
	var p: Dictionary = plays.get(player_name, {"day": day, "n": 0})
	if int(p["day"]) != day:
		p = {"day": day, "n": 0}
	var reward := 0
	if int(p["n"]) < FWConst.MINIGAME_REWARDED_RUNS:
		reward = score * FWConst.MINIGAME_REWARD_PER_COIN
		if score >= FWConst.MINIGAME_COINS:
			reward += FWConst.MINIGAME_FULL_BONUS
	p["n"] = int(p["n"]) + 1
	plays[player_name] = p
	return {"name": player_name, "kind": "end", "score": score, "best": best, "new_best": new_best, "reward": reward}


## پایان دور میدان ساخته‌شده: رکورد جدا برای هر میدان، بدون شمارندهٔ روزانه. جایزه (پیش از سقف پول سازنده) را cs می‌پردازد.
func _finish_arena(player_name: String, run: Dictionary) -> Dictionary:
	var id: int = int(run["arena"])
	var score: int = int(run["score"])
	var sc: Dictionary = arena_scores.get(id, {})
	var best: int = int(sc.get(player_name, 0))
	var new_best := score > best
	if new_best:
		if sc.size() < 500 or sc.has(player_name):
			sc[player_name] = score
		best = score
	arena_scores[id] = sc
	var reward := 0
	if player_name != str(run["owner"]):
		reward = score * int(run["per_coin"])
	return {"name": player_name, "kind": "end", "score": score, "best": best, "new_best": new_best,
		"reward": reward, "arena": id, "owner": str(run["owner"])}


func board() -> Array:
	var rows: Array = []
	for n in scores:
		rows.append([str(n), int(scores[n])])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and str(a[0]) < str(b[0])))
	return rows.slice(0, FWConst.MINIGAME_BOARD_SIZE)


## وضعیت قابل ارسال به یک بازیکن.
func public_state(player_name: String) -> Dictionary:
	var out := {"active": runs.has(player_name), "t": 0.0, "score": 0, "coins": [],
		"best": int(scores.get(player_name, 0)), "board": board()}
	if runs.has(player_name):
		var run: Dictionary = runs[player_name]
		out["t"] = snappedf(float(run["t"]), 0.1)
		out["score"] = int(run["score"])
		var cl: Array = []
		for c in run["coins"]:
			cl.append([c.x, c.y])
		out["coins"] = cl
	return out


func to_dict() -> Dictionary:
	return {"scores": scores.duplicate(), "plays": plays.duplicate(true), "arena_scores": arena_scores.duplicate(true)}


func load_dict(d: Variant) -> void:
	scores.clear()
	plays.clear()
	arena_scores.clear()
	if not (d is Dictionary):
		return
	var asc: Variant = d.get("arena_scores", {})
	if asc is Dictionary:
		for k in asc:
			var row: Variant = asc[k]
			if row is Dictionary and int(k) > 0 and arena_scores.size() < FWConst.ARENA_MAX_TOTAL:
				var clean: Dictionary = {}
				for pn in row:
					if clean.size() < 500:
						clean[str(pn)] = clampi(int(row[pn]), 0, FWConst.ARENA_COINS_MAX)
				arena_scores[int(k)] = clean
	var s: Variant = d.get("scores", {})
	if s is Dictionary:
		for k in s:
			if scores.size() < 500:
				scores[str(k)] = clampi(int(s[k]), 0, FWConst.MINIGAME_COINS)
	var pl: Variant = d.get("plays", {})
	if pl is Dictionary:
		for k in pl:
			var v: Variant = pl[k]
			if v is Dictionary and plays.size() < 500:
				plays[str(k)] = {"day": int(v.get("day", 0)), "n": clampi(int(v.get("n", 0)), 0, 1000)}
