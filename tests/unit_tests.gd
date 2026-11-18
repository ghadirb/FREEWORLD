extends SceneTree
## اجرا: godot --headless --path . --script res://tests/unit_tests.gd

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const CityState = preload("res://scripts/server/city_state.gd")
const Persistence = preload("res://scripts/server/persistence.gd")

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
