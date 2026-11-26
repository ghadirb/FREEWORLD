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
var arena_times: Dictionary = {}    # شناسهٔ میدان پارکور ← {نام بازیکن ← سریع‌ترین زمان تمام‌کردن (ثانیه)}
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
	var targets := Arenas.make_targets(world, seed_value, player_name, _counter, arena)
	var kind_pre: String = Arenas.clean_kind(arena.get("kind", "coins"))
	if targets.size() < Arenas.need_targets(kind_pre, int(arena["coins"])):
		return {"ok": false, "error": "mg_no_space"}
	var coins: Array = targets
	var queue: Array = []
	var kind_now: String = Arenas.clean_kind(arena.get("kind", "coins"))
	var diff: int = Arenas.clean_diff(arena.get("diff", FWConst.ARENA_DIFF_DEFAULT))
	var limit: float = Arenas.run_limit(arena, targets)
	if Arenas.is_ordered(kind_now):
		# پارکور و مسابقه: فقط ایستگاه بعدی دیده می‌شود؛ با رسیدن به آن، بعدی ظاهر می‌شود.
		coins = [targets[0]]
		queue = targets.slice(1)
	runs[player_name] = {"t": limit, "score": 0, "diff": diff, "rmult": float(FWConst.ARENA_DIFF_REWARD[diff]), "pen": FWConst.ARENA_OBS_PENALTY * float(FWConst.ARENA_DIFF_PENALTY[diff]), "coins": coins, "win": int(arena.get("win", 0)), "obs": Arenas.make_obstacles(seed_value, arena, targets) if kind_now == "parkour" else [], "clk": 0.0, "hit_cd": 0.0, "queue": queue, "limit": limit, "arena": int(arena["id"]),
		"total": int(arena["coins"]) if kind_now == "football" else targets.size(), "owner": str(arena["owner"]), "per_coin": int(arena["reward"]),
		"props": Arenas.clean_props(arena.get("props", []), arena), "prop_cd": 0.0,
		"pk": Arenas.is_ordered(kind_now), "rc": kind_now == "race", "bt": kind_now == "boat", "adv": kind_now == "adventure", "last": Vector2(float(arena["x"]), float(arena["z"]))}
	if kind_now == "survival":
		runs[player_name]["coins"] = []
		runs[player_name]["foes"] = []
		runs[player_name]["spawns"] = targets
		runs[player_name]["spawned"] = 0
		runs[player_name]["hp"] = FWConst.SURV_HP
		runs[player_name]["fs"] = float(FWConst.ARENA_DIFF_FOE_SPEED[diff])
		runs[player_name]["fd"] = float(FWConst.ARENA_DIFF_FOE_DAMAGE[diff])
		runs[player_name]["atk"] = 0.0
		runs[player_name]["send"] = 0.0
		runs[player_name]["total"] = int(arena["coins"])
	if kind_now == "island":
		var r2: Dictionary = runs[player_name]
		r2["isl"] = true
		r2["foes"] = []
		r2["spawns"] = Arenas.make_survival_spawns(world, seed_value, arena)
		r2["spawned"] = 0
		r2["hp"] = FWConst.SURV_HP
		r2["fs"] = float(FWConst.ARENA_DIFF_FOE_SPEED[diff])
		r2["fd"] = float(FWConst.ARENA_DIFF_FOE_DAMAGE[diff])
		r2["atk"] = 0.0
		r2["send"] = 0.0
		r2["total"] = targets.size()
		r2["ftotal"] = clampi(int(arena["coins"]) / 2, 2, FWConst.SURV_COUNT_MAX)
		r2["hun"] = FWConst.ISLE_HUNGER_MAX
		r2["scd"] = 0.0
	if kind_now == "football":
		var c0 := Vector2(float(arena["x"]), float(arena["z"]))
		runs[player_name]["ball"] = {"p": c0, "v": Vector2.ZERO, "cd": 0.0, "send": 0.0, "c": c0, "r": float(arena["r"]), "goal": targets[0], "gr": FWConst.FOOT_GOAL_RANGE * float(FWConst.ARENA_DIFF_GOAL[diff])}
	return {"ok": true}


