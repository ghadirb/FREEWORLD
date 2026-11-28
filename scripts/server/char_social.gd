extends RefCounted
## تعامل مستقل شخصیت‌ها با یکدیگر (پروتکل ۵۴، مرحلهٔ ۵). فقط روی سرور و بدون دخالت بازیکن.
## وقتی دو شخصیت نزدیک هم باشند: گفتگو یا مشاجره (بسته به همکاری/پرخاشگری و رابطهٔ قبلی)،
## تجارت واقعی از کیف یکدیگر، اتحاد بین دوستان، و خیانت به متحد توسط تیپ‌های فرصت‌طلب.
## همه‌چیز از همان حافظهٔ مرحلهٔ ۳ (`char_memory.gd`) می‌گذرد؛ پول و کالا فقط بین دو کیف جابه‌جا می‌شود.

const Memory = preload("res://scripts/server/char_memory.gd")
const War = preload("res://scripts/server/char_war.gd")

const MEET_RANGE := 10.0
const TICK_SECONDS := 5.0
const MEET_COOLDOWN := 90.0        # ثانیهٔ زمان جهان بین دو برخورد یک جفت
const TRADE_RANGE := 12.0
const BUYER_RESERVE := 40          # خریدار همیشه این مقدار پول نگه می‌دارد
const ALLY_MAX := 2
const ALLY_ATTITUDE := 0.2
const BETRAY_SCORE := 0.55


static func _ai(npc: Dictionary) -> Dictionary:
	return npc["ai"]


static func _pos(npc: Dictionary) -> Vector2:
	return Vector2(float(npc["x"]), float(npc["z"]))


static func is_allied(a: Dictionary, b: Dictionary) -> bool:
	return (_ai(a)["allies"] as Dictionary).has(str(b["acct"]))


static func _stance(cs, a: Dictionary, b: Dictionary) -> String:
	return Memory.stance(_ai(a), str(b["acct"]), cs.day_count)


## سازگاری دو شخصیت: همکاری بالا ← گفتگو؛ پرخاشگری بالا یا رابطهٔ بد ← مشاجره.
static func compat(cs, a: Dictionary, b: Dictionary) -> float:
	var ta: Dictionary = _ai(a)["traits"]
	var tb: Dictionary = _ai(b)["traits"]
	var coop: float = (float(ta["cooperation"]) + float(tb["cooperation"])) * 0.5
	var aggr: float = (float(ta["aggression"]) + float(tb["aggression"])) * 0.5
	var past: float = Memory.attitude(_ai(a), str(b["acct"]), cs.day_count) + Memory.attitude(_ai(b), str(a["acct"]), cs.day_count)
	return coop - aggr * 0.8 + 0.25 * past


## احتمال خیانت به متحد: خودخواه و جاه‌طلب و بی‌اعتماد ← بالا. قطعی است (نه تصادفی).
static func betray_score(a: Dictionary) -> float:
	var t: Dictionary = _ai(a)["traits"]
	return float(t["selfishness"]) * float(t["ambition"]) * (1.0 - 0.5 * float(t["trust"]))


## یک گام دوره‌ای: همهٔ جفت‌های نزدیک را بررسی می‌کند. dt ثانیه از گام قبلی.
static func tick(cs, dt: float) -> void:
	cs.social_t = float(cs.social_t) + dt
	if float(cs.social_t) < TICK_SECONDS:
		return
	cs.social_t = 0.0
	var ais: Array = []
	for n in cs.npcs:
		if n.get("ai", null) is Dictionary and cs.accounts.has(str(n.get("acct", ""))):
			ais.append(n)
	if ais.size() < 2 or not bool(cs.ai_settings.get("social", true)):
		return
	for i in ais.size():
		for j in range(i + 1, ais.size()):
			if _pos(ais[i]).distance_to(_pos(ais[j])) <= MEET_RANGE:
				meet(cs, ais[i], ais[j])


