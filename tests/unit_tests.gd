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
const NpcNav = preload("res://scripts/server/npc_nav.gd")
const Mine = preload("res://scripts/shared/mine.gd")
const Boat = preload("res://scripts/shared/boat.gd")
const RailNetwork = preload("res://scripts/shared/rail_network.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")
const ScenarioApply = preload("res://scripts/server/scenario_apply.gd")
const Entitlements = preload("res://scripts/client/entitlements.gd")
const Loc = preload("res://scripts/client/loc.gd")
const Story = preload("res://scripts/shared/story.gd")
const Book = preload("res://scripts/server/book.gd")
const Packs = preload("res://scripts/shared/blueprint_packs.gd")
const Blueprints = preload("res://scripts/server/blueprints.gd")

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
	test_processing_chain()
	test_jobs()
	test_livestock()
	test_world_tools()
	test_interiors()
	test_blocks_and_resources()
	test_exploration()
	test_npc_friendship()
	test_npc_sell()
	test_npc_buy()
	test_furniture()
	test_legends()
	test_minigame()
	test_arenas()
	test_arena_edit()
	test_disasters()
	test_race()
	test_car_race()
	test_trains()
	test_group_race()
	test_boat()
	test_god_tools()
	test_stairs_and_floors()
	test_p2p_trade()
	test_world_slots()
	test_npc_label_fade()
	test_terrain()
	test_mines()
	test_creative()
	test_day_night_and_creative_switch()
	test_clear_resource()
	test_world_rules()
	test_batch_build()
	test_blueprints()
	test_terrain_shapes()
	test_villages()
	test_scenarios()
	test_climates()
	test_story_book()
	test_blueprint_packs()
	test_quests()
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
	var rm: Dictionary = cs.place_building("baker", 2, "mill", 12, 14)
	check(rm["ok"], "mill placed")
	var rb: Dictionary = cs.place_building("baker", 3, "bakery", 16, 14)
	check(rb["ok"], "bakery placed (cost %d)" % int(FWConst.BUILDING_TYPES["bakery"]["cost"]))
	check(cs.place_building("shopper", 4, "shop", 24, 14)["ok"], "shop placed")
	check(cs.place_building("shopper", 5, "house", 4, 4)["ok"], "house placed")
	var bakery: Dictionary = _first_of(cs, "bakery")
	var mill: Dictionary = _first_of(cs, "mill")
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

	# آسیاب با خرید گندم از بازار آرد می‌سازد، سپس نانوایی آرد را مصرف می‌کند.
	var mill_money: int = cs.money_of("baker")
	_tick_for(cs, 20.0)
	check(int(floor(float(mill["stock"]))) >= 1, "mill made flour from market wheat")
	var flour_sale: Dictionary = cs.collect("baker", mill["id"])
	check(flour_sale["ok"] and flour_sale["good"] == "flour" and float(cs.market["flour"]) >= 1.0, "miller sells flour to market")
	check(cs.money_of("baker") > mill_money, "miller has income after selling flour")
	var baker_money: int = cs.money_of("baker")
	_tick_for(cs, 25.0)
	check(int(floor(float(bakery["stock"]))) >= 1, "bakery baked bread from market flour")
	check(float(cs.market["flour"]) <= 0.0, "baking consumed flour from the market")
	check(cs.money_of("baker") < baker_money, "baker paid for the flour")

	# نانوایی تا سقف موجودی تولید می‌کند و بیشتر نمی‌شود.
	cs.market["flour"] = 1000.0
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
	cs4.market["flour"] = 50.0
	_tick_for(cs4, 100.0)
	check(int(floor(float(_first_of(cs4, "bakery")["stock"]))) == 0, "bakery cannot bake without money for wheat")
	check(float(cs4.market["flour"]) == 50.0, "market flour untouched when the owner cannot pay")

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


func test_processing_chain() -> void:
	print("[milk -> cheese processing]")
	var cs = CityState.new(12345)
	_login(cs, "herder")
	_login(cs, "maker")
	cs.accounts["herder"]["money"] = 5000
	cs.accounts["maker"]["money"] = 5000
	check(cs.place_building("herder", 1, "barn", 4, 14)["ok"], "barn placed for cheese chain")
	check(cs.place_building("maker", 2, "dairy", 12, 14)["ok"], "dairy placed")
	var barn: Dictionary = _first_of(cs, "barn")
	var dairy: Dictionary = _first_of(cs, "dairy")
	_tick_for(cs, 55.0)
	var milk: Dictionary = cs.collect("herder", barn["id"])
	check(milk["ok"] and milk["good"] == "milk" and float(cs.market["milk"]) >= 2.0, "milk reaches shared market")
	var before: int = cs.money_of("maker")
	_tick_for(cs, 30.0)
	check(int(floor(float(dairy["stock"]))) >= 1, "dairy made cheese from milk")
	var cheese: Dictionary = cs.collect("maker", dairy["id"])
	check(cheese["ok"] and cheese["good"] == "cheese" and cheese["earned"] > 0, "cheese can be sold for income")
	check(cs.money_of("maker") > before, "cheese maker earns net income")
	var restored = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(restored != null and restored.market.has("cheese") and restored.prices.has("flour"), "new processing market persists")


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


func _land_cell(cs, from_x: int = 50, from_z: int = 50) -> Vector3i:
	## نزدیک‌ترین ستونی که خشکی است و داخل ساختمان/میدان نیست.
	for dx in range(0, 30):
		for dz in range(0, 30):
			var x := from_x + dx
			var z := from_z + dz
			var h: float = cs.world.height_at(x + 0.5, z + 0.5)
			if h >= 0.5 and h < 6.0 and not cs.occupied.has(Placement.cell_key(x >> 1, z >> 1)) and cs.check_block("player", x, maxi(0, int(floor(h))), z, "wood") == "":
				return Vector3i(x, maxi(0, int(floor(h))), z)
	return Vector3i(-999, 0, -999)


func test_blocks_and_resources() -> void:
	print("== blocks, tools, resources, trade ==")
	var cs = CityState.new(777)
	_login(cs, "builder")
	_login(cs, "other")
	cs.provision_admin("boss", "secret-secret-1")
	var inv: Dictionary = cs.accounts["builder"]["inv"]
	check(int(inv["wood"]) == int(FWConst.START_ITEMS["wood"]), "new accounts get starter materials")

	# --- منابع: قطعی و دارای هر سه نوع ---
	var kinds := {}
	var first := {}
	for rx in range(-60, 140):
		for rz in range(-60, 140):
			var n: Dictionary = cs.world.resource_in_cell(rx, rz)
			if not n.is_empty():
				kinds[n["kind"]] = int(kinds.get(n["kind"], 0)) + 1
				if not first.has(n["kind"]):
					first[n["kind"]] = [rx, rz, n]
	check(kinds.has("tree") and kinds.has("rock"), "world has harvestable trees and rocks (%s)" % str(kinds))
	var cs_b = CityState.new(777)
	var again: Dictionary = cs_b.world.resource_in_cell(first["tree"][0], first["tree"][1])
	check(again["x"] == first["tree"][2]["x"] and again["n"] == first["tree"][2]["n"], "resource nodes are deterministic per seed")
	check(cs.world.resource_in_cell(32, 32).is_empty(), "no resource nodes inside the city")

	# --- برداشت ---
	var tn: Array = first["tree"]
	var node: Dictionary = tn[2]
	var at := Vector2(float(node["x"]), float(node["z"]))
	var far := at + Vector2(FWConst.GATHER_RANGE + 2.0, 0)
	check(cs.gather("builder", tn[0], tn[1], "axe", far)["error"] == "too_far", "gather needs to be close")
	check(cs.gather("builder", tn[0], tn[1], "pickaxe", at)["error"] == "wrong_tool", "wrong tool is rejected")
	var wood0: int = int(inv["wood"])
	var g: Dictionary = cs.gather("builder", tn[0], tn[1], "axe", at)
	check(g["ok"] and int(inv["wood"]) == wood0 + int(node["n"]), "axe on a tree gives wood")
	check(cs.gather("builder", tn[0], tn[1], "axe", at)["error"] == "depleted", "a harvested tree is depleted")
	check(cs.depleted_flat().size() == 2, "depleted list is exported")
	_tick_for(cs, float(FWConst.RESOURCES["tree"]["respawn"]) + 1.0, 5.0)
	check(cs.depleted.is_empty() and cs.respawned.size() == 1, "trees grow back after a while")
	check(cs.gather("builder", tn[0], tn[1], "axe", at)["ok"], "a respawned tree can be harvested again")
	var hd: Vector2 = Vector2(60, 60)
	check(cs.dig("builder", 60.0, 60.0, "axe", hd)["error"] == "wrong_tool", "digging needs the shovel")
	check(cs.dig("builder", 60.0, 60.0, "shovel", hd)["error"] == "reserved", "the plaza ground is protected from digging")
	var d: Dictionary = cs.dig("builder", at.x, at.y, "shovel", at)
	check(d["ok"] and d["item"] in ["dirt", "sand"], "shovel digs dirt or sand on open land")

	# --- چیدن بلوک ---
	var cell: Vector3i = _land_cell(cs)
	check(cell.x != -999, "found a free land column for tests")
	var stone0: int = int(inv["stone"])
	check(cs.place_block("builder", 1, cell.x, cell.y, cell.z, "stone", 0)["ok"], "place a stone block on the ground")
	check(int(inv["stone"]) == stone0 - 1, "placing consumes the material")
	check(cs.place_block("builder", 2, cell.x, cell.y, cell.z, "wood", 0)["error"] == "occupied", "cannot place into an occupied cell")
	check(cs.place_block("builder", 3, cell.x + 2, cell.y + 3, cell.z, "wood", 0)["error"] == "unsupported", "floating blocks are rejected")
	check(cs.place_block("builder", 4, cell.x, cell.y + 1, cell.z, "wood", 0)["ok"], "stacking on a block is supported")
	check(cs.place_block("builder", 4, cell.x, cell.y + 2, cell.z, "wood", 0)["error"] == "duplicate", "repeated request id is ignored")
	check(cs.place_block("builder", 5, cell.x, cell.y + 2, cell.z, "wood", 99)["error"] == "bad_request", "bad colour is rejected")
	check(cs.place_block("builder", 6, cell.x + 1, cell.y - 1, cell.z, "wood", 0)["error"] in ["underground", "unsupported"], "no digging below the ground")
	check(cs.check_block("player", -9999, 0, 0, "wood") == "out_of_bounds", "world limits apply to blocks")
	check(cs.check_block("player", 63, 1, 63, "wood") == "reserved", "plaza is reserved for admins")
	check(cs.check_block("world_admin", 63, 1, 63, "wood") != "reserved", "admins may build in the plaza")
	var poor: Dictionary = cs.accounts["other"]["inv"]
	poor["glass"] = 0
	check(cs.place_block("other", 7, cell.x + 1, cell.y, cell.z, "glass", 0)["error"] == "no_items", "no material, no block")

	# --- مالکیت و بازپرداخت ---
	check(cs.remove_block("other", cell.x, cell.y + 1, cell.z)["error"] == "forbidden", "others cannot remove your blocks")
	check(cs.paint_block("other", cell.x, cell.y + 1, cell.z, 3)["error"] == "forbidden", "others cannot paint your blocks")
	check(cs.paint_block("builder", cell.x, cell.y + 1, cell.z, 3)["ok"], "owner can paint")
	var wood1: int = int(inv["wood"])
	check(cs.remove_block("builder", cell.x, cell.y + 1, cell.z)["ok"] and int(inv["wood"]) == wood1 + 1, "removing refunds the material")
	cs.place_block("builder", 8, cell.x, cell.y + 1, cell.z, "wood", 0)
	var wood2: int = int(inv["wood"])
	check(cs.remove_block("boss", cell.x, cell.y + 1, cell.z)["ok"], "admin can remove any block")
	check(int(inv["wood"]) == wood2 + 1, "refund goes to the block's owner")
	check(cs.audit.back()["action"] == "admin_remove_block", "admin removal of others' blocks is audited")

	# --- حرکت: دیوار، در، روی بلوک ایستادن ---
	var w: Vector3i = _land_cell(cs, cell.x + 4, cell.z + 4)
	var wx := float(w.x) + 0.5
	var wz := float(w.z) + 0.5
	var h0: float = cs.world.height_at(wx, wz)
	check(cs.is_walkable(wx, wz), "open ground is walkable")
	cs.place_block("builder", 20, w.x, w.y, w.z, "wood", 0)
	check(cs.is_walkable(wx, wz) and is_equal_approx(cs.ground_height(wx, wz), float(w.y + 1)), "a single block can be stood on")
	cs.place_block("builder", 21, w.x, w.y + 1, w.z, "wood", 0)
	check(not cs.is_walkable(wx, wz), "a two-block wall blocks movement")
	cs.remove_block("builder", w.x, w.y + 1, w.z)
	cs.remove_block("builder", w.x, w.y, w.z)
	cs.place_block("builder", 22, w.x, w.y, w.z, "door", 0)
	cs.place_block("builder", 23, w.x, w.y + 1, w.z, "door", 0)
	check(cs.is_walkable(wx, wz), "a two-high doorway can be walked through")
	cs.place_block("builder", 24, w.x, w.y + 2, w.z, "wood", 0)
	check(cs.is_walkable(wx, wz), "a lintel above a doorway does not block")
	check(is_equal_approx(cs.ground_height(wx, wz), h0), "walking through a door keeps the ground height")

	# --- NPCها: دیوار بلوکی مسیر را می‌بندد ---
	var nv0: int = cs.nav_version
	var nav = NpcNav.new(cs)
	var wc := Vector2i(70 >> 1, 90 >> 1)
	var wl: int = maxi(0, int(floor(cs.world.height_at(70.5, 90.5))))
	var pre: bool = nav._cell_free(wc.x, wc.y)
	cs._add_block(Vector3i(70, wl, 90), "stone", 0, "builder")
	check(nav._cell_free(wc.x, wc.y) == pre, "a single block does not wall off a cell for NPCs")
	cs._add_block(Vector3i(70, wl + 1, 90), "stone", 0, "builder")
	check(cs.nav_version > nv0 and not nav._cell_free(wc.x, wc.y), "a two-high wall closes the cell for NPC paths")
	cs._del_block(Vector3i(70, wl + 1, 90))
	check(nav._cell_free(wc.x, wc.y) == pre, "removing the wall reopens the cell")
	cs._del_block(Vector3i(70, wl, 90))

	# --- ساختمان روی بلوک‌ها ممنوع ---
	var bc := Vector2i(cell.x >> 1, cell.z >> 1)
	check(cs.blocks_in_footprint("road", bc.x, bc.y), "blocks_in_footprint sees blocks under a footprint")
	var res: Dictionary = cs.place_building("builder", 30, "road", bc.x, bc.y)
	check(res.get("error", "") == "blocks_in_way", "a building cannot be put on top of blocks")

	# --- جاده: بلوک جاده سرعت ماشین را بالا می‌برد و NPC مسیر جاده‌دار را ترجیح می‌دهد ---
	var rx := 100.5
	var rz := 90.5
	var rgy: int = maxi(0, int(floor(cs.world.height_at(rx, rz))))
	check(not cs.is_road_at(rx, rz), "no road on bare ground")
	cs._add_block(Vector3i(100, rgy, 90), "stone", 0, "builder")
	check(not cs.is_road_at(rx, rz), "a stone block is not a road")
	cs._del_block(Vector3i(100, rgy, 90))
	cs._add_block(Vector3i(100, rgy, 90), "road", 0, "builder")
	check(cs.is_road_at(rx, rz), "a road block on the ground is a road")
	check(not cs.is_road_at(rx + 4.0, rz), "the neighbouring ground is not a road")
	cs._del_block(Vector3i(100, rgy, 90))
	check(not cs.is_road_at(rx, rz), "removing the road block removes the road")
	cs._add_block(Vector3i(100, rgy, 90), "rail", 0, "builder")
	check(cs.ground_surface_at(rx, rz) == "rail" and not cs.is_road_at(rx, rz), "a rail block is a rail, not a road")
	check(is_equal_approx(cs.car_surface_mult(rx, rz), FWConst.CAR_RAIL_MULT) and FWConst.CAR_RAIL_MULT > FWConst.CAR_ROAD_MULT, "cars are fastest on rails")
	check(FWConst.block_passable("rail") and FWConst.BLOCK_ORDER.find("rail") == FWConst.BLOCK_ORDER.size() - 1, "rail is passable and appended last (old saves keep their ids)")
	cs._del_block(Vector3i(100, rgy, 90))
	check(is_equal_approx(cs.car_surface_mult(rx, rz), 1.0), "bare ground has no bonus")
	check(FWConst.CAR_ROAD_MULT > 1.0 and FWConst.NPC_ROAD_WEIGHT < 1.0, "road constants favour roads")
	var rnav = NpcNav.new(cs)
	rnav._ensure_grid()
	var rc := Vector2i(int(rx / FWConst.CELL_SIZE), int(rz / FWConst.CELL_SIZE))
	check(is_equal_approx(rnav._grid.get_point_weight_scale(rc), 1.0) and not rnav._is_road_cell(rc.x, rc.y), "plain cells cost full for NPC paths")

	# --- اقتصاد: ساخت مواد، فروش، خرید ---
	cs.accounts["builder"]["inv"]["clay"] = 6
	check(cs.craft("builder", "brick", 2)["ok"] and int(cs.accounts["builder"]["inv"]["brick"]) == int(FWConst.START_ITEMS["brick"]) + 4, "clay is fired into bricks")
	check(cs.craft("builder", "glass", 1)["error"] == "no_items", "crafting needs the ingredients")
	var money0: int = cs.money_of("builder")
	var p0: int = cs.sell_price("stone")
	var sold: Dictionary = cs.trade("builder", "stone", 3, false)
	check(sold["ok"] and cs.money_of("builder") == money0 + int(sold["total"]) and int(sold["total"]) > 0, "selling materials earns coins")
	check(cs.sell_price("stone") < p0, "selling lowers the price")
	_tick_for(cs, 120.0, 5.0)
	check(cs.sell_price("stone") == p0, "the price recovers over time")
	check(cs.trade("builder", "stone", 400, false)["error"] == "no_items", "cannot sell more than you own")
	var m1: int = cs.money_of("builder")
	var bought: Dictionary = cs.trade("builder", "wood", 2, true)
	check(bought["ok"] and cs.money_of("builder") == m1 - CityState.buy_price("wood") * 2, "buying costs coins")
	check(CityState.buy_price("wood") > cs.sell_price("wood"), "no buy-and-sell loop for profit")
	cs.accounts["other"]["money"] = 0
	check(cs.trade("other", "wood", 1, true)["error"] == "no_money", "buying needs coins")

	# --- ذخیره و بازیابی ---
	var data: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	var back = CityState.from_dict(data)
	check(back != null and back.blocks.size() == cs.blocks.size(), "blocks survive save and load (%d)" % cs.blocks.size())
	check(str(back.blocks[cell][2]) == "builder", "block owner is saved")
	check(int(back.accounts["builder"]["inv"]["brick"]) == int(cs.accounts["builder"]["inv"]["brick"]), "inventory is saved")
	check(back.block_cells.size() == cs.block_cells.size() and int(back.block_owner_count["builder"]) == int(cs.block_owner_count["builder"]), "block counters are rebuilt")
	cs.gather("builder", tn[0], tn[1], "axe", at)
	var back2 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(back2.depleted.size() == 1, "depleted resources are saved")
	var old: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	old.erase("blocks")
	old.erase("depleted")
	old["accounts"]["builder"].erase("inv")
	var legacy = CityState.from_dict(old)
	check(legacy != null and legacy.blocks.is_empty() and int(legacy.accounts["builder"]["inv"]["wood"]) == int(FWConst.START_ITEMS["wood"]), "old saves load and get starter materials")

	# --- بلوک روی کلاینت (آینه) ---
	var mirror = CityState.new(777)
	for batch in cs.block_batches():
		var i := 0
		while i + 4 < batch.size():
			mirror.apply_block(batch[i], batch[i + 1], batch[i + 2], batch[i + 3], batch[i + 4])
			i += 5
	check(mirror.blocks.size() == cs.blocks.size(), "the client mirror receives every block")
	check(mirror.is_walkable(wx, wz) == cs.is_walkable(wx, wz), "mirror and server agree on walkability")
	mirror.apply_block(cell.x, cell.y, cell.z, -1, 0)
	check(not mirror.blocks.has(cell), "block removal is mirrored")


func test_exploration() -> void:
	var cs = CityState.new(2026)
	_login(cs, "digger")
	var kinds := {}
	var firsts := {}
	for rx in range(-120, 220):
		for rz in range(-120, 220):
			var n: Dictionary = cs.world.resource_in_cell(rx, rz)
			if n.is_empty():
				continue
			kinds[n["kind"]] = int(kinds.get(n["kind"], 0)) + 1
			if not firsts.has(n["kind"]):
				firsts[n["kind"]] = [rx, rz, n]
	check(kinds.has("iron_ore") and kinds.has("chest"), "world has iron ore and treasure chests (%s)" % str(kinds))
	check(int(kinds.get("chest", 0)) < int(kinds.get("tree", 1)) / 10, "treasure is rare")
	var acc: Dictionary = cs.accounts.get("digger", {})
	check(not acc.is_empty(), "test account exists")
	var ch: Array = firsts["chest"]
	var at := Vector2(float(ch[2]["x"]), float(ch[2]["z"]))
	var m0: int = int(acc["money"])
	check(cs.gather("digger", ch[0], ch[1], "axe", at)["error"] == "wrong_tool", "chest needs the bare hand")
	check(cs.gather("digger", ch[0], ch[1], "hand", at + Vector2(FWConst.GATHER_RANGE + 3.0, 0))["error"] == "too_far", "chest needs closeness")
	var r: Dictionary = cs.gather("digger", ch[0], ch[1], "hand", at)
	check(r["ok"] and r["treasure"] and int(acc["money"]) == m0 + int(r["reward"]), "opening a chest pays coins")
	check(int(r["reward"]) >= 60 and int(r["reward"]) <= 240, "chest reward is in range")
	check(cs.gather("digger", ch[0], ch[1], "hand", at)["error"] == "depleted", "an opened chest is empty")
	var cs2 = CityState.new(2026)
	check(cs2.world.resource_in_cell(ch[0], ch[1])["kind"] == "chest", "chests are deterministic per seed")
	var io: Array = firsts["iron_ore"]
	var ip := Vector2(float(io[2]["x"]), float(io[2]["z"]))
	check(cs.gather("digger", io[0], io[1], "axe", ip)["error"] == "wrong_tool", "ore needs the pickaxe")
	var i0: int = int(acc["inv"].get("iron", 0))
	var g: Dictionary = cs.gather("digger", io[0], io[1], "pickaxe", ip)
	check(g["ok"] and g["item"] == "iron" and int(acc["inv"]["iron"]) == i0 + int(io[2]["n"]), "pickaxe on iron ore gives iron")
	cs.sell_price("iron")
	var money1: int = int(acc["money"])
	check(cs.trade("digger", "iron", 1, false)["ok"] and int(acc["money"]) > money1, "iron can be sold at the market")

	# --- ابزار آهنی ---
	var go: Array = firsts["gold_ore"]
	var gp := Vector2(float(go[2]["x"]), float(go[2]["z"]))
	check(cs.gather("digger", go[0], go[1], "pickaxe", gp)["error"] == "needs_better_tool", "gold ore needs an iron pickaxe")
	check(cs.craft("digger", "upgrade_pickaxe", 1)["error"] == "no_items", "upgrade needs iron")
	acc["inv"]["iron"] = 10
	acc["inv"]["wood"] = 10
	check(cs.craft("digger", "upgrade_pickaxe", 1)["ok"] and cs.tool_tier(acc, "pickaxe") == 2, "iron pickaxe is crafted")
	check(int(acc["inv"]["iron"]) == 6 and int(acc["inv"]["wood"]) == 8, "upgrade consumes materials")
	check(cs.craft("digger", "upgrade_pickaxe", 1)["error"] == "already_owned", "a tool is upgraded only once")
	var g2: Dictionary = cs.gather("digger", go[0], go[1], "pickaxe", gp)
	check(g2["ok"] and g2["item"] == "gold" and int(g2["count"]) == int(go[2]["n"]) + 1, "iron pickaxe mines gold with a bonus")
	check(cs.tool_tier(acc, "axe") == 1 and cs.inv_public("digger")["tools"]["pickaxe"] == 2, "tiers are reported per tool")
	var cs3 = CityState.from_dict(cs.to_dict())
	check(cs3 != null and cs3.tool_tier(cs3.accounts["digger"], "pickaxe") == 2, "tool upgrades survive a save/load")


