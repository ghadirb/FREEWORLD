extends RefCounted
## شبیه‌سازی NPCها (ماشین حالت ساده + برنامه روزانه). فقط روی سرور اجرا می‌شود.
## برنامه: ۶ بیدار شدن، ۷ رفتن به کار، ۸ تا ۱۷ کار، ۱۷ بازگشت، ۱۸ تا ۲۱ مغازه، ۲۲ خواب.

const FWConst = preload("res://scripts/core/const.gd")
const NpcNav = preload("res://scripts/server/npc_nav.gd")
const Residents = preload("res://scripts/server/residents.gd")
const Family = preload("res://scripts/server/family.gd")
const CharAI = preload("res://scripts/server/char_ai.gd")
const CharWatch = preload("res://scripts/server/char_watch.gd")
const CharSocial = preload("res://scripts/server/char_social.gd")
const CharWar = preload("res://scripts/server/char_war.gd")


static func hour_of(cs) -> float:
	return cs.world_time / 3600.0


static func ensure_npcs(cs, count: int = FWConst.NPC_COUNT) -> void:
	var plaza := FWConst.CITY_SIZE * 0.5
	while cs.npcs.size() < count:
		var i: int = cs.npcs.size()
		cs.npcs.append({
			"id": i + 1,
			"name": FWConst.NPC_NAMES[i % FWConst.NPC_NAMES.size()],
			"x": plaza + float(i) * 2.0 - 3.0,
			"z": plaza - 4.0,
			"state": "idle",
			"money": 100,
			"paid_day": -1,
		})


static func _list(cs, type: String) -> Array:
	var out: Array = []
	var ids: Array = cs.buildings.keys()
	ids.sort()
	for id in ids:
		if cs.buildings[id]["type"] == type:
			out.append(cs.buildings[id])
	return out


static func _pick(items: Array, index: int):
	if items.is_empty():
		return null
	return items[index % items.size()]


## برنامهٔ روزانه: نام فعالیت را برای ساعت داده‌شده برمی‌گرداند.
static func activity_for_hour(h: float) -> String:
	if h >= 22.0 or h < 6.0:
		return "sleep"
	if h < 7.0:
		return "wake"
	if h < 8.0:
		return "commute_work"
	if h < 17.0:
		return "work"
	if h < 18.0:
		return "commute_home"
	if h < 21.0:
		return "leisure"
	return "commute_home"


static func target_for(cs, npc: Dictionary, activity: String) -> Variant:
	var idx: int = int(npc["id"]) - 1
	var plaza := Vector2(FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5 - 4.0)
	match activity:
		"idle_home":
			var kb: int = int(npc.get("home_b", -1))
			return cs.door_point(cs.buildings[kb]) + Vector2(1.5, 1.5) if cs.buildings.has(kb) else plaza
		"sleep", "wake", "commute_home":
			var home = _pick(_list(cs, "house"), idx)
			var hb: int = int(npc.get("home_b", -1))
			if hb >= 0 and cs.buildings.has(hb):
				home = cs.buildings[hb]
			return cs.door_point(home) if home != null else plaza
		"commute_work", "work":
			var wbid: int = int(npc.get("wb", -1))
			if str(npc.get("emp", "")) != "" and cs.buildings.has(wbid):
				return cs.door_point(cs.buildings[wbid])
			var farms := _list(cs, "farm")
			var job = _pick(farms, idx)
			if job == null:
				job = _pick(_list(cs, "shop"), idx)
			return cs.door_point(job) if job != null else plaza
		"leisure":
			var shop = _pick(_list(cs, "shop"), idx)
			return cs.door_point(shop) if shop != null else plaza
	return plaza


static func _work_building(cs, npc: Dictionary):
	var idx: int = int(npc["id"]) - 1
	var job = _pick(_list(cs, "farm"), idx)
	if job == null:
		job = _pick(_list(cs, "shop"), idx)
	return job


