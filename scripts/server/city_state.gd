extends RefCounted
## وضعیت دائمی و مرجع یک شهر: حساب‌ها، ساختمان‌ها، اقتصاد، مجوزها و گزارش اقدامات.
## هیچ وابستگی‌ای به شبکه ندارد تا کاملاً قابل تست باشد.

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const NpcNav = preload("res://scripts/server/npc_nav.gd")
const Minigame = preload("res://scripts/server/minigame.gd")
const Race = preload("res://scripts/server/race.gd")
const Blueprints = preload("res://scripts/server/blueprints.gd")
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
## حالت خلاقانه: ساخت و ابزار رایگان و نامحدود، بدون سکه و بدون افت انرژی. هنگام ساخت جهان تعیین و ذخیره می‌شود.
var creative: bool = false
var undo_stacks: Dictionary = {}  # نام بازیکن -> پشتهٔ واگرد (فقط در حافظه)
## روستاها یک بار حیوان گرفته‌اند (برای جهان‌های قدیمی هم یک بار اجرا می‌شود).
var villages_seeded: bool = false
var day_count: int = 0
var god: Dictionary = {}
var next_god_id: int = 1
var _god_rng := RandomNumberGenerator.new()
var weather: String = "clear"
var disaster: Dictionary = {"kind": "", "t": 0.0}   # حادثهٔ جاری؛ موقت و ذخیره‌نشده
var disaster_cooldown: float = 0.0
var forest_growth: bool = false              # قانون جهان: درخت‌ها خودبه‌خود تکثیر می‌شوند (ذخیره می‌شود)
var fire: Dictionary = {}                    # شناسهٔ درخت در حال سوختن -> ثانیهٔ باقی‌مانده؛ موقت و ذخیره‌نشده
var nfire: Dictionary = {}                   # درخت‌های طبیعیِ در حال سوختن: "rx,rz" -> ثانیهٔ باقی‌مانده (موقت)
var nfire_dirty: bool = false                # سرور بعد از پخش s2c_fire پاکش می‌کند
var burned: Array = []                       # درخت‌های طبیعیِ تازه سوخته؛ سرور برای پخش حذفشان تخلیه می‌کند
var _fire_acc: float = 0.0
var _grow_acc: float = 0.0
var bread_price: float = FWConst.BREAD_BASE_PRICE
## موجودی بازار مشترک شهر: کالایی که کشاورزان فروخته‌اند و هنوز مصرف نشده.
var market: Dictionary = {"wheat": 0.0, "flour": 0.0, "bread": 0.0, "egg": 0.0, "milk": 0.0, "cheese": 0.0}
## قیمت کالاهای دامی (تخم‌مرغ و شیر).
var prices: Dictionary = {"egg": 6.0, "milk": 14.0, "flour": 16.0, "bread": 20.0, "cheese": 34.0}
var npcs: Array = []
var minigame = Minigame.new()
var race = Race.new()
var blueprints = Blueprints.new()
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


## آیا نقطه روی جاده است؟ (ساختمان «جاده» یا بلوک «جاده» روی سطح زمین). سرور و کلاینت هر دو از این استفاده می‌کنند.
func is_road_at(x: float, z: float) -> bool:
	var cx := int(floor(x / FWConst.CELL_SIZE))
	var cz := int(floor(z / FWConst.CELL_SIZE))
	var key := Placement.cell_key(cx, cz)
	if occupied.has(key) and buildings.has(occupied[key]) and str(buildings[occupied[key]]["type"]) == "road":
		return true
	if block_cells.has(key):
		var bx := int(floor(x))
		var bz := int(floor(z))
		var gy: int = maxi(0, int(floor(world.height_at(x, z))))
		for y in [gy - 1, gy]:
			if blocks.has(Vector3i(bx, y, bz)) and str(blocks[Vector3i(bx, y, bz)][0]) == "road":
				return true
	return false


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
	if world.village_solid_at(x, z, 0.3):
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


## پرداخت از حساب بازیکن. در جهان خلاقانه پول بی‌نهایت است: همیشه موفق، و چیزی کم نمی‌شود.
func _can_pay(acc: Dictionary, amount: int) -> bool:
	return creative or int(acc["money"]) >= amount


func _pay(acc: Dictionary, amount: int) -> bool:
	if creative:
		return true
	if int(acc["money"]) < amount:
		return false
	acc["money"] = int(acc["money"]) - amount
	return true


## درآمد بازیکن. در جهان خلاقانه سکه‌ای اضافه نمی‌شود (بازی به سکه وابسته نیست).
func _gain(acc: Dictionary, amount: int) -> void:
	if not creative:
		acc["money"] = int(acc["money"]) + amount


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
	if not creative and not FWConst.is_admin(acc["role"]) and count_owned(player_name) >= FWConst.MAX_BUILDINGS_PER_PLAYER:
		return {"ok": false, "error": "limit"}
	var cost := 0 if creative else int(FWConst.BUILDING_TYPES[type]["cost"])
	if not _pay(acc, cost):
		return {"ok": false, "error": "no_money"}
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
		_gain(accounts[owner_name], refund)
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
	_gain(accounts[player_name], earned)
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
		if accounts.has(employer) and _pay(accounts[employer], FWConst.WAGE_AMOUNT):
			_gain(acc, FWConst.WAGE_AMOUNT)
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
		if creative:
			acc["energy"] = FWConst.ENERGY_MAX
			continue
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
		"forest_growth":
			forest_growth = bool(value)
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
	return {"time_speed": time_speed, "weather": weather, "creative": creative, "forest_growth": forest_growth}


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
	if world.village_solid_at(float(x) + 0.5, float(z) + 0.5, 1.0):
		return "near_village"
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


