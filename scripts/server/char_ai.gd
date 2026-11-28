extends RefCounted
## مغز مستقل شخصیت (پروتکل ۵۴، مرحلهٔ ۱). فقط روی سرور؛ بدون اینترنت و بدون مدل زبانی کار می‌کند.
## هر شخصیت یک NPC معمولی است (همان مسیریابی، ذخیره و نمایش) با فیلد «ai» و یک حساب سایه «ai:<شناسه>»؛
## پس همهٔ اقدام‌هایش از همان توابع معتبر بازیکن می‌گذرد (برداشت منابع، فروش، ساخت‌وساز، برداشت تولید)
## و هیچ مجوز یا پول یا مصالحی از هیچ نمی‌گیرد. در جهان خلاقانه هزینه‌ها صفر می‌شود، ولی هوش و حافظه می‌ماند.
##
## چرخهٔ تصمیم (هر چند ثانیه، نه هر فریم): مشاهده ← رتبه‌بندی هدف‌ها با ویژگی‌ها ← برنامه‌ریزی چندمرحله‌ای ←
## اجرا گام‌به‌گام ← بررسی نتیجه (شکست = ثبت در حافظه، جریمهٔ هدف، برنامهٔ جدید).

const FWConst = preload("res://scripts/core/const.gd")
const NpcNav = preload("res://scripts/server/npc_nav.gd")
const Personality = preload("res://scripts/server/char_personality.gd")
const Placement = preload("res://scripts/shared/placement.gd")

const BUILD_TYPES := ["house", "farm", "coop", "shop", "well"]
const MULTI_OK := ["farm", "coop"]          # از این‌ها چند تا هم می‌شود ساخت
const MAX_PER_TYPE := 3
const GATHER_SECONDS := 1.5
const BUILD_SECONDS := 2.5
const LOG_MAX := 12
const BAD_RESOURCE_DAYS := 1
const SAVINGS_TARGET := 400


static func is_ai(npc: Dictionary) -> bool:
	return npc.get("ai", null) is Dictionary


static func tag(npc: Dictionary) -> String:
	return "c:" + str(npc["ai"].get("arch", "")) if is_ai(npc) else ""


static func count(cs) -> int:
	var n := 0
	for npc in cs.npcs:
		if is_ai(npc):
			n += 1
	return n


static func plaza() -> Vector2:
	return Vector2(FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5 - 4.0)


# ---------------- ساخت و بارگذاری ----------------

static func can_spawn(cs, actor: String) -> bool:
	return FWConst.is_admin(cs.role_of(actor)) or cs.creative


static func spawn(cs, arch: String, display_name: String = "") -> Dictionary:
	if not bool(cs.ai_settings["on"]):
		return {"ok": false, "error": "ai_off"}
	if not Personality.valid(arch):
		return {"ok": false, "error": "bad_request"}
	if count(cs) >= int(cs.ai_settings["max"]):
		return {"ok": false, "error": "ai_full"}
	if cs.npcs.size() >= FWConst.NPC_MAX:
		return {"ok": false, "error": "npc_full"}
	var nid := 1
	for n in cs.npcs:
		nid = maxi(nid, int(n["id"]) + 1)
	var acct := "ai:%d" % nid
	var p := plaza()
	var nm: String = display_name.strip_edges().substr(0, 16) if display_name.strip_edges() != "" else Personality.pick_name(arch, nid)
	var npc := {
		"id": nid, "name": nm, "x": p.x + float(nid % 5) * 1.5 - 3.0, "z": p.y - 2.0,
		"state": "idle", "money": 0, "paid_day": -1, "acct": acct,
		"ai": _fresh_ai(arch, nid),
	}
	cs.npcs.append(npc)
	cs.accounts[acct] = _shadow_account(cs, npc)
	cs._log(acct, "ai_spawn", {"id": nid, "arch": arch})
	return {"ok": true, "npc": npc}


static func _fresh_ai(arch: String, nid: int) -> Dictionary:
	return {
		"arch": arch, "traits": Personality.traits_for(arch, nid),
		"life": str(Personality.ARCHETYPES[arch]["life"]),
		"goals": [], "plan": [], "active": {}, "t": 0.0, "w": 0.0,
		"fails": {}, "bad": {}, "log": [],
		"stats": {"gathered": 0, "sold": 0, "built": 0, "failed": 0, "thoughts": 0},
	}


