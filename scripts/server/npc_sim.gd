extends RefCounted
## شبیه‌سازی NPCها (ماشین حالت ساده + برنامه روزانه). فقط روی سرور اجرا می‌شود.
## برنامه: ۶ بیدار شدن، ۷ رفتن به کار، ۸ تا ۱۷ کار، ۱۷ بازگشت، ۱۸ تا ۲۱ مغازه، ۲۲ خواب.

const FWConst = preload("res://scripts/core/const.gd")


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
		"sleep", "wake", "commute_home":
			var home = _pick(_list(cs, "house"), idx)
			return cs.door_point(home) if home != null else plaza
		"commute_work", "work":
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


static func step(cs, dt: float) -> void:
	var h := hour_of(cs)
	var day := int(floor(cs.world_time / 86400.0))
	var activity := activity_for_hour(h)
	for npc in cs.npcs:
		var target: Vector2 = target_for(cs, npc, activity)
		var pos := Vector2(npc["x"], npc["z"])
		var dist: float = pos.distance_to(target)
		if dist > 1.0:
			var next: Vector2 = pos + (target - pos).normalized() * minf(FWConst.NPC_SPEED * dt, dist)
			if cs.world.height_at(next.x, next.y) >= -0.3:
				npc["x"] = next.x
				npc["z"] = next.y
			npc["state"] = "walk"
		else:
			npc["state"] = activity
			if activity == "work":
				var b = _work_building(cs, npc)
				if b != null and b["type"] == "farm":
					b["stock"] = minf(FWConst.FARM_MAX_STOCK,
						float(b["stock"]) + dt / FWConst.FARM_SECONDS_PER_WHEAT * FWConst.NPC_WORK_BONUS)
			elif activity == "leisure" and int(npc["paid_day"]) != day:
				var shop = _pick(_list(cs, "shop"), int(npc["id"]) - 1)
				if shop != null and int(npc["money"]) >= FWConst.NPC_SHOP_PAYMENT:
					var owner_name: String = shop["owner"]
					if cs.accounts.has(owner_name):
						npc["money"] = int(npc["money"]) - FWConst.NPC_SHOP_PAYMENT
						cs.accounts[owner_name]["money"] = int(cs.accounts[owner_name]["money"]) + FWConst.NPC_SHOP_PAYMENT
						npc["paid_day"] = day
	_daily_income(cs, day)


## هر NPC روزی ۳ سکه درآمد دارد (سقف ۲۰۰) تا چرخهٔ خرید از مغازه متوقف نشود.
static func _daily_income(cs, day: int) -> void:
	for npc in cs.npcs:
		if not npc.has("income_day") or int(npc["income_day"]) != day:
			npc["income_day"] = day
			npc["money"] = mini(int(npc["money"]) + 3, 200)


static func public_list(cs) -> Array:
	var out: Array = []
	for n in cs.npcs:
		out.append([n["id"], snappedf(n["x"], 0.1), snappedf(n["z"], 0.1), n["state"], n["name"]])
	return out
