extends RefCounted
## مدیریت مجموعه (پروتکل ۵۳): باغ‌وحش و شهربازی. فقط روی سرور؛ همه‌چیز آفلاین هم کار می‌کند.
## هر ATTR_SECONDS ثانیه «بلیط» (سکه) به موجودی ساختمان اضافه می‌شود و صاحب با «برداشت» آن را می‌گیرد.
## باغ‌وحش: هرچه گونه‌های متفاوتِ بیشتری نزدیک در باشند و گونهٔ ترکیبی کمیاب‌تر، بلیط بیشتر.
## شهربازی: هرچه وسیله بیشتر (ارتقا با سکه) و NPC بزرگسال نزدیک بیشتر، بلیط بیشتر.

const FWConst = preload("res://scripts/core/const.gd")


static func is_attraction(type: String) -> bool:
	return FWConst.ATTRACTIONS.has(type)


static func stock_max(type: String) -> float:
	return FWConst.ZOO_MAX if type == "zoo" else FWConst.PARK_MAX


## آمار مجموعهٔ باغ‌وحش: {species, hybrids, animals}. توله‌ها شمرده نمی‌شوند.
static func zoo_stats(cs, b: Dictionary) -> Dictionary:
	var door: Vector2 = cs.door_point(b)
	var kinds := {}
	var animals := 0
	var r2: float = FWConst.ZOO_RADIUS * FWConst.ZOO_RADIUS
	for id in cs.god:
		var g: Dictionary = cs.god[id]
		if not FWConst.is_animal(str(g["kind"])) or float(g.get("young", 0.0)) > 0.0:
			continue
		var dx: float = float(g["x"]) - door.x
		var dz: float = float(g["z"]) - door.y
		if dx * dx + dz * dz > r2:
			continue
		kinds[str(g["kind"])] = true
		animals += 1
	var hybrids := 0
	for k in kinds:
		if FWConst.GOD_HYBRIDS.has(k):
			hybrids += 1
	return {"species": kinds.size(), "hybrids": hybrids, "animals": animals}


static func park_visitors(cs, b: Dictionary) -> int:
	var door: Vector2 = cs.door_point(b)
	var r2: float = FWConst.PARK_VISITOR_RADIUS * FWConst.PARK_VISITOR_RADIUS
	var n := 0
	for npc in cs.npcs:
		if bool(npc.get("kid", false)):
			continue
		var dx: float = float(npc["x"]) - door.x
		var dz: float = float(npc["z"]) - door.y
		if dx * dx + dz * dz <= r2:
			n += 1
	return mini(n, FWConst.PARK_VISITOR_CAP)


## بلیط یک دوره. گونهٔ ترکیبی هم به شمار گونه‌ها می‌آید و هم پاداش جدا دارد.
static func income_per_period(cs, b: Dictionary) -> int:
	if str(b["type"]) == "zoo":
		var st: Dictionary = zoo_stats(cs, b)
		if int(st["animals"]) == 0:
			return 0
		return FWConst.ZOO_BASE + int(st["species"]) * FWConst.ZOO_PER_SPECIES \
			+ int(st["hybrids"]) * FWConst.ZOO_HYBRID_BONUS + mini(int(st["animals"]), FWConst.ZOO_ANIMAL_CAP)
	return FWConst.PARK_BASE + rides_of(b) * FWConst.PARK_PER_RIDE + park_visitors(cs, b) * FWConst.PARK_PER_VISITOR


static func rides_of(b: Dictionary) -> int:
	return clampi(int(b.get("rides", FWConst.PARK_RIDES_START)), FWConst.PARK_RIDES_START, FWConst.PARK_RIDES_MAX)


## هر گام زمان: پیشرفت دوره و افزودن بلیط به موجودی.
static func tick(cs, b: Dictionary, delta: float) -> void:
	var cap: float = stock_max(str(b["type"]))
	if float(b["stock"]) >= cap:
		return
	b["prog"] = float(b.get("prog", 0.0)) + delta
	if float(b["prog"]) < FWConst.ATTR_SECONDS:
		return
	b["prog"] = fposmod(float(b["prog"]), FWConst.ATTR_SECONDS)
	b["stock"] = minf(cap, float(b["stock"]) + float(income_per_period(cs, b)))


static func upgrade_cost(b: Dictionary) -> int:
	return FWConst.PARK_RIDE_COST * rides_of(b)


## ارتقای شهربازی: یک وسیلهٔ بازی بیشتر. فقط صاحب. در جهان خلاقانه رایگان است.
static func upgrade(cs, player: String, id: int) -> Dictionary:
	if not cs.accounts.has(player) or not cs.buildings.has(id):
		return {"ok": false, "error": "no_building"}
	var b: Dictionary = cs.buildings[id]
	if str(b["owner"]) != player:
		return {"ok": false, "error": "forbidden"}
	if str(b["type"]) != "park":
		return {"ok": false, "error": "not_park"}
	if rides_of(b) >= FWConst.PARK_RIDES_MAX:
		return {"ok": false, "error": "rides_max"}
	var cost: int = 0 if cs.creative else upgrade_cost(b)
	if not cs._pay(cs.accounts[player], cost):
		return {"ok": false, "error": "no_money"}
	b["rides"] = rides_of(b) + 1
	cs._log(player, "ride_upgrade", {"id": id, "rides": b["rides"], "cost": cost})
	return {"ok": true, "rides": b["rides"], "money": cs.accounts[player]["money"], "id": id}
