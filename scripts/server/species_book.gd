extends RefCounted
## کتابچهٔ گونه‌ها و غذا دادن به حیوانات (پروتکل ۵۷). فقط روی سرور؛ آفلاین هم کار می‌کند.
## - کتابچه برای هر بازیکن جداست: دیدن یک حیوان از نزدیک (SPECIES_SEE_RANGE) گونه را ثبت می‌کند. کلاینت چیزی «ثبت» نمی‌کند.
## - غذا دادن: یک واحد گندم از بازار مشترک به قیمت روز (مثل خوردن نان) و سیری حیوان بالا می‌رود.
## - حیوان داخل شعاع باغ‌وحش با گذر زمان گرسنه می‌شود؛ گرسنگی بلیط باغ‌وحش را کم می‌کند (attractions.gd).

const FWConst = preload("res://scripts/core/const.gd")


static func _acc(cs, player: String) -> Dictionary:
	if not cs.accounts.has(player):
		return {}
	var acc: Dictionary = cs.accounts[player]
	if not (acc.get("species") is Dictionary):
		acc["species"] = {}
	if not (acc.get("species_fed") is Dictionary):
		acc["species_fed"] = {}
	return acc


## سیری یک حیوان (ثانیه). حیوانی که هنوز سیری ندارد، سیر حساب می‌شود (حیوان تازه‌رسیده به باغ‌وحش).
static func fed_of(g: Dictionary) -> float:
	return clampf(float(g.get("fed", FWConst.FEED_START)), 0.0, FWConst.FEED_MAX)


static func is_fed(g: Dictionary) -> bool:
	return fed_of(g) > 0.0


## نزدیک‌ترین حیوان به pos در برد؛ ‌-۱ اگر نبود. هم‌فاصله ← شناسهٔ کمتر (قطعی).
static func nearest_animal(cs, pos: Vector2, rng: float) -> int:
	var best := -1
	var best_d := rng * rng + 0.0001
	var ids: Array = cs.god.keys()
	ids.sort()
	for id in ids:
		var g: Dictionary = cs.god[id]
		if not FWConst.is_animal(str(g["kind"])):
			continue
		var dx: float = float(g["x"]) - pos.x
		var dz: float = float(g["z"]) - pos.y
		var d2: float = dx * dx + dz * dz
		if d2 < best_d:
			best_d = d2
			best = int(id)
	return best


## گونه‌های تازه‌دیده‌شدهٔ بازیکن: [{kind, reward, complete}]. complete = جایزهٔ کامل‌شدن کتابچه (۰ اگر نه).
static func observe(cs, player: String, pos: Vector2) -> Array:
	var out: Array = []
	var acc := _acc(cs, player)
	if acc.is_empty():
		return out
	var r2: float = FWConst.SPECIES_SEE_RANGE * FWConst.SPECIES_SEE_RANGE
	var ids: Array = cs.god.keys()
	ids.sort()
	for id in ids:
		var g: Dictionary = cs.god[id]
		var k := str(g["kind"])
		if not FWConst.SPECIES_ORDER.has(k) or acc["species"].has(k):
			continue
		var dx: float = float(g["x"]) - pos.x
		var dz: float = float(g["z"]) - pos.y
		if dx * dx + dz * dz > r2:
			continue
		out.append(_record(cs, player, acc, k))
	return out


static func _record(cs, player: String, acc: Dictionary, kind: String) -> Dictionary:
	acc["species"][kind] = maxi(1, int(cs.day_count))
	var reward := 0
	if not cs.creative:
		reward = FWConst.SPECIES_HYBRID_REWARD if FWConst.GOD_HYBRIDS.has(kind) else FWConst.SPECIES_REWARD
		acc["money"] = int(acc["money"]) + reward
	var complete := 0
	if acc["species"].size() >= FWConst.SPECIES_ORDER.size():
		if not cs.creative:
			complete = FWConst.SPECIES_COMPLETE_BONUS
			acc["money"] = int(acc["money"]) + complete
		else:
			complete = -1   # کامل شد (جهان خلاقانه جایزه ندارد)
	cs._log(player, "species_seen", {"kind": kind, "reward": reward})
	return {"kind": kind, "reward": reward, "complete": complete}