static func _shadow_account(cs, npc: Dictionary) -> Dictionary:
	return {
		"money": FWConst.AI_START_MONEY, "role": FWConst.ROLE_PLAYER, "token_hash": "!",   # هرگز با توکنی جور نمی‌شود
		"pos": [npc["x"], 0.0, npc["z"]], "wheat": 0, "requests": [], "job": 0, "work_acc": 0.0,
		"energy": FWConst.ENERGY_MAX, "hunger": FWConst.HUNGER_MAX, "hp": FWConst.PLAYER_HP_MAX,
		"gear": {"weapon": 0, "armor": 0}, "inv": {}, "book": {}, "stats": {}, "quests": {},
	}


## بازیابی ایمن از فایل ذخیره: برنامهٔ در حال اجرا ذخیره نمی‌شود و بعد از بارگذاری دوباره برنامه‌ریزی می‌شود.
static func load_ai(raw: Variant, nid: int) -> Variant:
	if not (raw is Dictionary) or not Personality.valid(str(raw.get("arch", ""))):
		return null
	var arch := str(raw["arch"])
	var ai := _fresh_ai(arch, nid)
	ai["traits"] = Personality.clean_traits(raw.get("traits", null), arch, nid)
	var goals: Array = []
	var rg: Variant = raw.get("goals", [])
	if rg is Array:
		for g in rg:
			if g is Dictionary and (BUILD_TYPES.has(str(g.get("type", ""))) or str(g.get("kind", "")) == "income"):
				goals.append({"kind": str(g.get("kind", "build")), "type": str(g.get("type", "")), "prio": clampf(float(g.get("prio", 0.0)), 0.0, 2.0), "h": str(g.get("h", "short"))})
	ai["goals"] = goals.slice(0, 6)
	var rf: Variant = raw.get("fails", {})
	if rf is Dictionary:
		for k in rf:
			ai["fails"][str(k)] = clampi(int(rf[k]), 0, 20)
	var rl: Variant = raw.get("log", [])
	if rl is Array:
		for e in rl.slice(0, LOG_MAX):
			ai["log"].append(str(e).substr(0, 60))
	var rs: Variant = raw.get("stats", {})
	if rs is Dictionary:
		for k in ai["stats"]:
			ai["stats"][k] = maxi(0, int(rs.get(k, 0)))
	return ai


# ---------------- زمان‌بندی ----------------

static func _interval(cs, npc: Dictionary) -> float:
	var base := 3.0
	match str(cs.ai_settings["level"]):
		"economy":
			base = 6.0
		"advanced":
			base = 1.5
	var p := Vector2(float(npc["x"]), float(npc["z"]))
	for name in cs.ai_positions:
		if (cs.ai_positions[name] as Vector2).distance_to(p) <= FWConst.AI_FAR_RADIUS:
			return base
	return base * FWConst.AI_FAR_MULT   # دور از همهٔ بازیکن‌ها: تصمیم‌گیری کم‌دقت‌تر


## یک گام شبیه‌سازی برای یک شخصیت. advance همان مسیریابی NPC موجود است.
static func step(cs, npc: Dictionary, dt: float, advance: Callable) -> void:
	var ai: Dictionary = npc["ai"]
	if not bool(cs.ai_settings["on"]) or not cs.accounts.has(str(npc.get("acct", ""))):
		npc["state"] = "idle"
		return
	ai["t"] = float(ai["t"]) + dt
	if (ai["plan"] as Array).is_empty():
		if float(ai["t"]) >= _interval(cs, npc):
			ai["t"] = 0.0
			think(cs, npc)
		else:
			npc["state"] = "idle"
		return
	_exec(cs, npc, dt, advance)


# ---------------- مشاهده و هدف‌ها ----------------

static func _owned(cs, acct: String) -> Dictionary:
	var out := {}
	for id in cs.buildings:
		var b: Dictionary = cs.buildings[id]
		if str(b["owner"]) == acct:
			out[str(b["type"])] = int(out.get(str(b["type"]), 0)) + 1
	return out


static func _money(cs, acct: String) -> int:
	return 1000000 if cs.creative else int(cs.accounts[acct]["money"])


static func _cost(type: String) -> int:
	return int(FWConst.BUILDING_TYPES[type]["cost"])


static func _fail_key(g: Dictionary) -> String:
	return str(g.get("kind", "")) + ":" + str(g.get("type", ""))