## میدان حذف شد: رکوردها پاک و دورهای در حال اجرای آن لغو می‌شوند.
func arena_removed(id: int) -> void:
	arena_scores.erase(id)
	arena_times.erase(id)
	for nm in runs.keys():
		if int(runs[nm].get("arena", 0)) == id:
			runs.erase(nm)


## نقطهٔ ذخیرهٔ دور پارکور (آخرین ایستگاه گرفته‌شده؛ در آغاز مرکز میدان) یا null. بازگشت ۳ ثانیه جریمه دارد.
## بازیکن الان در دور مسابقهٔ ماشین یک میدان است؟ (سقف سرعت مثل مسابقهٔ ایستگاه‌ها بالاتر می‌رود)
func is_arena_race(player_name: String) -> bool:
	return runs.has(player_name) and bool(runs[player_name].get("rc", false))


## بازیکن الان در دور مسابقهٔ قایق یک میدان است؟ (در این دور سوار/پیاده شدن قایق مجاز است)
func is_arena_boat(player_name: String) -> bool:
	return runs.has(player_name) and bool(runs[player_name].get("bt", false))


func respawn_point(player_name: String) -> Variant:
	if not runs.has(player_name) or not bool(runs[player_name].get("pk", false)):
		return null
	return runs[player_name]["last"]


func apply_respawn_penalty(player_name: String) -> void:
	if runs.has(player_name):
		runs[player_name]["t"] = float(runs[player_name]["t"]) - FWConst.ARENA_RESPAWN_PENALTY


func cancel(player_name: String) -> void:
	runs.erase(player_name)


## زمان را جلو می‌برد و سکه‌های نزدیک بازیکنان را برمی‌دارد. positions فقط بازیکنان آنلاین را دارد.
## رویدادها: {"name", "kind": "coin"} یا {"name", "kind": "end", "score", "best", "new_best", "reward"}.
## جایزه را خود cs (که حساب‌ها را دارد) از رویداد پایان می‌پردازد؛ این‌جا فقط محاسبه می‌شود.
func step(dt: float, positions: Dictionary, day: int, world_ref = null) -> Array:
	var events: Array = []
	for player_name in runs.keys():
		if not positions.has(player_name):
			runs.erase(player_name)   # بازیکن خارج شد؛ دور بی‌جایزه لغو می‌شود
			continue
		var run: Dictionary = runs[player_name]
		run["t"] = float(run["t"]) - dt
		var pos: Vector2 = positions[player_name]
		var coins: Array = run["coins"]
		var is_ball: bool = run.has("ball")
		var is_surv: bool = run.has("foes")
		if is_surv:
			_step_foes(world_ref, run, player_name, pos, dt, events)
		if is_ball:
			_step_ball(world_ref, run, player_name, pos, dt, events)
		var i := -1 if is_ball else coins.size() - 1
		while i >= 0:
			if pos.distance_to(coins[i]) <= FWConst.MINIGAME_PICK_RANGE:
				if bool(run.get("pk", false)):
					run["last"] = coins[i]   # ایستگاه گرفته‌شده = نقطهٔ ذخیره
				coins.remove_at(i)
				if run.has("hun"):
					run["hun"] = minf(float(run["hun"]) + FWConst.ISLE_FOOD, FWConst.ISLE_HUNGER_MAX)
				run["score"] = int(run["score"]) + 1
				var queue: Array = run.get("queue", [])
				if not queue.is_empty():
					coins.append(queue.pop_front())
				events.append({"name": player_name, "kind": "coin", "adv": bool(run.get("adv", false)), "n": int(run["score"]), "of": int(run.get("total", 0))})
			i -= 1
		if run.has("hun"):
			run["hun"] = maxf(float(run["hun"]) - FWConst.ISLE_HUNGER_RATE * dt, 0.0)
			run["hsend"] = float(run.get("hsend", 0.0)) + dt
			if float(run["hsend"]) >= 1.0:   # سیری هر ثانیه به کلاینت می‌رسد، حتی وقتی دشمنی نیست
				run["hsend"] = 0.0
				events.append({"name": player_name, "kind": "tick"})
			if float(run["hun"]) <= 0.0:
				run["hp"] = float(run["hp"]) - FWConst.ISLE_STARVE_DAMAGE * dt
				run["scd"] = float(run.get("scd", 0.0)) - dt
				if float(run["scd"]) <= 0.0:
					run["scd"] = 1.5
					events.append({"name": player_name, "kind": "hurt"})
		run["clk"] = float(run.get("clk", 0.0)) + dt
		var obs: Array = run.get("obs", [])
		if not obs.is_empty():
			run["hit_cd"] = maxf(float(run.get("hit_cd", 0.0)) - dt, 0.0)
			if float(run["hit_cd"]) <= 0.0 and (not coins.is_empty() or is_surv):
				for d in obs:
					if pos.distance_to(Arenas.obstacle_pos(d, float(run["clk"]))) <= FWConst.ARENA_OBS_HIT_RANGE:
						run["t"] = float(run["t"]) - float(run.get("pen", FWConst.ARENA_OBS_PENALTY))
						run["hit_cd"] = FWConst.ARENA_OBS_COOLDOWN
						events.append({"name": player_name, "kind": "hit"})
						break
		var props: Array = run.get("props", [])
		if not props.is_empty():
			run["prop_cd"] = maxf(float(run.get("prop_cd", 0.0)) - dt, 0.0)
			var j := props.size() - 1
			while j >= 0:
				var pp: Array = props[j]
				if pos.distance_to(Vector2(float(pp[1]), float(pp[2]))) <= FWConst.ARENA_PROP_RANGE:
					if str(pp[0]) == "bonus":
						run["t"] = minf(float(run["t"]) + FWConst.ARENA_BONUS_TIME, float(run.get("limit", run["t"])))
						props.remove_at(j)
						events.append({"name": player_name, "kind": "bonus"})
					elif float(run["prop_cd"]) <= 0.0 and (not coins.is_empty() or is_surv):
						run["t"] = float(run["t"]) - float(run.get("pen", FWConst.ARENA_OBS_PENALTY))
						run["prop_cd"] = FWConst.ARENA_OBS_COOLDOWN
						events.append({"name": player_name, "kind": "hit"})
				j -= 1
		if float(run["t"]) <= 0.0 or (coins.is_empty() and not is_surv) or ((is_ball or is_surv) and int(run["score"]) >= int(run.get("total", 1))) or (is_surv and float(run["hp"]) <= 0.0):
			events.append(_finish(player_name, day))
	return events


