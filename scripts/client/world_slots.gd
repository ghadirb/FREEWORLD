extends RefCounted
## چند جهان آفلاین با نام جدا. هر جهان پوشهٔ ذخیرهٔ خودش و Seed خودش را دارد.
## منطق خالص (روی Array) تا بدون UI قابل آزمایش باشد؛ ذخیره‌ی فهرست در Settings انجام می‌شود.

const Settings = preload("res://scripts/client/settings.gd")

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
static func add_world(worlds: Array, raw_name: String, seed_value: int) -> Dictionary:
	var n := clean_name(raw_name)
	if n.length() < NAME_MIN:
		return {"ok": false, "error": "bad_world_name"}
	if worlds.size() >= MAX_WORLDS:
		return {"ok": false, "error": "too_many_worlds"}
	for w in worlds:
		if str(w["name"]).to_lower() == n.to_lower():
			return {"ok": false, "error": "world_name_taken"}
	var id := _new_id(worlds)
	worlds.append({"id": id, "name": n, "seed": seed_value})
	return {"ok": true, "id": id}


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