func _mg_land_pos(cs) -> Vector2:
	# نقطه‌ای روی خشکی که برای چیدن سکه‌ها جا دارد
	var c: float = FWConst.CITY_SIZE * 0.5
	return Vector2(c, c)


func _race_run(cs, who: String, order: Array, others: Dictionary = {}) -> Array:
	var evs: Array = []
	for g in order:
		var pos: Dictionary = others.duplicate()
		pos[who] = g
		evs.append_array(cs.race_step(0.2, pos))
	return evs


func _row(x0: int, x1: int, z: int) -> Array:
	var out: Array = []
	for x in range(x0, x1 + 1):
		out.append(Vector2i(x, z))
	return out


func test_trains() -> void:
	print("-- trains")
	# یک خط مستقیم ۶ سلولی: رفت‌وبرگشت، طول ۵ پاره‌خط.
	var lines: Array = RailNetwork.build_lines(_row(0, 5, 0))
	check(lines.size() == 1 and not bool(lines[0]["loop"]) and is_equal_approx(float(lines[0]["length"]), 5.0), "six connected rails make one straight line")
	var p0: Vector3 = RailNetwork.position_on(lines[0], 0.0)
	check(is_equal_approx(p0.x, 0.5) and is_equal_approx(p0.y, 0.5), "the train starts at the first rail centre")
	var p_end: Vector3 = RailNetwork.position_on(lines[0], 5.0)
	check(is_equal_approx(p_end.x, 5.5), "the train reaches the far end after the line length")
	var p_back: Vector3 = RailNetwork.position_on(lines[0], 7.0)
	check(is_equal_approx(p_back.x, 3.5) and absf(absf(p_back.z) - PI / 2.0) < 0.01, "it then turns around and drives back")
	check(is_equal_approx(RailNetwork.position_on(lines[0], 10.0).x, 0.5), "a full round trip returns to the start")
	# جدا بودن دو خط و نادیده گرفتن ریل تک‌افتاده.
	var cells: Array = _row(0, 3, 0) + _row(0, 3, 10) + [Vector2i(50, 50)]
	check(RailNetwork.build_lines(cells).size() == 2, "separate rails make separate lines; a lone rail makes none")
	# حلقهٔ ۴×۴ (۱۲ سلول): حلقه است و پس از یک دور به جای اول برمی‌گردد.
	var ring: Array = []
	for x in range(0, 4):
		ring.append(Vector2i(x, 0))
		ring.append(Vector2i(x, 3))
	for z in range(1, 3):
		ring.append(Vector2i(0, z))
		ring.append(Vector2i(3, z))
	var rl: Array = RailNetwork.build_lines(ring)
	check(rl.size() == 1 and bool(rl[0]["loop"]) and is_equal_approx(float(rl[0]["length"]), 12.0), "a closed ring of 12 rails is a loop")
	var a: Vector3 = RailNetwork.position_on(rl[0], 3.0)
	var b: Vector3 = RailNetwork.position_on(rl[0], 15.0)
	check(is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y), "the loop train comes back after one lap")
	# شاخه: طولانی‌ترین مسیر اصلی انتخاب می‌شود و ساختار قطعی است.
	var tee: Array = _row(0, 6, 0) + [Vector2i(3, 1), Vector2i(3, 2)]
	var tl: Array = RailNetwork.build_lines(tee)
	check(tl.size() == 1 and not bool(tl[0]["loop"]) and is_equal_approx(float(tl[0]["length"]), 6.0), "a branched line uses its longest main path")
	check(RailNetwork.build_lines(tee) == tl, "line building is deterministic")
	# اتصال به CityState: افزودن و حذف ریل، و ساعت قطار.
	var cs = CityState.new(31337)
	check(cs.train_lines().is_empty(), "a city without rails has no trains")
	var y: int = maxi(0, int(floor(cs.world.height_at(100.5, 90.5))))
	for x in range(100, 104):
		cs._add_block(Vector3i(x, y, 90), "rail", 0, "builder")
	check(cs.train_lines().size() == 1, "laying four rail blocks creates a train line")
	cs._add_block(Vector3i(110, y, 95), "stone", 0, "builder")
	check(cs.train_lines().size() == 1, "non-rail blocks do not change the lines")
	cs._del_block(Vector3i(101, y, 90))
	check(cs.train_lines().size() == 1 and float(cs.train_lines()[0]["length"]) == 1.0, "breaking the middle rail leaves a lone rail (ignored) and a two-rail line")
	cs._add_block(Vector3i(101, y, 90), "rail", 0, "builder")
	var poses: Array = cs.train_poses(0.0)
	check(poses.size() == 1 and is_equal_approx(poses[0].x, 100.5), "train_poses gives the locomotive position per line")
	cs.tick(2.0)
	check(is_equal_approx(cs.train_clock, 2.0), "the server train clock advances with ticks")
	check(FWConst.PROTOCOL_VERSION >= 32 and FWConst.TRAIN_SPEED > 0.0, "protocol bumped for the train clock message")


func test_car_race() -> void:
	print("== Car race (protocol 28) ==")
	var cs = CityState.new(4247)
	_login(cs, "driver")
	_login(cs, "walker")
	var at := Vector2.ZERO
	var found := false
	for gx in range(30, 220, 6):
		for gz in range(30, 220, 6):
			var p := Vector2(gx, gz)
			if cs.race.start(cs.world, cs.seed_value, "probe", p, false, true)["ok"]:
				at = p
				found = true
				cs.race.runs.erase("probe")
				break
		if found:
			break
	check(found, "found open land for a car track")
	if not found:
		return
	check(cs.race_start("driver", at, false, true)["ok"] and cs.race.is_car_race("driver") and not cs.race.is_boat_race("driver"), "a car race starts")
	var st: Dictionary = cs.race.public_state("driver")
	check(bool(st["car"]) and st["pts"].size() == FWConst.RACE_GATES and float(st["total"]) == FWConst.CAR_RACE_TIME, "car race state is flagged with its own time limit")
	var gates: Array = []
	for g in st["pts"]:
		gates.append(Vector2(g[0], g[1]))
	for i in range(1, gates.size()):
		check(gates[i].distance_to(gates[i - 1]) > 30.0, "car gates are far apart")
		break
	var m0: int = int(cs.accounts["driver"]["money"])
	var evs: Array = _race_run(cs, "driver", gates, {"walker": at})
	var end_ev: Dictionary = {}
	for ev in evs:
		if ev["kind"] == "end":
			end_ev = ev
	check(not end_ev.is_empty() and end_ev["finished"] and bool(end_ev["car"]), "finishing the car race ends it")
	check(int(end_ev["reward"]) == FWConst.CAR_RACE_REWARD and int(cs.accounts["driver"]["money"]) == m0 + FWConst.CAR_RACE_REWARD, "the car race pays its own reward")
	check(cs.race.best_car.has("driver") and not cs.race.best.has("driver") and not cs.race.best_boat.has("driver"), "the car time goes to its own table")
	check(cs.race.board(false, true)[0][0] == "driver" and cs.race.board().is_empty(), "car and walking boards are separate")
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(back != null and back.race.best_car.has("driver"), "the car record survives save/load")
	cs.creative = true
	var mc: int = int(cs.accounts["driver"]["money"])
	cs.race_start("driver", at, false, true)
	_race_run(cs, "driver", gates, {})
	check(int(cs.accounts["driver"]["money"]) == mc, "creative: a race adds no coins")


func test_group_race() -> void:
	print("== Group race (protocol 29) ==")
	var cs = CityState.new(4248)
	for n in ["ann", "bob", "cy", "dee"]:
		_login(cs, n)
	var at := Vector2(FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5)
	check(cs.race_group("ghost", at)["error"] == "no_account", "unknown player cannot join")
	var r1: Dictionary = cs.race_group("ann", at)
	check(r1["ok"] and r1["opened"] and not cs.race.lobby.is_empty(), "the first request opens a lobby")
	check(cs.race_group("ann", at)["error"] == "grace_already", "no double sign-up")
	check(cs.race_group("bob", at)["ok"] and not cs.race_group("cy", at)["opened"], "others join the open lobby")
	var all := ["ann", "bob", "cy", "dee"]
	check(cs.race.lobby_step(1.0, all).is_empty(), "the lobby waits for the countdown")
	var evs: Array = cs.race.lobby_step(FWConst.GROUP_LOBBY_TIME, all)
	check(evs.size() == 1 and evs[0]["kind"] == "start" and evs[0]["members"].size() == 3, "the race starts with everyone who joined")
	check(cs.race.lobby.is_empty() and cs.race.is_running("ann") and cs.race.is_running("cy") and not cs.race.is_running("dee"), "members run, others do not")
	var st: Dictionary = cs.race.public_state("bob")
	check(bool(st["group"]) and st["pts"] == cs.race.public_state("ann")["pts"], "all racers share one track")
	var gates: Array = []
	for g in st["pts"]:
		gates.append(Vector2(g[0], g[1]))
	# ann رتبهٔ اول، bob دوم، cy هرگز نمی‌رسد
	var m_ann: int = int(cs.accounts["ann"]["money"])
	var m_bob: int = int(cs.accounts["bob"]["money"])
	var far := Vector2(900, 900)
	var done: Array = []
	for g in gates:
		done.append_array(cs.race_step(0.2, {"ann": g, "bob": far, "cy": far, "dee": at}))
	for g in gates:
		done.append_array(cs.race_step(0.2, {"ann": g, "bob": g, "cy": far, "dee": at}))
	var ends := {}
	for ev in done:
		if ev["kind"] == "end":
			ends[ev["name"]] = ev
	check(ends.has("ann") and int(ends["ann"]["rank"]) == 1 and int(ends["ann"]["reward"]) == FWConst.GROUP_REWARDS[0], "first place gets the biggest prize")
	check(ends.has("bob") and int(ends["bob"]["rank"]) == 2 and int(ends["bob"]["reward"]) == FWConst.GROUP_REWARDS[1], "second place gets the second prize")
	check(int(cs.accounts["ann"]["money"]) == m_ann + FWConst.GROUP_REWARDS[0] and int(cs.accounts["bob"]["money"]) == m_bob + FWConst.GROUP_REWARDS[1], "prizes are paid")
	check(int(ends["ann"]["of"]) == 3 and not cs.race.best.has("ann"), "group races do not touch the solo records")
	var guard := 0
	while cs.race.is_running("cy") and guard < 200:
		for ev in cs.race_step(1.0, {"cy": far, "dee": at}):
			if ev["kind"] == "end":
				ends[ev["name"]] = ev
		guard += 1
	check(ends.has("cy") and not ends["cy"]["finished"] and int(ends["cy"]["reward"]) == 0 and cs.race.groups.is_empty(), "a racer who times out gets nothing and the group is cleaned up")
	# با یک نفر لغو می‌شود
	cs.race_group("ann", at)
	var ev2: Array = cs.race.lobby_step(FWConst.GROUP_LOBBY_TIME, ["ann"])
	check(ev2.size() == 1 and ev2[0]["kind"] == "cancel" and not cs.race.is_running("ann"), "a lone player cancels the lobby")
	# حالت خلاقانه: بدون سکه
	cs.creative = true
	cs.race_group("ann", at)
	cs.race_group("bob", at)
	cs.race.lobby_step(FWConst.GROUP_LOBBY_TIME, ["ann", "bob"])
	var cm: int = int(cs.accounts["ann"]["money"])
	var cevs: Array = []
	for g in cs.race.public_state("ann")["pts"]:
		cevs.append_array(cs.race_step(0.2, {"ann": Vector2(g[0], g[1]), "bob": far}))
	var cend := {}
	for ev in cevs:
		if ev["kind"] == "end" and ev["name"] == "ann":
			cend = ev
	check(not cend.is_empty() and int(cend["reward"]) == 0 and int(cs.accounts["ann"]["money"]) == cm, "creative: group race pays no coins")


func test_race() -> void:
	print("== Gate race ==")
	var cs = CityState.new(4246)
	_login(cs, "racer")
	_login(cs, "other")
	var at := _mg_land_pos(cs)
	check(cs.race_start("ghost", at)["error"] == "no_account", "unknown player cannot race")
	check(cs.race_start("racer", at)["ok"], "a race starts")
	check(cs.race_start("racer", at)["error"] == "mg_running", "only one race at a time")
	check(cs.minigame_start("racer", at)["error"] == "mg_running", "no coin game during a race")
	var st: Dictionary = cs.race.public_state("racer")
	check(st["active"] and st["pts"].size() == FWConst.RACE_GATES and st["next"] == 0, "the track has all gates")
	var gates: Array = []
	for g in st["pts"]:
		gates.append(Vector2(float(g[0]), float(g[1])))
	var cs_b = CityState.new(4246)
	_login(cs_b, "racer")
	cs_b.race_start("racer", at)
	check(cs_b.race.public_state("racer")["pts"] == st["pts"], "the track is deterministic")
	# ترتیب: ایستگاه دوم را زودتر زدن چیزی ثبت نمی‌کند
	cs.race_step(0.1, {"racer": gates[1], "other": at})
	check(int(cs.race.public_state("racer")["next"]) == 0, "gates must be passed in order")
	var m0: int = int(cs.accounts["racer"]["money"])
	var evs: Array = _race_run(cs, "racer", gates, {"other": at})
	var end_ev: Dictionary = {}
	for ev in evs:
		if ev["kind"] == "end":
			end_ev = ev
	check(not end_ev.is_empty() and end_ev["finished"], "passing every gate in order finishes")
	check(int(end_ev["reward"]) == FWConst.RACE_REWARD and int(cs.accounts["racer"]["money"]) == m0 + FWConst.RACE_REWARD, "finishing pays the reward")
	check(int(end_ev["time"]) > 0 and end_ev["new_best"] and cs.race.board()[0][0] == "racer", "the time enters the leaderboard")
	# زمان‌سنجی: دور کند بدتر است و رکورد را عوض نمی‌کند
	var best0: int = int(cs.race.best["racer"])
	cs.race_start("racer", at)
	var slow_gates: Array = []
	for g in cs.race.public_state("racer")["pts"]:
		slow_gates.append(Vector2(float(g[0]), float(g[1])))
	var slow: Array = []
	for g in slow_gates:
		for k in 5:
			cs.race_step(1.0, {"racer": at + Vector2(900, 900), "other": at})
		slow.append_array(cs.race_step(0.2, {"racer": g, "other": at}))
	var slow_end: Dictionary = {}
	for ev in slow:
		if ev["kind"] == "end":
			slow_end = ev
	check(not slow_end.is_empty() and not slow_end["new_best"] and int(cs.race.best["racer"]) == best0, "a slower run keeps the old record")
	# مهلت
	cs.race_start("other", at)
	var guard := 0
	var fail_ev: Dictionary = {}
	while cs.race.is_running("other") and guard < 200:
		guard += 1
		for ev in cs.race_step(1.0, {"racer": at, "other": at + Vector2(900, 900)}):
			if ev["kind"] == "end":
				fail_ev = ev
	check(not fail_ev.is_empty() and not fail_ev["finished"] and int(fail_ev["reward"]) == 0, "timing out fails without reward")
	check(not cs.race.best.has("other"), "a failed run records no time")
	# محدودیت جایزهٔ روزانه
	cs.race.plays["racer"] = {"day": cs.day_count, "n": FWConst.RACE_REWARDED_RUNS}
	cs.race_start("racer", at)
	var gl: Array = []
	for g in cs.race.public_state("racer")["pts"]:
		gl.append(Vector2(float(g[0]), float(g[1])))
	var capped: Array = _race_run(cs, "racer", gl, {"other": at})
	var capped_end: Dictionary = {}
	for ev in capped:
		if ev["kind"] == "end":
			capped_end = ev
	check(not capped_end.is_empty() and int(capped_end["reward"]) == 0, "no reward after the daily limit")
	# خروج بازیکن
	cs.race_start("other", at)
	cs.race_step(0.1, {"racer": at})
	check(not cs.race.is_running("other"), "leaving cancels the race")
	# جدول: کمترین زمان بالاتر
	cs.race.best["other"] = 100
	check(cs.race.board()[0][0] == "other", "the leaderboard sorts by lowest time")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.race.best == cs.race.best and cs2.race.plays.has("racer"), "records survive save/load")
	check(not cs2.race.is_running("racer"), "an unfinished race is not saved")
	var old: Dictionary = cs.to_dict()
	old.erase("race")
	check(CityState.from_dict(old) != null, "old saves without race data still load")


## نقطه‌ای که در ۱۶ جهت تا ۳۰ متر آب باشد (داخل مرز جهان)؛ اگر نبود INF.
func _open_water(cs) -> Vector2:
	var x := -360.0
	while x < -40.0:
		var z := -360.0
		while z < -40.0:
			var all := Boat.is_water(cs, x, z)
			for k in 16:
				if not all:
					break
				var a := TAU * float(k) / 16.0
				if not Boat.is_water(cs, x + cos(a) * 30.0, z + sin(a) * 30.0):
					all = false
			if all:
				return Vector2(x, z)
			z += 10.0
		x += 10.0
	return Vector2(INF, INF)


func test_boat() -> void:
	print("== Boat (protocol 24) ==")
	var cs = CityState.new(4246)
	_login(cs, "sailor")
	_login(cs, "walker")
	# آب و خشکی
	var sp: Vector3 = cs.spawn_position()
	check(not Boat.is_water(cs, sp.x, sp.z), "the spawn is not water")
	var water := Vector2(-398.0, -398.0)
	check(Boat.is_water(cs, water.x, water.y), "deep terrain below the threshold is water")
	check(not cs.is_walkable(water.x, water.y), "players cannot walk on water")
	var near_w: Vector2 = Boat.find_water_near(cs, Vector2(sp.x, sp.z), FWConst.BOAT_BOARD_RANGE)
	check(not Boat.found(near_w), "no water is found next to the spawn")
	var land: Vector2 = Boat.find_land_near(cs, water, 40.0)
	check(Boat.found(land) and cs.is_walkable(land.x, land.y), "the nearest shore is walkable land")
	var back: Vector2 = Boat.find_water_near(cs, land, FWConst.BOAT_BOARD_RANGE)
	check(Boat.found(back) and Boat.is_water(cs, back.x, back.y), "water is found from the shore")
	check(Boat.find_land_near(cs, Vector2(sp.x, sp.z), 1.0) == Vector2(sp.x, sp.z), "standing on land returns the same point")
	# یک بلوک پل روی آب آن را قابل‌ایستادن و در نتیجه «غیرآب» می‌کند
	var bx := int(floor(water.x))
	var bz := int(floor(water.y))
	check(Boat.is_water(cs, float(bx) + 0.5, float(bz) + 0.5), "open water cell is water")
	# مسابقهٔ قایق
	var wcs = CityState.new(4246)
	_login(wcs, "sailor")
	check(wcs.race_start("sailor", Vector2(sp.x, sp.z), true)["error"] == "boat_race_no_space", "no boat race without open water")
	var open_w: Vector2 = _open_water(wcs)
	check(Boat.found(open_w), "open water exists in the world")
	check(wcs.race_start("sailor", open_w, true)["ok"], "a boat race starts on open water")
	check(wcs.race.is_boat_race("sailor"), "the run is marked as a boat race")
	var st: Dictionary = wcs.race.public_state("sailor")
	check(st["boat"] and st["pts"].size() == FWConst.RACE_GATES and float(st["total"]) == FWConst.BOAT_RACE_TIME, "boat track has all gates and its own time limit")
	var gates: Array = []
	var all_water := true
	for g in st["pts"]:
		var v := Vector2(float(g[0]), float(g[1]))
		gates.append(v)
		if not Boat.is_water(wcs, v.x, v.y):
			all_water = false
	check(all_water, "every boat gate is on water")
	var wcs_b = CityState.new(4246)
	_login(wcs_b, "sailor")
	wcs_b.race_start("sailor", Vector2(sp.x, sp.z), true)   # همان تعداد شروعِ قبلی تا شمارندهٔ مسیر یکسان باشد
	wcs_b.race_start("sailor", open_w, true)
	check(wcs_b.race.public_state("sailor")["pts"] == st["pts"], "the boat track is deterministic")
	wcs.race_step(0.1, {"sailor": gates[1]})
	check(int(wcs.race.public_state("sailor")["next"]) == 0, "boat gates must be passed in order")
	# ایستگاه قایق با شعاع بزرگ‌تر ثبت می‌شود
	wcs.race_step(0.1, {"sailor": gates[0] + Vector2(FWConst.BOAT_RACE_GATE_RANGE - 0.2, 0.0)})
	check(int(wcs.race.public_state("sailor")["next"]) == 1, "boat gate range applies")
	var m0: int = int(wcs.accounts["sailor"]["money"])
	var end_ev: Dictionary = {}
	for ev in _race_run(wcs, "sailor", gates.slice(1), {}):
		if ev["kind"] == "end":
			end_ev = ev
	check(not end_ev.is_empty() and end_ev["finished"] and end_ev["boat"], "finishing a boat race ends it")
	check(int(end_ev["reward"]) == FWConst.BOAT_RACE_REWARD and int(wcs.accounts["sailor"]["money"]) == m0 + FWConst.BOAT_RACE_REWARD, "a boat race pays the boat reward")
	check(wcs.race.board(true)[0][0] == "sailor" and wcs.race.board().is_empty(), "the boat time goes to its own leaderboard")
	check(wcs.race.best.is_empty() and wcs.race.best_boat.has("sailor"), "boat and land records are separate")
	# سقف جایزهٔ روزانه جدا از مسابقهٔ پیاده است
	check(wcs.race.plays.has("boat:sailor") and not wcs.race.plays.has("sailor"), "daily reward cap is counted per race kind")
	# مهلت مسابقهٔ قایق
	wcs.race_start("sailor", open_w, true)
	var guard := 0
	var fail_ev: Dictionary = {}
	while wcs.race.is_running("sailor") and guard < 300:
		guard += 1
		for ev in wcs.race_step(1.0, {"sailor": open_w + Vector2(300, 300)}):
			if ev["kind"] == "end":
				fail_ev = ev
	check(not fail_ev.is_empty() and not fail_ev["finished"] and fail_ev["boat"] and int(fail_ev["reward"]) == 0, "a boat race times out without reward")
	# ذخیره و بارگذاری
	var cs2 = CityState.from_dict(wcs.to_dict())
	check(cs2 != null and cs2.race.best_boat == wcs.race.best_boat and cs2.race.plays.has("boat:sailor"), "boat records survive save/load")
	var old: Dictionary = wcs.to_dict()
	old["race"].erase("best_boat")
	var cs3 = CityState.from_dict(old)
	check(cs3 != null and cs3.race.best_boat.is_empty(), "old saves without boat records still load")
	var bad: Dictionary = wcs.to_dict()
	bad["race"]["best_boat"] = {"x": 999999999}
	var cs4 = CityState.from_dict(bad)
	check(cs4 != null and int(cs4.race.best_boat["x"]) <= int(FWConst.BOAT_RACE_TIME * 100.0), "loaded boat times are clamped")
	# مالکیت قایق و ماهیگیری (پروتکل ۲۵)
	var ocs = CityState.new(4246)
	_login(ocs, "builder")
	ocs.creative = false
	var oacc: Dictionary = ocs.accounts["builder"]
	check(not ocs.has_boat(oacc), "a new survival player has no boat")
	oacc["inv"]["wood"] = 5
	oacc["inv"]["iron"] = 0
	check(ocs.craft("builder", "boat", 1)["error"] == "no_items", "the boat needs materials")
	oacc["inv"]["wood"] = 25
	oacc["inv"]["iron"] = 3
	check(ocs.craft("builder", "boat", 2)["error"] == "bad_request", "a boat is crafted once at a time")
	var bres: Dictionary = ocs.craft("builder", "boat", 1)
	check(bres["ok"] and ocs.has_boat(oacc), "crafting builds the boat")
	check(int(oacc["inv"]["wood"]) == 5 and int(oacc["inv"]["iron"]) == 1, "the boat costs 20 wood and 2 iron")
	check(ocs.craft("builder", "boat", 1)["error"] == "already_owned", "a second boat is refused")
	var ocs2 = CityState.from_dict(ocs.to_dict())
	check(ocs2 != null and ocs2.has_boat(ocs2.accounts["builder"]), "boat ownership survives save/load")
	ocs.creative = true
	check(ocs.has_boat({}), "creative worlds give everyone a boat")
	ocs.creative = false
	check(int(ocs.fish("builder", 0.1)["count"]) == 0, "a low roll catches nothing")
	var f1: Dictionary = ocs.fish("builder", 0.5)
	var f2: Dictionary = ocs.fish("builder", 0.95)
	check(int(f1["count"]) == 1 and int(f2["count"]) == 2 and int(oacc["inv"]["fish"]) == 3, "fishing yields 1 or 2 fish and fills the inventory")
	oacc["inv"]["fish"] = FWConst.ITEM_CAP
	check(ocs.fish("builder", 0.9)["error"] == "inv_full", "a full inventory refuses more fish")
	oacc["inv"]["fish"] = 4
	var sold: Dictionary = ocs.trade("builder", "fish", 4, false)
	check(sold["ok"] and int(sold["total"]) > 0, "fish can be sold at the market")
	# اسب (پروتکل ۲۶)
	var hcs = CityState.new(4246)
	_login(hcs, "rider")
	hcs.creative = false
	var hacc: Dictionary = hcs.accounts["rider"]
	hacc["money"] = 100
	check(not hcs.has_horse(hacc), "a new player has no horse")
	check(hcs.craft("rider", "horse", 1)["error"] == "no_money", "a horse needs enough coins")
	hacc["money"] = 1000
	var hres: Dictionary = hcs.craft("rider", "horse", 1)
	check(hres["ok"] and hcs.has_horse(hacc) and int(hacc["money"]) == 700, "buying the horse costs 300 coins")
	check(hcs.craft("rider", "horse", 1)["error"] == "already_owned", "a second horse is refused")
	var hcs2 = CityState.from_dict(hcs.to_dict())
	check(hcs2 != null and hcs2.has_horse(hcs2.accounts["rider"]), "horse ownership survives save/load")
	check(not hcs2.has_boat(hcs2.accounts["rider"]), "owning a horse does not give a boat")
	# ماشین (پروتکل ۲۷)
	hacc["money"] = 500
	check(not hcs.has_car(hacc), "a new player has no car")
	check(hcs.craft("rider", "car", 1)["error"] == "no_items", "a car needs iron")
	hacc["inv"]["iron"] = 6
	check(hcs.craft("rider", "car", 1)["error"] == "no_money", "a car needs enough coins")
	hacc["money"] = 2000
	var cres: Dictionary = hcs.craft("rider", "car", 1)
	check(cres["ok"] and hcs.has_car(hacc) and int(hacc["money"]) == 800 and int(hacc["inv"].get("iron", 0)) == 0, "buying the car costs 1200 coins and 6 iron")
	check(hcs.craft("rider", "car", 1)["error"] == "already_owned", "a second car is refused")
	var hcs3 = CityState.from_dict(hcs.to_dict())
	check(hcs3 != null and hcs3.has_car(hcs3.accounts["rider"]) and not hcs3.has_boat(hcs3.accounts["rider"]), "car ownership survives save/load")
	check(FWConst.CAR_SPEED_MULT > FWConst.HORSE_SPEED_MULT, "a car is faster than a horse")
	# مسابقهٔ پیاده روی خشکی هنوز مثل قبل
	check(cs.race_start("walker", Vector2(FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5))["ok"] and not cs.race.is_boat_race("walker"), "walking races are unchanged")