## فیزیک ساده و سمت‌سرور توپ فوتبال: لمس بازیکن توپ را از او دور می‌کند، اصطکاک آن را می‌خواباند، لبهٔ میدان
## و آب آن را برمی‌گرداند/نگه می‌دارد و رسیدن به دروازه گل حساب می‌شود (توپ به مرکز برمی‌گردد).
func _step_ball(world, run: Dictionary, player_name: String, pos: Vector2, dt: float, events: Array) -> void:
	var b: Dictionary = run["ball"]
	var p: Vector2 = b["p"]
	var v: Vector2 = b["v"]
	b["cd"] = maxf(float(b["cd"]) - dt, 0.0)
	if float(b["cd"]) <= 0.0 and pos.distance_to(p) <= FWConst.FOOT_RANGE:
		var dir: Vector2 = p - pos
		dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
		v = dir * FWConst.FOOT_KICK_SPEED
		b["cd"] = FWConst.FOOT_KICK_CD
	var np: Vector2 = p + v * dt
	var center: Vector2 = b["c"]
	var rad: float = float(b["r"]) - 0.5
	if np.distance_to(center) > rad:
		var n: Vector2 = (np - center).normalized()
		np = center + n * rad
		v = v.bounce(n) * 0.6
	if world != null and world.height_at(np.x, np.y) < 0.5:
		np = p
		v = Vector2.ZERO
	v *= exp(-FWConst.FOOT_FRICTION * dt)
	if v.length() < 0.2:
		v = Vector2.ZERO
	b["p"] = np
	b["v"] = v
	if np.distance_to(b["goal"]) <= float(b.get("gr", FWConst.FOOT_GOAL_RANGE)):
		run["score"] = int(run["score"]) + 1
		b["p"] = center
		b["v"] = Vector2.ZERO
		events.append({"name": player_name, "kind": "coin"})
		b["send"] = 0.0
		return
	b["send"] = float(b["send"]) + dt
	if float(b["send"]) >= FWConst.FOOT_SEND and v != Vector2.ZERO:
		b["send"] = 0.0
		events.append({"name": player_name, "kind": "ball"})