## برخورد دو شخصیت. false اگر هنوز در دورهٔ انتظار است.
static func meet(cs, a: Dictionary, b: Dictionary) -> bool:
	var ka := str(b["acct"])
	var kb := str(a["acct"])
	if War.at_war(a, b):
		return false     # در جنگ‌اند؛ برخورد دوستانه نیست (درگیری و مذاکره با چرخهٔ جنگ است)
	var last: float = float(_ai(a)["meet"].get(ka, -1.0e9))
	if float(cs.world_time) - last < MEET_COOLDOWN:
		return false
	_ai(a)["meet"][ka] = float(cs.world_time)
	_ai(b)["meet"][kb] = float(cs.world_time)
	_ai(a)["stats"]["met"] = int(_ai(a)["stats"]["met"]) + 1
	_ai(b)["stats"]["met"] = int(_ai(b)["stats"]["met"]) + 1
	# ۱) متحد فرصت‌طلب ممکن است خیانت کند (هر دو طرف بررسی می‌شوند؛ اول خودخواه‌تر)
	if is_allied(a, b):
		var first: Dictionary = a if betray_score(a) >= betray_score(b) else b
		var second: Dictionary = b if first == a else a
		for pair in [[first, second], [second, first]]:
			var traitor: Dictionary = pair[0]
			var victim: Dictionary = pair[1]
			var since: int = int(_ai(traitor)["allies"][str(victim["acct"])])
			if betray_score(traitor) >= BETRAY_SCORE and cs.day_count - since >= 1:
				_betray(cs, traitor, victim)
				return true
		Memory.record(_ai(a), "help", ka, 0.3, cs.day_count)
		Memory.record(_ai(b), "help", kb, 0.3, cs.day_count)
		return true
	# ۲) گفتگو یا مشاجره
	if compat(cs, a, b) < -0.1:
		Memory.record(_ai(a), "quarrel", ka, 0.5, cs.day_count)
		Memory.record(_ai(b), "quarrel", kb, 0.5, cs.day_count)
		_note(cs, a, "quarrel:" + str(b["name"]))
		_note(cs, b, "quarrel:" + str(a["name"]))
		War.try_declare(cs, a, b)     # مشاجرهٔ شدید بین دشمنان پرخاشگر می‌تواند به جنگ برسد
		return true
	Memory.record(_ai(a), "chat", ka, 0.5, cs.day_count)
	Memory.record(_ai(b), "chat", kb, 0.5, cs.day_count)
	# ۳) دوستی دوطرفه ← اتحاد
	if (_ai(a)["allies"] as Dictionary).size() < ALLY_MAX and (_ai(b)["allies"] as Dictionary).size() < ALLY_MAX \
			and Memory.attitude(_ai(a), ka, cs.day_count) >= ALLY_ATTITUDE and Memory.attitude(_ai(b), kb, cs.day_count) >= ALLY_ATTITUDE:
		_ai(a)["allies"][ka] = cs.day_count
		_ai(b)["allies"][kb] = cs.day_count
		Memory.record(_ai(a), "alliance", ka, 0.8, cs.day_count)
		Memory.record(_ai(b), "alliance", kb, 0.8, cs.day_count)
		_ai(a)["stats"]["allied"] = int(_ai(a)["stats"]["allied"]) + 1
		_ai(b)["stats"]["allied"] = int(_ai(b)["stats"]["allied"]) + 1
		_note(cs, a, "ally:" + str(b["name"]))
		_note(cs, b, "ally:" + str(a["name"]))
		cs.ai_events.append({"kind": "alliance", "a": str(a["name"]), "b": str(b["name"])})
	return true