func test_disasters() -> void:
	print("== Natural disasters ==")
	var cs = CityState.new(4245)
	cs.provision_admin("root", "secret")
	_login(cs, "pal")
	_login(cs, "mayor")
	check(cs.set_role("root", "mayor", "city_admin")["ok"], "mayor role set up")
	check(cs.start_disaster("pal", "storm")["error"] == "forbidden", "players cannot start disasters")
	check(cs.start_disaster("mayor", "meteor")["error"] == "bad_request", "unknown disaster is rejected")
	check(str(cs.disaster_public()["kind"]) == "", "no disaster at first")
	var r: Dictionary = cs.start_disaster("mayor", "storm")
	check(r["ok"] and r["disaster"]["kind"] == "storm" and r["disaster"]["t"] == FWConst.DISASTERS["storm"], "an admin starts a storm")
	check(cs.start_disaster("root", "quake")["error"] == "disaster_active", "only one disaster at a time")
	# اثر طوفان: انرژی بیرون دو برابر سریع‌تر کم می‌شود، داخل ساختمان تغییری ندارد
	cs.accounts["pal"]["energy"] = FWConst.ENERGY_MAX
	cs.energy_step(10.0, {"pal": 0})
	var drop_storm: float = FWConst.ENERGY_MAX - float(cs.accounts["pal"]["energy"])
	cs.disaster = {"kind": "", "t": 0.0}
	cs.accounts["pal"]["energy"] = FWConst.ENERGY_MAX
	cs.energy_step(10.0, {"pal": 0})
	var drop_calm: float = FWConst.ENERGY_MAX - float(cs.accounts["pal"]["energy"])
	check(is_equal_approx(drop_storm, drop_calm * FWConst.STORM_ENERGY_MULT), "storm drains energy faster outdoors")
	# پایان خودکار و وقفه
	cs.disaster = {"kind": "quake", "t": 2.0}
	check(not cs.disaster_step(1.0), "a disaster lasts its duration")
	check(cs.disaster_step(1.5) and str(cs.disaster_public()["kind"]) == "", "it ends on time")
	check(cs.start_disaster("mayor", "storm")["error"] == "disaster_cooldown", "a cooldown follows every disaster")
	cs.disaster_step(FWConst.DISASTER_COOLDOWN + 1.0)
	check(cs.start_disaster("mayor", "quake")["ok"], "a new one can start after the cooldown")
	# ثبت در گزارش و ذخیره‌نشدن
	var logged := false
	for e in cs.audit:
		if str(e["action"]) == "disaster":
			logged = true
	check(logged, "disasters are written to the admin audit log")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and str(cs2.disaster["kind"]) == "", "an ongoing disaster is not saved")


func test_arena_edit() -> void:
	print("== Arena editing ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "guest")
	_login(cs, "root")
	cs.accounts["maker"]["role"] = FWConst.ROLE_PLAYER
	cs.accounts["guest"]["role"] = FWConst.ROLE_PLAYER
	cs.accounts["root"]["role"] = FWConst.ROLE_WORLD_ADMIN
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var id: int = int(cs.arena_create("maker", "Gold Rush", at, 10.0, 10, 40.0, 2)["id"])
	var paid: int = int(cs.accounts["maker"]["money"])
	check(cs.arena_edit("ghost", id, "x", 10.0, 10, 40.0, 1) == "no_account", "unknown player cannot edit")
	check(cs.arena_edit("maker", 999, "x", 10.0, 10, 40.0, 1) == "arena_missing", "editing a missing arena fails")
	check(cs.arena_edit("guest", id, "Hacked", 10.0, 10, 40.0, 1) == "not_owner", "another player cannot edit my arena")
	check(cs.arena_edit("maker", id, "   ", 10.0, 10, 40.0, 1) == "arena_name", "an edited arena still needs a name")
	check(cs.arena_edit("maker", id, "Gold Rush 2", 8.0, 15, 60.0, 3) == "", "the owner edits name, radius, coins, time and prize")
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["name"]) == "Gold Rush 2" and float(a["r"]) == 8.0 and int(a["coins"]) == 15 and float(a["time"]) == 60.0 and int(a["reward"]) == 3, "the changes are stored")
	check(float(a["x"]) == snappedf(at.x, 0.1) and float(a["z"]) == snappedf(at.y, 0.1) and str(a["owner"]) == "maker", "position and owner stay the same")
	check(int(cs.accounts["maker"]["money"]) == paid, "editing is free")
	check(cs.arena_edit("maker", id, "Big", 999.0, 999, 9999.0, 99) == "" and float(cs.arenas.items[id]["r"]) == FWConst.ARENA_R_MAX and int(cs.arenas.items[id]["reward"]) == FWConst.ARENA_REWARD_MAX, "edited settings are clamped by the server")
	check(cs.arena_edit("root", id, "Admin Fix", 10.0, 10, 40.0, 1) == "" and str(cs.arenas.items[id]["name"]) == "Admin Fix", "an admin can edit any arena")
	# میدان دوم نزدیک: بزرگ‌کردن شعاع میدان اول نباید با آن تداخل کند.
	var far: Vector2 = at + Vector2(float(FWConst.ARENA_R_MIN) * 2.0 + FWConst.ARENA_SPACING + 12.0, 0.0)
	var r2: Dictionary = cs.arena_create("maker", "Neighbour", far, 6.0, 8, 40.0, 1)
	if r2["ok"]:
		check(cs.arena_edit("maker", id, "Admin Fix", 20.0, 10, 40.0, 1) == "arena_close", "growing an arena into a neighbour is refused")
		check(float(cs.arenas.items[id]["r"]) == 10.0, "a refused edit changes nothing")
	# ویرایش وسط دور، دور آن میدان را لغو می‌کند.
	cs.accounts["guest"]["money"] = 0
	check(cs.arena_play("guest", id, at)["ok"], "a guest starts a run")
	check(cs.arena_edit("maker", id, "Again", 10.0, 12, 40.0, 1) == "", "the owner edits while a run is active")
	check(not bool(cs.minigame.public_state("guest").get("active", false)), "editing cancels the running round of that arena")


func test_arenas() -> void:
	print("== Player arenas (creator layer) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "guest")
	cs.accounts["maker"]["money"] = 1000
	cs.accounts["guest"]["money"] = 0
	var at := _mg_land_pos(cs)
	check(cs.arena_create("ghost", "x", at, 10.0, 10, 40.0, 1)["error"] == "no_account", "unknown player cannot build an arena")
	check(cs.arena_create("maker", "   ", at, 10.0, 10, 40.0, 1)["error"] == "arena_name", "an arena needs a name")
	var r1: Dictionary = cs.arena_create("maker", "Gold Rush", at, 10.0, 10, 40.0, 2)
	check(r1["ok"] and int(cs.accounts["maker"]["money"]) == 1000 - FWConst.ARENA_COST, "arena is built and costs coins")
	check(cs.arena_create("maker", "Too Close", at + Vector2(5, 0), 10.0, 10, 40.0, 1)["error"] == "arena_close", "arenas cannot overlap")
	var bad: Dictionary = cs.arena_create("maker", "Wet", Vector2(-300, -300), 10.0, 10, 40.0, 1)
	check(not bad["ok"], "sea or out-of-land spots are refused (%s)" % str(bad.get("error", "")))
	var id: int = int(r1["id"])
	var a: Dictionary = cs.arenas.items[id]
	var wide: Dictionary = cs.arena_create("guest", "Greedy", at + Vector2(200, 0), 999.0, 999, 9999.0, 99)
	check(not wide["ok"] and wide["error"] == "arena_no_money", "a broke player cannot afford an arena")
	cs.accounts["guest"]["money"] = 1000
	var r3: Dictionary = cs.arena_create("guest", "Greedy", at + Vector2(200, 0), 999.0, 999, 9999.0, 99)
	if r3["ok"]:
		var g: Dictionary = cs.arenas.items[int(r3["id"])]
		check(float(g["r"]) == FWConst.ARENA_R_MAX and int(g["coins"]) == FWConst.ARENA_COINS_MAX and float(g["time"]) == FWConst.ARENA_TIME_MAX and int(g["reward"]) == FWConst.ARENA_REWARD_MAX, "settings are clamped by the server")
		cs.arena_remove("guest", int(r3["id"]))
	cs.accounts["guest"]["money"] = 0
	# بازی
	check(cs.arena_play("guest", 999, at)["error"] == "arena_missing", "missing arena")
	check(cs.arena_play("guest", id, at + Vector2(100, 100))["error"] == "arena_far", "must stand inside the arena")
	check(cs.arena_play("guest", id, at)["ok"], "a guest starts an arena run")
	check(cs.arena_play("guest", id, at)["error"] == "mg_running", "one run at a time")
	var pub: Dictionary = cs.minigame.public_state("guest")
	var coins: Array = pub["coins"]
	var inside := true
	for c in coins:
		if Vector2(float(c[0]), float(c[1])).distance_to(at) > float(a["r"]) + 0.5:
			inside = false
	check(pub["active"] and coins.size() >= FWConst.ARENA_COINS_MIN and coins.size() <= 10 and inside, "arena coins stay inside the circle")
	check(float(pub["t"]) <= 40.0 and float(pub["t"]) > 39.0, "run time comes from the arena")
	var owner_m: int = int(cs.accounts["maker"]["money"])
	var total: int = coins.size()
	var end_ev: Dictionary = {}
	for c in coins:
		for ev in cs.minigame_step(0.1, {"guest": Vector2(float(c[0]), float(c[1])), "maker": at}):
			if ev["kind"] == "end":
				end_ev = ev
	check(not end_ev.is_empty() and int(end_ev["score"]) == total and int(end_ev["arena"]) == id, "collecting all coins ends the arena run")
	check(int(end_ev["reward"]) == total * 2 and int(cs.accounts["guest"]["money"]) == total * 2, "prize is paid to the guest")
	check(int(cs.accounts["maker"]["money"]) == owner_m - total * 2, "prize comes out of the creator's money")
	check(cs.minigame.board().is_empty(), "arena runs do not touch the global leaderboard")
	check(int(cs.arenas_public()[0]["top"][1]) == total and cs.arenas_public()[0]["top"][0] == "guest", "arena keeps its own record")
	# سازنده خودش جایزه نمی‌گیرد
	cs.arena_play("maker", id, at)
	var own_end: Dictionary = {}
	for c in cs.minigame.public_state("maker")["coins"]:
		for ev in cs.minigame_step(0.1, {"maker": Vector2(float(c[0]), float(c[1]))}):
			if ev["kind"] == "end":
				own_end = ev
	check(not own_end.is_empty() and int(own_end["reward"]) == 0, "the creator earns no prize in their own arena")
	# سازندهٔ ناتوان از پرداخت
	cs.accounts["maker"]["money"] = 1
	cs.arena_play("guest", id, at)
	var poor_end: Dictionary = {}
	var g_before: int = int(cs.accounts["guest"]["money"])
	for c in cs.minigame.public_state("guest")["coins"]:
		for ev in cs.minigame_step(0.1, {"guest": Vector2(float(c[0]), float(c[1]))}):
			if ev["kind"] == "end":
				poor_end = ev
	check(not poor_end.is_empty() and int(poor_end["reward"]) <= 1 and int(cs.accounts["maker"]["money"]) >= 0, "prize never exceeds what the creator owns")
	check(int(cs.accounts["guest"]["money"]) - g_before == int(poor_end["reward"]), "guest receives exactly what was paid")
	# ماندگاری
	cs.accounts["maker"]["money"] = 500
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2.arenas.items.has(id) and cs2.arenas.items[id]["name"] == "Gold Rush", "arenas survive save and load")
	check(int(cs2.minigame.arena_scores.get(id, {}).get("guest", 0)) == total, "arena records survive save and load")
	# حذف
	check(cs.arena_remove("guest", id) == "not_owner", "others cannot delete an arena")
	cs.arena_play("guest", id, at)
	check(cs.minigame.is_running("guest"), "a run is active before deletion")
	check(cs.arena_remove("maker", id) == "" and not cs.arenas.items.has(id), "creator deletes the arena")
	check(not cs.minigame.is_running("guest") and not cs.minigame.arena_scores.has(id), "deleting cancels runs and records")
	check(cs.arena_remove("maker", id) == "arena_missing", "deleting twice reports missing")
	# سقف تعداد برای هر بازیکن و خلاقانه
	cs.accounts["maker"]["money"] = 100000
	var made := 0
	for i in range(6):
		var rr: Dictionary = cs.arena_create("maker", "A%d" % i, at + Vector2(float(i) * 60.0, 0.0), 8.0, 6, 30.0, 0)
		if rr["ok"]:
			made += 1
	check(made <= FWConst.ARENA_MAX_PER_PLAYER, "per-player arena limit holds (%d built)" % made)
	var cr = CityState.new(4244)
	cr.creative = true
	_login(cr, "free")
	cr.accounts["free"]["money"] = 0
	var cres: Dictionary = cr.arena_create("free", "Free", at, 10.0, 8, 30.0, 3)
	check(cres["ok"] and int(cr.accounts["free"]["money"]) == 0, "creative worlds build arenas for free")


func test_minigame() -> void:
	print("== Coin Rush minigame ==")
	var cs = CityState.new(4244)
	_login(cs, "runner")
	_login(cs, "rival")
	var at := _mg_land_pos(cs)
	check(cs.minigame_start("ghost", at)["error"] == "no_account", "unknown player cannot start")
	var st: Dictionary = cs.minigame_start("runner", at)
	check(st["ok"], "a run starts")
	check(cs.minigame_start("runner", at)["error"] == "mg_running", "only one run at a time")
	var pub: Dictionary = cs.minigame.public_state("runner")
	check(pub["active"] and pub["coins"].size() >= 5 and pub["coins"].size() <= FWConst.MINIGAME_COINS, "coins are placed around the player")
	var ok_dist := true
	for c in pub["coins"]:
		if Vector2(float(c[0]), float(c[1])).distance_to(at) > FWConst.MINIGAME_RADIUS + 1.0:
			ok_dist = false
	check(ok_dist, "coins stay within the play radius")
	# تعیین‌پذیری: همان seed و شمارنده همان چیدمان را می‌دهد
	var cs_b = CityState.new(4244)
	_login(cs_b, "runner")
	cs_b.minigame_start("runner", at)
	check(cs_b.minigame.public_state("runner")["coins"] == pub["coins"], "coin layout is deterministic")
	# دور نبودن از سکه: امتیازی نمی‌دهد
	var far := {"runner": at + Vector2(500, 500), "rival": at}
	cs.minigame_step(0.1, far)
	check(int(cs.minigame.public_state("runner")["score"]) == 0, "standing far from coins scores nothing")
	# جمع کردن همهٔ سکه‌ها با رفتن روی هرکدام
	var m0: int = int(cs.accounts["runner"]["money"])
	var total: int = pub["coins"].size()
	var end_ev: Dictionary = {}
	for c in pub["coins"]:
		var evs: Array = cs.minigame_step(0.1, {"runner": Vector2(float(c[0]), float(c[1])), "rival": at})
		for ev in evs:
			if ev["kind"] == "end":
				end_ev = ev
	check(not end_ev.is_empty() and end_ev["score"] == total, "collecting every coin ends the run with full score")
	var expect: int = total * FWConst.MINIGAME_REWARD_PER_COIN + (FWConst.MINIGAME_FULL_BONUS if total >= FWConst.MINIGAME_COINS else 0)
	check(int(end_ev["reward"]) == expect and int(cs.accounts["runner"]["money"]) == m0 + expect, "reward is paid to the account")
	check(not cs.minigame.is_running("runner"), "the run is over")
	check(cs.minigame.board()[0][0] == "runner" and cs.minigame.board()[0][1] == total, "best score reaches the leaderboard")
	# مهلت زمانی
	cs.minigame_start("rival", at)
	var timed: Array = []
	var guard := 0
	while cs.minigame.is_running("rival") and guard < 1000:
		guard += 1
		timed = cs.minigame_step(1.0, {"runner": at, "rival": at + Vector2(900, 900)})
	check(guard <= int(FWConst.MINIGAME_TIME) + 2 and not cs.minigame.is_running("rival"), "a run ends when time runs out")
	check(cs.minigame.board().size() == 1, "zero-score runs still record only real scores")
	# محدودیت جایزهٔ روزانه
	cs.minigame.plays["runner"] = {"day": cs.day_count, "n": FWConst.MINIGAME_REWARDED_RUNS}
	cs.minigame_start("runner", at)
	var capped: Array = []
	for c in cs.minigame.public_state("runner")["coins"]:
		for ev in cs.minigame_step(0.1, {"runner": Vector2(float(c[0]), float(c[1]))}):
			if ev["kind"] == "end":
				capped.append(ev)
	check(capped.size() == 1 and int(capped[0]["reward"]) == 0, "no reward after the daily limit")
	cs.day_count += 1
	cs.minigame_start("runner", at)
	var nd: Array = []
	for c in cs.minigame.public_state("runner")["coins"]:
		for ev in cs.minigame_step(0.1, {"runner": Vector2(float(c[0]), float(c[1]))}):
			if ev["kind"] == "end":
				nd.append(ev)
	check(nd.size() == 1 and int(nd[0]["reward"]) > 0, "rewards return on the next day")
	# خروج بازیکن دور را لغو می‌کند
	cs.minigame_start("rival", at)
	cs.minigame_step(0.1, {"runner": at})
	check(not cs.minigame.is_running("rival"), "leaving cancels the run without reward")
	# جدول امتیاز و ذخیره
	cs.minigame.scores["rival"] = 3
	var b: Array = cs.minigame.board()
	check(b[0][1] >= b[1][1], "leaderboard is sorted by score")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.minigame.scores == cs.minigame.scores and cs2.minigame.plays.has("runner"), "scores and daily limits survive save/load")
	check(not cs2.minigame.is_running("runner"), "an unfinished run is not saved")
	var old: Dictionary = cs.to_dict()
	old.erase("minigame")
	check(CityState.from_dict(old) != null, "old saves without minigame data still load")


