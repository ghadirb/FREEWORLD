extends RefCounted
## کتابخانهٔ سازه‌ها (Blueprint): بازیکن بلوک‌های کپی‌شده را با نام ذخیره می‌کند و می‌تواند
## با بقیهٔ بازیکنان شهر به اشتراک بگذارد. چسباندن همچنان از مسیر معتبرِ c2s_paste انجام می‌شود
## (برد، مالکیت، مواد...)؛ این ماژول فقط داده را نگه می‌دارد و دسترسی را کنترل می‌کند.

const FWConst = preload("res://scripts/core/const.gd")

const PER_PLAYER_MAX := 12
const TOTAL_MAX := 120
const NAME_MAX := 24

var items: Dictionary = {}   # شناسه ← {id, name, author, shared, n, size: [x,y,z], data: PackedInt32Array}
var next_id: int = 1


## داده باید دقیقاً خروجی copy_region باشد: ۵ عدد برای هر بلوک با فاصلهٔ نسبی ۰..۱۵. نامعتبر ← آرایهٔ خالی.
static func clean_data(data: PackedInt32Array) -> PackedInt32Array:
	if data.size() == 0 or data.size() % 5 != 0 or data.size() > FWConst.REGION_MAX_VOLUME * 5:
		return PackedInt32Array()
	var seen: Dictionary = {}
	var i := 0
	while i < data.size():
		var dx := data[i]
		var dy := data[i + 1]
		var dz := data[i + 2]
		var tid := data[i + 3]
		var col := data[i + 4]
		i += 5
		if dx < 0 or dy < 0 or dz < 0 or dx >= FWConst.REGION_MAX_SIDE or dy >= FWConst.REGION_MAX_SIDE or dz >= FWConst.REGION_MAX_SIDE:
			return PackedInt32Array()
		if tid < 0 or tid >= FWConst.BLOCK_ORDER.size() or not FWConst.meta_valid(col):
			return PackedInt32Array()
		var key := Vector3i(dx, dy, dz)
		if seen.has(key):
			return PackedInt32Array()
		seen[key] = true
	return data


static func clean_name(raw: String) -> String:
	var out := ""
	for ch in raw.strip_edges():
		if ch.unicode_at(0) >= 32:
			out += ch
	return out.strip_edges().substr(0, NAME_MAX)


func count_by(author: String) -> int:
	var n := 0
	for id in items:
		if str(items[id]["author"]) == author:
			n += 1
	return n


## نتیجه: {"ok": bool, "id": int, "error": String}
func save(author: String, raw_name: String, data: PackedInt32Array, shared: bool) -> Dictionary:
	var nm := clean_name(raw_name)
	if nm == "":
		return {"ok": false, "id": 0, "error": "bp_name"}
	var d := clean_data(data)
	if d.is_empty():
		return {"ok": false, "id": 0, "error": "bp_bad"}
	if items.size() >= TOTAL_MAX:
		return {"ok": false, "id": 0, "error": "bp_full"}
	if count_by(author) >= PER_PLAYER_MAX:
		return {"ok": false, "id": 0, "error": "bp_limit"}
	var mx := Vector3i.ZERO
	var i := 0
	while i < d.size():
		mx = Vector3i(maxi(mx.x, d[i]), maxi(mx.y, d[i + 1]), maxi(mx.z, d[i + 2]))
		i += 5
	var id := next_id
	next_id += 1
	items[id] = {"id": id, "name": nm, "author": author, "shared": shared, "n": d.size() / 5,
		"size": [mx.x + 1, mx.y + 1, mx.z + 1], "data": d}
	return {"ok": true, "id": id, "error": ""}


func can_see(player: String, id: int) -> bool:
	if not items.has(id):
		return false
	var b: Dictionary = items[id]
	return bool(b["shared"]) or str(b["author"]) == player


## فقط سازندهٔ سازه یا مدیر. خطا یا "" برای موفقیت.
func remove(actor: String, id: int, is_admin: bool) -> String:
	if not items.has(id):
		return "bp_missing"
	if str(items[id]["author"]) != actor and not is_admin:
		return "forbidden"
	items.erase(id)
	return ""


func set_shared(actor: String, id: int, shared: bool) -> String:
	if not items.has(id):
		return "bp_missing"
	if str(items[id]["author"]) != actor:
		return "forbidden"
	items[id]["shared"] = shared
	return ""


## فهرست خلاصه (بدون داده‌ها) برای بازیکن: سازه‌های خودش و سازه‌های اشتراکی دیگران.
func list_for(player: String) -> Array:
	var out: Array = []
	for id in items:
		if can_see(player, id):
			var b: Dictionary = items[id]
			out.append({"id": int(b["id"]), "name": str(b["name"]), "author": str(b["author"]),
				"shared": bool(b["shared"]), "n": int(b["n"]), "size": b["size"].duplicate()})
	out.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
	return out


func data_for(player: String, id: int) -> PackedInt32Array:
	if not can_see(player, id):
		return PackedInt32Array()
	return items[id]["data"]


func to_dict() -> Dictionary:
	var arr: Array = []
	for id in items:
		var b: Dictionary = items[id]
		arr.append({"id": int(b["id"]), "name": str(b["name"]), "author": str(b["author"]), "shared": bool(b["shared"]),
			"data": Marshalls.raw_to_base64((b["data"] as PackedInt32Array).to_byte_array())})
	return {"next_id": next_id, "items": arr}


func load_dict(d) -> void:
	items.clear()
	next_id = 1
	if not (d is Dictionary):
		return
	next_id = maxi(1, int(d.get("next_id", 1)))
	var arr = d.get("items", [])
	if not (arr is Array):
		return
	for e in arr:
		if not (e is Dictionary) or not e.has("data"):
			continue
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(e["data"]))
		var data := clean_data(raw.to_int32_array())
		var nm := clean_name(str(e.get("name", "")))
		if data.is_empty() or nm == "" or items.size() >= TOTAL_MAX:
			continue
		var id := int(e.get("id", 0))
		if id <= 0 or items.has(id):
			continue
		var mx := Vector3i.ZERO
		var i := 0
		while i < data.size():
			mx = Vector3i(maxi(mx.x, data[i]), maxi(mx.y, data[i + 1]), maxi(mx.z, data[i + 2]))
			i += 5
		items[id] = {"id": id, "name": nm, "author": str(e.get("author", "")), "shared": bool(e.get("shared", false)),
			"n": data.size() / 5, "size": [mx.x + 1, mx.y + 1, mx.z + 1], "data": data}
		next_id = maxi(next_id, id + 1)
