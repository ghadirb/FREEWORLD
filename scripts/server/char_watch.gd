extends RefCounted
## مشاهدهٔ شخصیت‌های مستقل (پروتکل ۵۶): فهرست همهٔ شخصیت‌ها با کار فعلی و جزئیات هر کدام (هدف، برنامه، رابطه‌ها، سابقه).
## فقط می‌خواند؛ هیچ‌چیز را عوض نمی‌کند. دسترسی را game_server بررسی می‌کند (مدیر یا جهان خلاقانه).

const CharAI = preload("res://scripts/server/char_ai.gd")
const Memory = preload("res://scripts/server/char_memory.gd")
const War = preload("res://scripts/server/char_war.gd")

const ROSTER_MAX := 24
const LOG_SHOWN := 12
const REL_SHOWN := 8


static func find(cs, npc_id: int) -> Dictionary:
	for n in cs.npcs:
		if int(n["id"]) == npc_id and CharAI.is_ai(n):
			return n
	return {}


## کار فعلی: کد فعالیت (برای ترجمه در کلاینت) و نوع ساختمان در صورت ساخت.
static func activity(cs, npc: Dictionary) -> Dictionary:
	var ai: Dictionary = npc["ai"]
	if not bool(cs.ai_settings["on"]):
		return {"code": "off", "type": ""}
	if War.retreating(npc):
		return {"code": "retreat", "type": ""}
	var plan: Array = ai["plan"]
	if plan.is_empty():
		return {"code": "think", "type": ""}
	var st: Dictionary = plan[0]
	return {"code": str(st.get("t", "think")), "type": str(st.get("type", ""))}


static func _money(cs, acct: String) -> int:
	return int(cs.accounts[acct]["money"]) if cs.accounts.has(acct) else 0


static func _row(cs, npc: Dictionary) -> Dictionary:
	var ai: Dictionary = npc["ai"]
	var act: Dictionary = activity(cs, npc)
	return {"id": int(npc["id"]), "name": str(npc["name"]), "arch": str(ai["arch"]), "custom": bool(ai.get("custom", false)),
		"x": snappedf(float(npc["x"]), 0.1), "z": snappedf(float(npc["z"]), 0.1), "act": str(act["code"]), "type": str(act["type"]),
		"money": _money(cs, str(npc["acct"])), "built": int(ai["stats"]["built"]), "war": War.in_war(npc), "hp": snappedf(War.hp_frac(npc), 0.01)}


static func roster(cs) -> Array:
	var out: Array = []
	for n in cs.npcs:
		if CharAI.is_ai(n):
			out.append(_row(cs, n))
			if out.size() >= ROSTER_MAX:
				break
	return out


static func _name_of_acct(cs, acct: String) -> String:
	for n in cs.npcs:
		if str(n.get("acct", "")) == acct:
			return str(n["name"])
	return acct


static func detail(cs, npc: Dictionary, viewer: String) -> Dictionary:
	var ai: Dictionary = npc["ai"]
	var d: Dictionary = _row(cs, npc)
	d["life"] = str(ai["life"])
	d["traits"] = (ai["traits"] as Dictionary).duplicate()
	d["stats"] = (ai["stats"] as Dictionary).duplicate()
	var goals: Array = []
	for g in (ai["goals"] as Array).slice(0, 4):
		goals.append({"kind": str(g.get("kind", "")), "type": str(g.get("type", "")), "prio": float(g.get("prio", 0.0)), "h": str(g.get("h", ""))})
	d["goals"] = goals
	var plan: Array = []
	for st in (ai["plan"] as Array).slice(0, 5):
		plan.append({"t": str(st.get("t", "")), "type": str(st.get("type", ""))})
	d["plan"] = plan
	d["log"] = (ai["log"] as Array).slice(-LOG_SHOWN)
	var rels: Array = []
	var seen := 0
	for who in (ai["mem"]["rel"] as Dictionary):
		if seen >= REL_SHOWN:
			break
		seen += 1
		rels.append({"who": _name_of_acct(cs, str(who)), "stance": Memory.stance(ai, str(who), cs.day_count), "me": str(who) == viewer})
	d["rels"] = rels
	var foes: Array = []
	for f in (ai["war"]["foes"] as Dictionary):
		foes.append(_name_of_acct(cs, str(f)))
	d["foes"] = foes
	var allies: Array = []
	for a in (ai["allies"] as Dictionary):
		allies.append(_name_of_acct(cs, str(a)))
	d["allies"] = allies
	return d