func test_npc_sell() -> void:
	print("== Selling to NPCs ==")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(4243)
	_login(cs, "trader")
	NpcSim.ensure_npcs(cs)
	var npc: Dictionary = cs.npcs[0]
	var id: int = int(npc["id"])
	var at := Vector2(float(npc["x"]), float(npc["z"]))
	var acc: Dictionary = cs.accounts["trader"]
	acc["inv"]["wood"] = 20
	npc["money"] = 1000
	check(cs.npc_sell("trader", 99, "wood", 1, at)["error"] == "no_npc", "selling to an unknown NPC is rejected")
	check(cs.npc_sell("trader", id, "wood", 1, at + Vector2(FWConst.NPC_TALK_RANGE + 2.0, 0))["error"] == "too_far", "selling needs closeness")
	check(cs.npc_sell("trader", id, "wood", 0, at)["error"] == "bad_request", "zero amount is rejected")
	check(cs.npc_sell("trader", id, "wood", FWConst.NPC_TRADE_MAX + 1, at)["error"] == "bad_request", "huge amount is rejected")
	check(cs.npc_sell("trader", id, "wood", 21, at)["error"] == "no_items", "cannot sell more than you own")
	var mult0: float = float(cs.item_mult.get("wood", 1.0))
	var m0: int = int(acc["money"])
	var r: Dictionary = cs.npc_sell("trader", id, "wood", 5, at)
	var unit: int = cs.sell_price("wood")
	check(r["ok"] and r["count"] == 5 and r["total"] == unit * 5, "a stranger pays the market price")
	check(int(acc["money"]) == m0 + unit * 5 and int(acc["inv"]["wood"]) == 15, "money and items move")
	check(int(npc["money"]) == 1000 - unit * 5, "the NPC pays from their own money")
	check(float(cs.item_mult.get("wood", 1.0)) == mult0, "selling to an NPC does not move the market price")
	acc["friends"] = {str(id): FWConst.FRIEND_LEVELS[1]}
	var r2: Dictionary = cs.npc_sell("trader", id, "wood", 1, at)
	check(r2["ok"] and r2["total"] > unit, "a best friend pays more than the market")
	var unit2: int = r2["total"]
	npc["money"] = unit2 * 2 + 1
	var r3: Dictionary = cs.npc_sell("trader", id, "wood", 10, at)
	check(r3["ok"] and r3["count"] == 2 and int(npc["money"]) == 1, "a poor NPC only buys what they can afford")
	npc["money"] = 0
	check(cs.npc_sell("trader", id, "wood", 1, at)["error"] == "npc_broke", "a broke NPC cannot buy")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and int(cs2.accounts["trader"]["money"]) == int(acc["money"]), "trade results survive save/load")


func test_npc_buy() -> void:
	print("== Buying from NPCs ==")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(4244)
	_login(cs, "buyer")
	NpcSim.ensure_npcs(cs)
	var npc: Dictionary = cs.npcs[0]
	var id: int = int(npc["id"])
	var at := Vector2(float(npc["x"]), float(npc["z"]))
	var acc: Dictionary = cs.accounts["buyer"]
	acc["money"] = 1000
	acc["inv"]["wood"] = 0
	check(cs.npc_buy("buyer", 99, "wood", 1, at)["error"] == "no_npc", "buying from an unknown NPC is rejected")
	check(cs.npc_buy("buyer", id, "wood", 1, at + Vector2(FWConst.NPC_TALK_RANGE + 2.0, 0))["error"] == "too_far", "buying needs closeness")
	check(cs.npc_buy("buyer", id, "gold", 1, at)["error"] == "bad_request", "an NPC does not sell gold")
	check(cs.npc_buy("buyer", id, "wood", 0, at)["error"] == "bad_request", "zero amount is rejected")
	check(cs.npc_buy("buyer", id, "wood", FWConst.NPC_TRADE_MAX + 1, at)["error"] == "bad_request", "huge amount is rejected")
	var unit := FWConst.npc_buy_price("wood", 0)
	check(unit < CityState.buy_price("wood"), "an NPC is cheaper than the public shop")
	var npc_m0: int = int(npc["money"])
	var r: Dictionary = cs.npc_buy("buyer", id, "wood", 5, at)
	check(r["ok"] and r["count"] == 5 and r["total"] == unit * 5, "a stranger pays the NPC price")
	check(int(acc["money"]) == 1000 - unit * 5 and int(acc["inv"]["wood"]) == 5, "money and items move")
	check(int(npc["money"]) == npc_m0 + unit * 5, "the NPC receives the payment")
	acc["friends"] = {str(id): FWConst.FRIEND_LEVELS[1]}
	check(FWConst.npc_buy_price("wood", 2) < unit, "a best friend gets a discount")
	var r2: Dictionary = cs.npc_buy("buyer", id, "wood", FWConst.NPC_TRADE_MAX, at)
	check(r2["ok"] and r2["count"] == FWConst.NPC_STOCK_PER_DAY - 5, "the daily stock caps what you can buy")
	check(cs.npc_buy("buyer", id, "wood", 1, at)["error"] == "npc_out_of_stock", "sold-out items are refused")
	check(cs.npc_buy("buyer", id, "stone", 1, at)["ok"], "stock is tracked per item")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.npc_buy("buyer", id, "wood", 1, at)["error"] == "npc_out_of_stock", "the daily stock survives save/load")
	cs2.day_count += 1
	check(cs2.npc_buy("buyer", id, "wood", 1, at)["ok"], "stock refills on a new day")
	acc["money"] = 0
	check(cs.npc_buy("buyer", id, "clay", 1, at)["error"] == "no_money", "you cannot buy without coins")
	acc["money"] = 5000
	acc["inv"]["dirt"] = FWConst.ITEM_CAP
	check(cs.npc_buy("buyer", id, "dirt", 1, at)["error"] == "inv_full", "a full bag is refused")


func test_furniture() -> void:
	print("== House furniture ==")
	var cs = CityState.new(4245)
	_login(cs, "home")
	_login(cs, "thief")
	cs.accounts["home"]["money"] = 5000
	cs.place_building("home", 1, "house", 12, 14)
	cs.place_building("home", 2, "shop", 20, 14)
	var house: Dictionary = _first_of(cs, "house")
	var shop: Dictionary = _first_of(cs, "shop")
	var hid: int = int(house["id"])
	var m0: int = int(cs.accounts["home"]["money"])
	check(cs.furn_place("thief", hid, "bed", 0, -2, 0)["error"] == "forbidden", "only the owner can furnish a house")
	check(cs.furn_place("home", int(shop["id"]), "bed", 0, -2, 0)["error"] == "not_house", "furniture only goes into houses")
	check(cs.furn_place("home", hid, "piano", 0, 0, 0)["error"] == "bad_request", "unknown furniture is rejected")
	check(cs.furn_place("home", hid, "bed", 0, 0, 7)["error"] == "bad_request", "a bad rotation is rejected")
	check(cs.furn_place("home", hid, "bed", INF, 0, 0)["error"] == "bad_request", "non-finite positions are rejected")
	var r: Dictionary = cs.furn_place("home", hid, "bed", -2.1, -2.8, 0)
	check(r["ok"] and r["furn"].size() == 1, "a bed is placed")
	check(int(cs.accounts["home"]["money"]) == m0 - int(FWConst.FURNITURE["bed"]["cost"]), "the price is charged")
	check(is_equal_approx(float(r["furn"][0]["x"]), -2.0), "positions snap to the grid")
	check(cs.furn_place("home", hid, "bed", -2.0, -2.8, 0)["error"] == "furn_overlap", "pieces cannot overlap")
	check(cs.furn_place("home", hid, "rug", -2.0, -2.8, 0)["ok"], "a rug can lie under a bed")
	check(cs.furn_place("home", hid, "rug", -2.0, -2.8, 0)["error"] == "furn_overlap", "two rugs cannot overlap")
	check(cs.furn_place("home", hid, "sofa", 3.5, 0, 0)["error"] == "furn_out", "pieces cannot leave the room")
	check(cs.furn_place("home", hid, "sofa", 3.25, 0, 1)["ok"], "rotation swaps width and depth")
	check(cs.furn_place("home", hid, "table", 0, 3.0, 0)["error"] == "furn_door", "the doorway stays clear")
	cs.accounts["home"]["money"] = 5
	check(cs.furn_place("home", hid, "table", 0, 0, 0)["error"] == "no_money", "furniture needs coins")
	cs.accounts["home"]["money"] = 5000
	var n0: int = cs.furn_of(hid).size()
	for i in FWConst.FURN_MAX:
		cs.furn_place("home", hid, "plant", -3.5 + float(i % 8) * 0.5, -1.0 + float(i / 8) * 0.75, 0)
	check(cs.furn_of(hid).size() == FWConst.FURN_MAX, "the per-house cap is enforced")
	check(cs.furn_place("home", hid, "lamp", 2.0, 2.0, 0)["error"] == "furn_full", "a full house is refused")
	var m1: int = int(cs.accounts["home"]["money"])
	check(cs.furn_remove("thief", hid, 0)["error"] == "forbidden", "only the owner can remove furniture")
	check(cs.furn_remove("home", hid, 99)["error"] == "bad_request", "a bad index is rejected")
	var rr: Dictionary = cs.furn_remove("home", hid, 0)
	check(rr["ok"] and int(cs.accounts["home"]["money"]) == m1 + int(FWConst.FURNITURE["bed"]["cost"]) / 2, "removing refunds half")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.furn_of(hid) == cs.furn_of(hid), "furniture survives save/load")
	var d: Dictionary = cs.to_dict()
	for b in d["buildings"]:
		if int(b["id"]) == hid:
			b["furn"] = [{"t": "piano", "x": 0, "z": 0, "r": 0}, {"t": "bed", "x": 99, "z": 0, "r": 0}, {"t": "lamp", "x": 1.0, "z": 1.0, "r": 5}]
	var cs3 = CityState.from_dict(d)
	check(cs3 != null and cs3.furn_of(hid).size() == 1, "corrupt furniture is dropped when loading")
	cs.creative = true
	var mc: int = int(cs.accounts["home"]["money"])
	cs.furn_remove("home", hid, 0)
	cs.furn_place("home", hid, "sofa", 0.0, -3.0, 0)
	check(int(cs.accounts["home"]["money"]) == mc, "creative mode is free")


func test_legends() -> void:
	print("[legends]")
	var ids := {}
	var data_ok := true
	var texts_ok := true
	var missing := ""
	for sc in Story.LEGENDS:
		var cast_roles: Array = []
		for c in Story.cast_for(str(sc)):
			cast_roles.append(str(c[1]))
		if not Scenarios.has(str(sc)):
			data_ok = false
		for e in Story.legend_entries(str(sc)):
			if ids.has(e["id"]) or Story.entry(str(e["id"])).is_empty() or not cast_roles.has(str(e["giver"])):
				data_ok = false
			ids[e["id"]] = true
			if int(e["reward"]) < 0 or int(e["reward"]) > 100:
				data_ok = false
			for lang in ["fa", "en"]:
				Loc.lang = lang
				for k in ["book_" + str(e["id"]), "book_%s_d" % str(e["id"])]:
					if Loc.t(k) == k:
						texts_ok = false
						missing = k
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["book_legend"] + range(8).map(func(i): return "legend_dir_%d" % i):
			if Loc.t(k) == k:
				texts_ok = false
				missing = k
	Loc.lang = "fa"
	check(data_ok, "legend steps have unique ids, known worlds, cast givers and small rewards (%d steps)" % ids.size())
	check(texts_ok, "every legend step and direction has Persian and English text (%s)" % missing)
	check(Story.legend_entries("").is_empty() and Story.entries_for("temperate", false, "").size() == Story.entries_for("temperate", false).size(), "worlds without a legend are unchanged")
	# همهٔ جهان‌های افسانه‌دار: مقصدها خشکی‌اند و نشانگر دارند
	for sc in Story.LEGENDS:
		var wc = CityState.new(int(Scenarios.def(str(sc))["seed"]))
		ScenarioApply.apply(wc, str(sc))
		var all_dry := true
		var all_marked := true
		for e in Story.legend_entries(str(sc)):
			var q: Vector2 = Book.legend_spot(wc, e)
			if Boat.is_water(wc, q.x, q.y) or wc.world.height_at(q.x, q.y) < 0.5:
				all_dry = false
			var hit := false
			for y in range(0, 24):
				if wc.blocks.has(Vector3i(int(floor(q.x)), y, int(floor(q.y)))):
					hit = true
					break
			if not hit:
				all_marked = false
		check(all_dry and all_marked, "%s: every stop is dry land with a marker" % str(sc))
	var cs = CityState.new(int(Scenarios.def("medieval_fort")["seed"]))
	ScenarioApply.apply(cs, "medieval_fort")
	_login(cs, "hero")
	var steps: Array = Story.legend_entries("medieval_fort")
	var spots: Array = []
	var dry := true
	var marked := true
	for e in steps:
		var sp: Vector2 = Book.legend_spot(cs, e)
		spots.append(sp)
		if Boat.is_water(cs, sp.x, sp.y):
			dry = false
		var found := false
		for y in range(0, 24):
			if cs.blocks.has(Vector3i(int(floor(sp.x)), y, int(floor(sp.y)))):
				found = true
				break
		if not found:
			marked = false
	check(dry, "every legend stop is on dry land")
	check(marked, "every legend stop has a built marker")
	check(Book.legend_spot(cs, steps[0]) == spots[0], "legend stops are deterministic")
	var acc: Dictionary = cs.accounts["hero"]
	var m0: int = int(acc["money"])
	var at2 := {"pos": Vector3(spots[1].x, 2.0, spots[1].y), "mine": ""}
	var got2: Array = Book.evaluate(cs, "hero", at2)
	check(not got2.any(func(g): return str(g["id"]).begins_with("lg_")), "a later stop does not unlock before the earlier ones")
	var at1 := {"pos": Vector3(spots[0].x, 2.0, spots[0].y), "mine": ""}
	var got1: Array = Book.evaluate(cs, "hero", at1)
	check(got1.any(func(g): return g["id"] == "lg_medieval_fort_1") and not got1.any(func(g): return g["id"] == "lg_medieval_fort_2"), "reaching the first stop unlocks only the first step")
	check(int(acc["money"]) >= m0 + int(steps[0]["reward"]), "the legend reward is paid")
	check(Book.evaluate(cs, "hero", at1).is_empty() or not Book.evaluate(cs, "hero", at1).any(func(g): return str(g["id"]).begins_with("lg_")), "a step unlocks only once")
	check(Book.evaluate(cs, "hero", at2).any(func(g): return g["id"] == "lg_medieval_fort_2"), "the second stop unlocks after the first")
	var nxt: Dictionary = Book.public_state(cs, "hero")["legend"]
	check(str(nxt.get("id", "")) == "lg_medieval_fort_3", "the book points at the next stop")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and (cs2.accounts["hero"]["book"] as Dictionary).has("lg_medieval_fort_2"), "legend progress survives save/load")
	# پایان افسانه: کالای کمیاب به کیف می‌رسد (فقط یک بار)
	var gem0: int = int(acc["inv"].get("gem", 0))
	var last_ok := true
	for i in range(2, steps.size()):
		var sp3: Vector2 = Book.legend_spot(cs, steps[i])
		var r3: Array = Book.evaluate(cs, "hero", {"pos": Vector3(sp3.x, 2.0, sp3.y), "mine": ""})
		if not r3.any(func(g): return g["id"] == str(steps[i]["id"])):
			last_ok = false
	check(last_ok, "all stops can be completed in order")
	check(int(acc["inv"].get("gem", 0)) == gem0 + 1, "finishing the legend gives the rare item once")
	check(Book.public_state(cs, "hero")["legend"].is_empty(), "no next stop after the legend is finished")
	# تالار پایانی: دیوار، سقف، دروازهٔ آزاد؛ و فقط داخل تالار مرحله را باز می‌کند
	var hs: Vector2 = Book.legend_spot(cs, steps[steps.size() - 1])
	var hx := int(floor(hs.x))
	var hz := int(floor(hs.y))
	var has_roof := false
	var has_wall := false
	var door_blocked := false
	for y in range(0, 40):
		if cs.blocks.has(Vector3i(hx, y, hz)) and str(cs.blocks[Vector3i(hx, y, hz)][0]) == "roof":
			has_roof = true
		if cs.blocks.has(Vector3i(hx - 4, y, hz)) and str(cs.blocks[Vector3i(hx - 4, y, hz)][0]) == "stone":
			has_wall = true
		var gd := maxi(0, int(floor(cs.world.height_at(float(hx + 4) + 0.5, float(hz) + 0.5))))
		if y >= gd and y < gd + 3 and (cs.blocks.has(Vector3i(hx + 4, y, hz)) or cs.blocks.has(Vector3i(hx + 4, y, hz + 1))):
			door_blocked = true
	check(has_roof and has_wall, "the final hall has stone walls and a roof")
	check(not door_blocked, "the hall doorway stays open")
	var cf = CityState.new(int(Scenarios.def("medieval_fort")["seed"]))
	ScenarioApply.apply(cf, "medieval_fort")
	_login(cf, "walker")
	var wacc: Dictionary = cf.accounts["walker"]
	for i in range(steps.size() - 1):
		var sq: Vector2 = Book.legend_spot(cf, steps[i])
		Book.evaluate(cf, "walker", {"pos": Vector3(sq.x, 2.0, sq.y), "mine": ""})
	var outside := Book.evaluate(cf, "walker", {"pos": Vector3(hs.x + 7.0, 2.0, hs.y), "mine": ""})
	check(not outside.any(func(g): return g["id"] == str(steps[steps.size() - 1]["id"])), "standing outside the hall does not finish the legend")
	check(Book.evaluate(cf, "walker", {"pos": Vector3(hs.x + 1.0, 2.0, hs.y), "mine": ""}).any(func(g): return g["id"] == str(steps[steps.size() - 1]["id"])), "standing inside the hall finishes the legend")
	check(wacc.get("book") is Dictionary, "book stays valid")
	check(FWConst.WORLD_LIMIT >= 800.0 and WorldGen.new(102).villages().size() >= 20, "the world is large and has many villages (%d)" % WorldGen.new(102).villages().size())
	var c2 = CityState.new(int(Scenarios.def("frozen_north")["seed"]))
	ScenarioApply.apply(c2, "frozen_north")
	_login(c2, "kid")
	var f1: Dictionary = Story.legend_entries("frozen_north")[0]
	var fs: Vector2 = Book.legend_spot(c2, f1)
	check(Book.evaluate(c2, "kid", {"pos": Vector3(fs.x, 2.0, fs.y), "mine": ""}).any(func(g): return g["id"] == "lg_frozen_north_1"), "winter world legend also works")


func test_npc_friendship() -> void:
	print("== NPC friendship ==")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(4242)
	_login(cs, "pal")
	NpcSim.ensure_npcs(cs)
	var npc: Dictionary = cs.npcs[0]
	var at := Vector2(float(npc["x"]), float(npc["z"]))
	var acc: Dictionary = cs.accounts["pal"]
	check(cs.npc_interact("pal", 99, "", at)["error"] == "no_npc", "unknown NPC is rejected")
	check(cs.npc_interact("pal", int(npc["id"]), "", at + Vector2(FWConst.NPC_TALK_RANGE + 2.0, 0))["error"] == "too_far", "talking needs closeness")
	var r: Dictionary = cs.npc_interact("pal", int(npc["id"]), "", at)
	check(r["ok"] and r["points"] == FWConst.FRIEND_TALK_POINTS and r["level"] == 0 and r["reward"] == 0, "first chat gives points, no reward yet")
	check(cs.npc_interact("pal", int(npc["id"]), "", at)["error"] == "already_talked", "one chat per day")
	var w0: int = int(acc["inv"]["wood"])
	var g: Dictionary = cs.npc_interact("pal", int(npc["id"]), "wood", at)
	check(g["ok"] and int(acc["inv"]["wood"]) == w0 - 1 and g["points"] == FWConst.FRIEND_TALK_POINTS + 2, "gift consumes the item and adds points")
	check(cs.npc_interact("pal", int(npc["id"]), "wood", at)["error"] == "already_gifted", "one gift per day")
	acc["inv"]["gold"] = 1
	cs.day_count += 1
	var g2: Dictionary = cs.npc_interact("pal", int(npc["id"]), "gold", at)
	check(g2["ok"] and g2["points"] == FWConst.FRIEND_TALK_POINTS + 2 + 15, "valuable gifts give more points")
	check(cs.npc_interact("pal", int(npc["id"]), "gold", at)["error"] != "", "no gift without the item")
	acc["friends"][str(npc["id"])] = FWConst.FRIEND_LEVELS[0]
	cs.day_count += 1
	var m0: int = int(acc["money"])
	var npc_m0: int = int(npc["money"])
	var r2: Dictionary = cs.npc_interact("pal", int(npc["id"]), "", at)
	check(r2["ok"] and r2["level"] == 1 and r2["reward"] == FWConst.FRIEND_REWARD[1] and int(acc["money"]) == m0 + int(r2["reward"]), "a friend gives a daily reward")
	check(int(npc["money"]) == npc_m0 - int(r2["reward"]), "the reward is paid from the NPC's own money")
	acc["friends"][str(npc["id"])] = FWConst.FRIEND_MAX - 1
	cs.day_count += 1
	check(cs.npc_interact("pal", int(npc["id"]), "", at)["points"] == FWConst.FRIEND_MAX, "friendship is capped")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.friendship_of(cs2.accounts["pal"], int(npc["id"])) == FWConst.FRIEND_MAX and cs2.day_count == cs.day_count, "friendship and day count survive save/load")
	check(cs.inv_public("pal")["friends"].has(str(npc["id"])), "friendship is reported to the client")
	cs.world_time = 86399.0
	cs.tick(1.0)
	check(cs.day_count == cs2.day_count + 1, "day counter advances when the clock wraps")


func test_god_tools() -> void:
	print("== god tools ==")
	var cs = CityState.new(31337)
	_login(cs, "mortal")
	cs.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
	var land := Vector2.ZERO
	for i in range(40, 200, 3):
		if cs.world.height_at(float(i), 70.0) > 1.5 and not cs.occupied.has(Placement.cell_key(i / 2, 35)):
			land = Vector2(float(i), 70.0)
			break
	check(land != Vector2.ZERO, "found land for the god tools")
	check(cs.god_action("mortal", "add", "tree", land.x, land.y)["error"] == "forbidden", "players cannot create creatures")
	check(cs.god_action("maker", "add", "dragon", land.x, land.y)["error"] == "bad_request", "unknown kinds are rejected")
	check(cs.god_action("maker", "add", "tree", NAN, 1.0)["error"] == "bad_request", "non-finite positions are rejected")
	check(cs.god_action("maker", "add", "tree", 99999.0, 0.0)["error"] == "bad_place", "outside the world is rejected")
	var water := Vector2.ZERO
	for i in range(0, 800, 4):
		if cs.world.height_at(float(i) - 300.0, 40.0) < 0.0:
			water = Vector2(float(i) - 300.0, 40.0)
			break
	if water != Vector2.ZERO:
		check(cs.god_action("maker", "add", "sheep", water.x, water.y)["error"] == "bad_place", "creatures cannot be placed in water")
	var tr: Dictionary = cs.god_action("maker", "add", "tree", land.x, land.y)
	check(tr["ok"] and cs.god.size() == 1, "an admin plants a tree")
	var sh: Dictionary = cs.god_action("maker", "add", "sheep", land.x + 3.0, land.y)
	check(sh["ok"], "an admin creates a sheep")
	var p0 := Vector2(float(cs.god[sh["id"]]["x"]), float(cs.god[sh["id"]]["z"]))
	for i in range(400):
		cs.god_step(0.25)
	var p1 := Vector2(float(cs.god[sh["id"]]["x"]), float(cs.god[sh["id"]]["z"]))
	check(p0.distance_to(p1) > 0.5, "animals wander")
	check(cs.world.height_at(p1.x, p1.y) >= FWConst.GOD_MIN_HEIGHT, "wandering animals stay on land")
	check(Vector2(float(cs.god[tr["id"]]["x"]), float(cs.god[tr["id"]]["z"])) == land, "trees do not move")
	check(cs.god_public().size() == 2 and cs.god_has_animals(), "public list reports both")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.god.size() == 2 and cs2.next_god_id == cs.next_god_id, "creatures survive save/load")
	check(cs.god_action("mortal", "remove", "", land.x, land.y)["error"] == "forbidden", "players cannot remove creatures")
	check(cs.god_action("maker", "remove", "", land.x + FWConst.WORLD_LIMIT + 100.0, land.y)["error"] == "bad_place", "far removal is rejected")
	check(cs.god_action("maker", "remove", "", land.x, land.y)["ok"] and not cs.god.has(tr["id"]), "an admin removes the tree")
	for i in range(FWConst.GOD_MAX):
		cs.god[1000 + i] = {"id": 1000 + i, "kind": "tree", "x": land.x, "z": land.y, "tx": 0.0, "tz": 0.0, "wait": 0.0}
	check(cs.god_action("maker", "add", "tree", land.x, land.y)["error"] == "god_full", "the creature limit is enforced")
	var audit_kinds := []
	for e in cs.audit:
		audit_kinds.append(str(e["action"]))
	check(audit_kinds.has("god_add") and audit_kinds.has("god_remove"), "god actions are audited")


