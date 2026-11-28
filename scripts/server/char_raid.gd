extends RefCounted
## حملهٔ شخصیت‌های مستقل به بازیکنی که او را دشمن می‌دانند (جنگ علیه بازیکن).
## فقط وقتی: جهان خلاقانه نیست، بازیکن بیرون از منطقهٔ امن و در معرض دشمنان وحشی است (همان فهرست wild_step)،
## شخصیت پرخاشگر و شجاع است و نگرشش به بازیکن «دشمن» است. ضربه از همان مسیر آسیب دشمنان وحشی می‌گذرد
## (زره، مرگ، جریمهٔ مرگ و بازگشت یکسان). بازیکن با دور شدن یا رفتن به منطقهٔ امن از حمله می‌گریزد.

const FWConst = preload("res://scripts/core/const.gd")
const Memory = preload("res://scripts/server/char_memory.gd")
const War = preload("res://scripts/server/char_war.gd")

const CHASE_RANGE := 70.0     # فقط بازیکن نزدیک تعقیب می‌شود
const HIT_RANGE := 3.5
const CHASE_SPEED := 3.2
const HIT_COOLDOWN := 3.0
const HIT_DAMAGE := 6.0
const MAX_RAIDERS := 2        # هم‌زمان حداکثر این تعداد به یک بازیکن حمله می‌کنند


static func _ai(npc: Dictionary) -> Dictionary:
	return npc["ai"]


## آیا این شخصیت می‌تواند به این بازیکن حمله کند؟ (بدون در نظر گرفتن فاصله)
static func is_hostile(cs, npc: Dictionary, who: String) -> bool:
	if not (npc.get("ai", null) is Dictionary) or cs.creative or not bool(cs.ai_settings["on"]):
		return false
	if War.retreating(npc) or War.hp_frac(npc) < 0.6:
		return false
	var t: Dictionary = _ai(npc)["traits"]
	if float(t["aggression"]) < War.WAR_MIN_AGGRESSION or float(t["bravery"]) < War.WAR_MIN_BRAVERY:
		return false
	return Memory.stance(_ai(npc), who, cs.day_count) == "enemy"


## players: [{name, pos: Vector2, armor: float}]. خروجی: [{name, amount}] برای ادغام با آسیب دشمنان وحشی.
static func step(cs, dt: float, players: Array) -> Array:
	var hurt: Array = []
	if cs.creative or players.is_empty() or not bool(cs.ai_settings["on"]):
		return hurt
	var sp: Vector3 = cs.spawn_position()
	var center := Vector2(sp.x, sp.z)
	var raiders := {}
	for npc in cs.npcs:
		if not (npc.get("ai", null) is Dictionary):
			continue
		npc["rcd"] = maxf(0.0, float(npc.get("rcd", 0.0)) - dt)
		var me := Vector2(float(npc["x"]), float(npc["z"]))
		for pl in players:
			var who: String = str(pl["name"])
			var pp: Vector2 = pl["pos"]
			if pp.distance_to(center) <= FWConst.WILD_SAFE_RADIUS:
				continue
			var d: float = me.distance_to(pp)
			if d > CHASE_RANGE or int(raiders.get(who, 0)) >= MAX_RAIDERS or not is_hostile(cs, npc, who):
				continue
			raiders[who] = int(raiders.get(who, 0)) + 1
			if int(npc.get("raid_day", -1)) != cs.day_count:
				npc["raid_day"] = cs.day_count
				Memory.record(_ai(npc), "war", who, 0.3, cs.day_count)
				cs.ai_events.append({"kind": "raid", "a": str(npc["name"]), "b": who})
			if d > HIT_RANGE:
				var step_to: Vector2 = me + (pp - me).normalized() * minf(CHASE_SPEED * dt, d - HIT_RANGE)
				if cs.is_walkable(step_to.x, step_to.y):
					npc["x"] = step_to.x
					npc["z"] = step_to.y
			elif float(npc["rcd"]) <= 0.0:
				npc["rcd"] = HIT_COOLDOWN
				hurt.append({"name": who, "amount": HIT_DAMAGE * (1.0 - float(pl["armor"]))})
			break   # هر شخصیت در هر گام حداکثر یک بازیکن را هدف می‌گیرد
	return hurt