## رتبه‌بندی هدف‌ها بر پایهٔ ویژگی‌ها، دارایی‌ها و شکست‌های قبلی. امتیاز بالاتر = مهم‌تر.
static func rank_goals(cs, npc: Dictionary) -> Array:
	var ai: Dictionary = npc["ai"]
	var t: Dictionary = ai["traits"]
	var arch: String = ai["arch"]
	var owned: Dictionary = _owned(cs, str(npc["acct"]))
	var goals: Array = []
	for type in BUILD_TYPES:
		var c: int = int(owned.get(type, 0))
		var w: float = Personality.build_weight(arch, type)
		if w <= 0.0 or c >= (MAX_PER_TYPE if MULTI_OK.has(type) else 1):
			continue
		var prio: float = w * pow(0.55, float(c)) * (0.7 + 0.3 * float(t["ambition"]))
		if type == "house" and c == 0:
			prio = 1.3   # سرپناه همیشه اول است
		elif int(owned.get("house", 0)) == 0:
			prio *= 0.3  # بدون خانه، ساخت‌وساز دیگر زود است
		prio *= pow(0.5, float(int(ai["fails"].get("build:" + type, 0))))
		var horizon := "short" if prio >= 0.8 else ("mid" if prio >= 0.4 else "long")
		goals.append({"kind": "build", "type": type, "prio": snappedf(prio, 0.01), "h": horizon})
	# ثروت‌اندوزی: هرچه خودخواه‌تر و جاه‌طلب‌تر، مهم‌تر.
	var inc: float = 0.25 + 0.3 * float(t["selfishness"]) + 0.2 * float(t["ambition"])
	goals.append({"kind": "income", "type": "", "prio": snappedf(inc, 0.01), "h": "long"})
	goals.sort_custom(func(a, b): return float(a["prio"]) > float(b["prio"]))
	return goals.slice(0, 5)


# ---------------- برنامه‌ریزی ----------------

static func think(cs, npc: Dictionary) -> void:
	var ai: Dictionary = npc["ai"]
	var acct: String = npc["acct"]
	ai["stats"]["thoughts"] = int(ai["stats"]["thoughts"]) + 1
	if int(ai["stats"]["thoughts"]) % 10 == 0:
		for fk in ai["fails"].keys():   # شکست‌های قدیمی کم‌کم فراموش می‌شوند تا شخصیت دوباره امتحان کند
			ai["fails"][fk] = maxi(0, int(ai["fails"][fk]) - 1)
	var goals: Array = rank_goals(cs, npc)
	ai["goals"] = goals
	var money: int = _money(cs, acct)
	for g in goals:
		if g["kind"] == "build":
			if not bool(cs.ai_settings["build"]):
				continue
			var cost: int = 0 if cs.creative else _cost(str(g["type"]))
			if money >= cost:
				var site: Dictionary = find_site(cs, npc, str(g["type"]))
				if site.is_empty():
					_note_fail(ai, g, "no_site")
					continue
				ai["plan"] = [_build_step(str(g["type"]), site)]
			else:
				var plan: Array = earn_plan(cs, npc, cost - money)
				if plan.is_empty():
					_note_fail(ai, g, "no_resource")
					continue
				ai["plan"] = plan
			ai["active"] = g
			_log(ai, "%s:%s" % [g["kind"], g["type"]], cs)
			return
		else:
			var target: int = maxi(SAVINGS_TARGET - money, 0)
			if target <= 0:
				continue
			var plan2: Array = earn_plan(cs, npc, target)
			if plan2.is_empty():
				continue
			ai["plan"] = plan2
			ai["active"] = g
			_log(ai, "income", cs)
			return
	ai["plan"] = [{"t": "wait", "s": 4.0}]
	ai["active"] = {}


static func _log(ai: Dictionary, what: String, cs) -> void:
	(ai["log"] as Array).append("d%d %s" % [cs.day_count, what])
	while (ai["log"] as Array).size() > LOG_MAX:
		(ai["log"] as Array).pop_front()


static func _note_fail(ai: Dictionary, g: Dictionary, why: String) -> void:
	var k := _fail_key(g)
	ai["fails"][k] = int(ai["fails"].get(k, 0)) + 1
	ai["stats"]["failed"] = int(ai["stats"]["failed"]) + 1


static func _build_step(type: String, site: Dictionary) -> Dictionary:
	var size: Array = FWConst.building_size(type)
	var door := Vector2((float(site["cx"]) + float(size[0]) * 0.5) * FWConst.CELL_SIZE, (float(site["cz"]) + float(size[1])) * FWConst.CELL_SIZE + 1.0)
	return {"t": "build", "type": type, "cx": int(site["cx"]), "cz": int(site["cz"]), "x": door.x, "z": door.y}


