extends RefCounted
## اعمال یک جهان آماده روی شهر تازه. فقط یک بار برای هر جهان اجرا می‌شود (پرچم scenario_applied در ذخیره می‌ماند).
## سازه‌ها با نقش مدیر و مالک «world» ساخته می‌شوند؛ هر ستونی که قانون ساخت را نقض کند (آب، روستا، معدن…) بی‌صدا رد می‌شود.

const FWConst = preload("res://scripts/core/const.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")
const NpcSim = preload("res://scripts/server/npc_sim.gd")
const Story = preload("res://scripts/shared/story.gd")
const Book = preload("res://scripts/server/book.gd")

const OWNER := "world"


## خروجی: تعداد بلوک‌های ساخته‌شده؛ -1 اگر سناریو ناشناخته یا قبلاً اعمال شده باشد.
static func apply(cs, id: String) -> int:
	if cs.scenario_applied or not Scenarios.has(id):
		return -1
	var d: Dictionary = Scenarios.def(id)
	cs.scenario = id
	cs.scenario_applied = true
	cs.set_climate(Scenarios.climate(id))
	cs.creative = cs.creative or bool(d["creative"])
	cs.world_time = float(d["hour"]) * 3600.0
	cs.weather = str(d["weather"])
	cs.time_speed = float(d["time_speed"])
	cs.forest_growth = bool(d["forest_growth"])
	NpcSim.ensure_npcs(cs, clampi(int(d["npcs"]), FWConst.NPC_COUNT, FWConst.NPC_NAMES.size()))
	_name_cast(cs, id)
	var placed := _place_columns(cs, Scenarios.columns(id))
	placed += _place_legend_markers(cs, id)
	_scatter_god(cs, id, d)
	return placed


## شخصیت‌های نام‌دار جهان (اگر فهرست مخصوص دارد) نام خود را می‌گیرند؛ دوستی‌ها به شناسه بسته است و دست نمی‌خورد.
static func _name_cast(cs, id: String) -> void:
	if not Story.CASTS.has(id):
		return
	var cast: Array = Story.cast_for(id)
	for i in range(mini(cast.size(), cs.npcs.size())):
		cs.npcs[i]["name"] = str(cast[i][0])


static func _ground_level(cs, x: int, z: int) -> int:
	var h: float = cs.world.height_at(float(x) + 0.5, float(z) + 0.5)
	return 0 if h < 0.2 else maxi(0, int(floor(h)))


## ستون‌ها را می‌گذارد. ستونی که گروه تراز دارد (c[6..9] = مرکز و نیم‌ابعاد) از بلندترین زمین همان مستطیل شروع می‌شود
## و زیر آن تا زمین با «dirt» پر می‌شود تا کف و پله‌ها هم‌تراز باشند.
static func _place_columns(cs, cols: Array) -> int:
	var placed := 0
	var group_base: Dictionary = {}
	for c in cols:
		var x := int(c[0])
		var z := int(c[1])
		var base := _ground_level(cs, x, z)
		if c.size() > 9:
			var key := Vector2i(int(c[6]), int(c[7]))
			if not group_base.has(key):
				var top := 0
				for gx in range(key.x - int(c[8]), key.x + int(c[8]) + 1):
					for gz in range(key.y - int(c[9]), key.y + int(c[9]) + 1):
						top = maxi(top, _ground_level(cs, gx, gz))
				group_base[key] = top
				for gx in range(key.x - int(c[8]), key.x + int(c[8]) + 1):
					for gz in range(key.y - int(c[9]), key.y + int(c[9]) + 1):
						var lv := _ground_level(cs, gx, gz)
						for fy in range(lv, top):
							if cs.blocks.size() < FWConst.MAX_BLOCKS_TOTAL and cs.check_block(FWConst.ROLE_WORLD_ADMIN, gx, fy, gz, "dirt") == "":
								cs._add_block(Vector3i(gx, fy, gz), "dirt", 0, OWNER)
								placed += 1
			base = int(group_base[key])
		for i in range(int(c[3])):
			if cs.blocks.size() >= FWConst.MAX_BLOCKS_TOTAL:
				return placed
			var y := base + int(c[2]) + i
			var type := str(c[4])
			if cs.check_block(FWConst.ROLE_WORLD_ADMIN, x, y, z, type) != "":
				continue
			cs._add_block(Vector3i(x, y, z), type, int(c[5]) if c.size() > 5 else 0, OWNER)
			placed += 1
	return placed


