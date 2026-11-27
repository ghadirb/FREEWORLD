extends RefCounted
## استخدام NPC و خانواده (پروتکل ۵۲). فقط روی سرور؛ همهٔ تصمیم‌ها اینجا گرفته می‌شود.
## NPC استخدام‌شده در ساعت کار به کارگاه صاحبش می‌رود و مثل کارگر تولید را سریع‌تر می‌کند و روزی HIRE_WAGE حقوق می‌گیرد.
## همسر و فرزند «خانواده»‌اند: بی‌هزینه کار می‌کنند. تگ عمومی هر NPC برای کلاینت: "" | "h:نام" کارگر | "s:نام" همسر | "k:نام" فرزند
## خردسال | "a:نام" فرزند بالغ.

const FWConst = preload("res://scripts/core/const.gd")


static func find_npc(cs, npc_id: int) -> Dictionary:
	for n in cs.npcs:
		if int(n["id"]) == npc_id:
			return n
	return {}


static func is_family_of(npc: Dictionary, player: String) -> bool:
	return str(npc.get("spouse_of", "")) == player or str(npc.get("parent", "")) == player


static func tag(npc: Dictionary) -> String:
	if bool(npc.get("kid", false)):
		return "k:" + str(npc.get("parent", ""))
	if str(npc.get("spouse_of", "")) != "":
		return "s:" + str(npc["spouse_of"])
	if str(npc.get("emp", "")) != "":
		return "h:" + str(npc["emp"])
	if str(npc.get("parent", "")) != "":
		return "a:" + str(npc["parent"])
	return ""


static func _level(cs, acc: Dictionary, npc_id: int) -> int:
	var pts: int = cs.friendship_of(acc, npc_id)
	var lv := 0
	for i in FWConst.FRIEND_LEVELS.size():
		if pts >= int(FWConst.FRIEND_LEVELS[i]):
			lv = i + 1
	return lv


static func _hired_count(cs, player: String, building_id: int = -1) -> int:
	var n := 0
	for npc in cs.npcs:
		if str(npc.get("emp", "")) == player and (building_id < 0 or int(npc.get("wb", -1)) == building_id):
			n += 1
	return n


static func _free_workplace(cs, player: String, from: Vector2) -> int:
	var best := -1
	var bd := INF
	var ids: Array = cs.buildings.keys()
	ids.sort()
	for id in ids:
		var b: Dictionary = cs.buildings[id]
		if str(b["owner"]) != player or not FWConst.JOB_TYPES.has(str(b["type"])):
			continue
		if _hired_count(cs, player, int(id)) >= FWConst.HIRE_PER_BUILDING:
			continue
		var d: float = cs.door_point(b).distance_to(from)
		if d < bd:
			bd = d
			best = int(id)
	return best


static func _check_near(cs, player: String, npc_id: int, pos: Vector2) -> Dictionary:
	if not cs.accounts.has(player):
		return {"ok": false, "error": "no_account"}
	var npc: Dictionary = find_npc(cs, npc_id)
	if npc.is_empty():
		return {"ok": false, "error": "no_npc"}
	if pos.distance_to(Vector2(float(npc["x"]), float(npc["z"]))) > FWConst.NPC_TALK_RANGE:
		return {"ok": false, "error": "too_far"}
	return {"ok": true, "npc": npc}


## استخدام در نزدیک‌ترین کارگاه خود بازیکن که جای خالی دارد.
static func hire(cs, player: String, npc_id: int, pos: Vector2) -> Dictionary:
	var chk: Dictionary = _check_near(cs, player, npc_id, pos)
	if not bool(chk["ok"]):
		return chk
	var npc: Dictionary = chk["npc"]
	var acc: Dictionary = cs.accounts[player]
	if bool(npc.get("kid", false)):
		return {"ok": false, "error": "npc_kid"}
	if str(npc.get("emp", "")) != "":
		return {"ok": false, "error": "npc_employed"}
	if str(npc.get("home_v", "")) != "" or str(npc.get("job", "")) != "":
		return {"ok": false, "error": "npc_has_job"}
	if _hired_count(cs, player) >= FWConst.HIRE_PER_PLAYER:
		return {"ok": false, "error": "hire_limit"}
	var family: bool = is_family_of(npc, player)
	if not family and _level(cs, acc, npc_id) < FWConst.HIRE_FRIEND_LEVEL:
		return {"ok": false, "error": "need_friend"}
	var wb: int = _free_workplace(cs, player, Vector2(float(npc["x"]), float(npc["z"])))
	if wb < 0:
		return {"ok": false, "error": "no_workplace"}
	var fee: int = 0 if family else FWConst.HIRE_FEE
	if fee > 0 and not cs._pay(acc, fee):
		return {"ok": false, "error": "no_money"}
	if fee > 0 and not cs.creative:
		npc["money"] = int(npc["money"]) + fee
	npc["emp"] = player
	npc["wb"] = wb
	cs._log(player, "npc_hire", {"npc": npc_id, "building": wb, "fee": fee})
	return {"ok": true, "npc": str(npc["name"]), "building": wb, "fee": fee, "money": int(acc["money"])}


