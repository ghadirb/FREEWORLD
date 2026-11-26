extends RefCounted
## دشمنان وحشی در جهان آزاد (پروتکل ۴۷، سمت سرور).
## شب‌ها نزدیک بازیکن‌ها پیدا می‌شوند، به سمتشان می‌دوند و حمله می‌کنند؛ بازیکن خودکار (مناسب لمسی)
## به نزدیک‌ترین دشمن در برد می‌زند. آسیب و پاداش را این ماژول حساب می‌کند و رویداد برمی‌گرداند؛
## اعمال سلامت/پول روی حساب کار city_state است. وضعیت دشمنان ذخیره نمی‌شود.

const FWConst = preload("res://scripts/core/const.gd")

var mobs: Array = []                 # [{id, kind, p: Vector2, hp, cd}]
var _next_id := 1
var _spawn_acc := 0.0
var _send_acc := 0.0
var _atk_cd: Dictionary = {}         # نام بازیکن → ثانیهٔ باقی‌ماندهٔ استراحت ضربه
var rng := RandomNumberGenerator.new()


static func is_night(world_time: float) -> bool:
	var h: float = fposmod(world_time, 86400.0) / 3600.0
	return h >= FWConst.WILD_NIGHT_START or h < FWConst.WILD_NIGHT_END


## players: [{name, pos: Vector2, dmg: int, armor: float (کاهش ۰..۱)}] فقط بازیکنانی که در معرض دشمن‌اند (بیرون، بی‌بازی).
## land: Callable(x, z) → bool. center: نقطهٔ امن. enabled: false یعنی جهان بدون دشمن (خلاقانه).
## خروجی: {"hurt": [{name, amount}], "kills": [{name, kind, money, drop}], "changed": bool, "send": bool}
func step(dt: float, players: Array, night: bool, land: Callable, center: Vector2, enabled: bool) -> Dictionary:
	var out := {"hurt": [], "kills": [], "changed": false, "send": false}
	if not enabled or players.is_empty():
		if not mobs.is_empty():
			mobs.clear()
			out["changed"] = true
			out["send"] = true
		return out
	# پایان شب یا دور شدن از همهٔ بازیکن‌ها: دشمن محو می‌شود.
	var i := mobs.size() - 1
	while i >= 0:
		var m: Dictionary = mobs[i]
		var near := false
		for pl in players:
			if (pl["pos"] as Vector2).distance_to(m["p"]) <= FWConst.WILD_DESPAWN_DIST:
				near = true
				break
		if not night or not near:
			mobs.remove_at(i)
			out["changed"] = true
		i -= 1
	# زایش
	_spawn_acc += dt
	if night and _spawn_acc >= FWConst.WILD_SPAWN_EVERY:
		_spawn_acc = 0.0
		if _try_spawn(players, land, center):
			out["changed"] = true
	# حرکت و حمله‌ی دشمن‌ها
	for m in mobs:
		var spec: Dictionary = FWConst.WILD_KINDS[str(m["kind"])]
		m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
		var target := _nearest_player(players, m["p"])
		if target.is_empty():
			continue
		var tp: Vector2 = target["pos"]
		var d: float = (m["p"] as Vector2).distance_to(tp)
		if d > FWConst.WILD_AGGRO:
			continue
		if d > float(spec["reach"]) * 0.8:
			var np: Vector2 = (m["p"] as Vector2).move_toward(tp, float(spec["speed"]) * dt)
			if land.call(np.x, np.y) and np.distance_to(center) > FWConst.WILD_SAFE_RADIUS * 0.5:
				m["p"] = np
		elif float(m["cd"]) <= 0.0:
			m["cd"] = float(spec["cd"])
			var amount: float = float(spec["dmg"]) * (1.0 - float(target["armor"]))
			out["hurt"].append({"name": str(target["name"]), "amount": amount})
	# ضربهٔ بازیکن‌ها
	for pl in players:
		var pname: String = str(pl["name"])
		_atk_cd[pname] = maxf(float(_atk_cd.get(pname, 0.0)) - dt, 0.0)
		if float(_atk_cd[pname]) > 0.0:
			continue
		var idx := -1
		var best: float = float(pl.get("range", FWConst.PLAYER_ATTACK_RANGE))
		for j in mobs.size():
			var dd: float = (mobs[j]["p"] as Vector2).distance_to(pl["pos"])
			if dd < best:
				best = dd
				idx = j
		if idx < 0:
			continue
		_atk_cd[pname] = float(pl.get("cd", FWConst.PLAYER_ATTACK_CD))
		var tm: Dictionary = mobs[idx]
		tm["hp"] = int(tm["hp"]) - int(pl["dmg"])
		var away: Vector2 = (tm["p"] as Vector2) - (pl["pos"] as Vector2)
		if away.length() > 0.01:
			var kp: Vector2 = (tm["p"] as Vector2) + away.normalized() * 0.7
			if land.call(kp.x, kp.y):
				tm["p"] = kp
		out["changed"] = true
		if int(tm["hp"]) <= 0:
			var spec2: Dictionary = FWConst.WILD_KINDS[str(tm["kind"])]
			var drop := ""
			if str(spec2["drop"]) != "" and rng.randf() < float(spec2["drop_chance"]):
				drop = str(spec2["drop"])
			out["kills"].append({"name": pname, "kind": str(tm["kind"]), "money": int(spec2["money"]), "drop": drop})
			mobs.remove_at(idx)
	_send_acc += dt
	if _send_acc >= FWConst.WILD_SEND_EVERY and not mobs.is_empty():
		_send_acc = 0.0
		out["send"] = true
	if out["changed"] and mobs.is_empty():
		out["send"] = true
	return out


func _nearest_player(players: Array, p: Vector2) -> Dictionary:
	var best := INF
	var res := {}
	for pl in players:
		var d: float = (pl["pos"] as Vector2).distance_to(p)
		if d < best:
			best = d
			res = pl
	return res


func _try_spawn(players: Array, land: Callable, center: Vector2) -> bool:
	if mobs.size() >= FWConst.WILD_GLOBAL_MAX:
		return false
	var pl: Dictionary = players[rng.randi() % players.size()]
	var around := 0
	for m in mobs:
		if (m["p"] as Vector2).distance_to(pl["pos"]) <= FWConst.WILD_DESPAWN_DIST:
			around += 1
	if around >= FWConst.WILD_PER_PLAYER:
		return false
	var ang: float = rng.randf() * TAU
	var dist: float = rng.randf_range(FWConst.WILD_SPAWN_MIN, FWConst.WILD_SPAWN_MAX)
	var sp: Vector2 = (pl["pos"] as Vector2) + Vector2.from_angle(ang) * dist
	if sp.distance_to(center) < FWConst.WILD_SAFE_RADIUS or not land.call(sp.x, sp.y):
		return false
	var kind := "ghoul" if rng.randf() < 0.35 else "wolf"
	var spec: Dictionary = FWConst.WILD_KINDS[kind]
	mobs.append({"id": _next_id, "kind": kind, "p": sp, "hp": int(spec["hp"]), "cd": 1.0})
	_next_id += 1
	return true


## قالب فشرده برای کلاینت: [[id, نوع، x، z، hp]]
func public() -> Array:
	var out: Array = []
	for m in mobs:
		var p: Vector2 = m["p"]
		out.append([int(m["id"]), str(m["kind"]), snappedf(p.x, 0.05), snappedf(p.y, 0.05), int(m["hp"])])
	return out
