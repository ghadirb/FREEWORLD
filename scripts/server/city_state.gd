extends RefCounted
## وضعیت دائمی و مرجع یک شهر: حساب‌ها، ساختمان‌ها، اقتصاد، مجوزها و گزارش اقدامات.
## هیچ وابستگی‌ای به شبکه ندارد تا کاملاً قابل تست باشد.

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const NpcNav = preload("res://scripts/server/npc_nav.gd")
const Minigame = preload("res://scripts/server/minigame.gd")
const Race = preload("res://scripts/server/race.gd")
const Mine = preload("res://scripts/shared/mine.gd")

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
## ابزارهای World Mode: ضریب سرعت گذر زمان و آب‌وهوا (هر دو ذخیره می‌شوند).
var time_speed: float = 1.0
var day_count: int = 0
var god: Dictionary = {}
var next_god_id: int = 1
var _god_rng := RandomNumberGenerator.new()
var weather: String = "clear"
var disaster: Dictionary = {"kind": "", "t": 0.0}   # حادثهٔ جاری؛ موقت و ذخیره‌نشده
var disaster_cooldown: float = 0.0
var bread_price: float = FWConst.BREAD_BASE_PRICE
## موجودی بازار مشترک شهر: کالایی که کشاورزان فروخته‌اند و هنوز مصرف نشده.
var market: Dictionary = {"wheat": 0.0, "flour": 0.0, "bread": 0.0, "egg": 0.0, "milk": 0.0, "cheese": 0.0}
## قیمت کالاهای دامی (تخم‌مرغ و شیر).
var prices: Dictionary = {"egg": 6.0, "milk": 14.0, "flour": 16.0, "bread": 20.0, "cheese": 34.0}
var npcs: Array = []
var minigame = Minigame.new()
var race = Race.new()
## ساخت بلوکی: Vector3i -> [نوع, رنگ, مالک]. block_cells شمارندهٔ بلوک در هر خانهٔ ۲×۲ شبکهٔ ساختمان است.
var blocks: Dictionary = {}
var block_cells: Dictionary = {}
var block_owner_count: Dictionary = {}
## منابع برداشت‌شده: "rx,rz" -> ثانیهٔ باقی‌مانده تا رویش دوباره. respawned را سرور تخلیه می‌کند.
var depleted: Dictionary = {}
var respawned: Array = []
## سنگ‌های برداشت‌شدهٔ معدن‌ها: "mx,mz:idx" -> ثانیهٔ باقی‌مانده تا رویش دوباره. mine_respawned را سرور تخلیه می‌کند.
var mine_depleted: Dictionary = {}
var mine_respawned: Array = []
## ضریب قیمت فروش هر ماده (با فروش زیاد کم می‌شود و کم‌کم برمی‌گردد).
var item_mult: Dictionary = {}
## پیشنهادهای معامله بین بازیکنان (ذخیره نمی‌شوند): id -> {from, to, item, n, price, ttl}
var offers: Dictionary = {}
var _next_offer: int = 1
## فاصلهٔ پرداخت حقوق (قابل تغییر در تست).
var wage_interval: float = FWConst.WAGE_INTERVAL
var _audit_counter: int = 0
## با هر تغییر در ساختمان‌ها زیاد می‌شود تا شبکهٔ مسیریابی دوباره ساخته شود (ذخیره نمی‌شود).
var nav_version: int = 0
## خانه‌های ۲×۲ که بلوک دیوار دارند (NPCها از آن‌ها رد نمی‌شوند). فقط سرور لازم دارد.
var walled: Dictionary = {}
var track_nav: bool = true
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
		"job": 0,
		"work_acc": 0.0,
		"energy": FWConst.ENERGY_MAX,
		"inv": FWConst.START_ITEMS.duplicate(),
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
		"job": 0,
		"work_acc": 0.0,
		"energy": FWConst.ENERGY_MAX,
		"inv": FWConst.START_ITEMS.duplicate(),
	}


func count_owned(player_name: String) -> int:
	var n := 0
	for id in buildings:
		if buildings[id]["owner"] == player_name:
			n += 1
	return n


## قابل‌عبور بودن نقطه برای بازیکن و NPC: جاده و چاه آزادند، بقیه ساختمان‌ها مانع‌اند.
## بلوک‌ها هم مانع‌اند (جز در و جاده). ref_y ارتفاع فعلی بازیکن است تا طبقه‌ها و پله‌ها درست تشخیص داده شوند.
func is_walkable(x: float, z: float, ref_y: float = NAN) -> bool:
	var cx := int(floor(x / FWConst.CELL_SIZE))
	var cz := int(floor(z / FWConst.CELL_SIZE))
	var key := Placement.cell_key(cx, cz)
	if occupied.has(key):
		var t: String = buildings[occupied[key]]["type"]
		if t != "road" and t != "well":
			return false
	return not is_nan(surface_at(x, z, ref_y))


func _solid_at(bx: int, lv: int, bz: int) -> bool:
	var b = blocks.get(Vector3i(bx, lv, bz))
	return b != null and not FWConst.block_passable(str(b[0]))


## ارتفاع پله در نقطهٔ (fx, fz) داخل بلوک: از لبهٔ پایین (۰) تا لبهٔ بالا (۱) در جهت facing.
static func stair_t(fx: float, fz: float, facing: int) -> float:
	match facing:
		0:
			return fz
		1:
			return fx
		2:
			return 1.0 - fz
	return 1.0 - fx


## سطحی که در (x, z) می‌شود روی آن ایستاد و از ارتفاع ref_y قابل‌رسیدن است (حداکثر یک بلوک بالاتر).
## زمین، بالای بلوک‌های پر، جاده و پله کاندید هستند و باید جای سر (دو بلوک) آزاد باشد.
## اگر ref_y داده نشود، ارتفاع زمین مرجع است. NAN یعنی نمی‌شود رفت.
func surface_at(x: float, z: float, ref_y: float = NAN) -> float:
	var h: float = world.height_at(x, z)
	if blocks.is_empty():
		return h if h >= -0.3 else NAN
	var limit: float = (h if is_nan(ref_y) else ref_y) + FWConst.STEP_UP
	var bx := int(floor(x))
	var bz := int(floor(z))
	var lv := maxi(0, int(floor(h)))
	var best := NAN
	if h >= -0.3 and h <= limit and not _solid_at(bx, lv, bz) and not _solid_at(bx, lv + 1, bz):
		best = h
	for k in range(lv, lv + FWConst.MAX_BLOCK_HEIGHT + 1):
		if float(k) > limit:
			break
		var b = blocks.get(Vector3i(bx, k, bz))
		if b == null:
			continue
		var t := str(b[0])
		var sv: float
		var top := k + 2
		match t:
			"door":
				continue
			"road":
				sv = maxf(float(k) + 0.15, h) if k == lv else float(k) + 0.15
				top = k + 1
			"stairs":
				sv = float(k) + stair_t(x - float(bx), z - float(bz), FWConst.meta_facing(int(b[1])))
				if k == lv:
					sv = maxf(sv, h)
			_:
				sv = float(k + 1)
		if sv > limit:
			continue
		var clear := true
		for lvl in range(k + 1, top + 1):
			if _solid_at(bx, lvl, bz):
				clear = false
				break
		if clear and (is_nan(best) or sv > best):
			best = sv
	return best


## ارتفاع سطحی که بازیکن روی آن می‌ایستد (زمین، بالای بلوک، جاده، پله).
func ground_height(x: float, z: float, ref_y: float = NAN) -> float:
	var s := surface_at(x, z, ref_y)
	return world.height_at(x, z) if is_nan(s) else s


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
	if blocks_in_footprint(type, cx, cz):
		return {"ok": false, "error": "blocks_in_way"}
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
		"prog": 0.0,
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
	var fired: Array = _clear_jobs_for(id)
	var refund := int(int(FWConst.BUILDING_TYPES[b["type"]]["cost"]) * FWConst.REFUND_RATIO)
	var owner_name: String = b["owner"]
	if accounts.has(owner_name):
		accounts[owner_name]["money"] = int(accounts[owner_name]["money"]) + refund
	if not is_owner:
		# اقدام مدیر روی ملک دیگران حتماً در گزارش ثبت می‌شود.
		_log(player_name, "admin_remove", {"id": id, "owner": owner_name, "type": b["type"]})
	else:
		_log(player_name, "remove", {"id": id, "type": b["type"]})
	return {"ok": true, "id": id, "owner": owner_name, "refund": refund, "fired": fired}