static func fire(cs, player: String, npc_id: int) -> Dictionary:
	var npc: Dictionary = find_npc(cs, npc_id)
	if npc.is_empty():
		return {"ok": false, "error": "no_npc"}
	if str(npc.get("emp", "")) != player:
		return {"ok": false, "error": "not_yours"}
	npc["emp"] = ""
	npc["wb"] = -1
	cs._log(player, "npc_fire", {"npc": npc_id})
	return {"ok": true, "npc": str(npc["name"])}


static func _home_of(cs, player: String) -> int:
	var ids: Array = cs.buildings.keys()
	ids.sort()
	for id in ids:
		var b: Dictionary = cs.buildings[id]
		if str(b["type"]) == "house" and str(b["owner"]) == player:
			return int(id)
	return -1


## ازدواج: دوست صمیمی، خانهٔ شخصی، هزینهٔ عروسی. NPC به خانهٔ بازیکن می‌آید (ساکن روستا می‌شود شهروند).
static func marry(cs, player: String, npc_id: int, pos: Vector2) -> Dictionary:
	var chk: Dictionary = _check_near(cs, player, npc_id, pos)
	if not bool(chk["ok"]):
		return chk
	var npc: Dictionary = chk["npc"]
	var acc: Dictionary = cs.accounts[player]
	if int(acc.get("spouse", 0)) != 0:
		return {"ok": false, "error": "has_spouse"}
	if bool(npc.get("kid", false)) or str(npc.get("parent", "")) == player:
		return {"ok": false, "error": "npc_kid"}
	if str(npc.get("spouse_of", "")) != "" or str(npc.get("emp", "")) != "":
		return {"ok": false, "error": "npc_taken"}
	if _level(cs, acc, npc_id) < FWConst.MARRY_FRIEND_LEVEL:
		return {"ok": false, "error": "need_friend"}
	var home: int = _home_of(cs, player)
	if home < 0:
		return {"ok": false, "error": "need_house"}
	if not cs._pay(acc, FWConst.MARRY_COST):
		return {"ok": false, "error": "no_money"}
	if not cs.creative:
		npc["money"] = int(npc["money"]) + FWConst.MARRY_COST
	npc["spouse_of"] = player
	npc["home_b"] = home
	npc["home_v"] = ""
	npc["job"] = ""
	npc["last_birth"] = cs.day_count
	acc["spouse"] = npc_id
	cs._log(player, "npc_marry", {"npc": npc_id, "house": home})
	return {"ok": true, "npc": str(npc["name"]), "money": int(acc["money"])}


static func divorce(cs, player: String) -> Dictionary:
	var acc: Dictionary = cs.accounts.get(player, {})
	var sid: int = int(acc.get("spouse", 0))
	if sid == 0:
		return {"ok": false, "error": "no_spouse"}
	var npc: Dictionary = find_npc(cs, sid)
	acc["spouse"] = 0
	var nm := ""
	if not npc.is_empty():
		npc["spouse_of"] = ""
		nm = str(npc["name"])
	cs._log(player, "npc_divorce", {"npc": sid})
	return {"ok": true, "npc": nm}