func test_stairs_and_floors() -> void:
	print("== stairs and second floors ==")
	var cs = CityState.new(777)
	_login(cs, "mason")
	var base: Vector3i = _land_cell(cs, 20, 20)
	var x0: int = base.x
	var z0: int = base.z
	var lvs: Array = []
	var bl := 0
	for i in range(4):
		var lv: int = maxi(0, int(floor(cs.world.height_at(x0 + 0.5, z0 + i + 0.5))))
		lvs.append(lv)
		bl = maxi(bl, lv + 1)
	# پایه: سنگ تا زیر سطح bl، سپس سه پله و کف طبقهٔ دوم
	for i in range(4):
		for lvl in range(int(lvs[i]), bl):
			cs._add_block(Vector3i(x0, lvl, z0 + i), "stone", 0, "mason")
	cs._add_block(Vector3i(x0, bl, z0), "stairs", 0, "mason")
	cs._add_block(Vector3i(x0, bl + 1, z0 + 1), "stairs", 0, "mason")
	cs._add_block(Vector3i(x0, bl + 2, z0 + 2), "stairs", 0, "mason")
	cs._add_block(Vector3i(x0, bl + 2, z0 + 3), "wood", 0, "mason")
	var fx := float(x0) + 0.5
	var b := float(bl)
	check(is_equal_approx(cs.surface_at(fx, float(z0) + 0.1, b), b + 0.1), "bottom of the stairs is walkable at ground level")
	# بالا رفتن
	var y := b
	var z := float(z0) + 0.02
	var ok_up := true
	var max_jump := 0.0
	while z < float(z0) + 3.9:
		var ny: float = cs.surface_at(fx, z, y)
		if is_nan(ny) or ny < y - 0.001:
			ok_up = false
			break
		max_jump = maxf(max_jump, ny - y)
		y = ny
		z += 0.05
	check(ok_up, "walking up the stairs never gets blocked or sinks")
	check(max_jump < 0.12, "the stair ramp is smooth (max step %.3f)" % max_jump)
	check(is_equal_approx(y, b + 3.0), "the top of the stairs reaches the second floor (%.2f)" % y)
	check(is_equal_approx(cs.surface_at(fx, float(z0) + 3.5, b + 3.0), b + 3.0), "the upper floor can be stood on")
	check(is_equal_approx(cs.surface_at(fx, float(z0) + 3.5, b), b), "ground below the upper floor is still reachable")
	# پایین آمدن
	var down_ok := true
	z = float(z0) + 3.9
	y = b + 3.0
	while z > float(z0) + 0.02:
		var ny2: float = cs.surface_at(fx, z, y)
		if is_nan(ny2) or ny2 > y + 0.001:
			down_ok = false
			break
		y = ny2
		z -= 0.05
	check(down_ok and absf(y - b) < 0.2, "walking back down returns to the ground")
	# طبقهٔ دوم از کنار بدون پله قابل‌صعود نیست
	var stuck: float = cs.surface_at(fx, float(z0) + 3.5, b + 0.5)
	check(is_nan(stuck) or stuck <= b + 1.5, "a player at ground level cannot jump onto the second floor")
	# جهت پله
	check(is_equal_approx(CityState.stair_t(0.3, 0.8, 0), 0.8) and is_equal_approx(CityState.stair_t(0.3, 0.8, 2), 0.2), "stairs rise along +z or −z")
	check(is_equal_approx(CityState.stair_t(0.3, 0.8, 1), 0.3) and is_equal_approx(CityState.stair_t(0.3, 0.8, 3), 0.7), "stairs rise along +x or −x")
	# متا: رنگ + جهت
	var free: Vector3i = _land_cell(cs, 70, 20)
	check(cs.place_block("mason", 1, free.x, free.y, free.z, "stairs", 16 * 1 + 0)["ok"], "stairs can be placed with a facing")
	check(cs.paint_block("mason", free.x, free.y, free.z, 4)["color"] == 20, "painting keeps the stair facing")
	check(cs.place_block("mason", 2, free.x + 1, free.y, free.z, "stairs", 99)["error"] == "bad_request", "invalid block meta is rejected")
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(int(back.blocks[free][1]) == 20, "facing and colour survive saving")
	var mirror = CityState.new(777)
	for batch in cs.block_batches():
		var i := 0
		while i + 4 < batch.size():
			mirror.apply_block(batch[i], batch[i + 1], batch[i + 2], batch[i + 3], batch[i + 4])
			i += 5
	check(is_equal_approx(mirror.surface_at(fx, float(z0) + 1.5, b + 1.0), cs.surface_at(fx, float(z0) + 1.5, b + 1.0)), "client mirror computes the same stair height")


func test_p2p_trade() -> void:
	print("== direct player trade ==")
	var cs = CityState.new(777)
	_login(cs, "seller")
	_login(cs, "buyer")
	var s_inv: Dictionary = cs.accounts["seller"]["inv"]
	var b_inv: Dictionary = cs.accounts["buyer"]["inv"]
	check(cs.make_offer("seller", "seller", "wood", 1, 1)["error"] == "bad_request", "no offers to yourself")
	check(cs.make_offer("seller", "buyer", "wood", 9999, 1)["error"] == "bad_request", "absurd amounts are rejected")
	check(cs.make_offer("seller", "buyer", "wood", 400, 1)["error"] == "no_items", "you must own what you offer")
	var r: Dictionary = cs.make_offer("seller", "buyer", "wood", 10, 50)
	check(r["ok"], "a valid offer is created")
	var wood0: int = int(s_inv["wood"])
	check(cs.answer_offer("seller", r["id"], true)["error"] == "no_offer", "only the addressed player can answer")
	cs.accounts["buyer"]["money"] = 10
	check(cs.answer_offer("buyer", r["id"], true)["error"] == "no_money", "buyer needs the coins")
	check(not cs.offers.has(r["id"]), "an answered offer is consumed")
	var r2: Dictionary = cs.make_offer("seller", "buyer", "wood", 10, 50)
	cs.accounts["buyer"]["money"] = 200
	var sm: int = cs.money_of("seller")
	var res: Dictionary = cs.answer_offer("buyer", r2["id"], true)
	check(res["ok"] and res["accepted"], "buyer accepts")
	check(int(s_inv["wood"]) == wood0 - 10 and int(b_inv["wood"]) == int(FWConst.START_ITEMS["wood"]) + 10, "materials move to the buyer")
	check(cs.money_of("buyer") == 150 and cs.money_of("seller") == sm + 50, "coins move to the seller")
	var r3: Dictionary = cs.make_offer("seller", "buyer", "stone", 5, 10)
	check(cs.answer_offer("buyer", r3["id"], false)["accepted"] == false, "an offer can be declined")
	var r4: Dictionary = cs.make_offer("seller", "buyer", "stone", 5, 10)
	s_inv["stone"] = 0
	check(cs.answer_offer("buyer", r4["id"], true)["error"] == "offer_invalid", "an offer is re-checked when accepted")
	for i in range(FWConst.OFFER_MAX_PENDING):
		cs.make_offer("seller", "buyer", "dirt", 1, 1)
	check(cs.make_offer("seller", "buyer", "dirt", 1, 1)["error"] == "limit", "pending offers per player are limited")
	cs.tick(FWConst.OFFER_TTL + 1.0)
	check(cs.offers.is_empty(), "offers expire")


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


func _terrain_spot(cs, lo: float, hi: float) -> Vector2:
	## نقطهٔ بیرون از شهر با ارتفاع پایهٔ مشخص که همسایگی‌اش ساختمانی ندارد.
	for xi in range(-90, 0, 4):
		for zi in range(-90, 0, 4):
			var h: float = cs.world.base_height_at(float(xi), float(zi))
			if h >= lo and h <= hi:
				return Vector2(float(xi), float(zi))
	return Vector2(NAN, NAN)


func test_terrain() -> void:
	print("== terrain edits: pits, lakes, filling (protocol 16) ==")
	var w := WorldGen.new(4343)
	var p := Vector2(37.0, 51.0)
	var base: float = w.base_height_at(p.x, p.y)
	check(is_equal_approx(w.height_at(p.x, p.y), base), "with no edits the height is the seed terrain")
	var ix := int(round(p.x / FWConst.TERRAIN_EDIT_STEP))
	var iz := int(round(p.y / FWConst.TERRAIN_EDIT_STEP))
	var vx: float = float(ix) * FWConst.TERRAIN_EDIT_STEP
	var vz: float = float(iz) * FWConst.TERRAIN_EDIT_STEP
	w.set_edit(ix, iz, -8)
	check(is_equal_approx(w.height_at(vx, vz), w.base_height_at(vx, vz) - 1.0), "a vertex edit moves that vertex by units/8 metres")
	var mid: float = w.height_at(vx + 1.0, vz)
	check(absf(mid - (w.base_height_at(vx + 1.0, vz) - 0.5)) < 0.3, "height blends smoothly between edited and neighbouring vertices")
	w.set_edit(ix, iz, -9999)
	check(w.edit_units(ix, iz) == FWConst.TERRAIN_ADMIN_MIN_UNITS, "edits are clamped to the admin maximum depth")
	w.set_edit(ix, iz, 9999)
	check(w.edit_units(ix, iz) == FWConst.TERRAIN_ADMIN_MAX_UNITS, "edits are clamped to the admin maximum height")
	w.set_edit(ix, iz, 0)
	check(w.edits.is_empty(), "setting an edit to zero removes it")

	var cs = CityState.new(4343)
	_login(cs, "digger")
	var spot := _terrain_spot(cs, 1.0, 4.0)
	check(not is_nan(spot.x), "found open land outside the city for digging")
	var h0: float = cs.world.height_at(spot.x, spot.y)
	var dirt0: int = int(cs.accounts["digger"]["inv"].get("dirt", 0)) + int(cs.accounts["digger"]["inv"].get("sand", 0))
	check(cs.dig("digger", spot.x, spot.y, "axe", spot)["error"] == "wrong_tool", "terraforming needs the shovel")
	check(cs.dig("digger", spot.x, spot.y, "shovel", spot + Vector2(FWConst.GATHER_RANGE + 3.0, 0))["error"] == "too_far", "terraforming needs closeness")
	var r: Dictionary = cs.dig("digger", spot.x, spot.y, "shovel", spot)
	check(r["ok"] and r["changes"].size() == 9, "one dig changes a 3x3 patch of vertices")
	check(cs.world.height_at(spot.x, spot.y) < h0 - 0.2, "digging lowers the ground")
	var dirt1: int = int(cs.accounts["digger"]["inv"].get("dirt", 0)) + int(cs.accounts["digger"]["inv"].get("sand", 0))
	check(dirt1 == dirt0 + 1, "digging yields one dirt or sand")

	# دریاچه: آن‌قدر بکن تا کف زیر سطح دریا برود
	var digs := 1
	while cs.world.height_at(spot.x, spot.y) >= 0.0 and digs < 60:
		var rr: Dictionary = cs.dig("digger", spot.x, spot.y, "shovel", spot)
		if not rr["ok"]:
			break
		digs += 1
	check(cs.world.height_at(spot.x, spot.y) < 0.0, "a deep enough pit drops below sea level")
	check(cs.world.biome_at(spot.x, spot.y) == "water", "the pit counts as water (a lake)")
	# عمق محدود است
	var guard := 0
	var last: Dictionary = {"ok": true}
	while last["ok"] and guard < 100:
		last = cs.dig("digger", spot.x, spot.y, "shovel", spot)
		guard += 1
	check(last["error"] == "terrain_limit", "the pit stops at the maximum depth")
	check(cs.world.edit_units(int(round(spot.x / 2.0)), int(round(spot.y / 2.0))) == FWConst.TERRAIN_MIN_UNITS, "the centre sits exactly at the depth limit")

	# پر کردن
	var acc: Dictionary = cs.accounts["digger"]
	var before: float = cs.world.height_at(spot.x, spot.y)
	acc["inv"]["dirt"] = 0
	acc["inv"]["sand"] = 0
	check(cs.fill("digger", spot.x, spot.y, "shovel", spot)["error"] == "no_material", "filling needs dirt or sand")
	acc["inv"]["dirt"] = 5
	var f: Dictionary = cs.fill("digger", spot.x, spot.y, "shovel", spot)
	check(f["ok"] and int(acc["inv"]["dirt"]) == 4, "filling spends one dirt")
	check(cs.world.height_at(spot.x, spot.y) > before + 0.3, "filling raises the ground")

	# قفل‌ها
	var key := Placement.cell_key(int(floor(spot.x / 2.0)), int(floor(spot.y / 2.0)))
	cs.block_cells[key] = 1
	check(cs.dig("digger", spot.x, spot.y, "shovel", spot)["error"] == "terrain_locked", "ground under blocks cannot be reshaped")
	cs.block_cells.erase(key)
	var c0: float = FWConst.CITY_SIZE * 0.5
	check(cs.fill("digger", c0, c0, "shovel", Vector2(c0, c0))["error"] == "reserved", "the plaza ground is protected from players")
	var far_x: float = FWConst.CITY_SIZE + FWConst.WORLD_LIMIT + 50.0
	check(cs.dig("digger", far_x, far_x, "shovel", Vector2(far_x, far_x))["error"] == "out_of_bounds", "terraforming beyond the world edge is refused")

	# سقف تعداد تغییرات
	var cs2 = CityState.new(4343)
	_login(cs2, "digger")
	for i in range(FWConst.TERRAIN_MAX_EDITS - 3):
		cs2.world.edits["%d,%d" % [5000 + i, 5000]] = 1
	var sp2 := _terrain_spot(cs2, 1.0, 4.0)
	check(cs2.dig("digger", sp2.x, sp2.y, "shovel", sp2)["error"] == "terrain_full", "the number of terrain edits is capped")

	# بیل آهنی: ۵×۵ و قفل‌های گسترده‌تر
	var cs3 = CityState.new(4343)
	_login(cs3, "smith")
	cs3.accounts["smith"]["tools"] = {"shovel": true}
	var sp3 := _terrain_spot(cs3, 1.0, 4.0)
	var ri: Dictionary = cs3.dig("smith", sp3.x, sp3.y, "shovel", sp3)
	check(ri["ok"] and ri["changes"].size() == 25 and ri["count"] == 2, "an iron shovel digs a 5x5 patch and yields double")
	var v3: Vector2i = CityState.terrain_vertex(sp3.x + 9.0, sp3.y)
	cs3.block_cells[Placement.cell_key(v3.x - 3, v3.y)] = 1
	check(cs3.terrain_check("player", v3, 1) == "" and cs3.terrain_check("player", v3, 2) == "terrain_locked", "the iron shovel needs a wider clear area")

	# رودخانه
	var rv := WorldGen.new(4343)
	var cc: float = FWConst.CITY_SIZE * 0.5
	var near_ok := true
	for k in range(0, 360, 10):
		var q := Vector2(cc, cc) + Vector2(FWConst.RIVER_MIN_DIST - 1.0, 0.0).rotated(deg_to_rad(float(k)))
		near_ok = near_ok and rv.river_weight(q.x, q.y) == 0.0
	check(near_ok, "no river inside the city's surroundings")
	var wet := 0
	for xi in range(-380, 520, 8):
		for zi in range(-380, 520, 8):
			if rv.river_weight(float(xi), float(zi)) > 0.9 and rv.height_at(float(xi), float(zi)) < 0.0 and rv.biome_at(float(xi), float(zi)) == "water":
				wet += 1
	check(wet > 20, "rivers carve water channels in the world (%d wet samples)" % wet)
	check(is_equal_approx(rv.height_at(-200.0, -200.0), WorldGen.new(4343).height_at(-200.0, -200.0)), "river terrain is deterministic")

	# ذخیره، بارگذاری و همگام‌سازی
	var flat: PackedInt32Array = cs.terrain_flat()
	check(flat.size() == cs.world.edits.size() * 3, "terrain is exported as triples")
	var parsed = JSON.parse_string(JSON.stringify(cs.to_dict()))
	var back = CityState.from_dict(parsed)
	check(back != null and back.world.edits == cs.world.edits, "terrain edits survive a save and reload")
	check(is_equal_approx(back.world.height_at(spot.x, spot.y), cs.world.height_at(spot.x, spot.y)), "a reloaded city has the same ground")
	var twin := WorldGen.new(4343)
	var i2 := 0
	while i2 + 2 < flat.size():
		twin.set_edit(flat[i2], flat[i2 + 1], flat[i2 + 2])
		i2 += 3
	check(is_equal_approx(twin.height_at(spot.x + 1.3, spot.y - 0.7), cs.world.height_at(spot.x + 1.3, spot.y - 0.7)), "a client rebuilding from the list sees identical ground")
	var old_save: Dictionary = parsed.duplicate(true)
	old_save.erase("terrain")
	var legacy = CityState.from_dict(old_save)
	check(legacy != null and legacy.world.edits.is_empty(), "older saves without terrain still load")

	# کلاینت
	var gc := Node.new()
	gc.set_script(GameClient)
	root.add_child(gc)
	gc.mirror = CityState.new(4343)
	var areas: Array = []
	gc.terrain_changed.connect(func(x0, z0, x1, z1): areas.append([x0, z0, x1, z1]))
	gc.on_terrain(flat)
	check(gc.mirror.world.edits == cs.world.edits, "the client mirror applies the full terrain list")
	check(areas.size() == 1 and areas[0][0] < areas[0][2], "the client announces which area to rebuild")
	gc.on_terrain_edit(PackedInt32Array([ix, iz, -4]))
	check(gc.mirror.world.edit_units(ix, iz) == -4, "the client applies a single terrain edit")
	gc.queue_free()


func _first_node(layout: Dictionary, kind: String) -> Dictionary:
	for n in layout["nodes"]:
		if str(n["kind"]) == kind:
			return n
	return {}


