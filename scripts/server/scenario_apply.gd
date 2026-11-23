extends RefCounted
## اعمال یک جهان آماده روی شهر تازه. فقط یک بار برای هر جهان اجرا می‌شود (پرچم scenario_applied در ذخیره می‌ماند).
## سازه‌ها با نقش مدیر و مالک «world» ساخته می‌شوند؛ هر ستونی که قانون ساخت را نقض کند (آب، روستا، معدن…) بی‌صدا رد می‌شود.

const FWConst = preload("res://scripts/core/const.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")
const NpcSim = preload("res://scripts/server/npc_sim.gd")

const OWNER := "world"


## خروجی: تعداد بلوک‌های ساخته‌شده؛ -1 اگر سناریو ناشناخته یا قبلاً اعمال شده باشد.
static func apply(cs, id: String) -> int:
	if cs.scenario_applied or not Scenarios.has(id):
		return -1
	var d: Dictionary = Scenarios.def(id)
	cs.scenario = id
	cs.scenario_applied = true
	cs.creative = cs.creative or bool(d["creative"])
	cs.world_time = float(d["hour"]) * 3600.0
	cs.weather = str(d["weather"])
	cs.time_speed = float(d["time_speed"])
	cs.forest_growth = bool(d["forest_growth"])
	NpcSim.ensure_npcs(cs, clampi(int(d["npcs"]), FWConst.NPC_COUNT, FWConst.NPC_NAMES.size()))
	var placed := _place_columns(cs, Scenarios.columns(id))
	_scatter_god(cs, id, d)
	return placed


static func _ground_level(cs, x: int, z: int) -> int:
	var h: float = cs.world.height_at(float(x) + 0.5, float(z) + 0.5)
	return 0 if h < 0.2 else maxi(0, int(floor(h)))


static func _place_columns(cs, cols: Array) -> int:
	var placed := 0
	for c in cols:
		var x := int(c[0])
		var z := int(c[1])
		var base := _ground_level(cs, x, z)
		for i in range(int(c[3])):
			if cs.blocks.size() >= FWConst.MAX_BLOCKS_TOTAL:
				return placed
			var y := base + int(c[2]) + i
			var type := str(c[4])
			if cs.check_block(FWConst.ROLE_WORLD_ADMIN, x, y, z, type) != "":
				continue
			cs._add_block(Vector3i(x, y, z), type, 0, OWNER)
			placed += 1
	return placed


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
