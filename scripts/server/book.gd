extends RefCounted
## کتاب ماجراجویی (سمت سرور): دستاوردهای اختیاری که فقط از روی وضعیت معتبر خود سرور
## (حساب، ساختمان‌ها، بلوک‌ها، موقعیتی که سرعت‌سنج تأیید کرده) سنجیده می‌شوند. کلاینت هیچ چیزی را «ثبت» نمی‌کند.
## هر دستاورد فقط یک‌بار باز می‌شود و جایزهٔ کوچکش را می‌دهد (در جهان خلاقانه جایزه صفر است).

const FWConst = preload("res://scripts/core/const.gd")
const Story = preload("res://scripts/shared/story.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")
const Boat = preload("res://scripts/shared/boat.gd")


## دستاوردهای تازه‌بازشده برای بازیکن: [{id, reward}]. ctx: {pos: Vector3, mine: String}.
static func evaluate(cs, player: String, ctx: Dictionary) -> Array:
	var unlocked: Array = []
	if not cs.accounts.has(player):
		return unlocked
	var acc: Dictionary = cs.accounts[player]
	if not (acc.get("book") is Dictionary):
		acc["book"] = {}
	var type_counts: Dictionary = {}
	var type_counts_ready := false
	for e in Story.entries_for(cs.world.climate, cs.creative, cs.scenario):
		var id := str(e["id"])
		if acc["book"].has(id):
			continue
		if str(e["kind"]) == "blocks_of" and not type_counts_ready:
			type_counts = _block_type_counts(cs, player)
			type_counts_ready = true
		if not _met(cs, acc, player, e, ctx, type_counts):
			continue
		var reward := 0 if cs.creative else int(e["reward"])
		acc["book"][id] = cs.day_count
		if reward > 0:
			acc["money"] = int(acc["money"]) + reward
		cs._log(player, "book_unlock", {"id": id, "reward": reward})
		unlocked.append({"id": id, "reward": reward})
	return unlocked


static func _block_type_counts(cs, player: String) -> Dictionary:
	var out: Dictionary = {}
	for v in cs.blocks:
		var b: Array = cs.blocks[v]
		if str(b[2]) == player:
			out[str(b[0])] = int(out.get(str(b[0]), 0)) + 1
	return out


static func _met(cs, acc: Dictionary, player: String, e: Dictionary, ctx: Dictionary, type_counts: Dictionary) -> bool:
	var pos: Vector3 = ctx.get("pos", Vector3.ZERO)
	match str(e["kind"]):
		"dist":
			var half := FWConst.CITY_SIZE * 0.5
			return Vector2(pos.x, pos.z).distance_to(Vector2(half, half)) >= float(e["a"])
		"in_village":
			return cs.world.near_village(pos.x, pos.z, FWConst.VILLAGE_RADIUS)
		"in_mine":
			return str(ctx.get("mine", "")) != ""
		"biome":
			if pos.y < float(e["b"]):
				return false
			return (e["a"] as Array).has(cs.world.biome_at(pos.x, pos.z))
		"height":
			return pos.y >= float(e["a"])
		"owns":
			var n := 0
			for id in cs.buildings:
				if cs.buildings[id]["owner"] == player and str(cs.buildings[id]["type"]) == str(e["a"]):
					n += 1
			return n >= int(e["b"])
		"blocks":
			return int(cs.block_owner_count.get(player, 0)) >= int(e["a"])
		"blocks_of":
			return int(type_counts.get(str(e["a"]), 0)) >= int(e["b"])
		"tool_any":
			return acc.get("tools") is Dictionary and not (acc["tools"] as Dictionary).is_empty()
		"friends":
			var cnt := 0
			var f: Variant = acc.get("friends", {})
			if f is Dictionary:
				for k in f:
					if cs.friend_level(int(f[k])) >= int(e["a"]):
						cnt += 1
			return cnt >= int(e["b"])
		"stat":
			var st: Variant = acc.get("stats", {})
			return st is Dictionary and int(st.get(str(e["a"]), 0)) >= int(e["b"])
		"flag":
			return bool(acc.get(str(e["a"]), false))
		"chains":
			var full := 0
			var q: Variant = acc.get("quests", {})
			if q is Dictionary:
				for role in q:
					if int(q[role]) >= Story.quest_total(str(role)):
						full += 1
			return full >= int(e["a"])
		"money":
			return int(acc["money"]) >= int(e["a"])
		"legend":
			# مرحله‌ها به ترتیب‌اند: مرحلهٔ قبل باید باز شده باشد.
			if int(e["a"]) > 0 and not (acc["book"] as Dictionary).has("lg_%s_%d" % [str(e["scenario"]), int(e["a"])]):
				return false
			var spot: Vector2 = legend_spot(cs, e)
			return Vector2(pos.x, pos.z).distance_to(spot) <= float(e["r"])
	return false