## یک گام حرکت NPC به سمت مقصد با دور زدن موانع. {p: موقعیت جدید, arrived: bool}
static func _advance(cs, npc: Dictionary, pos: Vector2, target: Vector2, dt: float) -> Dictionary:
	var goal: Vector2i = NpcNav.cell_of(target)
	var st = cs.npc_paths.get(npc["id"])
	if st == null or st["goal"] != goal or st["ver"] != cs.nav_version:
		var found = cs.nav.find_path(pos, target)
		st = {"goal": goal, "ver": cs.nav_version, "found": found != null,
			"pts": found if found != null else []}
		cs.npc_paths[npc["id"]] = st
	if not st["found"]:
		# مسیری وجود ندارد (محاصره‌شده): مثل قبل مستقیم برو تا اقتصاد متوقف نشود.
		var dist: float = pos.distance_to(target)
		var nxt: Vector2 = pos + (target - pos).normalized() * minf(FWConst.NPC_SPEED * dt, dist)
		if cs.world.height_at(nxt.x, nxt.y) >= -0.3:
			return {"p": nxt, "arrived": false}
		return {"p": pos, "arrived": false}
	var pts: Array = st["pts"]
	if pts.is_empty():
		return {"p": pos, "arrived": true}
	var budget: float = FWConst.NPC_SPEED * dt
	var p: Vector2 = pos
	while budget > 0.0 and not pts.is_empty():
		var w: Vector2 = pts[0]
		var d: float = p.distance_to(w)
		if d <= budget:
			p = w
			budget -= d
			pts.pop_front()
		else:
			p += (w - p).normalized() * budget
			budget = 0.0
	return {"p": p, "arrived": false}


## ساعت تفریح: هر NPC روزی یک‌بار هزینهٔ ثابت مغازه می‌دهد و یک‌بار (اگر نان در بازار باشد) نان می‌خرد.
static func _leisure_shopping(cs, npc: Dictionary, day: int) -> void:
	var shop = _pick(_list(cs, "shop"), int(npc["id"]) - 1)
	if shop == null:
		return
	if int(npc["paid_day"]) != day and int(npc["money"]) >= FWConst.NPC_SHOP_PAYMENT:
		var owner_name: String = shop["owner"]
		if cs.accounts.has(owner_name):
			npc["money"] = int(npc["money"]) - FWConst.NPC_SHOP_PAYMENT
			cs.accounts[owner_name]["money"] = int(cs.accounts[owner_name]["money"]) + FWConst.NPC_SHOP_PAYMENT
			npc["paid_day"] = day
	if int(npc.get("bread_day", -1)) != day and cs.npc_buy_bread(npc, shop):
		npc["bread_day"] = day
	# هر روز یک خوراکی پروتئینی/لبنی (به‌نوبت)، اگر در بازار باشد.
	if int(npc.get("goods_day", -1)) != day:
		var order: Array = ["egg", "milk", "cheese"] if (int(npc["id"]) + day) % 2 == 0 else ["cheese", "milk", "egg"]
		for g in order:
			if cs.npc_buy_good(npc, shop, g):
				npc["goods_day"] = day
				break


