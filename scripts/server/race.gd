extends RefCounted
## مسابقهٔ ایستگاه‌ها (حس رانندگی): ۶ ایستگاه روی یک حلقه دور بازیکن، به ترتیب و با سرعت بیشتر (کارت).
## سرور ترتیب و زمان را از موقعیت خودش می‌سنجد؛ در طول مسابقه سقف سرعتِ مجاز بازیکن RACE_SPEED_MULT برابر است.
## فقط بهترین زمان هر بازیکن ذخیره می‌شود؛ دور نیمه‌تمام ذخیره نمی‌شود.

const FWConst = preload("res://scripts/core/const.gd")

var runs: Dictionary = {}    # نام ← {"t": زمان باقی‌مانده, "next": int, "pts": Array[Vector2]}
var best: Dictionary = {}    # نام ← بهترین زمان (صدم ثانیه)
var plays: Dictionary = {}   # نام ← {"day": int, "n": int} دورهای جایزه‌دار امروز
var _counter: int = 0


func is_running(player_name: String) -> bool:
	return runs.has(player_name)


func _land(world, p: Vector2) -> bool:
	var h: float = world.height_at(p.x, p.y)
	return h >= 0.5 and h <= FWConst.MINIGAME_MAX_HEIGHT


## حلقه‌ای از ایستگاه‌ها که مرکزش کمی دورتر از بازیکن است تا خودِ نقطهٔ شروع روی حلقه باشد. همه باید روی خشکی باشند.
func _make_ring(world, seed_value: int, player_name: String, pos: Vector2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("race:%d:%s:%d" % [seed_value, player_name, _counter])
	for attempt in 40:
		var dir := rng.randf() * TAU
		var center := pos + Vector2(cos(dir), sin(dir)) * FWConst.RACE_RADIUS
		var pts: Array = []
		var ok := true
		for i in FWConst.RACE_GATES:
			# ایستگاه‌ها از موقعیت بازیکن شروع می‌شوند و دور مرکز می‌چرخند؛ اولی نزدیک شروع نیست تا فوراً ثبت نشود
			var a := dir + PI + TAU * float(i + 1) / float(FWConst.RACE_GATES)
			var g := center + Vector2(cos(a), sin(a)) * FWConst.RACE_RADIUS
			g = Vector2(snappedf(g.x, 0.1), snappedf(g.y, 0.1))
			if not _land(world, g):
				ok = false
				break
			pts.append(g)
		if ok:
			return pts
	return []


func start(world, seed_value: int, player_name: String, pos: Vector2) -> Dictionary:
	if runs.has(player_name):
		return {"ok": false, "error": "mg_running"}
	_counter += 1
	var pts := _make_ring(world, seed_value, player_name, pos)
	if pts.is_empty():
		return {"ok": false, "error": "race_no_space"}
	runs[player_name] = {"t": FWConst.RACE_TIME, "next": 0, "pts": pts}
	return {"ok": true}


## رویدادها: {"name","kind":"gate"} یا {"name","kind":"end","finished","time","best","new_best","reward"}.
func step(dt: float, positions: Dictionary, day: int) -> Array:
	var events: Array = []
	for player_name in runs.keys():
		if not positions.has(player_name):
			runs.erase(player_name)   # خروج بازیکن: دور لغو، بدون جایزه
			continue
		var run: Dictionary = runs[player_name]
		run["t"] = float(run["t"]) - dt
		var pts: Array = run["pts"]
		var pos: Vector2 = positions[player_name]
		if int(run["next"]) < pts.size() and pos.distance_to(pts[int(run["next"])]) <= FWConst.RACE_GATE_RANGE:
			run["next"] = int(run["next"]) + 1
			events.append({"name": player_name, "kind": "gate"})
		if int(run["next"]) >= pts.size():
			events.append(_finish(player_name, day, true))
		elif float(run["t"]) <= 0.0:
			events.append(_finish(player_name, day, false))
	return events


func _finish(player_name: String, day: int, finished: bool) -> Dictionary:
	var run: Dictionary = runs[player_name]
	runs.erase(player_name)
	var elapsed_cs := int(round((FWConst.RACE_TIME - float(run["t"])) * 100.0))
	elapsed_cs = clampi(elapsed_cs, 1, int(FWConst.RACE_TIME * 100.0))
	var new_best := false
	var reward := 0
	if finished:
		var old: int = int(best.get(player_name, 0))
		if old == 0 or elapsed_cs < old:
			best[player_name] = elapsed_cs
			new_best = true
		var p: Dictionary = plays.get(player_name, {"day": day, "n": 0})
		if int(p["day"]) != day:
			p = {"day": day, "n": 0}
		if int(p["n"]) < FWConst.RACE_REWARDED_RUNS:
			reward = FWConst.RACE_REWARD
		p["n"] = int(p["n"]) + 1
		plays[player_name] = p
	return {"name": player_name, "kind": "end", "finished": finished, "time": elapsed_cs,
		"best": int(best.get(player_name, 0)), "new_best": new_best, "reward": reward}


func board() -> Array:
	var rows: Array = []
	for n in best:
		rows.append([str(n), int(best[n])])
	rows.sort_custom(func(a, b): return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and str(a[0]) < str(b[0])))
	return rows.slice(0, FWConst.MINIGAME_BOARD_SIZE)


func public_state(player_name: String) -> Dictionary:
	var out := {"active": runs.has(player_name), "t": 0.0, "next": 0, "pts": [],
		"best": int(best.get(player_name, 0)), "board": board()}
	if runs.has(player_name):
		var run: Dictionary = runs[player_name]
		out["t"] = snappedf(float(run["t"]), 0.1)
		out["next"] = int(run["next"])
		var pl: Array = []
		for c in run["pts"]:
			pl.append([c.x, c.y])
		out["pts"] = pl
	return out


func to_dict() -> Dictionary:
	return {"best": best.duplicate(), "plays": plays.duplicate(true)}


func load_dict(d: Variant) -> void:
	best.clear()
	plays.clear()
	if not (d is Dictionary):
		return
	var b: Variant = d.get("best", {})
	if b is Dictionary:
		for k in b:
			if best.size() < 500:
				var v := int(b[k])
				if v > 0:
					best[str(k)] = clampi(v, 1, int(FWConst.RACE_TIME * 100.0))
	var pl: Variant = d.get("plays", {})
	if pl is Dictionary:
		for k in pl:
			var v: Variant = pl[k]
			if v is Dictionary and plays.size() < 500:
				plays[str(k)] = {"day": int(v.get("day", 0)), "n": clampi(int(v.get("n", 0)), 0, 1000)}