func test_mines() -> void:
	print("[mines]")
	var w1 := WorldGen.new(2026)
	var w2 := WorldGen.new(2026)
	var w3 := WorldGen.new(99)
	var es: Array = w1.mine_entrances()
	check(es.size() >= 8, "mountains have mine entrances (%d)" % es.size())
	var same := es.size() == w2.mine_entrances().size()
	if same:
		for i in range(es.size()):
			if es[i]["id"] != w2.mine_entrances()[i]["id"] or es[i]["x"] != w2.mine_entrances()[i]["x"]:
				same = false
	check(same, "entrances are deterministic per seed")
	check(w3.mine_entrances().size() > 0 and w3.mine_entrances()[0]["id"] != es[0]["id"] or w3.mine_entrances().size() != es.size(), "different seeds give different entrances")
	var on_mountain := true
	var outside := true
	var ids := {}
	for e in es:
		var h: float = w1.base_height_at(float(e["x"]), float(e["z"]))
		if h < FWConst.MINE_MIN_HEIGHT or h > FWConst.MINE_MAX_HEIGHT:
			on_mountain = false
		if Vector2(float(e["x"]), float(e["z"])).distance_to(Vector2(64, 64)) < 130.0:
			outside = false
		ids[e["id"]] = true
	check(on_mountain, "every entrance stands on a mountain")
	check(outside and ids.size() == es.size(), "entrances are outside the city and unique")
	check(w1.mine_entrance(str(es[0]["id"]))["x"] == es[0]["x"] and w1.mine_entrance("nope").is_empty(), "entrance lookup by id")
	var near: Dictionary = w1.nearest_mine_entrance(float(es[0]["x"]) + 1.0, float(es[0]["z"]), 5.0)
	check(near.get("id", "") == es[0]["id"] and w1.nearest_mine_entrance(float(es[0]["x"]) + 60.0, float(es[0]["z"]), 5.0).is_empty(), "nearest entrance respects the range")

	# --- چیدمان تونل‌ها ---
	var e0: Dictionary = es[0]
	var l1: Dictionary = Mine.layout(2026, int(e0["mx"]), int(e0["mz"]))
	var l2: Dictionary = Mine._generate(2026, int(e0["mx"]), int(e0["mz"]))
	check(l1["tiles"] == l2["tiles"] and l1["nodes"].size() == l2["nodes"].size(), "mine layout is deterministic")
	var l3: Dictionary = Mine._generate(2026, int(e0["mx"]) + 1, int(e0["mz"]))
	check(l3["tiles"] != l1["tiles"], "different mines have different tunnels")
	var border_closed := true
	for i in range(Mine.SIZE):
		if Mine.tile_open(l1, i, 0) or Mine.tile_open(l1, i, Mine.SIZE - 1) or Mine.tile_open(l1, 0, i) or Mine.tile_open(l1, Mine.SIZE - 1, i):
			border_closed = false
	check(border_closed, "mine is enclosed by rock")
	var open_n := 0
	var unreachable := 0
	for i in range(Mine.SIZE * Mine.SIZE):
		if int(l1["tiles"][i]) == 1:
			open_n += 1
			if int(l1["dist"][i]) < 0:
				unreachable += 1
	check(open_n > 150 and unreachable == 0, "all tunnels are reachable from the entrance (%d tiles)" % open_n)
	var sp: Vector2 = Mine.spawn_point(l1)
	check(Mine.walkable(l1, sp.x, sp.y), "entry point is walkable")
	check(not Mine.walkable(l1, 0.5, 0.5) and not Mine.walkable(l1, NAN, 1.0) and not Mine.walkable(l1, -3.0, 4.0), "rock and invalid points are not walkable")
	var edge_x: float = floorf(sp.x / Mine.TILE) * Mine.TILE
	check(Mine.walkable(l1, sp.x, sp.y) and (not Mine.tile_open(l1, int(sp.x / Mine.TILE) - 1, int(sp.y / Mine.TILE))) == (not Mine.walkable(l1, edge_x + 0.1, sp.y)), "characters keep a margin from walls")
	var nodes: Array = l1["nodes"]
	check(nodes.size() >= 25, "mine has plenty of ore nodes (%d)" % nodes.size())
	var kinds := {}
	var pos_seen := {}
	var all_ok := true
	for n in nodes:
		kinds[n["kind"]] = int(kinds.get(n["kind"], 0)) + 1
		pos_seen["%.2f,%.2f" % [n["x"], n["z"]]] = true
		if not Mine.tile_open(l1, int(n["tx"]), int(n["tz"])) or int(l1["dist"][Mine.tile_index(int(n["tx"]), int(n["tz"]))]) < 3:
			all_ok = false
		if int(n["idx"]) != nodes.find(n):
			all_ok = false
	check(all_ok and pos_seen.size() == nodes.size(), "ore sits in reachable tunnels, away from the door, with stable indices")
	check(int(kinds.get("chest", 0)) == FWConst.MINE_CHESTS, "mine hides exactly %d treasure chests" % FWConst.MINE_CHESTS)
	var shallow := 0
	var deep_valuable := 0
	for n in nodes:
		var pct: int = int(n["depth"]) * 100 / maxi(int(l1["max_dist"]), 1)
		if pct < 30 and (n["kind"] == "gold" or n["kind"] == "gem"):
			shallow += 1
		if pct >= 65 and (n["kind"] == "gold" or n["kind"] == "gem" or n["kind"] == "chest"):
			deep_valuable += 1
	check(shallow == 0 and deep_valuable >= 2, "valuable ore is found deep, not near the door")
	var all_kinds := {}
	for e in es:
		var lx: Dictionary = Mine.layout(2026, int(e["mx"]), int(e["mz"]))
		for n in lx["nodes"]:
			all_kinds[n["kind"]] = true
	check(all_kinds.has("stone") and all_kinds.has("coal") and all_kinds.has("iron") and all_kinds.has("gold") and all_kinds.has("gem") and all_kinds.has("chest"), "all ore kinds occur across mines")
	check(Mine.parse_id("3,-2") == Vector2i(3, -2) and Mine.parse_id("bad").x == -99999 and Mine.parse_id("1,x").x == -99999, "mine ids parse safely")

	# --- منطق شهر ---
	var cs = CityState.new(2026)
	_login(cs, "miner")
	var acc: Dictionary = cs.accounts["miner"]
	var mid: String = str(e0["id"])
	var at := Vector2(float(e0["x"]), float(e0["z"]))
	check(cs.mine_enter_error("miner", mid, at + Vector2(FWConst.MINE_ENTER_RANGE + 5.0, 0)) == "too_far", "must stand at the entrance to enter")
	check(cs.mine_enter_error("miner", "9,9", at) == "no_mine" and cs.mine_enter_error("ghost", mid, at) == "no_account", "unknown mine and unknown player are rejected")
	check(cs.mine_enter_error("miner", mid, at + Vector2(2.0, 0)) == "", "standing at the entrance allows entering")
	var layout: Dictionary = cs.mine_layout(mid)
	var stone: Dictionary = _first_node(layout, "stone")
	if stone.is_empty():
		stone = _first_node(layout, "coal")
	var sat := Vector2(float(stone["x"]), float(stone["z"]))
	check(cs.mine_gather("miner", mid, int(stone["idx"]), sat + Vector2(FWConst.MINE_GATHER_RANGE + 3.0, 0))["error"] == "too_far", "ore needs closeness")
	check(cs.mine_gather("miner", mid, 9999, sat)["error"] == "no_resource" and cs.mine_gather("miner", "9,9", 0, sat)["error"] == "no_mine", "bad ore index and bad mine are rejected")
	var item: String = FWConst.MINE_ORES[str(stone["kind"])]["item"]
	var before: int = int(acc["inv"].get(item, 0))
	var g: Dictionary = cs.mine_gather("miner", mid, int(stone["idx"]), sat)
	check(g["ok"] and g["item"] == item and int(acc["inv"][item]) == before + int(stone["n"]), "mining gives the ore")
	check(cs.mine_gather("miner", mid, int(stone["idx"]), sat)["error"] == "depleted", "mined ore is depleted")
	check(cs.mine_depleted_list(mid).has(int(stone["idx"])), "depleted list reports the mined ore")
	check(cs.mine_depleted_list("0,0").is_empty(), "depleted list is per mine")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.mine_depleted_list(mid).has(int(stone["idx"])), "mined ore survives a save/load")
	cs.tick(float(FWConst.MINE_ORES[str(stone["kind"])]["respawn"]) + 1.0)
	check(not cs.mine_respawned.is_empty() and cs.mine_respawned[0][0] == mid and int(cs.mine_respawned[0][1]) == int(stone["idx"]), "ore grows back and is announced")
	check(cs.mine_gather("miner", mid, int(stone["idx"]), sat)["ok"], "respawned ore can be mined again")

	# --- طلا و جواهر کلنگ آهنی می‌خواهند؛ صندوق پول می‌دهد ---
	var gold: Dictionary = {}
	var gold_mine := ""
	for e in es:
		gold = _first_node(Mine.layout(2026, int(e["mx"]), int(e["mz"])), "gold")
		if not gold.is_empty():
			gold_mine = str(e["id"])
			break
	var gat := Vector2(float(gold["x"]), float(gold["z"]))
	check(cs.mine_gather("miner", gold_mine, int(gold["idx"]), gat)["error"] == "needs_better_tool", "gold needs an iron pickaxe")
	acc["inv"]["iron"] = 10
	acc["inv"]["wood"] = 10
	cs.craft("miner", "upgrade_pickaxe", 1)
	var gg: Dictionary = cs.mine_gather("miner", gold_mine, int(gold["idx"]), gat)
	check(gg["ok"] and gg["item"] == "gold" and int(gg["count"]) == int(gold["n"]) + 1, "iron pickaxe mines gold with a bonus")
	var chest: Dictionary = _first_node(cs.mine_layout(mid), "chest")
	var cat := Vector2(float(chest["x"]), float(chest["z"]))
	var m0: int = int(acc["money"])
	var cr: Dictionary = cs.mine_gather("miner", mid, int(chest["idx"]), cat)
	check(cr["ok"] and cr["treasure"] and int(acc["money"]) == m0 + int(chest["reward"]), "mine chest pays its fixed reward")
	check(int(chest["reward"]) >= 150 and int(chest["reward"]) <= 500, "mine chest reward is in range")
	check(cs.mine_gather("miner", mid, int(chest["idx"]), cat)["error"] == "depleted", "opened mine chest is empty")
	acc["inv"]["coal"] = 5
	acc["inv"]["gem"] = 2
	var m1: int = int(acc["money"])
	check(cs.trade("miner", "coal", 5, false)["ok"] and cs.trade("miner", "gem", 2, false)["ok"] and int(acc["money"]) > m1 + 100, "coal and gems sell at the market")
	acc["inv"][item] = FWConst.ITEM_CAP
	cs.mine_depleted.clear()
	check(cs.mine_gather("miner", mid, int(stone["idx"]), sat)["error"] == "inv_full", "full inventory blocks mining")

	# --- ساخت و تغییر زمین کنار ورودی ممنوع است ---
	var ex := int(floor(float(e0["x"])))
	var ez := int(floor(float(e0["z"])))
	check(cs.check_block(FWConst.ROLE_PLAYER, ex, 20, ez, "stone") == "near_mine", "blocks cannot be placed at a mine entrance")
	check(cs.terrain_check(FWConst.ROLE_PLAYER, Vector2i(int(round(float(e0["x"]) / 2.0)), int(round(float(e0["z"]) / 2.0)))) == "near_mine", "terrain near a mine entrance is locked")
	check(cs.check_block(FWConst.ROLE_PLAYER, ex + 40, 20, ez, "stone") != "near_mine", "building far from the entrance is not blocked by it")


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


func test_world_rules() -> void:
	print("[world rules]")
	var cs = CityState.new(31337)
	_login(cs, "mortal")
	cs.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
	var land := Vector2.ZERO
	for i in range(40, 200, 3):
		if cs.world.height_at(float(i), 70.0) > 1.5 and cs._god_spot_ok(float(i), 70.0):
			land = Vector2(float(i), 70.0)
			break
	check(land != Vector2.ZERO, "found land for world rules")
	check(cs.ignite("mortal", land.x, land.y)["error"] == "forbidden", "players cannot start fires")
	check(cs.plant_grove("mortal", land.x, land.y)["error"] == "forbidden", "players cannot plant groves")
	check(cs.ignite("maker", land.x, land.y)["error"] == "no_target", "fire needs a tree")
	check(cs.ignite("maker", NAN, 1.0)["error"] == "bad_request", "fire rejects non-finite positions")
	var gr: Dictionary = cs.plant_grove("maker", land.x, land.y)
	check(gr["ok"] and int(gr["planted"]) > 0 and cs.god.size() == int(gr["planted"]), "grove plants trees")
	for id in cs.god:
		check(str(cs.god[id]["kind"]) == "tree", "grove only plants trees")
		break
	check(cs.god_public()[0].size() == 5 and int(cs.god_public()[0][4]) == 0, "public list carries a fire flag (off)")
	# آتش: یک درخت می‌سوزد، به همسایه‌ها سرایت می‌کند و همه می‌سوزند.
	var first_id: int = cs.god.keys()[0]
	var fx: float = float(cs.god[first_id]["x"])
	var fz: float = float(cs.god[first_id]["z"])
	check(cs.ignite("maker", fx, fz)["ok"] and cs.fire.has(first_id), "an admin ignites a tree")
	check(int(cs.god_public()[0][4]) == 1 or cs.god_public().any(func(e): return int(e[4]) == 1), "burning tree is flagged")
	var any_change := false
	for i in range(60):
		if cs.fire_step(1.0):
			any_change = true
	check(any_change, "fire changes the world")
	check(cs.fire.is_empty(), "fire burns out")
	check(cs.god.size() < int(gr["planted"]), "burned trees are gone")
	# باران آتش را زود خاموش می‌کند و سرایت را کم می‌کند.
	var dry = CityState.new(31337)
	var wet = CityState.new(31337)
	for c in [dry, wet]:
		c.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
		c.plant_grove("maker", land.x, land.y)
		c.ignite("maker", float(c.god[c.god.keys()[0]]["x"]), float(c.god[c.god.keys()[0]]["z"]))
	wet.weather = "rain"
	var before_n: int = dry.god.size()
	for i in range(4):
		dry.fire_step(1.0)
		wet.fire_step(1.0)
	check(before_n > 0 and wet.fire.size() <= dry.fire.size(), "rain does not make fire worse")
	for i in range(8):
		wet.fire_step(1.0)
	check(wet.fire.is_empty(), "rain puts the fire out quickly")
	# درخت‌های طبیعی Seed هم می‌سوزند و بعد دوباره می‌رویند.
	var nat = CityState.new(31337)
	nat.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
	var spot := Vector2.ZERO
	var cluster := 0
	for rx in range(60, 140):
		for rz in range(60, 140):
			var nd: Dictionary = nat.world.resource_in_cell(rx, rz)
			if nd.is_empty() or str(nd["kind"]) != "tree":
				continue
			var cnt := 0
			for ox in range(-2, 3):
				for oz in range(-2, 3):
					var o2: Dictionary = nat.world.resource_in_cell(rx + ox, rz + oz)
					if not o2.is_empty() and str(o2["kind"]) == "tree":
						cnt += 1
			if cnt > cluster:
				cluster = cnt
				spot = Vector2(float(nd["x"]), float(nd["z"]))
	check(cluster >= 5, "found a dense natural forest")
	var ni: Dictionary = nat.ignite("maker", spot.x, spot.y)
	check(ni["ok"] and ni.has("natural") and nat.nfire.size() == 1 and nat.nfire_dirty, "natural tree ignites")
	check(nat.nfire_flat().size() == 2, "natural fire is exported")
	for i in range(60):
		nat.fire_step(1.0)
	check(nat.nfire.is_empty(), "natural fire burns out")
	check(nat.depleted.size() >= 1 and nat.burned.size() == nat.depleted.size(), "burned trees vanish like chopped ones")
	check(nat.depleted.size() > 1, "fire spreads through a natural forest")
	check(nat.nfire.size() <= FWConst.NFIRE_MAX, "natural fire respects the cap")
	var first_key: String = nat.burned[0]
	check(float(nat.depleted[first_key]) > 200.0, "burned trees regrow only after a long time")
	# قطع‌کردن درخت در حال سوختن آتش را قطع می‌کند.
	var chop = CityState.new(31337)
	chop.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
	chop.ignite("maker", spot.x, spot.y)
	var ck: String = chop.nfire.keys()[0]
	chop.depleted[ck] = 5.0
	chop.fire_step(1.0)
	check(chop.nfire.is_empty(), "a chopped burning tree stops burning")
	# قانون رشد جنگل
	var gz = CityState.new(31337)
	gz.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
	gz.plant_grove("maker", land.x, land.y)
	var n0: int = gz.god.size()
	check(not gz.growth_step(1000.0) and gz.god.size() == n0, "no growth while the law is off")
	_login(gz, "mortal")
	check(gz.set_world("mortal", "forest_growth", true)["error"] == "forbidden", "players cannot change world laws")
	check(gz.set_world("maker", "forest_growth", true)["ok"] and gz.forest_growth and bool(gz.world_public()["forest_growth"]), "admin enables forest growth")
	for i in range(80):
		gz.growth_step(FWConst.GROW_INTERVAL)
	check(gz.god.size() > n0, "forests spread with the law on")
	check(gz.god.size() <= FWConst.GROW_CAP, "growth respects the cap")
	for id in gz.god:
		check(gz._god_spot_ok(float(gz.god[id]["x"]), float(gz.god[id]["z"])), "grown trees stand on valid ground")
		break
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(gz.to_dict())))
	check(back != null and back.forest_growth and back.god.size() == gz.god.size(), "law and trees survive save and load")
	check(not CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict()))).forest_growth, "law defaults to off")


func test_day_night_and_creative_switch() -> void:
	print("== Day/night jump and creative switch ==")
	var cs = CityState.new(5151)
	_login(cs, "boss")
	_login(cs, "pal")
	cs.accounts["boss"]["role"] = FWConst.ROLE_WORLD_ADMIN
	cs.accounts["pal"]["role"] = FWConst.ROLE_PLAYER
	cs.world_time = 3.0 * 3600.0
	check(not cs.set_world("pal", "day_time", "day")["ok"], "a normal player cannot change the time of day")
	check(cs.set_world("boss", "day_time", "day")["ok"] and is_equal_approx(cs.world_time, 12.0 * 3600.0), "admin turns night into day")
	check(cs.set_world("boss", "day_time", "night")["ok"] and is_equal_approx(cs.world_time, 0.0), "admin turns day into night")
	check(not cs.set_world("boss", "day_time", "dusk")["ok"], "unknown time of day is refused")
	# حالت خلاقانه روی جهان قدیمی: پس از بارگذاری با force_creative اعمال می‌شود.
	var old = CityState.new(5152)
	_login(old, "boss")
	old.accounts["boss"]["money"] = 1
	check(not old.creative and not old._can_pay(old.accounts["boss"], 500), "an old non-creative world charges coins")
	var loaded = CityState.from_dict(old.to_dict())
	loaded.creative = true   # همان کاری که game_server.start با force_creative می‌کند
	check(loaded._can_pay(loaded.accounts["boss"], 500) and loaded._pay(loaded.accounts["boss"], 500) and int(loaded.accounts["boss"]["money"]) == 1, "switching an old world to creative makes everything free")
	check(loaded.has_car(loaded.accounts["boss"]) and loaded.has_boat(loaded.accounts["boss"]), "vehicles are free in a world switched to creative")


func test_clear_resource() -> void:
	print("== Hold-to-remove natural resources ==")
	var cs = CityState.new(6161)
	_login(cs, "boss")
	_login(cs, "pal")
	cs.accounts["boss"]["role"] = FWConst.ROLE_WORLD_ADMIN
	cs.accounts["pal"]["role"] = FWConst.ROLE_PLAYER
	var found := {}
	for rz in range(0, 40):
		for rx in range(0, 40):
			var n: Dictionary = cs.world.resource_in_cell(rx, rz)
			if not n.is_empty() and found.is_empty():
				found = {"rx": rx, "rz": rz, "x": float(n["x"]), "z": float(n["z"])}
	check(not found.is_empty(), "the test world has a natural resource")
	if found.is_empty():
		return
	var at := Vector2(found["x"], found["z"])
	var rx: int = found["rx"]
	var rz: int = found["rz"]
	check(cs.gather("pal", rx, rz, "remove", at)["error"] == "forbidden", "a normal player cannot remove resources")
	check(cs.gather("boss", rx, rz, "remove", at + Vector2(50, 50))["error"] == "too_far", "removal needs the admin to be close")
	var r: Dictionary = cs.gather("boss", rx, rz, "remove", at)
	check(r["ok"] and r.get("cleared", false), "the admin removes a tree or rock by holding")
	check(cs.depleted.has("%d,%d" % [rx, rz]), "the resource is marked gone for everyone")
	cs.tick(100000.0)
	check(cs.depleted.has("%d,%d" % [rx, rz]), "a removed resource never grows back")
	check(cs.gather("boss", rx, rz, "remove", at)["error"] == "depleted", "removing it twice is refused")
	var back = CityState.from_dict(cs.to_dict())
	check(back.depleted.has("%d,%d" % [rx, rz]), "the removal survives a save and load")


func test_creative() -> void:
	print("[creative]")
	var sv = CityState.new(12345)
	var cr = CityState.new(12345)
	cr.creative = true
	_login(sv, "sam")
	_login(cr, "cora")
	for c in [sv, cr]:
		var nm := "sam" if c == sv else "cora"
		c.accounts[nm]["money"] = 0
		c.accounts[nm]["inv"] = {}
	check(sv.place_building("sam", 1, "house", 10, 10)["error"] == "no_money", "survival: no money, no house")
	var rb: Dictionary = cr.place_building("cora", 1, "house", 10, 10)
	check(rb["ok"] and int(cr.accounts["cora"]["money"]) == 0, "creative: house is free")
	var cell := Vector3i(40, 0, 40)
	var h: float = cr.world.height_at(40.5, 40.5)
	cell.y = maxi(0, int(floor(h)))
	check(not sv.place_block("sam", 2, cell.x, cell.y, cell.z, "stone", 0)["ok"], "survival: block needs materials")
	check(cr.place_block("cora", 2, cell.x, cell.y, cell.z, "stone", 0)["ok"], "creative: block needs no materials")
	check(cr.tool_tier(cr.accounts["cora"], "pickaxe") == 2 and sv.tool_tier(sv.accounts["sam"], "pickaxe") == 1, "creative: every tool is upgraded")
	var rc: Dictionary = cr.craft("cora", "plank", 1) if FWConst.RECIPES.has("plank") else {"ok": true}
	check(rc["ok"], "creative: crafting is free")
	cr.accounts["cora"]["energy"] = 5.0
	cr.energy_step(100.0, {"cora": 0})
	check(float(cr.accounts["cora"]["energy"]) == FWConst.ENERGY_MAX, "creative: energy never drains")
	# پول: در خلاقانه هیچ‌چیز به سکه وابسته نیست و سکه نه کم می‌شود نه زیاد
	var shop_item: String = str(FWConst.ITEMS.keys()[0])
	var rs: Dictionary = sv.trade("sam", shop_item, 1, true)
	check(not rs["ok"] and rs["error"] == "no_money", "survival: shop needs coins")
	var rbuy: Dictionary = cr.trade("cora", shop_item, 3, true)
	check(rbuy["ok"] and int(cr.accounts["cora"]["money"]) == 0 and int(cr.accounts["cora"]["inv"].get(shop_item, 0)) >= 3, "creative: shop is free with zero coins")
	var rsell: Dictionary = cr.trade("cora", shop_item, 2, false)
	check(rsell["ok"] and int(cr.accounts["cora"]["money"]) == 0, "creative: selling never adds coins")
	var hid: int = int(rb["building"]["id"])
	cr.remove_building("cora", hid)
	check(int(cr.accounts["cora"]["money"]) == 0, "creative: demolish gives no refund coins")
	_login(cr, "dan")
	cr.accounts["dan"]["money"] = 0
	cr.accounts["cora"]["inv"][shop_item] = 5
	var ro: Dictionary = cr.make_offer("cora", "dan", shop_item, 2, 500)
	if ro.get("ok", false):
		var ra: Dictionary = cr.answer_offer("dan", int(ro["id"]), true)
		check(ra["ok"] and int(cr.accounts["dan"]["money"]) == 0 and int(cr.accounts["cora"]["money"]) == 0, "creative: player trade moves items but no coins")
	check(bool(cr.world_public()["creative"]) and not bool(sv.world_public()["creative"]), "welcome info carries the mode")
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cr.to_dict())))
	check(back != null and back.creative and not CityState.from_dict(JSON.parse_string(JSON.stringify(sv.to_dict()))).creative, "mode survives save and load")


func _flat_patch(c, role: String, size: int) -> Vector3i:
	for gx in range(20, 200, 3):
		for gz in range(20, 200, 3):
			var base_h: int = maxi(0, int(floor(c.world.height_at(gx + 0.5, gz + 0.5))))
			var good: bool = c.world.height_at(gx + 0.5, gz + 0.5) >= 0.2
			for dx in range(size):
				for dz in range(size):
					var hh: float = c.world.height_at(gx + dx + 0.5, gz + dz + 0.5)
					if hh < 0.2 or maxi(0, int(floor(hh))) != base_h or c.check_block(role, gx + dx, base_h, gz + dz, "stone") != "":
						good = false
			if good:
				return Vector3i(gx, base_h, gz)
	return Vector3i(-999, 0, 0)


