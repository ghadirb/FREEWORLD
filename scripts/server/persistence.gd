extends RefCounted
## ذخیره‌سازی امن: نوشتن در فایل موقت، نگه‌داشتن نسخهٔ .bak و بازیابی هنگام خرابی.


static func save_json(path: String, data: Dictionary) -> bool:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Persistence: cannot open %s" % tmp)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return parsed


## ابتدا فایل اصلی، در صورت خرابی نسخهٔ پشتیبان. در غیر این صورت {}.
static func load_json(path: String) -> Dictionary:
	var d = _read(path)
	if d != null:
		return d
	d = _read(path + ".bak")
	if d != null:
		push_warning("Persistence: main save invalid, recovered from backup")
		return d
	return {}
