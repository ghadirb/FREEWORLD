extends RefCounted
## ساکنان خانه‌ها: (۱) هر خانهٔ روستای آماده یک ساکن دارد؛ (۲) خانهٔ ساخته‌شدهٔ بازیکن
## با تخت و غذا مهاجر می‌گیرد. هر ساکن یک شغل دارد و به اقتصاد بازار وصل است.
## فقط روی سرور اجرا می‌شود؛ همه‌چیز قطعی و ذخیره‌شونده است.

const FWConst = preload("res://scripts/core/const.gd")

const FOOD := ["bread", "egg", "milk", "cheese", "wheat"]


static func is_villager(npc: Dictionary) -> bool:
	return str(npc.get("home_v", "")) != ""


static func count_villagers(cs) -> int:
	var n := 0
	for npc in cs.npcs:
		if is_villager(npc):
			n += 1
	return n


## NPCهایی که در سقف NPC_MAX حساب می‌شوند (ساکنان روستا جدا شمرده می‌شوند).
static func count_capped(cs) -> int:
	return cs.npcs.size() - count_villagers(cs)


static func _next_id(cs) -> int:
	var nid := 1
	for n in cs.npcs:
		nid = maxi(nid, int(n["id"]) + 1)
	return nid


static func _new_npc(cs, x: float, z: float) -> Dictionary:
	var nid := _next_id(cs)
	return {
		"id": nid, "name": FWConst.NPC_NAMES[(nid - 1) % FWConst.NPC_NAMES.size()],
		"x": x, "z": z, "state": "idle", "money": 100, "paid_day": -1,
		"job": "", "home_b": -1, "home_v": "", "vx": 0.0, "vz": 0.0,
	}


## یک بار برای هر جهان: به هر خانهٔ روستا یک ساکن می‌دهد؛ ابتدا روستاهای نزدیک به شهر، تا سقف VILLAGER_MAX.
static func seed_villagers(cs) -> int:
	if cs.villagers_seeded:
		return 0
	cs.villagers_seeded = true
	var center := Vector2(FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5)
	var vs: Array = cs.world.villages().duplicate()
	vs.sort_custom(func(a, b):
		var da := Vector2(float(a["x"]), float(a["z"])).distance_to(center)
		var db := Vector2(float(b["x"]), float(b["z"])).distance_to(center)
		return da < db if da != db else str(a["id"]) < str(b["id"]))
	var added := 0
	var jobs_i := 0
	for v in vs:
		var houses: Array = v["houses"]
		for i in houses.size():
			if count_villagers(cs) >= FWConst.VILLAGER_MAX:
				return added
			var h: Dictionary = houses[i]
			var npc := _new_npc(cs, float(h["ex"]), float(h["ez"]))
			npc["home_v"] = "h%d,%d,%d" % [int(v["x"]), int(v["z"]), i] if not h.has("id") else str(h["id"])
			npc["vx"] = float(v["x"])
			npc["vz"] = float(v["z"])
			npc["job"] = FWConst.RESIDENT_JOBS[jobs_i % FWConst.RESIDENT_JOBS.size()]
			jobs_i += 1
			cs.npcs.append(npc)
			added += 1
	return added


## ساعت کاری ساکنان: کشاورز گندم می‌دهد، نانوا آرد را نان می‌کند، همه روزی یک غذا می‌خورند.
## برای هر ساکن در هر روز حداکثر یک بار اجرا می‌شود. در جهان خلاقانه اقتصاد دست نمی‌خورد.
static func work_daily(cs, npc: Dictionary, day: int) -> void:
	if int(npc.get("wk_day", -1)) == day:
		return
	npc["wk_day"] = day
	if cs.creative:
		return
	var m: Dictionary = cs.market
	match str(npc.get("job", "")):
		"farmer":
			m["wheat"] = minf(FWConst.MARKET_MAX_STOCK, float(m["wheat"]) + FWConst.RESIDENT_WHEAT_PER_DAY)
		"baker":
			var f := minf(FWConst.RESIDENT_BAKER_FLOUR, float(m["flour"]))
			if f >= 2.0:
				m["flour"] = float(m["flour"]) - f
				m["bread"] = minf(FWConst.MARKET_MAX_STOCK, float(m["bread"]) + f)
	_eat(cs)


## مصرف روزانهٔ غذا از بازار (نان، تخم‌مرغ، شیر، پنیر، گندم - به همین ترتیب).
static func _eat(cs) -> void:
	var need: float = FWConst.RESIDENT_EAT_PER_DAY
	for g in FOOD:
		var have: float = float(cs.market.get(g, 0.0))
		if have >= need:
			cs.market[g] = have - need
			return


