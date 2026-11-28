extends RefCounted
## چند جهان آفلاین با نام جدا. هر جهان پوشهٔ ذخیرهٔ خودش و Seed خودش را دارد.
## منطق خالص (روی Array) تا بدون UI قابل آزمایش باشد؛ ذخیره‌ی فهرست در Settings انجام می‌شود.

const Settings = preload("res://scripts/client/settings.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")
const Entitlements = preload("res://scripts/client/entitlements.gd")

const BASE_DIR := "user://worlds"
const LEGACY_DIR := "user://offline_world"
const MAX_WORLDS := 12
const NAME_MIN := 1
const NAME_MAX := 24


static func clean_name(raw: String) -> String:
	var n := raw.strip_edges().replace("\n", " ")
	if n.length() > NAME_MAX:
		n = n.substr(0, NAME_MAX)
	return n


## جهان جدید به فهرست اضافه می‌شود. خروجی: {ok, id} یا {ok:false, error}.
static func add_world(worlds: Array, raw_name: String, seed_value: int, creative: bool = false, scenario: String = "") -> Dictionary:
	var n := clean_name(raw_name)
	if n.length() < NAME_MIN:
		return {"ok": false, "error": "bad_world_name"}
	if worlds.size() >= MAX_WORLDS:
		return {"ok": false, "error": "too_many_worlds"}
	for w in worlds:
		if str(w["name"]).to_lower() == n.to_lower():
			return {"ok": false, "error": "world_name_taken"}
	if scenario != "":
		if not Scenarios.has(scenario):
			return {"ok": false, "error": "bad_world_name"}
		if not Entitlements.is_unlocked(scenario):
			return {"ok": false, "error": "locked_world"}
		# جهان آماده: Seed و حالت از تعریف سناریو می‌آید (حالت خلاقانه را تیک کاربر هم می‌تواند روشن کند).
		seed_value = int(Scenarios.def(scenario)["seed"])
		creative = creative or bool(Scenarios.def(scenario)["creative"])
	var id := _new_id(worlds)
	var w := {"id": id, "name": n, "seed": seed_value, "creative": creative}
	if scenario != "":
		w["scenario"] = scenario
	worlds.append(w)
	return {"ok": true, "id": id}


## سفر سیاره‌ای: آیا جهان مقصد (جهان آمادهٔ آن سیاره) وجود دارد یا می‌شود ساخت؟ خالی = بله.
static func voyage_target_error(worlds: Array, scenario: String) -> String:
	if not Scenarios.has(scenario):
		return "bad_request"
	if not Entitlements.is_unlocked(scenario):
		return "locked_world"
	if not find_scenario_world(worlds, scenario).is_empty():
		return ""
	if worlds.size() >= MAX_WORLDS:
		return "too_many_worlds"
	return ""


static func _new_id(worlds: Array) -> String:
	var i := 1
	while true:
		var cand := "w%d" % i
		var used := false
		for w in worlds:
			if str(w["id"]) == cand:
				used = true
				break
		if not used:
			return cand
		i += 1
	return ""


static func find(worlds: Array, id: String) -> Dictionary:
	for w in worlds:
		if str(w["id"]) == id:
			return w
	return {}


static func find_by_name(worlds: Array, name: String) -> Dictionary:
	for w in worlds:
		if str(w["name"]).to_lower() == name.to_lower():
			return w
	return {}


## آخرین جهانی که از این جهان آماده ساخته شده (خالی اگر نیست).
static func find_scenario_world(worlds: Array, scenario: String) -> Dictionary:
	for i in range(worlds.size() - 1, -1, -1):
		if str(worlds[i].get("scenario", "")) == scenario:
			return worlds[i]
	return {}


## نام یکتا بر پایهٔ base: «نام»، «نام ۲»، «نام ۳» …
static func unique_name(worlds: Array, base: String) -> String:
	var b := clean_name(base)
	var n := b
	var k := 2
	while not find_by_name(worlds, n).is_empty():
		var suffix := " %d" % k
		n = b.substr(0, NAME_MAX - suffix.length()) + suffix
		k += 1
	return n


static func remove_world(worlds: Array, id: String) -> bool:
	for i in worlds.size():
		if str(worlds[i]["id"]) == id:
			worlds.remove_at(i)
			return true
	return false


static func data_dir(w: Dictionary) -> String:
	return str(w.get("dir", "%s/%s" % [BASE_DIR, str(w["id"])]))


## پاک‌کردن فایل‌های یک جهان (فقط فایل‌های همان پوشه).
static func erase_files(w: Dictionary) -> void:
	var d := data_dir(w)
	var dir := DirAccess.open(d)
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(d)


# ---------------- ذخیرهٔ فهرست در Settings ----------------

static func load_worlds() -> Array:
	var raw = Settings.get_value("worlds", [])
	var out: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for w in raw:
			if typeof(w) == TYPE_DICTIONARY and w.has("id") and w.has("name") and w.has("seed"):
				out.append(w)
	if out.is_empty():
		out = _migrate_legacy()
	return out


## ذخیرهٔ قدیمی (یک جهان در user://offline_world) به‌صورت جهان «جهان من» حفظ می‌شود.
static func _migrate_legacy() -> Array:
	var out: Array = []
	var legacy_seed := int(Settings.get_value("local_seed", 0))
	if legacy_seed != 0 and DirAccess.dir_exists_absolute(LEGACY_DIR):
		out.append({"id": "w1", "name": "جهان من", "seed": legacy_seed, "dir": LEGACY_DIR})
		save_worlds(out)
		Settings.set_value("current_world", "w1")
	return out


static func save_worlds(worlds: Array) -> void:
	Settings.set_value("worlds", worlds)


static func current_id(worlds: Array) -> String:
	var id := str(Settings.get_value("current_world", ""))
	if not find(worlds, id).is_empty():
		return id
	return str(worlds[0]["id"]) if not worlds.is_empty() else ""


static func set_current(id: String) -> void:
	Settings.set_value("current_world", id)