## جمع‌آوری منابع و فروش تا کسری پول جبران شود؛ اول تولید ساختمان‌های خودش را برمی‌دارد.
static func earn_plan(cs, npc: Dictionary, deficit: int) -> Array:
	var acct: String = npc["acct"]
	var steps: Array = []
	var need: int = deficit
	for id in cs.buildings:
		var b: Dictionary = cs.buildings[id]
		if str(b["owner"]) == acct and FWConst.PRODUCERS.has(str(b["type"])) and int(floor(float(b["stock"]))) >= 2:
			var d: Vector2 = cs.door_point(b)
			steps.append({"t": "collect", "id": int(id), "x": d.x, "z": d.y})
			need -= int(floor(float(b["stock"]))) * 6
	var pos := Vector2(float(npc["x"]), float(npc["z"]))
	var used := {}
	var n: int = clampi(int(ceil(float(maxi(need, 0)) / 9.0)), 2 if need > 0 else 0, 5)
	for i in n:
		var r: Dictionary = find_resource(cs, npc, pos, used)
		if r.is_empty():
			break
		used[r["key"]] = true
		steps.append({"t": "gather", "rx": r["rx"], "rz": r["rz"], "x": r["x"], "z": r["z"], "tool": r["tool"], "key": r["key"]})
		pos = Vector2(r["x"], r["z"])
	if steps.is_empty():
		return []
	var p := plaza()
	steps.append({"t": "sell_all", "x": p.x, "z": p.y})
	return steps


## نزدیک‌ترین منبع قابل‌برداشت (درخت/سنگ/خاک رس) با کمی ترجیح به کالای گران‌تر.
static func find_resource(cs, npc: Dictionary, from: Vector2, used: Dictionary) -> Dictionary:
	var ai: Dictionary = npc["ai"]
	var cell := FWConst.RESOURCE_CELL
	var cx0 := int(floor(from.x / cell))
	var cz0 := int(floor(from.y / cell))
	var best := {}
	var best_score := INF
	var R := FWConst.AI_SCAN_CELLS
	for dx in range(-R, R + 1):
		for dz in range(-R, R + 1):
			var rx := cx0 + dx
			var rz := cz0 + dz
			var key := "%d,%d" % [rx, rz]
			if cs.depleted.has(key) or used.has(key) or int(ai["bad"].get(key, -99)) >= cs.day_count - BAD_RESOURCE_DAYS:
				continue
			var node: Dictionary = cs.world.resource_in_cell(rx, rz)
			if node.is_empty():
				continue
			var kind := str(node["kind"])
			if not (kind in ["tree", "rock", "clay"]):
				continue
			var def: Dictionary = FWConst.RESOURCES[kind]
			var d: float = from.distance_to(Vector2(float(node["x"]), float(node["z"])))
			var score: float = d - float(FWConst.ITEMS.get(str(def["item"]), 1.0)) * 2.0
			if score < best_score:
				best_score = score
				best = {"rx": rx, "rz": rz, "x": float(node["x"]), "z": float(node["z"]), "tool": str(def["tool"]), "key": key}
	return best


## نزدیک‌ترین محل مجاز برای ساختمان، دور از میدان؛ اطراف خانهٔ خودش یا میدان جستجو می‌شود.
static func find_site(cs, npc: Dictionary, type: String) -> Dictionary:
	var acct: String = npc["acct"]
	var anchor := Vector2i(FWConst.PLAZA_MIN - 4 - (int(npc["id"]) % 3) * 3, FWConst.PLAZA_MIN + (int(npc["id"]) % 5) - 2)
	for id in cs.buildings:
		var b: Dictionary = cs.buildings[id]
		if str(b["owner"]) == acct and str(b["type"]) == "house":
			anchor = Vector2i(int(b["cx"]), int(b["cz"]))
	var role: String = cs.role_of(acct)
	for r in range(2, 26):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var cx: int = anchor.x + dx
				var cz: int = anchor.y + dz
				if Placement.check(cs.world, cs.occupied, type, cx, cz, role) == "" and not cs.blocks_in_footprint(type, cx, cz):
					return {"cx": cx, "cz": cz}
	return {}


# ---------------- اجرا ----------------

