extends RefCounted
## مسابقهٔ ایستگاه‌ها (حس رانندگی): ۶ ایستگاه روی یک حلقه دور بازیکن، به ترتیب و با سرعت بیشتر (کارت).
## سرور ترتیب و زمان را از موقعیت خودش می‌سنجد؛ در طول مسابقه سقف سرعتِ مجاز بازیکن RACE_SPEED_MULT برابر است.
## فقط بهترین زمان هر بازیکن ذخیره می‌شود؛ دور نیمه‌تمام ذخیره نمی‌شود.
## مسابقهٔ قایق (پروتکل ۲۴): وقتی بازیکن سوار قایق است ایستگاه‌ها روی آب ساخته می‌شوند و جدول و جایزهٔ جدا دارد.

const FWConst = preload("res://scripts/core/const.gd")

var runs: Dictionary = {}    # نام ← {"t": زمان باقی‌مانده, "next": int, "pts": Array[Vector2]}
var best: Dictionary = {}    # نام ← بهترین زمان (صدم ثانیه)
var best_boat: Dictionary = {}   # نام ← بهترین زمان مسابقهٔ قایق (جدول جدا از پیاده)
var best_car: Dictionary = {}    # نام ← بهترین زمان مسابقهٔ ماشین (پروتکل ۲۸، جدول جدا)
var plays: Dictionary = {}   # نام ← {"day": int, "n": int} دورهای جایزه‌دار امروز
var _counter: int = 0


func is_running(player_name: String) -> bool:
	return runs.has(player_name)


func _land(world, p: Vector2) -> bool:
	var h: float = world.height_at(p.x, p.y)
	return h >= 0.5 and h <= FWConst.MINIGAME_MAX_HEIGHT


## آب عمیق‌تر از لبهٔ ساحل (حاشیه‌ای که قایق گیر نکند).
## ایستگاه باید داخل مرز جهان هم باشد تا قابل‌رسیدن بماند.
func _water(world, p: Vector2) -> bool:
	var lo: float = -FWConst.WORLD_LIMIT + 1.0
	var hi: float = FWConst.CITY_SIZE + FWConst.WORLD_LIMIT - 1.0
	if p.x < lo or p.x > hi or p.y < lo or p.y > hi:
		return false
	return world.height_at(p.x, p.y) < FWConst.BOAT_MIN_H - 0.2


## حلقه‌ای از ایستگاه‌ها که مرکزش کمی دورتر از بازیکن است تا خودِ نقطهٔ شروع روی حلقه باشد.
## پیاده: همه روی خشکی. قایق: همه روی آب و وسط هر دو ایستگاه هم آب باشد تا مسیر بین آن‌ها بسته نباشد.
func _make_ring(world, seed_value: int, player_name: String, pos: Vector2, boat: bool = false, car: bool = false) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("race:%d:%s:%d" % [seed_value, player_name, _counter])
	var radius: float = FWConst.BOAT_RACE_RADIUS if boat else (FWConst.CAR_RACE_RADIUS if car else FWConst.RACE_RADIUS)
	for attempt in (80 if (boat or car) else 40):
		var dir := rng.randf() * TAU
		var center := pos + Vector2(cos(dir), sin(dir)) * radius
		var pts: Array = []
		var ok := true
		for i in FWConst.RACE_GATES:
			# ایستگاه‌ها از موقعیت بازیکن شروع می‌شوند و دور مرکز می‌چرخند؛ اولی نزدیک شروع نیست تا فوراً ثبت نشود
			var a := dir + PI + TAU * float(i + 1) / float(FWConst.RACE_GATES)
			var g := center + Vector2(cos(a), sin(a)) * radius
			g = Vector2(snappedf(g.x, 0.1), snappedf(g.y, 0.1))
			var good: bool = _water(world, g) if boat else _land(world, g)
			if good and (boat or car):
				var prev: Vector2 = pts[pts.size() - 1] if not pts.is_empty() else pos
				var mid: Vector2 = (prev + g) * 0.5
				good = _water(world, mid) if boat else _land(world, mid)   # مسیر بین دو ایستگاه هم باز باشد
			if not good:
				ok = false
				break
			pts.append(g)
		if ok:
			return pts
	return []


func start(world, seed_value: int, player_name: String, pos: Vector2, boat: bool = false, car: bool = false) -> Dictionary:
	if runs.has(player_name):
		return {"ok": false, "error": "mg_running"}
	_counter += 1
	var pts := _make_ring(world, seed_value, player_name, pos, boat, car)
	if pts.is_empty():
		return {"ok": false, "error": "boat_race_no_space" if boat else ("car_race_no_space" if car else "race_no_space")}
	var total: float = FWConst.BOAT_RACE_TIME if boat else (FWConst.CAR_RACE_TIME if car else FWConst.RACE_TIME)
	runs[player_name] = {"t": total, "total": total, "next": 0, "pts": pts, "boat": boat, "car": car}
	return {"ok": true}