func test_blueprints() -> void:
	print("-- blueprints")
	var BP = preload("res://scripts/server/blueprints.gd")
	var cs = CityState.new(12345)
	_login(cs, "ali")
	_login(cs, "sara")
	var good := PackedInt32Array([0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0])
	var r: Dictionary = cs.blueprints.save("ali", "  Hut\n ", good, false)
	check(r["ok"] and int(r["id"]) == 1, "blueprint saved with cleaned name")
	check(str(cs.blueprints.items[1]["name"]) == "Hut" and int(cs.blueprints.items[1]["n"]) == 3, "name trimmed, block count stored")
	check(cs.blueprints.save("ali", "   ", good, false)["error"] == "bp_name", "empty name rejected")
	check(cs.blueprints.save("ali", "x", PackedInt32Array([0, 0, 0]), false)["error"] == "bp_bad", "bad length rejected")
	check(cs.blueprints.save("ali", "x", PackedInt32Array([-1, 0, 0, 0, 0]), false)["error"] == "bp_bad", "negative offset rejected")
	check(cs.blueprints.save("ali", "x", PackedInt32Array([16, 0, 0, 0, 0]), false)["error"] == "bp_bad", "offset beyond side limit rejected")
	check(cs.blueprints.save("ali", "x", PackedInt32Array([0, 0, 0, 999, 0]), false)["error"] == "bp_bad", "unknown block type rejected")
	check(cs.blueprints.save("ali", "x", PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]), false)["error"] == "bp_bad", "duplicate cell rejected")
	var huge := PackedInt32Array()
	for i in range(FWConst.REGION_MAX_VOLUME + 1):
		huge.append_array(PackedInt32Array([i % 16, (i / 16) % 16, i / 256, 0, 0]))
	check(cs.blueprints.save("ali", "huge", huge, false)["error"] == "bp_bad", "over-volume rejected")
	# دسترسی
	check(cs.blueprints.list_for("sara").is_empty(), "private blueprint hidden from others")
	check(cs.blueprints.data_for("sara", 1).is_empty(), "private blueprint data not served to others")
	check(cs.blueprints.set_shared("sara", 1, true) == "forbidden", "only the author can share")
	check(cs.blueprints.set_shared("ali", 1, true) == "", "author shares")
	check(cs.blueprints.list_for("sara").size() == 1 and cs.blueprints.data_for("sara", 1).size() == 15, "shared blueprint visible to others")
	check(cs.blueprints.remove("sara", 1, false) == "forbidden", "others cannot delete")
	# سقف هر بازیکن
	for i in range(BP.PER_PLAYER_MAX - 1):
		cs.blueprints.save("ali", "b%d" % i, good, false)
	check(cs.blueprints.count_by("ali") == BP.PER_PLAYER_MAX, "per-player cap reached")
	check(cs.blueprints.save("ali", "over", good, false)["error"] == "bp_limit", "per-player cap enforced")
	check(cs.blueprints.save("sara", "mine", good, true)["ok"], "cap is per player")
	# چرخش ۹۰ درجه
	var st := BP.rotate_y(PackedInt32Array([0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0]))
	check(BP.extent(good) == Vector3i(2, 2, 1) and BP.extent(st) == Vector3i(1, 2, 2), "rotation swaps the x/z extents")
	check(BP.clean_data(st).size() == 15, "rotated data stays valid")
	var r4 := good
	for i in range(4):
		r4 = BP.rotate_y(r4)
	var a1: Dictionary = {}
	var a2: Dictionary = {}
	for k in range(good.size() / 5):
		a1[Vector3i(good[k * 5], good[k * 5 + 1], good[k * 5 + 2])] = true
		a2[Vector3i(r4[k * 5], r4[k * 5 + 1], r4[k * 5 + 2])] = true
	check(a1 == a2 and r4.size() == good.size(), "four rotations return to the original")
	var stairs_id: int = FWConst.BLOCK_ORDER.find("stairs")
	var sr := BP.rotate_y(PackedInt32Array([0, 0, 0, stairs_id, 3 + 16 * 3]))
	check(FWConst.meta_facing(sr[4]) == 0 and FWConst.meta_color(sr[4]) == 3, "stairs facing turns with the structure, colour kept")
	check(BP.rotate_y(PackedInt32Array()).is_empty(), "rotating nothing is empty")
	# ذخیره و بازیابی
	var d: Dictionary = cs.to_dict()
	var json := JSON.stringify(d)
	var cs2 = CityState.from_dict(JSON.parse_string(json))
	check(cs2 != null and cs2.blueprints.items.size() == cs.blueprints.items.size(), "blueprints survive save/load")
	check(cs2.blueprints.data_for("sara", 1) == good, "blueprint data identical after reload")
	check(cs2.blueprints.next_id == cs.blueprints.next_id, "next id preserved")
	# حذف توسط مدیر
	check(cs2.blueprints.remove("someone", 1, true) == "", "admin can delete any")
	check(cs2.blueprints.remove("ali", 1, false) == "bp_missing", "deleted blueprint is gone")
	# داده‌های خراب در فایل ذخیره نادیده گرفته می‌شود
	var bad := BP.new()
	bad.load_dict({"next_id": 5, "items": [{"id": 2, "name": "ok", "author": "a", "shared": true, "data": Marshalls.raw_to_base64(good.to_byte_array())}, {"id": 3, "name": "bad", "author": "a", "data": "!!!"}, "junk"]})
	check(bad.items.size() == 1 and bad.next_id == 5, "corrupt entries skipped on load")


func test_batch_build() -> void:
	print("[batch build]")
	var cr = CityState.new(12345)
	cr.creative = true
	_login(cr, "cora")
	_login(cr, "dan")
	var o := _flat_patch(cr, "player", 4)
	check(o.x != -999, "found a flat patch for tests")
	var a := o
	var b := o + Vector3i(3, 0, 3)
	var cells: Array = CityState.region_cells(a, b)
	check(cells.size() == 16, "4x1x4 region has 16 cells")
	check(CityState.region_cells(a, a + Vector3i(40, 0, 0)).is_empty(), "region wider than the side limit is refused")
	check(CityState.region_cells(a, a + Vector3i(15, 15, 15)).is_empty(), "region over the volume limit is refused")
	check(CityState.region_cells(a, a + Vector3i(3, 3, 3), true).size() == 56, "hollow 4x4x4 shell has 56 cells")
	# پر کردن
	var entries: Array = []
	for v in cells:
		entries.append([v, "stone", 0])
	var r: Dictionary = cr.batch_place("cora", entries)
	check(int(r["placed"]) == 16 and (r["changed"] as Array).size() == 16, "fill places all 16 blocks")
	check(cr.blocks.size() == 16 and cr.undo_depth("cora") == 1, "one fill is one undo step")
	# واگرد پر کردن
	var u: Dictionary = cr.undo_last("cora")
	check(int(u["removed"]) == 16 and cr.blocks.is_empty(), "undo removes the whole fill")
	check(cr.undo_last("cora")["error"] == "nothing_to_undo", "undo with empty history reports it")
	# پاک کردن و واگرد پاک کردن
	cr.batch_place("cora", entries)
	var rc: Dictionary = cr.batch_remove("cora", cells)
	check(int(rc["removed"]) == 16 and cr.blocks.is_empty(), "clear removes all 16")
	var u2: Dictionary = cr.undo_last("cora")
	check(int(u2["placed"]) == 16 and cr.blocks.size() == 16, "undo of clear restores the blocks")
	# بلوک دیگران پاک نمی‌شود
	var rd: Dictionary = cr.batch_remove("dan", cells)
	check(int(rd["removed"]) == 0 and cr.blocks.size() == 16, "a normal player cannot clear someone else's blocks")
	# واگرد تک‌بلوک
	var one := Vector3i(o.x, o.y + 1, o.z)
	check(cr.place_block("dan", 0, one.x, one.y, one.z, "wood", 0)["ok"], "single place on top works")
	check(cr.undo_depth("dan") == 1, "single place is recorded for undo")
	check(int(cr.undo_last("dan")["removed"]) == 1 and not cr.blocks.has(one), "undo of a single place")
	# دیوارهای تو خالی و چینش لایه‌ای (لایهٔ بالا به تکیه‌گاه پایین نیاز دارد)
	var cr2 = CityState.new(12345)
	cr2.creative = true
	_login(cr2, "erin")
	var shell: Array = []
	for v in CityState.region_cells(o, o + Vector3i(3, 3, 3), true):
		shell.append([v, "brick", 0])
	shell.reverse()  # عمداً از بالا به پایین؛ سرور باید مرتب کند
	var rs: Dictionary = cr2.batch_place("erin", shell)
	check(int(rs["placed"]) == 56, "hollow shell stacks correctly even when sent top-down (%d)" % int(rs["placed"]))
	# هزینه در حالت بقا
	var sv = CityState.new(12345)
	_login(sv, "sam")
	sv.accounts["sam"]["inv"] = {}
	var rn: Dictionary = sv.batch_place("sam", entries)
	check(int(rn["placed"]) == 0 and sv.blocks.is_empty(), "survival: batch fill without materials places nothing")
	check(sv.undo_depth("sam") == 0, "a failed batch leaves no undo record")
	# سقف عمق واگرد
	for i in range(FWConst.UNDO_DEPTH + 5):
		cr.push_undo("cora", [Vector3i(i, 0, 0)], [])
	check(cr.undo_depth("cora") == FWConst.UNDO_DEPTH, "undo history is capped")


func _open_ground(c, role: String) -> Vector2:
	for gx in range(60, 400, 12):
		for gz in range(60, 400, 12):
			var v: Vector2i = CityState.terrain_vertex(float(gx), float(gz))
			if c.terrain_check(role, v, FWConst.SHAPE_RADIUS) == "" and c.world.height_at(float(gx), float(gz)) >= 1.0:
				return Vector2(gx, gz)
	return Vector2(-1, -1)


func test_terrain_shapes() -> void:
	print("[admin terrain shapes: mountain, lake, flatten]")
	var cs = CityState.new(12345)
	_login(cs, "root")
	cs.accounts["root"]["role"] = FWConst.ROLE_WORLD_ADMIN
	_login(cs, "pat")
	var at: Vector2 = _open_ground(cs, "admin")
	check(at.x >= 0.0, "found open ground for terrain tests")
	var h0: float = cs.world.height_at(at.x, at.y)
	check(cs.shape_terrain("pat", "mountain", at.x, at.y)["error"] == "forbidden", "normal players cannot shape terrain")
	check(cs.shape_terrain("root", "volcano", at.x, at.y)["error"] == "bad_request", "unknown shape is refused")
	var r: Dictionary = cs.shape_terrain("root", "mountain", at.x, at.y)
	check(r["ok"] and (r["changes"] as Array).size() > 20, "mountain changes many vertices")
	var h1: float = cs.world.height_at(at.x, at.y)
	check(h1 > h0 + 6.0, "one mountain raises the centre by ~8 m (%.1f -> %.1f)" % [h0, h1])
	for i in range(3):
		cs.shape_terrain("root", "mountain", at.x, at.y)
	var peak: float = cs.world.height_at(at.x, at.y)
	check(peak <= cs.world.base_height_at(at.x, at.y) + float(FWConst.TERRAIN_ADMIN_MAX_UNITS) * FWConst.TERRAIN_UNIT + 0.01, "mountain height is capped at the admin limit")
	var edge: float = cs.world.height_at(at.x + float(FWConst.SHAPE_RADIUS) * FWConst.TERRAIN_EDIT_STEP + 4.0, at.y)
	check(absf(edge - cs.world.base_height_at(at.x + float(FWConst.SHAPE_RADIUS) * FWConst.TERRAIN_EDIT_STEP + 4.0, at.y)) < 0.01, "mountain does not leak outside its radius")
	# دریاچه
	var cs2 = CityState.new(12345)
	_login(cs2, "root")
	cs2.accounts["root"]["role"] = FWConst.ROLE_WORLD_ADMIN
	var rl: Dictionary = cs2.shape_terrain("root", "lake", at.x, at.y)
	check(rl["ok"], "lake tool works")
	var hl: float = cs2.world.height_at(at.x, at.y)
	check(hl < 0.2, "lake centre is below the water line (%.2f)" % hl)
	# صاف کردن
	var cs3 = CityState.new(12345)
	_login(cs3, "root")
	cs3.accounts["root"]["role"] = FWConst.ROLE_WORLD_ADMIN
	cs3.shape_terrain("root", "mountain", at.x + 6.0, at.y)
	var rf: Dictionary = cs3.shape_terrain("root", "flatten", at.x, at.y)
	check(rf["ok"] or rf["error"] == "terrain_limit", "flatten runs")
	# پایداری ذخیره
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(back != null and absf(back.world.height_at(at.x, at.y) - peak) < 0.01, "shaped terrain survives save and load")
	# بازیکن عادی روی کوه مدیر زمین را پایین نمی‌آورد/بالا نمی‌برد اشتباهی
	var old_units: int = cs.world.edit_units(CityState.terrain_vertex(at.x, at.y).x, CityState.terrain_vertex(at.x, at.y).y)
	cs.apply_terraform(CityState.terrain_vertex(at.x, at.y), 1, 1)
	check(cs.world.edit_units(CityState.terrain_vertex(at.x, at.y).x, CityState.terrain_vertex(at.x, at.y).y) == old_units, "a player's fill does not flatten an admin mountain")
	# قفل زیر ساختمان
	var cs4 = CityState.new(12345)
	_login(cs4, "root")
	cs4.accounts["root"]["role"] = FWConst.ROLE_WORLD_ADMIN
	cs4.occupied[Placement.cell_key(int(at.x / FWConst.CELL_SIZE), int(at.y / FWConst.CELL_SIZE))] = 1
	check(cs4.shape_terrain("root", "mountain", at.x, at.y)["error"] == "terrain_locked", "shaping is refused under buildings")


func test_villages() -> void:
	print("[villages]")
	var w = WorldGen.new(12345)
	var vs: Array = w.villages()
	check(vs.size() >= 3, "world has villages (%d)" % vs.size())
	var w2 = WorldGen.new(12345)
	check(JSON.stringify(w2.villages()) == JSON.stringify(vs), "villages are deterministic")
	var half := FWConst.CITY_SIZE * 0.5
	var all_ok := true
	var houses := 0
	for v in vs:
		check(Vector2(float(v["x"]), float(v["z"])).distance_to(Vector2(half, half)) >= FWConst.VILLAGE_MIN_CITY_DIST, "village outside city")
		for h in v["houses"]:
			houses += 1
			if w.base_height_at(float(h["cx"]), float(h["cz"])) < 1.0 or w.river_weight(float(h["cx"]), float(h["cz"])) > 0.0:
				all_ok = false
			if w.village_solid_at(float(h["ex"]), float(h["ez"]), 0.3):
				all_ok = false
			if w.house_site(str(h["id"])).is_empty() or w.mine_entrance(str(h["id"])).is_empty():
				all_ok = false
	check(all_ok and houses >= 12, "houses on dry land, exit free, lookup works (%d houses)" % houses)
	var h0: Dictionary = vs[0]["houses"][0]
	check(w.village_solid_at(float(h0["cx"]), float(h0["cz"])), "house footprint is solid")
	check(not w.nearest_house_door(float(h0["x"]), float(h0["z"]), 2.0).is_empty(), "door found nearby")
	check(w.nearest_site(float(h0["ex"]), float(h0["ez"]), 6.0).get("id", "") == str(h0["id"]), "nearest_site returns the house")
	check(w.house_site("h999,999,0").is_empty() and w.house_site("hx").is_empty(), "bad house ids rejected")
	# سرور
	var cs = CityState.new(12345)
	_login(cs, "vil")
	var hid := str(h0["id"])
	check(cs.mine_enter_error("vil", hid, Vector2(float(h0["x"]) + 30.0, float(h0["z"]))) == "too_far", "house: too far to enter")
	check(cs.mine_enter_error("vil", hid, Vector2(float(h0["ex"]), float(h0["ez"]))) == "", "house: can enter at the door")
	check(not cs.is_walkable(float(h0["cx"]), float(h0["cz"])), "cannot walk through a house")
	var lay: Dictionary = cs.mine_layout(hid)
	check(String(lay.get("style", "")) == "house" and Mine.walkable(lay, Mine.spawn_point(lay).x, Mine.spawn_point(lay).y), "house interior has a walkable entry")
	check(cs.mine_gather("vil", hid, 1, Vector2(float(lay["nodes"][1]["x"]), float(lay["nodes"][1]["z"])))["ok"], "house chest pays coins")
	cs.accounts["vil"]["energy"] = 10.0
	var rb: Dictionary = cs.mine_gather("vil", hid, 0, Vector2(float(lay["nodes"][0]["x"]), float(lay["nodes"][0]["z"])))
	check(rb["ok"] and rb.get("rested", false) and float(cs.accounts["vil"]["energy"]) == FWConst.ENERGY_MAX, "bed restores energy")
	check(not cs.mine_gather("vil", hid, 0, Vector2(float(lay["nodes"][0]["x"]), float(lay["nodes"][0]["z"])))["ok"], "bed has a cooldown")
	# حیوانات روستا یک بار
	var n1: int = cs.seed_village_life()
	check(n1 > 0 and cs.seed_village_life() == 0, "village animals seeded once (%d)" % n1)
	check(cs.check_block("player", int(floor(float(h0["cx"]))), 3, int(floor(float(h0["cz"]))), "stone") == "near_village", "no blocks on a house")
	for i in range(1, 8):
		var r := w.resource_in_cell(int(float(vs[0]["x"]) / FWConst.RESOURCE_CELL) + i % 3, int(float(vs[0]["z"]) / FWConst.RESOURCE_CELL) + i / 3)
		check(r.is_empty(), "no wild resources inside the village")


func test_scenarios() -> void:
	print("[scenarios]")
	check(Scenarios.ids().size() == 8, "eight ready-made worlds")
	var free := 0
	var premium := 0
	for id in Scenarios.ids():
		if Scenarios.is_premium(id):
			premium += 1
		else:
			free += 1
	check(free >= 3 and premium >= 3, "free and premium worlds both exist (%d/%d)" % [free, premium])
	var names_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for id in Scenarios.ids():
			if Loc.t("scen_" + id) == "scen_" + id or Loc.t("scen_%s_desc" % id) == "scen_%s_desc" % id:
				names_ok = false
	Loc.lang = "fa"
	check(names_ok, "every world has a Persian and English name and description")
	for id in Scenarios.ids():
		var d: Dictionary = Scenarios.def(id)
		var cs = CityState.new(int(d["seed"]))
		var n: int = ScenarioApply.apply(cs, id)
		check(n > 20, "%s builds structures (%d blocks)" % [id, n])
		check(cs.scenario == id and cs.scenario_applied, "%s remembers its scenario" % id)
		check(ScenarioApply.apply(cs, id) == -1, "%s is applied only once" % id)
		check(cs.npcs.size() >= FWConst.NPC_COUNT, "%s has citizens" % id)
		check(cs.creative == bool(d["creative"]), "%s creative flag follows the definition" % id)
		var bad := 0
		for v in cs.blocks:
			if cs.blocks[v][2] != ScenarioApply.OWNER or not FWConst.BLOCK_TYPES.has(str(cs.blocks[v][0])):
				bad += 1
		check(bad == 0, "%s blocks are valid and owned by the world" % id)
		# تعیین‌گرا: دو بار ساخت همان نتیجه را می‌دهد
		var cs2 = CityState.new(int(d["seed"]))
		ScenarioApply.apply(cs2, id)
		check(cs2.blocks.size() == cs.blocks.size() and cs2.god.size() == cs.god.size(), "%s is deterministic" % id)
		# حساب تازه سرمایهٔ سناریو را می‌گیرد؛ ذخیره و بارگذاری سناریو را حفظ می‌کند
		var r: Dictionary = cs.authenticate("newbie", "x")
		check(r["ok"] and int(cs.accounts["newbie"]["money"]) == int(d["money"]), "%s start money" % id)
		check(cs.accounts["newbie"]["inv"] == Scenarios.start_items(id), "%s start items" % id)
		var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
		check(back != null and back.scenario == id and back.scenario_applied and back.blocks.size() == cs.blocks.size(), "%s survives save and load" % id)
		check(ScenarioApply.apply(back, id) == -1, "%s is not re-applied after load" % id)
	# ناشناخته و جهان معمولی
	var plain = CityState.new(5)
	check(ScenarioApply.apply(plain, "nope") == -1 and plain.scenario == "", "unknown world is ignored")
	plain.authenticate("p", "x")
	check(int(plain.accounts["p"]["money"]) == FWConst.START_MONEY and plain.accounts["p"]["inv"] == FWConst.START_ITEMS, "plain world keeps the default start")
	# ساخت جهان در منو
	var ws: Array = []
	var ok: Dictionary = WorldSlots.add_world(ws, "x1", 1, false, "merchant_city")
	check(ok["ok"] and int(ws[0]["seed"]) == int(Scenarios.def("merchant_city")["seed"]) and ws[0]["scenario"] == "merchant_city", "menu world uses the scenario seed")
	var ok2: Dictionary = WorldSlots.add_world(ws, "x2", 1, false, "builder_playground")
	check(ok2["ok"] and ws[1]["creative"], "creative scenario makes a creative world")
	check(not WorldSlots.add_world(ws, "x3", 1, false, "nope")["ok"], "unknown scenario is rejected")
	check(Entitlements.is_unlocked("medieval_fort") and Entitlements.is_unlocked("green_valley"), "worlds are open until payments are connected")


func test_climates() -> void:
	print("[climates]")
	var WG = load("res://scripts/world/world_generator.gd")
	var base = WG.new(297)
	var win = WG.new(297)
	win.climate = "winter"
	var des = WG.new(326)
	des.climate = "desert"
	var des_base = WG.new(326)
	var seen_w := {}
	var seen_d := {}
	var seen_t := {}
	var same_h := true
	for iz in range(0, 640, 16):
		for ix in range(0, 640, 16):
			seen_w[win.biome_at(float(ix), float(iz))] = true
			seen_d[des.biome_at(float(ix), float(iz))] = true
			seen_t[base.biome_at(float(ix), float(iz))] = true
			if absf(win.height_at(float(ix), float(iz)) - base.height_at(float(ix), float(iz))) > 0.0001:
				same_h = false
			if absf(des.height_at(float(ix), float(iz)) - des_base.height_at(float(ix), float(iz))) > 0.0001:
				same_h = false
	check(same_h, "climate never changes terrain height (only appearance and resources)")
	var ok_t := true
	for b in seen_t:
		if not ["water", "beach", "mountain", "forest", "plain"].has(b):
			ok_t = false
	check(ok_t, "temperate keeps the original biome names")
	var ok_w := true
	for b in seen_w:
		if not ["water", "beach", "mountain", "snow", "snow_forest"].has(b):
			ok_w = false
	check(ok_w and seen_w.has("snow") and seen_w.has("snow_forest"), "winter has snow and snow forest only (%s)" % str(seen_w.keys()))
	var ok_d := true
	for b in seen_d:
		if not ["water", "beach", "mesa", "desert", "oasis"].has(b):
			ok_d = false
	check(ok_d and seen_d.has("desert"), "desert has sand, oasis and mesa only (%s)" % str(seen_d.keys()))
	check(WG.is_wooded("snow_forest") and WG.is_wooded("oasis") and WG.is_wooded("forest") and not WG.is_wooded("desert"), "wooded biome helper")
	check(WG.is_rocky("mesa") and WG.is_rocky("mountain") and not WG.is_rocky("snow"), "rocky biome helper")
	for b in ["snow", "snow_forest", "desert", "oasis", "mesa"]:
		check(WG.biome_color(b) != WG.biome_color("plain"), "%s has its own colour" % b)
	# منابع: درخت و صخره در هر اقلیم پیدا می‌شود، قطعی است و صحرا خاک رس دارد
	var kinds_w := {}
	var kinds_d := {}
	for rz in range(0, 160):
		for rx in range(0, 160):
			var a: Dictionary = win.resource_in_cell(rx, rz)
			if not a.is_empty():
				kinds_w[a["kind"]] = true
			var d: Dictionary = des.resource_in_cell(rx, rz)
			if not d.is_empty():
				kinds_d[d["kind"]] = true
	check(kinds_w.has("tree") and kinds_w.has("rock"), "winter has trees and rocks (%s)" % str(kinds_w.keys()))
	check(kinds_d.has("clay") and kinds_d.has("tree") and kinds_d.has("rock"), "desert has palms, rocks and clay (%s)" % str(kinds_d.keys()))
	var win2 = WG.new(297)
	win2.climate = "winter"
	var same := true
	for rz in range(0, 40):
		for rx in range(0, 40):
			if str(win.resource_in_cell(rx, rz)) != str(win2.resource_in_cell(rx, rz)):
				same = false
	check(same, "resources are deterministic per seed and climate")
	# سناریوها و ذخیره
	check(Scenarios.climate("frozen_north") == "winter" and Scenarios.climate("desert_caravan") == "desert", "scenario climates")
	check(Scenarios.climate("green_valley") == "temperate" and Scenarios.climate("nope") == "temperate", "default climate is temperate")
	var cs = CityState.new(int(Scenarios.def("frozen_north")["seed"]))
	check(cs.world.climate == "temperate", "a fresh city is temperate")
	ScenarioApply.apply(cs, "frozen_north")
	check(cs.world.climate == "winter", "applying a winter world sets the climate")
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(back != null and back.world.climate == "winter", "climate survives save and load")
	cs.set_climate("lava")
	check(cs.world.climate == "temperate", "unknown climate falls back to temperate")