## غذا دادن به نزدیک‌ترین حیوان (در FEED_RANGE). خطاها: no_account، no_animal، animal_full، no_stock، no_money.
static func feed(cs, player: String, pos: Vector2) -> Dictionary:
	var acc := _acc(cs, player)
	if acc.is_empty():
		return {"ok": false, "error": "no_account"}
	var id := nearest_animal(cs, pos, FWConst.FEED_RANGE)
	if id < 0:
		return {"ok": false, "error": "no_animal"}
	var g: Dictionary = cs.god[id]
	if fed_of(g) >= FWConst.FEED_MAX - 1.0:
		return {"ok": false, "error": "animal_full"}
	var paid := 0
	if not cs.creative:
		if float(cs.market.get("wheat", 0.0)) < 1.0:
			return {"ok": false, "error": "no_stock"}
		paid = int(ceil(cs._price_for("wheat")))
		if not cs._pay(acc, paid):
			return {"ok": false, "error": "no_money"}
		cs.market["wheat"] = float(cs.market["wheat"]) - 1.0
	g["fed"] = minf(FWConst.FEED_MAX, fed_of(g) + FWConst.FEED_ADD)
	var k := str(g["kind"])
	acc["species_fed"][k] = int(acc["species_fed"].get(k, 0)) + 1
	var seen: Array = []
	if FWConst.SPECIES_ORDER.has(k) and not acc["species"].has(k):
		seen.append(_record(cs, player, acc, k))   # غذا دادن هم گونه را ثبت می‌کند
	cs._log(player, "feed_animal", {"kind": k, "paid": paid})
	return {"ok": true, "id": id, "kind": k, "paid": paid, "fed": int(round(100.0 * fed_of(g) / FWConst.FEED_MAX)), "seen": seen}


## گرسنه‌شدن: فقط حیواناتی که داخل شعاع یک باغ‌وحش‌اند (حیوان آزاد خودش می‌چرد). true اگر چیزی عوض شد.
static func hunger_step(cs, dt: float) -> bool:
	var doors: Array = []
	for id in cs.buildings:
		if str(cs.buildings[id]["type"]) == "zoo":
			doors.append(cs.door_point(cs.buildings[id]))
	if doors.is_empty():
		return false
	var r2: float = FWConst.ZOO_RADIUS * FWConst.ZOO_RADIUS
	var changed := false
	for gid in cs.god:
		var g: Dictionary = cs.god[gid]
		if not FWConst.is_animal(str(g["kind"])):
			continue
		for d in doors:
			var dx: float = float(g["x"]) - d.x
			var dz: float = float(g["z"]) - d.y
			if dx * dx + dz * dz <= r2:
				g["fed"] = maxf(0.0, fed_of(g) - dt)
				changed = true
				break
	return changed


## وضعیت کتابچه برای کلاینت: rows = [[گونه، روز دیدن (۰ = ندیده)، تعداد وعده، ۱ اگر ترکیبی]]،
## done، total، complete و zoo = [تعداد حیوان، تعداد سیر] در همهٔ باغ‌وحش‌های خود بازیکن.
static func public_state(cs, player: String) -> Dictionary:
	var acc := _acc(cs, player)
	var rows: Array = []
	var done := 0
	for k in FWConst.SPECIES_ORDER:
		var day := int(acc.get("species", {}).get(k, 0)) if not acc.is_empty() else 0
		if day > 0:
			done += 1
		rows.append([k, day, int(acc.get("species_fed", {}).get(k, 0)) if not acc.is_empty() else 0, 1 if FWConst.GOD_HYBRIDS.has(k) else 0])
	var animals := 0
	var fed := 0
	for id in cs.buildings:
		var b: Dictionary = cs.buildings[id]
		if str(b["type"]) == "zoo" and str(b["owner"]) == player:
			var st: Dictionary = cs.zoo_stats_of(b)
			animals += int(st["animals"])
			fed += int(st["fed"])
	return {"rows": rows, "done": done, "total": FWConst.SPECIES_ORDER.size(), "zoo": [animals, fed]}