func is_boat_race(player_name: String) -> bool:
	return runs.has(player_name) and bool(runs[player_name].get("boat", false))


func is_car_race(player_name: String) -> bool:
	return runs.has(player_name) and bool(runs[player_name].get("car", false))


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
		var gate_range: float = FWConst.BOAT_RACE_GATE_RANGE if bool(run.get("boat", false)) else (FWConst.CAR_RACE_GATE_RANGE if bool(run.get("car", false)) else FWConst.RACE_GATE_RANGE)
		if int(run["next"]) < pts.size() and pos.distance_to(pts[int(run["next"])]) <= gate_range:
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
	var boat: bool = bool(run.get("boat", false))
	var car: bool = bool(run.get("car", false))
	var total: float = float(run.get("total", FWConst.RACE_TIME))
	var elapsed_cs := int(round((total - float(run["t"])) * 100.0))
	elapsed_cs = clampi(elapsed_cs, 1, int(total * 100.0))
	var table: Dictionary = best_boat if boat else (best_car if car else best)
	var new_best := false
	var reward := 0
	if finished:
		var old: int = int(table.get(player_name, 0))
		if old == 0 or elapsed_cs < old:
			table[player_name] = elapsed_cs
			new_best = true
		var key: String = ("boat:" + player_name) if boat else (("car:" + player_name) if car else player_name)
		var p: Dictionary = plays.get(key, {"day": day, "n": 0})
		if int(p["day"]) != day:
			p = {"day": day, "n": 0}
		if int(p["n"]) < FWConst.RACE_REWARDED_RUNS:
			reward = FWConst.BOAT_RACE_REWARD if boat else (FWConst.CAR_RACE_REWARD if car else FWConst.RACE_REWARD)
		p["n"] = int(p["n"]) + 1
		plays[key] = p
	return {"name": player_name, "kind": "end", "finished": finished, "time": elapsed_cs, "boat": boat, "car": car,
		"best": int(table.get(player_name, 0)), "new_best": new_best, "reward": reward}


func board(boat: bool = false, car: bool = false) -> Array:
	var table: Dictionary = best_boat if boat else (best_car if car else best)
	var rows: Array = []
	for n in table:
		rows.append([str(n), int(table[n])])
	rows.sort_custom(func(a, b): return int(a[1]) < int(b[1]) or (int(a[1]) == int(b[1]) and str(a[0]) < str(b[0])))
	return rows.slice(0, FWConst.MINIGAME_BOARD_SIZE)


func public_state(player_name: String) -> Dictionary:
	var out := {"active": runs.has(player_name), "t": 0.0, "next": 0, "pts": [], "boat": false,
		"best": int(best.get(player_name, 0)), "board": board(),
		"boat_best": int(best_boat.get(player_name, 0)), "boat_board": board(true),
		"car": false, "car_best": int(best_car.get(player_name, 0)), "car_board": board(false, true)}
	if runs.has(player_name):
		var run: Dictionary = runs[player_name]
		out["boat"] = bool(run.get("boat", false))
		out["car"] = bool(run.get("car", false))
		out["total"] = float(run.get("total", FWConst.RACE_TIME))
		out["t"] = snappedf(float(run["t"]), 0.1)
		out["next"] = int(run["next"])
		var pl: Array = []
		for c in run["pts"]:
			pl.append([c.x, c.y])
		out["pts"] = pl
	return out


func to_dict() -> Dictionary:
	return {"best": best.duplicate(), "best_boat": best_boat.duplicate(), "best_car": best_car.duplicate(), "plays": plays.duplicate(true)}


func load_dict(d: Variant) -> void:
	best.clear()
	best_boat.clear()
	best_car.clear()
	plays.clear()
	if not (d is Dictionary):
		return
	_load_table(best, d.get("best", {}), int(FWConst.RACE_TIME * 100.0))
	_load_table(best_boat, d.get("best_boat", {}), int(FWConst.BOAT_RACE_TIME * 100.0))
	_load_table(best_car, d.get("best_car", {}), int(FWConst.CAR_RACE_TIME * 100.0))
	var pl: Variant = d.get("plays", {})
	if pl is Dictionary:
		for k in pl:
			var v: Variant = pl[k]
			if v is Dictionary and plays.size() < 1000:
				plays[str(k)] = {"day": int(v.get("day", 0)), "n": clampi(int(v.get("n", 0)), 0, 1000)}


func _load_table(table: Dictionary, src: Variant, max_cs: int) -> void:
	if not (src is Dictionary):
		return
	for k in src:
		if table.size() < 500:
			var v := int(src[k])
			if v > 0:
				table[str(k)] = clampi(v, 1, max_cs)