func test_story_book() -> void:
	print("[story and adventure book]")
	check(FWConst.PROTOCOL_VERSION >= 34, "protocol bumped for the book message and the climate in login info")
	# --- یکپارچگی داده و متن‌ها ---
	var ids := {}
	var dup := false
	var bad_role := false
	var kinds := ["dist", "in_village", "in_mine", "biome", "height", "owns", "blocks", "blocks_of", "tool_any", "friends", "stat", "flag", "money", "chains"]
	var bad_kind := false
	for e in Story.ENTRIES:
		if ids.has(e["id"]):
			dup = true
		ids[e["id"]] = true
		if not Story.ROLES.has(str(e["giver"])):
			bad_role = true
		if not kinds.has(str(e["kind"])) or not ["", "winter", "desert"].has(str(e["climate"])) or int(e["reward"]) < 0 or int(e["reward"]) > 100:
			bad_kind = true
	check(not dup and not bad_role and not bad_kind, "book entries have unique ids, known roles and kinds, small rewards (%d entries)" % Story.ENTRIES.size())
	var texts_ok := true
	var missing := ""
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for e in Story.ENTRIES:
			for k in ["book_" + str(e["id"]), "book_%s_d" % str(e["id"])]:
				if Loc.t(k) == k:
					texts_ok = false
					missing = k
		for r in Story.ROLES:
			for k in ["role_" + r, Story.line_key(r, 0), Story.line_key(r, 1), Story.line_key(r, 2), Story.hint_key(r), Story.done_key(r)]:
				if Loc.t(k) == k:
					texts_ok = false
					missing = k
		for k in ["book", "book_title", "book_hint", "book_progress", "msg_book_unlock", "msg_book_reward", "dlg_quest_hint"]:
			if Loc.t(k) == k:
				texts_ok = false
				missing = k
	Loc.lang = "fa"
	check(texts_ok, "every entry, role and dialogue line has Persian and English text (%s)" % missing)
	var scenes_ok := true
	var scene_missing := ""
	for lang_code in ["fa", "en"]:
		Loc.lang = lang_code
		for sc in Story.LEGENDS:
			for e in Story.legend_entries(str(sc)):
				var sk := "book_%s_s" % str(e["id"])
				if Loc.t(sk) == sk:
					scenes_ok = false
					scene_missing = sk
	Loc.lang = "fa"
	check(scenes_ok, "every legend step has a story scene in Persian and English (%s)" % scene_missing)
	# --- شخصیت‌ها ---
	check(Story.role_of("", 1) == "farmer" and Story.role_of("", 3) == "guide" and Story.role_of("", 4) == "villager", "default cast by NPC order")
	check(Story.role_of("frozen_north", 1) == "hunter" and Story.role_of("desert_caravan", 1) == "nomad", "scenario casts differ")
	check(Story.role_of("green_valley", 2) == "baker", "scenarios without their own cast use the default one")
	var wcs = CityState.new(int(Scenarios.def("frozen_north")["seed"]))
	ScenarioApply.apply(wcs, "frozen_north")
	check(str(wcs.npcs[0]["name"]) == "بهمن" and str(wcs.npcs[1]["name"]) == "شیرین", "a ready-made world names its cast")
	# --- ارزیابی دستاوردها ---
	var cs = CityState.new(12345)
	_login(cs, "hero")
	load("res://scripts/server/npc_sim.gd").ensure_npcs(cs)
	var acc: Dictionary = cs.accounts["hero"]
	var half := FWConst.CITY_SIZE * 0.5
	var near := {"pos": Vector3(half, 2.0, half), "mine": ""}
	check(Book.evaluate(cs, "hero", near).is_empty(), "standing in the plaza unlocks nothing")
	var m0: int = int(acc["money"])
	var far := {"pos": Vector3(half + 70.0, 2.0, half), "mine": ""}
	var got: Array = Book.evaluate(cs, "hero", far)
	var got_ids: Array = []
	for g in got:
		got_ids.append(g["id"])
	check(got_ids.has("explorer_60") and not got_ids.has("explorer_200"), "walking 70 m out unlocks the 60 m entry only (%s)" % str(got_ids))
	var gained := 0
	for g in got:
		gained += int(g["reward"])
	check(int(acc["money"]) == m0 + gained and gained >= 15, "the small reward is paid")
	check(Book.evaluate(cs, "hero", far).is_empty() and int(acc["money"]) == m0 + gained, "an entry unlocks and pays only once")
	check(not Book.evaluate(cs, "hero", {"pos": Vector3(half + 210.0, 2.0, half), "mine": ""}).is_empty(), "a farther walk unlocks the next entry")
	check(Book.evaluate(cs, "nobody", far).is_empty(), "unknown players are ignored")
	# مایل‌استون‌های مبتنی بر وضعیت حساب
	for i in range(50):
		cs._add_block(Vector3i(i, 0, 300), "stone", 0, "hero")
	check(Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "builder_50"), "50 own blocks unlock the builder entry")
	check(not Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "builder_300"), "300 blocks are not reached")
	cs.buildings[9001] = {"id": 9001, "type": "house", "owner": "hero", "cx": 5, "cz": 5, "stock": 0.0, "prog": 0.0, "furn": []}
	check(Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "first_house"), "owning a house unlocks the homeowner entry")
	acc["friends"] = {"1": 30}
	check(Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "friend_first"), "a friend-level NPC unlocks the friendship entry")
	check(not Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "friend_three"), "three friends are not reached")
	acc["stats"] = {"talks": 10, "gifts": 0}
	check(Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "chatterbox"), "talk counter unlocks chatterbox")
	check(Book.evaluate(cs, "hero", {"pos": Vector3(half, 2.0, half), "mine": "5,5"}).any(func(g): return g["id"] == "miner"), "being in a mine unlocks the miner entry")
	acc["boat"] = true
	check(Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "sailor"), "owning a boat unlocks the sailor entry")
	acc["money"] = 12000
	check(Book.evaluate(cs, "hero", near).any(func(g): return g["id"] == "rich"), "enough coins unlock the wealthy entry")
	# --- وضعیت عمومی ---
	var st: Dictionary = Book.public_state(cs, "hero")
	check(int(st["total"]) == Story.entries_for("temperate", false).size() and st["rows"].size() == int(st["total"]), "public state lists this world's entries")
	var done_rows := 0
	for row in st["rows"]:
		if int(row[1]) > 0:
			done_rows += 1
	check(done_rows == int(st["done"]) and done_rows >= 8, "done count matches unlocked rows (%d)" % done_rows)
	check(str(st["roles"]["1"]) == "farmer" and str(st["roles"]["4"]) == "villager", "public state tells each NPC's role")
	# --- ذخیره و بارگذاری ---
	var back = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(back != null and back.accounts["hero"]["book"].size() == acc["book"].size() and int(back.accounts["hero"]["stats"]["talks"]) == 10, "book and stats survive save and load")
	var raw: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	raw["accounts"]["hero"]["book"]["nonsense_entry"] = 3
	var back2 = CityState.from_dict(raw)
	check(back2 != null and not back2.accounts["hero"]["book"].has("nonsense_entry"), "unknown book ids are dropped on load")
	var old: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	old["accounts"]["hero"].erase("book")
	old["accounts"]["hero"].erase("stats")
	var back3 = CityState.from_dict(old)
	check(back3 != null and back3.accounts["hero"]["book"].is_empty() and back3.accounts["hero"]["stats"].is_empty(), "old saves without a book load with an empty one")
	# --- گفت‌وگو ---
	var cs2 = CityState.new(777)
	_login(cs2, "talker")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	NpcSim.ensure_npcs(cs2)
	var farmer: Dictionary = cs2.npcs[0]
	var at := Vector2(float(farmer["x"]), float(farmer["z"]))
	var r: Dictionary = cs2.npc_interact("talker", int(farmer["id"]), "", at)
	check(r["ok"] and r["role"] == "farmer" and r["line"] == "dlg_farmer_0" and r["hint"] == "dlg_quest_hint" and r["entry"] == "", "the farmer greets and points to his quest first")
	check(int(cs2.accounts["talker"]["stats"]["talks"]) == 1, "talking is counted")
	var gr: Dictionary = cs2.npc_interact("talker", int(farmer["id"]), "wood", at)
	check(gr["ok"] and gr["line"] == "" and int(cs2.accounts["talker"]["stats"]["gifts"]) == 1, "gifts are counted and carry no speech")
	cs2.accounts["talker"]["book"]["first_house"] = 0
	cs2.accounts["talker"]["book"]["wheat_farm"] = 0
	var d0: Dictionary = Book.dialogue(cs2, "talker", "farmer", 1)
	check(d0["hint"] == "dlg_farmer_hint" and d0["entry"] == "wheat_farm" or d0["hint"] == "dlg_quest_hint", "quest first, then book entries")
	cs2.accounts["talker"]["quests"]["farmer"] = 3
	cs2.accounts["talker"]["book"]["friend_first"] = 0
	var d1: Dictionary = Book.dialogue(cs2, "talker", "farmer", 1)
	check(d1["hint"] == "dlg_farmer_hint" and d1["entry"] == "wheat_farm" or d1["hint"] == "dlg_farmer_done", "after the quest chain the farmer talks about his book entries")
	cs2.accounts["talker"]["book"]["wheat_farm"] = 0
	var d: Dictionary = Book.dialogue(cs2, "talker", "farmer", 1)
	check(d["line"] == "dlg_farmer_1" and d["hint"] == "dlg_farmer_done" and d["entry"] == "", "after finishing quests and entries the farmer thanks you")
	check(Book.dialogue(cs2, "talker", "villager", 0)["hint"] == "", "villagers only greet")
	# --- خلاقانه و اقلیم ---
	var cc = CityState.new(321)
	cc.creative = true
	_login(cc, "maker")
	check(Story.entries_for("temperate", true).size() == Story.entries_for("temperate", false).size() - 1, "creative worlds hide the coin entry")
	var cm: int = int(cc.accounts["maker"]["money"])
	cc.accounts["maker"]["money"] = cm + 5000
	var cgot: Array = Book.evaluate(cc, "maker", {"pos": Vector3(half + 70.0, 2.0, half), "mine": ""})
	check(not cgot.is_empty() and int(cc.accounts["maker"]["money"]) == cm + 5000, "creative worlds unlock entries but never pay coins")
	check(not cgot.any(func(g): return g["id"] == "rich"), "the wealth entry never unlocks in creative")
	var wnames := []
	for e in Story.entries_for("winter", false):
		wnames.append(e["id"])
	var dnames := []
	for e in Story.entries_for("desert", false):
		dnames.append(e["id"])
	check(wnames.has("snow_walker") and not wnames.has("oasis_find") and dnames.has("oasis_find") and not dnames.has("snow_walker"), "climate-specific entries only appear in their climate")
	var wc = CityState.new(297)
	wc.set_climate("winter")
	_login(wc, "skier")
	var snow_pos := Vector3.ZERO
	var found := false
	for iz in range(0, 640, 8):
		for ix in range(0, 640, 8):
			var b: String = wc.world.biome_at(float(ix), float(iz))
			if b == "snow" or b == "snow_forest":
				snow_pos = Vector3(float(ix), wc.world.height_at(float(ix), float(iz)), float(iz))
				found = true
				break
		if found:
			break
	check(found and Book.evaluate(wc, "skier", {"pos": snow_pos, "mine": ""}).any(func(g): return g["id"] == "snow_walker"), "walking on snow unlocks the winter entry")


func test_blueprint_packs() -> void:
	print("[blueprint packs]")
	check(Packs.ids() == ["castle", "village", "town"], "three packs: castle, village, town")
	var seen := {}
	var all_ok := true
	var detail := ""
	var texts_ok := true
	var missing := ""
	for item in Packs.item_ids():
		if seen.has(item):
			all_ok = false
			detail = "duplicate " + str(item)
		seen[item] = true
		var d: PackedInt32Array = Packs.build(str(item))
		var n := d.size() / 5
		var ext: Vector3i = Blueprints.extent(d)
		if Blueprints.clean_data(d).is_empty():
			all_ok = false
			detail = "%s is not a valid blueprint" % item
		elif n < 20 or n > FWConst.REGION_MAX_VOLUME or maxi(ext.x, maxi(ext.y, ext.z)) > FWConst.REGION_MAX_SIDE:
			all_ok = false
			detail = "%s has %d blocks, extent %s" % [item, n, str(ext)]
		# هر طرح دست‌کم یک در و یک پنجره یا چراغ دارد (خانه‌ها قابل ورود و دیده‌شدنی‌اند) و روی زمین شروع می‌شود
		var types := {}
		var lowest := 99
		var i := 0
		while i < d.size():
			types[str(FWConst.BLOCK_ORDER[d[i + 3]])] = true
			lowest = mini(lowest, d[i + 1])
			i += 5
		if lowest != 0:
			all_ok = false
			detail = "%s floats above the ground" % item
		if (str(item).begins_with("castle_") and str(item) != "castle_wall") or str(item).begins_with("village_house") or str(item) == "village_cottage" or str(item) == "town_hall" or str(item) == "town_shop_row" or str(item) == "village_barn":
			if not types.has("door"):
				all_ok = false
				detail = "%s has no door" % item
		for lang in ["fa", "en"]:
			Loc.lang = lang
			if Loc.t("bpk_" + str(item)) == "bpk_" + str(item):
				texts_ok = false
				missing = str(item)
	Loc.lang = "fa"
	check(all_ok, "all %d designs are valid, fit 16x16x16 and 512 blocks, start on the ground (%s)" % [Packs.item_ids().size(), detail])
	check(texts_ok, "every design has Persian and English names (%s)" % missing)
	var pk_texts := true
	for pid in Packs.ids():
		for lang in ["fa", "en"]:
			Loc.lang = lang
			if Loc.t("pack_" + str(pid)) == "pack_" + str(pid) or Loc.t("pack_%s_d" % pid) == "pack_%s_d" % pid:
				pk_texts = false
	for k in ["bp_packs", "bp_packs_hint", "msg_pack_locked", "msg_pack_used"]:
		for lang in ["fa", "en"]:
			Loc.lang = lang
			if Loc.t(k) == k:
				pk_texts = false
	Loc.lang = "fa"
	check(pk_texts, "pack titles, descriptions and UI texts exist in both languages")
	check(Packs.build("nope").is_empty() and Packs.pack("nope").is_empty(), "unknown designs and packs are empty")
	check(Packs.build("castle_keep") == Packs.build("castle_keep"), "designs are deterministic")
	# چرخش چهار بار = همان طرح؛ تعداد بلوک عوض نمی‌شود
	var base: PackedInt32Array = Packs.build("village_house")
	var r := base
	for k in range(4):
		r = Blueprints.rotate_y(r)
	var set_a := {}
	var set_b := {}
	var j := 0
	while j < base.size():
		set_a[str([base[j], base[j + 1], base[j + 2], base[j + 3], base[j + 4]])] = true
		set_b[str([r[j], r[j + 1], r[j + 2], r[j + 3], r[j + 4]])] = true
		j += 5
	check(base.size() == r.size() and set_a == set_b, "four rotations bring a design back to itself")
	check(Entitlements.pack_unlocked("castle") and Entitlements.pack_unlocked("village") and Entitlements.pack_unlocked("town") and Entitlements.pack_unlocked("nope"), "packs are open while payments are disabled")
	check(Packs.is_premium("castle") and not Packs.is_premium("nope"), "packs are marked as sellable content")


func test_quests() -> void:
	print("[npc quests]")
	check(FWConst.PROTOCOL_VERSION >= 35, "protocol bumped for the quest message")
	# --- یکپارچگی داده ---
	var bad := ""
	for role in Story.QUESTS:
		if not Story.ROLES.has(str(role)):
			bad = "unknown role " + str(role)
		var chain: Array = Story.QUESTS[role]
		var prev_need := 0
		for i in range(chain.size()):
			var st: Dictionary = chain[i]
			if not FWConst.ITEMS.has(str(st["item"])) or int(st["n"]) < 1 or int(st["n"]) > FWConst.NPC_TRADE_MAX:
				bad = "%s step %d has a bad item or amount" % [role, i]
			if int(st["need"]) < prev_need or int(st["need"]) > FWConst.FRIEND_LEVELS.size():
				bad = "%s step %d friendship need goes down or is too high" % [role, i]
			prev_need = int(st["need"])
			if int(st["reward"]) < 1 or int(st["reward"]) > 200:
				bad = "%s step %d reward out of range" % [role, i]
			if st.has("bonus") and (i != chain.size() - 1 or not FWConst.ITEMS.has(str(st["bonus"][0]))):
				bad = "%s bonus must be on the last step with a real item" % role
		if chain.size() != 3:
			bad = "%s has %d steps" % [role, chain.size()]
	check(bad == "", "every quest chain is valid: roles, items, rising friendship, last-step bonus (%s)" % bad)
	check(Story.quest_total("farmer") == 3 and Story.quest_total("villager") == 0 and Story.quest_step("farmer", 3).is_empty() and Story.quest_step("farmer", 0)["item"] == "wood", "quest helpers")
	var texts := true
	var miss := ""
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["quest_turn_in", "quest_step", "quest_reward", "quest_bonus", "quest_need_friend", "quest_have", "quest_all_done", "quest_creative", "msg_quest_done", "err_quest_none", "err_quest_friend", "book_quest_first", "book_quest_first_d", "book_quest_five", "book_quest_chain_d"]:
			if Loc.t(k) == k and Loc.err(k.trim_prefix("err_")) == k.trim_prefix("err_"):
				texts = false
				miss = k
	Loc.lang = "fa"
	check(texts, "quest texts exist in both languages (%s)" % miss)
	# --- جریان تحویل ---
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(4242)
	_login(cs, "q")
	NpcSim.ensure_npcs(cs)
	var farmer: Dictionary = cs.npcs[0]
	var at := Vector2(float(farmer["x"]), float(farmer["z"]))
	var acc: Dictionary = cs.accounts["q"]
	acc["inv"] = {}   # کیف آغازین حساب تازه کالا دارد؛ این‌جا از صفر شروع می‌کنیم
	check(not cs.quest_turn_in("nobody", int(farmer["id"]), at)["ok"], "unknown player cannot hand in")
	check(cs.quest_turn_in("q", 999, at)["error"] == "no_npc", "unknown NPC")
	check(cs.quest_turn_in("q", int(farmer["id"]), at + Vector2(60, 0))["error"] == "too_far", "too far from the NPC")
	check(cs.quest_turn_in("q", int(cs.npcs[3]["id"]), Vector2(float(cs.npcs[3]["x"]), float(cs.npcs[3]["z"])))["error"] == "quest_none", "a plain villager has no quest")
	check(cs.quest_turn_in("q", int(farmer["id"]), at)["error"] == "no_items", "not enough materials")
	acc["inv"]["wood"] = 25
	var m0: int = int(acc["money"])
	var r1: Dictionary = cs.quest_turn_in("q", int(farmer["id"]), at)
	check(r1["ok"] and r1["step"] == 1 and r1["reward"] == 30 and int(acc["inv"]["wood"]) == 5 and int(acc["money"]) == m0 + 30, "step 1: materials taken, coins paid")
	check(int(acc["friends"][str(farmer["id"])]) == Story.QUEST_FRIEND_POINTS and int(acc["stats"]["quests"]) == 1, "a step adds friendship and counts")
	acc["inv"]["stone"] = 30
	check(cs.quest_turn_in("q", int(farmer["id"]), at)["error"] == "quest_friend", "step 2 needs friendship level (even with the materials)")
	check(int(acc["inv"]["stone"]) == 30 and int(acc["quests"]["farmer"]) == 1, "a refused hand-in takes nothing")
	acc["friends"][str(farmer["id"])] = FWConst.FRIEND_LEVELS[0]
	var r2: Dictionary = cs.quest_turn_in("q", int(farmer["id"]), at)
	check(r2["ok"] and r2["step"] == 2 and int(acc["inv"]["stone"]) == 5, "step 2 after becoming friends")
	acc["inv"]["brick"] = 20
	acc["friends"][str(farmer["id"])] = FWConst.FRIEND_LEVELS[1]
	var gem0: int = int(acc["inv"].get("gem", 0))
	var r3: Dictionary = cs.quest_turn_in("q", int(farmer["id"]), at)
	check(r3["ok"] and r3["step"] == 3 and r3["bonus_item"] == "gem" and int(acc["inv"]["gem"]) == gem0 + 1 and int(acc["inv"]["brick"]) == 5, "final step pays the bonus gift")
	check(cs.quest_turn_in("q", int(farmer["id"]), at)["error"] == "quest_none", "a finished chain cannot be repeated")
	# دستاوردهای مأموریت
	var got: Array = Book.evaluate(cs, "q", {"pos": Vector3(FWConst.CITY_SIZE * 0.5, 2.0, FWConst.CITY_SIZE * 0.5), "mine": ""})
	var ids: Array = []
	for g in got:
		ids.append(g["id"])
	check(ids.has("quest_first") and ids.has("quest_chain") and not ids.has("quest_five"), "quest entries unlock (%s)" % str(ids))
	var st: Dictionary = Book.public_state(cs, "q")
	check(int(st["quests"]["farmer"]) == 3, "public state carries quest progress")
	# ذخیره و بارگذاری و ورودی خراب
	var raw: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	var back = CityState.from_dict(raw)
	check(back != null and int(back.accounts["q"]["quests"]["farmer"]) == 3 and int(back.accounts["q"]["stats"]["quests"]) == 3, "quest progress survives save and load")
	raw["accounts"]["q"]["quests"] = {"farmer": 99, "ghost": 2, "baker": -4}
	var back2 = CityState.from_dict(raw)
	check(back2 != null and int(back2.accounts["q"]["quests"]["farmer"]) == 3 and not back2.accounts["q"]["quests"].has("ghost") and int(back2.accounts["q"]["quests"]["baker"]) == 0, "corrupt quest data is clamped or dropped")
	var old: Dictionary = JSON.parse_string(JSON.stringify(cs.to_dict()))
	old["accounts"]["q"].erase("quests")
	var back3 = CityState.from_dict(old)
	check(back3 != null and back3.accounts["q"]["quests"].is_empty(), "old saves without quests load empty")
	# --- خلاقانه ---
	var cc = CityState.new(4243)
	cc.creative = true
	_login(cc, "maker")
	NpcSim.ensure_npcs(cc)
	var cf: Dictionary = cc.npcs[0]
	var cat := Vector2(float(cf["x"]), float(cf["z"]))
	cc.accounts["maker"]["inv"] = {}
	var cm: int = int(cc.accounts["maker"]["money"])
	var cr: Dictionary = cc.quest_turn_in("maker", int(cf["id"]), cat)
	check(cr["ok"] and cr["reward"] == 0 and int(cc.accounts["maker"]["money"]) == cm and int(cc.accounts["maker"]["inv"].get("wood", 0)) == 0, "creative: no materials needed, no coins")
	check(int(cc.accounts["maker"]["quests"]["farmer"]) == 1, "creative still records progress")
	# --- کاروان صحرا: نقش‌های مخصوص جهان ---
	var dcs = CityState.new(int(Scenarios.def("desert_caravan")["seed"]))
	_login(dcs, "d")
	ScenarioApply.apply(dcs, "desert_caravan")
	var nomad: Dictionary = dcs.npcs[0]
	dcs.accounts["d"]["inv"] = {"clay": 20}
	var dr: Dictionary = dcs.quest_turn_in("d", int(nomad["id"]), Vector2(float(nomad["x"]), float(nomad["z"])))
	check(dr["ok"] and dr["role"] == "nomad" and int(dcs.accounts["d"]["quests"]["nomad"]) == 1, "scenario casts have their own quests (nomad in the desert)")