## مبارزه و بقا (سمت سرور): دشمن‌ها از نقطه‌های زایش می‌آیند، به سمت بازیکن می‌دوند و با برخورد از سلامت او کم می‌کنند؛
## بازیکن هر ۰٫۶ ثانیه به نزدیک‌ترین دشمن در برد ضربه می‌زند (خودکار، مناسب لمسی). سلامت صفر یا پایان زمان دور را تمام می‌کند.
func _step_foes(world, run: Dictionary, player_name: String, pos: Vector2, dt: float, events: Array) -> void:
	var foes: Array = run["foes"]
	var spawns: Array = run["spawns"]
	var total: int = int(run.get("ftotal", run.get("total", 1)))
	while foes.size() < FWConst.SURV_ALIVE_MAX and int(run["spawned"]) < total and not spawns.is_empty():
		var sp: Vector2 = spawns[int(run["spawned"]) % spawns.size()]
		if sp.distance_to(pos) < 5.0:
			break
		foes.append({"p": sp, "hp": FWConst.SURV_FOE_HP, "cd": 0.5})
		run["spawned"] = int(run["spawned"]) + 1
	run["atk"] = maxf(float(run["atk"]) - dt, 0.0)
	var nearest := -1
	var best := FWConst.SURV_ATTACK_RANGE
	for i in foes.size():
		var f: Dictionary = foes[i]
		var fp: Vector2 = f["p"]
		var d: float = fp.distance_to(pos)
		f["cd"] = maxf(float(f["cd"]) - dt, 0.0)
		if d > FWConst.SURV_FOE_REACH * 0.8:
			var np: Vector2 = fp.move_toward(pos, FWConst.SURV_FOE_SPEED * float(run.get("fs", 1.0)) * dt)
			if world == null or world.height_at(np.x, np.y) >= 0.5:
				f["p"] = np
		elif float(f["cd"]) <= 0.0:
			run["hp"] = float(run["hp"]) - FWConst.SURV_FOE_DAMAGE * float(run.get("fd", 1.0))
			f["cd"] = FWConst.SURV_FOE_CD
			events.append({"name": player_name, "kind": "hurt"})
		if d < best:
			best = d
			nearest = i
	if nearest >= 0 and float(run["atk"]) <= 0.0:
		var tf: Dictionary = foes[nearest]
		tf["hp"] = int(tf["hp"]) - 1
		run["atk"] = FWConst.SURV_ATTACK_CD
		var away: Vector2 = (tf["p"] - pos)
		tf["p"] = tf["p"] + (away.normalized() * 0.8 if away.length() > 0.01 else Vector2.ZERO)
		if int(tf["hp"]) <= 0:
			foes.remove_at(nearest)
			if not bool(run.get("isl", false)):   # در جزیره امتیاز از منابع می‌آید نه کشتن
				run["score"] = int(run["score"]) + 1
				events.append({"name": player_name, "kind": "coin"})
	run["send"] = float(run["send"]) + dt
	if float(run["send"]) >= FWConst.FOOT_SEND and not foes.is_empty():
		run["send"] = 0.0
		events.append({"name": player_name, "kind": "ball"})


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
	# شرط برد (اختیاری): درصدی از اهداف باید گرفته شود؛ جایزه فقط برای برنده پرداخت می‌شود.
	var goal: int = int(run.get("win", 0))
	var total: int = maxi(int(run.get("total", 0)), 1)
	var won: bool = goal <= 0 or score * 100 >= total * goal
	if bool(run.get("isl", false)) and float(run.get("hp", 1.0)) <= 0.0:
		won = false   # جزیرهٔ بقا: مردن یعنی باخت
	var reward := 0
	if player_name != str(run["owner"]) and won:
		reward = int(round(float(score) * float(run["per_coin"]) * float(run.get("rmult", 1.0))))
	# پارکور: اگر همهٔ ایستگاه‌ها گرفته شد، زمان تمام‌کردن ثبت و سریع‌ترین زمان نگه داشته می‌شود.
	var finish_time := 0.0
	var new_time := false
	if run.has("queue") and score >= int(run.get("total", 0)) and int(run.get("total", 0)) > 0:
		finish_time = snappedf(maxf(float(run.get("limit", 0.0)) - float(run["t"]), 0.1), 0.1)
		var tm: Dictionary = arena_times.get(id, {})
		var prev: float = float(tm.get(player_name, 0.0))
		if prev <= 0.0 or finish_time < prev:
			if tm.size() < 500 or tm.has(player_name):
				tm[player_name] = finish_time
				new_time = true
		arena_times[id] = tm
	return {"name": player_name, "kind": "end", "score": score, "best": best, "new_best": new_best,
		"reward": reward, "arena": id, "owner": str(run["owner"]), "time": finish_time, "new_time": new_time, "goal": goal, "won": won}