func place_block(player_name: String, req_id: int, x: int, y: int, z: int, type: String, color: int, record: bool = true) -> Dictionary:
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
	if not creative and not FWConst.is_admin(acc["role"]) and int(block_owner_count.get(player_name, 0)) >= FWConst.MAX_BLOCKS_PER_PLAYER:
		return {"ok": false, "error": "limit"}
	var cost: Dictionary = {} if creative else FWConst.BLOCK_TYPES[type]["cost"]
	if not has_items(acc["inv"], cost):
		return {"ok": false, "error": "no_items"}
	for item in cost:
		acc["inv"][item] = int(acc["inv"][item]) - int(cost[item])
	_add_block(Vector3i(x, y, z), type, color, player_name)
	if record:
		push_undo(player_name, [Vector3i(x, y, z)], [])
	return {"ok": true, "type": type, "color": color}


func remove_block(player_name: String, x: int, y: int, z: int, record: bool = true) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var v := Vector3i(x, y, z)
	if not blocks.has(v):
		return {"ok": false, "error": "no_block"}
	var b: Array = blocks[v]
	var owner_name: String = str(b[2])
	if owner_name != player_name and not FWConst.is_admin(role_of(player_name)):
		return {"ok": false, "error": "forbidden"}
	var cost: Dictionary = {} if creative else FWConst.BLOCK_TYPES[str(b[0])]["cost"]
	if accounts.has(owner_name):
		for item in cost:
			_inv_add(accounts[owner_name], str(item), int(cost[item]))
	if owner_name != player_name:
		_log(player_name, "admin_remove_block", {"owner": owner_name, "type": str(b[0]), "x": x, "y": y, "z": z})
	if record:
		push_undo(player_name, [], [[v, str(b[0]), int(b[1]), owner_name]])
	_del_block(v)
	return {"ok": true, "owner": owner_name}



# ---------------- عملیات دسته‌ای و واگرد (پروتکل ۲۰) ----------------

## خانه‌های یک جعبه (دو گوشهٔ دلخواه). اگر از سقف ابعاد/حجم بزرگ‌تر باشد آرایهٔ خالی برمی‌گرداند.
## hollow: فقط پوستهٔ بیرونی (دیوار/کف/سقف).
static func region_cells(a: Vector3i, b: Vector3i, hollow: bool = false) -> Array:
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	var hi := Vector3i(maxi(a.x, b.x), maxi(a.y, b.y), maxi(a.z, b.z))
	var size := hi - lo + Vector3i.ONE
	if size.x > FWConst.REGION_MAX_SIDE or size.y > FWConst.REGION_MAX_SIDE or size.z > FWConst.REGION_MAX_SIDE:
		return []
	if size.x * size.y * size.z > FWConst.REGION_MAX_VOLUME:
		return []
	var out: Array = []
	for y in range(lo.y, hi.y + 1):
		for z in range(lo.z, hi.z + 1):
			for x in range(lo.x, hi.x + 1):
				if hollow and x > lo.x and x < hi.x and y > lo.y and y < hi.y and z > lo.z and z < hi.z:
					continue
				out.append(Vector3i(x, y, z))
	return out


func push_undo(player_name: String, added: Array, removed: Array) -> void:
	if added.is_empty() and removed.is_empty():
		return
	var st: Array = undo_stacks.get(player_name, [])
	st.append({"add": added, "del": removed})
	while st.size() > FWConst.UNDO_DEPTH:
		st.pop_front()
	undo_stacks[player_name] = st


func undo_depth(player_name: String) -> int:
	return (undo_stacks.get(player_name, []) as Array).size()


## entries: [[Vector3i, type, color], ...]. پایین‌ترین لایه اول چیده می‌شود تا تکیه‌گاه لایهٔ بالا باشد.
## can_place(v) -> bool اختیاری است (مثلاً بازیکنی روی آن خانه نایستاده باشد).
func batch_place(player_name: String, entries: Array, can_place: Callable = Callable()) -> Dictionary:
	var out := {"changed": [], "placed": 0, "removed": 0, "skipped": 0, "error": ""}
	if not accounts.has(player_name):
		out["error"] = "no_account"
		return out
	var sorted := entries.duplicate()
	sorted.sort_custom(func(p, q): return (p[0] as Vector3i).y < (q[0] as Vector3i).y)
	var added: Array = []
	for e in sorted:
		var v: Vector3i = e[0]
		if can_place.is_valid() and not can_place.call(v):
			out["skipped"] += 1
			continue
		var res := place_block(player_name, 0, v.x, v.y, v.z, str(e[1]), int(e[2]), false)
		if res["ok"]:
			added.append(v)
			out["changed"].append([v, FWConst.BLOCK_ORDER.find(str(e[1])), int(e[2])])
		else:
			out["skipped"] += 1
			out["error"] = str(res["error"])
	out["placed"] = added.size()
	push_undo(player_name, added, [])
	return out


func batch_remove(player_name: String, cells: Array) -> Dictionary:
	var out := {"changed": [], "placed": 0, "removed": 0, "skipped": 0, "error": "", "owners": {}}
	if not accounts.has(player_name):
		out["error"] = "no_account"
		return out
	var removed: Array = []
	for v in cells:
		if not blocks.has(v):
			continue
		var b: Array = blocks[v]
		var rec := [v, str(b[0]), int(b[1]), str(b[2])]
		var res := remove_block(player_name, v.x, v.y, v.z, false)
		if res["ok"]:
			removed.append(rec)
			out["changed"].append([v, -1, 0])
			out["owners"][str(res["owner"])] = true
		else:
			out["skipped"] += 1
			out["error"] = str(res["error"])
	out["removed"] = removed.size()
	push_undo(player_name, [], removed)
	return out