static func _betray(cs, traitor: Dictionary, victim: Dictionary) -> void:
	var kt := str(traitor["acct"])
	var kv := str(victim["acct"])
	(_ai(traitor)["allies"] as Dictionary).erase(kv)
	(_ai(victim)["allies"] as Dictionary).erase(kt)
	Memory.record(_ai(victim), "betray", kt, 1.0, cs.day_count)
	_ai(traitor)["stats"]["betrayed"] = int(_ai(traitor)["stats"]["betrayed"]) + 1
	_note(cs, traitor, "betray:" + str(victim["name"]))
	_note(cs, victim, "betrayed_by:" + str(traitor["name"]))
	cs.ai_events.append({"kind": "betrayal", "a": str(traitor["name"]), "b": str(victim["name"])})


static func _note(cs, npc: Dictionary, what: String) -> void:
	var log: Array = _ai(npc)["log"]
	log.append("d%d %s" % [cs.day_count, what])
	while log.size() > 12:
		log.pop_front()


# ---------------- تجارت بین شخصیت‌ها ----------------

## نزدیک‌ترین خریداری که حاضر و قادر به خرید است (دشمن نمی‌خرد؛ فقط معامله‌گر یا همکارجو می‌خرد).
static func find_buyer(cs, seller: Dictionary, item: String, n: int) -> Dictionary:
	var best := {}
	var bd := INF
	var base: int = cs.sell_price(item)
	for other in cs.npcs:
		if other == seller or not (other.get("ai", null) is Dictionary) or not cs.accounts.has(str(other.get("acct", ""))):
			continue
		var d: float = _pos(seller).distance_to(_pos(other))
		if d > TRADE_RANGE or d >= bd:
			continue
		if _stance(cs, seller, other) == "enemy" or _stance(cs, other, seller) == "enemy" or War.at_war(seller, other):
			continue
		var t: Dictionary = _ai(other)["traits"]
		if str(_ai(other)["arch"]) != "trader" and float(t["cooperation"]) < 0.45:
			continue
		var unit := _unit(cs, seller, other, base)
		if int(cs.accounts[str(other["acct"])]["money"]) - BUYER_RESERVE < unit:
			continue
		best = other
		bd = d
	return best


static func _unit(cs, seller: Dictionary, buyer: Dictionary, base: int) -> int:
	var f := Memory.price_factor(_ai(seller), str(buyer["acct"]), cs.day_count)
	return maxi(1, int(floor(float(base) * 0.9 * f)))


## فروش مستقیم n واحد از کیف فروشنده به خریدار؛ بازگشت: {count, total} (count صفر یعنی معامله نشد).
static func sell_to(cs, seller: Dictionary, buyer: Dictionary, item: String, n: int) -> Dictionary:
	var sa: Dictionary = cs.accounts[str(seller["acct"])]
	var ba: Dictionary = cs.accounts[str(buyer["acct"])]
	var unit := _unit(cs, seller, buyer, cs.sell_price(item))
	var count: int = mini(n, int(sa["inv"].get(item, 0)))
	count = mini(count, (int(ba["money"]) - BUYER_RESERVE) / unit)
	count = mini(count, 50)
	if count < 1:
		return {"count": 0, "total": 0}
	var total: int = unit * count
	sa["inv"][item] = int(sa["inv"][item]) - count
	cs._inv_add(ba, item, count)
	ba["money"] = int(ba["money"]) - total
	cs._gain(sa, total)
	var bought: Dictionary = _ai(buyer)["bought"]
	bought[item] = int(bought.get(item, 0)) + count     # این‌ها را دوباره به همتا نمی‌فروشد (جلوگیری از رفت‌وبرگشت)
	Memory.record(_ai(seller), "trade", str(buyer["acct"]), minf(1.0, float(total) / 100.0), cs.day_count)
	Memory.record(_ai(buyer), "trade", str(seller["acct"]), minf(1.0, float(total) / 100.0), cs.day_count)
	_ai(seller)["stats"]["traded"] = int(_ai(seller)["stats"]["traded"]) + 1
	_ai(buyer)["stats"]["traded"] = int(_ai(buyer)["stats"]["traded"]) + 1
	_note(cs, seller, "sold_to:%s" % str(buyer["name"]))
	return {"count": count, "total": total}