func board() -> Array:
	var rows: Array = []
	for n in scores:
		rows.append([str(n), int(scores[n])])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]) or (int(a[1]) == int(b[1]) and str(a[0]) < str(b[0])))
	return rows.slice(0, FWConst.MINIGAME_BOARD_SIZE)


## وضعیت قابل ارسال به یک بازیکن.
func public_state(player_name: String) -> Dictionary:
	var out := {"active": runs.has(player_name), "t": 0.0, "score": 0, "coins": [], "pk": false,
		"best": int(scores.get(player_name, 0)), "board": board()}
	if runs.has(player_name):
		var run: Dictionary = runs[player_name]
		out["t"] = snappedf(float(run["t"]), 0.1)
		out["score"] = int(run["score"])
		out["pk"] = bool(run.get("pk", false))
		out["rc"] = bool(run.get("rc", false))
		out["bt"] = bool(run.get("bt", false))
		out["diff"] = int(run.get("diff", FWConst.ARENA_DIFF_DEFAULT))
		if bool(run.get("adv", false)):
			out["adv"] = true
			out["left"] = (run.get("queue", []) as Array).size()
		if run.has("foes"):
			var fl: Array = []
			for f in run["foes"]:
				fl.append([snappedf(f["p"].x, 0.05), snappedf(f["p"].y, 0.05)])
			out["foes"] = fl
			out["hp"] = int(ceil(maxf(float(run["hp"]), 0.0)))
			if run.has("hun"):
				out["hun"] = int(ceil(float(run["hun"])))
		if run.has("ball"):
			var bb: Dictionary = run["ball"]
			out["ball"] = [snappedf(bb["p"].x, 0.05), snappedf(bb["p"].y, 0.05), snappedf(bb["v"].x, 0.05), snappedf(bb["v"].y, 0.05)]
		if not run.get("props", []).is_empty():
			out["props"] = run["props"]
		var cl: Array = []
		for c in run["coins"]:
			cl.append([c.x, c.y])
		out["coins"] = cl
		var ob: Array = run.get("obs", [])
		if not ob.is_empty():
			out["obs"] = ob
			out["el"] = snappedf(float(run.get("clk", 0.0)), 0.1)
	return out


func to_dict() -> Dictionary:
	return {"scores": scores.duplicate(), "plays": plays.duplicate(true), "arena_scores": arena_scores.duplicate(true), "arena_times": arena_times.duplicate(true)}


func load_dict(d: Variant) -> void:
	scores.clear()
	plays.clear()
	arena_scores.clear()
	arena_times.clear()
	if not (d is Dictionary):
		return
	var atm: Variant = d.get("arena_times", {})
	if atm is Dictionary:
		for k in atm:
			var trow: Variant = atm[k]
			if trow is Dictionary and int(k) > 0 and arena_times.size() < FWConst.ARENA_MAX_TOTAL:
				var tclean: Dictionary = {}
				for pn in trow:
					if tclean.size() < 500:
						tclean[str(pn)] = clampf(float(trow[pn]), 0.1, FWConst.ARENA_TIME_MAX)
				arena_times[int(k)] = tclean
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