## آخرین عمل بازیکن را برمی‌گرداند. بلوک‌هایی که دیگر مال او نیستند یا جایشان پر شده دست نمی‌خورند.
func undo_last(player_name: String, can_place: Callable = Callable()) -> Dictionary:
	var out := {"changed": [], "placed": 0, "removed": 0, "skipped": 0, "error": "", "owners": {}}
	var st: Array = undo_stacks.get(player_name, [])
	if st.is_empty() or not accounts.has(player_name):
		out["error"] = "nothing_to_undo"
		return out
	var rec: Dictionary = st.pop_back()
	undo_stacks[player_name] = st
	for v in rec["add"]:
		if blocks.has(v) and str(blocks[v][2]) == player_name:
			var res := remove_block(player_name, v.x, v.y, v.z, false)
			if res["ok"]:
				out["removed"] += 1
				out["changed"].append([v, -1, 0])
				continue
		out["skipped"] += 1
	var dels: Array = (rec["del"] as Array).duplicate()
	dels.sort_custom(func(p, q): return (p[0] as Vector3i).y < (q[0] as Vector3i).y)
	for d in dels:
		var v: Vector3i = d[0]
		if str(d[3]) != player_name or (can_place.is_valid() and not can_place.call(v)):
			out["skipped"] += 1
			continue
		var res := place_block(player_name, 0, v.x, v.y, v.z, str(d[1]), int(d[2]), false)
		if res["ok"]:
			out["placed"] += 1
			out["changed"].append([v, FWConst.BLOCK_ORDER.find(str(d[1])), int(d[2])])
		else:
			out["skipped"] += 1
	return out


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
	if creative:
		return 2
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


## یک بار برای هر جهان: چند گوسفند و خرگوش پرسه‌زن کنار چاه هر روستا (قطعی از Seed، قابل حذف توسط مدیر).
func seed_village_life() -> int:
	if villages_seeded:
		return 0
	villages_seeded = true
	var added := 0
	for v in world.villages():
		for i in range(FWConst.VILLAGE_ANIMALS.size()):
			if god.size() >= FWConst.GOD_MAX:
				return added
			var a: float = float(i) * 2.1 + float(absi(hash(str(v["id"]))) % 628) / 100.0
			var x: float = float(v["x"]) + cos(a) * 3.5
			var z: float = float(v["z"]) + sin(a) * 3.5
			if not _god_spot_ok(x, z):
				continue
			var id := next_god_id
			next_god_id += 1
			god[id] = {"id": id, "kind": FWConst.VILLAGE_ANIMALS[i], "x": x, "z": z, "tx": x, "tz": z, "wait": 1.0}
			added += 1
	return added


func _in_world(x: float, z: float) -> bool:
	var half := FWConst.CITY_SIZE * 0.5
	return is_finite(x) and is_finite(z) and absf(x - half) <= FWConst.WORLD_LIMIT and absf(z - half) <= FWConst.WORLD_LIMIT


## یک درخت تازه نزدیک (x, z) می‌کارد؛ true اگر جای مناسب پیدا شد.
func _spawn_tree_near(x: float, z: float, min_r: float, max_r: float) -> bool:
	if god.size() >= FWConst.GOD_MAX:
		return false
	for _try in range(5):
		var a := _god_rng.randf() * TAU
		var r := min_r + _god_rng.randf() * (max_r - min_r)
		var tx := x + cos(a) * r
		var tz := z + sin(a) * r
		if not _in_world(tx, tz) or not _god_spot_ok(tx, tz):
			continue
		var crowded := false
		for gid in god:
			if Vector2(float(god[gid]["x"]), float(god[gid]["z"])).distance_to(Vector2(tx, tz)) < 1.2:
				crowded = true
				break
		if crowded:
			continue
		var id := next_god_id
		next_god_id += 1
		god[id] = {"id": id, "kind": "tree", "x": tx, "z": tz, "tx": tx, "tz": tz, "wait": 1.0}
		return true
	return false


