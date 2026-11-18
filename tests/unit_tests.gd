extends SceneTree
## اجرا: godot --headless --path . --script res://tests/unit_tests.gd

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const CityState = preload("res://scripts/server/city_state.gd")
const Persistence = preload("res://scripts/server/persistence.gd")
const WorldSlots = preload("res://scripts/client/world_slots.gd")
const GameView = preload("res://scripts/client/game_view.gd")
const TlsSetup = preload("res://scripts/networking/tls_setup.gd")
const GameClient = preload("res://scripts/networking/game_client.gd")
const Settings = preload("res://scripts/client/settings.gd")

var _fail := 0
var _pass := 0


func check(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("  ok   ", label)
	else:
		_fail += 1
		print("  FAIL ", label)


func _init() -> void:
	test_world()
	test_placement_and_economy()
	test_permissions()
	test_persistence()
	test_npc()
	test_npc_pathfinding()
	test_economy_chain()
	test_jobs()
	test_livestock()
	test_world_tools()
	test_interiors()
	test_world_slots()
	test_npc_label_fade()
	test_tls_pinning()
	print("\nRESULT: %d passed, %d failed" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _login(cs, n: String) -> String:
	return cs.authenticate(n, "")["token"]


func test_world() -> void:
	print("[world]")
	var a := WorldGen.new(777)
	var b := WorldGen.new(777)
	var c := WorldGen.new(778)
	var same := true
	var differs := false
	for i in range(50):
		var x := i * 7.3
		var z := i * 3.1
		if a.height_at(x, z) != b.height_at(x, z):
			same = false
		if a.height_at(x, z) != c.height_at(x, z):
			differs = true
	check(same, "same seed gives identical terrain")
	check(differs, "different seed gives different terrain")
	var half := FWConst.CITY_SIZE * 0.5
	check(a.height_at(half, half) > 1.0, "city center is dry land")
	check(a.biome_at(half, half) != "water", "city center is not water")
	var water_found := false
	for i in range(200):
		if a.biome_at(300 + i * 11.0, 300 + i * 7.0) == "water":
			water_found = true
	check(water_found, "world contains water outside the city")


func test_placement_and_economy() -> void:
	print("[placement & economy]")
	var cs = CityState.new(12345)
	var tok := _login(cs, "alice")
	check(tok != "", "new account gets a token")
	check(cs.money_of("alice") == FWConst.START_MONEY, "starting money")
	var r: Dictionary = cs.place_building("alice", 1, "house", 10, 10)
	check(r["ok"], "place house")
	check(cs.money_of("alice") == FWConst.START_MONEY - 300, "house cost charged")
	var dup: Dictionary = cs.place_building("alice", 1, "house", 20, 20)
	check(not dup["ok"] and cs.money_of("alice") == FWConst.START_MONEY - 300, "duplicate request id is not charged twice")
	var ov: Dictionary = cs.place_building("alice", 2, "house", 11, 11)
	check(not ov["ok"] and ov["error"] == "occupied", "overlap rejected")
	var oob: Dictionary = cs.place_building("alice", 3, "house", 63, 63)
	check(not oob["ok"] and oob["error"] == "out_of_bounds", "out of bounds rejected")
	var bad: Dictionary = cs.place_building("alice", 4, "castle", 5, 5)
	check(not bad["ok"] and bad["error"] == "unknown_type", "unknown type rejected")
	var f: Dictionary = cs.place_building("alice", 5, "farm", 14, 10)
	check(f["ok"], "place farm")
	var fid: int = f["building"]["id"]
	check(not cs.collect("alice", fid)["ok"], "cannot collect before production")
	cs.tick(35.0)
	var col: Dictionary = cs.collect("alice", fid)
	check(col["ok"] and col["count"] == 3, "farm produced 3 wheat in 35s")
	check(col["earned"] > 0 and cs.wheat_price < FWConst.WHEAT_BASE_PRICE, "selling wheat pays and lowers price")
	var poor = CityState.new(12345)
	_login(poor, "bob")
	poor.accounts["bob"]["money"] = 10
	check(poor.place_building("bob", 1, "house", 10, 10)["error"] == "no_money", "insufficient money rejected")


func test_permissions() -> void:
	print("[permissions]")
	var cs = CityState.new(12345)
	_login(cs, "alice")
	_login(cs, "bob")
	cs.provision_admin("root", "secret")
	var plaza: Dictionary = cs.place_building("alice", 1, "road", 31, 31)
	check(not plaza["ok"] and plaza["error"] == "reserved", "player cannot build in plaza")
	check(cs.place_building("root", 1, "road", 31, 31)["ok"], "admin can build in plaza")
	var b: Dictionary = cs.place_building("alice", 2, "house", 10, 10)
	var bid: int = b["building"]["id"]
	check(cs.remove_building("bob", bid)["error"] == "forbidden", "other player cannot remove my building")
	check(cs.collect("bob", bid)["ok"] == false, "other player cannot collect")
	check(not cs.set_role("alice", "bob", "city_admin")["ok"], "player cannot grant roles")
	check(cs.set_role("root", "bob", "city_admin")["ok"], "world admin grants city admin")
	var before: int = cs.audit.size()
	var rm: Dictionary = cs.remove_building("bob", bid)
	check(rm["ok"], "city admin can remove another player's building")
	check(cs.audit.size() == before + 1 and cs.audit[-1]["action"] == "admin_remove", "admin removal is audited")
	check(cs.money_of("alice") == FWConst.START_MONEY - 300 + 150, "owner is refunded 50%")
	var auth_ok: Dictionary = cs.authenticate("alice", "wrong")
	check(not auth_ok["ok"], "wrong token rejected")
	check(cs.authenticate("root", "secret")["ok"], "provisioned admin logs in with secret")
	check(not cs.authenticate("root", "guess")["ok"], "admin name cannot be claimed without secret")


func test_persistence() -> void:
	print("[persistence]")
	var dir := OS.get_user_data_dir().path_join("unit_test_save")
	var path := dir.path_join("city.json")
	DirAccess.make_dir_recursive_absolute(dir)
	for fn in ["city.json", "city.json.bak", "city.json.tmp"]:
		DirAccess.remove_absolute(dir.path_join(fn))
	var cs = CityState.new(4242)
	var tok := _login(cs, "carol")
	cs.place_building("carol", 9, "farm", 12, 12)
	cs.tick(25.0)
	check(Persistence.save_json(path, cs.to_dict()), "save succeeds")
	var cs2 = CityState.from_dict(Persistence.load_json(path))
	check(cs2 != null, "load parses")
	check(cs2.buildings.size() == 1 and cs2.occupied.size() == 9, "buildings and occupancy restored")
	check(cs2.money_of("carol") == FWConst.START_MONEY - 200, "money restored")
	check(cs2.authenticate("carol", tok)["ok"], "token still valid after reload")
	check(cs2.place_building("carol", 9, "house", 30, 5)["error"] == "duplicate", "request memory survives reload")
	check(cs2.place_building("carol", 10, "house", 13, 13)["error"] == "occupied", "occupancy blocks after reload")
	check(Persistence.save_json(path, cs2.to_dict()), "second save creates backup")
	check(FileAccess.file_exists(path + ".bak"), "backup file exists")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ corrupted")
	f.close()
	var rec := Persistence.load_json(path)
	check(rec.has("accounts"), "corrupted save recovered from backup")
	check(CityState.from_dict({"foo": 1}) == null, "invalid data rejected")


func _run_hours(cs, from_hour: float, to_hour: float) -> void:
	cs.world_time = from_hour * 3600.0
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var guard := 0
	while cs.world_time < to_hour * 3600.0 and guard < 200000:
		NpcSim.step(cs, 0.5)
		cs.world_time += 0.5 * FWConst.TIME_SCALE
		guard += 1


func test_npc() -> void:
	print("[npc]")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	check(NpcSim.activity_for_hour(3.0) == "sleep", "schedule: 3am sleep")
	check(NpcSim.activity_for_hour(10.0) == "work", "schedule: 10am work")
	check(NpcSim.activity_for_hour(19.0) == "leisure", "schedule: 7pm leisure")
	var cs = CityState.new(12345)
	_login(cs, "owner")
	cs.accounts["owner"]["money"] = 5000
	for i in range(4):
		check(cs.place_building("owner", 100 + i, "house", 4 + i * 3, 4)["ok"], "house %d placed" % i)
	check(cs.place_building("owner", 200, "farm", 4, 14)["ok"], "farm placed")
	check(cs.place_building("owner", 201, "shop", 20, 14)["ok"], "shop placed")
	NpcSim.ensure_npcs(cs, 4)
	check(cs.npcs.size() == 4, "four npcs created")
	var money_before := cs.money_of("owner")
	_run_hours(cs, 6.0, 12.0)
	var farm = _first_of(cs, "farm")
	var at_work := 0
	for n in cs.npcs:
		var d: Vector2 = cs.door_point(farm)
		if Vector2(n["x"], n["z"]).distance_to(d) < 2.0:
			at_work += 1
	check(at_work >= 1, "an npc is at the farm during work hours")
	check(float(farm["stock"]) > 0.0, "npc work produces wheat without any player")
	_run_hours(cs, 12.0, 21.0)
	check(cs.money_of("owner") > money_before, "npcs pay the shop owner in the evening")
	_run_hours(cs, 21.0, 24.0)
	var asleep := 0
	for n in cs.npcs:
		if n["state"] == "sleep":
			asleep += 1
	check(asleep >= 1, "npcs sleep at night")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.npcs.size() == 4, "npcs survive save/load")
	var walk_ok: bool = cs.is_walkable(9.0, 9.0) == false
	check(walk_ok, "building cells block walking")
	check(cs.is_walkable(100.0, 100.0), "open ground is walkable")
	_login(cs, "spammer")
	cs.accounts["spammer"]["money"] = 100000
	var ok_count := 0
	for i in range(60):
		if cs.place_building("spammer", 1000 + i, "road", 40 + (i % 20), 40 + int(i / 20.0))["ok"]:
			ok_count += 1
	check(ok_count == FWConst.MAX_BUILDINGS_PER_PLAYER, "per-player building limit enforced")


func _first_of(cs, type: String) -> Dictionary:
	for id in cs.buildings:
		if cs.buildings[id]["type"] == type:
			return cs.buildings[id]
	return {}


func test_npc_pathfinding() -> void:
	print("[npc pathfinding]")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(12345)
	_login(cs, "owner")
	cs.accounts["owner"]["money"] = 100000
	cs.accounts["owner"]["role"] = FWConst.ROLE_WORLD_ADMIN
	# دیواری از خانه‌ها (ستون cx=20..21) که مسیر مستقیم را می‌بندد.
	var walls := 0
	for i in range(0, 14):
		if cs.place_building("owner", 500 + i, "house", 20, 2 + i * 2)["ok"]:
			walls += 1
	check(walls >= 8, "wall of houses built (%d)" % walls)
	var from := Vector2(17.0 * FWConst.CELL_SIZE + 1.0, 14.0 * FWConst.CELL_SIZE + 1.0)
	var to := Vector2(25.0 * FWConst.CELL_SIZE + 1.0, 14.0 * FWConst.CELL_SIZE + 1.0)
	check(cs.is_walkable(from.x, from.y) and cs.is_walkable(to.x, to.y), "start and goal are open ground")
	var path = cs.nav.find_path(from, to)
	check(path != null and not path.is_empty(), "a path is found around the wall")
	var straight := from.distance_to(to)
	var plen := 0.0
	var prev := from
	var all_clear := true
	for w in path:
		plen += prev.distance_to(w)
		# هر ۰٫۲۵ واحد از هر پاره‌خط باید قابل عبور باشد.
		var steps := int(ceil(prev.distance_to(w) / 0.25))
		for k in range(1, steps + 1):
			var q := prev.lerp(w, float(k) / float(steps))
			if not cs.is_walkable(q.x, q.y):
				all_clear = false
		prev = w
	check(all_clear, "path never crosses a building")
	check(plen > straight * 1.05, "path is a real detour (%.1f vs straight %.1f)" % [plen, straight])
	# شبیه‌سازی حرکت واقعی NPC تا مقصد.
	var npc := {"id": 1, "x": from.x, "z": from.y}
	var reached := false
	var crossed := false
	for i in range(4000):
		var mv: Dictionary = NpcSim._advance(cs, npc, Vector2(npc["x"], npc["z"]), to, 0.2)
		npc["x"] = mv["p"].x
		npc["z"] = mv["p"].y
		if not cs.is_walkable(npc["x"], npc["z"]):
			crossed = true
		if mv["arrived"] or Vector2(npc["x"], npc["z"]).distance_to(to) <= 1.0:
			reached = true
			break
	check(reached, "npc walks all the way to the goal")
	check(not crossed, "npc never steps inside a building while walking")
	# حذف یک ساختمان دیوار ← مسیر باید دوباره حساب شود و کوتاه‌تر شود.
	var ver_before: int = cs.nav_version
	for id in cs.buildings.keys():
		var b: Dictionary = cs.buildings[id]
		if b["cz"] <= 14 and b["cz"] + 2 > 14:
			cs.remove_building("owner", id)
	check(cs.nav_version > ver_before, "building changes invalidate the nav grid")
	var path2 = cs.nav.find_path(from, to)
	var plen2 := 0.0
	prev = from
	for w in path2:
		plen2 += prev.distance_to(w)
		prev = w
	check(plen2 < plen, "path shortens after a gap is opened (%.1f < %.1f)" % [plen2, plen])
	# وقتی مبدأ و مقصد در یک سلول باشند مسیر بی‌اهمیت است.
	var cs2 = CityState.new(12345)
	var far = cs2.nav.find_path(Vector2(100.0, 100.0), Vector2(100.0, 100.0))
	check(far != null and far.size() <= 1, "same-cell goal gives a trivial path (just the exact goal)")


func _tick_for(cs, seconds: float, step: float = 0.5) -> void:
	var t := 0.0
	while t < seconds:
		cs.tick(step)
		t += step


func test_economy_chain() -> void:
	print("[economy chain: wheat -> market -> bread -> npc]")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(12345)
	_login(cs, "farmer")
	_login(cs, "baker")
	_login(cs, "shopper")
	for n in ["farmer", "baker", "shopper"]:
		cs.accounts[n]["money"] = 5000
	check(cs.place_building("farmer", 1, "farm", 4, 14)["ok"], "farm placed")
	var rb: Dictionary = cs.place_building("baker", 2, "bakery", 12, 14)
	check(rb["ok"], "bakery placed (cost %d)" % int(FWConst.BUILDING_TYPES["bakery"]["cost"]))
	check(cs.place_building("shopper", 3, "shop", 20, 14)["ok"], "shop placed")
	check(cs.place_building("shopper", 4, "house", 4, 4)["ok"], "house placed")
	var bakery: Dictionary = _first_of(cs, "bakery")
	var farm: Dictionary = _first_of(cs, "farm")

	# بدون گندم در بازار، نانوایی نان نمی‌پزد.
	_tick_for(cs, 120.0)
	check(int(floor(float(bakery["stock"]))) == 0, "bakery makes no bread while the market has no wheat")
	check(float(cs.market["wheat"]) == 0.0, "market starts empty")

	# کشاورز گندم می‌فروشد ← بازار گندم پیدا می‌کند.
	var wheat_before: int = cs.money_of("farmer")
	var col: Dictionary = cs.collect("farmer", farm["id"])
	check(col["ok"] and col["good"] == "wheat" and col["count"] >= 5, "farmer sells wheat (%d)" % int(col.get("count", 0)))
	check(cs.money_of("farmer") > wheat_before, "farmer earned money")
	var in_market: float = float(cs.market["wheat"])
	check(in_market >= 5.0, "wheat is now in the market (%d)" % int(in_market))

	# نانوایی با خرید گندم از بازار نان می‌پزد و پول گندم از صاحبش کم می‌شود.
	var baker_money: int = cs.money_of("baker")
	var price_at_start: int = int(floor(cs.wheat_price))
	_tick_for(cs, 25.0)
	check(int(floor(float(bakery["stock"]))) >= 1, "bakery baked bread from market wheat")
	check(float(cs.market["wheat"]) <= in_market - 2.0, "baking consumed %d wheat from the market" % FWConst.BREAD_WHEAT_COST)
	check(cs.money_of("baker") <= baker_money - FWConst.BREAD_WHEAT_COST * (price_at_start - 1), "baker paid for the wheat")

	# نانوایی تا سقف موجودی تولید می‌کند و بیشتر نمی‌شود.
	cs.market["wheat"] = 1000.0
	_tick_for(cs, 400.0)
	check(float(bakery["stock"]) <= FWConst.BAKERY_MAX_STOCK, "bakery stock is capped")
	check(float(bakery["stock"]) >= FWConst.BAKERY_MAX_STOCK - 0.01, "bakery fills up when wheat is available")

	# صاحب نانوایی نان را می‌فروشد؛ قیمت نان افت می‌کند و نان به بازار می‌رود.
	var bp_before: float = cs.bread_price
	var money_b: int = cs.money_of("baker")
	var sale: Dictionary = cs.collect("baker", bakery["id"])
	check(sale["ok"] and sale["good"] == "bread", "baker sells bread")
	check(cs.money_of("baker") > money_b and sale["earned"] > 0, "baker earned money from bread")
	check(cs.bread_price < bp_before, "selling bread lowers the bread price")
	check(float(cs.market["bread"]) >= float(sale["count"]), "bread entered the market")
	check(not cs.collect("baker", bakery["id"])["ok"], "nothing left to collect right after selling")

	# فقط صاحب می‌تواند؛ ساختمان غیرتولیدی هم نه.
	check(cs.collect("farmer", bakery["id"])["error"] == "forbidden", "only the owner collects from a bakery")
	var house: Dictionary = _first_of(cs, "house")
	check(cs.collect("shopper", house["id"])["error"] == "not_producer", "a house is not a producer")

	# NPCها در ساعت تفریح نان می‌خرند و پولش به صاحب مغازه می‌رسد.
	NpcSim.ensure_npcs(cs, 4)
	cs.market["bread"] = 20.0
	cs.bread_price = FWConst.BREAD_BASE_PRICE
	var shop_money: int = cs.money_of("shopper")
	_run_hours(cs, 12.0, 21.0)
	var bought: float = 20.0 - float(cs.market["bread"])
	check(bought >= 1.0, "npcs bought bread from the market (%d)" % int(bought))
	check(cs.money_of("shopper") > shop_money + int(bought), "the shop owner got paid for bread (beyond the fixed fee)")
	var bought_day1: float = bought
	_run_hours(cs, 21.0, 23.9)  # همان روز دوباره نمی‌خرند
	check(20.0 - float(cs.market["bread"]) == bought_day1, "each npc buys at most one bread per day")

	# بدون نان در بازار NPC چیزی نمی‌خرد و پولش حفظ می‌شود.
	var cs3 = CityState.new(12345)
	_login(cs3, "s")
	cs3.accounts["s"]["money"] = 5000
	cs3.place_building("s", 1, "shop", 20, 14)
	cs3.place_building("s", 2, "house", 4, 4)
	NpcSim.ensure_npcs(cs3, 2)
	var nm: int = int(cs3.npcs[0]["money"])
	check(not cs3.npc_buy_bread(cs3.npcs[0], _first_of(cs3, "shop")), "npc cannot buy bread when the market has none")
	check(int(cs3.npcs[0]["money"]) == nm, "npc money unchanged on a failed purchase")

	# صاحب نانوایی بدون پول گندم نمی‌تواند نان بپزد.
	var cs4 = CityState.new(12345)
	_login(cs4, "poor")
	cs4.accounts["poor"]["money"] = 600
	check(cs4.place_building("poor", 1, "bakery", 12, 14)["ok"], "poor baker places bakery")
	check(cs4.money_of("poor") == 0, "poor baker has no money left")
	cs4.market["wheat"] = 50.0
	_tick_for(cs4, 100.0)
	check(int(floor(float(_first_of(cs4, "bakery")["stock"]))) == 0, "bakery cannot bake without money for wheat")
	check(float(cs4.market["wheat"]) == 50.0, "market wheat untouched when the owner cannot pay")

	# ذخیره و بازیابی: بازار، قیمت نان و پیشرفت پخت حفظ می‌شود.
	cs.market["bread"] = 7.0
	cs.bread_price = 13.5
	var cs2 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(cs2 != null, "economy state serializes")
	check(float(cs2.market["bread"]) == 7.0 and absf(cs2.bread_price - 13.5) < 0.001, "market and bread price survive save/load")
	check(cs2.buildings.size() == cs.buildings.size(), "buildings survive save/load")
	# ذخیره‌ی قدیمی (بدون بازار) بدون خطا بارگذاری می‌شود.
	var old: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	old.erase("market")
	old.erase("bread_price")
	var cs5 = CityState.from_dict(old)
	check(cs5 != null and float(cs5.market["bread"]) == 0.0 and cs5.bread_price == FWConst.BREAD_BASE_PRICE, "old saves without a market still load")


func test_jobs() -> void:
	print("[jobs and wages]")
	var cs = CityState.new(12345)
	_login(cs, "boss")
	_login(cs, "worker")
	_login(cs, "other")
	cs.accounts["boss"]["money"] = 5000
	check(cs.place_building("boss", 1, "farm", 4, 14)["ok"], "boss farm placed")
	check(cs.place_building("boss", 2, "house", 12, 4)["ok"], "boss house placed")
	check(cs.place_building("other", 3, "bakery", 20, 14)["ok"], "other bakery placed")
	var farm: Dictionary = _first_of(cs, "farm")
	var house: Dictionary = _first_of(cs, "house")
	var bakery: Dictionary = _first_of(cs, "bakery")
	cs.wage_interval = 10.0

	# قوانین استخدام
	check(cs.take_job("boss", farm["id"])["error"] == "own_workplace", "cannot work for yourself")
	check(cs.take_job("worker", house["id"])["error"] == "bad_workplace", "a house offers no work")
	check(cs.take_job("worker", 9999)["error"] == "no_building", "unknown building")
	check(cs.take_job("worker", farm["id"])["ok"] and cs.job_of("worker") == farm["id"], "worker is hired at the farm")
	check(cs.take_job("worker", farm["id"])["error"] == "already_employed", "cannot be hired twice at the same place")

	# حقوق فقط برای کارگر حاضر در محل کار
	var door: Vector2 = cs.door_point(farm)
	var far := Vector2(door.x + 100.0, door.y)
	var worker_money: int = cs.money_of("worker")
	var boss_money: int = cs.money_of("boss")
	for i in range(40):
		cs.work_step(0.5, {"worker": far})
	check(cs.money_of("worker") == worker_money, "no wage while away from the workplace")
	check(cs.money_of("boss") == boss_money, "employer pays nothing for an absent worker")
	var paid := 0
	for i in range(40):
		for ev in cs.work_step(0.5, {"worker": door}):
			paid += int(ev["amount"])
	check(paid == FWConst.WAGE_AMOUNT * 2, "two wages in 20s of presence (%d)" % paid)
	check(cs.money_of("worker") == worker_money + paid, "worker received exactly the wages")
	check(cs.money_of("boss") == boss_money - paid, "wages come out of the employer's money (conserved)")
	check(cs.money_of("worker") + cs.money_of("boss") == worker_money + boss_money, "no money is created")
	# بازیکن آفلاین (در positions نیست) کار نمی‌کند
	var before: int = cs.money_of("worker")
	for i in range(60):
		cs.work_step(0.5, {})
	check(cs.money_of("worker") == before, "offline worker is not paid")

	# حضور کارگر تولید را سریع‌تر می‌کند
	var a = CityState.new(12345)
	var b = CityState.new(12345)
	for c in [a, b]:
		_login(c, "boss")
		_login(c, "worker")
		c.accounts["boss"]["money"] = 5000
		c.place_building("boss", 1, "farm", 4, 14)
	b.take_job("worker", _first_of(b, "farm")["id"])
	for i in range(100):
		a.tick(0.5)
		b.tick(0.5)
		b.work_step(0.5, {"worker": b.door_point(_first_of(b, "farm"))})
	check(float(_first_of(b, "farm")["stock"]) > float(_first_of(a, "farm")["stock"]) * 1.3, "worker speeds up the farm (%.1f vs %.1f)" % [float(_first_of(b, "farm")["stock"]), float(_first_of(a, "farm")["stock"])])

	# کارفرمای بی‌پول: حقوق صفر و رویداد هشدار
	cs.accounts["boss"]["money"] = 5
	var broke := false
	var money_w: int = cs.money_of("worker")
	for i in range(40):
		for ev in cs.work_step(0.5, {"worker": door}):
			if int(ev["amount"]) == 0:
				broke = true
	check(broke, "broke employer produces a warning event")
	check(cs.money_of("worker") == money_w and cs.money_of("boss") == 5, "broke employer pays nothing and keeps their coins")

	# نانوایی هم کار می‌دهد؛ شغل جدید جای قبلی را می‌گیرد
	check(cs.take_job("worker", bakery["id"])["ok"] and cs.job_of("worker") == bakery["id"], "job at the bakery replaces the old one")
	var bk_door: Vector2 = cs.door_point(bakery)
	cs.market["wheat"] = 100.0
	cs.accounts["other"]["money"] = 5000
	bakery["prog"] = 0.0
	cs.work_step(10.0, {"worker": bk_door})
	check(float(bakery["prog"]) >= 4.9, "worker speeds up baking")

	# ترک شغل
	check(cs.quit_job("worker")["ok"] and cs.job_of("worker") == 0, "worker quits")
	check(cs.quit_job("worker")["error"] == "no_job", "quitting twice is an error")

	# حذف ساختمان ← شغل لغو می‌شود
	cs.take_job("worker", farm["id"])
	cs.take_job("other", farm["id"])
	var rm: Dictionary = cs.remove_building("boss", farm["id"])
	check(rm["ok"] and rm["fired"].size() == 2, "removing a workplace fires its workers")
	check(cs.job_of("worker") == 0 and cs.job_of("other") == 0, "fired workers have no job")

	# ذخیره و بازیابی
	cs.take_job("worker", bakery["id"])
	var cs2 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(cs2 != null and cs2.job_of("worker") == bakery["id"], "job survives save/load")
	var old: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	for n in old["accounts"]:
		old["accounts"][n].erase("job")
		old["accounts"][n].erase("work_acc")
	var cs3 = CityState.from_dict(old)
	check(cs3 != null and cs3.job_of("worker") == 0, "old saves without jobs still load")


func test_livestock() -> void:
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(12345)
	_login(cs, "herder")
	_login(cs, "helper")
	cs.accounts["herder"]["money"] = 5000
	var rc: Dictionary = cs.place_building("herder", 1, "coop", 12, 14)
	var rb: Dictionary = cs.place_building("herder", 2, "barn", 20, 14)
	check(rc["ok"] and rb["ok"], "coop and barn can be placed")
	var coop: Dictionary = _first_of(cs, "coop")
	var barn: Dictionary = _first_of(cs, "barn")
	check(not cs.collect("herder", coop["id"])["ok"], "nothing to collect from a fresh coop")
	_tick_for(cs, 60.0)
	check(int(floor(float(coop["stock"]))) >= 3, "coop lays eggs over time")
	check(float(barn["stock"]) >= 2.0, "barn gives milk over time")
	_tick_for(cs, 600.0)
	check(float(coop["stock"]) <= float(FWConst.LIVESTOCK["coop"]["max"]), "coop stock is capped")
	var ep: float = float(cs.prices["egg"])
	var money: int = cs.money_of("herder")
	var sale: Dictionary = cs.collect("herder", coop["id"])
	check(sale["ok"] and sale["good"] == "egg" and sale["earned"] > 0, "owner sells eggs")
	check(cs.money_of("herder") == money + int(sale["earned"]), "money matches earnings")
	check(float(cs.prices["egg"]) < ep, "selling eggs lowers the egg price")
	check(float(cs.prices["egg"]) >= float(FWConst.LIVESTOCK["coop"]["min"]), "egg price has a floor")
	check(float(cs.market["egg"]) >= float(sale["count"]) - 0.01, "eggs entered the market")
	var ms: Dictionary = cs.collect("herder", barn["id"])
	check(ms["ok"] and ms["good"] == "milk", "owner sells milk")
	check(cs.collect("helper", coop["id"])["error"] == "forbidden", "only the owner collects")
	var low: float = float(cs.prices["milk"])
	_tick_for(cs, 120.0)
	check(float(cs.prices["milk"]) > low, "milk price recovers")
	check(float(cs.prices["milk"]) <= float(FWConst.LIVESTOCK["barn"]["base"]), "milk price never exceeds base")

	# مشاغل: کارگر کنار مرغداری تولید را سریع‌تر می‌کند.
	check(cs.take_job("helper", coop["id"])["ok"], "can take a job at a coop")
	coop["stock"] = 0.0
	cs.work_step(10.0, {"helper": cs.door_point(coop)})
	check(float(coop["stock"]) > 0.3, "worker speeds up the coop")

	# NPCها تخم‌مرغ و شیر می‌خرند؛ روزی حداکثر یک کالا.
	var cs2 = CityState.new(12345)
	_login(cs2, "shopper")
	cs2.accounts["shopper"]["money"] = 5000
	cs2.place_building("shopper", 1, "shop", 20, 14)
	NpcSim.ensure_npcs(cs2, 4)
	cs2.market["egg"] = 20.0
	cs2.market["milk"] = 20.0
	var before: float = 40.0
	_run_hours(cs2, 12.0, 21.0)
	var bought: float = before - float(cs2.market["egg"]) - float(cs2.market["milk"])
	check(bought >= 1.0, "npcs bought eggs or milk (%d)" % int(bought))
	check(bought <= 4.0, "each npc buys at most one egg/milk per day")

	# ذخیره و بارگذاری قیمت‌ها و موجودی بازار دامی را حفظ می‌کند.
	cs.prices["egg"] = 3.5
	cs.market["milk"] = 7.0
	var cs3 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(cs3 != null and absf(float(cs3.prices["egg"]) - 3.5) < 0.001, "egg price survives save/load")
	check(cs3 != null and absf(float(cs3.market["milk"]) - 7.0) < 0.001, "milk stock survives save/load")
	check(cs3 != null and _first_of(cs3, "barn").size() > 0, "barn survives save/load")
	var pub: Dictionary = cs.market_public()
	check(pub.has("egg_price") and pub.has("milk") and pub.has("egg"), "market_public exposes livestock goods")


func test_world_tools() -> void:
	var cs = CityState.new(12345)
	_login(cs, "plain")
	_login(cs, "mayor")
	cs.accounts["mayor"]["role"] = FWConst.ROLE_CITY_ADMIN
	check(cs.set_world("plain", "weather", "rain")["error"] == "forbidden", "ordinary player cannot change the weather")
	check(cs.set_world("plain", "time_speed", 4.0)["error"] == "forbidden", "ordinary player cannot change time speed")
	check(cs.weather == "clear" and cs.time_speed == 1.0, "forbidden changes leave the world untouched")
	check(cs.set_world("mayor", "weather", "snow")["error"] == "bad_request", "unknown weather is rejected")
	check(cs.set_world("mayor", "time_speed", 999.0)["error"] == "bad_request", "unlisted time speed is rejected")
	check(cs.set_world("mayor", "nonsense", 1)["error"] == "bad_request", "unknown setting is rejected")
	check(cs.set_world("mayor", "weather", "rain")["ok"] and cs.weather == "rain", "admin sets rain")
	var t0: float = cs.world_time
	cs.tick(1.0)
	var normal: float = cs.world_time - t0
	check(cs.set_world("mayor", "time_speed", 10.0)["ok"], "admin speeds up time")
	t0 = cs.world_time
	cs.tick(1.0)
	check(absf((cs.world_time - t0) - normal * 10.0) < 0.01, "time runs 10x faster")
	check(cs.set_world("mayor", "time_speed", 0.0)["ok"], "admin pauses time")
	t0 = cs.world_time
	cs.tick(5.0)
	check(cs.world_time == t0, "paused time does not advance")
	var logged := false
	for e in cs.audit:
		if e["action"] == "set_world" and e["actor"] == "mayor":
			logged = true
	check(logged, "world changes are written to the audit log")
	var cs2 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(cs2 != null and cs2.weather == "rain" and cs2.time_speed == 0.0, "weather and time speed survive save/load")
	var old: Dictionary = cs.to_dict()
	old.erase("weather")
	old.erase("time_speed")
	var cs3 = CityState.from_dict(JSON.parse_string(JSON.stringify(old)))
	check(cs3 != null and cs3.weather == "clear" and cs3.time_speed == 1.0, "old saves default to clear weather, normal speed")


func test_interiors() -> void:
	var cs = CityState.new(12345)
	_login(cs, "owner")
	_login(cs, "guest")
	cs.accounts["owner"]["money"] = 5000
	check(cs.place_building("owner", 1, "house", 12, 14)["ok"], "house placed")
	check(cs.place_building("owner", 2, "shop", 20, 14)["ok"], "shop placed")
	check(cs.place_building("owner", 3, "farm", 28, 14)["ok"], "farm placed")
	var house: Dictionary = _first_of(cs, "house")
	var shop: Dictionary = _first_of(cs, "shop")
	var farm: Dictionary = _first_of(cs, "farm")
	var near_house: Vector2 = cs.door_point(house)
	check(cs.enter_error("owner", house["id"], near_house) == "", "owner can enter own house")
	check(cs.enter_error("guest", house["id"], near_house) == "private_house", "guests cannot enter a private house")
	check(cs.enter_error("guest", shop["id"], cs.door_point(shop)) == "", "anyone can enter a shop")
	check(cs.enter_error("owner", farm["id"], cs.door_point(farm)) == "not_enterable", "a farm cannot be entered")
	check(cs.enter_error("owner", house["id"], near_house + Vector2(100, 0)) == "too_far", "must be near the door")
	check(cs.enter_error("owner", 9999, near_house) == "no_building", "unknown building")

	# انرژی: بیرون کم می‌شود، در خانهٔ خود زیاد می‌شود، در مغازه استراحت نمی‌شود.
	var e0: float = float(cs.accounts["owner"]["energy"])
	cs.energy_step(100.0, {"owner": 0})
	check(float(cs.accounts["owner"]["energy"]) < e0, "energy drains outside")
	var low: float = float(cs.accounts["owner"]["energy"])
	cs.energy_step(10.0, {"owner": shop["id"]})
	check(float(cs.accounts["owner"]["energy"]) < low, "no rest in a shop")
	cs.accounts["owner"]["energy"] = 10.0
	cs.energy_step(10.0, {"owner": house["id"]})
	check(float(cs.accounts["owner"]["energy"]) > 30.0, "rest in own house restores energy")
	cs.energy_step(1000.0, {"owner": house["id"]})
	check(float(cs.accounts["owner"]["energy"]) == FWConst.ENERGY_MAX, "energy is capped")
	cs.accounts["guest"]["energy"] = 50.0
	cs.energy_step(10.0, {"guest": house["id"]})
	check(float(cs.accounts["guest"]["energy"]) < 50.0, "no rest in someone else's house")
	cs.accounts["guest"]["energy"] = 0.0
	cs.energy_step(1000.0, {"guest": 0})
	check(float(cs.accounts["guest"]["energy"]) == 0.0, "energy never goes below zero")

	# بدون انرژی کار نمی‌شود (تولید و حقوق متوقف).
	cs.place_building("owner", 4, "farm", 34, 14)
	var farm2: Dictionary = {}
	for id in cs.buildings:
		if cs.buildings[id]["type"] == "farm" and cs.buildings[id]["cx"] == 34:
			farm2 = cs.buildings[id]
	cs.take_job("guest", farm2["id"])
	farm2["stock"] = 0.0
	cs.work_step(10.0, {"guest": cs.door_point(farm2)})
	check(float(farm2["stock"]) == 0.0, "an exhausted worker does not speed production")
	cs.accounts["guest"]["energy"] = 50.0
	cs.work_step(10.0, {"guest": cs.door_point(farm2)})
	check(float(farm2["stock"]) > 0.0, "a rested worker works")
	cs.accounts["owner"]["energy"] = 42.0
	var cs2 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(cs2 != null and absf(float(cs2.accounts["owner"]["energy"]) - 42.0) < 0.001, "energy survives save/load")
	var d: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	d["accounts"]["owner"].erase("energy")
	var cs3 = CityState.from_dict(d)
	check(cs3 != null and float(cs3.accounts["owner"]["energy"]) == FWConst.ENERGY_MAX, "old saves start with full energy")


func test_world_slots() -> void:
	print("-- multiple offline worlds --")
	var worlds: Array = []
	var a: Dictionary = WorldSlots.add_world(worlds, "  جهان اول  ", 111)
	check(a["ok"] and worlds.size() == 1 and worlds[0]["name"] == "جهان اول", "world is added with a trimmed name")
	var b: Dictionary = WorldSlots.add_world(worlds, "Second", 222)
	check(b["ok"] and a["id"] != b["id"], "each world gets its own id")
	check(WorldSlots.data_dir(worlds[0]) != WorldSlots.data_dir(worlds[1]), "each world has its own data folder")
	check(int(WorldSlots.find(worlds, b["id"])["seed"]) == 222, "each world keeps its own seed")
	check(WorldSlots.add_world(worlds, "second", 5)["error"] == "world_name_taken", "duplicate names are refused (case-insensitive)")
	check(WorldSlots.add_world(worlds, "   ", 5)["error"] == "bad_world_name", "empty names are refused")
	check(WorldSlots.clean_name("x".repeat(100)).length() == WorldSlots.NAME_MAX, "long names are cut")
	# ids are never reused after a delete in the middle
	WorldSlots.remove_world(worlds, a["id"])
	var c: Dictionary = WorldSlots.add_world(worlds, "Third", 333)
	check(c["ok"] and c["id"] != b["id"], "ids stay unique after deleting a world")
	check(not WorldSlots.remove_world(worlds, "nope"), "deleting an unknown world is a no-op")
	while worlds.size() < WorldSlots.MAX_WORLDS:
		WorldSlots.add_world(worlds, "w%d" % worlds.size(), 1)
	check(WorldSlots.add_world(worlds, "overflow", 1)["error"] == "too_many_worlds", "world count is limited")
	# فایل‌ها: پاک‌کردن یک جهان به جهان دیگر آسیب نمی‌زند
	var w1 := {"id": "t1", "name": "x", "seed": 1, "dir": "user://test_worlds/t1"}
	var w2 := {"id": "t2", "name": "y", "seed": 2, "dir": "user://test_worlds/t2"}
	Persistence.save_json(WorldSlots.data_dir(w1) + "/city_1.json", {"k": 1})
	Persistence.save_json(WorldSlots.data_dir(w2) + "/city_1.json", {"k": 2})
	WorldSlots.erase_files(w1)
	check(Persistence.load_json(WorldSlots.data_dir(w1) + "/city_1.json").is_empty(), "erased world has no save left")
	check(int(Persistence.load_json(WorldSlots.data_dir(w2) + "/city_1.json").get("k", 0)) == 2, "other worlds are untouched")
	WorldSlots.erase_files(w2)
	DirAccess.remove_absolute("user://test_worlds")


func test_npc_label_fade() -> void:
	print("-- NPC label fade --")
	check(is_equal_approx(GameView.npc_label_alpha(5.0, 45.0), 1.0), "near NPC name is fully visible")
	check(is_equal_approx(GameView.npc_label_alpha(27.0, 45.0), 1.0), "name stays solid up to 60% of the limit")
	var mid: float = GameView.npc_label_alpha(36.0, 45.0)
	check(mid > 0.1 and mid < 0.9, "name is partly transparent in the fade band")
	check(is_equal_approx(GameView.npc_label_alpha(45.0, 45.0), 0.0), "name is gone at the limit")
	check(GameView.npc_label_alpha(500.0, 45.0) == 0.0, "far NPC name is hidden")


func test_tls_pinning() -> void:
	print("-- network encryption (DTLS, certificate pinning) --")
	Settings.persist = false
	var dir := "user://test_tls"
	var kc1: Dictionary = TlsSetup.load_or_create(dir)
	var kc2: Dictionary = TlsSetup.load_or_create(dir)
	check(not kc1.is_empty() and not kc2.is_empty(), "server certificate is created")
	var pem1: String = TlsSetup.cert_pem(kc1)
	check(pem1 == TlsSetup.cert_pem(kc2) and pem1 != "", "certificate is stored and reused, not regenerated")
	check(TlsSetup.server_options(kc1) != null, "server TLS options are built")
	check(TlsSetup.client_options_for(pem1) != null, "client TLS options are built from the pinned certificate")
	check(TlsSetup.client_options_for("not a certificate") == null, "garbage certificate is rejected")
	check(TlsSetup.fingerprint(pem1) != TlsSetup.fingerprint(pem1 + "x") and TlsSetup.fingerprint(pem1).length() == 64, "fingerprint is a sha256 of the certificate")
	check(TlsSetup.is_cert_request(TlsSetup.build_cert_request()), "full-size certificate request is accepted")
	check(not TlsSetup.is_cert_request(TlsSetup.CERT_MAGIC.to_utf8_buffer()), "short certificate request is ignored (anti-amplification)")
	check(not TlsSetup.is_cert_request(PackedByteArray([1, 2, 3])), "junk packets are ignored")
	# کلاینت: گواهی عوض‌شده رد می‌شود؛ اولین گواهی پین می‌شود
	var c := Node.new()
	c.set_script(GameClient)
	root.add_child(c)
	var errors: Array = []
	c.login_failed.connect(func(e): errors.append(e))
	c._cert_host = "127.0.0.1"
	c._cert_port = 9
	Settings.save_pin("127.0.0.1", 9, "0".repeat(64))
	c._on_cert_received(pem1)
	check(errors == ["cert_changed"], "a changed server certificate is refused")
	check(Settings.pin_for("127.0.0.1", 9) == "0".repeat(64), "a refused certificate does not overwrite the pin")
	Settings.clear_pins()
	check(Settings.pin_for("127.0.0.1", 9) == "", "forgetting certificates clears the pins")
	c._on_cert_received(pem1)
	check(Settings.pin_for("127.0.0.1", 9) == TlsSetup.fingerprint(pem1), "first use pins the certificate")
	c.disconnect_from_server()
	c.queue_free()
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(dir)
	Settings.clear_pins()