## نشانگر هر مرحلهٔ افسانه: ستون سنگی با چراغ بالایش و حلقهٔ آجری پایش (مرحلهٔ آخر یک تالار سنگیِ سقف‌دار است).
static func _place_legend_markers(cs, id: String) -> int:
	var cols: Array = []
	var placed := 0
	var entries: Array = Story.legend_entries(id)
	for e in entries:
		var sp: Vector2 = Book.legend_spot(cs, e)
		var x := int(floor(sp.x))
		var z := int(floor(sp.y))
		if int(e["a"]) == entries.size() - 1:
			placed += _place_hall(cs, x, z)
			continue
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if dx != 0 or dz != 0:
					cols.append([x + dx, z + dz, 0, 1, "brick"])
		cols.append([x, z, 0, 4, "stone"])
		cols.append([x, z, 4, 1, "lamp"])
	return placed + _place_columns(cs, cols)


## تالار پایان افسانه: دیوار سنگی ۴ بلوکی دور یک اتاق ۷×۷، دروازهٔ سه‌بلوکی سمت شرق، سقف، چهار چراغ گوشه و یک سکو با چراغ.
## ارتفاع از بلندترین نقطهٔ زمین زیر تالار گرفته می‌شود تا سقف صاف و بی‌حفره باشد؛ ستون‌های پایین‌تر تا زمین پر می‌شوند.
static func _place_hall(cs, cx: int, cz: int) -> int:
	var base := 0
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			base = maxi(base, _ground_level(cs, cx + dx, cz + dz))
	var placed := 0
	# دیوارها (از زمین هر ستون تا زیر سقف)
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			if maxi(absi(dx), absi(dz)) != 4:
				continue
			if dx == 4 and absi(dz) <= 1:
				continue   # دروازه
			var x := cx + dx
			var z := cz + dz
			for y in range(_ground_level(cs, x, z), base + 4):
				placed += _put(cs, x, y, z, "stone")
	# سقف: از بیرون به داخل تا هر بلوک به همسایه‌اش تکیه کند
	for ring in range(4, -1, -1):
		for dx in range(-ring, ring + 1):
			for dz in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) == ring:
					placed += _put(cs, cx + dx, base + 4, cz + dz, "roof")
	# چراغ‌های گوشه (روی زمین داخل) و سکوی میانی
	for c in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3)]:
		placed += _put(cs, cx + c.x, _ground_level(cs, cx + c.x, cz + c.y), cz + c.y, "lamp")
	var gy := _ground_level(cs, cx, cz)
	placed += _put(cs, cx, gy, cz, "stone")
	placed += _put(cs, cx, gy + 1, cz, "lamp")
	return placed


static func _put(cs, x: int, y: int, z: int, type: String) -> int:
	if cs.blocks.size() >= FWConst.MAX_BLOCKS_TOTAL:
		return 0
	if cs.check_block(FWConst.ROLE_WORLD_ADMIN, x, y, z, type) != "":
		return 0
	cs._add_block(Vector3i(x, y, z), type, 0, OWNER)
	return 1


## درخت و حیوان‌های آرام دور میدان، قطعی از Seed جهان (جدا از rng سازه‌ها).
static func _scatter_god(cs, id: String, d: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"]) * 104729 + 3
	var wanted: Array = []
	for i in range(int(d["trees"])):
		wanted.append("tree")
	for kind in d["animals"]:
		for i in range(int(d["animals"][kind])):
			wanted.append(str(kind))
	for kind in wanted:
		for _try in range(12):
			if cs.god.size() >= FWConst.GOD_MAX:
				return
			var a := rng.randf() * TAU
			var r := 14.0 + rng.randf() * 40.0
			var x: float = float(Scenarios.CENTER) + cos(a) * r
			var z: float = float(Scenarios.CENTER) + sin(a) * r
			if not cs._god_spot_ok(x, z) or cs.blocks.has(Vector3i(int(floor(x)), _ground_level(cs, int(floor(x)), int(floor(z))), int(floor(z)))):
				continue
			var gid: int = cs.next_god_id
			cs.next_god_id += 1
			cs.god[gid] = {"id": gid, "kind": kind, "x": x, "z": z, "tx": x, "tz": z, "wait": 1.0}
			break
