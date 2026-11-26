extends RefCounted
## دشمنان سیاه‌چال معدن‌ها (سمت سرور): اسکلت‌های پراکنده، نگهبان هر صندوق گنج و یک نگهبان بزرگ در عمیق‌ترین نقطه.
## دشمن‌ها با مسیریابی روی کاشی‌های معدن بازیکن را دنبال می‌کنند؛ فقط وقتی کسی داخل معدن است وجود دارند.
## دشمن کشته‌شده CAVE_RESPAWN ثانیه بعد برمی‌گردد. ذخیره نمی‌شود. خانهٔ روستا (شناسهٔ h...) دشمن ندارد.

const FWConst = preload("res://scripts/core/const.gd")
const Mine = preload("res://scripts/shared/mine.gd")

var caves: Dictionary = {}      # mine_id -> {"mobs": Array, "send": float}
var dead: Dictionary = {}       # "mine_id:slot" -> ثانیهٔ باقی‌مانده
var _atk: Dictionary = {}       # نام بازیکن -> استراحت ضربه
var rng := RandomNumberGenerator.new()


## جایگاه‌های قطعی زایش: [{slot, kind, p: Vector2}]. نگهبان بزرگ همیشه slot 0 است.
static func slots(layout: Dictionary, mine_id: String) -> Array:
	var out: Array = []
	if mine_id.begins_with("h") or layout.is_empty() or not layout.has("dist"):
		return out
	var tiles: PackedByteArray = layout["tiles"]
	var dist: PackedInt32Array = layout["dist"]
	var size: int = Mine.SIZE
	var deepest := -1
	var deepest_d := -1
	for i in tiles.size():
		if int(tiles[i]) == 1 and int(dist[i]) > deepest_d:
			deepest_d = int(dist[i])
			deepest = i
	if deepest < 0:
		return out
	var used: Array = []
	out.append({"slot": 0, "kind": "warden", "p": Mine.tile_center(deepest % size, deepest / size)})
	used.append(Vector2i(deepest % size, deepest / size))
	for n in layout["nodes"]:
		if str(n["kind"]) == "chest":
			var t := Vector2i(int(n["tx"]), int(n["tz"]))
			if used.has(t):
				continue
			used.append(t)
			out.append({"slot": out.size(), "kind": "skeleton", "p": Mine.tile_center(t.x, t.y)})
	# پراکنده: انتخاب قطعی از کاشی‌های باز با فاصلهٔ کافی از هم و از ورودی
	var cands: Array = []
	for i in tiles.size():
		if int(tiles[i]) == 1 and int(dist[i]) >= FWConst.CAVE_MIN_DEPTH:
			cands.append(i)
	var r := Mine.Rng.new(absi(hash(mine_id)) + 977)
	var guard := 0
	var want: int = out.size() + FWConst.CAVE_MOBS
	while out.size() < want and not cands.is_empty() and guard < 400:
		guard += 1
		var ci: int = int(cands[r.below(cands.size())])
		var t2 := Vector2i(ci % size, ci / size)
		var ok := true
		for u in used:
			if absi(u.x - t2.x) + absi(u.y - t2.y) < 4:
				ok = false
				break
		if not ok:
			continue
		used.append(t2)
		out.append({"slot": out.size(), "kind": "skeleton", "p": Mine.tile_center(t2.x, t2.y)})
	return out


func _populate(mine_id: String, layout: Dictionary) -> Array:
	var mobs: Array = []
	for s in slots(layout, mine_id):
		if dead.has("%s:%d" % [mine_id, int(s["slot"])]):
			continue
		var spec: Dictionary = FWConst.WILD_KINDS[str(s["kind"])]
		mobs.append({"slot": int(s["slot"]), "kind": str(s["kind"]), "p": s["p"], "home": s["p"],
			"hp": int(spec["hp"]), "cd": 1.0, "wp": s["p"], "re": 0.0})
	return mobs


static func _tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / Mine.TILE)), int(floor(p.y / Mine.TILE)))


## مسیر کاشی‌به‌کاشی (BFS) از a به b؛ فقط تا max_tiles کاشی. خروجی: کاشی بعدی یا a اگر مسیری نیست، و طول مسیر.
static func next_step(layout: Dictionary, a: Vector2i, b: Vector2i, max_tiles: int) -> Dictionary:
	if a == b:
		return {"next": a, "len": 0}
	var prev := {}
	prev[a] = a
	var q: Array = [a]
	var depth := {a: 0}
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		if int(depth[c]) >= max_tiles:
			continue
		for d in Mine.DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or not Mine.tile_open(layout, n.x, n.y):
				continue
			prev[n] = c
			depth[n] = int(depth[c]) + 1
			if n == b:
				var cur: Vector2i = n
				while prev[cur] != a:
					cur = prev[cur]
				return {"next": cur, "len": int(depth[n])}
			q.append(n)
	return {"next": a, "len": -1}