## برداشت و فروش تولید: گندم از مزرعه یا نان از نانوایی. کالا به بازار شهر می‌رود.
func collect(player_name: String, id: int) -> Dictionary:
	if not accounts.has(player_name) or not buildings.has(id):
		return {"ok": false, "error": "no_building"}
	var b: Dictionary = buildings[id]
	if b["owner"] != player_name:
		return {"ok": false, "error": "forbidden"}
	var good := ""
	match str(b["type"]):
		"farm":
			good = "wheat"
		"bakery":
			good = "bread"
		"coop", "barn":
			good = str(FWConst.LIVESTOCK[str(b["type"])]["good"])
		"mill", "dairy":
			good = str(FWConst.PROCESSORS[str(b["type"])]["output"])
		_:
			return {"ok": false, "error": "not_producer"}
	var n := int(floor(float(b["stock"])))
	if n < 1:
		return {"ok": false, "error": "nothing"}
	var earned := 0
	for i in range(n):
		if good == "wheat":
			earned += int(floor(wheat_price))
			wheat_price = maxf(FWConst.WHEAT_MIN_PRICE, wheat_price - FWConst.WHEAT_SELL_DROP)
		elif good == "bread":
			earned += int(floor(float(prices[good])))
			prices[good] = maxf(float(FWConst.PROCESSORS["bakery"]["min"]), float(prices[good]) - float(FWConst.PROCESSORS["bakery"]["drop"]))
			bread_price = float(prices[good]) # compatibility for existing clients/saves
		elif FWConst.PROCESSORS.has(str(b["type"])):
			var proc: Dictionary = FWConst.PROCESSORS[str(b["type"])]
			earned += int(floor(float(prices[good])))
			prices[good] = maxf(float(proc["min"]), float(prices[good]) - float(proc["drop"]))
		else:
			var lv: Dictionary = FWConst.LIVESTOCK[str(b["type"])]
			earned += int(floor(float(prices[good])))
			prices[good] = maxf(float(lv["min"]), float(prices[good]) - float(lv["drop"]))
	b["stock"] = float(b["stock"]) - n
	market[good] = minf(FWConst.MARKET_MAX_STOCK, float(market[good]) + n)
	accounts[player_name]["money"] = int(accounts[player_name]["money"]) + earned
	_log(player_name, "collect", {"id": id, "good": good, "count": n, "earned": earned})
	return {"ok": true, "good": good, "count": n, "earned": earned, "money": accounts[player_name]["money"], "building": b}


# ---------------- مشاغل ----------------

func _clear_jobs_for(building_id: int) -> Array:
	var fired: Array = []
	for n in accounts:
		if int(accounts[n].get("job", 0)) == building_id:
			accounts[n]["job"] = 0
			accounts[n]["work_acc"] = 0.0
			fired.append(n)
	return fired


func job_of(player_name: String) -> int:
	if accounts.has(player_name):
		return int(accounts[player_name].get("job", 0))
	return 0


## استخدام در مزرعه یا نانوایی بازیکن دیگر. شغل قبلی (در صورت وجود) جایگزین می‌شود.
func take_job(player_name: String, building_id: int) -> Dictionary:
	if not accounts.has(player_name) or not buildings.has(building_id):
		return {"ok": false, "error": "no_building"}
	var b: Dictionary = buildings[building_id]
	if not FWConst.JOB_TYPES.has(str(b["type"])):
		return {"ok": false, "error": "bad_workplace"}
	if b["owner"] == player_name:
		return {"ok": false, "error": "own_workplace"}
	if not accounts.has(b["owner"]):
		return {"ok": false, "error": "bad_workplace"}
	if job_of(player_name) == building_id:
		return {"ok": false, "error": "already_employed"}
	accounts[player_name]["job"] = building_id
	accounts[player_name]["work_acc"] = 0.0
	_log(player_name, "job_taken", {"building": building_id, "employer": b["owner"]})
	return {"ok": true, "building": building_id}


func quit_job(player_name: String) -> Dictionary:
	if job_of(player_name) == 0:
		return {"ok": false, "error": "no_job"}
	var old: int = job_of(player_name)
	accounts[player_name]["job"] = 0
	accounts[player_name]["work_acc"] = 0.0
	_log(player_name, "job_quit", {"building": old})
	return {"ok": true}


## یک گام کار: positions = {نام بازیکن آنلاین: Vector2}. کارگر حاضر در محل کار تولید را سریع‌تر
## می‌کند و به‌ازای هر wage_interval ثانیه حقوق از جیب کارفرما می‌گیرد.
## رویدادها: {worker, employer, amount (۰ یعنی کارفرما پول نداشت)}
func work_step(delta: float, positions: Dictionary) -> Array:
	var events: Array = []
	for name in accounts:
		var acc: Dictionary = accounts[name]
		var jid: int = int(acc.get("job", 0))
		if jid == 0 or not positions.has(name):
			continue
		if float(acc.get("energy", FWConst.ENERGY_MAX)) <= 0.0:
			continue  # خسته است؛ باید در خانه استراحت کند
		if not buildings.has(jid):
			acc["job"] = 0
			continue
		var b: Dictionary = buildings[jid]
		if (positions[name] as Vector2).distance_to(door_point(b)) > FWConst.INTERACT_RANGE:
			continue
		match str(b["type"]):
			"farm":
				b["stock"] = minf(FWConst.FARM_MAX_STOCK,
					float(b["stock"]) + delta / FWConst.FARM_SECONDS_PER_WHEAT * FWConst.WORKER_BONUS)
			"bakery", "mill", "dairy":
				b["prog"] = minf(float(b.get("prog", 0.0)) + delta * FWConst.WORKER_BONUS, float(FWConst.PROCESSORS[str(b["type"])]["seconds"]))
			"coop", "barn":
				var lv: Dictionary = FWConst.LIVESTOCK[str(b["type"])]
				b["stock"] = minf(float(lv["max"]), float(b["stock"]) + delta / float(lv["seconds"]) * FWConst.WORKER_BONUS)
		acc["work_acc"] = float(acc.get("work_acc", 0.0)) + delta
		if float(acc["work_acc"]) < wage_interval:
			continue
		acc["work_acc"] = float(acc["work_acc"]) - wage_interval
		var employer: String = b["owner"]
		if accounts.has(employer) and int(accounts[employer]["money"]) >= FWConst.WAGE_AMOUNT:
			accounts[employer]["money"] = int(accounts[employer]["money"]) - FWConst.WAGE_AMOUNT
			acc["money"] = int(acc["money"]) + FWConst.WAGE_AMOUNT
			_log(employer, "wage", {"worker": name, "amount": FWConst.WAGE_AMOUNT})
			events.append({"worker": name, "employer": employer, "amount": FWConst.WAGE_AMOUNT})
		else:
			events.append({"worker": name, "employer": employer, "amount": 0})
	return events


## تغییر تنظیمات جهان توسط مدیر. key: "time_speed" یا "weather".
## خطای ورود به ساختمان یا رشتهٔ خالی. pos فاصلهٔ تعامل را می‌سنجد.
func enter_error(player_name: String, id: int, pos: Vector2) -> String:
	if not accounts.has(player_name) or not buildings.has(id):
		return "no_building"
	var b: Dictionary = buildings[id]
	if not FWConst.ENTERABLE.has(str(b["type"])):
		return "not_enterable"
	if str(b["type"]) == "house" and b["owner"] != player_name:
		return "private_house"
	if pos.distance_to(door_point(b)) > FWConst.INTERACT_RANGE:
		return "too_far"
	return ""


## یک گام انرژی. online = {نام بازیکن: شناسهٔ ساختمانی که داخلش است (۰ = بیرون)}.
## در خانهٔ خودش استراحت می‌کند؛ در غیر این صورت به‌آرامی کم می‌شود.
func energy_step(delta: float, online: Dictionary) -> void:
	for name in online:
		if not accounts.has(name):
			continue
		var acc: Dictionary = accounts[name]
		var e: float = float(acc.get("energy", FWConst.ENERGY_MAX))
		var bid: int = int(online[name])
		var resting: bool = bid > 0 and buildings.has(bid) and str(buildings[bid]["type"]) == "house" and buildings[bid]["owner"] == name
		if resting:
			e += FWConst.ENERGY_REST_PER_SEC * delta
		else:
			var mult: float = FWConst.STORM_ENERGY_MULT if (str(disaster["kind"]) == "storm" and bid == 0) else 1.0
			e -= FWConst.ENERGY_DECAY_PER_SEC * delta * mult
		acc["energy"] = clampf(e, 0.0, FWConst.ENERGY_MAX)


