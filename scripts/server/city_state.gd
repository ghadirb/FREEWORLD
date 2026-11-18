extends RefCounted
## وضعیت دائمی و مرجع یک شهر: حساب‌ها، ساختمان‌ها، اقتصاد، مجوزها و گزارش اقدامات.
## هیچ وابستگی‌ای به شبکه ندارد تا کاملاً قابل تست باشد.

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const NpcNav = preload("res://scripts/server/npc_nav.gd")

const SAVE_VERSION := 1
const MAX_REQUEST_MEMORY := 64

var city_id: String = "city_1"
var seed_value: int = 12345
var world
var accounts: Dictionary = {}
var buildings: Dictionary = {}
var occupied: Dictionary = {}
var next_building_id: int = 1
var audit: Array = []
var world_time: float = 8.0 * 3600.0
var wheat_price: float = FWConst.WHEAT_BASE_PRICE
var npcs: Array = []
var _audit_counter: int = 0
## با هر تغییر در ساختمان‌ها زیاد می‌شود تا شبکهٔ مسیریابی دوباره ساخته شود (ذخیره نمی‌شود).
var nav_version: int = 0
var nav
## مسیر فعلی هر NPC (حافظهٔ موقت؛ ذخیره نمی‌شود): id -> {goal: Vector2i, ver: int, pts: Array}
var npc_paths: Dictionary = {}


func _init(s: int = 12345, id: String = "city_1") -> void:
	seed_value = s
	city_id = id
	world = WorldGen.new(s)
	nav = NpcNav.new(self)


static func hash_token(token: String) -> String:
	return token.sha256_text()


static func new_token() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(16).hex_encode()


func spawn_position() -> Vector3:
	var x := FWConst.CITY_SIZE * 0.5
	var z := FWConst.CITY_SIZE * 0.5 + 6.0
	return Vector3(x, world.height_at(x, z), z)


## حساب را می‌سازد (در صورت نبود) و نتیجهٔ احراز هویت را برمی‌گرداند.
## {ok, error, token (فقط برای حساب جدید)}
func authenticate(player_name: String, token: String) -> Dictionary:
	if accounts.has(player_name):
		var acc: Dictionary = accounts[player_name]
		if acc["token_hash"] == hash_token(token):
			return {"ok": true, "token": ""}
		return {"ok": false, "error": "bad_token"}
	var t := new_token()
	var sp := spawn_position()
	accounts[player_name] = {
		"money": FWConst.START_MONEY,
		"role": FWConst.ROLE_PLAYER,
		"token_hash": hash_token(t),
		"pos": [sp.x, sp.y, sp.z],
		"wheat": 0,
		"requests": [],
	}
	_log(player_name, "account_created", {})
	return {"ok": true, "token": t}


## حساب مدیر با رمز مشخص (از آرگومان سرور) از پیش ساخته می‌شود.
func provision_admin(player_name: String, secret: String, role: String = FWConst.ROLE_WORLD_ADMIN) -> void:
	var sp := spawn_position()
	if accounts.has(player_name):
		accounts[player_name]["role"] = role
		accounts[player_name]["token_hash"] = hash_token(secret)
		return
	accounts[player_name] = {
		"money": FWConst.START_MONEY,
		"role": role,
		"token_hash": hash_token(secret),
		"pos": [sp.x, sp.y, sp.z],
		"wheat": 0,
		"requests": [],
	}


func count_owned(player_name: String) -> int:
	var n := 0
	for id in buildings:
		if buildings[id]["owner"] == player_name:
			n += 1
	return n


## قابل‌عبور بودن نقطه برای بازیکن و NPC: جاده و چاه آزادند، بقیه ساختمان‌ها مانع‌اند.
func is_walkable(x: float, z: float) -> bool:
	var cx := int(floor(x / FWConst.CELL_SIZE))
	var cz := int(floor(z / FWConst.CELL_SIZE))
	var key := Placement.cell_key(cx, cz)
	if occupied.has(key):
		var t: String = buildings[occupied[key]]["type"]
		if t != "road" and t != "well":
			return false
	return world.height_at(x, z) >= -0.3


## نقطهٔ جلوی در ساختمان (برای فاصلهٔ تعامل و مقصد NPC).
func door_point(b: Dictionary) -> Vector2:
	var size: Array = FWConst.building_size(b["type"])
	return Vector2(
		(float(b["cx"]) + float(size[0]) * 0.5) * FWConst.CELL_SIZE,
		(float(b["cz"]) + float(size[1])) * FWConst.CELL_SIZE + 1.0)


## اعمال تغییر دریافتی از سرور روی نسخهٔ محلی کلاینت (بدون اعتبارسنجی).
func apply_add(b: Dictionary) -> void:
	var nb := {
		"id": int(b["id"]), "type": str(b["type"]), "owner": str(b["owner"]),
		"cx": int(b["cx"]), "cz": int(b["cz"]), "stock": float(b.get("stock", 0)),
	}
	buildings[nb["id"]] = nb
	for c in Placement.footprint(nb["type"], nb["cx"], nb["cz"]):
		occupied[Placement.cell_key(c.x, c.y)] = nb["id"]
	nav_version += 1