static func step(cs, dt: float) -> void:
	var h := hour_of(cs)
	var day := int(floor(cs.world_time / 86400.0))
	var activity := activity_for_hour(h)
	cs.ai_thinks_left = CharAI.think_budget(cs)   # سقف تصمیم‌های هر گام: جلوگیری از پرش وقتی چند شخصیت هم‌زمان فکر می‌کنند
	CharSocial.tick(cs, dt)   # شخصیت‌های مستقل با هم تعامل می‌کنند (مرحلهٔ ۵)
	CharWar.tick(cs, dt)      # جنگ، عقب‌نشینی و مذاکره بین شخصیت‌ها
	for npc in cs.npcs:
		if CharAI.is_ai(npc):
			CharAI.step(cs, npc, dt, _advance)   # شخصیت هوشمند: برنامهٔ روزانه ندارد، خودش تصمیم می‌گیرد
			continue
		if Residents.is_villager(npc):
			_step_villager(cs, npc, activity, day, dt)
			continue
		var kid: bool = bool(npc.get("kid", false))
		var target: Vector2 = target_for(cs, npc, "idle_home" if kid else activity)
		var pos := Vector2(npc["x"], npc["z"])
		var dist: float = pos.distance_to(target)
		var arrived: bool = dist <= 1.0
		if not arrived:
			var mv: Dictionary = _advance(cs, npc, pos, target, dt)
			npc["x"] = mv["p"].x
			npc["z"] = mv["p"].y
			arrived = mv["arrived"]
			if not arrived:
				npc["state"] = "walk"
		if arrived and kid:
			npc["state"] = "idle"
		elif arrived:
			npc["state"] = activity
			if activity == "work" and str(npc.get("job", "")) != "":
				Residents.work_daily(cs, npc, day)
			if activity == "work" and str(npc.get("emp", "")) != "":
				Family.work(cs, npc, dt)
			elif activity == "work":
				var b = _work_building(cs, npc)
				if b != null and b["type"] == "farm":
					b["stock"] = minf(FWConst.FARM_MAX_STOCK,
						float(b["stock"]) + dt / FWConst.FARM_SECONDS_PER_WHEAT * FWConst.NPC_WORK_BONUS)
			elif activity == "leisure":
				_leisure_shopping(cs, npc, day)
	_daily_income(cs, day)
	Family.daily(cs, day)


## ساکن روستا: بدون مسیریابی شهری؛ مستقیم و آهسته به مقصد می‌رود و آب را دور می‌زند.
static func _step_villager(cs, npc: Dictionary, activity: String, day: int, dt: float) -> void:
	var target: Vector2 = Residents.village_target(cs, npc, activity)
	var pos := Vector2(npc["x"], npc["z"])
	var dist: float = pos.distance_to(target)
	if dist > 0.6:
		var nxt: Vector2 = pos + (target - pos).normalized() * minf(FWConst.NPC_SPEED * dt, dist)
		if cs.world.height_at(nxt.x, nxt.y) >= -0.3 and not cs.world.village_solid_at(nxt.x, nxt.y, 0.2):
			npc["x"] = nxt.x
			npc["z"] = nxt.y
		npc["state"] = "walk"
		return
	npc["state"] = activity
	if activity == "work":
		Residents.work_daily(cs, npc, day)


## هر NPC روزی NPC_DAILY_INCOME سکه درآمد دارد (سقف NPC_MAX_MONEY) تا چرخهٔ خرید متوقف نشود.
static func _daily_income(cs, day: int) -> void:
	for npc in cs.npcs:
		if not npc.has("income_day") or int(npc["income_day"]) != day:
			npc["income_day"] = day
			npc["money"] = mini(int(npc["money"]) + FWConst.NPC_DAILY_INCOME, FWConst.NPC_MAX_MONEY)


## فقط NPCهای نزدیک (x, z)؛ ساکنان روستاهای دور برای این بازیکن فرستاده نمی‌شوند.
static func public_list_near(cs, x: float, z: float, radius: float = FWConst.NPC_SYNC_RADIUS) -> Array:
	var out: Array = []
	var r2 := radius * radius
	for n in cs.npcs:
		var dx: float = float(n["x"]) - x
		var dz: float = float(n["z"]) - z
		if dx * dx + dz * dz <= r2:
			var row: Array = [n["id"], snappedf(n["x"], 0.1), snappedf(n["z"], 0.1), n["state"], n["name"], Residents.is_inside(n), _tag(n)]
			if CharAI.is_ai(n):
				row.append(CharWatch.activity_short(cs, n))   # نشانگر کار فعلی بالای سر شخصیت مستقل
			out.append(row)
	return out


static func _tag(n: Dictionary) -> String:
	return CharAI.tag(n) if CharAI.is_ai(n) else Family.tag(n)


static func public_list(cs) -> Array:
	var out: Array = []
	for n in cs.npcs:
		out.append([n["id"], snappedf(n["x"], 0.1), snappedf(n["z"], 0.1), n["state"], n["name"], Residents.is_inside(n), _tag(n)])
	return out