## قدرت «آتش»: نزدیک‌ترین درخت (کاشته‌شده یا طبیعی، تا FIRE_IGNITE_RANGE) را آتش می‌زند. فقط مدیران.
func ignite(actor: String, x: float, z: float) -> Dictionary:
	if not FWConst.is_admin(role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	if not _in_world(x, z):
		return {"ok": false, "error": "bad_request"}
	var best := -1
	var best_d := FWConst.FIRE_IGNITE_RANGE
	for id in god:
		if str(god[id]["kind"]) != "tree" or fire.has(id):
			continue
		var d := Vector2(float(god[id]["x"]), float(god[id]["z"])).distance_to(Vector2(x, z))
		if d <= best_d:
			best_d = d
			best = id
	var nbest := ""
	var nbest_d := best_d
	var rxc := int(floor(x / FWConst.RESOURCE_CELL))
	var rzc := int(floor(z / FWConst.RESOURCE_CELL))
	for rx in range(rxc - 2, rxc + 3):
		for rz in range(rzc - 2, rzc + 3):
			var key := "%d,%d" % [rx, rz]
			if depleted.has(key) or nfire.has(key):
				continue
			var n: Dictionary = world.resource_in_cell(rx, rz)
			if n.is_empty() or str(n["kind"]) != "tree":
				continue
			var nd := Vector2(float(n["x"]), float(n["z"])).distance_to(Vector2(x, z))
			if nd <= nbest_d:
				nbest_d = nd
				nbest = key
	if nbest != "" and nfire.size() < FWConst.NFIRE_MAX:
		nfire[nbest] = FWConst.FIRE_BURN_SECONDS
		nfire_dirty = true
		_log(actor, "fire", {"natural": nbest})
		return {"ok": true, "natural": nbest}
	if best < 0:
		return {"ok": false, "error": "no_target"}
	fire[best] = FWConst.FIRE_BURN_SECONDS
	_log(actor, "fire", {"id": best})
	return {"ok": true, "id": best}


## قدرت «جنگل»: تا GROVE_SIZE درخت دور نقطه می‌کارد. فقط مدیران.
func plant_grove(actor: String, x: float, z: float) -> Dictionary:
	if not FWConst.is_admin(role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	if not _in_world(x, z):
		return {"ok": false, "error": "bad_request"}
	if god.size() >= FWConst.GOD_MAX:
		return {"ok": false, "error": "god_full"}
	var planted := 0
	for _i in range(FWConst.GROVE_SIZE * 2):
		if planted >= FWConst.GROVE_SIZE:
			break
		if _spawn_tree_near(x, z, 0.0, 6.0):
			planted += 1
	if planted == 0:
		return {"ok": false, "error": "bad_place"}
	_log(actor, "grove", {"n": planted})
	return {"ok": true, "planted": planted}


## گام آتش‌سوزی؛ true اگر مجموعهٔ درخت‌های کاشته‌شده یا در حال سوختن‌شان تغییر کرد (god_public باید پخش شود).
## درخت‌های طبیعی در nfire می‌سوزند و با پایان آتش مثل درخت قطع‌شده ناپدید می‌شوند (depleted) و بعد از FIRE_REGROW ثانیه
## دوباره می‌رویند؛ تغییرشان با nfire_dirty و burned به سرور اعلام می‌شود.
## آتش به ساختمان، بازیکن و حیوان آسیبی نمی‌رساند. باران سرایت را کم و سوختن را تند می‌کند.
func fire_step(dt: float) -> bool:
	if fire.is_empty() and nfire.is_empty():
		_fire_acc = 0.0
		return false
	var changed := false
	var raining: bool = weather == "rain" or str(disaster["kind"]) == "storm"
	var decay: float = dt * (FWConst.FIRE_RAIN_DECAY if raining else 1.0)
	for id in fire.keys():
		if not god.has(id):
			fire.erase(id)
			changed = true
			continue
		fire[id] = float(fire[id]) - decay
		if float(fire[id]) <= 0.0:
			god.erase(id)
			fire.erase(id)
			changed = true
	for key in nfire.keys():
		if depleted.has(key):   # در حین سوختن قطع شد
			nfire.erase(key)
			nfire_dirty = true
			continue
		nfire[key] = float(nfire[key]) - decay
		if float(nfire[key]) <= 0.0:
			nfire.erase(key)
			depleted[key] = FWConst.FIRE_REGROW
			burned.append(key)
			nfire_dirty = true
	_fire_acc += dt
	while _fire_acc >= 1.0:
		_fire_acc -= 1.0
		var chance: float = FWConst.FIRE_SPREAD_CHANCE * (FWConst.FIRE_RAIN_SPREAD if raining else 1.0)
		var sources: Array = []
		for id in fire:
			sources.append(Vector2(float(god[id]["x"]), float(god[id]["z"])))
		for key in nfire:
			var parts: PackedStringArray = str(key).split(",")
			var nn: Dictionary = world.resource_in_cell(int(parts[0]), int(parts[1]))
			if not nn.is_empty():
				sources.append(Vector2(float(nn["x"]), float(nn["z"])))
		var new_god: Array = []
		var new_nat: Array = []
		for gp in sources:
			for oid in god:
				if fire.has(oid) or new_god.has(oid) or str(god[oid]["kind"]) != "tree":
					continue
				if gp.distance_to(Vector2(float(god[oid]["x"]), float(god[oid]["z"]))) <= FWConst.FIRE_SPREAD_RANGE and _god_rng.randf() < chance:
					new_god.append(oid)
			var rxc := int(floor(gp.x / FWConst.RESOURCE_CELL))
			var rzc := int(floor(gp.y / FWConst.RESOURCE_CELL))
			var reach := int(ceil(FWConst.FIRE_SPREAD_RANGE / FWConst.RESOURCE_CELL)) + 1
			for rx in range(rxc - reach, rxc + reach + 1):
				for rz in range(rzc - reach, rzc + reach + 1):
					var nk := "%d,%d" % [rx, rz]
					if depleted.has(nk) or nfire.has(nk) or new_nat.has(nk):
						continue
					var cand: Dictionary = world.resource_in_cell(rx, rz)
					if cand.is_empty() or str(cand["kind"]) != "tree":
						continue
					if gp.distance_to(Vector2(float(cand["x"]), float(cand["z"]))) <= FWConst.FIRE_SPREAD_RANGE and _god_rng.randf() < chance:
						new_nat.append(nk)
		for oid in new_god:
			fire[oid] = FWConst.FIRE_BURN_SECONDS
			changed = true
		for nk in new_nat:
			if nfire.size() >= FWConst.NFIRE_MAX:
				break
			nfire[nk] = FWConst.FIRE_BURN_SECONDS
			nfire_dirty = true
	return changed


func nfire_flat() -> PackedInt32Array:
	var out := PackedInt32Array()
	for key in nfire:
		var parts: PackedStringArray = str(key).split(",")
		out.append(int(parts[0]))
		out.append(int(parts[1]))
	return out


## قانون «رشد جنگل»: هر GROW_INTERVAL ثانیه هر درخت با احتمالی نزدیک خودش درخت تازه می‌کارد (تا سقف GROW_CAP).
func growth_step(dt: float) -> bool:
	if not forest_growth:
		return false
	_grow_acc += dt
	if _grow_acc < FWConst.GROW_INTERVAL:
		return false
	_grow_acc = 0.0
	var chance: float = FWConst.GROW_CHANCE * (2.0 if weather == "rain" else 1.0)
	var parents: Array = []
	for id in god:
		if str(god[id]["kind"]) == "tree" and not fire.has(id):
			parents.append(id)
	var changed := false
	for id in parents:
		if god.size() >= FWConst.GROW_CAP:
			break
		if _god_rng.randf() >= chance:
			continue
		if _spawn_tree_near(float(god[id]["x"]), float(god[id]["z"]), 2.0, 5.0):
			changed = true
	return changed


func _god_spot_ok(x: float, z: float) -> bool:
	if world.height_at(x, z) < FWConst.GOD_MIN_HEIGHT:
		return false
	if world.village_solid_at(x, z, 0.4):
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
		out.append([int(id), str(g["kind"]), snappedf(float(g["x"]), 0.05), snappedf(float(g["z"]), 0.05), 1 if fire.has(id) else 0])
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
		if creative:
			reward = 0
		else:
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
	var afford := n if creative else int(npc["money"]) / unit
	var count := mini(n, afford)
	if count < 1:
		return {"ok": false, "error": "npc_broke"}
	var total := 0 if creative else unit * count
	npc["money"] = int(npc["money"]) - total
	acc["inv"][item] = int(acc["inv"][item]) - count
	_gain(acc, total)
	_log(player_name, "npc_sell", {"npc": npc_id, "item": item, "n": count, "total": total})
	return {"ok": true, "npc": str(npc["name"]), "item": item, "count": count, "total": total, "money": int(acc["money"])}


## سهمیهٔ باقی‌ماندهٔ فروش روزانهٔ یک NPC برای کالا (روز تازه ← سهمیه از نو).
func _npc_stock_left(npc: Dictionary, item: String) -> int:
	if int(npc.get("stock_day", -1)) != day_count:
		npc["stock_day"] = day_count
		npc["sold"] = {}
	var sold: Dictionary = npc.get("sold", {})
	return FWConst.NPC_STOCK_PER_DAY - int(sold.get(item, 0))


## خرید از NPC نزدیک: قیمت ثابت ارزان‌تر از فروشگاه، با تخفیف دوستی و سهمیهٔ روزانه. پول به NPC می‌رسد.
func npc_buy(player_name: String, npc_id: int, item: String, n: int, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if not FWConst.NPC_SELLS.has(item) or n < 1 or n > FWConst.NPC_TRADE_MAX:
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
	var left := _npc_stock_left(npc, item)
	if left < 1:
		return {"ok": false, "error": "npc_out_of_stock"}
	var acc: Dictionary = accounts[player_name]
	var lv := friend_level(friendship_of(acc, npc_id))
	var unit := FWConst.npc_buy_price(item, lv)
	var count := mini(n, left)
	if not creative:
		count = mini(count, int(acc["money"]) / unit)
	if count < 1:
		return {"ok": false, "error": "no_money"}
	if int(acc["inv"].get(item, 0)) + count > FWConst.ITEM_CAP:
		count = FWConst.ITEM_CAP - int(acc["inv"].get(item, 0))
		if count < 1:
			return {"ok": false, "error": "inv_full"}
	var total := 0 if creative else unit * count
	_pay(acc, total)
	npc["money"] = int(npc["money"]) + total
	acc["inv"][item] = int(acc["inv"].get(item, 0)) + count
	var sold: Dictionary = npc["sold"]
	sold[item] = int(sold.get(item, 0)) + count
	_log(player_name, "npc_buy", {"npc": npc_id, "item": item, "n": count, "total": total})
	return {"ok": true, "npc": str(npc["name"]), "item": item, "count": count, "total": total, "money": int(acc["money"])}


## مبلمان یک خانه (کپی). برای ساختمان بدون مبلمان آرایهٔ خالی.
func furn_of(id: int) -> Array:
	if not buildings.has(id):
		return []
	return (buildings[id].get("furn", []) as Array).duplicate(true)


func _own_house(player_name: String, id: int) -> String:
	if not accounts.has(player_name) or not buildings.has(id):
		return "no_building"
	var b: Dictionary = buildings[id]
	if str(b["type"]) != "house":
		return "not_house"
	if str(b["owner"]) != player_name:
		return "forbidden"
	return ""


## چیدن یک مبلمان در خانهٔ خود. x,z مختصات نسبت به مرکز اتاق؛ rot ۰..۳ (هر واحد ۹۰°).
## سرور به ۰٫۲۵ متر گرد می‌کند، جا (دیوار، هم‌پوشانی، جلوی در) و هزینه را می‌سنجد.
func furn_place(player_name: String, id: int, type: String, x: float, z: float, rot: int) -> Dictionary:
	var err := _own_house(player_name, id)
	if err != "":
		return {"ok": false, "error": err}
	if not FWConst.FURNITURE.has(type) or not (is_finite(x) and is_finite(z)) or rot < 0 or rot > 3:
		return {"ok": false, "error": "bad_request"}
	var b: Dictionary = buildings[id]
	var list: Array = b.get("furn", [])
	if list.size() >= FWConst.FURN_MAX:
		return {"ok": false, "error": "furn_full"}
	var sx := snappedf(x, FWConst.FURN_SNAP)
	var sz := snappedf(z, FWConst.FURN_SNAP)
	var h := FWConst.furn_half(type, rot)
	if absf(sx) + h.x > FWConst.FURN_BOUND or absf(sz) + h.y > FWConst.FURN_BOUND:
		return {"ok": false, "error": "furn_out"}
	var flat: bool = bool(FWConst.FURNITURE[type].get("flat", false))
	for e in list:
		var eh := FWConst.furn_half(str(e["t"]), int(e["r"]))
		var eflat: bool = bool(FWConst.FURNITURE[str(e["t"])].get("flat", false))
		if eflat != flat:
			continue   # فرش زیر مبلمان قرار می‌گیرد
		if absf(sx - float(e["x"])) < h.x + eh.x - 0.001 and absf(sz - float(e["z"])) < h.y + eh.y - 0.001:
			return {"ok": false, "error": "furn_overlap"}
	if not flat and absf(sx) < h.x + 1.0 and sz + h.y > 2.4:
		return {"ok": false, "error": "furn_door"}   # جلوی در باید باز بماند
	var acc: Dictionary = accounts[player_name]
	var cost := 0 if creative else int(FWConst.FURNITURE[type]["cost"])
	if not _pay(acc, cost):
		return {"ok": false, "error": "no_money"}
	list.append({"t": type, "x": sx, "z": sz, "r": rot})
	b["furn"] = list
	_log(player_name, "furn_place", {"id": id, "t": type, "x": sx, "z": sz, "r": rot})
	return {"ok": true, "furn": furn_of(id), "money": int(acc["money"])}


## برداشتن مبلمان شمارهٔ idx از خانهٔ خود؛ نیمی از قیمت برمی‌گردد.
func furn_remove(player_name: String, id: int, idx: int) -> Dictionary:
	var err := _own_house(player_name, id)
	if err != "":
		return {"ok": false, "error": err}
	var b: Dictionary = buildings[id]
	var list: Array = b.get("furn", [])
	if idx < 0 or idx >= list.size():
		return {"ok": false, "error": "bad_request"}
	var t := str(list[idx]["t"])
	list.remove_at(idx)
	b["furn"] = list
	var acc: Dictionary = accounts[player_name]
	var refund := 0 if creative else int(floor(float(FWConst.FURNITURE[t]["cost"]) * FWConst.FURN_REFUND))
	_gain(acc, refund)
	_log(player_name, "furn_remove", {"id": id, "t": t, "refund": refund})
	return {"ok": true, "furn": furn_of(id), "money": int(acc["money"])}


## شروع یک دور مینی‌بازی سکه‌یاب برای بازیکن.
func minigame_start(player_name: String, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if race.is_running(player_name):
		return {"ok": false, "error": "mg_running"}
	return minigame.start(world, seed_value, player_name, pos)


## شروع مسابقهٔ ایستگاه‌ها. هم‌زمان با سکه‌یاب ممکن نیست.
func race_start(player_name: String, pos: Vector2, boat: bool = false, car: bool = false) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if minigame.is_running(player_name):
		return {"ok": false, "error": "mg_running"}
	return race.start(world, seed_value, player_name, pos, boat, car)


## درخواست/پیوستن به مسابقهٔ گروهی هم‌زمان (پروتکل ۲۹).
func race_group(player_name: String, pos: Vector2) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if minigame.is_running(player_name):
		return {"ok": false, "error": "mg_running"}
	return race.group_request(world, seed_value, player_name, pos)


func race_step(dt: float, positions: Dictionary) -> Array:
	var events: Array = race.step(dt, positions, day_count)
	for ev in events:
		if ev["kind"] == "end":
			var nm: String = ev["name"]
			if creative:
				ev["reward"] = 0   # جهان خلاقانه: بدون سکه
			if int(ev["reward"]) > 0 and accounts.has(nm):
				_gain(accounts[nm], int(ev["reward"]))
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
				_gain(accounts[nm], int(ev["reward"]))
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
		_gain(acc, reward)
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
	return Mine.layout_of(seed_value, mine_id)


## خطای ورود به معدن یا رشتهٔ خالی. pos موقعیت بازیکن روی نقشهٔ بیرون است.
func mine_enter_error(player_name: String, mine_id: String, pos: Vector2) -> String:
	if not accounts.has(player_name):
		return "no_account"
	var e: Dictionary = world.mine_entrance(mine_id)
	if e.is_empty():
		return "no_mine"
	var rng := FWConst.HOUSE_ENTER_RANGE if mine_id.begins_with("h") else FWConst.MINE_ENTER_RANGE
	if pos.distance_to(Vector2(float(e["x"]), float(e["z"]))) > rng:
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
	var acc: Dictionary = accounts[player_name]
	if str(node["kind"]) == "bed":
		mine_depleted[key] = FWConst.HOME_REST_COOLDOWN
		acc["energy"] = FWConst.ENERGY_MAX
		return {"ok": true, "rested": true, "idx": idx}
	if str(node["kind"]) == "hchest":
		var hr: int = randi_range(int(FWConst.HOME_CHEST["reward_min"]), int(FWConst.HOME_CHEST["reward_max"]))
		_gain(acc, hr)
		mine_depleted[key] = float(FWConst.HOME_CHEST["respawn"])
		return {"ok": true, "treasure": true, "reward": hr, "money": int(acc["money"]), "idx": idx}
	var def: Dictionary = FWConst.MINE_ORES[str(node["kind"])]
	if def.has("reward_min"):
		var reward: int = int(node["reward"])
		_gain(acc, reward)
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
	if world.village_solid_at(float(v.x) * FWConst.TERRAIN_EDIT_STEP, float(v.y) * FWConst.TERRAIN_EDIT_STEP, 2.5 + float(r) * FWConst.TERRAIN_EDIT_STEP):
		return "near_village"
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
			var want: int = old + sign * int(st[ring])
			# حد بازیکن عادی؛ اگر مدیر جایی را بالاتر/پایین‌تر برده، زمین به‌زور کم یا زیاد نمی‌شود.
			if sign > 0:
				want = mini(want, maxi(FWConst.TERRAIN_MAX_UNITS, old))
			else:
				want = maxi(want, mini(FWConst.TERRAIN_MIN_UNITS, old))
			world.set_edit(ix, iz, want)
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
		if not creative and int(acc["inv"].get(item, 0)) >= FWConst.ITEM_CAP:
			return {"ok": false, "error": "inv_full"}
	else:
		item = "dirt" if inv_count(acc["inv"], "dirt") > 0 else "sand"
		if not creative and inv_count(acc["inv"], item) < 1:
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
	if creative:
		pass  # مادهٔ نامحدود: موجودی دست نمی‌خورد
	elif sign < 0:
		_inv_add(acc, item, n)
	else:
		_inv_add(acc, item, -1)
	return {"ok": true, "item": item, "count": n, "changes": changed, "mode": "dig" if sign < 0 else "fill"}


## ابزار شکل‌دهی زمین برای مدیر: mountain (کوه)، lake (دریاچه)، flatten (صاف کردن به ارتفاع مرکز).
## فقط روی لایهٔ ویرایش زمین عمل می‌کند؛ زمین پایه از Seed دست‌نخورده می‌ماند.
func shape_terrain(actor: String, kind: String, x: float, z: float) -> Dictionary:
	if not FWConst.is_admin(role_of(actor)):
		return {"ok": false, "error": "forbidden"}
	if not FWConst.GOD_SHAPES.has(kind) or not (is_finite(x) and is_finite(z)):
		return {"ok": false, "error": "bad_request"}
	var v := terrain_vertex(x, z)
	var rad := FWConst.SHAPE_RADIUS
	var err := terrain_check(role_of(actor), v, rad)
	if err != "":
		return {"ok": false, "error": err}
	var step := FWConst.TERRAIN_EDIT_STEP
	var center_h: float = world.height_at(float(v.x) * step, float(v.y) * step)
	var plan: Array = []
	var fresh := 0
	for dx in range(-rad, rad + 1):
		for dz in range(-rad, rad + 1):
			var d := sqrt(float(dx * dx + dz * dz))
			if d >= float(rad):
				continue
			var w := 0.5 * (1.0 + cos(PI * d / float(rad)))
			var ix := v.x + dx
			var iz := v.y + dz
			var h: float = world.height_at(float(ix) * step, float(iz) * step)
			var old: int = world.edit_units(ix, iz)
			var nu := old
			match kind:
				"mountain":
					nu = old + int(round(w * float(FWConst.SHAPE_MOUNTAIN_UNITS)))
				"lake":
					if h > FWConst.SHAPE_LAKE_FLOOR:
						nu = old + int(round((FWConst.SHAPE_LAKE_FLOOR - h) * w / FWConst.TERRAIN_UNIT))
				"flatten":
					nu = old + int(round((center_h - h) * w / FWConst.TERRAIN_UNIT))
			nu = clampi(nu, FWConst.TERRAIN_ADMIN_MIN_UNITS, FWConst.TERRAIN_ADMIN_MAX_UNITS)
			if nu != old:
				plan.append([ix, iz, nu])
				if old == 0:
					fresh += 1
	if plan.is_empty():
		return {"ok": false, "error": "terrain_limit"}
	if world.edits.size() + fresh > FWConst.TERRAIN_MAX_EDITS:
		return {"ok": false, "error": "terrain_full"}
	var changed: Array = []
	for e in plan:
		world.set_edit(int(e[0]), int(e[1]), int(e[2]))
		changed.append([int(e[0]), int(e[1]), world.edit_units(int(e[0]), int(e[1]))])
	_log(actor, "terrain_shape", {"kind": kind, "x": snappedf(x, 0.1), "z": snappedf(z, 0.1)})
	return {"ok": true, "changes": changed}


## کندن زمین با بیل: خاک یا شن می‌دهد و زمین را پایین می‌برد؛ زیر ۰ متر آب می‌آید (دریاچه).
func dig(player_name: String, x: float, z: float, tool: String, pos: Vector2) -> Dictionary:
	return _terraform(player_name, x, z, tool, pos, -1)


## پر کردن گودی: یک خاک (یا شن) مصرف می‌کند و زمین را بالا می‌آورد.
func fill(player_name: String, x: float, z: float, tool: String, pos: Vector2) -> Dictionary:
	return _terraform(player_name, x, z, tool, pos, 1)


func has_boat(acc: Dictionary) -> bool:
	return creative or bool(acc.get("boat", false))


func has_horse(acc: Dictionary) -> bool:
	return creative or bool(acc.get("horse", false))


func has_car(acc: Dictionary) -> bool:
	return creative or bool(acc.get("car", false))


## ماهیگیری: r عدد تصادفی [۰،۱) از سرور است (برای قابل‌آزمون بودن از بیرون می‌آید).
func fish(player_name: String, r: float) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	var n := 0 if r < FWConst.FISH_MISS else (1 if r < FWConst.FISH_DOUBLE else 2)
	var acc: Dictionary = accounts[player_name]
	if n > 0:
		if int(acc["inv"].get("fish", 0)) >= FWConst.ITEM_CAP:
			return {"ok": false, "error": "inv_full"}
		_inv_add(acc, "fish", n)
	return {"ok": true, "count": n}


func craft(player_name: String, recipe: String, times: int) -> Dictionary:
	if not accounts.has(player_name):
		return {"ok": false, "error": "no_account"}
	if not FWConst.RECIPES.has(recipe) or times < 1 or times > 50:
		return {"ok": false, "error": "bad_request"}
	var r: Dictionary = FWConst.RECIPES[recipe]
	var acc: Dictionary = accounts[player_name]
	if r.has("unlock"):
		var key: String = str(r["unlock"])
		if times != 1:
			return {"ok": false, "error": "bad_request"}
		if creative or bool(acc.get(key, false)):
			return {"ok": false, "error": "already_owned"}
		if not has_items(acc["inv"], r["in"]):
			return {"ok": false, "error": "no_items"}
		var price: int = int(r.get("money", 0))
		if not _pay(acc, price):
			return {"ok": false, "error": "no_money"}
		for item in r["in"]:
			acc["inv"][item] = int(acc["inv"][item]) - int(r["in"][item])
		acc[key] = true
		_log(player_name, "unlock", {"what": key})
		return {"ok": true, "unlock": key}
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
	if not creative and not has_items(acc["inv"], r["in"], times):
		return {"ok": false, "error": "no_items"}
	if not creative:
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
		total = 0 if creative else buy_price(item) * n
		if not _pay(acc, total):
			return {"ok": false, "error": "no_money"}
		_inv_add(acc, item, n)
		_log(player_name, "buy_item", {"item": item, "n": n, "cost": total})
		return {"ok": true, "buy": true, "item": item, "count": n, "total": total, "money": acc["money"]}
	if int(acc["inv"].get(item, 0)) < n:
		return {"ok": false, "error": "no_items"}
	for i in range(n):
		total += sell_price(item)
		item_mult[item] = maxf(FWConst.SELL_FLOOR, float(item_mult.get(item, 1.0)) - FWConst.SELL_DROP)
	acc["inv"][item] = int(acc["inv"][item]) - n
	_gain(acc, total)
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
	if not _can_pay(buyer, int(o["price"])):
		return {"ok": false, "error": "no_money", "offer": o}
	if int(buyer["inv"].get(o["item"], 0)) + int(o["n"]) > FWConst.ITEM_CAP:
		return {"ok": false, "error": "inv_full", "offer": o}
	seller["inv"][o["item"]] = int(seller["inv"][o["item"]]) - int(o["n"])
	_inv_add(buyer, str(o["item"]), int(o["n"]))
	_pay(buyer, int(o["price"]))
	_gain(seller, int(o["price"]))
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
	if not _pay(accounts[owner_name], cost):
		return
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
	_gain(accounts[owner_name], price)
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
	_gain(accounts[owner_name], price)
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
		"creative": creative,
		"villages_seeded": villages_seeded,
		"weather": weather,
		"forest_growth": forest_growth,
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
		"blueprints": blueprints.to_dict(),
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
## مبلمان ذخیره‌شده را پاک‌سازی می‌کند: نوع ناشناخته، خارج از اتاق یا بیش از سقف دور ریخته می‌شود.
static func _load_furn(v: Variant) -> Array:
	var out: Array = []
	if not (v is Array):
		return out
	for e in v:
		if out.size() >= FWConst.FURN_MAX:
			break
		if not (e is Dictionary) or not FWConst.FURNITURE.has(str(e.get("t", ""))):
			continue
		var r := int(e.get("r", 0)) % 4
		var x := float(e.get("x", 0.0))
		var z := float(e.get("z", 0.0))
		if not (is_finite(x) and is_finite(z)):
			continue
		var h := FWConst.furn_half(str(e["t"]), r)
		if absf(x) + h.x > FWConst.FURN_BOUND + 0.01 or absf(z) + h.y > FWConst.FURN_BOUND + 0.01:
			continue
		out.append({"t": str(e["t"]), "x": x, "z": z, "r": r})
	return out


static func _load_sold(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if v is Dictionary:
		for k in v:
			if FWConst.NPC_SELLS.has(str(k)):
				out[str(k)] = clampi(int(v[k]), 0, FWConst.NPC_STOCK_PER_DAY)
	return out


static func from_dict(d: Dictionary):
	for k in ["save_version", "city_id", "seed", "accounts", "buildings", "next_building_id"]:
		if not d.has(k):
			return null
	if typeof(d["accounts"]) != TYPE_DICTIONARY or typeof(d["buildings"]) != TYPE_ARRAY:
		return null
	var cs = load("res://scripts/server/city_state.gd").new(int(d["seed"]), str(d["city_id"]))
	cs.world_time = float(d.get("world_time", 8.0 * 3600.0))
	cs.day_count = int(d.get("day_count", 0))
	cs.creative = bool(d.get("creative", false))
	cs.villages_seeded = bool(d.get("villages_seeded", false))
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
	cs.blueprints.load_dict(d.get("blueprints", {}))
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
	cs.forest_growth = bool(d.get("forest_growth", false))
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
			"boat": bool(a.get("boat", false)),
			"horse": bool(a.get("horse", false)),
			"car": bool(a.get("car", false)),
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
			"furn": _load_furn(b.get("furn", null)) if str(b["type"]) == "house" else [],
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
				"stock_day": int(n.get("stock_day", -1)),
				"sold": _load_sold(n.get("sold", null)),
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