static func food_total(cs) -> float:
	var t := 0.0
	for g in FOOD:
		t += float(cs.market.get(g, 0.0))
	return t


static func _has_bed(b: Dictionary) -> bool:
	for e in b.get("furn", []):
		if str(e.get("t", "")) == "bed":
			return true
	return false


static func home_taken(cs, bid: int) -> bool:
	for n in cs.npcs:
		if int(n.get("home_b", -1)) == bid:
			return true
	return false


static func _pick_job(cs) -> String:
	var counts := {}
	for j in FWConst.RESIDENT_JOBS:
		counts[j] = 0
	for n in cs.npcs:
		var j: String = str(n.get("job", ""))
		if counts.has(j):
			counts[j] = int(counts[j]) + 1
	var has_farm := false
	var has_bakery := false
	for id in cs.buildings:
		match str(cs.buildings[id]["type"]):
			"farm": has_farm = true
			"bakery": has_bakery = true
	var best: String = FWConst.RESIDENT_JOBS[0]
	var best_c := 1 << 30
	for j in FWConst.RESIDENT_JOBS:
		var c: int = int(counts[j])
		if j == "farmer" and not has_farm:
			c += 1000
		if j == "baker" and not has_bakery:
			c += 1000
		if c < best_c:
			best_c = c
			best = j
	return best


## هر روز بازی: خانه‌های بازیکن را بررسی می‌کند. خانه‌ای که حداقل یک روز از ساختش گذشته،
## تخت دارد و بازار غذا دارد یک مهاجر می‌گیرد (حداکثر MIGRANT_MAX_PER_DAY در روز).
static func daily(cs, day: int) -> int:
	# ساکنِ خانه‌ای که خراب شده بی‌خانه می‌شود (NPC عادی می‌ماند).
	for n in cs.npcs:
		var hb: int = int(n.get("home_b", -1))
		if hb >= 0 and not cs.buildings.has(hb):
			n["home_b"] = -1
	for k in cs.house_seen.keys().duplicate():
		if not cs.buildings.has(int(k)):
			cs.house_seen.erase(k)
	if cs.creative:
		return 0
	var ids: Array = cs.buildings.keys()
	ids.sort()
	var arrived := 0
	for id in ids:
		var b: Dictionary = cs.buildings[id]
		if str(b["type"]) != "house":
			continue
		var key := str(id)
		if not cs.house_seen.has(key):
			cs.house_seen[key] = day
			continue
		if arrived >= FWConst.MIGRANT_MAX_PER_DAY:
			continue
		if day - int(cs.house_seen[key]) < 1 or home_taken(cs, int(id)) or not _has_bed(b):
			continue
		if count_capped(cs) >= FWConst.NPC_MAX:
			continue
		if food_total(cs) < FWConst.MIGRANT_FOOD_MIN * float(cs.npcs.size() + 1) / 4.0:
			continue
		var door: Vector2 = cs.door_point(b)
		var npc := _new_npc(cs, door.x, door.y)
		npc["home_b"] = int(id)
		npc["job"] = _pick_job(cs)
		cs.npcs.append(npc)
		cs._log(str(b["owner"]), "migrant", {"house": int(id), "npc": int(npc["id"]), "job": npc["job"]})
		arrived += 1
	return arrived


## مقصد ساکن روستا برای فعالیت جاری (به صورت Vector2).
static func village_target(cs, npc: Dictionary, activity: String) -> Vector2:
	var c := Vector2(float(npc["vx"]), float(npc["vz"]))
	var a: float = float(int(npc["id"]) % 7) * 0.9
	match activity:
		"sleep", "wake", "commute_home":
			var h: Dictionary = cs.world.house_site(str(npc["home_v"]))
			if not h.is_empty():
				return Vector2(float(h["ex"]), float(h["ez"]))
			return c + Vector2(cos(a), sin(a)) * 4.0
		"commute_work", "work":
			return c + Vector2(cos(a), sin(a)) * 4.5
	return c + Vector2(cos(a + 2.0), sin(a + 2.0)) * 3.0


## ساکن در خواب کنار در خانه‌اش «داخل خانه» حساب می‌شود (مشتری آن را نمی‌بیند).
static func is_inside(npc: Dictionary) -> int:
	if str(npc.get("state", "")) != "sleep":
		return 0
	return 1 if (is_villager(npc) or int(npc.get("home_b", -1)) >= 0) else 0
