extends RefCounted
## مینی‌بازی «سکه‌یاب»: هر بازیکن یک دور ۶۰ ثانیه‌ای دارد و باید ۲۰ سکهٔ پخش‌شده دور خود را جمع کند.
## همهٔ منطق (چیدمان سکه‌ها، جمع‌آوری، زمان، جایزه، جدول امتیاز) در سرور است؛ کلاینت فقط نمایش می‌دهد.
## دورهای در حال اجرا ذخیره نمی‌شوند؛ فقط بهترین امتیاز هر بازیکن (جدول امتیاز) ذخیره می‌شود.

const FWConst = preload("res://scripts/core/const.gd")

var runs: Dictionary = {}    # نام بازیکن ← {"t": float, "score": int, "coins": Array[Vector2]}
var scores: Dictionary = {}  # نام بازیکن ← بهترین امتیاز
var plays: Dictionary = {}   # نام بازیکن ← {"day": int, "n": int} تعداد دورهای جایزه‌دار امروز
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
	return {"scores": scores.duplicate(), "plays": plays.duplicate(true)}


func load_dict(d: Variant) -> void:
	scores.clear()
	plays.clear()
	if not (d is Dictionary):
		return
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