func apply_remove(id: int) -> void:
	if not buildings.has(id):
		return
	var b: Dictionary = buildings[id]
	for c in Placement.footprint(b["type"], b["cx"], b["cz"]):
		occupied.erase(Placement.cell_key(c.x, c.y))
	buildings.erase(id)
	nav_version += 1


func role_of(player_name: String) -> String:
	if accounts.has(player_name):
		return accounts[player_name]["role"]
	return FWConst.ROLE_PLAYER


func money_of(player_name: String) -> int:
	return int(accounts[player_name]["money"])


func _log(actor: String, action: String, detail: Dictionary) -> void:
	_audit_counter += 1
	audit.append({"n": _audit_counter, "t": int(world_time), "actor": actor, "action": action, "detail": detail})
	if audit.size() > FWConst.AUDIT_MAX:
		audit = audit.slice(audit.size() - FWConst.AUDIT_MAX)


func _remember_request(acc: Dictionary, req_id: int) -> bool:
	## true = قبلاً دیده شده (درخواست تکراری).
	var reqs: Array = acc["requests"]
	if reqs.has(req_id):
		return true
	reqs.append(req_id)
	if reqs.size() > MAX_REQUEST_MEMORY:
		reqs.pop_front()
	return false


func place_building(player_name: String, req_id: int, type: String, cx: int, cz: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var acc: Dictionary = accounts[player_name]
	if req_id != 0 and _remember_request(acc, req_id):
		return {"ok": false, "error": "duplicate", "silent": true}
	var err := Placement.check(world, occupied, type, cx, cz, acc["role"])
	if err != "":
		return {"ok": false, "error": err}
	if not FWConst.is_admin(acc["role"]) and count_owned(player_name) >= FWConst.MAX_BUILDINGS_PER_PLAYER:
		return {"ok": false, "error": "limit"}
	var cost := int(FWConst.BUILDING_TYPES[type]["cost"])
	if int(acc["money"]) < cost:
		return {"ok": false, "error": "no_money"}
	acc["money"] = int(acc["money"]) - cost
	var b := {
		"id": next_building_id,
		"type": type,
		"owner": player_name,
		"cx": cx,
		"cz": cz,
		"stock": 0.0,
	}
	next_building_id += 1
	buildings[b["id"]] = b
	for c in Placement.footprint(type, cx, cz):
		occupied[Placement.cell_key(c.x, c.y)] = b["id"]
	nav_version += 1
	_log(player_name, "place", {"id": b["id"], "type": type, "cx": cx, "cz": cz})
	return {"ok": true, "building": b, "money": acc["money"]}


func remove_building(player_name: String, id: int) -> Dictionary:
	if not accounts.has(player_name) or not buildings.has(id):
		return {"ok": false, "error": "no_building"}
	var b: Dictionary = buildings[id]
	var role: String = accounts[player_name]["role"]
	var is_owner: bool = b["owner"] == player_name
	if not is_owner and not FWConst.is_admin(role):
		return {"ok": false, "error": "forbidden"}
	for c in Placement.footprint(b["type"], b["cx"], b["cz"]):
		occupied.erase(Placement.cell_key(c.x, c.y))
	buildings.erase(id)
	nav_version += 1
	var refund := int(int(FWConst.BUILDING_TYPES[b["type"]]["cost"]) * FWConst.REFUND_RATIO)
	var owner_name: String = b["owner"]
	if accounts.has(owner_name):
		accounts[owner_name]["money"] = int(accounts[owner_name]["money"]) + refund
	if not is_owner:
		# اقدام مدیر روی ملک دیگران حتماً در گزارش ثبت می‌شود.
		_log(player_name, "admin_remove", {"id": id, "owner": owner_name, "type": b["type"]})
	else:
		_log(player_name, "remove", {"id": id, "type": b["type"]})
	return {"ok": true, "id": id, "owner": owner_name, "refund": refund}


func collect(player_name: String, id: int) -> Dictionary:
	if not accounts.has(player_name) or not buildings.has(id):
		return {"ok": false, "error": "no_building"}
	var b: Dictionary = buildings[id]
	if b["owner"] != player_name:
		return {"ok": false, "error": "forbidden"}
	if b["type"] != "farm":
		return {"ok": false, "error": "not_farm"}
	var n := int(floor(float(b["stock"])))
	if n < 1:
		return {"ok": false, "error": "nothing"}
	var earned := 0
	for i in range(n):
		earned += int(floor(wheat_price))
		wheat_price = maxf(FWConst.WHEAT_MIN_PRICE, wheat_price - FWConst.WHEAT_SELL_DROP)
	b["stock"] = float(b["stock"]) - n
	accounts[player_name]["money"] = int(accounts[player_name]["money"]) + earned
	_log(player_name, "collect", {"id": id, "count": n, "earned": earned})
	return {"ok": true, "count": n, "earned": earned, "money": accounts[player_name]["money"], "building": b}


func set_role(actor: String, target: String, role: String) -> Dictionary:
	if role_of(actor) != FWConst.ROLE_WORLD_ADMIN:
		return {"ok": false, "error": "forbidden"}
	if not FWConst.ROLES.has(role) or not accounts.has(target):
		return {"ok": false, "error": "bad_request"}
	accounts[target]["role"] = role
	_log(actor, "set_role", {"target": target, "role": role})
	return {"ok": true}


func tick(delta: float) -> void:
	world_time = fposmod(world_time + delta * FWConst.TIME_SCALE, 86400.0)
	wheat_price = minf(FWConst.WHEAT_BASE_PRICE, wheat_price + FWConst.WHEAT_RECOVER_PER_SEC * delta)
	for id in buildings:
		var b: Dictionary = buildings[id]
		if b["type"] == "farm":
			b["stock"] = minf(FWConst.FARM_MAX_STOCK, float(b["stock"]) + delta / FWConst.FARM_SECONDS_PER_WHEAT)


func building_public(b: Dictionary) -> Dictionary:
	return {
		"id": b["id"], "type": b["type"], "owner": b["owner"],
		"cx": b["cx"], "cz": b["cz"], "stock": int(floor(float(b["stock"]))),
	}


func all_buildings_public() -> Array:
	var out: Array = []
	for id in buildings:
		out.append(building_public(buildings[id]))
	return out


func to_dict() -> Dictionary:
	var bl: Array = []
	for id in buildings:
		bl.append(buildings[id])
	return {
		"save_version": SAVE_VERSION,
		"city_id": city_id,
		"seed": seed_value,
		"world_time": world_time,
		"wheat_price": wheat_price,
		"next_building_id": next_building_id,
		"accounts": accounts,
		"buildings": bl,
		"audit": audit,
		"npcs": npcs,
	}


## داده‌ی بارگذاری‌شده را اعتبارسنجی می‌کند. در صورت خرابی null برمی‌گرداند.
static func from_dict(d: Dictionary):
	for k in ["save_version", "city_id", "seed", "accounts", "buildings", "next_building_id"]:
		if not d.has(k):
			return null
	if typeof(d["accounts"]) != TYPE_DICTIONARY or typeof(d["buildings"]) != TYPE_ARRAY:
		return null
	var cs = load("res://scripts/server/city_state.gd").new(int(d["seed"]), str(d["city_id"]))
	cs.world_time = float(d.get("world_time", 8.0 * 3600.0))
	cs.wheat_price = float(d.get("wheat_price", FWConst.WHEAT_BASE_PRICE))
	cs.next_building_id = int(d["next_building_id"])
	for name in d["accounts"]:
		var a: Dictionary = d["accounts"][name]
		if not (a.has("money") and a.has("role") and a.has("token_hash") and a.has("pos")):
			return null
		var reqs: Array = []
		for r in a.get("requests", []):
			reqs.append(int(r))
		cs.accounts[str(name)] = {
			"money": int(a["money"]),
			"role": str(a["role"]) if FWConst.ROLES.has(str(a["role"])) else FWConst.ROLE_PLAYER,
			"token_hash": str(a["token_hash"]),
			"pos": [float(a["pos"][0]), float(a["pos"][1]), float(a["pos"][2])],
			"wheat": int(a.get("wheat", 0)),
			"requests": reqs,
		}
	for b in d["buildings"]:
		if not (b.has("id") and b.has("type") and b.has("owner") and b.has("cx") and b.has("cz")):
			return null
		if not FWConst.BUILDING_TYPES.has(str(b["type"])):
			return null
		var nb := {
			"id": int(b["id"]), "type": str(b["type"]), "owner": str(b["owner"]),
			"cx": int(b["cx"]), "cz": int(b["cz"]), "stock": float(b.get("stock", 0.0)),
		}
		cs.buildings[nb["id"]] = nb
		for c in Placement.footprint(nb["type"], nb["cx"], nb["cz"]):
			cs.occupied[Placement.cell_key(c.x, c.y)] = nb["id"]
	for n in d.get("npcs", []):
		if n is Dictionary and n.has("id") and n.has("x") and n.has("z"):
			cs.npcs.append({
				"id": int(n["id"]), "name": str(n.get("name", "NPC")),
				"x": float(n["x"]), "z": float(n["z"]),
				"state": str(n.get("state", "idle")), "money": int(n.get("money", 100)),
				"paid_day": int(n.get("paid_day", -1)),
				"income_day": int(n.get("income_day", -1)),
			})
	for e in d.get("audit", []):
		cs.audit.append(e)
	cs._audit_counter = cs.audit.size()
	return cs