static func _move(cs, npc: Dictionary, target: Vector2, reach: float, dt: float, advance: Callable) -> bool:
	var pos := Vector2(float(npc["x"]), float(npc["z"]))
	if pos.distance_to(target) <= reach:
		return true
	var mv: Dictionary = advance.call(cs, npc, pos, target, dt)
	var np: Vector2 = mv["p"]
	if bool(mv["arrived"]) and np.distance_to(target) > reach:
		# مسیر به مرکز سلول رسید ولی هنوز دور است: مستقیم نزدیک شو (مثل بازگشت امن مسیریابی)
		var nxt: Vector2 = np + (target - np).normalized() * minf(FWConst.NPC_SPEED * dt, np.distance_to(target))
		if cs.world.height_at(nxt.x, nxt.y) >= -0.3:
			np = nxt
	npc["x"] = np.x
	npc["z"] = np.y
	npc["state"] = "walk"
	return np.distance_to(target) <= reach


static func _fail_step(cs, npc: Dictionary, st: Dictionary, err: String) -> void:
	var ai: Dictionary = npc["ai"]
	ai["stats"]["failed"] = int(ai["stats"]["failed"]) + 1
	if st.has("key"):
		ai["bad"][str(st["key"])] = cs.day_count   # این منبع را چند روز نادیده بگیر
	var g: Dictionary = ai["active"]
	if not g.is_empty() and str(st["t"]) in ["build"]:
		var k := _fail_key(g)
		ai["fails"][k] = int(ai["fails"].get(k, 0)) + 1
	_log(ai, "fail:%s:%s" % [st["t"], err], cs)
	ai["plan"] = []
	ai["w"] = 0.0


static func _exec(cs, npc: Dictionary, dt: float, advance: Callable) -> void:
	var ai: Dictionary = npc["ai"]
	var acct: String = npc["acct"]
	var plan: Array = ai["plan"]
	var st: Dictionary = plan[0]
	var pos := Vector2(float(npc["x"]), float(npc["z"]))
	match str(st["t"]):
		"wait":
			npc["state"] = "idle"
			ai["w"] = float(ai["w"]) + dt
			if float(ai["w"]) >= float(st["s"]):
				ai["w"] = 0.0
				plan.pop_front()
		"gather":
			if not _move(cs, npc, Vector2(float(st["x"]), float(st["z"])), FWConst.GATHER_RANGE - 2.0, dt, advance):
				return
			npc["state"] = "work"
			ai["w"] = float(ai["w"]) + dt
			if float(ai["w"]) < GATHER_SECONDS:
				return
			ai["w"] = 0.0
			var res: Dictionary = cs.gather(acct, int(st["rx"]), int(st["rz"]), str(st["tool"]), pos)
			if bool(res["ok"]):
				ai["stats"]["gathered"] = int(ai["stats"]["gathered"]) + int(res.get("count", 0))
				plan.pop_front()
			else:
				_fail_step(cs, npc, st, str(res["error"]))
		"sell_all":
			if not _move(cs, npc, Vector2(float(st["x"]), float(st["z"])), 3.0, dt, advance):
				return
			var inv: Dictionary = cs.accounts[acct]["inv"]
			for item in inv.keys():
				var n: int = int(inv[item])
				if n > 0 and FWConst.ITEMS.has(item):
					var r: Dictionary = cs.trade(acct, str(item), n, false)
					if bool(r["ok"]):
						ai["stats"]["sold"] = int(ai["stats"]["sold"]) + int(r["total"])
			_log(ai, "sold", cs)
			plan.pop_front()
		"collect":
			if not _move(cs, npc, Vector2(float(st["x"]), float(st["z"])), 2.5, dt, advance):
				return
			var r2: Dictionary = cs.collect(acct, int(st["id"]))
			if bool(r2["ok"]):
				ai["stats"]["sold"] = int(ai["stats"]["sold"]) + int(r2["earned"])
			plan.pop_front()
		"build":
			if not _move(cs, npc, Vector2(float(st["x"]), float(st["z"])), 2.5, dt, advance):
				return
			npc["state"] = "work"
			ai["w"] = float(ai["w"]) + dt
			if float(ai["w"]) < BUILD_SECONDS:
				return
			ai["w"] = 0.0
			var res2: Dictionary = cs.place_building(acct, 0, str(st["type"]), int(st["cx"]), int(st["cz"]))
			if bool(res2["ok"]):
				ai["stats"]["built"] = int(ai["stats"]["built"]) + 1
				ai["fails"].erase("build:" + str(st["type"]))
				cs.ai_events.append({"kind": "built", "id": int(res2["building"]["id"])})
				_log(ai, "built:" + str(st["type"]), cs)
				plan.pop_front()
			else:
				_fail_step(cs, npc, st, str(res2["error"]))
		_:
			plan.pop_front()