## players: [{name, pos: Vector2 (محلی معدن), dmg, armor}] بازیکنان داخل این معدن.
## خروجی مثل Wild.step: {"hurt", "kills", "changed", "send"}
func step(dt: float, mine_id: String, layout: Dictionary, players: Array) -> Dictionary:
	var out := {"hurt": [], "kills": [], "changed": false, "send": false}
	if players.is_empty():
		if caves.has(mine_id):
			caves.erase(mine_id)
			out["changed"] = true
		return out
	if not caves.has(mine_id):
		caves[mine_id] = {"mobs": _populate(mine_id, layout), "send": 0.0}
		out["changed"] = true
		out["send"] = true
	var st: Dictionary = caves[mine_id]
	var mobs: Array = st["mobs"]
	for m in mobs:
		var spec: Dictionary = FWConst.WILD_KINDS[str(m["kind"])]
		m["cd"] = maxf(float(m["cd"]) - dt, 0.0)
		m["re"] = float(m["re"]) - dt
		var target := {}
		var best := INF
		for pl in players:
			var dd: float = (pl["pos"] as Vector2).distance_to(m["p"])
			if dd < best:
				best = dd
				target = pl
		if target.is_empty():
			continue
		var tp: Vector2 = target["pos"]
		if best <= float(spec["reach"]) * 0.8:
			if float(m["cd"]) <= 0.0:
				m["cd"] = float(spec["cd"])
				out["hurt"].append({"name": str(target["name"]), "amount": float(spec["dmg"]) * (1.0 - float(target["armor"]))})
			continue
		# مسیر: هر ۰٫۴ ثانیه کاشی بعدی را دوباره حساب کن
		if float(m["re"]) <= 0.0:
			m["re"] = 0.4
			var ns: Dictionary = next_step(layout, _tile_of(m["p"]), _tile_of(tp), FWConst.CAVE_AGGRO_TILES)
			if int(ns["len"]) < 0:
				m["wp"] = m["home"]       # بازیکن دور است: به جای خود برگرد
			elif int(ns["len"]) == 0:
				m["wp"] = tp
			else:
				var nt: Vector2i = ns["next"]
				m["wp"] = Mine.tile_center(nt.x, nt.y)
		var wp: Vector2 = m["wp"]
		if (m["p"] as Vector2).distance_to(wp) > 0.1:
			var np: Vector2 = (m["p"] as Vector2).move_toward(wp, float(spec["speed"]) * dt)
			if Mine.walkable(layout, np.x, np.y):
				m["p"] = np
				out["changed"] = true
	# ضربهٔ بازیکن‌ها
	for pl in players:
		var pname: String = str(pl["name"])
		_atk[pname] = maxf(float(_atk.get(pname, 0.0)) - dt, 0.0)
		if float(_atk[pname]) > 0.0:
			continue
		var idx := -1
		# راهروهای معدن تنگ‌اند؛ کمان نباید از پشت دیوار بزند.
		var bd: float = minf(float(pl.get("range", FWConst.PLAYER_ATTACK_RANGE)), 5.0)
		for j in mobs.size():
			var dd2: float = (mobs[j]["p"] as Vector2).distance_to(pl["pos"])
			if dd2 < bd:
				bd = dd2
				idx = j
		if idx < 0:
			continue
		_atk[pname] = float(pl.get("cd", FWConst.PLAYER_ATTACK_CD))
		var tm: Dictionary = mobs[idx]
		tm["hp"] = int(tm["hp"]) - int(pl["dmg"])
		out["changed"] = true
		if int(tm["hp"]) <= 0:
			var sp2: Dictionary = FWConst.WILD_KINDS[str(tm["kind"])]
			var drop := ""
			if str(sp2["drop"]) != "" and rng.randf() < float(sp2["drop_chance"]):
				drop = str(sp2["drop"])
			out["kills"].append({"name": pname, "kind": str(tm["kind"]), "money": int(sp2["money"]), "drop": drop})
			dead["%s:%d" % [mine_id, int(tm["slot"])]] = FWConst.CAVE_RESPAWN
			mobs.remove_at(idx)
			out["send"] = true
	st["send"] = float(st["send"]) + dt
	if float(st["send"]) >= FWConst.WILD_SEND_EVERY and out["changed"]:
		st["send"] = 0.0
		out["send"] = true
	return out


func tick(dt: float) -> void:
	for k in dead.keys():
		dead[k] = float(dead[k]) - dt
		if float(dead[k]) <= 0.0:
			dead.erase(k)


## فهرست فشرده برای کلاینت، هم‌قالب s2c_wild: [[id, نوع، x، z، hp]] در مختصات محلی معدن.
func public(mine_id: String) -> Array:
	var out: Array = []
	if not caves.has(mine_id):
		return out
	for m in caves[mine_id]["mobs"]:
		var p: Vector2 = m["p"]
		out.append([FWConst.CAVE_ID_OFFSET + int(m["slot"]), str(m["kind"]), snappedf(p.x, 0.05), snappedf(p.y, 0.05), int(m["hp"])])
	return out


## معدن‌هایی که الان دشمن فعال دارند ولی بازیکنی در گروه‌ها نیست پاک می‌شوند.
func drop_empty(active: Array) -> void:
	for k in caves.keys():
		if not active.has(k):
			caves.erase(k)