## جای واقعی یک مرحلهٔ افسانه: نزدیک نقطهٔ نامی (فاصله از مرکز)، اولین خشکیِ قابل‌ایستادن در حلقه‌های بزرگ‌شونده.
## قطعی است (فقط از Seed و دادهٔ ثابت)، پس سرور و نشانگر ساخته‌شده همیشه یک جا را نشان می‌دهند.
static func legend_spot(cs, e: Dictionary) -> Vector2:
	var cx: float = float(Scenarios.CENTER) + float(e["dx"])
	var cz: float = float(Scenarios.CENTER) + float(e["dz"])
	for ring in range(0, 13):
		var rad := float(ring) * 4.0
		var n := 1 if ring == 0 else 16
		for k in range(n):
			var a := TAU * float(k) / float(n)
			var x := cx + cos(a) * rad
			var z := cz + sin(a) * rad
			if cs.world.height_at(x, z) < 0.5 or Boat.is_water(cs, x, z):
				continue
			if cs.world.near_mine_entrance(x, z, FWConst.MINE_NO_BUILD_RADIUS) or cs.world.village_solid_at(x, z, 3.0):
				continue
			return Vector2(floorf(x) + 0.5, floorf(z) + 0.5)
	return Vector2(cx, cz)


## مرحلهٔ بعدی افسانه برای بازیکن (خالی اگر جهان افسانه ندارد یا همه تمام شده): {id, x, z}.
static func next_legend(cs, player: String) -> Dictionary:
	if not cs.accounts.has(player):
		return {}
	var book: Variant = cs.accounts[player].get("book", {})
	for e in Story.legend_entries(cs.scenario):
		if not (book is Dictionary and (book as Dictionary).has(str(e["id"]))):
			var sp: Vector2 = legend_spot(cs, e)
			return {"id": str(e["id"]), "x": sp.x, "z": sp.y}
	return {}


## وضعیت کتاب برای کلاینت: ورودی‌های این جهان به ترتیب، با روز بازشدن (۰ = هنوز باز نشده) و نقش NPCها.
static func public_state(cs, player: String) -> Dictionary:
	var rows: Array = []
	var done := 0
	var book: Dictionary = {}
	if cs.accounts.has(player) and cs.accounts[player].get("book") is Dictionary:
		book = cs.accounts[player]["book"]
	for e in Story.entries_for(cs.world.climate, cs.creative, cs.scenario):
		var id := str(e["id"])
		var d := int(book.get(id, -1)) + 1 if book.has(id) else 0
		if d > 0:
			done += 1
		rows.append([id, d, 0 if cs.creative else int(e["reward"]), str(e["giver"])])
	var roles: Dictionary = {}
	for n in cs.npcs:
		roles[str(int(n["id"]))] = Story.role_of(cs.scenario, int(n["id"]))
	var quests: Dictionary = {}
	if cs.accounts.has(player) and cs.accounts[player].get("quests") is Dictionary:
		quests = cs.accounts[player]["quests"].duplicate()
	return {"rows": rows, "done": done, "total": rows.size(), "roles": roles, "quests": quests, "legend": next_legend(cs, player)}


## خط‌های گفت‌وگو برای نقش: {line, hint, entry}. hint خالی یعنی «همه‌چیز انجام شده» (از done_key استفاده می‌شود).
static func dialogue(cs, player: String, role: String, level: int) -> Dictionary:
	var out := {"line": Story.line_key(role, level), "hint": "", "entry": ""}
	var book: Dictionary = {}
	if cs.accounts.has(player) and cs.accounts[player].get("book") is Dictionary:
		book = cs.accounts[player]["book"]
	var qdone := 0
	if cs.accounts.has(player) and cs.accounts[player].get("quests") is Dictionary:
		qdone = int(cs.accounts[player]["quests"].get(role, 0))
	if not Story.quest_step(role, qdone).is_empty():
		out["hint"] = "dlg_quest_hint"
		out["entry"] = ""
		return out
	var mine: Array = []
	for e in Story.entries_for(cs.world.climate, cs.creative, cs.scenario):
		if str(e["giver"]) == role:
			mine.append(e)
	if mine.is_empty():
		return out
	for e in mine:
		if not book.has(str(e["id"])):
			out["hint"] = Story.hint_key(role)
			out["entry"] = str(e["id"])
			return out
	out["hint"] = Story.done_key(role)
	return out
