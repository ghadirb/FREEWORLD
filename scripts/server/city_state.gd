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
## ابزارهای World Mode: ضریب سرعت گذر زمان و آب‌وهوا (هر دو ذخیره می‌شوند).
var time_speed: float = 1.0
var weather: String = "clear"
var bread_price: float = FWConst.BREAD_BASE_PRICE
## موجودی بازار مشترک شهر: کالایی که کشاورزان فروخته‌اند و هنوز مصرف نشده.
var market: Dictionary = {"wheat": 0.0, "flour": 0.0, "bread": 0.0, "egg": 0.0, "milk": 0.0, "cheese": 0.0}
## قیمت کالاهای دامی (تخم‌مرغ و شیر).
var prices: Dictionary = {"egg": 6.0, "milk": 14.0, "flour": 16.0, "bread": 20.0, "cheese": 34.0}
var npcs: Array = []
## فاصلهٔ پرداخت حقوق (قابل تغییر در تست).
var wage_interval: float = FWConst.WAGE_INTERVAL
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
		"job": 0,
		"work_acc": 0.0,
		"energy": FWConst.ENERGY_MAX,
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
			e -= FWConst.ENERGY_DECAY_PER_SEC * delta
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


func tick(delta: float) -> void:
	world_time = fposmod(world_time + delta * FWConst.TIME_SCALE * time_speed, 86400.0)
	wheat_price = minf(FWConst.WHEAT_BASE_PRICE, wheat_price + FWConst.WHEAT_RECOVER_PER_SEC * delta)
	bread_price = move_toward(bread_price, FWConst.BREAD_BASE_PRICE, FWConst.BREAD_RECOVER_PER_SEC * delta)
	for id in buildings:
		var b: Dictionary = buildings[id]
		match str(b["type"]):
			"farm":
				b["stock"] = minf(FWConst.FARM_MAX_STOCK, float(b["stock"]) + delta / FWConst.FARM_SECONDS_PER_WHEAT)
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
	for e in d.get("audit", []):
		cs.audit.append(e)
	cs._audit_counter = cs.audit.size()
	return cs