## تولید کارگر استخدام‌شده در ساعت کار؛ مثل work_step ولی با HIRE_BONUS.
static func work(cs, npc: Dictionary, dt: float) -> void:
	var wb: int = int(npc.get("wb", -1))
	if not cs.buildings.has(wb):
		return
	var b: Dictionary = cs.buildings[wb]
	match str(b["type"]):
		"farm":
			b["stock"] = minf(FWConst.FARM_MAX_STOCK, float(b["stock"]) + dt / FWConst.FARM_SECONDS_PER_WHEAT * FWConst.HIRE_BONUS)
		"bakery", "mill", "dairy":
			b["prog"] = minf(float(b.get("prog", 0.0)) + dt * FWConst.HIRE_BONUS, float(FWConst.PROCESSORS[str(b["type"])]["seconds"]))
		"coop", "barn":
			var lv: Dictionary = FWConst.LIVESTOCK[str(b["type"])]
			b["stock"] = minf(float(lv["max"]), float(b["stock"]) + dt / float(lv["seconds"]) * FWConst.HIRE_BONUS)


## هر روز یک‌بار: حقوق، سهم همسر، تولد فرزند و بزرگ شدن. رویدادها در cs.family_events می‌روند.
static func daily(cs, day: int) -> void:
	if cs.family_day == day:
		return
	cs.family_day = day
	for npc in cs.npcs:
		var emp: String = str(npc.get("emp", ""))
		if emp != "":
			var wb: int = int(npc.get("wb", -1))
			if not cs.accounts.has(emp) or not cs.buildings.has(wb) or str(cs.buildings[wb]["owner"]) != emp:
				npc["emp"] = ""
				npc["wb"] = -1
				continue
			if not is_family_of(npc, emp) and not cs.creative:
				if cs._pay(cs.accounts[emp], FWConst.HIRE_WAGE):
					npc["money"] = int(npc["money"]) + FWConst.HIRE_WAGE
				else:
					npc["emp"] = ""
					npc["wb"] = -1
					cs.family_events.append({"kind": "hire_quit", "player": emp, "npc": str(npc["name"])})
		var sp: String = str(npc.get("spouse_of", ""))
		if sp != "":
			if not cs.accounts.has(sp) or int(cs.accounts[sp].get("spouse", 0)) != int(npc["id"]):
				npc["spouse_of"] = ""
				continue
			if not cs.creative:
				var share: int = mini(FWConst.FAMILY_SPOUSE_DAILY, int(npc["money"]))
				npc["money"] = int(npc["money"]) - share
				cs.accounts[sp]["money"] = int(cs.accounts[sp]["money"]) + share
			_maybe_birth(cs, npc, sp, day)
		if bool(npc.get("kid", false)) and day - int(npc.get("born_day", day)) >= FWConst.FAMILY_GROW_DAYS:
			npc["kid"] = false
			cs.family_events.append({"kind": "child_grown", "player": str(npc.get("parent", "")), "npc": str(npc["name"])})


static func _children_of(cs, player: String) -> int:
	var n := 0
	for npc in cs.npcs:
		if str(npc.get("parent", "")) == player:
			n += 1
	return n


static func _maybe_birth(cs, spouse: Dictionary, player: String, day: int) -> void:
	if day - int(spouse.get("last_birth", day)) < FWConst.FAMILY_CHILD_DAYS:
		return
	var home: int = int(spouse.get("home_b", -1))
	if not cs.buildings.has(home) or str(cs.buildings[home]["owner"]) != player:
		return
	if _children_of(cs, player) >= FWConst.FAMILY_CHILD_MAX or cs.npcs.size() >= FWConst.NPC_MAX:
		return
	var next_id := 1
	for n in cs.npcs:
		next_id = maxi(next_id, int(n["id"]) + 1)
	var door: Vector2 = cs.door_point(cs.buildings[home])
	cs.npcs.append({"id": next_id, "name": FWConst.NPC_NAMES[(next_id * 7 + day) % FWConst.NPC_NAMES.size()],
		"x": door.x, "z": door.y, "state": "idle", "money": 0, "paid_day": -1, "income_day": day,
		"bread_day": -1, "goods_day": -1, "stock_day": -1, "sold": {}, "placed": false, "job": "",
		"home_b": home, "home_v": "", "vx": 0.0, "vz": 0.0, "wk_day": -1,
		"kid": true, "parent": player, "born_day": day, "emp": "", "wb": -1, "spouse_of": "", "last_birth": day})
	spouse["last_birth"] = day
	cs.family_events.append({"kind": "birth", "player": player, "npc": str(cs.npcs[cs.npcs.size() - 1]["name"])})