func set_world(actor: String, key: String, value: Variant) -> Dictionary:
	if not FWConst.is_admin(role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	match key:
		"time_speed":
			var v := float(value)
			if not FWConst.TIME_SPEEDS.has(v):
				return {"ok": false, "error": "bad_request"}
			time_speed = v
		"weather":
			if not FWConst.WEATHERS.has(str(value)):
				return {"ok": false, "error": "bad_request"}
			weather = str(value)
		_:
			return {"ok": false, "error": "bad_request"}
	_log(actor, "set_world", {"key": key, "value": value})
	return {"ok": true, "world": world_public()}


## آغاز حادثهٔ طبیعی توسط مدیر. همزمان فقط یکی و بین دو حادثه وقفه هست.
func start_disaster(actor: String, kind: String) -> Dictionary:
	if not FWConst.is_admin(role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	if not FWConst.DISASTERS.has(kind):
		return {"ok": false, "error": "bad_request"}
	if str(disaster["kind"]) != "":
		return {"ok": false, "error": "disaster_active"}
	if disaster_cooldown > 0.0:
		return {"ok": false, "error": "disaster_cooldown"}
	disaster = {"kind": kind, "t": float(FWConst.DISASTERS[kind])}
	_log(actor, "disaster", {"kind": kind})
	return {"ok": true, "disaster": disaster_public()}


## true یعنی حادثه همین حالا تمام شد (برای اعلام به کلاینت‌ها).
func disaster_step(delta: float) -> bool:
	disaster_cooldown = maxf(0.0, disaster_cooldown - delta)
	if str(disaster["kind"]) == "":
		return false
	disaster["t"] = float(disaster["t"]) - delta
	if float(disaster["t"]) > 0.0:
		return false
	disaster = {"kind": "", "t": 0.0}
	disaster_cooldown = FWConst.DISASTER_COOLDOWN
	return true


func disaster_public() -> Dictionary:
	return {"kind": str(disaster["kind"]), "t": snappedf(float(disaster["t"]), 0.1)}


func world_public() -> Dictionary:
	return {"time_speed": time_speed, "weather": weather}


func set_role(actor: String, target: String, role: String) -> Dictionary:
	if role_of(actor) != FWConst.ROLE_WORLD_ADMIN:
		return {"ok": false, "error": "forbidden"}
	if not FWConst.ROLES.has(role) or not accounts.has(target):
		return {"ok": false, "error": "bad_request"}
	accounts[target]["role"] = role
	_log(actor, "set_role", {"target": target, "role": role})
	return {"ok": true}


# ---------------- ساخت بلوکی، منابع و فروشگاه ----------------

const NEIGHBORS := [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


func blocks_in_footprint(type: String, cx: int, cz: int) -> bool:
	if block_cells.is_empty():
		return false
	for c in Placement.footprint(type, cx, cz):
		if block_cells.has(Placement.cell_key(c.x, c.y)):
			return true
	return false


## خانه دیوار دارد اگر در یکی از چهار ستونش بلوک پر در ارتفاع سر باشد (یک بلوک تکی قابل‌قدم‌گذاشتن است).
func _cell_walled(cx: int, cz: int) -> bool:
	if not block_cells.has(Placement.cell_key(cx, cz)):
		return false
	for dx in range(2):
		for dz in range(2):
			var bx := cx * 2 + dx
			var bz := cz * 2 + dz
			var lv := maxi(0, int(floor(world.height_at(float(bx) + 0.5, float(bz) + 0.5))))
			if _solid_at(bx, lv + 1, bz):
				return true
	return false


func _refresh_walled(cx: int, cz: int) -> void:
	if not track_nav:
		return
	var key := Placement.cell_key(cx, cz)
	var now := _cell_walled(cx, cz)
	if now == walled.has(key):
		return
	if now:
		walled[key] = true
	else:
		walled.erase(key)
	nav_version += 1


func _add_block(v: Vector3i, type: String, color: int, owner_name: String) -> void:
	if blocks.has(v):
		return
	blocks[v] = [type, color, owner_name]
	var k := Placement.cell_key(v.x >> 1, v.z >> 1)
	block_cells[k] = int(block_cells.get(k, 0)) + 1
	block_owner_count[owner_name] = int(block_owner_count.get(owner_name, 0)) + 1
	_refresh_walled(v.x >> 1, v.z >> 1)


func _del_block(v: Vector3i) -> void:
	if not blocks.has(v):
		return
	var owner_name: String = str(blocks[v][2])
	blocks.erase(v)
	var k := Placement.cell_key(v.x >> 1, v.z >> 1)
	var left := int(block_cells.get(k, 0)) - 1
	if left <= 0:
		block_cells.erase(k)
	else:
		block_cells[k] = left
	block_owner_count[owner_name] = maxi(0, int(block_owner_count.get(owner_name, 0)) - 1)
	_refresh_walled(v.x >> 1, v.z >> 1)


## اعمال تغییر بلوک روی نسخهٔ محلی کلاینت: type_id < 0 یعنی حذف.
func apply_block(x: int, y: int, z: int, type_id: int, color: int) -> void:
	var v := Vector3i(x, y, z)
	if type_id < 0 or type_id >= FWConst.BLOCK_ORDER.size():
		_del_block(v)
		return
	if blocks.has(v):
		_del_block(v)
	_add_block(v, str(FWConst.BLOCK_ORDER[type_id]), color if FWConst.meta_valid(color) else 0, "")


func block_batches() -> Array:
	var out: Array = []
	var cur := PackedInt32Array()
	for v in blocks:
		var b: Array = blocks[v]
		cur.append(v.x)
		cur.append(v.y)
		cur.append(v.z)
		cur.append(FWConst.BLOCK_ORDER.find(str(b[0])))
		cur.append(int(b[1]))
		if cur.size() >= FWConst.BLOCK_SEND_BATCH * 5:
			out.append(cur)
			cur = PackedInt32Array()
	if cur.size() > 0:
		out.append(cur)
	return out


func inv_count(inv: Dictionary, item: String) -> int:
	return int(inv.get(item, 0))


func has_items(inv: Dictionary, cost: Dictionary, times: int = 1) -> bool:
	for item in cost:
		if int(inv.get(item, 0)) < int(cost[item]) * times:
			return false
	return true


func _inv_add(acc: Dictionary, item: String, n: int) -> void:
	var inv: Dictionary = acc["inv"]
	inv[item] = mini(FWConst.ITEM_CAP, int(inv.get(item, 0)) + n)


func sell_price(item: String) -> int:
	return maxi(1, int(floor(float(FWConst.ITEMS[item]) * float(item_mult.get(item, 1.0)))))


static func buy_price(item: String) -> int:
	return int(ceil(float(FWConst.ITEMS[item]) * FWConst.BUY_MARKUP))


func inv_public(player_name: String) -> Dictionary:
	var sell: Dictionary = {}
	for item in FWConst.ITEM_ORDER:
		sell[item] = sell_price(item)
	var inv: Dictionary = {}
	if accounts.has(player_name):
		for item in FWConst.ITEM_ORDER:
			inv[item] = int(accounts[player_name]["inv"].get(item, 0))
	var tools: Dictionary = {}
	if accounts.has(player_name):
		for tl in FWConst.TOOL_UPGRADES:
			tools[tl] = tool_tier(accounts[player_name], tl)
	var friends: Dictionary = {}
	if accounts.has(player_name) and accounts[player_name].get("friends") is Dictionary:
		friends = accounts[player_name]["friends"].duplicate()
	return {"inv": inv, "sell": sell, "tools": tools, "friends": friends}


## خطای کد برای قرار دادن یک بلوک (رشتهٔ خالی = مجاز). موجودی و سقف‌ها جداگانه بررسی می‌شوند.
func check_block(role: String, x: int, y: int, z: int, type: String) -> String:
	if not FWConst.BLOCK_TYPES.has(type):
		return "unknown_type"
	var lo := -int(FWConst.WORLD_LIMIT)
	var hi := int(FWConst.CITY_SIZE + FWConst.WORLD_LIMIT)
	if x < lo or z < lo or x >= hi or z >= hi:
		return "out_of_bounds"
	var v := Vector3i(x, y, z)
	if blocks.has(v):
		return "occupied"
	if world.near_mine_entrance(float(x) + 0.5, float(z) + 0.5, FWConst.MINE_NO_BUILD_RADIUS):
		return "near_mine"
	if occupied.has(Placement.cell_key(x >> 1, z >> 1)):
		return "occupied"
	if not FWConst.is_admin(role):
		var cx := x >> 1
		var cz := z >> 1
		if cx >= FWConst.PLAZA_MIN and cx <= FWConst.PLAZA_MAX and cz >= FWConst.PLAZA_MIN and cz <= FWConst.PLAZA_MAX:
			return "reserved"
	var h: float = world.height_at(float(x) + 0.5, float(z) + 0.5)
	var water := h < 0.2
	var lv := 0 if water else maxi(0, int(floor(h)))
	if y < lv:
		return "underground"
	if y > lv + FWConst.MAX_BLOCK_HEIGHT:
		return "too_high"
	if water or y > lv:
		var supported := false
		for d in NEIGHBORS:
			if blocks.has(v + d):
				supported = true
				break
		# پل: کنار ساحل (خشکی) روی سطح دریا هم تکیه‌گاه حساب می‌شود.
		if not supported and water and y == 0:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if world.height_at(float(x + d.x) + 0.5, float(z + d.y) + 0.5) >= 0.2:
					supported = true
					break
		if not supported:
			return "unsupported"
	return ""


func place_block(player_name: String, req_id: int, x: int, y: int, z: int, type: String, color: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var acc: Dictionary = accounts[player_name]
	if req_id != 0 and _remember_request(acc, req_id):
		return {"ok": false, "error": "duplicate", "silent": true}
	if not FWConst.meta_valid(color):
		return {"ok": false, "error": "bad_request"}
	var err := check_block(acc["role"], x, y, z, type)
	if err != "":
		return {"ok": false, "error": err}
	if blocks.size() >= FWConst.MAX_BLOCKS_TOTAL:
		return {"ok": false, "error": "limit"}
	if not FWConst.is_admin(acc["role"]) and int(block_owner_count.get(player_name, 0)) >= FWConst.MAX_BLOCKS_PER_PLAYER:
		return {"ok": false, "error": "limit"}
	var cost: Dictionary = FWConst.BLOCK_TYPES[type]["cost"]
	if not has_items(acc["inv"], cost):
		return {"ok": false, "error": "no_items"}
	for item in cost:
		acc["inv"][item] = int(acc["inv"][item]) - int(cost[item])
	_add_block(Vector3i(x, y, z), type, color, player_name)
	return {"ok": true, "type": type, "color": color}


func remove_block(player_name: String, x: int, y: int, z: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var v := Vector3i(x, y, z)
	if not blocks.has(v):
		return {"ok": false, "error": "no_block"}
	var b: Array = blocks[v]
	var owner_name: String = str(b[2])
	if owner_name != player_name and not FWConst.is_admin(role_of(player_name)):
		return {"ok": false, "error": "forbidden"}
	var cost: Dictionary = FWConst.BLOCK_TYPES[str(b[0])]["cost"]
	if accounts.has(owner_name):
		for item in cost:
			_inv_add(accounts[owner_name], str(item), int(cost[item]))
	if owner_name != player_name:
		_log(player_name, "admin_remove_block", {"owner": owner_name, "type": str(b[0]), "x": x, "y": y, "z": z})
	_del_block(v)
	return {"ok": true, "owner": owner_name}


func paint_block(player_name: String, x: int, y: int, z: int, color: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var v := Vector3i(x, y, z)
	if not blocks.has(v):
		return {"ok": false, "error": "no_block"}
	if color < 0 or color >= FWConst.COLOR_COUNT:
		return {"ok": false, "error": "bad_request"}
	var b: Array = blocks[v]
	if str(b[2]) != player_name and not FWConst.is_admin(role_of(player_name)):
		return {"ok": false, "error": "forbidden"}
	b[1] = (int(b[1]) / 16) * 16 + color  # جهت پله حفظ می‌شود
	return {"ok": true, "type": str(b[0]), "color": int(b[1])}


## برداشت از درخت/سنگ/خاک رس. pos موقعیت بازیکن است (برای فاصله).
func tool_tier(acc: Dictionary, tool: String) -> int:
	var t: Variant = acc.get("tools", {})
	return 2 if (t is Dictionary and bool(t.get(tool, false))) else 1


## ابزارهای خلقت. action: "add" یا "remove". فقط مدیران.
func god_action(actor: String, action: String, kind: String, x: float, z: float) -> Dictionary:
	if not FWConst.is_admin(role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	if not (is_finite(x) and is_finite(z)):
		return {"ok": false, "error": "bad_request"}
	var half := FWConst.CITY_SIZE * 0.5
	if absf(x - half) > FWConst.WORLD_LIMIT or absf(z - half) > FWConst.WORLD_LIMIT:
		return {"ok": false, "error": "bad_place"}
	if action == "remove":
		var best := -1
		var best_d := FWConst.GOD_REMOVE_RANGE
		for id in god:
			var d := Vector2(float(god[id]["x"]), float(god[id]["z"])).distance_to(Vector2(x, z))
			if d <= best_d:
				best_d = d
				best = id
		if best < 0:
			return {"ok": false, "error": "no_target"}
		var k: String = str(god[best]["kind"])
		god.erase(best)
		_log(actor, "god_remove", {"kind": k})
		return {"ok": true}
	if action != "add" or not (FWConst.GOD_STATIC.has(kind) or FWConst.GOD_ANIMALS.has(kind)):
		return {"ok": false, "error": "bad_request"}
	if god.size() >= FWConst.GOD_MAX:
		return {"ok": false, "error": "god_full"}
	if not _god_spot_ok(x, z):
		return {"ok": false, "error": "bad_place"}
	var id := next_god_id
	next_god_id += 1
	god[id] = {"id": id, "kind": kind, "x": x, "z": z, "tx": x, "tz": z, "wait": 1.0}
	_log(actor, "god_add", {"kind": kind})
	return {"ok": true, "id": id}


func _god_spot_ok(x: float, z: float) -> bool:
	if world.height_at(x, z) < FWConst.GOD_MIN_HEIGHT:
		return false
	return not occupied.has(Placement.cell_key(int(floor(x / FWConst.CELL_SIZE)), int(floor(z / FWConst.CELL_SIZE))))


## حیوانات آرام راه می‌روند: هدف تصادفی نزدیک، فقط روی خشکی و بیرون از ساختمان‌ها.
func god_step(dt: float) -> void:
	for id in god:
		var g: Dictionary = god[id]
		if not FWConst.GOD_ANIMALS.has(str(g["kind"])):
			continue
		var pos := Vector2(float(g["x"]), float(g["z"]))
		var target := Vector2(float(g["tx"]), float(g["tz"]))
		if pos.distance_to(target) < 0.3:
			g["wait"] = float(g["wait"]) - dt
			if float(g["wait"]) <= 0.0:
				var a := _god_rng.randf() * TAU
				var r := 2.0 + _god_rng.randf() * 6.0
				g["tx"] = pos.x + cos(a) * r
				g["tz"] = pos.y + sin(a) * r
				g["wait"] = 2.0 + _god_rng.randf() * 5.0
			continue
		var step: Vector2 = pos.move_toward(target, float(FWConst.GOD_ANIMALS[str(g["kind"])]) * dt)
		if _god_spot_ok(step.x, step.y):
			g["x"] = step.x
			g["z"] = step.y
		else:
			g["tx"] = pos.x
			g["tz"] = pos.y


func god_public() -> Array:
	var out: Array = []
	var ids: Array = god.keys()
	ids.sort()
	for id in ids:
		var g: Dictionary = god[id]
		out.append([int(id), str(g["kind"]), snappedf(float(g["x"]), 0.05), snappedf(float(g["z"]), 0.05)])
	return out


func god_has_animals() -> bool:
	for id in god:
		if FWConst.GOD_ANIMALS.has(str(god[id]["kind"])):
			return true
	return false


static func friend_level(points: int) -> int:
	var lv := 0
	for t in FWConst.FRIEND_LEVELS:
		if points >= int(t):
			lv += 1
	return lv


func friendship_of(acc: Dictionary, npc_id: int) -> int:
	var f: Variant = acc.get("friends", {})
	return int(f.get(str(npc_id), 0)) if f is Dictionary else 0


## صحبت (item خالی) یا هدیه دادن یک واحد کالا به NPC نزدیک. هرکدام روزی یک بار برای هر NPC.
func npc_interact(player_name: String, npc_id: int, item: String, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var npc: Dictionary = {}
	for n in npcs:
		if int(n["id"]) == npc_id:
			npc = n
			break
	if npc.is_empty():
		return {"ok": false, "error": "no_npc"}
	if pos.distance_to(Vector2(float(npc["x"]), float(npc["z"]))) > FWConst.NPC_TALK_RANGE:
		return {"ok": false, "error": "too_far"}
	var acc: Dictionary = accounts[player_name]
	if not (acc.get("friends") is Dictionary):
		acc["friends"] = {}
	if not (acc.get("npc_day") is Dictionary):
		acc["npc_day"] = {}
	var kind := "talk" if item == "" else "gift"
	var dkey := "%d:%s" % [npc_id, kind]
	if int(acc["npc_day"].get(dkey, -1)) == day_count:
		return {"ok": false, "error": "already_talked" if kind == "talk" else "already_gifted"}
	var pts := friendship_of(acc, npc_id)
	var gain := 0
	var reward := 0
	if kind == "talk":
		gain = FWConst.FRIEND_TALK_POINTS
		var want: int = int(FWConst.FRIEND_REWARD[friend_level(pts)])
		reward = mini(want, int(npc["money"]))
		npc["money"] = int(npc["money"]) - reward
		acc["money"] = int(acc["money"]) + reward
	else:
		if not FWConst.ITEMS.has(item) or int(acc["inv"].get(item, 0)) < 1:
			return {"ok": false, "error": "no_items"}
		acc["inv"][item] = int(acc["inv"][item]) - 1
		gain = clampi(int(ceil(float(FWConst.ITEMS[item]) * 0.5)), 1, 15)
	acc["npc_day"][dkey] = day_count
	var np: int = mini(FWConst.FRIEND_MAX, pts + gain)
	acc["friends"][str(npc_id)] = np
	return {"ok": true, "kind": kind, "npc": str(npc["name"]), "npc_id": npc_id, "points": np, "level": friend_level(np),
		"reward": reward, "item": item, "money": int(acc["money"])}


## فروش n واحد کالا به NPC نزدیک. قیمت هر واحد = قیمت فعلی بازار + پاداش دوستی؛ پول از کیف خود NPC می‌رود،
## پس اگر NPC پول کم داشته باشد فقط به اندازهٔ توانش می‌خرد. بازار مشترک را تکان نمی‌دهد.
func npc_sell(player_name: String, npc_id: int, item: String, n: int, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if not FWConst.ITEMS.has(item) or n < 1 or n > FWConst.NPC_TRADE_MAX:
		return {"ok": false, "error": "bad_request"}
	var npc: Dictionary = {}
	for nn in npcs:
		if int(nn["id"]) == npc_id:
			npc = nn
			break
	if npc.is_empty():
		return {"ok": false, "error": "no_npc"}
	if pos.distance_to(Vector2(float(npc["x"]), float(npc["z"]))) > FWConst.NPC_TALK_RANGE:
		return {"ok": false, "error": "too_far"}
	var acc: Dictionary = accounts[player_name]
	if int(acc["inv"].get(item, 0)) < n:
		return {"ok": false, "error": "no_items"}
	var lv := friend_level(friendship_of(acc, npc_id))
	var unit := maxi(1, int(floor(float(sell_price(item)) * (1.0 + float(FWConst.NPC_TRADE_BONUS[lv])))))
	var afford := int(npc["money"]) / unit
	var count := mini(n, afford)
	if count < 1:
		return {"ok": false, "error": "npc_broke"}
	var total := unit * count
	npc["money"] = int(npc["money"]) - total
	acc["inv"][item] = int(acc["inv"][item]) - count
	acc["money"] = int(acc["money"]) + total
	_log(player_name, "npc_sell", {"npc": npc_id, "item": item, "n": count, "total": total})
	return {"ok": true, "npc": str(npc["name"]), "item": item, "count": count, "total": total, "money": int(acc["money"])}


## شروع یک دور مینی‌بازی سکه‌یاب برای بازیکن.
func minigame_start(player_name: String, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if race.is_running(player_name):
		return {"ok": false, "error": "mg_running"}
	return minigame.start(world, seed_value, player_name, pos)


## شروع مسابقهٔ ایستگاه‌ها. هم‌زمان با سکه‌یاب ممکن نیست.
func race_start(player_name: String, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if minigame.is_running(player_name):
		return {"ok": false, "error": "mg_running"}
	return race.start(world, seed_value, player_name, pos)


func race_step(dt: float, positions: Dictionary) -> Array:
	var events: Array = race.step(dt, positions, day_count)
	for ev in events:
		if ev["kind"] == "end":
			var nm: String = ev["name"]
			if int(ev["reward"]) > 0 and accounts.has(nm):
				accounts[nm]["money"] = int(accounts[nm]["money"]) + int(ev["reward"])
				_log(nm, "race_reward", {"time": ev["time"], "reward": ev["reward"]})
			ev["money"] = money_of(nm)
	return events


## هر فریم سرور: رویدادهای مینی‌بازی را می‌گیرد و جایزهٔ دورهای تمام‌شده را به حساب بازیکن می‌ریزد.
func minigame_step(dt: float, positions: Dictionary) -> Array:
	var events: Array = minigame.step(dt, positions, day_count)
	for ev in events:
		if ev["kind"] == "end":
			var nm: String = ev["name"]
			if int(ev["reward"]) > 0 and accounts.has(nm):
				accounts[nm]["money"] = int(accounts[nm]["money"]) + int(ev["reward"])
				_log(nm, "minigame_reward", {"score": ev["score"], "reward": ev["reward"]})
			ev["money"] = money_of(nm)
	return events


func gather(player_name: String, rx: int, rz: int, tool: String, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var node: Dictionary = world.resource_in_cell(rx, rz)
	if node.is_empty():
		return {"ok": false, "error": "no_resource"}
	var key := "%d,%d" % [rx, rz]
	if depleted.has(key):
		return {"ok": false, "error": "depleted"}
	var def: Dictionary = FWConst.RESOURCES[str(node["kind"])]
	if tool != str(def["tool"]):
		return {"ok": false, "error": "wrong_tool", "tool": str(def["tool"])}
	if pos.distance_to(Vector2(float(node["x"]), float(node["z"]))) > FWConst.GATHER_RANGE:
		return {"ok": false, "error": "too_far"}
	var acc: Dictionary = accounts[player_name]
	if tool_tier(acc, tool) < int(def.get("min_tier", 1)):
		return {"ok": false, "error": "needs_better_tool"}
	if def.has("reward_min"):
		# صندوق گنج: مقدار پاداش قطعی از موقعیت گره (همه جا یکسان)، نه تصادفی سمت کلاینت.
		var span: int = int(def["reward_max"]) - int(def["reward_min"]) + 1
		var reward: int = int(def["reward_min"]) + int(world._h01(rx, rz, 8) * float(span))
		acc["money"] = int(acc["money"]) + reward
		depleted[key] = float(def["respawn"])
		_log(player_name, "treasure", {"rx": rx, "rz": rz, "reward": reward})
		return {"ok": true, "treasure": true, "reward": reward, "money": int(acc["money"]), "rx": rx, "rz": rz}
	var item: String = def["item"]
	if int(acc["inv"].get(item, 0)) >= FWConst.ITEM_CAP:
		return {"ok": false, "error": "inv_full"}
	var got: int = int(node["n"]) + (1 if tool_tier(acc, tool) >= 2 else 0)
	_inv_add(acc, item, got)
	depleted[key] = float(def["respawn"])
	return {"ok": true, "item": item, "count": got, "rx": rx, "rz": rz}


# ---------------- معدن زیرزمینی (پروتکل ۱۷) ----------------

func mine_layout(mine_id: String) -> Dictionary:
	var v: Vector2i = Mine.parse_id(mine_id)
	return Mine.layout(seed_value, v.x, v.y)


## خطای ورود به معدن یا رشتهٔ خالی. pos موقعیت بازیکن روی نقشهٔ بیرون است.
func mine_enter_error(player_name: String, mine_id: String, pos: Vector2) -> String:
	if not accounts.has(player_name):
		return "no_account"
	var e: Dictionary = world.mine_entrance(mine_id)
	if e.is_empty():
		return "no_mine"
	if pos.distance_to(Vector2(float(e["x"]), float(e["z"]))) > FWConst.MINE_ENTER_RANGE:
		return "too_far"
	return ""


## برداشت یک سنگ معدن. mpos موقعیت بازیکن در مختصات محلی معدن است.
## ابزار را سرور از نوع سنگ می‌فهمد (کلنگ؛ برای صندوق دست)، نه از کلاینت.
func mine_gather(player_name: String, mine_id: String, idx: int, mpos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if world.mine_entrance(mine_id).is_empty():
		return {"ok": false, "error": "no_mine"}
	var node: Dictionary = Mine.node_of(mine_layout(mine_id), idx)
	if node.is_empty():
		return {"ok": false, "error": "no_resource"}
	var key := "%s:%d" % [mine_id, idx]
	if mine_depleted.has(key):
		return {"ok": false, "error": "depleted"}
	if mpos.distance_to(Vector2(float(node["x"]), float(node["z"]))) > FWConst.MINE_GATHER_RANGE:
		return {"ok": false, "error": "too_far"}
	var def: Dictionary = FWConst.MINE_ORES[str(node["kind"])]
	var acc: Dictionary = accounts[player_name]
	if def.has("reward_min"):
		var reward: int = int(node["reward"])
		acc["money"] = int(acc["money"]) + reward
		mine_depleted[key] = float(def["respawn"])
		_log(player_name, "mine_treasure", {"mine": mine_id, "idx": idx, "reward": reward})
		return {"ok": true, "treasure": true, "reward": reward, "money": int(acc["money"]), "idx": idx}
	if tool_tier(acc, "pickaxe") < int(def.get("min_tier", 1)):
		return {"ok": false, "error": "needs_better_tool"}
	var item: String = def["item"]
	if int(acc["inv"].get(item, 0)) >= FWConst.ITEM_CAP:
		return {"ok": false, "error": "inv_full"}
	var got: int = int(node["n"]) + (1 if tool_tier(acc, "pickaxe") >= 2 else 0)
	_inv_add(acc, item, got)
	mine_depleted[key] = float(def["respawn"])
	return {"ok": true, "item": item, "count": got, "idx": idx}


## شمارهٔ سنگ‌های برداشت‌شدهٔ یک معدن (برای ارسال به بازیکنی که وارد می‌شود).
func mine_depleted_list(mine_id: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	var prefix := mine_id + ":"
	for key in mine_depleted:
		var k := str(key)
		if k.begins_with(prefix):
			out.append(int(k.substr(prefix.length())))
	out.sort()
	return out


## کندن خاک/شن با بیل: ۱ واحد خاک یا (کنار ساحل) شن.
## رأس شبکهٔ ۲ متریِ نزدیک به نقطه.
static func terrain_vertex(x: float, z: float) -> Vector2i:
	return Vector2i(int(round(x / FWConst.TERRAIN_EDIT_STEP)), int(round(z / FWConst.TERRAIN_EDIT_STEP)))


## خطای تغییر زمین در همسایگی r رأس (r=۱ بیل معمولی ۳×۳، r=۲ بیل آهنی ۵×۵)؛ رشتهٔ خالی = مجاز.
## زیر ساختمان و بلوک و میدان (برای غیرمدیر) قفل است.
func terrain_check(role: String, v: Vector2i, r: int = 1) -> String:
	var lim := int(FWConst.WORLD_LIMIT / FWConst.TERRAIN_EDIT_STEP)
	var hi := int(FWConst.CITY_SIZE / FWConst.TERRAIN_EDIT_STEP) + lim
	if v.x - r < -lim or v.y - r < -lim or v.x + r > hi or v.y + r > hi:
		return "out_of_bounds"
	if world.near_mine_entrance(float(v.x) * FWConst.TERRAIN_EDIT_STEP, float(v.y) * FWConst.TERRAIN_EDIT_STEP, FWConst.MINE_NO_BUILD_RADIUS + float(r) * FWConst.TERRAIN_EDIT_STEP):
		return "near_mine"
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var vx := v.x + dx
			var vz := v.y + dz
			for cx in [vx - 1, vx]:
				for cz in [vz - 1, vz]:
					var key := Placement.cell_key(cx, cz)
					if occupied.has(key) or block_cells.has(key):
						return "terrain_locked"
					if not FWConst.is_admin(role) and cx >= FWConst.PLAZA_MIN and cx <= FWConst.PLAZA_MAX and cz >= FWConst.PLAZA_MIN and cz <= FWConst.PLAZA_MAX:
						return "reserved"
	return ""


## تغییر را روی لایهٔ زمین اعمال می‌کند (سرور و کلاینت). sign = -1 کندن، +1 پر کردن.
## فهرست رأس‌های واقعاً تغییرکرده را [[ix, iz, مقدار جدید], ...] برمی‌گرداند.
func apply_terraform(v: Vector2i, sign: int, r: int = 1) -> Array:
	var changed: Array = []
	var st: Array = FWConst.TERRAIN_DIG_STRENGTH_IRON if r >= 2 else FWConst.TERRAIN_DIG_STRENGTH
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var ring: int = absi(dx) + absi(dz)
			if ring >= st.size():
				continue
			var ix := v.x + dx
			var iz := v.y + dz
			var old: int = world.edit_units(ix, iz)
			world.set_edit(ix, iz, old + sign * int(st[ring]))
			var now: int = world.edit_units(ix, iz)
			if now != old:
				changed.append([ix, iz, now])
	return changed


func terrain_flat() -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in world.edits:
		var kp: PackedStringArray = str(k).split(",")
		out.append(int(kp[0]))
		out.append(int(kp[1]))
		out.append(int(world.edits[k]))
	return out


func _terraform(player_name: String, x: float, z: float, tool: String, pos: Vector2, sign: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if tool != "shovel":
		return {"ok": false, "error": "wrong_tool", "tool": "shovel"}
	if pos.distance_to(Vector2(x, z)) > FWConst.GATHER_RANGE:
		return {"ok": false, "error": "too_far"}
	var v := terrain_vertex(x, z)
	var acc0: Dictionary = accounts[player_name]
	var rad := 2 if tool_tier(acc0, "shovel") >= 2 else 1
	var err := terrain_check(role_of(player_name), v, rad)
	if err != "":
		return {"ok": false, "error": err}
	var h: float = world.height_at(x, z)
	var acc: Dictionary = accounts[player_name]
	var item := "sand" if h < 0.9 else "dirt"
	if sign < 0:
		if int(acc["inv"].get(item, 0)) >= FWConst.ITEM_CAP:
			return {"ok": false, "error": "inv_full"}
	else:
		item = "dirt" if inv_count(acc["inv"], "dirt") > 0 else "sand"
		if inv_count(acc["inv"], item) < 1:
			return {"ok": false, "error": "no_material"}
	var fresh := 0
	for dx in range(-rad, rad + 1):
		for dz in range(-rad, rad + 1):
			if world.edit_units(v.x + dx, v.y + dz) == 0:
				fresh += 1
	if world.edits.size() + fresh > FWConst.TERRAIN_MAX_EDITS:
		return {"ok": false, "error": "terrain_full"}
	var changed := apply_terraform(v, sign, rad)
	if changed.is_empty():
		return {"ok": false, "error": "terrain_limit"}
	var n: int = (2 if tool_tier(acc, "shovel") >= 2 else 1) if sign < 0 else 1
	if sign < 0:
		_inv_add(acc, item, n)
	else:
		_inv_add(acc, item, -1)
	return {"ok": true, "item": item, "count": n, "changes": changed, "mode": "dig" if sign < 0 else "fill"}


## کندن زمین با بیل: خاک یا شن می‌دهد و زمین را پایین می‌برد؛ زیر ۰ متر آب می‌آید (دریاچه).
func dig(player_name: String, x: float, z: float, tool: String, pos: Vector2) -> Dictionary:
	return _terraform(player_name, x, z, tool, pos, -1)


## پر کردن گودی: یک خاک (یا شن) مصرف می‌کند و زمین را بالا می‌آورد.
func fill(player_name: String, x: float, z: float, tool: String, pos: Vector2) -> Dictionary:
	return _terraform(player_name, x, z, tool, pos, 1)


func craft(player_name: String, recipe: String, times: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if not FWConst.RECIPES.has(recipe) or times < 1 or times > 50:
		return {"ok": false, "error": "bad_request"}
	var r: Dictionary = FWConst.RECIPES[recipe]
	var acc: Dictionary = accounts[player_name]
	if r.has("upgrade"):
		var tl: String = str(r["upgrade"])
		if times != 1:
			return {"ok": false, "error": "bad_request"}
		if tool_tier(acc, tl) >= 2:
			return {"ok": false, "error": "already_owned"}
		if not has_items(acc["inv"], r["in"]):
			return {"ok": false, "error": "no_items"}
		for item in r["in"]:
			acc["inv"][item] = int(acc["inv"][item]) - int(r["in"][item])
		if not acc.has("tools") or not (acc["tools"] is Dictionary):
			acc["tools"] = {}
		acc["tools"][tl] = true
		_log(player_name, "tool_upgrade", {"tool": tl})
		return {"ok": true, "upgrade": tl}
	if not has_items(acc["inv"], r["in"], times):
		return {"ok": false, "error": "no_items"}
	for item in r["in"]:
		acc["inv"][item] = int(acc["inv"][item]) - int(r["in"][item]) * times
	_inv_add(acc, str(r["out"]), int(r["n"]) * times)
	return {"ok": true, "item": str(r["out"]), "count": int(r["n"]) * times}


## فروش مواد به بازار شهر (درآمد) یا خرید از فروشگاه عمومی.
func trade(player_name: String, item: String, n: int, buy: bool) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if not FWConst.ITEMS.has(item) or n < 1 or n > 500:
		return {"ok": false, "error": "bad_request"}
	var acc: Dictionary = accounts[player_name]
	var total := 0
	if buy:
		if int(acc["inv"].get(item, 0)) + n > FWConst.ITEM_CAP:
			return {"ok": false, "error": "inv_full"}
		total = buy_price(item) * n
		if int(acc["money"]) < total:
			return {"ok": false, "error": "no_money"}
		acc["money"] = int(acc["money"]) - total
		_inv_add(acc, item, n)
		_log(player_name, "buy_item", {"item": item, "n": n, "cost": total})
		return {"ok": true, "buy": true, "item": item, "count": n, "total": total, "money": acc["money"]}
	if int(acc["inv"].get(item, 0)) < n:
		return {"ok": false, "error": "no_items"}
	for i in range(n):
		total += sell_price(item)
		item_mult[item] = maxf(FWConst.SELL_FLOOR, float(item_mult.get(item, 1.0)) - FWConst.SELL_DROP)
	acc["inv"][item] = int(acc["inv"][item]) - n
	acc["money"] = int(acc["money"]) + total
	return {"ok": true, "buy": false, "item": item, "count": n, "total": total, "money": acc["money"]}


## پیشنهاد فروش مستقیم: from به to، n واحد item را به قیمت کل price می‌فروشد. مواد تا پذیرش نزد فروشنده می‌مانند.
func make_offer(from_name: String, to_name: String, item: String, n: int, price: int) -> Dictionary:
	if not accounts.has(from_name) or not accounts.has(to_name) or from_name == to_name:
		return {"ok": false, "error": "bad_request"}
	if not FWConst.ITEMS.has(item) or n < 1 or n > 500 or price < 0 or price > FWConst.OFFER_MAX_PRICE:
		return {"ok": false, "error": "bad_request"}
	if int(accounts[from_name]["inv"].get(item, 0)) < n:
		return {"ok": false, "error": "no_items"}
	var pending := 0
	for id in offers:
		if offers[id]["from"] == from_name:
			pending += 1
	if pending >= FWConst.OFFER_MAX_PENDING:
		return {"ok": false, "error": "limit"}
	var id := _next_offer
	_next_offer += 1
	offers[id] = {"from": from_name, "to": to_name, "item": item, "n": n, "price": price, "ttl": FWConst.OFFER_TTL}
	return {"ok": true, "id": id, "offer": offers[id]}


func answer_offer(player_name: String, id: int, accept: bool) -> Dictionary:
	if not offers.has(id) or offers[id]["to"] != player_name:
		return {"ok": false, "error": "no_offer"}
	var o: Dictionary = offers[id]
	offers.erase(id)
	if not accept:
		return {"ok": true, "accepted": false, "offer": o}
	var seller: Dictionary = accounts[o["from"]]
	var buyer: Dictionary = accounts[o["to"]]
	if int(seller["inv"].get(o["item"], 0)) < int(o["n"]):
		return {"ok": false, "error": "offer_invalid", "offer": o}
	if int(buyer["money"]) < int(o["price"]):
		return {"ok": false, "error": "no_money", "offer": o}
	if int(buyer["inv"].get(o["item"], 0)) + int(o["n"]) > FWConst.ITEM_CAP:
		return {"ok": false, "error": "inv_full", "offer": o}
	seller["inv"][o["item"]] = int(seller["inv"][o["item"]]) - int(o["n"])
	_inv_add(buyer, str(o["item"]), int(o["n"]))
	buyer["money"] = int(buyer["money"]) - int(o["price"])
	seller["money"] = int(seller["money"]) + int(o["price"])
	_log(o["from"], "p2p_trade", {"to": o["to"], "item": o["item"], "n": o["n"], "price": o["price"]})
	return {"ok": true, "accepted": true, "offer": o}


func _tick_resources(delta: float) -> void:
	for oid in offers.keys():
		offers[oid]["ttl"] = float(offers[oid]["ttl"]) - delta
		if float(offers[oid]["ttl"]) <= 0.0:
			offers.erase(oid)
	for key in depleted.keys():
		depleted[key] = float(depleted[key]) - delta
		if float(depleted[key]) <= 0.0:
			depleted.erase(key)
			respawned.append(key)
	for mkey in mine_depleted.keys():
		mine_depleted[mkey] = float(mine_depleted[mkey]) - delta
		if float(mine_depleted[mkey]) <= 0.0:
			mine_depleted.erase(mkey)
			var mk := str(mkey)
			var cut := mk.rfind(":")
			mine_respawned.append([mk.substr(0, cut), int(mk.substr(cut + 1))])
	for item in item_mult.keys():
		item_mult[item] = minf(1.0, float(item_mult[item]) + FWConst.SELL_RECOVER_PER_SEC * delta)


func depleted_flat() -> PackedInt32Array:
	var out := PackedInt32Array()
	for key in depleted:
		var parts: PackedStringArray = str(key).split(",")
		out.append(int(parts[0]))
		out.append(int(parts[1]))
	return out


func tick(delta: float) -> void:
	_tick_resources(delta)
	var prev_time := world_time
	world_time = fposmod(world_time + delta * FWConst.TIME_SCALE * time_speed, 86400.0)
	if world_time < prev_time:
		day_count += 1
	wheat_price = minf(FWConst.WHEAT_BASE_PRICE, wheat_price + FWConst.WHEAT_RECOVER_PER_SEC * delta)
	bread_price = move_toward(bread_price, FWConst.BREAD_BASE_PRICE, FWConst.BREAD_RECOVER_PER_SEC * delta)
	for id in buildings:
		var b: Dictionary = buildings[id]
		match str(b["type"]):
			"farm":
				var grow: float = FWConst.STORM_FARM_MULT if str(disaster["kind"]) == "storm" else 1.0
				b["stock"] = minf(FWConst.FARM_MAX_STOCK, float(b["stock"]) + delta * grow / FWConst.FARM_SECONDS_PER_WHEAT)
			"bakery", "mill", "dairy":
				_tick_processor(b, delta)
			"coop", "barn":
				var lv: Dictionary = FWConst.LIVESTOCK[str(b["type"])]
				b["stock"] = minf(float(lv["max"]), float(b["stock"]) + delta / float(lv["seconds"]))
	for t in FWConst.LIVESTOCK:
		var lv: Dictionary = FWConst.LIVESTOCK[t]
		var g: String = lv["good"]
		prices[g] = minf(float(lv["base"]), float(prices[g]) + float(lv["recover"]) * delta)
	for t in FWConst.PROCESSORS:
		var proc: Dictionary = FWConst.PROCESSORS[t]
		var output: String = proc["output"]
		prices[output] = minf(float(proc["base"]), float(prices.get(output, proc["base"])) + float(proc["recover"]) * delta)
	bread_price = float(prices["bread"])


## نانوایی: وقتی زمان پخت رسید، اگر بازار گندم داشته باشد و صاحب‌اش پول گندم را بپردازد، یک نان می‌پزد.
## (پول گندم به «بازار شهر» می‌رود؛ کشاورز قبلاً هنگام فروش به بازار پولش را گرفته است.)
func _tick_processor(b: Dictionary, delta: float) -> void:
	var proc: Dictionary = FWConst.PROCESSORS[str(b["type"])]
	if float(b["stock"]) >= float(proc["max"]):
		return
	b["prog"] = minf(float(b.get("prog", 0.0)) + delta, float(proc["seconds"]))
	if float(b["prog"]) < float(proc["seconds"]):
		return
	var owner_name: String = b["owner"]
	if not accounts.has(owner_name):
		return
	var input: String = proc["input"]
	var amount: int = int(proc["amount"])
	if float(market[input]) < float(amount):
		return
	var cost: int = amount * int(floor(_price_for(input)))
	if int(accounts[owner_name]["money"]) < cost:
		return
	accounts[owner_name]["money"] = int(accounts[owner_name]["money"]) - cost
	market[input] = float(market[input]) - float(amount)
	b["stock"] = float(b["stock"]) + 1.0
	b["prog"] = 0.0


## خرید یک نان از بازار توسط NPC؛ پول به صاحب مغازه می‌رسد. true اگر خرید انجام شد.
func npc_buy_bread(npc: Dictionary, shop: Dictionary) -> bool:
	var price: int = int(floor(bread_price))
	if float(market["bread"]) < 1.0 or int(npc["money"]) < price:
		return false
	var owner_name: String = shop["owner"]
	if not accounts.has(owner_name):
		return false
	npc["money"] = int(npc["money"]) - price
	accounts[owner_name]["money"] = int(accounts[owner_name]["money"]) + price
	market["bread"] = float(market["bread"]) - 1.0
	prices["bread"] = minf(FWConst.BREAD_BASE_PRICE * 2.0, float(prices["bread"]) + FWConst.BREAD_BUY_RISE)
	bread_price = float(prices["bread"])
	return true


## خرید یک تخم‌مرغ یا شیر از بازار توسط NPC؛ پول به صاحب مغازه می‌رسد.
func npc_buy_good(npc: Dictionary, shop: Dictionary, good: String) -> bool:
	if not prices.has(good):
		return false
	var price: int = int(floor(float(prices[good])))
	if float(market[good]) < 1.0 or int(npc["money"]) < price:
		return false
	var owner_name: String = shop["owner"]
	if not accounts.has(owner_name):
		return false
	npc["money"] = int(npc["money"]) - price
	accounts[owner_name]["money"] = int(accounts[owner_name]["money"]) + price
	market[good] = float(market[good]) - 1.0
	return true


func market_public() -> Dictionary:
	return {
		"wheat_price": snappedf(wheat_price, 0.01), "bread_price": snappedf(bread_price, 0.01),
		"wheat": int(floor(float(market["wheat"]))), "flour": int(floor(float(market["flour"]))), "bread": int(floor(float(market["bread"]))),
		"egg_price": snappedf(float(prices["egg"]), 0.01), "milk_price": snappedf(float(prices["milk"]), 0.01),
		"flour_price": snappedf(float(prices["flour"]), 0.01), "cheese_price": snappedf(float(prices["cheese"]), 0.01),
		"egg": int(floor(float(market["egg"]))), "milk": int(floor(float(market["milk"]))), "cheese": int(floor(float(market["cheese"]))),
	}


func _price_for(good: String) -> float:
	return wheat_price if good == "wheat" else float(prices.get(good, 0.0))


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
		"day_count": day_count,
		"god": god.values(),
		"next_god_id": next_god_id,
		"wheat_price": wheat_price,
		"time_speed": time_speed,
		"weather": weather,
		"bread_price": bread_price,
		"market": market,
		"prices": prices,
		"next_building_id": next_building_id,
		"accounts": accounts,
		"buildings": bl,
		"audit": audit,
		"npcs": npcs,
		"blocks": _blocks_to_list(),
		"depleted": depleted,
		"mine_depleted": mine_depleted,
		"terrain": terrain_flat(),
		"item_mult": item_mult,
		"minigame": minigame.to_dict(),
		"race": race.to_dict(),
	}


## حساب‌های قدیمی بدون کیف، مواد اولیه می‌گیرند تا بتوانند فوراً بسازند.
static func _load_friends(v) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v:
			out[str(k)] = clampi(int(v[k]), 0, FWConst.FRIEND_MAX)
	return out


static func _load_npc_day(v) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v:
			out[str(k)] = int(v[k])
	return out


static func _load_tools(v) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for tl in FWConst.TOOL_UPGRADES:
			if bool(v.get(tl, false)):
				out[tl] = true
	return out


static func _load_inv(v) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for item in FWConst.ITEM_ORDER:
			out[item] = clampi(int(v.get(item, 0)), 0, FWConst.ITEM_CAP)
	else:
		out = FWConst.START_ITEMS.duplicate()
	return out


func _blocks_to_list() -> Array:
	var out: Array = []
	for v in blocks:
		var b: Array = blocks[v]
		out.append([v.x, v.y, v.z, str(b[0]), int(b[1]), str(b[2])])
	return out


## داده‌ی بارگذاری‌شده را اعتبارسنجی می‌کند. در صورت خرابی null برمی‌گرداند.
static func from_dict(d: Dictionary):
	for k in ["save_version", "city_id", "seed", "accounts", "buildings", "next_building_id"]:
		if not d.has(k):
			return null
	if typeof(d["accounts"]) != TYPE_DICTIONARY or typeof(d["buildings"]) != TYPE_ARRAY:
		return null
	var cs = load("res://scripts/server/city_state.gd").new(int(d["seed"]), str(d["city_id"]))
	cs.world_time = float(d.get("world_time", 8.0 * 3600.0))
	cs.day_count = int(d.get("day_count", 0))
	cs.next_god_id = maxi(1, int(d.get("next_god_id", 1)))
	var gl = d.get("god", [])
	if gl is Array:
		for g in gl:
			if g is Dictionary and g.has("id") and g.has("kind") and g.has("x") and g.has("z") and cs.god.size() < FWConst.GOD_MAX:
				var gk := str(g["kind"])
				if FWConst.GOD_STATIC.has(gk) or FWConst.GOD_ANIMALS.has(gk):
					var gid := int(g["id"])
					cs.god[gid] = {"id": gid, "kind": gk, "x": float(g["x"]), "z": float(g["z"]), "tx": float(g["x"]), "tz": float(g["z"]), "wait": 1.0}
					cs.next_god_id = maxi(cs.next_god_id, gid + 1)
	cs.minigame.load_dict(d.get("minigame", {}))
	cs.race.load_dict(d.get("race", {}))
	cs.wheat_price = float(d.get("wheat_price", FWConst.WHEAT_BASE_PRICE))
	cs.bread_price = float(d.get("bread_price", FWConst.BREAD_BASE_PRICE))
	var mk = d.get("market", {})
	if mk is Dictionary:
		cs.market = {
			"wheat": float(mk.get("wheat", 0.0)), "flour": float(mk.get("flour", 0.0)), "bread": float(mk.get("bread", 0.0)),
			"egg": float(mk.get("egg", 0.0)), "milk": float(mk.get("milk", 0.0)), "cheese": float(mk.get("cheese", 0.0)),
		}
	var pr = d.get("prices", {})
	if pr is Dictionary:
		cs.prices = {"egg": float(pr.get("egg", 6.0)), "milk": float(pr.get("milk", 14.0)), "flour": float(pr.get("flour", 16.0)), "bread": float(pr.get("bread", cs.bread_price)), "cheese": float(pr.get("cheese", 34.0))}
	# bread_price در ذخیره‌های نسخه‌های قبل منبع حقیقت بود؛ آن را بر قیمت جدید ترجیح می‌دهیم.
	cs.prices["bread"] = cs.bread_price
	var ts := float(d.get("time_speed", 1.0))
	cs.time_speed = ts if FWConst.TIME_SPEEDS.has(ts) else 1.0
	var wt := str(d.get("weather", "clear"))
	cs.weather = wt if FWConst.WEATHERS.has(wt) else "clear"
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
			"job": int(a.get("job", 0)),
			"work_acc": float(a.get("work_acc", 0.0)),
			"energy": clampf(float(a.get("energy", FWConst.ENERGY_MAX)), 0.0, FWConst.ENERGY_MAX),
			"inv": _load_inv(a.get("inv", null)),
			"tools": _load_tools(a.get("tools", null)),
			"friends": _load_friends(a.get("friends", null)),
			"npc_day": _load_npc_day(a.get("npc_day", null)),
		}
	for b in d["buildings"]:
		if not (b.has("id") and b.has("type") and b.has("owner") and b.has("cx") and b.has("cz")):
			return null
		if not FWConst.BUILDING_TYPES.has(str(b["type"])):
			return null
		var nb := {
			"id": int(b["id"]), "type": str(b["type"]), "owner": str(b["owner"]),
			"cx": int(b["cx"]), "cz": int(b["cz"]), "stock": float(b.get("stock", 0.0)),
			"prog": float(b.get("prog", 0.0)),
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
				"bread_day": int(n.get("bread_day", -1)),
				"goods_day": int(n.get("goods_day", -1)),
			})
	var bl = d.get("blocks", [])
	cs.track_nav = false
	if bl is Array:
		for e in bl:
			if e is Array and e.size() >= 6 and FWConst.BLOCK_TYPES.has(str(e[3])):
				cs._add_block(Vector3i(int(e[0]), int(e[1]), int(e[2])), str(e[3]), int(e[4]) if FWConst.meta_valid(int(e[4])) else 0, str(e[5]))
	cs.track_nav = true
	for k in cs.block_cells.keys():
		var kp: PackedStringArray = str(k).split(",")
		cs._refresh_walled(int(kp[0]), int(kp[1]))
	var dp = d.get("depleted", {})
	if dp is Dictionary:
		for k in dp:
			cs.depleted[str(k)] = float(dp[k])
	var mdp = d.get("mine_depleted", {})
	if mdp is Dictionary:
		for k in mdp:
			if str(k).contains(":"):
				cs.mine_depleted[str(k)] = float(mdp[k])
	var tr = d.get("terrain", [])
	if tr is Array:
		var ti := 0
		while ti + 2 < tr.size() and cs.world.edits.size() < FWConst.TERRAIN_MAX_EDITS:
			cs.world.set_edit(int(tr[ti]), int(tr[ti + 1]), int(tr[ti + 2]))
			ti += 3
	var im = d.get("item_mult", {})
	if im is Dictionary:
		for k in im:
			if FWConst.ITEMS.has(str(k)):
				cs.item_mult[str(k)] = clampf(float(im[k]), FWConst.SELL_FLOOR, 1.0)
	for e in d.get("audit", []):
		cs.audit.append(e)
	cs._audit_counter = cs.audit.size()
	return cs
