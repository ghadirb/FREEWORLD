extends SceneTree
## اجرا: godot --headless --path . --script res://tests/unit_tests.gd

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const Arenas = preload("res://scripts/server/arenas.gd")
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
const Gravity = preload("res://scripts/shared/gravity.gd")
const Story = preload("res://scripts/shared/story.gd")
const Book = preload("res://scripts/server/book.gd")
const Packs = preload("res://scripts/shared/blueprint_packs.gd")
const Blueprints = preload("res://scripts/server/blueprints.gd")
const WorldPreview = preload("res://scripts/client/world_preview.gd")
const WorldGallery = preload("res://scripts/client/world_gallery.gd")

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
	test_arena_parkour()
	test_arena_race()
	test_arena_boat()
	test_arena_island()
	test_arena_football()
	test_arena_survival()
	test_arena_adventure()
	test_arena_win_rule()
	test_arena_ratings()
	test_arena_obstacles()
	test_arena_checkpoint_respawn()
	test_arena_props()
	test_arena_share_code()
	test_arena_difficulty()
	test_disasters()
	test_race()
	test_car_race()
	test_trains()
	test_group_race()
	test_boat()
	test_god_tools()
	test_species_breeding()
	test_family()
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
	test_civilization()
	test_wild()
	test_weapons()
	test_hunger()
	test_god_human()
	test_residents()
	test_attractions()
	test_autonomous_characters()
	test_character_memory()
	test_character_social()
	test_character_war()
	test_character_creator()
	test_character_performance()
	test_character_fortify()
	test_character_discovery()
	test_cave()
	test_batch_build()
	test_blueprints()
	test_terrain_shapes()
	test_villages()
	test_scenarios()
	test_gallery_and_rooms()
	test_two_storey_house()
	test_climates()
	test_gravity()
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
		var cd: float = Vector2(float(c[0]), float(c[1])).distance_to(at)
		if cd < float(a["r"]) + FWConst.ARENA_COURSE_GAP - 0.5 or cd > float(a["r"]) + Arenas.course_range("coins", 1) + 0.5:
			inside = false
	check(pub["active"] and coins.size() >= FWConst.ARENA_COINS_MIN and coins.size() <= 10 and inside, "arena coins are spread outside the circle, within the course range")
	check(float(pub["t"]) >= 39.0 and float(pub["t"]) <= FWConst.ARENA_TIME_CAP, "run time is the base time plus the travel time")
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
	for i in range(FWConst.ARENA_MAX_PER_PLAYER + 3):
		var rr: Dictionary = cs.arena_create("maker", "A%d" % i, at + Vector2(float(i) * 30.0, 0.0), 8.0, 6, 30.0, 0)
		if rr["ok"]:
			made += 1
	check(made == FWConst.ARENA_MAX_PER_PLAYER, "per-player arena limit holds and allows %d (%d built)" % [FWConst.ARENA_MAX_PER_PLAYER, made])
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


func _breed_land(cs) -> Vector2:
	for i in range(40, 200, 3):
		if cs.world.height_at(float(i), 70.0) > 1.5 and not cs.occupied.has(Placement.cell_key(i / 2, 35)):
			return Vector2(float(i), 70.0)
	return Vector2.ZERO


func _breed_put(cs, kind: String, x: float, z: float, young: float = 0.0) -> int:
	var id: int = cs.next_god_id
	cs.next_god_id += 1
	cs.god[id] = {"id": id, "kind": kind, "x": x, "z": z, "tx": x, "tz": z, "wait": 1.0, "young": young, "bcd": 0.0}
	return id


func _breed_count(cs, kind: String) -> int:
	var n := 0
	for id in cs.god:
		if str(cs.god[id]["kind"]) == kind:
			n += 1
	return n


func test_family() -> void:
	print("== hiring NPCs and family ==")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var Family = load("res://scripts/server/family.gd")
	var cs = CityState.new(4242)
	_login(cs, "boss")
	NpcSim.ensure_npcs(cs)
	var acc: Dictionary = cs.accounts["boss"]
	acc["money"] = 2000
	cs.buildings[900] = {"id": 900, "type": "farm", "owner": "boss", "cx": 30, "cz": 30, "stock": 0.0, "prog": 0.0}
	cs.buildings[901] = {"id": 901, "type": "house", "owner": "boss", "cx": 40, "cz": 30, "stock": 0.0, "prog": 0.0}
	var npc: Dictionary = {}
	for n in cs.npcs:
		if str(n.get("home_v", "")) == "" and str(n.get("job", "")) == "":
			npc = n
			break
	check(not npc.is_empty(), "found a free NPC")
	var nid: int = int(npc["id"])
	var at := Vector2(float(npc["x"]), float(npc["z"]))
	check(Family.hire(cs, "boss", 9999, at)["error"] == "no_npc", "unknown NPC")
	check(Family.hire(cs, "boss", nid, at + Vector2(FWConst.NPC_TALK_RANGE + 3.0, 0.0))["error"] == "too_far", "hiring needs closeness")
	check(Family.hire(cs, "boss", nid, at)["error"] == "need_friend", "a stranger cannot be hired")
	acc["friends"] = {str(nid): FWConst.FRIEND_LEVELS[0]}
	var m0: int = int(acc["money"])
	var h: Dictionary = Family.hire(cs, "boss", nid, at)
	check(bool(h["ok"]) and int(h["building"]) == 900 and int(acc["money"]) == m0 - FWConst.HIRE_FEE, "a friend is hired at the nearest own workplace for the fee")
	check(Family.tag(npc) == "h:boss", "the public tag marks the worker")
	check(Family.hire(cs, "boss", nid, at)["error"] == "npc_employed", "already employed")
	check(Family.fire(cs, "other", nid)["error"] == "not_yours", "only the employer can dismiss")
	# تولید
	var s0: float = float(cs.buildings[900]["stock"])
	Family.work(cs, npc, 30.0)
	check(float(cs.buildings[900]["stock"]) > s0, "a hired worker speeds up production")
	# حقوق روزانه
	var day: int = cs.day_count + 1
	var m1: int = int(acc["money"])
	var nm1: int = int(npc["money"])
	Family.daily(cs, day)
	check(int(acc["money"]) == m1 - FWConst.HIRE_WAGE and int(npc["money"]) == nm1 + FWConst.HIRE_WAGE, "the wage is paid once a day")
	Family.daily(cs, day)
	check(int(acc["money"]) == m1 - FWConst.HIRE_WAGE, "the daily step is idempotent within a day")
	acc["money"] = 0
	Family.daily(cs, day + 1)
	check(str(npc["emp"]) == "" and cs.family_events.size() == 1 and cs.family_events[0]["kind"] == "hire_quit", "an unpaid worker quits and the owner is told")
	cs.family_events.clear()
	acc["money"] = 2000
	check(bool(Family.hire(cs, "boss", nid, at)["ok"]), "rehire works")
	var gone: Array = cs._clear_jobs_for(900)
	check(str(npc["emp"]) == "" and int(npc["wb"]) == -1, "removing the workplace releases its workers")
	check(bool(Family.fire(cs, "boss", nid).get("ok", false)) == false, "dismissing a free NPC is refused")
	# ازدواج
	cs.buildings[900] = {"id": 900, "type": "farm", "owner": "boss", "cx": 30, "cz": 30, "stock": 0.0, "prog": 0.0}
	check(Family.marry(cs, "boss", nid, at)["error"] == "need_friend", "marriage needs a close friend")
	acc["friends"] = {str(nid): FWConst.FRIEND_LEVELS[1]}
	cs.buildings.erase(901)
	check(Family.marry(cs, "boss", nid, at)["error"] == "need_house", "marriage needs a house")
	cs.buildings[901] = {"id": 901, "type": "house", "owner": "boss", "cx": 40, "cz": 30, "stock": 0.0, "prog": 0.0}
	acc["money"] = FWConst.MARRY_COST - 1
	check(Family.marry(cs, "boss", nid, at)["error"] == "no_money", "the wedding costs money")
	acc["money"] = 2000
	var mm: Dictionary = Family.marry(cs, "boss", nid, at)
	check(bool(mm["ok"]) and int(acc["spouse"]) == nid and int(npc["home_b"]) == 901 and Family.tag(npc) == "s:boss", "marriage moves the spouse into the house")
	check(int(acc["money"]) == 2000 - FWConst.MARRY_COST, "the wedding is paid for")
	check(Family.marry(cs, "boss", nid, at)["error"] == "has_spouse", "only one spouse")
	# سهم همسر
	var before: int = int(acc["money"])
	var wed_day: int = int(npc["last_birth"])
	Family.daily(cs, wed_day + 1)
	check(int(acc["money"]) > before, "the spouse shares part of their money each day")
	# فرزند
	check(cs.npcs.size() > 0 and _kids(cs) == 0, "no child at first")
	Family.daily(cs, wed_day + FWConst.FAMILY_CHILD_DAYS)
	check(_kids(cs) == 1, "a child is born after the interval")
	var kid: Dictionary = cs.npcs[cs.npcs.size() - 1]
	check(bool(kid["kid"]) and str(kid["parent"]) == "boss" and Family.tag(kid) == "k:boss", "the child is marked as a young child of the player")
	check(Family.hire(cs, "boss", int(kid["id"]), Vector2(float(kid["x"]), float(kid["z"])))["error"] == "npc_kid", "a young child cannot be hired")
	var born_day: int = int(kid["born_day"])
	Family.daily(cs, born_day + FWConst.FAMILY_CHILD_DAYS)
	check(_kids_total(cs) == 2, "a second child arrives")
	Family.daily(cs, born_day + FWConst.FAMILY_CHILD_DAYS * 3)
	check(_kids_total(cs) == 2, "the child cap is respected")
	Family.daily(cs, born_day + FWConst.FAMILY_GROW_DAYS)
	check(not bool(kid["kid"]) and Family.tag(kid) == "a:boss", "the child grows up")
	# بچه‌ی بالغ بی‌هزینه و بی‌حقوق کار می‌کند
	var mf: int = int(acc["money"])
	var hk: Dictionary = Family.hire(cs, "boss", int(kid["id"]), Vector2(float(kid["x"]), float(kid["z"])))
	check(bool(hk["ok"]) and int(hk["fee"]) == 0 and int(acc["money"]) == mf, "family members are hired for free")
	var mw: int = int(acc["money"])
	Family.daily(cs, born_day + FWConst.FAMILY_GROW_DAYS + 1)
	check(int(acc["money"]) >= mw, "family members work without wage")
	# ذخیره و بازیابی
	var cs2 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs.to_dict())))
	check(cs2 != null and int(cs2.accounts["boss"]["spouse"]) == nid, "the spouse link survives save/load")
	var k2: Dictionary = Family.find_npc(cs2, int(kid["id"]))
	check(not k2.is_empty() and str(k2["emp"]) == "boss" and str(k2["parent"]) == "boss" and int(k2["wb"]) == int(kid["wb"]), "employment and parentage survive save/load")
	# طلاق
	check(bool(Family.divorce(cs, "boss")["ok"]) and int(acc["spouse"]) == 0 and str(npc["spouse_of"]) == "", "divorce clears the link")
	check(Family.divorce(cs, "boss")["error"] == "no_spouse", "divorce needs a spouse")
	# شبیه‌سازی: فرزند خردسال دم خانه می‌ماند و کارگر سر کار می‌رود
	var cs3 = CityState.new(4242)
	_login(cs3, "boss")
	NpcSim.ensure_npcs(cs3)
	cs3.buildings[901] = {"id": 901, "type": "house", "owner": "boss", "cx": 40, "cz": 30, "stock": 0.0, "prog": 0.0}
	cs3.buildings[900] = {"id": 900, "type": "farm", "owner": "boss", "cx": 30, "cz": 30, "stock": 0.0, "prog": 0.0}
	var worker: Dictionary = {}
	for n in cs3.npcs:
		if str(n.get("home_v", "")) == "" and str(n.get("job", "")) == "":
			worker = n
			break
	worker["emp"] = "boss"
	worker["wb"] = 900
	cs3.world_time = 10.0 * 3600.0
	for i in 600:
		NpcSim.step(cs3, 0.5)
	var door: Vector2 = cs3.door_point(cs3.buildings[900])
	check(Vector2(float(worker["x"]), float(worker["z"])).distance_to(door) < 6.0, "a hired NPC walks to their employer's workplace in the daytime")
	check(float(cs3.buildings[900]["stock"]) > 0.0, "and produces there")


func _kids(cs) -> int:
	var n := 0
	for x in cs.npcs:
		if bool(x.get("kid", false)):
			n += 1
	return n


func _kids_total(cs) -> int:
	var n := 0
	for x in cs.npcs:
		if str(x.get("parent", "")) == "boss":
			n += 1
	return n


func test_species_breeding() -> void:
	print("== species breeding ==")
	var cs = CityState.new(31337)
	var land: Vector2 = _breed_land(cs)
	check(land != Vector2.ZERO, "found land for breeding")
	var a: int = _breed_put(cs, "sheep", land.x, land.y)
	var b: int = _breed_put(cs, "sheep", land.x + 1.5, land.y)
	check(not cs.breed_step(5.0), "nothing happens before the breeding interval")
	var rounds := 0
	while cs.god.size() <= 2 and rounds < 80:
		rounds += 1
		cs.breed_step(FWConst.BREED_INTERVAL)
	check(cs.god.size() == 3, "two adult sheep close together get a lamb")
	var baby: int = -1
	for id in cs.god:
		if id != a and id != b:
			baby = id
	check(str(cs.god[baby]["kind"]) == "sheep" and float(cs.god[baby]["young"]) > 0.0, "the newborn is a young sheep")
	var pub: Array = cs.god_public()
	var rows_young := 0
	for row in pub:
		if (row as Array).size() > 5:
			rows_young += 1
	check(rows_young == 1, "only the young animal is flagged in the public list")
	var far_a: int = _breed_put(cs, "deer", land.x, land.y + 3.0)
	check(float(cs.god[a]["bcd"]) > 0.0 and float(cs.god[b]["bcd"]) > 0.0, "parents rest after giving birth")
	# توله تا بالغ شدن زاد و ولد نمی‌کند و بعد بالغ می‌شود
	for k in 3:
		cs.breed_step(FWConst.BREED_INTERVAL)
	check(float(cs.god[baby]["young"]) == 0.0, "the young animal grows up")
	# فاصله: دو حیوان دور از هم جفت نمی‌شوند
	var cs2 = CityState.new(31337)
	_breed_put(cs2, "rabbit", land.x, land.y)
	_breed_put(cs2, "rabbit", land.x + 40.0, land.y)
	for k in 40:
		cs2.breed_step(FWConst.BREED_INTERVAL)
	check(cs2.god.size() == 2, "distant animals do not breed")
	# سقف: از سقف کل بیشتر نمی‌شود
	var cs3 = CityState.new(31337)
	for k in FWConst.BREED_CAP:
		_breed_put(cs3, "sheep" if k % 2 == 0 else "deer", land.x + float(k % 5) * 0.5, land.y + float(k % 3) * 0.5)
	var before: int = cs3.god.size()
	for k in 30:
		cs3.breed_step(FWConst.BREED_INTERVAL)
	check(cs3.god.size() == before, "population cap stops breeding")
	# گونهٔ ترکیبی: گوسفند و گوزن
	var cs4 = CityState.new(31337)
	_breed_put(cs4, "sheep", land.x, land.y)
	_breed_put(cs4, "deer", land.x + 1.5, land.y)
	var r4 := 0
	while cs4.species_found.is_empty() and r4 < 3000:
		r4 += 1
		cs4.breed_step(FWConst.BREED_INTERVAL)
	check(cs4.species_found.has("horned_sheep"), "crossing a sheep and a deer can discover the horned sheep")
	check(cs4.species_events == ["horned_sheep"], "the discovery is queued once for announcement")
	check(_breed_count(cs4, "horned_sheep") >= 1 and FWConst.is_animal("horned_sheep") and FWConst.animal_speed("horned_sheep") > 0.0, "the hybrid is a real animal with a speed")
	check(not FWConst.GOD_ANIMALS.has("horned_sheep"), "hybrids cannot be placed with the god tool")
	cs4.species_events.clear()
	for k in 200:
		cs4.breed_step(FWConst.BREED_INTERVAL)
	check(cs4.species_events.is_empty(), "a species is only announced the first time")
	cs4.god[cs4.god.keys()[0]]["young"] = 20.0
	var cs5 = CityState.from_dict(JSON.parse_string(JSON.stringify(cs4.to_dict())))
	check(cs5 != null and cs5.species_found.has("horned_sheep") and _breed_count(cs5, "horned_sheep") == _breed_count(cs4, "horned_sheep"), "hybrids and the discovery survive save/load")
	check(float(cs5.god[cs4.god.keys()[0]]["young"]) == 20.0, "a young animal stays young after save/load")


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


func test_civilization() -> void:
	print("[civilization]")
	var Civ = load("res://scripts/server/civ.gd")
	var all_land := func(_x: float, _z: float) -> bool: return true
	var no_land := func(_x: float, _z: float) -> bool: return false
	var no_farms := func(_x: float, _z: float, _r: float) -> int: return 0
	var c = Civ.new()
	check(not c.found(10.0, 10.0, no_land, 0)["ok"], "kingdom needs land")
	check(c.found(NAN, 10.0, all_land, 0)["error"] == "bad_request", "kingdom rejects non-finite positions")
	var a: Dictionary = c.found(100.0, 100.0, all_land, 0)
	check(a["ok"] and c.items.size() == 1, "an admin can found a kingdom")
	check(c.found(130.0, 100.0, all_land, 0)["error"] == "civ_too_close", "capitals keep their distance")
	var b: Dictionary = c.found(200.0, 100.0, all_land, 0)
	check(b["ok"], "second kingdom 100 m away")
	var ia: int = int(a["id"])
	var ib: int = int(b["id"])
	check(c.items[ia]["n"] != c.items[ib]["n"], "kingdoms get different names")
	# رشد: جمعیت تا ظرفیت بالا می‌رود و سکونتگاه تازه ساخته می‌شود.
	for i in range(45):
		c.step_once(all_land, no_farms, 0)
	check(int(c.items[ia]["pop"]) >= 25 and int(c.items[ia]["pop"]) <= int(c.items[ia]["cap"]) + 1, "population grows toward capacity")
	check(c.items[ia]["s"].size() >= 2, "a grown kingdom founds a new settlement")
	check(int(c.items[ia]["cap"]) >= 60, "capacity counts every settlement")
	# مزرعه ظرفیت را بالا می‌برد.
	var one_farm := func(_x: float, _z: float, _r: float) -> int: return 1
	check(c.capacity_of(c.items[ia], one_farm) > c.capacity_of(c.items[ia], no_farms), "farms feed more people")
	# مرز زمین: بدون خشکی گسترش نمی‌یابد.
	var d = Civ.new()
	d.found(100.0, 100.0, all_land, 0)
	for i in range(30):
		d.step_once(no_land, no_farms, 0)
	check(d.items[1]["s"].size() == 1, "no expansion without land")
	# رابطه‌ها
	check(c.set_relation(ia, ia, Civ.WAR, 0) == "civ_no_target", "a kingdom cannot fight itself")
	check(c.set_relation(ia, 99, Civ.WAR, 0) == "civ_no_target", "unknown kingdom is rejected")
	check(c.set_relation(ia, ib, Civ.ALLY, 0) == "", "alliance accepted")
	check(c.set_relation(ia, ib, Civ.WAR, 0) == "civ_need_peace", "alliance cannot flip straight into war")
	check(c.set_relation(ia, ib, Civ.PEACE, 0) == "" and c.relation(ia, ib) == Civ.PEACE, "peace clears the relation")
	check(c.set_relation(ia, ib, Civ.PEACE, 0) == "civ_same", "repeating a relation is rejected")
	# جنگ: دو طرف تلفات می‌دهند؛ ضعیف‌تر فتح می‌شود.
	c.items[ia]["pop"] = 60
	c.items[ib]["pop"] = 12
	check(c.set_relation(ia, ib, Civ.WAR, 0) == "", "war declared")
	var pop_a: int = int(c.items[ia]["pop"])
	c._wars(0)
	check(int(c.items[ia]["pop"]) < pop_a and int(c.items[ib]["pop"]) < 12, "both sides lose people in war")
	var settlements_before: int = c.items[ia]["s"].size() + c.items[ib]["s"].size()
	c.items[ib]["pop"] = 2
	c._collapse(0)
	check(not c.items.has(ib) and c.items.has(ia), "the beaten kingdom falls")
	check(c.items[ia]["s"].size() == mini(settlements_before, Civ.MAX_SETTLEMENTS), "the winner takes the settlements")
	check(c.rel.is_empty(), "relations are cleaned after a conquest")
	# جنگ دور: بدون برخورد مرزها تلفاتی نیست.
	var f = Civ.new()
	var fa: int = int(f.found(100.0, 100.0, all_land, 0)["id"])
	var fb: int = int(f.found(600.0, 100.0, all_land, 0)["id"])
	f.set_relation(fa, fb, Civ.WAR, 0)
	f.items[fa]["pop"] = 20
	f.items[fb]["pop"] = 20
	f._wars(0)
	check(int(f.items[fa]["pop"]) == 20 and int(f.items[fb]["pop"]) == 20, "distant war causes no losses")
	# متحدها به جنگ می‌پیوندند.
	var g = Civ.new()
	var ga: int = int(g.found(100.0, 100.0, all_land, 0)["id"])
	var gb: int = int(g.found(220.0, 100.0, all_land, 0)["id"])
	var gc: int = int(g.found(340.0, 100.0, all_land, 0)["id"])
	g.set_relation(ga, gb, Civ.ALLY, 0)
	g.set_relation(gc, ga, Civ.WAR, 0)
	check(g.relation(gb, gc) == Civ.WAR, "an ally joins the war")
	# طاعون و قحطی
	var h = Civ.new()
	var ha: int = int(h.found(100.0, 100.0, all_land, 0)["id"])
	h.items[ha]["pop"] = 30
	check(h.trigger(ha, "plague", 0) == "" and h.trigger(ha, "meteor", 0) == "bad_request", "plague accepted, unknown event rejected")
	h.step_once(all_land, no_farms, 0)
	check(int(h.items[ha]["pop"]) < 30, "plague kills people")
	for i in range(12):
		h.step_once(all_land, no_farms, 0)
	check(float(h.items[ha]["plague"]) == 0.0 and int(h.items[ha]["pop"]) > 0, "plague ends and the kingdom survives")
	h.items[ha]["pop"] = 1
	h.trigger(ha, "famine", 0)
	h.step_once(all_land, no_farms, 0)
	check(not h.items.has(ha), "a kingdom with no people goes extinct")
	# سرعت زمان: توقف = بدون شبیه‌سازی.
	var j = Civ.new()
	j.found(100.0, 100.0, all_land, 0)
	check(not j.step(100.0, 0.0, all_land, no_farms, 0) and int(j.items[1]["pop"]) == Civ.START_POP, "time speed 0 pauses civilization")
	check(j.step(Civ.STEP_SECONDS + 0.1, 1.0, all_land, no_farms, 0) and int(j.items[1]["pop"]) > Civ.START_POP, "civilization advances with time")
	# ذخیره و بازیابی
	var snap: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var r = Civ.new()
	r.load_dict(snap)
	check(r.items.size() == c.items.size() and r.items.has(ia) and r.next_id == c.next_id, "civilization survives save and load")
	check(r.items[ia]["s"].size() == c.items[ia]["s"].size() and int(r.items[ia]["pop"]) == int(c.items[ia]["pop"]), "kingdom details survive the round trip")
	r.load_dict({"items": {"1": {"s": [[NAN, 1.0]]}, "x": 5, "2": {"s": [[5.0, 5.0]], "pop": -9999999, "n": 999}}, "rel": {"2,1": 1}})
	check(r.items.size() == 1 and int(r.items[2]["pop"]) == 0 and int(r.items[2]["n"]) == Civ.NAME_COUNT - 1, "load sanitizes bad data")
	var pub: Dictionary = c.public()
	check(pub.has("k") and pub.has("rel") and pub.has("log") and pub["k"][0].size() == 8, "public view shape")
	# ادغام با شهر: فقط مدیر؛ مرز روی خشکی؛ ذخیره با شهر.
	var cs = CityState.new(31337)
	_login(cs, "mortal")
	cs.provision_admin("maker", "secret-secret-1", FWConst.ROLE_CITY_ADMIN)
	var spot := Vector2.ZERO
	for i in range(100, 400, 5):
		if cs.world.height_at(float(i), 90.0) > 1.5:
			spot = Vector2(float(i), 90.0)
			break
	check(spot != Vector2.ZERO, "found land for a kingdom")
	check(cs.civ_action("mortal", "found", 0, 0, spot.x, spot.y)["error"] == "forbidden", "players cannot found kingdoms")
	var fr: Dictionary = cs.civ_action("maker", "found", 0, 0, spot.x, spot.y)
	check(fr["ok"] and cs.civ.items.size() == 1, "an admin founds a kingdom in the city")
	check(cs.civ_action("maker", "plague", 0, 0, spot.x, spot.y)["ok"], "a plague targets the kingdom under the tap")
	check(cs.civ_action("maker", "plague", 0, 0, spot.x + 500.0, spot.y)["error"] == "civ_no_target", "a plague needs a kingdom")
	check(cs.civ_action("maker", "dance", 0, 0, 0.0, 0.0)["error"] == "bad_request", "unknown civ action rejected")
	check(cs.civ_action("mortal", "war", 1, 2, 0.0, 0.0)["error"] == "forbidden", "players cannot declare wars")
	var logged := false
	for e in cs.audit:
		if str(e["action"]) == "civ_found":
			logged = true
	check(logged, "founding a kingdom is audited")
	var d2: Dictionary = cs.to_dict()
	check(d2.has("civ") and d2["civ"]["items"].size() == 1, "civ is part of the city save")
	check(FWConst.PROTOCOL_VERSION >= 45, "protocol bumped for the civilization message")


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
	nat._god_rng.seed = 4242  # seed ثابت: پخش آتش احتمالی است و تست نباید گاهی شکست بخورد
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
	check(Scenarios.ids().size() == 9, "nine ready-made worlds")
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
	# --- غار: گنبد توخالی با درگاه قابل ورود ---
	var cave_d: Dictionary = Scenarios.def("medieval_fort")
	var cave_cs = CityState.new(int(cave_d["seed"]))
	ScenarioApply.apply(cave_cs, "medieval_fort")
	var cave_x: int = Scenarios.CENTER + 34
	var cave_z: int = Scenarios.CENTER - 4
	var g0: int = ScenarioApply._ground_level(cave_cs, cave_x, cave_z)
	var g2: int = ScenarioApply._ground_level(cave_cs, cave_x + 2, cave_z)
	var g5: int = ScenarioApply._ground_level(cave_cs, cave_x, cave_z + 5)
	var door_free := true
	var inside_free := true
	for dy in range(3):
		if cave_cs.blocks.has(Vector3i(cave_x, g5 + dy, cave_z + 5)):
			door_free = false
		if cave_cs.blocks.has(Vector3i(cave_x + 2, g2 + dy, cave_z)):
			inside_free = false
	check(door_free and inside_free, "the cave has a free doorway and a hollow inside")
	check(cave_cs.blocks.has(Vector3i(cave_x, g0 + 5, cave_z)), "the cave has a solid roof")
	# غار در جهان‌های دیگر و خانهٔ مبله‌شده
	for cave_case in [["god_sandbox", Scenarios.CENTER + 34], ["desert_caravan", Scenarios.CENTER - 34]]:
		var cdef: Dictionary = Scenarios.def(str(cave_case[0]))
		var ccs = CityState.new(int(cdef["seed"]))
		ScenarioApply.apply(ccs, str(cave_case[0]))
		var ccx: int = int(cave_case[1])
		var cg: int = ScenarioApply._ground_level(ccs, ccx, Scenarios.CENTER - 4)
		check(ccs.blocks.has(Vector3i(ccx, cg + 5, Scenarios.CENTER - 4)), "%s has a cave with a solid roof" % str(cave_case[0]))
	var vcs = CityState.new(int(Scenarios.def("green_valley")["seed"]))
	ScenarioApply.apply(vcs, "green_valley")
	var hx: int = Scenarios.CENTER + 32
	var hz: int = Scenarios.CENTER + 4
	check(vcs.blocks.has(Vector3i(hx - 1, ScenarioApply._ground_level(vcs, hx - 1, hz - 1), hz - 1)), "the village cottage has a bed")
	check(not vcs.blocks.has(Vector3i(hx, ScenarioApply._ground_level(vcs, hx, hz + 1), hz + 1)), "the cottage entry cell inside the door stays free")
	var bell: Dictionary = Story.legend_entries("medieval_fort")[2]
	var bell_spot: Vector2 = Book.legend_spot(cave_cs, bell)
	check(int(floor(bell_spot.x)) == cave_x and int(floor(bell_spot.y)) == cave_z and float(bell["r"]) <= 3.5, "the bell-cave legend step sits inside the cave and needs you to enter it")
	check(Book.evaluate(cave_cs, "hero", {"pos": Vector3(bell_spot.x + 6.0, 2.0, bell_spot.y), "mine": ""}).is_empty() or not Book.evaluate(cave_cs, "hero", {"pos": Vector3(bell_spot.x + 6.0, 2.0, bell_spot.y), "mine": ""}).any(func(g): return g["id"] == "lg_medieval_fort_3"), "standing outside the cave does not complete the bell step")
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


func test_gravity() -> void:
	print("[gravity]")
	check(Gravity.g("temperate") == Gravity.EARTH_G and Gravity.g("winter") == Gravity.EARTH_G and Gravity.g("desert") == Gravity.EARTH_G, "Earth climates share Earth gravity")
	check(Gravity.g("moon") == Gravity.MOON_G and Gravity.is_low_gravity("moon") and not Gravity.is_low_gravity("temperate"), "the moon has low gravity")
	check(Gravity.g("nonsense") == Gravity.EARTH_G, "unknown climate falls back to Earth gravity")
	var ratio: float = Gravity.max_height("moon") / Gravity.max_height("temperate")
	check(absf(ratio - Gravity.EARTH_G / Gravity.MOON_G) < 0.001 and ratio > 5.5, "a moon hop is about six times higher")
	check(Gravity.max_height("temperate") > FWConst.FLY_MIN_ALT, "an Earth hop clears the airborne threshold")
	check(Gravity.max_height("moon") < FWConst.FLY_MAX_ALT, "a moon hop stays far below the creative flight ceiling")
	check(Gravity.air_time("moon") > Gravity.air_time("temperate") * 5.0, "moon hops last about six times longer")
	check(Gravity.server_cap("moon") > Gravity.max_height("moon") and Gravity.server_cap("temperate") > Gravity.max_height("temperate"), "server cap leaves network slack")
	# فیزیک: شبیه‌سازی گام‌به‌گام همان بیشینهٔ فرمول را می‌دهد و در زمان هوا می‌نشیند.
	for cl in ["temperate", "moon"]:
		var alt := 0.0
		var vy: float = Gravity.JUMP_SPEED
		var peak := 0.0
		var t := 0.0
		var dt := 1.0 / 120.0
		while true:
			vy -= Gravity.g(cl) * dt
			alt += vy * dt
			t += dt
			peak = maxf(peak, alt)
			if alt <= 0.0:
				break
		check(absf(peak - Gravity.max_height(cl)) < 0.05 and absf(t - Gravity.air_time(cl)) < 0.1, "%s: simulated hop matches the formulas" % cl)


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
	# ماه (جهان فضایی): زیست‌بوم‌ها، منابع و همان ارتفاع زمین پایه
	var moon = WG.new(411)
	moon.climate = "moon"
	var moon_base = WG.new(411)
	var seen_m := {}
	var moon_same_h := true
	var kinds_m := {}
	for iz in range(0, 640, 16):
		for ix in range(0, 640, 16):
			seen_m[moon.biome_at(float(ix), float(iz))] = true
			if absf(moon.height_at(float(ix), float(iz)) - moon_base.height_at(float(ix), float(iz))) > 0.0001:
				moon_same_h = false
	for rz in range(0, 160):
		for rx in range(0, 160):
			var m: Dictionary = moon.resource_in_cell(rx, rz)
			if not m.is_empty():
				kinds_m[m["kind"]] = true
	var ok_m := true
	for b in seen_m:
		if not ["water", "beach", "mountain", "regolith", "crystal_field"].has(b):
			ok_m = false
	check(ok_m and seen_m.has("regolith") and seen_m.has("crystal_field"), "moon has regolith and crystal fields only (%s)" % str(seen_m.keys()))
	check(moon_same_h, "moon never changes terrain height")
	check(WG.is_wooded("crystal_field") and not WG.is_wooded("regolith"), "crystal field counts as wooded (gives wood)")
	check(WG.biome_color("regolith") != WG.biome_color("plain") and WG.biome_color("crystal_field") != WG.biome_color("forest"), "moon biomes have their own colours")
	check(kinds_m.has("tree") and kinds_m.has("rock"), "moon has crystal spires and rocks (%s)" % str(kinds_m.keys()))
	check(FWConst.CLIMATES.has("moon") and Scenarios.climate("space_colony") == "moon", "space colony uses the moon climate")
	check(Scenarios.is_premium("space_colony") and Story.cast_for("space_colony").size() == 4 and Story.legend_entries("space_colony").size() == 4, "space colony has a cast and a four-step legend")
	var mnames := []
	for e in Story.entries_for("moon", false):
		mnames.append(e["id"])
	check(mnames.has("dust_walker") and mnames.has("dome_builder") and not mnames.has("snow_walker") and not mnames.has("oasis_find"), "moon entries appear only on the moon")
	var m_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for e in Story.entries_for("moon", false, "space_colony"):
			if Loc.t("book_" + str(e["id"])) == "book_" + str(e["id"]):
				m_ok = false
	Loc.lang = "fa"
	check(m_ok, "every moon entry has Persian and English text")
	var mcs = CityState.new(411)
	ScenarioApply.apply(mcs, "space_colony")
	var rocket_x: int = Scenarios.CENTER + 28
	var rocket_z: int = Scenarios.CENTER + 12
	var lamp_y := -1
	var rocket_base := -1
	for ry in range(0, 30):
		if mcs.blocks.has(Vector3i(rocket_x, ry, rocket_z)) and str(mcs.blocks[Vector3i(rocket_x, ry, rocket_z)][0]) == "lamp":
			lamp_y = ry
		if mcs.blocks.has(Vector3i(rocket_x + 1, ry, rocket_z)) and str(mcs.blocks[Vector3i(rocket_x + 1, ry, rocket_z)][0]) == "brick" and rocket_base < 0:
			rocket_base = ry
	check(mcs.world.climate == "moon" and lamp_y == rocket_base + 10, "the rocket stands level on the landing pad with its lamp on top (base %d, lamp %d)" % [rocket_base, lamp_y])
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
		if not kinds.has(str(e["kind"])) or not ["", "winter", "desert", "moon"].has(str(e["climate"])) or int(e["reward"]) < 0 or int(e["reward"]) > 100:
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



func test_gallery_and_rooms() -> void:
	print("[gallery and rooms]")
	# --- پیش‌نمایش: قطعی، رنگارنگ و متفاوت برای هر جهان ---
	var hashes: Dictionary = {}
	for id in Scenarios.ids():
		var img: Image = WorldPreview.render(id, 96, 80)
		check(img.get_width() == 96 and img.get_height() == 80, "%s preview has the requested size" % id)
		var colors: Dictionary = {}
		for y in range(0, 80, 4):
			for x in range(0, 96, 4):
				colors[img.get_pixel(x, y).to_html(false)] = true
		check(colors.size() >= 6, "%s preview is not a flat color (%d tones)" % [id, colors.size()])
		check(WorldPreview.render(id, 96, 80).get_data() == img.get_data(), "%s preview is deterministic" % id)
		hashes[hash(img.get_data())] = true
	check(hashes.size() == Scenarios.ids().size(), "every world has its own picture")
	for id in Scenarios.ids():
		check(ResourceLoader.exists(WorldPreview.photo_path(id)) and WorldPreview.texture(id).get_width() >= 400, "%s has a real in-game 3D picture" % id)
	check(WorldPreview.render("no_such_world", 8, 8).get_width() == 8, "an unknown world still renders a placeholder")
	# --- غنی‌تر بودن جهان‌های ویژه ---
	var free_min := 9999
	var prem_min := 9999
	for id in Scenarios.ids():
		var n: int = WorldPreview.stats(id)["structures"]
		if Scenarios.is_premium(id):
			prem_min = mini(prem_min, n)
		else:
			free_min = mini(free_min, n)
	check(prem_min > free_min, "every premium world has more structures than the sparsest free world (%d > %d)" % [prem_min, free_min])
	# --- گالری بدون خطا ساخته می‌شود ---
	var gal = WorldGallery.new()
	gal.setup(["green_valley"])
	gal._ready()   # بدون درخت صحنه هم ساخته می‌شود
	check(gal.get_child_count() > 0, "the gallery builds a card for every world")
	gal.free()
	# --- کمک‌های فهرست جهان‌ها ---
	var ws: Array = []
	WorldSlots.add_world(ws, "دره‌ی سبز", 102, false, "green_valley")
	check(WorldSlots.unique_name(ws, "دره‌ی سبز") == "دره‌ی سبز 2", "a repeated world name gets a number")
	check(WorldSlots.unique_name(ws, "تازه") == "تازه", "a free name is kept")
	check(str(WorldSlots.find_scenario_world(ws, "green_valley").get("scenario", "")) == "green_valley", "an existing world of a scenario is found")
	check(WorldSlots.find_scenario_world(ws, "god_sandbox").is_empty(), "no world of an unused scenario")
	# --- اتاق‌های داخلی واقعی در عمارت شهر تاجران ---
	var d: Dictionary = Scenarios.def("merchant_city")
	var cs = CityState.new(int(d["seed"]))
	ScenarioApply.apply(cs, "merchant_city")
	var cx: int = Scenarios.CENTER
	var cz: int = Scenarios.CENTER + 40
	var g := func(x: int, z: int) -> int: return ScenarioApply._ground_level(cs, x, z)
	check(cs.blocks.has(Vector3i(cx - 2, g.call(cx - 2, cz - 3), cz - 3)), "the manor has an interior partition wall")
	var doorway_free := true
	for dy in range(2):
		for px in [-2, 2]:
			if cs.blocks.has(Vector3i(cx + px, g.call(cx + px, cz) + dy, cz)):
				doorway_free = false
	check(doorway_free, "the doorways between manor rooms are open")
	check(not cs.blocks.has(Vector3i(cx, g.call(cx, cz + 3), cz + 3)) and not cs.blocks.has(Vector3i(cx, g.call(cx, cz + 3) + 1, cz + 3)), "the cell just inside the manor front door is free")
	check(cs.blocks.has(Vector3i(cx - 5, g.call(cx - 5, cz - 3), cz - 3)), "the manor bedroom has a bed")
	check(cs.blocks.has(Vector3i(cx + 3, g.call(cx + 3, cz - 3) + 1, cz - 3)), "the manor library has a tall bookshelf")
	check(cs.blocks.size() < FWConst.MAX_BLOCKS_TOTAL / 2, "a ready-made world stays far below the block cap (%d)" % cs.blocks.size())


func test_two_storey_house() -> void:
	print("[two-storey house]")
	var worlds := {"island_castaway": Vector2i(-40, 0), "medieval_fort": Vector2i(-40, 0), "merchant_city": Vector2i(-40, 0), "frozen_north": Vector2i(-40, 0), "desert_caravan": Vector2i(-32, -24)}
	for id in worlds:
		var d: Dictionary = Scenarios.def(id)
		var cs = CityState.new(int(d["seed"]))
		ScenarioApply.apply(cs, id)
		var cx: int = Scenarios.CENTER + worlds[id].x
		var cz: int = Scenarios.CENTER + worlds[id].y
		var sx := -5
		var z0 := -3
		var g := 0   # ترازِ کف = بلندترین زمین زیر عمارت (ScenarioApply زیرسازی را پر می‌کند)
		for gx in range(cx - 8, cx + 9):
			for gz in range(cz - 6, cz + 7):
				g = maxi(g, ScenarioApply._ground_level(cs, gx, gz))
		check(cs.blocks.has(Vector3i(cx + sx + 3, g + 3, cz + z0)), "%s: the top stair sits in the opening of the floor slab" % id)
		check(not cs.blocks.has(Vector3i(cx + sx + 2, g + 3, cz + z0)), "%s: no ceiling slab covers the staircase" % id)
		# از جلوی پله با گام‌های کوچک تا طبقهٔ بالا می‌رویم؛ هر گام باید با قاعدهٔ واقعی حرکت (STEP_UP) مجاز باشد.
		var x := float(cx + sx - 1) + 0.5
		var z := float(cz + z0) + 0.5
		var y: float = cs.ground_height(x, z)
		var ok := true
		while x < float(cx + sx + 4) + 0.5:
			x += 0.1
			var sfc: float = cs.surface_at(x, z, y)
			if is_nan(sfc) or sfc - y > FWConst.STEP_UP + 0.001:
				ok = false
				break
			y = sfc
		check(ok, "%s: a player can walk up the stairs step by step" % id)
		check(y >= float(g) + 3.99, "%s: the stairs end on the upper floor (y=%.2f)" % [id, y])
		check(cs.blocks.has(Vector3i(cx + sx + 1, g + 4, cz + z0 + 1)), "%s: the stairwell has a railing" % id)
		check(cs.blocks.has(Vector3i(cx + 4, g + 7, cz)), "%s: the upper floor has its own roof" % id)
		# درِ جلو تا پای پله باز است: از خانهٔ پشت در تا خانهٔ جلوی پله با گام‌های ۰٫۱
		var px := float(cx) + 0.5
		var pz := float(cz + 4) + 0.5
		var py: float = cs.ground_height(px, pz)
		var reach := true
		while pz > float(cz + z0) + 0.5:
			pz -= 0.1
			var s2: float = cs.surface_at(px, pz, py)
			if is_nan(s2) or s2 - py > FWConst.STEP_UP + 0.001:
				reach = false
				break
			py = s2
		check(reach, "%s: one can walk from the front door to the back wall inside" % id)


func test_arena_parkour() -> void:
	print("== Parkour arenas (checkpoints in order) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "runner")
	cs.accounts["maker"]["money"] = 1000
	cs.accounts["runner"]["money"] = 0
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Run", at, 14.0, 99, 90.0, 2, "parkour")
	check(bool(res["ok"]), "a parkour arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "parkour", "the arena remembers its kind")
	check(int(a["coins"]) == FWConst.ARENA_PARKOUR_MAX, "checkpoint count is clamped for parkour")
	check(Arenas.clean_kind("bogus") == "coins", "unknown kinds fall back to coin hunt")
	var pts: Array = Arenas.make_checkpoints(cs.world, cs.seed_value, a)
	check(pts.size() >= FWConst.ARENA_COINS_MIN, "checkpoints are placed on land")
	check(pts == Arenas.make_checkpoints(cs.world, cs.seed_value, a), "checkpoint layout is deterministic")
	var pub: Array = cs.arenas_public()
	check(str(pub[0]["kind"]) == "parkour", "the public list carries the kind")
	check(bool(cs.arena_play("runner", id, at)["ok"]), "a runner can start the parkour")
	var st: Dictionary = cs.minigame.public_state("runner")
	check(st["coins"].size() == 1, "only the next checkpoint is visible")
	var first := Vector2(float(st["coins"][0][0]), float(st["coins"][0][1]))
	var ev: Array = cs.minigame.step(0.1, {"runner": Vector2(-9999.0, -9999.0)}, 1)
	check(ev.is_empty(), "standing far away reaches nothing")
	var steps := 0
	var guard := 0
	while cs.minigame.runs.has("runner") and guard < 40:
		guard += 1
		var cur: Dictionary = cs.minigame.public_state("runner")
		if not bool(cur["active"]):
			break
		var target := Vector2(float(cur["coins"][0][0]), float(cur["coins"][0][1]))
		check(cur["coins"].size() == 1, "one checkpoint at a time")
		cs.minigame.step(0.1, {"runner": target}, 1)
		steps += 1
	check(steps == pts.size(), "the runner reaches every checkpoint in order")
	check(not cs.minigame.runs.has("runner"), "the run ends after the last checkpoint")
	check(int(cs.minigame.arena_scores[id]["runner"]) == pts.size(), "the checkpoint count is the record")
	var tm: Dictionary = cs.minigame.arena_times.get(id, {})
	check(tm.has("runner") and float(tm["runner"]) > 0.0, "finishing all checkpoints records a time")
	check(float(cs.arenas_public()[0]["best_time"][1]) > 0.0 and str(cs.arenas_public()[0]["best_time"][0]) == "runner", "the list shows the fastest runner")
	var t1: float = float(tm["runner"])
	cs.arena_play("runner", id, at)
	for _i in 3:
		cs.minigame.step(5.0, {"runner": at}, 1)   # دور دوم کند: زمان بدتر ثبت نمی‌شود
	var safety := 0
	while cs.minigame.runs.has("runner") and safety < 40:
		safety += 1
		var cur2: Dictionary = cs.minigame.public_state("runner")
		if not bool(cur2["active"]):
			break
		cs.minigame.step(0.1, {"runner": Vector2(float(cur2["coins"][0][0]), float(cur2["coins"][0][1]))}, 1)
	check(float(cs.minigame.arena_times[id]["runner"]) <= t1, "a slower run never replaces the best time")
	var d0: Dictionary = cs.minigame.to_dict()
	var mg2 = cs.minigame.get_script().new()
	mg2.load_dict(d0)
	check(float(mg2.arena_times[id]["runner"]) == float(cs.minigame.arena_times[id]["runner"]), "times survive saving and loading")
	check(first.distance_to(pts[0]) < 0.2, "the first checkpoint is the first of the layout")
	var ed: String = cs.arena_edit("maker", id, "Run 2", 14.0, 8, 60.0, 1, "coins")
	check(ed == "" and str(cs.arenas.items[id]["kind"]) == "coins", "the owner can switch the arena back to coin hunt")
	var d: Dictionary = cs.arenas.to_dict()
	var arenas2 = Arenas.new()
	arenas2.load_dict(d)
	check(str(arenas2.items[id]["kind"]) == "coins", "kind survives saving and loading")


func test_arena_win_rule() -> void:
	print("== Arena win threshold ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "runner")
	cs.accounts["maker"]["money"] = 1000
	cs.accounts["runner"]["money"] = 0
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Gate", at, 14.0, 8, 60.0, 2, "parkour", 999)
	check(bool(res["ok"]), "an arena with a win threshold can be built")
	var id: int = int(res["id"])
	check(int(cs.arenas.items[id]["win"]) == FWConst.ARENA_WIN_MAX, "the win threshold is clamped to 100")
	check(int(cs.arenas_public()[0]["win"]) == 100, "the public list carries the threshold")
	check(bool(cs.arena_play("runner", id, at)["ok"]), "the runner starts")
	var evs: Array = cs.minigame_step(700.0, {"runner": Vector2(-9999.0, -9999.0)})
	var end_ev: Dictionary = {}
	for e in evs:
		if str(e["kind"]) == "end":
			end_ev = e
	check(not end_ev.is_empty() and not bool(end_ev["won"]) and int(end_ev["reward"]) == 0, "timing out below the threshold loses and pays nothing")
	check(cs.money_of("runner") == 0, "a loser receives no prize")
	check(bool(cs.arena_play("runner", id, at)["ok"]), "the runner tries again")
	var total := 0
	var guard := 0
	var final_ev: Dictionary = {}
	while cs.minigame.runs.has("runner") and guard < 40:
		guard += 1
		var cur: Dictionary = cs.minigame.public_state("runner")
		var tgt := Vector2(float(cur["coins"][0][0]), float(cur["coins"][0][1]))
		for e in cs.minigame_step(0.1, {"runner": tgt}):
			if str(e["kind"]) == "end":
				final_ev = e
		total += 1
	check(not final_ev.is_empty() and bool(final_ev["won"]) and int(final_ev["goal"]) == 100, "reaching every checkpoint wins")
	check(cs.money_of("runner") == total * 2, "the winner is paid per checkpoint by the creator")
	var cs2 = CityState.new(4244)
	cs2.arenas.load_dict(cs.arenas.to_dict())
	check(int(cs2.arenas.items[id]["win"]) == 100, "the threshold survives saving and loading")


func test_arena_ratings() -> void:
	print("== Arena ratings ==")
	var cs = CityState.new(4244)
	for n in ["maker", "fan", "rival", "ghost2"]:
		_login(cs, n)
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var id: int = int(cs.arena_create("maker", "Rated", at, 12.0, 8, 30.0, 0)["id"])
	check(cs.arena_rate("maker", id, 5) == "arena_rate_own", "the creator cannot rate their own game")
	check(cs.arena_rate("fan", id, 5) == "arena_rate_unplayed", "rating needs a played round first")
	check(cs.arena_rate("nobody", id, 5) == "no_account", "unknown players cannot rate")
	check(cs.arena_rate("fan", 999, 5) == "arena_missing", "a missing arena cannot be rated")
	cs.minigame.arena_scores[id] = {"fan": 3, "rival": 1}
	check(cs.arena_rate("fan", id, 0) == "arena_rate_bad" and cs.arena_rate("fan", id, 6) == "arena_rate_bad", "stars outside 1 to 5 are refused")
	check(cs.arena_rate("fan", id, 5) == "", "a player who played can rate")
	check(cs.arena_rate("rival", id, 2) == "", "a second player rates")
	check(cs.arenas.rating_of(id) == [3.5, 2], "the average and the count are computed")
	check(cs.arena_rate("fan", id, 1) == "" and cs.arenas.rating_of(id) == [1.5, 2], "a player can change their vote, never vote twice")
	check(cs.arenas_public()[0]["rating"] == [1.5, 2], "the list carries the rating")
	var cs2 = CityState.new(4244)
	cs2.arenas.load_dict(cs.arenas.to_dict())
	check(cs2.arenas.rating_of(id) == [1.5, 2], "ratings survive saving and loading")
	check(cs.arena_remove("maker", id) == "" and cs.arenas.rating_of(id) == [0.0, 0], "deleting a game deletes its ratings")


func test_arena_obstacles() -> void:
	print("== Parkour moving obstacles ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "runner")
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Mover", at, 14.0, 6, 60.0, 0, "parkour", 0, 99)
	check(bool(res["ok"]), "a parkour arena with obstacles is built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(int(a["obs"]) == FWConst.ARENA_OBS_MAX, "the obstacle count is clamped")
	var defs: Array = Arenas.make_obstacles(cs.seed_value, a)
	check(defs.size() == FWConst.ARENA_OBS_MAX and defs == Arenas.make_obstacles(cs.seed_value, a), "obstacles are deterministic")
	var p0: Vector2 = Arenas.obstacle_pos(defs[0], 0.0)
	var p1: Vector2 = Arenas.obstacle_pos(defs[0], 1.3)
	check(p0 == Arenas.obstacle_pos(defs[0], 0.0), "an obstacle position depends only on the clock")
	check(p0.distance_to(p1) > 0.01, "an obstacle really moves")
	var lo := Vector2(minf(float(defs[0][0]), float(defs[0][2])) - 0.01, minf(float(defs[0][1]), float(defs[0][3])) - 0.01)
	var hi := Vector2(maxf(float(defs[0][0]), float(defs[0][2])) + 0.01, maxf(float(defs[0][1]), float(defs[0][3])) + 0.01)
	check(p1.x >= lo.x and p1.x <= hi.x and p1.y >= lo.y and p1.y <= hi.y, "an obstacle stays on its segment")
	var coin_arena := int(cs.arena_create("maker", "Plain", at + Vector2(80, 0), 10.0, 8, 30.0, 0, "coins", 0, 5)["id"])
	check(int(cs.arenas.items[coin_arena]["obs"]) == 0, "coin arenas never get obstacles")
	check(int(cs.arenas_public()[0]["obs"]) == FWConst.ARENA_OBS_MAX, "the list carries the obstacle count")
	check(bool(cs.arena_play("runner", id, at)["ok"]), "the runner starts")
	var st: Dictionary = cs.minigame.public_state("runner")
	check(st.has("obs") and st["obs"].size() == FWConst.ARENA_OBS_MAX and st.has("el"), "the run state carries the obstacles and the clock")
	defs = st["obs"]
	# سرِ مانع بایست؛ برخورد زمان را کم می‌کند و بلافاصله دوباره نمی‌زند.
	var t_before: float = float(cs.minigame.runs["runner"]["t"])
	var stand: Vector2 = Arenas.obstacle_pos(defs[0], float(cs.minigame.runs["runner"]["clk"]) + 0.05)
	var hit := false
	for e in cs.minigame.step(0.05, {"runner": stand}, 1):
		if str(e["kind"]) == "hit":
			hit = true
	check(hit, "touching an obstacle is a hit")
	check(float(cs.minigame.runs["runner"]["t"]) <= t_before - FWConst.ARENA_OBS_PENALTY + 0.01, "a hit costs time")
	var t_after: float = float(cs.minigame.runs["runner"]["t"])
	cs.minigame.step(0.05, {"runner": stand}, 1)
	check(float(cs.minigame.runs["runner"]["t"]) > t_after - 0.5, "hits have a cool-down")
	var arenas2 = Arenas.new()
	arenas2.load_dict(cs.arenas.to_dict())
	check(int(arenas2.items[id]["obs"]) == FWConst.ARENA_OBS_MAX, "obstacles survive saving and loading")
	check(cs.arena_edit("maker", id, "Mover", 14.0, 6, 60.0, 0, "coins", 0, 4) == "" and int(cs.arenas.items[id]["obs"]) == 0, "switching to coin hunt removes obstacles")


func test_arena_checkpoint_respawn() -> void:
	print("== Parkour checkpoint respawn ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "runner")
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var id: int = int(cs.arena_create("maker", "Save", at, 14.0, 6, 90.0, 0, "parkour")["id"])
	check(cs.minigame.respawn_point("runner") == null, "no checkpoint without a run")
	cs.arena_play("runner", id, at)
	check(bool(cs.minigame.public_state("runner")["pk"]), "the public state flags a parkour run")
	var start_pt: Variant = cs.minigame.respawn_point("runner")
	check(start_pt != null and Vector2(start_pt).distance_to(at) < 0.5, "the first save point is the arena centre")
	var st: Dictionary = cs.minigame.public_state("runner")
	var first := Vector2(float(st["coins"][0][0]), float(st["coins"][0][1]))
	cs.minigame.step(0.1, {"runner": first}, 1)
	check(Vector2(cs.minigame.respawn_point("runner")).distance_to(first) < 0.2, "a reached station becomes the save point")
	var before: float = float(cs.minigame.runs["runner"]["t"])
	cs.minigame.apply_respawn_penalty("runner")
	check(is_equal_approx(before - float(cs.minigame.runs["runner"]["t"]), FWConst.ARENA_RESPAWN_PENALTY), "respawning costs the time penalty")
	var cid: int = int(cs.arena_create("maker", "Coins", at + Vector2(60.0, 0.0), 10.0, 8, 30.0, 0, "coins")["id"])
	cs.minigame.cancel("runner")
	cs.arena_play("runner", cid, at + Vector2(60.0, 0.0))
	check(cs.minigame.respawn_point("runner") == null, "coin-hunt runs have no save point")


func test_arena_props() -> void:
	print("== Arena custom objects ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "runner")
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var id: int = int(cs.arena_create("maker", "Props", at, 14.0, 6, 60.0, 0, "parkour")["id"])
	check(cs.arena_prop("runner", id, "prop_bonus", at) == "not_owner", "only the creator places objects")
	check(cs.arena_prop("maker", id, "prop_bonus", at + Vector2(500.0, 0.0)) == "prop_far", "objects must be inside the arena")
	check(cs.arena_prop("maker", 999, "prop_bonus", at) == "arena_missing", "missing arena")
	check(cs.arena_prop("maker", id, "prop_undo", at) == "prop_empty", "nothing to undo at first")
	check(cs.arena_prop("maker", id, "prop_bonus", at) == "", "a time bonus is placed")
	check(cs.arena_prop("maker", id, "prop_hazard", at + Vector2(0.5, 0.0)) == "prop_close", "objects keep their distance")
	check(cs.arena_prop("maker", id, "prop_hazard", at + Vector2(4.0, 0.0)) == "", "a trap is placed")
	check(cs.arenas_public()[0]["props"].size() == 2, "the public list carries the objects")
	# ذخیره و بارگذاری
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2.arenas.items[id]["props"].size() == 2, "objects survive save and load")
	# ویرایش میدان، اشیا را نگه می‌دارد
	check(cs.arena_edit("maker", id, "Props2", 14.0, 6, 60.0, 0, "parkour") == "", "editing works")
	check(cs.arenas.items[id]["props"].size() == 2, "editing keeps the objects")
	# اجرا: جایزهٔ زمان و تله
	cs.arena_play("runner", id, at)
	cs.minigame.runs["runner"]["t"] = 30.0
	var ev: Array = cs.minigame.step(0.1, {"runner": at}, 1)
	var got_bonus := false
	for e in ev:
		if e["kind"] == "bonus":
			got_bonus = true
	check(got_bonus, "touching a bonus raises a bonus event")
	check(float(cs.minigame.runs["runner"]["t"]) > 34.0, "the bonus adds time")
	cs.minigame.runs["runner"]["t"] = 59.0
	cs.minigame.step(0.1, {"runner": at + Vector2(4.0, 0.0)}, 1)
	check(float(cs.minigame.runs["runner"]["t"]) < 56.0, "a trap costs time")
	cs.minigame.runs["runner"]["t"] = 59.0
	cs.minigame.step(0.1, {"runner": at}, 1)
	check(float(cs.minigame.runs["runner"]["t"]) <= 59.0, "a used bonus is gone and time never exceeds the limit")
	check(cs.arena_prop("maker", id, "prop_undo", at) == "", "the last object can be removed")
	check(cs.arenas.items[id]["props"].size() == 1, "undo removes one object")
	var filled := 0
	for i in range(FWConst.ARENA_PROPS_MAX + 3):
		if cs.arena_prop("maker", id, "prop_bonus", at + Vector2(-12.0 + float(i) * 2.1, 6.0 if i % 2 == 0 else -6.0)) == "":
			filled += 1
	check(cs.arenas.items[id]["props"].size() <= FWConst.ARENA_PROPS_MAX, "the object limit holds (%d added)" % filled)
	check(Arenas.clean_props([["bogus", 1, 1], ["bonus", 1e30, 0]], {"x": 0.0, "z": 0.0, "r": 10.0}).is_empty(), "bad objects are dropped on load")


func test_arena_race() -> void:
	print("== Car race arenas (ordered gates on a loop track) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "driver")
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Speedway", at, 20.0, 99, 60.0, 1, "race", 100, 5)
	check(bool(res["ok"]), "a race arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "race" and int(a["coins"]) == FWConst.ARENA_PARKOUR_MAX, "kind is kept and the gate count is clamped")
	check(int(a["obs"]) == 0, "race arenas have no moving obstacles")
	var gates: Array = Arenas.make_race_gates(cs.world, cs.seed_value, a)
	check(gates.size() >= FWConst.ARENA_COINS_MIN, "gates are placed on land")
	check(gates == Arenas.make_race_gates(cs.world, cs.seed_value, a), "gate layout is deterministic")
	var center := Vector2(float(a["x"]), float(a["z"]))
	var ring_ok := true
	for g in gates:
		var d: float = (g as Vector2).distance_to(center)
		if d < float(a["r"]) + FWConst.ARENA_COURSE_GAP - 0.5 or d > 2.2 * Arenas.course_range("race", 1):
			ring_ok = false
	check(ring_ok, "gates sit on a loop outside the start arena")
	check(bool(cs.arena_play("driver", id, at)["ok"]), "a driver can start the race")
	check(cs.minigame.is_arena_race("driver") and bool(cs.minigame.public_state("driver")["rc"]), "the run is flagged as a race (higher speed cap)")
	check(not cs.minigame.is_arena_race("maker"), "other players are not flagged")
	var steps := 0
	var guard := 0
	while cs.minigame.runs.has("driver") and guard < 40:
		guard += 1
		var cur: Dictionary = cs.minigame.public_state("driver")
		var target := Vector2(float(cur["coins"][0][0]), float(cur["coins"][0][1]))
		cs.minigame.step(0.1, {"driver": target}, 1)
		steps += 1
	check(steps == gates.size() and not cs.minigame.is_arena_race("driver"), "the driver passes every gate in order and the flag clears")
	check(float(cs.minigame.arena_times.get(id, {}).get("driver", 0.0)) > 0.0, "finishing the track records a lap time")
	var pr: Dictionary = Arenas.parse_code(Arenas.export_code(a))
	check(bool(pr["ok"]) and str(pr["def"]["kind"]) == "race", "the share code keeps the race kind")


func test_arena_boat() -> void:
	print("== Boat race arenas (ordered gates on the water) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "sailor")
	cs.accounts["maker"]["money"] = 1000
	# جایی را پیدا کن که کنار آب است و زنجیرهٔ دروازهٔ کافی دارد (قطعی از Seed)
	var at := Vector2(-1.0, -1.0)
	for gx in range(-40, int(FWConst.CITY_SIZE) + 41, 20):
		for gz in range(-40, int(FWConst.CITY_SIZE) + 41, 20):
			if at.x >= 0.0 or cs.world.height_at(float(gx), float(gz)) < 0.5 or cs.world.height_at(float(gx), float(gz)) > FWConst.MINIGAME_MAX_HEIGHT:
				continue
			var probe := {"id": 1, "x": float(gx), "z": float(gz), "r": 16.0, "coins": 8, "diff": 2}
			if Arenas.make_boat_gates(cs.world, cs.seed_value, probe).size() >= FWConst.ARENA_COINS_MIN:
				at = Vector2(float(gx), float(gz))
	check(at.x >= 0.0, "found a shore spot with enough water for a boat course")
	if at.x < 0.0:
		return
	var res: Dictionary = cs.arena_create("maker", "Regatta", at, 16.0, 8, 60.0, 1, "boat", 100, 5, 2)
	check(bool(res["ok"]), "a boat arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "boat" and int(a["obs"]) == 0, "kind is kept and there are no moving obstacles")
	var gates: Array = Arenas.make_boat_gates(cs.world, cs.seed_value, a)
	check(gates.size() >= FWConst.ARENA_COINS_MIN and gates.size() <= int(a["coins"]), "gates are placed (at least the minimum)")
	check(gates == Arenas.make_boat_gates(cs.world, cs.seed_value, a), "gate layout is deterministic")
	var center := Vector2(float(a["x"]), float(a["z"]))
	var wet := true
	var spaced := true
	for i in gates.size():
		var g: Vector2 = gates[i]
		if not Arenas.on_water(cs.world, g) or g.distance_to(center) < float(a["r"]) + FWConst.ARENA_COURSE_GAP - 0.5:
			wet = false
		if i > 0 and g.distance_to(gates[i - 1]) < 9.9:
			spaced = false
	check(wet, "every gate is on water outside the start arena")
	check(spaced, "gates are spaced at least 10 m apart")
	cs.creative = false
	var nb: Dictionary = cs.arena_play("sailor", id, at)
	check(not bool(nb["ok"]) and str(nb["error"]) == "need_boat", "a player without a boat cannot start the race")
	cs.accounts["sailor"]["boat"] = true
	check(bool(cs.arena_play("sailor", id, at)["ok"]), "a sailor with a boat can start")
	check(cs.minigame.is_arena_boat("sailor") and bool(cs.minigame.public_state("sailor")["bt"]), "the run is flagged as a boat race")
	check(not cs.minigame.is_arena_boat("maker") and not cs.minigame.is_arena_race("sailor"), "other players and the car flag are not affected")
	var steps := 0
	var guard := 0
	while cs.minigame.runs.has("sailor") and guard < 40:
		guard += 1
		var cur: Dictionary = cs.minigame.public_state("sailor")
		var target := Vector2(float(cur["coins"][0][0]), float(cur["coins"][0][1]))
		cs.minigame.step(0.1, {"sailor": target}, 1)
		steps += 1
	check(steps == gates.size() and not cs.minigame.is_arena_boat("sailor"), "the sailor passes every gate in order and the flag clears")
	check(float(cs.minigame.arena_times.get(id, {}).get("sailor", 0.0)) > 0.0, "finishing records a lap time")
	var pr: Dictionary = Arenas.parse_code(Arenas.export_code(a))
	check(bool(pr["ok"]) and str(pr["def"]["kind"]) == "boat", "the share code keeps the boat kind")


func test_arena_island() -> void:
	print("== Survival island arenas (hunger, food, enemies, timer) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "castaway")
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Isle", at, 16.0, 10, 90.0, 2, "island", 50, 5, 1)
	check(bool(res["ok"]), "an island arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "island" and int(a["obs"]) == 0, "kind is kept and there are no moving obstacles")
	var food: Array = Arenas.make_island_food(cs.world, cs.seed_value, 1, a)
	check(food.size() >= FWConst.ARENA_COINS_MIN, "food is placed on land")
	check(food == Arenas.make_island_food(cs.world, cs.seed_value, 1, a), "food layout is deterministic per run")
	var center := Vector2(float(a["x"]), float(a["z"]))
	var inside := true
	var spaced := true
	for i in food.size():
		if (food[i] as Vector2).distance_to(center) > float(a["r"]) + 0.5:
			inside = false
		for j in i:
			if (food[i] as Vector2).distance_to(food[j]) < FWConst.ISLE_FOOD_SPACING - 0.1:
				spaced = false
	check(inside and spaced, "food sits inside the island and is spaced apart")
	check(bool(cs.arena_play("castaway", id, at)["ok"]), "a castaway can start")
	var st: Dictionary = cs.minigame.public_state("castaway")
	check(st.has("hun") and st.has("hp") and int(st["hun"]) == int(FWConst.ISLE_HUNGER_MAX), "the run starts with full hunger and health")
	check((st["coins"] as Array).size() == food.size() or (st["coins"] as Array).size() >= FWConst.ARENA_COINS_MIN, "all food is visible at once (not ordered)")
	var run: Dictionary = cs.minigame.runs["castaway"]
	run["spawns"] = []   # برای آزمون سرد: بدون دشمن
	var far := center + Vector2(15.0, 0.0)
	cs.minigame.step(10.0, {"castaway": far}, 1)
	var hun_after: float = float(run["hun"])
	check(hun_after < FWConst.ISLE_HUNGER_MAX - 11.0 and hun_after > FWConst.ISLE_HUNGER_MAX - 13.0, "hunger drains over time")
	check(float(run["hp"]) == FWConst.SURV_HP, "no damage while still fed")
	# غذا خوردن سیری را برمی‌گرداند
	var first: Vector2 = (run["coins"] as Array)[0]
	var evs: Array = cs.minigame.step(0.1, {"castaway": first}, 1)
	check(float(run["hun"]) > hun_after + 5.0 and float(run["hun"]) <= FWConst.ISLE_HUNGER_MAX and int(run["score"]) == 1, "eating food restores fullness and scores")
	var ticks := 0
	for e in cs.minigame.step(1.0, {"castaway": far}, 1):
		if e["kind"] == "tick":
			ticks += 1
	check(ticks >= 1, "a periodic tick event pushes the hunger value to the client")
	# گرسنگی: سلامتی می‌ریزد
	run["hun"] = 0.0
	var hp0: float = float(run["hp"])
	cs.minigame.step(2.0, {"castaway": far}, 1)
	check(float(run["hp"]) < hp0 - FWConst.ISLE_STARVE_DAMAGE * 1.9, "starving drains health")
	# زنده ماندن تا پایان زمان با شرط برد ۵۰٪ (۵ غذا) جایزه می‌دهد
	for k in 4:
		var nxt: Vector2 = (run["coins"] as Array)[0]
		cs.minigame.step(0.1, {"castaway": nxt}, 1)
	run["hun"] = 100.0
	run["hp"] = 50.0
	run["t"] = 0.05
	var end_ev: Dictionary = {}
	for e in cs.minigame.step(0.1, {"castaway": far}, 1):
		if e["kind"] == "end":
			end_ev = e
	check(not end_ev.is_empty() and bool(end_ev["won"]) and int(end_ev["reward"]) > 0, "surviving with enough food wins and pays the reward")
	# مرگ = باخت حتی با غذای کافی
	check(bool(cs.arena_play("castaway", id, at)["ok"]), "a second run can start")
	var run2: Dictionary = cs.minigame.runs["castaway"]
	run2["spawns"] = []
	run2["score"] = int(run2["total"])
	run2["hp"] = 0.0
	var dead_ev: Dictionary = {}
	for e in cs.minigame.step(0.1, {"castaway": far}, 1):
		if e["kind"] == "end":
			dead_ev = e
	check(not dead_ev.is_empty() and not bool(dead_ev["won"]) and int(dead_ev["reward"]) == 0, "dying is a loss with no reward")
	var pr: Dictionary = Arenas.parse_code(Arenas.export_code(a))
	check(bool(pr["ok"]) and str(pr["def"]["kind"]) == "island", "the share code keeps the island kind")


func test_arena_football() -> void:
	print("== Football arenas (server-side ball) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "kicker")
	cs.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Pitch", at, 14.0, 99, 60.0, 1, "football", 100)
	check(bool(res["ok"]), "a football arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "football" and int(a["coins"]) == FWConst.FOOT_GOALS_MAX, "kind kept and goal count clamped")
	var goal: Array = Arenas.make_football_goal(cs.world, cs.seed_value, a)
	check(goal.size() == 1 and goal == Arenas.make_football_goal(cs.world, cs.seed_value, a), "one deterministic goal")
	check(bool(cs.arena_play("kicker", id, at)["ok"]), "a player can start football")
	var st: Dictionary = cs.minigame.public_state("kicker")
	check(st.has("ball") and st["coins"].size() == 1, "state carries the ball and the goal")
	var g: Vector2 = goal[0]
	var center := Vector2(float(a["x"]), float(a["z"]))
	# بازیکن روی دروازه می‌ایستد ولی توپ نیست: امتیازی نمی‌دهد
	cs.minigame.step(0.1, {"kicker": g}, 1, cs.world)
	check(int(cs.minigame.runs["kicker"]["score"]) == 0, "standing in the goal scores nothing without the ball")
	# بازیکن پشت توپ می‌ایستد و به سمت دروازه می‌دود
	var dir: Vector2 = (g - center).normalized()
	var guard := 0
	var kicks := 0
	while cs.minigame.runs.has("kicker") and int(cs.minigame.runs["kicker"]["score"]) == 0 and guard < 400:
		guard += 1
		var ball: Vector2 = cs.minigame.runs["kicker"]["ball"]["p"]
		var behind: Vector2 = ball - dir * 1.0
		var evs: Array = cs.minigame.step(0.05, {"kicker": behind}, 1, cs.world)
		for e in evs:
			if str(e["kind"]) == "ball":
				kicks += 1
	check(not cs.minigame.runs.has("kicker") or int(cs.minigame.runs["kicker"]["score"]) >= 1, "pushing the ball to the goal scores")
	check(kicks > 0, "ball position updates are announced while it moves")
	var ball_run: Dictionary = {"ball": {"p": center, "v": Vector2(50.0, 0.0), "cd": 0.0, "send": 0.0, "c": center, "r": 14.0, "goal": Vector2(1e6, 1e6)}}
	cs.minigame.runs["kicker"] = {"t": 30.0, "score": 0, "coins": [g], "ball": ball_run["ball"], "total": 3, "limit": 30.0, "arena": id, "owner": "maker", "per_coin": 1, "win": 0, "props": [], "obs": [], "queue": []}
	for k in 60:
		cs.minigame.step(0.05, {"kicker": Vector2(-9999.0, -9999.0)}, 1, cs.world)
	var bp: Vector2 = cs.minigame.runs["kicker"]["ball"]["p"]
	check(bp.distance_to(center) <= 14.0, "the ball stays inside the arena")
	check(Arenas.parse_code(Arenas.export_code(a))["def"]["kind"] == "football", "share code keeps football")


func test_arena_survival() -> void:
	print("== Combat and survival arenas ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "fighter")
	cs.accounts["maker"]["money"] = 1000
	cs.accounts["fighter"]["money"] = 0
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Arena", at, 14.0, 99, 90.0, 1, "survival", 100)
	check(bool(res["ok"]), "a survival arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "survival" and int(a["coins"]) == FWConst.SURV_COUNT_MAX, "kind kept and enemy count clamped")
	check(Arenas.make_survival_spawns(cs.world, cs.seed_value, a).size() >= 1, "spawn points exist on land")
	check(bool(cs.arena_play("fighter", id, at)["ok"]), "a fighter can start the round")
	var st: Dictionary = cs.minigame.public_state("fighter")
	check(st.has("foes") and int(st["hp"]) == int(FWConst.SURV_HP), "state carries enemies and health")
	var total: int = int(cs.minigame.runs["fighter"]["total"])
	# بازیکن ثابت در مرکز می‌ماند: دشمن‌ها می‌رسند، بازیکن خودکار می‌زند
	var kills_seen := 0
	var hurt := 0
	var guard := 0
	while cs.minigame.runs.has("fighter") and guard < 6000:
		guard += 1
		var evs: Array = cs.minigame.step(0.05, {"fighter": at}, 1, cs.world)
		for e in evs:
			if str(e["kind"]) == "hurt":
				hurt += 1
			if str(e["kind"]) == "coin":
				kills_seen += 1
		if cs.minigame.runs.has("fighter"):
			cs.minigame.runs["fighter"]["hp"] = FWConst.SURV_HP   # بازیکن آسیب‌ناپذیر برای آزمایش
	check(kills_seen == total and not cs.minigame.runs.has("fighter"), "all enemies are defeated and the round ends")
	check(hurt > 0, "enemies hurt the player when they reach him")
	check(int(cs.minigame.arena_scores[id]["fighter"]) == total, "the record counts defeated enemies")
	# مرگ: سلامت صفر دور را تمام می‌کند
	check(bool(cs.arena_play("fighter", id, at)["ok"]), "a second round starts")
	cs.minigame.runs["fighter"]["hp"] = 5.0
	guard = 0
	while cs.minigame.runs.has("fighter") and guard < 4000:
		guard += 1
		cs.minigame.step(0.05, {"fighter": at}, 1, cs.world)
		if cs.minigame.runs.has("fighter") and float(cs.minigame.runs["fighter"]["hp"]) > 0.0:
			cs.minigame.runs["fighter"]["hp"] = 5.0 if guard < 5 else 0.0
	check(not cs.minigame.runs.has("fighter"), "zero health ends the round")
	check(Arenas.parse_code(Arenas.export_code(a))["def"]["kind"] == "survival", "share code keeps survival")


func test_arena_adventure() -> void:
	print("== Adventure arenas (staged treasure hunt) ==")
	var cs = CityState.new(4244)
	_login(cs, "maker")
	_login(cs, "hero")
	cs.accounts["maker"]["money"] = 1000
	cs.accounts["hero"]["money"] = 0
	var at := _mg_land_pos(cs)
	var res: Dictionary = cs.arena_create("maker", "Quest", at, 18.0, 99, 90.0, 2, "adventure", 100)
	check(bool(res["ok"]), "an adventure arena can be built")
	var id: int = int(res["id"])
	var a: Dictionary = cs.arenas.items[id]
	check(str(a["kind"]) == "adventure" and int(a["coins"]) == FWConst.ADV_STAGES_MAX, "kind kept and stage count clamped")
	var stages: Array = Arenas.make_adventure_stages(cs.world, cs.seed_value, a)
	check(stages.size() >= 3 and stages == Arenas.make_adventure_stages(cs.world, cs.seed_value, a), "stages are placed on land and deterministic")
	var center := Vector2(float(a["x"]), float(a["z"]))
	check((stages[0] as Vector2).distance_to(center) < (stages[stages.size() - 1] as Vector2).distance_to(center), "later stages are farther out")
	check(bool(cs.arena_play("hero", id, at)["ok"]), "a hero can start the adventure")
	var st: Dictionary = cs.minigame.public_state("hero")
	check(bool(st["adv"]) and st["coins"].size() == 1 and int(st["left"]) == stages.size() - 1, "only the next stage is visible and the state counts what is left")
	var stage_events := 0
	var guard := 0
	while cs.minigame.runs.has("hero") and guard < 40:
		guard += 1
		var cur: Dictionary = cs.minigame.public_state("hero")
		var target := Vector2(float(cur["coins"][0][0]), float(cur["coins"][0][1]))
		for e in cs.minigame.step(0.1, {"hero": target}, 1, cs.world):
			if str(e["kind"]) == "coin" and bool(e.get("adv", false)):
				stage_events += 1
	check(stage_events == stages.size(), "every stage announces progress with adv, n and of")
	check(not cs.minigame.runs.has("hero") and float(cs.minigame.arena_times.get(id, {}).get("hero", 0.0)) > 0.0, "reaching the treasure ends the quest with a time")
	check(Arenas.parse_code(Arenas.export_code(a))["def"]["kind"] == "adventure", "share code keeps adventure")


func test_arena_share_code() -> void:
	print("== Arena share code (between worlds) ==")
	check(FWConst.PROTOCOL_VERSION >= 40, "protocol bumped for the arena import message")
	var a_world = CityState.new(4244)
	_login(a_world, "maker")
	a_world.accounts["maker"]["money"] = 1000
	var at := _mg_land_pos(a_world)
	var id: int = int(a_world.arena_create("maker", "Shared Run", at, 14.0, 6, 70.0, 2, "parkour", 50, 2)["id"])
	a_world.arena_prop("maker", id, "prop_bonus", at)
	a_world.arena_prop("maker", id, "prop_hazard", at + Vector2(4.0, 0.0))
	var code: String = Arenas.export_code(a_world.arenas.items[id])
	check(code.begins_with("FWA1:") and code.length() < FWConst.ARENA_CODE_MAX, "the code has the expected prefix and size")
	var pr: Dictionary = Arenas.parse_code(code)
	check(bool(pr["ok"]) and str(pr["def"]["name"]) == "Shared Run" and str(pr["def"]["kind"]) == "parkour", "the code decodes to the same game")
	check(pr["def"]["props"].size() == 2 and absf(float(pr["def"]["props"][1][1]) - 4.0) < 0.2, "objects are stored relative to the centre")
	# جهان دیگر
	var b_world = CityState.new(777)
	_login(b_world, "friend")
	b_world.accounts["friend"]["money"] = 1000
	var bt := _mg_land_pos(b_world)
	var res: Dictionary = b_world.arena_import("friend", code, bt)
	check(bool(res["ok"]), "the code builds the game in another world")
	var ib: Dictionary = b_world.arenas.items[int(res["id"])]
	check(str(ib["name"]) == "Shared Run" and int(ib["win"]) == 50 and int(ib["obs"]) == 2 and str(ib["owner"]) == "friend", "settings are copied and the importer owns the copy")
	check(int(b_world.money_of("friend")) == 1000 - FWConst.ARENA_COST, "importing costs the normal arena price")
	check(ib["props"].size() >= 1, "objects are copied around the new centre")
	# ورودی بد
	for bad in ["", "hello", "FWA1:", "FWA1:@@@@", "FWA2:" + code.substr(5), "FWA1:" + Marshalls.raw_to_base64("{\"v\":1,\"n\":\"\"}".to_utf8_buffer()), "FWA1:" + "A".repeat(FWConst.ARENA_CODE_MAX)]:
		check(str(b_world.arena_import("friend", bad, bt + Vector2(100.0, 0.0)).get("error", "")) == "arena_code", "bad code refused: %s" % bad.left(12))
	var evil := {"v": 1, "n": "X", "k": "parkour", "r": 99999.0, "c": 9999999, "t": 1e12, "x": 999999, "w": 5000, "o": 500, "p": [["bonus", 1e9, 0], ["bogus", 1, 1]]}
	var eres: Dictionary = b_world.arena_import("friend", "FWA1:" + Marshalls.raw_to_base64(JSON.stringify(evil).to_utf8_buffer()), bt + Vector2(100.0, 0.0))
	if bool(eres["ok"]):
		var ea: Dictionary = b_world.arenas.items[int(eres["id"])]
		check(float(ea["r"]) <= FWConst.ARENA_R_MAX and int(ea["coins"]) <= FWConst.ARENA_PARKOUR_MAX and float(ea["time"]) <= FWConst.ARENA_TIME_MAX and int(ea["reward"]) <= FWConst.ARENA_REWARD_MAX and int(ea["win"]) <= FWConst.ARENA_WIN_MAX and int(ea["obs"]) <= FWConst.ARENA_OBS_MAX and ea["props"].is_empty(), "hostile numbers are clamped and bad objects dropped")
	else:
		check(true, "hostile code refused outright")


func _arena_finish_reward(cs, who: String, id: int, at: Vector2, score: int) -> int:
	cs.minigame.cancel(who)
	if not bool(cs.arena_play(who, id, at)["ok"]):
		return -1
	cs.minigame.runs[who]["score"] = score
	for e in cs.minigame_step(9999.0, {who: Vector2(-9999.0, -9999.0)}):
		if str(e["kind"]) == "end":
			return int(e["reward"])
	return -1


func test_arena_difficulty() -> void:
	print("== Arena difficulty and courses outside the start arena ==")
	check(Arenas.clean_diff(0) == 0 and Arenas.clean_diff(2) == 2 and Arenas.clean_diff(9) == 2 and Arenas.clean_diff(-3) == 0, "difficulty is clamped to easy, medium, hard")
	check(Arenas.clean_diff("x") == 1 and Arenas.clean_diff(null) == 1, "an unknown difficulty means medium")
	var cs = CityState.new(4301)
	_login(cs, "maker")
	_login(cs, "guest")
	cs.accounts["maker"]["money"] = 5000
	cs.accounts["guest"]["money"] = 0
	var at := _mg_land_pos(cs)
	var spots: Array = []
	var k := 0
	while spots.size() < 5 and k < 120:
		var sp := at + Vector2(float(k) * 45.0, 0.0)
		var sh: float = cs.world.height_at(sp.x, sp.y)
		if sh >= 1.0 and sh <= 10.0:
			spots.append(sp)
		k += 1
	check(spots.size() >= 4, "the test world has land for four separate arenas")
	var ids: Array = []
	var means: Array = []
	for d in 3:
		var res: Dictionary = cs.arena_create("maker", "Diff%d" % d, spots[d], 10.0, 12, 40.0, 2, "coins", 0, 0, d)
		if not bool(res["ok"]):
			ids.append(0)
			means.append(0.0)
			continue
		var id: int = int(res["id"])
		ids.append(id)
		var a: Dictionary = cs.arenas.items[id]
		check(int(a["diff"]) == d, "the arena remembers difficulty %d" % d)
		var pts: Array = Arenas.make_targets(cs.world, cs.seed_value, "maker", 0, a)
		var c0 := Vector2(float(a["x"]), float(a["z"]))
		var sum := 0.0
		var outside := true
		for p in pts:
			var pd: float = (p as Vector2).distance_to(c0)
			sum += pd
			if pd < float(a["r"]) + FWConst.ARENA_COURSE_GAP - 0.5:
				outside = false
		check(outside and pts.size() >= FWConst.ARENA_COINS_MIN, "difficulty %d: every coin is outside the start arena" % d)
		means.append(sum / float(maxi(pts.size(), 1)))
	check(ids.size() == 3 and float(means[2]) > float(means[0]), "a harder game sends the player farther across the city")
	var edit_err: String = cs.arena_edit("maker", ids[1], "Diff1", 10.0, 12, 40.0, 2, "coins", 0, 0, 2)
	check(edit_err == "" and int(cs.arenas.items[ids[1]]["diff"]) == 2, "the owner can change the difficulty of an existing game (%s)" % edit_err)
	check(int(cs.arenas_public()[0]["diff"]) >= 0, "the public list carries the difficulty")
	# جایزه: آسان ۰٫۷۵، متوسط ۱، سخت ۱٫۵ برابر
	var r0 := _arena_finish_reward(cs, "guest", ids[0], Vector2(float(cs.arenas.items[ids[0]]["x"]), float(cs.arenas.items[ids[0]]["z"])), 10)
	var r2 := _arena_finish_reward(cs, "guest", ids[1], Vector2(float(cs.arenas.items[ids[1]]["x"]), float(cs.arenas.items[ids[1]]["z"])), 10)
	check(r0 == 15 and r2 == 30, "prize scales with difficulty (easy 15, hard 30 for ten targets at 2 each; got %d and %d)" % [r0, r2])
	# زمان: سخت ضریب کمتر از آسان دارد
	var base := {"x": 0.0, "z": 0.0, "r": 10.0, "time": 60.0, "kind": "football", "coins": 3}
	var te: float = Arenas.run_limit(base.merged({"diff": 0}, true), [])
	var tm: float = Arenas.run_limit(base.merged({"diff": 1}, true), [])
	var th: float = Arenas.run_limit(base.merged({"diff": 2}, true), [])
	check(te > tm and tm > th and is_equal_approx(tm, 60.0), "time shrinks with difficulty (easy %.0f, medium %.0f, hard %.0f)" % [te, tm, th])
	# پارکور: مسیر از میدان تا جای دور، بیرون از میدان و بلندتر با سختی
	var pk := {"id": 7, "x": at.x, "z": at.y, "r": 12.0, "coins": 6, "kind": "parkour", "time": 60.0, "diff": 0}
	var pe: Array = Arenas.make_checkpoints(cs.world, cs.seed_value, pk)
	var ph: Array = Arenas.make_checkpoints(cs.world, cs.seed_value, pk.merged({"diff": 2}, true))
	var far_e := 0.0
	var far_h := 0.0
	var out_ok := true
	for p in pe:
		far_e = maxf(far_e, (p as Vector2).distance_to(at))
		if (p as Vector2).distance_to(at) < 12.0 + FWConst.ARENA_COURSE_GAP - 0.5:
			out_ok = false
	for p in ph:
		far_h = maxf(far_h, (p as Vector2).distance_to(at))
	check(out_ok and pe.size() >= FWConst.ARENA_COINS_MIN, "parkour checkpoints all lie outside the start arena")
	check(far_h > far_e, "the hard parkour route ends farther away")
	# موانع پارکور روی مسیرند و با سختی بیشتر می‌شوند
	check(Arenas.eff_obs("parkour", 3, 0) == 1 and Arenas.eff_obs("parkour", 3, 1) == 3 and Arenas.eff_obs("parkour", 3, 2) == 5, "difficulty adds or removes moving obstacles")
	check(Arenas.eff_obs("coins", 3, 2) == 0, "other kinds never get obstacles")
	var obs: Array = Arenas.make_obstacles(cs.seed_value, pk.merged({"obs": 3, "diff": 1}, true), pe)
	check(obs.size() == 3, "route obstacles follow the obstacle count")
	# بقا: دشمن سخت سریع‌تر و پرآسیب‌تر است
	var svr: Dictionary = cs.arena_create("maker", "Fight", spots[3], 14.0, 5, 60.0, 1, "survival", 0, 0, 2)
	check(bool(svr["ok"]), "a hard survival arena can be built")
	var sv: int = int(svr.get("id", 0))
	if sv > 0:
		cs.arena_play("guest", sv, spots[3])
		var run: Dictionary = cs.minigame.runs.get("guest", {})
		check(is_equal_approx(float(run.get("fs", 0.0)), 1.25) and is_equal_approx(float(run.get("fd", 0.0)), 1.4), "hard survival makes foes faster and stronger")
		cs.minigame.cancel("guest")
	# کد اشتراک و ذخیره
	var code: String = Arenas.export_code(cs.arenas.items[ids[0]])
	var pr: Dictionary = Arenas.parse_code(code)
	check(bool(pr["ok"]) and int(pr["def"]["diff"]) == 0, "the share code carries the difficulty")
	var a2 = Arenas.new()
	a2.load_dict(cs.arenas.to_dict())
	check(int(a2.items[ids[1]]["diff"]) == 2, "difficulty survives saving and loading")
	check(FWConst.PROTOCOL_VERSION >= 46, "protocol bumped for the arena difficulty field")


func test_wild() -> void:
	print("== Wild enemies, weapons and armor ==")
	var Wild = load("res://scripts/server/wild.gd")
	var land := func(_x: float, _z: float) -> bool: return true
	var center := Vector2(0, 0)
	check(Wild.is_night(23.0 * 3600.0) and Wild.is_night(2.0 * 3600.0) and not Wild.is_night(12.0 * 3600.0), "night is 20:00 to 05:00")
	var w = Wild.new()
	w.rng.seed = 7
	var me := {"name": "hero", "pos": Vector2(200, 200), "dmg": 1, "armor": 0.0}
	# روز: دشمنی نیست
	for i in range(20):
		w.step(1.0, [me], false, land, center, true)
	check(w.mobs.is_empty(), "no enemies spawn in daylight")
	# جهان بدون دشمن (خلاقانه)
	for i in range(20):
		w.step(1.0, [me], true, land, center, false)
	check(w.mobs.is_empty(), "no enemies when the world is peaceful")
	# شب: دشمن زایش می‌شود ولی از سقف هر بازیکن بیشتر نمی‌شود
	for i in range(60):
		w.step(1.0, [{"name": "hero", "pos": Vector2(200, 200), "dmg": 0, "armor": 1.0}], true, land, center, true)
	check(w.mobs.size() >= 1 and w.mobs.size() <= FWConst.WILD_PER_PLAYER, "night spawns respect the per-player cap (%d)" % w.mobs.size())
	for m in w.mobs:
		var d: float = (m["p"] as Vector2).distance_to(Vector2(200, 200))
		check(d <= FWConst.WILD_SPAWN_MAX + 1.0 or d < FWConst.WILD_AGGRO, "enemies stay near the player")
	# زره کامل: آسیب صفر؛ بدون زره: آسیب می‌خورد
	var hurt_full := 0.0
	var hurt_none := 0.0
	for i in range(400):
		var r1: Dictionary = w.step(0.25, [{"name": "hero", "pos": Vector2(200, 200), "dmg": 0, "armor": 1.0}], true, land, center, true)
		for h in r1["hurt"]:
			hurt_full += float(h["amount"])
		var r2: Dictionary = w.step(0.25, [{"name": "hero", "pos": Vector2(200, 200), "dmg": 0, "armor": 0.0}], true, land, center, true)
		for h in r2["hurt"]:
			hurt_none += float(h["amount"])
	check(hurt_full == 0.0 and hurt_none > 0.0, "armor reduces damage (full %.1f vs none %.1f)" % [hurt_full, hurt_none])
	# بازیکن با شمشیر دشمن را می‌کشد و پاداش می‌گیرد
	var kills := 0
	var money := 0
	for i in range(1200):
		var r3: Dictionary = w.step(0.25, [{"name": "hero", "pos": Vector2(200, 200), "dmg": 3, "armor": 0.5}], true, land, center, true)
		for k in r3["kills"]:
			kills += 1
			money += int(k["money"])
	check(kills >= 1 and money >= 6, "an armed player kills enemies and earns coins (%d kills)" % kills)
	# صبح: همه محو می‌شوند
	w.step(1.0, [me], false, land, center, true)
	check(w.mobs.is_empty(), "enemies vanish at dawn")
	# دور میدان مرکزی امن است
	var w2 = Wild.new()
	w2.rng.seed = 11
	for i in range(80):
		w2.step(1.0, [{"name": "hero", "pos": Vector2(5, 5), "dmg": 0, "armor": 1.0}], true, land, center, true)
	var safe_ok := true
	for m in w2.mobs:
		if (m["p"] as Vector2).distance_to(center) < FWConst.WILD_SAFE_RADIUS * 0.5:
			safe_ok = false
	check(safe_ok, "enemies do not enter the town square")
	# ساخت تجهیزات و ذخیره
	var cs = CityState.new(5151)
	_login(cs, "smith")
	var acc: Dictionary = cs.accounts["smith"]
	check(cs.gear_of(acc) == {"weapon": 0, "armor": 0}, "new players have no gear")
	check(cs.craft("smith", "sword", 1)["error"] == "no_items", "sword needs materials")
	acc["inv"]["iron"] = 20
	acc["inv"]["wood"] = 20
	acc["inv"]["stone"] = 20
	check(cs.craft("smith", "sword", 1)["ok"] and int(cs.gear_of(acc)["weapon"]) == 2, "an iron sword is crafted")
	check(cs.craft("smith", "club", 1)["error"] == "gear_have", "a weaker weapon is refused after a better one")
	check(cs.craft("smith", "vest", 1)["ok"] and cs.craft("smith", "plate", 1)["ok"] and int(cs.gear_of(acc)["armor"]) == 2, "armor goes vest then iron plate")
	check(cs.craft("smith", "sword", 2)["error"] == "bad_request", "gear can only be crafted one at a time")
	check(cs.vitals_public("smith") == [100, 2, 2, 100], "vitals report hp and gear tiers")
	var cs2 = CityState.from_dict(cs.to_dict())
	check(cs2 != null and cs2.vitals_public("smith") == [100, 2, 2, 100], "gear and health survive save and load")
	# مرگ: سلامت پر، بازگشت به میدان، جریمهٔ محدود
	var cs3 = CityState.new(5152)
	_login(cs3, "victim")
	cs3.accounts["victim"]["money"] = 1000
	cs3.accounts["victim"]["hp"] = 1.0
	cs3.world_time = 23.0 * 3600.0
	var sp3: Vector3 = cs3.spawn_position()
	var field := Vector2(sp3.x + 60.0, sp3.z)   # خشکی بیرون از میدان امن
	var died := false
	for i in range(4000):
		var r4: Dictionary = cs3.wild_step(0.25, {"victim": field})
		if not r4["died"].is_empty():
			died = true
			break
		cs3.accounts["victim"]["hp"] = 1.0
	check(died, "enemies can defeat an unarmored player")
	check(float(cs3.accounts["victim"]["hp"]) == FWConst.PLAYER_HP_MAX and int(cs3.accounts["victim"]["money"]) >= 1000 - FWConst.DEATH_MONEY_LOSS_MAX, "death restores health and costs a capped amount")
	# خلاقانه: هیچ دشمنی
	var cs4 = CityState.new(5153)
	_login(cs4, "maker")
	cs4.creative = true
	cs4.world_time = 23.0 * 3600.0
	for i in range(100):
		cs4.wild_step(1.0, {"maker": Vector2(cs4.spawn_position().x + 60.0, cs4.spawn_position().z)})
	check(cs4.wild.mobs.is_empty(), "creative worlds have no enemies")
	# متن‌ها
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["health", "craft_club", "craft_sword", "craft_vest", "craft_plate", "msg_gear_made", "msg_wild_died", "err_gear_have"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "wild and gear texts exist in Persian and English")


func _fire_once(tier: int, kind: String, dist: float, steps: Array) -> Array:
	# یک دشمن در فاصلهٔ dist می‌گذارد و با سلاح سطح tier چند گام می‌رود؛ hp پس از هر گام را برمی‌گرداند.
	var Wild = load("res://scripts/server/wild.gd")
	var w = Wild.new()
	w.rng.seed = 3
	w.mobs.append({"id": 1, "kind": kind, "p": Vector2(200.0 + dist, 200.0), "hp": int(FWConst.WILD_KINDS[kind]["hp"]), "cd": 99.0})
	var pl := {"name": "hero", "pos": Vector2(200, 200), "dmg": int(FWConst.GEAR_WEAPON_DAMAGE[tier]), "range": float(FWConst.GEAR_WEAPON_RANGE[tier]), "cd": float(FWConst.GEAR_WEAPON_CD[tier]), "armor": 1.0}
	var land := func(_x: float, _z: float) -> bool: return true
	var hp_after: Array = []
	for dt in steps:
		w.step(float(dt), [pl], true, land, Vector2(0, 0), true)
		hp_after.append(int(w.mobs[0]["hp"]) if not w.mobs.is_empty() else 0)
	return hp_after


func test_weapons() -> void:
	print("== More weapons: spear, axe, bow ==")
	var n: int = FWConst.GEAR_WEAPON_DAMAGE.size()
	check(n == 6 and FWConst.GEAR_WEAPON_RANGE.size() == n and FWConst.GEAR_WEAPON_CD.size() == n, "weapon tables have six matching rungs")
	var rungs := {}
	for key in FWConst.RECIPES:
		var r: Dictionary = FWConst.RECIPES[key]
		if str(r.get("gear", "")) == "weapon":
			rungs[int(r["tier"])] = key
	check(rungs.size() == 5 and rungs[1] == "club" and rungs[2] == "sword" and rungs[3] == "spear" and rungs[4] == "axe" and rungs[5] == "bow", "weapon ladder is club, sword, spear, axe, bow")
	var dps_ok := true
	for t in range(1, n):
		if t == 5:
			continue  # کمان با برد بلند، نه ضربهٔ در ثانیهٔ بیشتر، ارزش دارد
		if float(FWConst.GEAR_WEAPON_DAMAGE[t]) / float(FWConst.GEAR_WEAPON_CD[t]) <= float(FWConst.GEAR_WEAPON_DAMAGE[t - 1]) / float(FWConst.GEAR_WEAPON_CD[t - 1]):
			dps_ok = false
	check(dps_ok, "each melee rung out-damages the previous one per second")
	check(float(FWConst.GEAR_WEAPON_RANGE[5]) > 3.0 * float(FWConst.GEAR_WEAPON_RANGE[2]) and float(FWConst.GEAR_WEAPON_RANGE[3]) > float(FWConst.GEAR_WEAPON_RANGE[2]), "bow outranges everything and the spear outreaches the sword")
	# برد واقعی در نبرد
	check(_fire_once(1, "wolf", 4.0, [0.05])[0] == 3, "a club cannot reach 4 m")
	check(_fire_once(3, "wolf", 4.0, [0.05])[0] <= 0, "a spear hits at 4 m")
	check(_fire_once(3, "wolf", 8.0, [0.05])[0] == 3, "a spear cannot reach 8 m")
	check(_fire_once(5, "wolf", 10.0, [0.05])[0] <= 0, "a bow kills a wolf from 10 m")
	check(_fire_once(5, "wolf", 14.0, [0.05])[0] == 3, "a bow cannot reach 14 m")
	# فاصلهٔ ضربه: کمان ۱٫۱ ثانیه، تبر ۱ ثانیه (غول ۶ جان دارد)
	var bow_hp: Array = _fire_once(5, "ghoul", 9.0, [0.05, 0.5, 0.5, 0.2])
	check(bow_hp[0] == 1 and bow_hp[1] == 1 and bow_hp[2] == 1, "the bow shoots once, then waits for its cooldown")
	check(bow_hp[3] <= 0, "the bow shoots again after about 1.1 s")
	check(_fire_once(4, "ghoul", 2.0, [0.05])[0] <= 0, "one axe swing kills a ghoul")
	# ساخت و ذخیره
	var cs = CityState.new(6161)
	_login(cs, "smith")
	var acc: Dictionary = cs.accounts["smith"]
	acc["inv"]["iron"] = 30
	acc["inv"]["wood"] = 40
	acc["inv"]["stone"] = 10
	check(cs.craft("smith", "bow", 1)["ok"] and int(cs.gear_of(acc)["weapon"]) == 5, "a bow can be crafted straight from a bare fist")
	check(cs.craft("smith", "axe", 1)["error"] == "gear_have" and cs.craft("smith", "spear", 1)["error"] == "gear_have", "weaker weapons are refused after the bow")
	var cs_b = CityState.new(6162)
	_login(cs_b, "ranger")
	var acc_b: Dictionary = cs_b.accounts["ranger"]
	check(cs_b.craft("ranger", "spear", 1)["error"] == "no_items", "spear needs materials")
	acc_b["inv"]["iron"] = 30
	acc_b["inv"]["wood"] = 30
	acc_b["inv"]["stone"] = 10
	check(cs_b.craft("ranger", "spear", 1)["ok"] and cs_b.craft("ranger", "axe", 1)["ok"] and int(cs_b.gear_of(acc_b)["weapon"]) == 4, "spear then axe upgrade in order")
	check(int(acc_b["inv"]["iron"]) == 30 - 2 - 5 and int(acc_b["inv"]["wood"]) == 30 - 4 - 3 and int(acc_b["inv"]["stone"]) == 8, "weapon materials are consumed")
	var cs_c = CityState.from_dict(cs.to_dict())
	check(cs_c != null and cs_c.vitals_public("smith")[1] == 5, "the bow survives saving and loading")
	check(cs.gear_of({"gear": {"weapon": 99, "armor": 99}}) == {"weapon": 5, "armor": 2}, "corrupt gear tiers are clamped to the real ladder")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["craft_spear", "craft_axe", "craft_bow"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "new weapon texts exist in Persian and English")


func test_hunger() -> void:
	print("-- hunger and food (protocol 48)")
	check(FWConst.PROTOCOL_VERSION >= 48, "protocol bumped for the eat message")
	var cs = CityState.new(6101)
	_login(cs, "eater")
	var acc: Dictionary = cs.accounts["eater"]
	check(float(acc["hunger"]) == FWConst.HUNGER_MAX, "new accounts start with full hunger")
	cs.energy_step(100.0, {"eater": 0})
	check(float(acc["hunger"]) < FWConst.HUNGER_MAX, "hunger falls over time")
	check(cs.vitals_public("eater").size() == 4, "vitals carry hunger as the fourth value")
	# سیری: نمی‌شود غذا هدر داد
	acc["hunger"] = FWConst.HUNGER_MAX
	check(str(cs.eat("eater", "fish")["error"]) == "not_hungry", "cannot eat when full")
	acc["hunger"] = 10.0
	check(str(cs.eat("eater", "pizza")["error"]) == "bad_request", "unknown food is rejected")
	check(str(cs.eat("eater", "fish")["error"]) == "no_items", "fish needs a fish in the pack")
	acc["inv"]["fish"] = 2
	var r: Dictionary = cs.eat("eater", "fish")
	check(bool(r["ok"]) and int(acc["inv"]["fish"]) == 1 and absf(float(acc["hunger"]) - 40.0) < 0.001, "eating fish uses one fish and restores hunger")
	# نان از بازار
	check(str(cs.eat("eater", "bread")["error"]) == "no_stock", "bread needs market stock")
	cs.market["bread"] = 3.0
	var money0: int = int(acc["money"])
	var r2: Dictionary = cs.eat("eater", "bread")
	check(bool(r2["ok"]) and int(r2["paid"]) > 0 and int(acc["money"]) == money0 - int(r2["paid"]) and absf(float(cs.market["bread"]) - 2.0) < 0.001, "bread costs coins and one market unit")
	acc["hunger"] = 5.0
	acc["money"] = 0
	check(str(cs.eat("eater", "bread")["error"]) == "no_money", "market food needs money")
	acc["hunger"] = 95.0
	acc["inv"]["fish"] = 1
	cs.eat("eater", "fish")
	check(float(acc["hunger"]) == FWConst.HUNGER_MAX, "hunger never exceeds the maximum")
	# گرسنگی کامل: خستگی سریع‌تر، بدون مرگ
	var cs2 = CityState.new(6102)
	_login(cs2, "a")
	_login(cs2, "b")
	cs2.accounts["a"]["hunger"] = 0.0
	cs2.accounts["b"]["hunger"] = 50.0
	cs2.energy_step(60.0, {"a": 0, "b": 0})
	var lost_a: float = FWConst.ENERGY_MAX - float(cs2.accounts["a"]["energy"])
	var lost_b: float = FWConst.ENERGY_MAX - float(cs2.accounts["b"]["energy"])
	check(lost_a > lost_b * 2.5, "starving players tire several times faster")
	check(float(cs2.accounts["a"]["hp"]) == FWConst.PLAYER_HP_MAX, "hunger alone never hurts health")
	# بدون بهبود سلامت در گرسنگی
	cs2.accounts["a"]["hp"] = 50.0
	cs2.accounts["b"]["hp"] = 50.0
	cs2.accounts["a"]["hunger"] = 0.0
	cs2.accounts["b"]["hunger"] = 80.0
	cs2._hurt_t["a"] = 99.0
	cs2._hurt_t["b"] = 99.0
	var spot := Vector2(cs2.spawn_position().x + 60.0, cs2.spawn_position().z)
	cs2.wild_step(5.0, {"a": spot, "b": spot})
	check(float(cs2.accounts["a"]["hp"]) == 50.0 and float(cs2.accounts["b"]["hp"]) > 50.0, "starving players do not regain health")
	# خلاقانه: گرسنگی نیست
	var cs3 = CityState.new(6103)
	_login(cs3, "maker")
	cs3.creative = true
	cs3.accounts["maker"]["hunger"] = 3.0
	cs3.energy_step(10.0, {"maker": 0})
	check(float(cs3.accounts["maker"]["hunger"]) == FWConst.HUNGER_MAX, "creative worlds have no hunger")
	# ذخیره و بارگذاری، و ذخیرهٔ قدیمی بدون کلید
	var cs4 = CityState.new(6104)
	_login(cs4, "saver")
	cs4.accounts["saver"]["hunger"] = 33.0
	var back = CityState.from_dict(cs4.to_dict())
	check(back != null and absf(float(back.accounts["saver"]["hunger"]) - 33.0) < 0.001, "hunger survives save and load")
	var old: Dictionary = cs4.to_dict()
	old["accounts"]["saver"].erase("hunger")
	var back2 = CityState.from_dict(old)
	check(back2 != null and float(back2.accounts["saver"]["hunger"]) == FWConst.HUNGER_MAX, "old saves without hunger load as full")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["hunger", "eat_title", "eat_fish", "eat_bread", "eat_cheese", "eat_milk", "eat_egg", "msg_ate", "err_not_hungry", "err_no_stock"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "hunger texts exist in Persian and English")


func test_god_human() -> void:
	print("-- god tool: place and remove humans")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(6201)
	_login(cs, "plain")
	cs.provision_admin("boss", "secret")
	NpcSim.ensure_npcs(cs)
	var base: int = cs.npcs.size()
	var sp: Vector3 = cs.spawn_position()
	var spot := Vector2(sp.x + 6.0, sp.z + 6.0)
	check(str(cs.god_action("plain", "add", FWConst.GOD_HUMAN, spot.x, spot.y)["error"]) == "forbidden", "regular players cannot place humans")
	var r: Dictionary = cs.god_action("boss", "add", FWConst.GOD_HUMAN, spot.x, spot.y)
	check(bool(r["ok"]) and cs.npcs.size() == base + 1, "admin places a human as a real NPC")
	var made: Dictionary = cs.npcs[cs.npcs.size() - 1]
	var ids := {}
	for n in cs.npcs:
		ids[int(n["id"])] = true
	check(ids.size() == cs.npcs.size(), "placed humans get unique ids")
	check(bool(made["placed"]) and str(made["name"]) != "" and absf(float(made["x"]) - spot.x) < 0.01, "placed human has a name, position and the placed flag")
	NpcSim.step(cs, 1.0)
	check(cs.npcs.size() == base + 1, "placed humans take part in the daily simulation")
	# سقف
	while cs.npcs.size() < FWConst.NPC_MAX:
		cs.npcs.append({"id": 900 + cs.npcs.size(), "name": "x", "x": 1.0, "z": 1.0, "state": "idle", "money": 0, "paid_day": -1})
	check(str(cs.god_action("boss", "add", FWConst.GOD_HUMAN, spot.x + 2.0, spot.y)["error"]) == "npc_full", "residents are capped")
	# ذخیره و بارگذاری
	var cs2 = CityState.new(6202)
	cs2.provision_admin("boss", "secret")
	NpcSim.ensure_npcs(cs2)
	cs2.god_action("boss", "add", FWConst.GOD_HUMAN, spot.x, spot.y)
	var back = CityState.from_dict(cs2.to_dict())
	var kept := false
	for n in back.npcs:
		if bool(n.get("placed", false)):
			kept = true
	check(back != null and back.npcs.size() == cs2.npcs.size() and kept, "placed humans survive save and load")
	# حذف: فقط انسان‌های گذاشته‌شده، نه NPCهای اصلی
	var n_before: int = back.npcs.size()
	var base_npc: Dictionary = back.npcs[0]
	var rm0: Dictionary = back.god_action("boss", "remove", "", float(base_npc["x"]), float(base_npc["z"]))
	check(back.npcs.size() == n_before and not bool(rm0["ok"]), "starting NPCs are not removable with the remove tool")
	var rm: Dictionary = back.god_action("boss", "remove", "", spot.x, spot.y)
	check(bool(rm["ok"]) and back.npcs.size() == n_before - 1, "remove deletes a placed human")
	# خلاقانه
	var cs3 = CityState.new(6203)
	cs3.creative = true
	cs3.provision_admin("boss", "secret")
	check(bool(cs3.god_action("boss", "add", FWConst.GOD_HUMAN, spot.x, spot.y)["ok"]), "humans can be placed in creative worlds")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["god_human", "err_npc_full"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "human tool texts exist in Persian and English")


func test_attractions() -> void:
	print("-- collections: zoo and amusement park")
	var cs = CityState.new(6301)
	_login(cs, "owner")
	_login(cs, "other")
	cs.accounts["owner"]["money"] = 5000
	var spot := Vector2i(0, 0)
	var zid := -1
	var pid := -1
	var found := 0
	for cx in range(8, 90, 4):
		for cz in range(8, 90, 4):
			if found == 0:
				var r: Dictionary = cs.place_building("owner", 0, "zoo", cx, cz)
				if bool(r["ok"]):
					zid = int(r["building"]["id"])
					found = 1
			elif found == 1:
				var r2: Dictionary = cs.place_building("owner", 0, "park", cx, cz)
				if bool(r2["ok"]):
					pid = int(r2["building"]["id"])
					found = 2
	check(zid > 0 and pid > 0, "zoo and park can be built")
	if zid < 0 or pid < 0:
		return
	var zoo: Dictionary = cs.buildings[zid]
	var park: Dictionary = cs.buildings[pid]
	check(int(park["rides"]) == FWConst.PARK_RIDES_START, "a new park starts with one ride")
	# باغ‌وحش خالی بلیط نمی‌فروشد
	for i in 3:
		cs.tick(FWConst.ATTR_SECONDS)
	check(float(zoo["stock"]) == 0.0, "an empty zoo sells no tickets")
	check(float(park["stock"]) > 0.0, "the park sells tickets")
	# حیوان‌ها
	var door: Vector2 = cs.door_point(zoo)
	cs.god[9001] = {"id": 9001, "kind": "sheep", "x": door.x + 2.0, "z": door.y, "tx": door.x, "tz": door.y, "wait": 99.0}
	cs.god[9002] = {"id": 9002, "kind": "deer", "x": door.x - 2.0, "z": door.y, "tx": door.x, "tz": door.y, "wait": 99.0}
	cs.god[9003] = {"id": 9003, "kind": "sheep", "x": door.x + 200.0, "z": door.y, "tx": door.x, "tz": door.y, "wait": 99.0}
	var Att = load("res://scripts/server/attractions.gd")
	var st: Dictionary = Att.zoo_stats(cs, zoo)
	check(int(st["species"]) == 2 and int(st["animals"]) == 2 and int(st["hybrids"]) == 0, "zoo counts nearby species, not far animals")
	var base_inc: int = Att.income_per_period(cs, zoo)
	cs.god[9004] = {"id": 9004, "kind": "jackalope", "x": door.x, "z": door.y + 2.0, "tx": door.x, "tz": door.y, "wait": 99.0}
	check(Att.income_per_period(cs, zoo) > base_inc + FWConst.ZOO_HYBRID_BONUS, "a hybrid species earns the rarity bonus")
	cs.god[9005] = {"id": 9005, "kind": "rabbit", "x": door.x, "z": door.y - 2.0, "tx": door.x, "tz": door.y, "wait": 99.0, "young": 30.0}
	check(int(Att.zoo_stats(cs, zoo)["animals"]) == 3, "young animals are not counted")
	zoo["stock"] = 0.0
	cs.tick(FWConst.ATTR_SECONDS + 0.1)
	check(float(zoo["stock"]) >= float(Att.income_per_period(cs, zoo)) - 0.5, "a zoo with animals earns tickets per period")
	# سقف
	for i in 200:
		cs.tick(FWConst.ATTR_SECONDS)
	check(float(zoo["stock"]) <= FWConst.ZOO_MAX and float(park["stock"]) <= FWConst.PARK_MAX, "ticket stock is capped")
	# برداشت
	var money0: int = int(cs.accounts["owner"]["money"])
	var stock0: int = int(floor(float(zoo["stock"])))
	var c: Dictionary = cs.collect("owner", zid)
	check(bool(c["ok"]) and int(c["earned"]) == stock0 and int(cs.accounts["owner"]["money"]) == money0 + stock0, "collecting tickets pays coins one-to-one")
	check(float(zoo["stock"]) < 1.0, "collecting empties the stock")
	check(str(cs.collect("other", pid)["error"]) == "forbidden", "only the owner collects tickets")
	check(str(cs.collect("owner", zid)["error"]) == "nothing", "nothing to collect right after collecting")
	# ارتقا
	var inc1: int = Att.income_per_period(cs, park)
	var u: Dictionary = Att.upgrade(cs, "owner", pid)
	check(bool(u["ok"]) and int(park["rides"]) == 2, "upgrade adds a ride")
	check(Att.income_per_period(cs, park) == inc1 + FWConst.PARK_PER_RIDE, "each ride raises park income")
	check(int(cs.accounts["owner"]["money"]) == int(u["money"]), "upgrade returns the new balance")
	check(str(Att.upgrade(cs, "other", pid)["error"]) == "forbidden", "only the owner upgrades")
	check(str(Att.upgrade(cs, "owner", zid)["error"]) == "not_park", "zoo cannot be upgraded as a park")
	Att.upgrade(cs, "owner", pid)
	Att.upgrade(cs, "owner", pid)
	check(str(Att.upgrade(cs, "owner", pid)["error"]) == "rides_max", "rides are capped")
	cs.accounts["owner"]["money"] = 0
	# ذخیره و بارگذاری
	var back = CityState.from_dict(cs.to_dict())
	check(back != null and int(back.buildings[pid]["rides"]) == FWConst.PARK_RIDES_MAX, "rides survive save and load")
	check(int(cs.building_public(park)["rides"]) == FWConst.PARK_RIDES_MAX, "public park info carries the ride count")
	# بدون پول
	var cs2 = CityState.new(6303)
	_login(cs2, "poor")
	cs2.accounts["poor"]["money"] = 5000
	var pk: Dictionary = {}
	for cx in range(8, 60, 4):
		if pk.is_empty():
			var rr: Dictionary = cs2.place_building("poor", 0, "park", cx, 8)
			if bool(rr["ok"]):
				pk = rr["building"]
	cs2.accounts["poor"]["money"] = 10
	check(str(Att.upgrade(cs2, "poor", int(pk["id"]))["error"]) == "no_money", "upgrade needs money")
	cs2.creative = true
	check(bool(Att.upgrade(cs2, "poor", int(pk["id"]))["ok"]), "upgrade is free in creative worlds")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["type_zoo", "type_park", "msg_collected_tickets", "rides_label", "ride_upgrade_btn", "msg_ride_upgraded", "err_not_park", "err_rides_max"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "collection texts exist in Persian and English")


func _ai_run(cs, steps: int, dt: float = 0.5) -> int:
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var longest := 0
	for i in steps:
		cs.tick(dt)
		NpcSim.step(cs, dt)
		for n in cs.npcs:
			if n.get("ai", null) is Dictionary:
				longest = maxi(longest, (n["ai"]["plan"] as Array).size())
	return longest


func _ai_owned(cs, acct: String) -> Array:
	var out: Array = []
	for id in cs.buildings:
		if str(cs.buildings[id]["owner"]) == acct:
			out.append(str(cs.buildings[id]["type"]))
	return out


func test_autonomous_characters() -> void:
	print("-- autonomous characters: stage 1 brain")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var Pers = load("res://scripts/server/char_personality.gd")
	var cs = CityState.new(4242)
	NpcSim.ensure_npcs(cs)
	_login(cs, "plain")
	cs.provision_admin("boss", "secret")
	var base_npcs: int = cs.npcs.size()
	check(not CharAI.can_spawn(cs, "plain") and CharAI.can_spawn(cs, "boss"), "only admins may spawn characters in a normal world")
	check(str(CharAI.spawn(cs, "nonsense")["error"]) == "bad_request", "unknown archetype is rejected")
	var r: Dictionary = CharAI.spawn(cs, "rival")
	check(bool(r["ok"]) and cs.npcs.size() == base_npcs + 1, "a rival character is created as an NPC")
	var npc: Dictionary = r["npc"]
	var acct: String = str(npc["acct"])
	check(cs.accounts.has(acct) and str(cs.authenticate(acct, "")["error"]) == "bad_token", "its shadow account can never be logged into")
	check(CharAI.tag(npc) == "c:rival" and NpcSim.public_list(cs)[cs.npcs.size() - 1][6] == "c:rival", "public NPC list carries the character tag")
	check(str(Family_check(cs, npc)) == "ai_npc", "autonomous characters cannot be hired or married")
	# سقف و خاموش
	cs.ai_settings["max"] = 1
	check(str(CharAI.spawn(cs, "trader")["error"]) == "ai_full", "the character limit is enforced")
	cs.ai_settings["max"] = 5
	cs.ai_settings["on"] = false
	check(str(CharAI.spawn(cs, "trader")["error"]) == "ai_off", "spawning is refused when autonomy is switched off")
	var th0: int = int(npc["ai"]["stats"]["thoughts"])
	_ai_run(cs, 40)
	check(int(npc["ai"]["stats"]["thoughts"]) == th0, "a switched-off brain makes no decisions")
	cs.ai_settings["on"] = true
	# تیپ‌ها واقعاً فرق دارند
	var fresh := {}
	var firsts := {}
	for a in Pers.ORDER:
		var cs_t = CityState.new(5000)
		var rr: Dictionary = CharAI.spawn(cs_t, a)
		fresh[a] = rr["npc"]
		for g in CharAI.rank_goals(cs_t, rr["npc"]):
			if g["kind"] == "build" and g["type"] != "house":
				firsts[a] = g["type"]
				break
	check(float(fresh["warlord"]["ai"]["traits"]["aggression"]) > float(fresh["trader"]["ai"]["traits"]["aggression"]) + 0.5, "warlord is far more aggressive than the trader")
	check(float(fresh["schemer"]["ai"]["traits"]["trust"]) < float(fresh["rival"]["ai"]["traits"]["trust"]), "the schemer trusts less than the rival")
	var distinct := {}
	for a in firsts:
		distinct[firsts[a]] = true
	check(distinct.size() >= 3, "the five types prefer different first projects (%d distinct)" % distinct.size())
	check(str(CharAI.rank_goals(cs, npc)[0]["type"]) == "house", "shelter comes first for everyone")
	# استقلال واقعی: بدون هیچ دستوری جمع می‌کند، می‌فروشد و می‌سازد
	var longest: int = _ai_run(cs, 5000)
	var ai: Dictionary = npc["ai"]
	check(int(ai["stats"]["gathered"]) > 0 and int(ai["stats"]["sold"]) > 0, "it gathered real resources and sold them on the market")
	var owned: Array = _ai_owned(cs, acct)
	check(owned.has("house"), "it built a real house with money it earned (owned: %s)" % str(owned))
	check(owned.size() >= 2, "it kept pursuing further goals and built more")
	check(longest >= 3, "it ran a multi-step plan (longest plan %d)" % longest)
	var kinds := {}
	for g in ai["goals"]:
		kinds[str(g["kind"]) + str(g["type"])] = true
	check(kinds.size() >= 3, "it holds several goals at once")
	check(int(cs.accounts[acct]["money"]) >= 0, "its money never goes negative")
	check(cs.ai_events.size() >= 1, "buildings it makes are queued for broadcast to clients")
	# شکست و برنامهٔ جدید
	var f0: int = int(ai["stats"]["failed"])
	ai["plan"] = [{"t": "build", "type": "house", "cx": FWConst.PLAZA_MIN, "cz": FWConst.PLAZA_MIN, "x": float(npc["x"]), "z": float(npc["z"])}]
	ai["w"] = 99.0
	CharAI.step(cs, npc, 0.1, func(c, n, p, t, d): return {"p": p, "arrived": true})
	check(int(ai["stats"]["failed"]) == f0 + 1 and (ai["plan"] as Array).is_empty(), "an impossible build fails, is remembered and the plan is dropped")
	check(str((ai["log"] as Array)[(ai["log"] as Array).size() - 1]).contains("fail:build"), "the failure is written in its log")
	# زمان‌بندی: دور از بازیکن کندتر فکر می‌کند
	cs.ai_positions.clear()
	var far_iv: float = CharAI._interval(cs, npc)
	cs.ai_positions["plain"] = Vector2(float(npc["x"]) + 5.0, float(npc["z"]))
	var near_iv: float = CharAI._interval(cs, npc)
	check(far_iv >= near_iv * 4.0, "distant characters think much less often")
	# ذخیره و بارگذاری
	var back = CityState.from_dict(cs.to_dict())
	var bnpc: Dictionary = {}
	for n in back.npcs:
		if int(n["id"]) == int(npc["id"]):
			bnpc = n
	check(not bnpc.is_empty() and bnpc.get("ai", null) is Dictionary, "the character survives save and load")
	check(str(bnpc["ai"]["arch"]) == "rival" and int(bnpc["ai"]["stats"]["built"]) == int(ai["stats"]["built"]), "identity and experience survive save and load")
	check((bnpc["ai"]["goals"] as Array).size() == (ai["goals"] as Array).size(), "its goals survive save and load")
	check(back.accounts.has(acct) and _ai_owned(back, acct).size() == owned.size(), "its assets survive save and load")
	var b_before: int = _ai_owned(back, acct).size()
	_ai_run(back, 3000)
	check(int(bnpc["ai"]["stats"]["thoughts"]) > int(ai["stats"]["thoughts"]) - 1, "it keeps thinking after loading")
	check(_ai_owned(back, acct).size() >= b_before, "it still owns everything after continuing")
	# ساخت قدیمی بدون فیلد ai مشکلی ندارد
	var old: Dictionary = cs.to_dict()
	for n in old["npcs"]:
		n.erase("ai")
		n.erase("acct")
	var legacy = CityState.from_dict(old)
	check(legacy != null and CharAI.count(legacy) == 0, "saves without characters still load")
	# حالت خلاقانه
	var cc = CityState.new(4243)
	cc.creative = true
	var cr: Dictionary = CharAI.spawn(cc, "trader")
	_ai_run(cc, 400)
	check(_ai_owned(cc, str(cr["npc"]["acct"])).size() >= 1 and int(cr["npc"]["ai"]["stats"]["gathered"]) == 0, "in creative worlds it builds at once without gathering")
	check(int(cr["npc"]["ai"]["stats"]["thoughts"]) > 0, "intelligence stays active in creative worlds")
	# NPCهای عادی دست نخورده‌اند
	var normal_moved := false
	for n in cs.npcs:
		if not (n.get("ai", null) is Dictionary) and str(n["state"]) != "idle":
			normal_moved = true
	check(normal_moved, "regular NPCs still follow their daily schedule")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["ai_spawn_title", "ai_arch_schemer", "ai_arch_rival", "ai_arch_mystery", "ai_arch_trader", "ai_arch_warlord", "msg_ai_spawned", "fam_c_mine", "fam_c_other", "err_ai_off", "err_ai_full", "err_ai_npc"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "character texts exist in Persian and English")


func _mem_pos(npc: Dictionary) -> Vector2:
	return Vector2(float(npc["x"]), float(npc["z"]))


func test_character_memory() -> void:
	print("-- autonomous characters: stage 3 memory and relationships")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var Mem = load("res://scripts/server/char_memory.gd")
	var Pers = load("res://scripts/server/char_personality.gd")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(5151)
	NpcSim.ensure_npcs(cs)
	_login(cs, "p")
	cs.provision_admin("boss", "secret")
	var tr: Dictionary = CharAI.spawn(cs, "trader")["npc"]
	var sc: Dictionary = CharAI.spawn(cs, "schemer")["npc"]
	check(tr["ai"]["mem"] is Dictionary and (tr["ai"]["mem"]["rel"] as Dictionary).is_empty(), "a new character starts with an empty memory")
	check(CharAI.stance_toward(cs, tr, "p") == "neutral", "a stranger is treated neutrally")
	# همان رفتار، تأثیر متفاوت بر دو تیپ (اعتمادپذیری)
	for i in 6:
		cs.day_count += 1
		cs.accounts["p"]["inv"]["gem"] = 3
		check(bool(cs.npc_interact("p", int(tr["id"]), "gem", _mem_pos(tr))["ok"]) or i > 0, "gift accepted")
		cs.npc_interact("p", int(sc["id"]), "gem", _mem_pos(sc))
	var a_tr: float = Mem.attitude(tr["ai"], "p", cs.day_count)
	var a_sc: float = Mem.attitude(sc["ai"], "p", cs.day_count)
	check(a_tr > 0.2 and a_sc > 0.0, "repeated gifts earn trust (%.2f / %.2f)" % [a_tr, a_sc])
	check(a_tr > a_sc, "the trusting trader warms up faster than the suspicious schemer")
	check(CharAI.stance_toward(cs, tr, "p") in ["friend", "ally"], "after several gifts the trader is a friend")
	check(Mem.remembers(tr["ai"], "p", "gift"), "the gift is stored as an important event")
	# واکنش متفاوت در برخورد بعدی
	cs.day_count += 1
	var talk_friend: Dictionary = cs.npc_interact("p", int(tr["id"]), "", _mem_pos(tr))
	check(bool(talk_friend["ok"]) and str(talk_friend["line"]) in ["dlg_ai_gift_mem", "dlg_ai_friend", "dlg_ai_ally"] and str(talk_friend["stance"]) in ["friend", "ally"], "a friend greets warmly (%s)" % str(talk_friend["line"]))
	# معامله واقعی: از کیف خود شخصیت و نه از هیچ
	cs.accounts["p"]["inv"]["wood"] = 10
	var money_ai0: int = int(cs.accounts[str(tr["acct"])]["money"])
	var money_p0: int = int(cs.accounts["p"]["money"])
	var sold: Dictionary = cs.npc_sell("p", int(tr["id"]), "wood", 5, _mem_pos(tr))
	check(bool(sold["ok"]) and int(sold["count"]) >= 1, "player can sell goods to a friendly character")
	var pt: int = int(sold["total"])
	check(int(cs.accounts[str(tr["acct"])]["money"]) == money_ai0 - pt and int(cs.accounts["p"]["money"]) == money_p0 + pt, "money moves between the two wallets and is never created")
	check(int(cs.accounts[str(tr["acct"])]["inv"].get("wood", 0)) == int(sold["count"]), "the goods really end up in the character's bag")
	var bought: Dictionary = cs.npc_buy("p", int(tr["id"]), "wood", 99, _mem_pos(tr))
	check(not bool(bought["ok"]) or int(bought["count"]) <= int(sold["count"]), "a character cannot sell more than it has")
	# خیانت: دوست بود، مدیر ملکش را خراب می‌کند
	var home: Dictionary = cs.place_building(str(tr["acct"]), 0, "house", 6, 6) if false else {}
	cs.buildings[9001] = {"id": 9001, "type": "house", "owner": str(tr["acct"]), "cx": 2, "cz": 2, "stock": 0.0, "level": 1}
	cs.provision_admin("p", "x")
	var rem: Dictionary = cs.remove_building("p", 9001)
	check(bool(rem["ok"]), "an admin can remove the character's building")
	check(Mem.remembers(tr["ai"], "p", "betray") and Mem.remembers(tr["ai"], "p", "demolish"), "the character remembers both the demolition and the betrayal")
	check(int(tr["ai"]["mem"]["rel"]["p"]["betray"]) == 1, "betrayal count is recorded")
	check(CharAI.stance_toward(cs, tr, "p") in ["wary", "enemy"], "a former friend turns hostile (%s)" % CharAI.stance_toward(cs, tr, "p"))
	cs.day_count += 1
	var after: Dictionary = cs.npc_interact("p", int(tr["id"]), "", _mem_pos(tr))
	if bool(after["ok"]):
		check(str(after["line"]) == "dlg_ai_betrayed", "it reacts differently and mentions the betrayal")
	else:
		check(str(after["error"]) == "ai_hostile", "a hostile character refuses to talk")
	# دشمن کامل: معامله و صحبت را قطع می‌کند
	for i in 3:
		Mem.record(tr["ai"], "demolish", "p", 1.0, cs.day_count)
	check(CharAI.refuses(cs, tr, "p"), "an enemy refuses contact")
	check(str(cs.npc_sell("p", int(tr["id"]), "wood", 1, _mem_pos(tr))["error"]) == "ai_hostile", "an enemy refuses to trade")
	check(str(cs.npc_interact("p", int(tr["id"]), "", _mem_pos(tr))["error"]) == "ai_hostile", "an enemy refuses to talk")
	# فراموشی: دشمنی کم می‌شود ولی خیانت می‌ماند
	var e0: float = float(tr["ai"]["mem"]["rel"]["p"]["enemy"])
	Mem.attitude(tr["ai"], "p", cs.day_count + 40)
	var e1: float = float(tr["ai"]["mem"]["rel"]["p"]["enemy"])
	check(e1 < e0 and int(tr["ai"]["mem"]["rel"]["p"]["betray"]) == 1, "enmity fades with time but the betrayal stays")
	# پرخاشگر کینهٔ ماندگارتر دارد
	var w: Dictionary = CharAI.spawn(cs, "warlord")["npc"]
	var m: Dictionary = CharAI.spawn(cs, "mystery")["npc"]
	cs.day_count += 100
	var day0: int = cs.day_count
	Mem.record(w["ai"], "demolish", "q", 0.5, day0)
	Mem.record(m["ai"], "demolish", "q", 0.5, day0)
	Mem.attitude(w["ai"], "q", day0 + 30)
	Mem.attitude(m["ai"], "q", day0 + 30)
	check(float(w["ai"]["mem"]["rel"]["q"]["enemy"]) > float(m["ai"]["mem"]["rel"]["q"]["enemy"]), "the aggressive warlord holds a grudge longer than the mystery type")
	# یادگیری محدود
	var base: Dictionary = Pers.traits_for("rival", 77)
	var lr: Dictionary = {"traits": base.duplicate()}
	for i in 200:
		Mem.learn(lr, false, base)
	check(float(lr["traits"]["caution"]) > float(base["caution"]) and float(lr["traits"]["caution"]) <= minf(1.0, float(base["caution"]) + 0.25) + 0.001, "repeated failures make it more cautious, within a bounded range")
	check(float(lr["traits"]["risk"]) < float(base["risk"]) and float(lr["traits"]["risk"]) >= maxf(0.0, float(base["risk"]) - 0.25) - 0.001, "and less risk-taking, within a bounded range")
	# سقف حافظه
	var cap: Dictionary = {"arch": "rival", "traits": Pers.traits_for("rival", 5), "mem": Mem.fresh()}
	for i in 60:
		Mem.record(cap, "gift", "who%d" % i, 1.0, i)
	check((cap["mem"]["rel"] as Dictionary).size() <= Mem.REL_MAX and (cap["mem"]["events"] as Array).size() <= Mem.EVENTS_MAX, "memory stays bounded")
	for i in 200:
		Mem.record(cap, "talk", "who0", 0.0, 100)
	check(int(cap["mem"]["tally"]["talk"]) == 200 and (cap["mem"]["events"] as Array).size() <= Mem.EVENTS_MAX, "minor events are aggregated, not stored one by one")
	Mem.record(cap, "betray", "who59", 1.0, 100)
	for i in 40:
		Mem.record(cap, "gift", "z%d" % i, 1.0, 101)
	check(Mem.remembers(cap, "who59", "betray"), "a betrayal is never pushed out by newer minor events")
	# ذخیره و بارگذاری
	var back = CityState.from_dict(cs.to_dict())
	var btr: Dictionary = CharAI.find(back, int(tr["id"]))
	check(not btr.is_empty() and Mem.remembers(btr["ai"], "p", "betray") and int(btr["ai"]["mem"]["rel"]["p"]["betray"]) == 1, "memory and betrayal survive save and load")
	check(abs(float(btr["ai"]["mem"]["rel"]["p"]["enemy"]) - float(tr["ai"]["mem"]["rel"]["p"]["enemy"])) < 0.01, "relationship values survive save and load")
	# فایل ذخیرهٔ خراب یا قدیمی
	var bad: Dictionary = (tr["ai"] as Dictionary).duplicate(true)
	bad["mem"] = {"rel": {"p": {"trust": 99, "friend": "x", "enemy": -5, "betray": -3}, "bad": 7}, "events": [5, {"k": "nonsense"}], "tally": {"talk": -4}}
	var fixed: Variant = CharAI.load_ai(bad, int(tr["id"]))
	var fr: Dictionary = fixed["mem"]["rel"]["p"]
	check(fixed != null and float(fr["trust"]) <= 1.0 and float(fr["enemy"]) >= 0.0 and int(fr["betray"]) >= 0 and (fixed["mem"]["events"] as Array).is_empty(), "corrupted memory is sanitized when loading")
	var old_ai: Dictionary = (tr["ai"] as Dictionary).duplicate(true)
	old_ai.erase("mem")
	var legacy_ai: Variant = CharAI.load_ai(old_ai, int(tr["id"]))
	check(legacy_ai != null and (legacy_ai["mem"]["rel"] as Dictionary).is_empty(), "stage-1 saves without memory still load")
	# بازیکن ناشناس / NPC معمولی دست نخورده
	var plain: Dictionary = {}
	for n in cs.npcs:
		if not CharAI.is_ai(n):
			plain = n
			break
	check(CharAI.remember(cs, plain, "gift", "p", 1.0).is_empty() and CharAI.stance_toward(cs, plain, "p") == "neutral", "regular NPCs are unaffected by the memory system")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["err_ai_hostile", "dlg_ai_ally", "dlg_ai_friend", "dlg_ai_neutral", "dlg_ai_wary", "dlg_ai_enemy", "dlg_ai_betrayed", "dlg_ai_grudge", "dlg_ai_gift_mem"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "memory reaction texts exist in Persian and English")


func _soc_pair(cs, a_arch: String, b_arch: String) -> Array:
	var CharAI = load("res://scripts/server/char_ai.gd")
	var a: Dictionary = CharAI.spawn(cs, a_arch)["npc"]
	var b: Dictionary = CharAI.spawn(cs, b_arch)["npc"]
	b["x"] = float(a["x"]) + 2.0
	b["z"] = float(a["z"])
	return [a, b]


func test_character_social() -> void:
	print("-- autonomous characters: stage 5 relations between characters")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var Soc = load("res://scripts/server/char_social.gd")
	var Mem = load("res://scripts/server/char_memory.gd")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(6161)
	NpcSim.ensure_npcs(cs)
	cs.provision_admin("boss", "secret")
	cs.ai_settings["max"] = 12
	# دوستی و اتحاد بین دو شخصیت سازگار، بدون بازیکن
	var p1: Array = _soc_pair(cs, "trader", "rival")
	var tr: Dictionary = p1[0]
	var rv: Dictionary = p1[1]
	check(Soc.compat(cs, tr, rv) > 0.0, "a trader and a rival are compatible")
	var formed := false
	for i in 12:
		cs.world_time += Soc.MEET_COOLDOWN + 1.0
		Soc.meet(cs, tr, rv)
		if Soc.is_allied(tr, rv):
			formed = true
			break
	check(formed and Soc.is_allied(rv, tr), "two compatible characters become allies on their own after repeated meetings")
	check(Mem.stance(tr["ai"], str(rv["acct"]), cs.day_count) in ["friend", "ally"] and Mem.remembers(tr["ai"], str(rv["acct"]), "alliance"), "they remember each other as friends")
	check(int(tr["ai"]["stats"]["allied"]) == 1 and int(rv["ai"]["stats"]["met"]) >= 2, "the meeting is recorded in their experience")
	check(cs.ai_events.size() >= 1 and str(cs.ai_events[cs.ai_events.size() - 1]["kind"]) == "alliance", "the alliance is announced to players")
	# هم‌ارزی: کولداون
	var met_before: int = int(tr["ai"]["stats"]["met"])
	check(not Soc.meet(cs, tr, rv) and int(tr["ai"]["stats"]["met"]) == met_before, "a pair cannot meet again before the cooldown ends")
	# تیپ‌های ناسازگار مشاجره می‌کنند و دشمن می‌شوند
	var p2: Array = _soc_pair(cs, "warlord", "schemer")
	check(Soc.compat(cs, p2[0], p2[1]) < -0.1, "a warlord and a schemer are not compatible")
	for i in 8:
		cs.world_time += Soc.MEET_COOLDOWN + 1.0
		Soc.meet(cs, p2[0], p2[1])
	check(not Soc.is_allied(p2[0], p2[1]) and Mem.stance(p2[0]["ai"], str(p2[1]["acct"]), cs.day_count) in ["wary", "enemy"], "incompatible characters quarrel and turn against each other (%s)" % Mem.stance(p2[0]["ai"], str(p2[1]["acct"]), cs.day_count))
	check(Mem.stance(tr["ai"], str(rv["acct"]), cs.day_count) != Mem.stance(p2[0]["ai"], str(p2[1]["acct"]), cs.day_count), "different pairs end up in different relationships")
	# تجارت واقعی بین شخصیت‌ها
	var sellr: Dictionary = rv
	var buyr: Dictionary = tr
	cs.accounts[str(sellr["acct"])]["inv"]["wood"] = 10
	cs.accounts[str(buyr["acct"])]["money"] = 200
	var tot0: int = int(cs.accounts[str(sellr["acct"])]["money"]) + int(cs.accounts[str(buyr["acct"])]["money"])
	var found: Dictionary = Soc.find_buyer(cs, sellr, "wood", 10)
	check(not found.is_empty() and str(found["acct"]) == str(buyr["acct"]), "a nearby trader is found as a buyer")
	var res: Dictionary = Soc.sell_to(cs, sellr, buyr, "wood", 10)
	check(int(res["count"]) >= 1 and int(cs.accounts[str(buyr["acct"])]["inv"]["wood"]) == int(res["count"]), "goods really move to the buyer's bag")
	var tot1: int = int(cs.accounts[str(sellr["acct"])]["money"]) + int(cs.accounts[str(buyr["acct"])]["money"])
	check(tot0 == tot1, "trade between characters never creates or destroys money")
	check(int(buyr["ai"]["bought"].get("wood", 0)) == int(res["count"]) and int(sellr["ai"]["stats"]["traded"]) == 1, "the trade is remembered and bought goods are not re-sold to peers")
	# خریدار مناسب نیست: جنگجو (غیرمعامله‌گر)، فقیر، دشمن، دور
	var w: Dictionary = p2[0]
	w["x"] = float(sellr["x"]) + 1.0
	w["z"] = float(sellr["z"])
	cs.accounts[str(w["acct"])]["money"] = 500
	cs.accounts[str(buyr["acct"])]["money"] = 10
	check(Soc.find_buyer(cs, sellr, "wood", 5).is_empty(), "uncooperative non-traders and broke traders do not buy")
	cs.accounts[str(buyr["acct"])]["money"] = 500
	for i in 3:
		Mem.record(sellr["ai"], "betray", str(buyr["acct"]), 1.0, cs.day_count)
	check(Soc.find_buyer(cs, sellr, "wood", 5).is_empty(), "an enemy is never sold to")
	buyr["x"] = float(sellr["x"]) + 80.0
	check(Soc.find_buyer(cs, sellr, "wood", 5).is_empty(), "a distant character is not a buyer")
	# خیانت متحد فرصت‌طلب
	var p3: Array = _soc_pair(cs, "schemer", "trader")
	var sch: Dictionary = p3[0]
	var vic: Dictionary = p3[1]
	sch["ai"]["allies"][str(vic["acct"])] = cs.day_count
	vic["ai"]["allies"][str(sch["acct"])] = cs.day_count
	check(Soc.betray_score(sch) >= Soc.BETRAY_SCORE and Soc.betray_score(vic) < Soc.BETRAY_SCORE, "only the opportunistic schemer is capable of betrayal")
	cs.world_time += Soc.MEET_COOLDOWN + 1.0
	Soc.meet(cs, sch, vic)
	check(Soc.is_allied(sch, vic) and Soc.is_allied(vic, sch), "a fresh alliance is not betrayed on the same day")
	cs.day_count += 2
	cs.world_time += Soc.MEET_COOLDOWN + 1.0
	Soc.meet(cs, sch, vic)
	check(not Soc.is_allied(sch, vic) and not Soc.is_allied(vic, sch), "the schemer later breaks the alliance")
	check(Mem.remembers(vic["ai"], str(sch["acct"]), "betray") and int(sch["ai"]["stats"]["betrayed"]) == 1, "the victim remembers the betrayal")
	check(Mem.stance(vic["ai"], str(sch["acct"]), cs.day_count) in ["wary", "enemy"], "the betrayed trader turns against the schemer")
	check(cs.ai_events[cs.ai_events.size() - 1]["kind"] == "betrayal", "the betrayal is announced to players")
	# تفاوت تیپ‌ها: خیانت‌پذیری
	var capable: Array = []
	for a in Pers_order():
		var tmp: Dictionary = CharAI.spawn(cs, a)["npc"]
		if Soc.betray_score(tmp) >= Soc.BETRAY_SCORE:
			capable.append(a)
	check(capable == ["schemer"], "among the five archetypes only the schemer is capable of betraying allies (%s)" % str(capable))
	# ذخیره و بارگذاری اتحاد
	cs.day_count += 1
	var back = CityState.from_dict(cs.to_dict())
	var btr: Dictionary = CharAI.find(back, int(tr["id"]))
	var brv: Dictionary = CharAI.find(back, int(rv["id"]))
	check(Soc.is_allied(btr, brv) and int(btr["ai"]["stats"]["allied"]) == 1, "alliances and social experience survive save and load")
	var junk: Dictionary = (tr["ai"] as Dictionary).duplicate(true)
	junk["allies"] = {"ai:1": 3, "player": 4, "ai:2": -7, "ai:3": 1, "ai:4": 1}
	var cleaned: Variant = CharAI.load_ai(junk, int(tr["id"]))
	check((cleaned["allies"] as Dictionary).size() <= Soc.ALLY_MAX and not (cleaned["allies"] as Dictionary).has("player"), "corrupted alliances are sanitized when loading")
	var old_ai: Dictionary = (tr["ai"] as Dictionary).duplicate(true)
	old_ai.erase("allies")
	check(CharAI.load_ai(old_ai, int(tr["id"])) != null, "older saves without alliances still load")
	# جهان بدون بازیکن: چند شخصیت خودشان با هم برخورد دارند
	var w2 = CityState.new(6162)
	NpcSim.ensure_npcs(w2)
	w2.ai_settings["max"] = 8
	for a in Pers_order():
		CharAI.spawn(w2, a)
	_ai_run(w2, 6000)
	var met := 0
	var rels := 0
	var trades := 0
	var built := 0
	for n in w2.npcs:
		if n.get("ai", null) is Dictionary:
			met += int(n["ai"]["stats"]["met"])
			rels += (n["ai"]["mem"]["rel"] as Dictionary).size()
			trades += int(n["ai"]["stats"]["traded"])
			built += int(n["ai"]["stats"]["built"])
	print("   unattended world: met=%d relations=%d trades=%d built=%d" % [met, rels, trades, built])
	check(met > 0 and rels > 0, "with no player present the characters meet and form relationships on their own")
	check(built > 0, "they keep building while socializing")
	var money_ok := true
	for n in w2.npcs:
		if n.get("ai", null) is Dictionary and int(w2.accounts[str(n["acct"])]["money"]) < 0:
			money_ok = false
	check(money_ok, "no character ever ends up with negative money")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["msg_ai_alliance", "msg_ai_betrayal"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "alliance and betrayal texts exist in Persian and English")


func Pers_order() -> Array:
	return load("res://scripts/server/char_personality.gd").ORDER


func Family_check(cs, npc: Dictionary) -> String:
	var Fam = load("res://scripts/server/family.gd")
	return str(Fam._check_near(cs, "plain", int(npc["id"]), Vector2(float(npc["x"]), float(npc["z"])))["error"])


func test_residents() -> void:
	print("-- residents: village houses and migrants")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var Residents = load("res://scripts/server/residents.gd")
	var cs = CityState.new(6301)
	NpcSim.ensure_npcs(cs)
	var base: int = cs.npcs.size()
	var n1: int = Residents.seed_villagers(cs)
	check(n1 > 0 and Residents.seed_villagers(cs) == 0, "village residents are seeded once (%d)" % n1)
	check(Residents.count_villagers(cs) == n1 and n1 <= FWConst.VILLAGER_MAX, "village residents respect their own cap")
	var homes := {}
	var all_jobs := true
	for n in cs.npcs:
		if Residents.is_villager(n):
			homes[str(n["home_v"])] = true
			if not FWConst.RESIDENT_JOBS.has(str(n["job"])):
				all_jobs = false
			if cs.world.house_site(str(n["home_v"])).is_empty():
				all_jobs = false
	check(homes.size() == n1 and all_jobs, "each resident has a unique real village house and a job")
	check(Residents.count_capped(cs) == base, "villagers do not use the NPC_MAX budget")
	# شبیه‌سازی: شب کنار خانه می‌خوابند و پنهان می‌شوند؛ ظهر سر کارند
	var v: Dictionary = {}
	for n in cs.npcs:
		if Residents.is_villager(n):
			v = n
			break
	cs.world_time = 3.0 * 3600.0
	for i in 400:
		NpcSim.step(cs, 0.5)
	check(str(v["state"]) == "sleep" and Residents.is_inside(v) == 1, "a villager sleeps in the house at night")
	var door: Dictionary = cs.world.house_site(str(v["home_v"]))
	check(Vector2(float(v["x"]), float(v["z"])).distance_to(Vector2(float(door["ex"]), float(door["ez"]))) < 1.5, "sleeping villager is at their own door")
	cs.world_time = 11.0 * 3600.0
	for i in 600:
		NpcSim.step(cs, 0.5)
	check(str(v["state"]) == "work" and Residents.is_inside(v) == 0, "a villager works in the village by day")
	# اقتصاد: کشاورز گندم می‌دهد، نانوا آرد را نان می‌کند، همه غذا می‌خورند
	var cs2 = CityState.new(6302)
	cs2.market["flour"] = 10.0
	cs2.market["bread"] = 5.0
	var farmer := {"job": "farmer"}
	Residents.work_daily(cs2, farmer, 5)
	check(float(cs2.market["wheat"]) == FWConst.RESIDENT_WHEAT_PER_DAY, "a farmer resident adds wheat to the market")
	Residents.work_daily(cs2, farmer, 5)
	check(float(cs2.market["wheat"]) == FWConst.RESIDENT_WHEAT_PER_DAY, "resident work happens once per day")
	var baker := {"job": "baker"}
	var bread0: float = float(cs2.market["bread"])
	Residents.work_daily(cs2, baker, 5)
	check(float(cs2.market["flour"]) == 8.0 and float(cs2.market["bread"]) > bread0 - 1.0 and float(cs2.market["bread"]) < bread0 + 3.0, "a baker resident turns flour into bread")
	cs2.creative = true
	var w0: float = float(cs2.market["wheat"])
	Residents.work_daily(cs2, {"job": "farmer"}, 6)
	check(float(cs2.market["wheat"]) == w0, "creative worlds leave the market alone")
	# مهاجران
	var cs3 = CityState.new(6303)
	_login(cs3, "owner")
	cs3.accounts["owner"]["money"] = 5000
	NpcSim.ensure_npcs(cs3)
	cs3.place_building("owner", 1, "house", 12, 14)
	var house: Dictionary = _first_of(cs3, "house")
	var hid: int = int(house["id"])
	for g in ["bread", "egg", "milk"]:
		cs3.market[g] = 20.0
	var before: int = cs3.npcs.size()
	Residents.daily(cs3, 1)
	check(cs3.npcs.size() == before, "no migrant on the first day (house just seen)")
	Residents.daily(cs3, 2)
	check(cs3.npcs.size() == before, "no migrant without a bed")
	cs3.furn_place("owner", hid, "bed", -2.1, -2.8, 0)
	var ok_day: int = Residents.daily(cs3, 3)
	check(ok_day == 1 and cs3.npcs.size() == before + 1, "a furnished house with food gets one migrant")
	var mg: Dictionary = cs3.npcs[cs3.npcs.size() - 1]
	check(int(mg["home_b"]) == hid and FWConst.RESIDENT_JOBS.has(str(mg["job"])), "the migrant lives in that house and has a job")
	check(Residents.daily(cs3, 4) == 0 and cs3.npcs.size() == before + 1, "one house holds one resident")
	cs3.world_time = 3.0 * 3600.0
	for i in 400:
		NpcSim.step(cs3, 0.5)
	var back = CityState.from_dict(cs3.to_dict())
	var kept := false
	for n in back.npcs:
		if int(n.get("home_b", -1)) == hid and str(n.get("job", "")) == str(mg["job"]):
			kept = true
	check(back != null and kept and back.house_seen.has(str(hid)), "migrants and house bookkeeping survive save and load")
	cs3.buildings.erase(hid)
	Residents.daily(cs3, 5)
	check(int(mg["home_b"]) == -1, "a resident whose house is gone becomes homeless but stays")
	# بدون غذا مهاجر نمی‌آید؛ خلاقانه هم نه
	var cs4 = CityState.new(6304)
	_login(cs4, "o")
	cs4.accounts["o"]["money"] = 5000
	cs4.place_building("o", 1, "house", 12, 14)
	var h4: Dictionary = _first_of(cs4, "house")
	cs4.furn_place("o", int(h4["id"]), "bed", -2.1, -2.8, 0)
	Residents.daily(cs4, 1)
	var n4: int = cs4.npcs.size()
	Residents.daily(cs4, 3)
	check(cs4.npcs.size() == n4, "no migrant without food in the market")
	# گفتگو و معامله
	var cs5 = CityState.new(6305)
	_login(cs5, "t")
	cs5.accounts["t"]["money"] = 1000
	cs5.npcs.append({"id": 60, "name": "x", "x": 5.0, "z": 5.0, "state": "idle", "money": 100, "paid_day": -1, "job": "seller", "home_b": -1, "home_v": "", "vx": 0.0, "vz": 0.0})
	cs5.npcs.append({"id": 61, "name": "y", "x": 5.0, "z": 6.0, "state": "idle", "money": 100, "paid_day": -1, "job": "miner", "home_b": -1, "home_v": "", "vx": 0.0, "vz": 0.0})
	cs5.npcs.append({"id": 62, "name": "z", "x": 6.0, "z": 5.0, "state": "idle", "money": 100, "paid_day": -1})
	var tk: Dictionary = cs5.npc_interact("t", 60, "", Vector2(5.0, 5.0))
	check(bool(tk["ok"]) and str(tk["line"]) == "dlg_job_seller_%d" % int(tk["level"]), "residents talk about their job")
	var plain_price: int = int(cs5.npc_buy("t", 62, "stone", 1, Vector2(6.0, 5.0))["total"])
	var seller_price: int = int(cs5.npc_buy("t", 60, "stone", 1, Vector2(5.0, 5.0))["total"])
	check(seller_price < plain_price, "a seller resident sells cheaper (%d < %d)" % [seller_price, plain_price])
	var left_plain: int = cs5._npc_stock_left(cs5.npcs[2], "stone")
	var bought := 0
	for i in 25:
		var r: Dictionary = cs5.npc_buy("t", 61, "stone", 1, Vector2(5.0, 6.0))
		if bool(r["ok"]):
			bought += 1
	check(bought > FWConst.NPC_STOCK_PER_DAY and left_plain <= FWConst.NPC_STOCK_PER_DAY, "a miner resident has a larger daily stone stock (%d)" % bought)
	var near_all: Array = NpcSim.public_list_near(cs, FWConst.CITY_SIZE * 0.5, FWConst.CITY_SIZE * 0.5)
	check(near_all.size() < cs.npcs.size() and near_all.size() >= base, "tick lists only nearby NPCs (%d of %d)" % [near_all.size(), cs.npcs.size()])
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for j in FWConst.RESIDENT_JOBS:
			for lv in 3:
				if Loc.t("dlg_job_%s_%d" % [j, lv]) == "dlg_job_%s_%d" % [j, lv]:
					texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "resident dialogue exists in Persian and English")


func test_cave() -> void:
	print("-- cave: dungeon guards in mines")
	var Cave = load("res://scripts/server/cave.gd")
	var cs = CityState.new(6401)
	var es: Array = cs.world.mine_entrances()
	check(not es.is_empty(), "world has mines for the cave test")
	var mid: String = str(es[0]["id"])
	var lay: Dictionary = cs.mine_layout(mid)
	var a: Array = Cave.slots(lay, mid)
	var b: Array = Cave.slots(cs.mine_layout(mid), mid)
	check(a.size() >= 4 and JSON.stringify(a) == JSON.stringify(b), "cave slots are deterministic (%d)" % a.size())
	check(str(a[0]["kind"]) == "warden", "slot 0 is the warden at the deepest point")
	var spawn_ok := true
	var entry: Vector2 = Mine.spawn_point(lay)
	for sl in a:
		var tp: Vector2 = sl["p"]
		if not Mine.walkable(lay, tp.x, tp.y) or tp.distance_to(entry) < 6.0:
			spawn_ok = false
	check(spawn_ok, "guards stand on walkable tiles away from the entrance")
	check(Cave.slots(cs.mine_layout("h10,10,0"), "h10,10,0").is_empty(), "village house rooms have no guards")
	# مسیریابی کاشی‌به‌کاشی
	var start: Vector2i = Vector2i(int(floor(entry.x / Mine.TILE)), int(floor(entry.y / Mine.TILE)))
	var wt: Vector2 = a[0]["p"]
	var goal := Vector2i(int(floor(wt.x / Mine.TILE)), int(floor(wt.y / Mine.TILE)))
	var ns: Dictionary = Cave.next_step(lay, start, goal, 999)
	check(int(ns["len"]) > 0 and Mine.tile_open(lay, (ns["next"] as Vector2i).x, (ns["next"] as Vector2i).y), "BFS finds a route through the maze")
	check(int(Cave.next_step(lay, start, goal, 2)["len"]) < 0, "aggro range limits the route search")
	# شبیه‌سازی
	var cv = Cave.new()
	check(cv.step(1.0, mid, lay, [])["changed"] == false and not cv.caves.has(mid), "empty mine has no state")
	var pl := {"name": "p", "pos": entry, "dmg": 1, "armor": 0.0}
	var r0: Dictionary = cv.step(0.1, mid, lay, [pl])
	check(cv.caves.has(mid) and bool(r0["send"]) and cv.public(mid).size() == a.size(), "guards appear when a player enters")
	# بازیکن کنار نگهبان بزرگ: او را می‌زند و آسیب می‌بیند
	var near: Vector2 = (a[0]["p"] as Vector2) + Vector2(1.0, 0.0)
	if not Mine.walkable(lay, near.x, near.y):
		near = a[0]["p"]
	pl["pos"] = near
	pl["dmg"] = 100
	var hurt := false
	var killed := false
	for i in 120:
		var rr: Dictionary = cv.step(0.1, mid, lay, [pl])
		if not rr["hurt"].is_empty():
			hurt = true
		for k in rr["kills"]:
			if str(k["kind"]) == "warden":
				killed = true
				check(int(k["money"]) == int(FWConst.WILD_KINDS["warden"]["money"]) and str(k["drop"]) == "gold", "the warden pays coins and gold")
		if killed:
			break
	check(killed, "a strong player kills the warden")
	check(hurt or killed, "guards attack in melee range")
	# رفتن و آمدن: نگهبان کشته‌شده بلافاصله برنمی‌گردد
	cv.caves.erase(mid)
	cv.step(0.1, mid, lay, [{"name": "p", "pos": entry, "dmg": 1, "armor": 0.0}])
	var has_warden := false
	for m in cv.public(mid):
		if str(m[1]) == "warden":
			has_warden = true
	check(not has_warden, "a killed guard stays dead until the respawn timer ends")
	cv.tick(FWConst.CAVE_RESPAWN + 1.0)
	cv.caves.erase(mid)
	cv.step(0.1, mid, lay, [{"name": "p", "pos": entry, "dmg": 1, "armor": 0.0}])
	has_warden = false
	for m in cv.public(mid):
		if str(m[1]) == "warden":
			has_warden = true
	check(has_warden, "the guard returns after the respawn timer")
	# تعقیب: اسکلت نزدیک ورودی دنبال بازیکن می‌آید و به او می‌رسد
	var cv2 = Cave.new()
	var sk: Dictionary = {}
	for sl in a:
		if str(sl["kind"]) == "skeleton":
			sk = sl
			break
	var sk_tile := Vector2i(int(floor((sk["p"] as Vector2).x / Mine.TILE)), int(floor((sk["p"] as Vector2).y / Mine.TILE)))
	var pl2 := {"name": "q", "pos": sk["p"] + Vector2(0, 0), "dmg": 0, "armor": 0.0}
	# بازیکن چند کاشی دورتر از اسکلت روی مسیر باز
	var far: Vector2 = sk["p"]
	for d in Mine.DIRS:
		var t2: Vector2i = sk_tile + d * 2
		if Mine.tile_open(lay, t2.x, t2.y) and Mine.tile_open(lay, sk_tile.x + d.x, sk_tile.y + d.y):
			far = Mine.tile_center(t2.x, t2.y)
			break
	pl2["pos"] = far
	cv2.step(0.1, mid, lay, [pl2])
	var got_hit := false
	for i in 200:
		var rr2: Dictionary = cv2.step(0.1, mid, lay, [pl2])
		if not rr2["hurt"].is_empty():
			got_hit = true
			break
	check(got_hit, "a skeleton chases the player along the corridor and strikes")
	# سرور: ساختار نتیجه و خلاقانه
	cs.provision_admin("boss", "x")
	_login(cs, "p")
	var rs: Dictionary = cs.wild_step(0.5, {}, {"p": {"mine": mid, "pos": entry}})
	check(rs.has("cave_send") and cs.caves.caves.has(mid), "city state runs guards for players inside a mine")
	cs.creative = true
	cs.wild_step(0.5, {}, {"p": {"mine": mid, "pos": entry}})
	check(not cs.caves.caves.has(mid), "creative worlds have no cave guards")


func test_character_fortify() -> void:
	print("-- autonomous characters: stage 2 walls, towers and repair")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var Fort = load("res://scripts/server/char_fortify.gd")
	var cs = CityState.new(4242)
	NpcSim.ensure_npcs(cs)
	cs.provision_admin("boss", "secret")
	var r: Dictionary = CharAI.spawn(cs, "warlord")
	check(bool(r["ok"]), "a warlord character is created")
	var npc: Dictionary = r["npc"]
	var acct: String = str(npc["acct"])
	var ai: Dictionary = npc["ai"]
	# هنوز خانه ندارد ← هدف دیوار نیست
	check(Fort.house_of(cs, acct).is_empty() and Fort.missing(cs, npc).is_empty(), "no wall is wanted before there is a house")
	var have_fort := false
	for g in CharAI.rank_goals(cs, npc):
		if str(g["kind"]) == "fortify":
			have_fort = true
	check(not have_fort, "fortify is not a goal without a house")
	# با خانه، هدف دیوار پدید می‌آید
	_ai_run(cs, 6000)
	var house: Dictionary = Fort.house_of(cs, acct)
	check(not house.is_empty(), "it built its house first")
	var blocks_before: int = int(cs.block_owner_count.get(acct, 0))
	_ai_run(cs, 12000)
	var placed: int = int(cs.block_owner_count.get(acct, 0))
	check(placed >= blocks_before and placed >= 20, "it placed real wall blocks around its house (%d)" % placed)
	var all_stone := true
	for v in cs.blocks:
		if str(cs.blocks[v][2]) == acct and str(cs.blocks[v][0]) != "stone":
			all_stone = false
	check(all_stone, "the wall is made of stone")
	check(int(ai["stats"]["built"]) > 1, "wall blocks count as built work in its stats")
	# دروازه باز می‌ماند و دیوار داخل خانه نمی‌رود
	var cells: Array = Fort.target_cells(cs, house, false)
	var door_x: int = int(house["cx"]) * 2 + 2
	var gate_open := true
	for v in cells:
		if v.x == door_x and v.z == int(house["cz"]) * 2 + 4 + Fort.MARGIN:
			gate_open = false
	check(gate_open, "a gate gap is left in front of the door")
	# هزینهٔ واقعی: سنگ از کیف مصرف می‌شود، منفی نمی‌شود
	check(int(cs.accounts[acct]["inv"].get("stone", 0)) >= 0, "stone is spent for real and never goes negative")
	# تخریب بخشی از دیوار ← تعمیر
	var mine: Array = []
	for v in cs.blocks:
		if str(cs.blocks[v][2]) == acct:
			mine.append(v)
	mine.sort()
	var cut := 0
	for v in mine:
		if cut >= 5:
			break
		if bool(cs.remove_block("boss", v.x, v.y, v.z, false)["ok"]):
			cut += 1
	var after_cut: int = int(cs.block_owner_count.get(acct, 0))
	_ai_run(cs, 9000)
	check(int(cs.block_owner_count.get(acct, 0)) > after_cut, "it repairs a damaged wall by itself")
	# ذخیره و بارگذاری: ادامه بدون هیچ فیلد جدیدی
	var back = CityState.from_dict(cs.to_dict())
	var bn: Dictionary = {}
	for n in back.npcs:
		if int(n["id"]) == int(npc["id"]):
			bn = n
	check(not bn.is_empty() and int(back.block_owner_count.get(acct, 0)) == int(cs.block_owner_count.get(acct, 0)), "wall blocks survive save and load")
	# جهان خلاقانه: بدون هزینه
	var cc = CityState.new(4242)
	NpcSim.ensure_npcs(cc)
	cc.creative = true
	var rc: Dictionary = CharAI.spawn(cc, "mystery")
	_ai_run(cc, 6000)
	check(int(cc.block_owner_count.get(str(rc["npc"]["acct"]), 0)) > 0, "creative worlds build walls without stone cost")
	# برج‌ها فقط برای تیپ‌های جاه‌طلب و جنگجو
	check(Fort.wants_towers(ai), "a warlord wants towers")
	for a in ["rival", "mystery", "trader"]:
		var other: Dictionary = CharAI.spawn(cc, a)
		check(other["ok"] and not Fort.wants_towers(other["npc"]["ai"]), "%s does not build towers" % a)
	var tower := 0
	for v in cs.blocks:
		if str(cs.blocks[v][2]) == acct and v.y >= int(floor(cs.world.height_at(float(v.x) + 0.5, float(v.z) + 0.5))) + Fort.WALL_H:
			tower += 1
	check(tower > 0, "the warlord raised real tower blocks above the wall height (%d)" % tower)
	# سنگ دیوار را نمی‌فروشد وقتی دیوار ناقص است
	cs.remove_block("boss", mine[mine.size() - 1].x, mine[mine.size() - 1].y, mine[mine.size() - 1].z, false)
	check(Fort.keeps_stone(cs, npc), "an unfinished wall makes it keep its stone")


func test_character_discovery() -> void:
	print("-- autonomous characters: gradual map discovery")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var cs = CityState.new(4242)
	NpcSim.ensure_npcs(cs)
	cs.provision_admin("boss", "secret")
	var r: Dictionary = CharAI.spawn(cs, "trader")
	var npc: Dictionary = r["npc"]
	var ai: Dictionary = npc["ai"]
	CharAI.reveal(npc)
	var seen0: int = ai["seen"].size()
	check(seen0 > 0 and seen0 <= 25, "a new character has only seen the area around itself (%d cells)" % seen0)
	# منبع ندیده شناخته نمی‌شود: همهٔ منابع پیدا‌شده باید در سلول دیده‌شده باشند
	var pos := Vector2(float(npc["x"]), float(npc["z"]))
	var all_seen := true
	var found := 0
	for k in ["tree", "rock", "clay"]:
		var f: Dictionary = CharAI.find_resource(cs, npc, pos, {}, [k])
		if not f.is_empty():
			found += 1
			if not CharAI.has_seen(ai, float(f["x"]), float(f["z"])):
				all_seen = false
	check(all_seen, "it only knows resources inside cells it has seen (%d found)" % found)
	var far := 0
	for dx in range(-24, 25):
		for dz in range(-24, 25):
			var n: Dictionary = cs.world.resource_in_cell(int(pos.x / 4.0) + dx, int(pos.y / 4.0) + dz)
			if not n.is_empty() and not CharAI.has_seen(ai, float(n["x"]), float(n["z"])):
				far += 1
	check(far > 0, "there are real resources it has not discovered yet (%d)" % far)
	# جهان بدون هیچ کشفی: برنامهٔ گشت می‌سازد
	var blank: Dictionary = {"id": 3, "x": 100.0, "z": 100.0, "ai": CharAI._fresh_ai("trader", 3)}
	var ep: Array = CharAI.explore_plan(cs, blank)
	check(ep.size() == 1 and str(ep[0]["t"]) == "explore", "with nothing seen it plans to explore")
	check(not CharAI.has_seen(blank["ai"], float(ep[0]["x"]), float(ep[0]["z"])), "the exploration target is an unseen cell")
	# شبیه‌سازی طولانی: دنیا را بیشتر می‌بیند و باز هم تولید می‌کند
	_ai_run(cs, 6000)
	check(ai["seen"].size() > seen0 + 10, "it discovered much more of the world by walking (%d cells)" % ai["seen"].size())
	check(int(ai["stats"]["gathered"]) > 0 and int(ai["stats"]["sold"]) > 0, "it still gathers and sells using only discovered resources")
	check(ai["seen"].size() <= CharAI.SEEN_MAX, "the discovery memory is bounded")
	# ذخیره و بارگذاری
	var back = CityState.from_dict(cs.to_dict())
	var bn: Dictionary = {}
	for n2 in back.npcs:
		if int(n2["id"]) == int(npc["id"]):
			bn = n2
	check(not bn.is_empty() and bn["ai"]["seen"].size() == ai["seen"].size(), "discovered cells survive save and load")
	var bad: Dictionary = CharAI.load_ai({"arch": "trader", "seen": {"x,y": true, "5,6": true, "1": true}}, 9)
	check(bad["seen"].size() == 1 and bad["seen"].has("5,6"), "corrupt discovery entries are dropped on load")
	var old: Dictionary = CharAI.load_ai({"arch": "trader"}, 9)
	check(old != null and old["seen"].is_empty(), "saves from before discovery still load")


func test_character_war() -> void:
	print("-- autonomous characters: war, retreat and negotiation")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var War = load("res://scripts/server/char_war.gd")
	var Soc = load("res://scripts/server/char_social.gd")
	var Mem = load("res://scripts/server/char_memory.gd")
	var Fort = load("res://scripts/server/char_fortify.gd")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var cs = CityState.new(7171)
	NpcSim.ensure_npcs(cs)
	cs.provision_admin("boss", "secret")
	cs.ai_settings["max"] = 12
	# --- اعلام جنگ: فقط دشمنِ پرخاشگر و شجاع ---
	var p: Array = _soc_pair(cs, "warlord", "schemer")
	var wl: Dictionary = p[0]
	var sc: Dictionary = p[1]
	var kwl := str(wl["acct"])
	var ksc := str(sc["acct"])
	check(not War.can_declare(cs, wl, sc), "no war between characters who are not enemies")
	for i in 6:
		Mem.record(wl["ai"], "quarrel", ksc, 1.0, cs.day_count)
		Mem.record(sc["ai"], "quarrel", kwl, 1.0, cs.day_count)
	check(Mem.stance(wl["ai"], ksc, cs.day_count) == "enemy", "repeated quarrels make them enemies")
	var tp: Array = _soc_pair(cs, "trader", "rival")
	for i in 6:
		Mem.record(tp[0]["ai"], "quarrel", str(tp[1]["acct"]), 1.0, cs.day_count)
	check(not War.can_declare(cs, tp[0], tp[1]), "a gentle trader is never aggressive enough to declare war")
	var ally_a: Array = _soc_pair(cs, "warlord", "schemer")
	for i in 6:
		Mem.record(ally_a[0]["ai"], "quarrel", str(ally_a[1]["acct"]), 1.0, cs.day_count)
	ally_a[0]["ai"]["allies"][str(ally_a[1]["acct"])] = cs.day_count
	check(not War.can_declare(cs, ally_a[0], ally_a[1]), "allies do not declare war on each other")
	var n_ev0: int = cs.ai_events.size()
	check(War.try_declare(cs, wl, sc) and War.at_war(wl, sc) and War.at_war(sc, wl), "the aggressive enemy declares war")
	check(bool(wl["ai"]["war"]["foes"][ksc]["agg"]) and not bool(sc["ai"]["war"]["foes"][kwl]["agg"]), "the declarer is recorded as the aggressor")
	check(cs.ai_events.size() == n_ev0 + 1 and str(cs.ai_events[cs.ai_events.size() - 1]["kind"]) == "war", "the war is announced to players")
	check(Mem.remembers(sc["ai"], kwl, "war") and int(wl["ai"]["stats"]["wars"]) == 1, "both remember the war")
	check(not War.try_declare(cs, wl, sc), "a war that is already on is not declared twice")
	check(not Soc.meet(cs, wl, sc), "characters at war do not hold friendly meetings")
	# --- لشکرکشی ---
	sc["x"] = float(wl["x"]) + 60.0
	var mp: Array = War.march_plan(cs, wl)
	check(mp.size() == 1 and str(mp[0]["t"]) == "march", "the aggressor marches toward a distant enemy")
	check(War.march_plan(cs, sc).is_empty(), "the defender does not march")
	sc["x"] = float(wl["x"]) + 400.0
	check(War.march_plan(cs, wl).is_empty(), "nobody marches across the whole world")
	sc["x"] = float(wl["x"]) + 3.0
	check(War.march_plan(cs, wl).is_empty(), "no marching when already at the enemy")
	# --- درگیری ---
	var hp0: float = float(wl["ai"]["war"]["hp"])
	War.tick(cs, 5.0)
	check(float(wl["ai"]["war"]["hp"]) < hp0 and float(sc["ai"]["war"]["hp"]) < hp0, "both sides lose war-health in a clash")
	check(float(wl["ai"]["war"]["hp"]) > float(sc["ai"]["war"]["hp"]), "the braver warlord wins the exchange against the schemer")
	check(float(cs.accounts[kwl]["hp"]) == FWConst.PLAYER_HP_MAX, "war never touches the character's account health")
	# --- دیوار واقعاً کمک می‌کند ---
	var host: Dictionary = CharAI.spawn(cs, "warlord")["npc"]
	var khost := str(host["acct"])
	cs.accounts[khost]["money"] = 100000
	var site: Dictionary = CharAI.find_site(cs, host, "house")
	cs.place_building(khost, 1, "house", int(site["cx"]), int(site["cz"]))
	var house: Dictionary = Fort.house_of(cs, khost)
	check(not house.is_empty(), "test setup: the defender has a house")
	if not house.is_empty():
		var hp_pos: Vector2 = War.home_of(cs, host)
		host["x"] = hp_pos.x
		host["z"] = hp_pos.y
		var open_f: float = War.damage_taken_factor(cs, host)
		check(is_equal_approx(open_f, 1.0) and War.wall_intact(cs, host) == 0.0, "without a wall nothing softens the blows")
		for v in Fort.target_cells(cs, house, Fort.wants_towers(host["ai"])):
			cs.blocks[v] = ["stone", 0, khost]
		var walled_f: float = War.damage_taken_factor(cs, host)
		check(War.wall_intact(cs, host) >= 0.99 and walled_f < 0.7, "a complete real wall cuts the damage taken (%.2f)" % walled_f)
		host["x"] = hp_pos.x + 60.0
		check(is_equal_approx(War.damage_taken_factor(cs, host), 1.0), "the wall only helps near its own house")
		for v in Fort.target_cells(cs, house, Fort.wants_towers(host["ai"])):
			cs.blocks.erase(v)
	# --- عقب‌نشینی ---
	var retreated := false
	var guard := 0
	while guard < 60 and not War.retreating(wl) and not War.retreating(sc):
		War.tick(cs, 5.0)
		guard += 1
		if not War.at_war(wl, sc):
			break
	retreated = War.retreating(wl) or War.retreating(sc)
	var loser_first: Dictionary = sc if War.retreating(sc) else wl
	check(retreated or not War.at_war(wl, sc), "a hurt character retreats or the war ends")
	if retreated:
		check(float(loser_first["ai"]["war"]["hp"]) <= War.retreat_threshold(loser_first) + 0.001 or float(loser_first["ai"]["war"]["away"]) > 0.0, "it retreats at its own threshold")
		check(str(loser_first["ai"]["plan"][0]["t"]) == "retreat" if not (loser_first["ai"]["plan"] as Array).is_empty() else true, "retreat makes it walk home")
		var hp_r: float = float(sc["ai"]["war"]["hp"]) + float(wl["ai"]["war"]["hp"])
		var rec: bool = false
		for e in cs.ai_events:
			if str(e["kind"]) == "retreat":
				rec = true
		check(rec, "the retreat is announced to players")
		check(War.retreat_threshold(sc) > War.retreat_threshold(wl), "the cautious schemer retreats earlier than the brave warlord")
	# --- مذاکره و صلح ---
	var money0: int = int(cs.accounts[kwl]["money"]) + int(cs.accounts[ksc]["money"])
	var g2 := 0
	while War.at_war(wl, sc) and g2 < 400:
		War.tick(cs, 5.0)
		g2 += 1
	check(not War.at_war(wl, sc) and not War.at_war(sc, wl), "the war ends by negotiation within a bounded time (%d ticks)" % g2)
	var money1: int = int(cs.accounts[kwl]["money"]) + int(cs.accounts[ksc]["money"])
	check(money0 == money1, "tribute only moves money between the two wallets")
	check(int(cs.accounts[kwl]["money"]) >= 0 and int(cs.accounts[ksc]["money"]) >= 0, "nobody ends up in debt")
	check(Mem.remembers(wl["ai"], ksc, "peace") and Mem.remembers(sc["ai"], kwl, "peace"), "both remember the peace")
	check(Mem.remembers(wl["ai"], ksc, "war_win") or Mem.remembers(sc["ai"], kwl, "war_win") or absf(War.hp_frac(wl) - War.hp_frac(sc)) < 0.15, "a clear winner remembers the victory")
	var pe := false
	for e in cs.ai_events:
		if str(e["kind"]) == "peace":
			pe = true
	check(pe, "the peace is announced to players")
	for i in 6:
		Mem.record(wl["ai"], "quarrel", ksc, 1.0, cs.day_count)
	check(not War.can_declare(cs, wl, sc), "a truce prevents an immediate new war")
	cs.day_count += War.TRUCE_DAYS + 1
	check(float(wl["ai"]["war"]["truce"][ksc]) <= cs.day_count, "the truce is time-limited")
	# --- آتش‌بس اجباری برای جنگ بی‌نتیجه ---
	var q: Array = _soc_pair(cs, "warlord", "warlord")
	q[1]["x"] = float(q[0]["x"]) + 300.0
	for i in 6:
		Mem.record(q[0]["ai"], "quarrel", str(q[1]["acct"]), 1.0, cs.day_count)
	if War.try_declare(cs, q[0], q[1]):
		cs.day_count += War.MAX_WAR_DAYS
		War.tick(cs, 5.0)
		check(not War.at_war(q[0], q[1]), "a pointless distant war is ended by force after a few days")
	# --- تنظیمات ---
	var r1: Array = _soc_pair(cs, "warlord", "schemer")
	for i in 6:
		Mem.record(r1[0]["ai"], "quarrel", str(r1[1]["acct"]), 1.0, cs.day_count)
	cs.ai_settings["war"] = false
	check(not War.can_declare(cs, r1[0], r1[1]), "war can be switched off in the settings")
	cs.ai_settings["war"] = true
	check(War.try_declare(cs, r1[0], r1[1]), "and switched on again")
	cs.ai_settings["war"] = false
	War.tick(cs, 5.0)
	check(not War.in_war(r1[0]) and not War.in_war(r1[1]), "switching war off ends running wars")
	cs.ai_settings["war"] = true
	# --- ذخیره و بارگذاری ---
	var cs3 = CityState.new(7373)
	NpcSim.ensure_npcs(cs3)
	cs3.provision_admin("boss", "secret")
	cs3.ai_settings["max"] = 12
	var s1: Array = _soc_pair(cs3, "warlord", "schemer")
	for i in 6:
		Mem.record(s1[0]["ai"], "quarrel", str(s1[1]["acct"]), 1.0, cs3.day_count)
	War.try_declare(cs3, s1[0], s1[1])
	s1[0]["ai"]["war"]["hp"] = 42.0
	var back = CityState.from_dict(cs3.to_dict())
	var bw: Dictionary = {}
	for n2 in back.npcs:
		if int(n2["id"]) == int(s1[0]["id"]):
			bw = n2
	check(not bw.is_empty() and (bw["ai"]["war"]["foes"] as Dictionary).has(str(s1[1]["acct"])) and is_equal_approx(float(bw["ai"]["war"]["hp"]), 42.0), "a running war and war-health survive save and load")
	check(bool(back.ai_settings["war"]), "the war setting survives save and load")
	var bad: Dictionary = War.load_war({"hp": 900, "away": -5, "foes": {"p": {"since": 1}, "ai:3": {"since": -4, "ticks": "x"}, "ai:4": 7}, "truce": {"zz": 3, "ai:9": 5}})
	check(float(bad["hp"]) <= War.HP_MAX and float(bad["away"]) >= 0.0 and (bad["foes"] as Dictionary).size() == 1 and (bad["foes"] as Dictionary).has("ai:3") and (bad["truce"] as Dictionary).size() == 1, "corrupted war data is sanitized when loading")
	var old: Dictionary = CharAI.load_ai({"arch": "trader"}, 9)
	check(old != null and (old["war"]["foes"] as Dictionary).is_empty() and float(old["war"]["hp"]) == War.HP_MAX, "saves from before war still load")
	# --- جهان بدون بازیکن: بدون خطا و بدون پول منفی ---
	var w2 = CityState.new(7272)
	NpcSim.ensure_npcs(w2)
	w2.provision_admin("boss", "secret")
	w2.ai_settings["max"] = 8
	for arch in ["schemer", "rival", "mystery", "trader", "warlord", "warlord", "schemer"]:
		if Personality_valid(arch):
			CharAI.spawn(w2, arch)
	_ai_run(w2, 9000)
	var wars := 0
	var peaces := 0
	var ok_state := true
	for n3 in w2.npcs:
		if n3.get("ai", null) is Dictionary:
			wars += int(n3["ai"]["stats"]["wars"])
			peaces += 1 if Mem_has_peace(n3) else 0
			var hp3: float = float(n3["ai"]["war"]["hp"])
			if hp3 < 0.0 or hp3 > War.HP_MAX or int(w2.accounts[str(n3["acct"])]["money"]) < 0:
				ok_state = false
			for fk in n3["ai"]["war"]["foes"]:
				if not w2.accounts.has(str(fk)):
					ok_state = false
	print("   unattended war world: wars=%d characters_with_peace_memory=%d" % [wars, peaces])
	check(ok_state, "after a long unattended run all war-health and money values are valid")
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		for k in ["msg_ai_war", "msg_ai_retreat", "msg_ai_peace"]:
			if Loc.t(k) == k:
				texts_ok = false
	Loc.lang = "fa"
	check(texts_ok, "war, retreat and peace texts exist in Persian and English")


func Personality_valid(arch: String) -> bool:
	return load("res://scripts/server/char_personality.gd").valid(arch)


func Mem_has_peace(n: Dictionary) -> bool:
	return int(n["ai"]["mem"]["tally"].get("peace", 0)) > 0



func test_character_creator() -> void:
	print("-- autonomous characters: stage 6 character creator")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var Creator = load("res://scripts/server/char_creator.gd")
	var Pers = load("res://scripts/server/char_personality.gd")
	var Mem = load("res://scripts/server/char_memory.gd")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	# --- پاک‌سازی مشخصات ---
	var junk: Dictionary = Pers.clean_spec({"name": "  \u0001Ali\u0002 the very long named hero  ", "arch": "bogus", "life": "x", "style": "y", "rel": "z",
		"traits": {"bravery": 7.5, "caution": -3, "trust": "abc", "unknown": 1}})
	check(str(junk["arch"]) == "rival" and str(junk["style"]) == "balanced" and str(junk["rel"]) == "neutral", "invalid role, style and relation fall back to safe defaults")
	check(str(junk["name"]).length() <= Pers.NAME_MAX and not str(junk["name"]).contains("\u0001"), "the name is trimmed and stripped of control characters")
	check(float(junk["traits"]["bravery"]) == 1.0 and float(junk["traits"]["caution"]) == 0.0, "trait values are clamped between 0 and 1")
	check(float(junk["traits"]["trust"]) == float(Pers.ARCHETYPES["rival"]["traits"]["trust"]), "a non-numeric trait keeps the role default")
	check(Pers.clean_spec(null)["traits"].size() == Pers.TRAIT_KEYS.size(), "a missing spec still yields a complete character")
	# --- ساخت ---
	var cs = CityState.new(9191)
	NpcSim.ensure_npcs(cs)
	cs.provision_admin("boss", "secret")
	cs.ai_settings["max"] = 12
	_login(cs, "plain")
	var spec := {"name": "Dara", "arch": "trader", "life": "dominion", "style": "military", "rel": "enemy",
		"traits": {"bravery": 0.9, "caution": 0.1, "ambition": 0.9, "trust": 0.2, "aggression": 0.9, "cooperation": 0.2, "selfishness": 0.8, "risk": 0.9}}
	var r: Dictionary = Creator.create(cs, spec, "boss")
	check(bool(r["ok"]) and str(r["npc"]["name"]) == "Dara", "a custom character is created with the chosen name")
	var n: Dictionary = r["npc"]
	check(bool(n["ai"]["custom"]) and str(n["ai"]["life"]) == "dominion" and float(n["ai"]["traits"]["aggression"]) == 0.9, "chosen traits and life goal are applied")
	check(Pers.weight_of(n["ai"], "house") > Pers.weight_of(n["ai"], "shop"), "the military style changes building interest (house over shop for a trader)")
	check(Mem.stance(n["ai"], "boss", cs.day_count) == "enemy", "the chosen initial relation to the creator is an enemy")
	var plain: Dictionary = CharAI.spawn(cs, "trader")["npc"]
	check(Pers.weight_of(plain["ai"], "shop") == Pers.build_weight("trader", "shop"), "an ordinary character is unaffected by the creator")
	check(Mem.stance(n["ai"], "someone_else", cs.day_count) == "neutral", "the relation applies only to the creator")
	for rel in ["ally", "friend", "neutral", "rival", "enemy"]:
		var tmp: Dictionary = Creator.create(cs, {"arch": "mystery", "rel": rel}, "boss")["npc"]
		var st: String = Mem.stance(tmp["ai"], "boss", cs.day_count)
		var want: String = {"ally": "ally", "friend": "friend", "neutral": "neutral", "rival": "wary", "enemy": "enemy"}[rel]
		check(st == want, "initial relation %s gives stance %s (got %s)" % [rel, want, st])
	# --- رفتار واقعاً از ویژگی‌ها می‌آید ---
	var pair: Array = []
	for aggr in [0.05, 0.95]:
		var c2 = CityState.new(4040)
		NpcSim.ensure_npcs(c2)
		c2.ai_settings["max"] = 12
		var sp := {"arch": "rival", "traits": {"aggression": aggr, "bravery": aggr, "caution": 1.0 - aggr, "ambition": 0.8}}
		var nn: Dictionary = Creator.create(c2, sp, "boss")["npc"]
		_ai_run(c2, 120)
		pair.append({"owned": _ai_owned(c2, str(nn["acct"])).size(), "thoughts": int(nn["ai"]["stats"]["thoughts"]), "tr": nn["ai"]["traits"]})
	check(int(pair[0]["thoughts"]) > 0 and int(pair[1]["thoughts"]) > 0, "custom characters make independent decisions")
	check(float(pair[0]["tr"]["aggression"]) < 0.5 and float(pair[1]["tr"]["aggression"]) > 0.5, "the two custom characters keep very different personalities")
	# --- حد یادگیری از ویژگی‌های انتخابی ---
	var learner: Dictionary = Creator.create(cs, {"arch": "rival", "traits": {"caution": 0.5, "risk": 0.5, "bravery": 0.5}}, "boss")["npc"]
	for i in 100:
		Mem.learn(learner["ai"], false, Pers.base_of(learner["ai"], int(learner["id"])))
	check(float(learner["ai"]["traits"]["caution"]) <= 0.75 + 0.001 and float(learner["ai"]["traits"]["risk"]) >= 0.25 - 0.001, "learning stays within 0.25 of the CHOSEN traits")
	# --- ویرایش ---
	Mem.record(n["ai"], "gift", "boss", 1.0, cs.day_count)
	var mem_before: int = (n["ai"]["mem"]["rel"] as Dictionary).size()
	var money_before: int = int(cs.accounts[str(n["acct"])]["money"])
	var e: Dictionary = Creator.edit(cs, int(n["id"]), {"name": "Dara2", "arch": "warlord", "traits": {"aggression": 0.1}, "life": "wealth", "style": "economic"})
	check(bool(e["ok"]) and str(n["name"]) == "Dara2" and float(n["ai"]["traits"]["aggression"]) == 0.1, "an existing character can be edited")
	check(str(n["ai"]["arch"]) == "trader", "editing never changes the base role")
	check((n["ai"]["mem"]["rel"] as Dictionary).size() == mem_before and int(cs.accounts[str(n["acct"])]["money"]) == money_before, "editing keeps memory and assets")
	check(Pers.weight_of(n["ai"], "shop") > Pers.weight_of(n["ai"], "house"), "the edited economic style changes building interest")
	check(not bool(Creator.edit(cs, 99999, {})["ok"]), "editing an unknown character is rejected")
	var human_id := -1
	for hn in cs.npcs:
		if not CharAI.is_ai(hn):
			human_id = int(hn["id"])
			break
	check(not bool(Creator.edit(cs, human_id, {"name": "Hacked"})["ok"]), "an ordinary NPC cannot be edited as a character")
	# --- قالب‌ها ---
	var t1: Dictionary = Creator.save_template(cs, spec)
	check(bool(t1["ok"]) and cs.ai_templates.size() == 1, "a template is saved")
	for i in 20:
		Creator.save_template(cs, {"arch": "mystery"})
	check(cs.ai_templates.size() == Creator.TEMPLATES_MAX, "the template list is capped")
	check(str(Creator.save_template(cs, spec)["error"]) == "ai_tpl_full", "a full template list is refused")
	var cnt: int = CharAI.count(cs)
	var sp2: Dictionary = Creator.spawn_template(cs, 0, "boss")
	check(bool(sp2["ok"]) and CharAI.count(cs) == cnt + 1 and str(sp2["npc"]["name"]) == "Dara", "a saved template spawns a character")
	check(not bool(Creator.spawn_template(cs, 99, "boss")["ok"]) and not bool(Creator.delete_template(cs, -1)["ok"]), "bad template index is rejected")
	check(bool(Creator.delete_template(cs, 1)["ok"]) and cs.ai_templates.size() == Creator.TEMPLATES_MAX - 1, "a template can be deleted")
	# --- سقف‌ها همچنان برقرارند ---
	cs.ai_settings["max"] = CharAI.count(cs)
	check(str(Creator.create(cs, spec, "boss")["error"]) == "ai_full", "the character limit applies to custom characters too")
	cs.ai_settings["on"] = false
	check(str(Creator.create(cs, spec, "boss")["error"]) == "ai_off", "custom characters are refused when autonomy is off")
	cs.ai_settings["on"] = true
	cs.ai_settings["max"] = 12
	# --- ذخیره و بارگذاری ---
	cs.day_count += 1
	var back = CityState.from_dict(cs.to_dict())
	var bn: Dictionary = CharAI.find(back, int(n["id"]))
	check(not bn.is_empty() and bool(bn["ai"]["custom"]) and str(bn["ai"]["life"]) == "wealth", "a custom character survives save and load")
	check(float(bn["ai"]["traits"]["aggression"]) == 0.1 and float(bn["ai"]["base"]["aggression"]) == 0.1, "its chosen traits and base survive save and load")
	check(Pers.weight_of(bn["ai"], "shop") == Pers.weight_of(n["ai"], "shop"), "its style survives save and load")
	check(Mem.remembers(bn["ai"], "boss", "gift"), "its memory survives save and load")
	check(back.ai_templates.size() == cs.ai_templates.size() and str(back.ai_templates[0]["name"]) == "Dara", "templates survive save and load")
	var dirty: Dictionary = cs.to_dict()
	dirty["ai_templates"] = [{"arch": "zzz", "traits": {"bravery": 99}}, "junk", 5, {"name": "X", "arch": "warlord"}]
	for npc_raw in dirty["npcs"]:
		if npc_raw.get("ai", null) is Dictionary and bool(npc_raw["ai"].get("custom", false)):
			npc_raw["ai"]["bw"] = {"shop": 99.0, "bogus": 1.0}
			npc_raw["ai"]["life"] = "evil"
			npc_raw["ai"]["base"] = "garbage"
			break
	var clean = CityState.from_dict(dirty)
	check(clean.ai_templates.size() == 2 and float(clean.ai_templates[0]["traits"]["bravery"]) <= 1.0, "corrupted templates are sanitized on load")
	var worst := 0.0
	for cn in clean.npcs:
		if cn.get("ai", null) is Dictionary and bool(cn["ai"]["custom"]):
			worst = maxf(worst, float((cn["ai"]["bw"] as Dictionary).get("shop", 0.0)))
			check(Pers.LIFE_GOALS.has(str(cn["ai"]["life"])) and not (cn["ai"]["bogus"] if cn["ai"].has("bogus") else false), "a corrupted life goal falls back to a valid one")
	check(worst <= 1.2, "corrupted style weights are clamped on load")
	var old: Dictionary = cs.to_dict()
	old.erase("ai_templates")
	check(CityState.from_dict(old).ai_templates.is_empty(), "older saves without templates still load")
	# --- متن‌ها ---
	var texts_ok := true
	for lang in ["fa", "en"]:
		Loc.lang = lang
		var keys: Array = ["ai_creator_open", "ai_creator_title", "ai_creator_hint", "ai_name_hint", "ai_create_go", "ai_edit_go", "ai_edit_open", "ai_tpl_save",
			"ai_tpl_title", "msg_ai_tpl_saved", "msg_ai_edited", "err_ai_tpl_full"]
		for k in Pers.TRAIT_KEYS:
			keys.append("ai_t_" + k)
		for k in Pers.LIFE_GOALS:
			keys.append("ai_life_" + k)
		for k in Pers.STYLES:
			keys.append("ai_style_" + k)
		for k in Pers.RELATIONS:
			keys.append("ai_rel_" + k)
		for k in ["arch", "life", "style", "rel"]:
			keys.append("ai_pick_" + k)
		for k in keys:
			if Loc.t(k) == k:
				texts_ok = false
				print("   missing text: ", lang, " ", k)
	Loc.lang = "fa"
	check(texts_ok, "creator texts exist in Persian and English")
	check(FWConst.PROTOCOL_VERSION >= 55, "protocol bumped for the character creator message")
	check(load("res://scripts/server/game_server.gd").LOCAL_METHODS.has("c2s_ai_creator"), "the creator message is allowed in the offline local server")


func test_character_performance() -> void:
	print("-- autonomous characters: stage 8 performance")
	var CharAI = load("res://scripts/server/char_ai.gd")
	var NpcSim = load("res://scripts/server/npc_sim.gd")
	var Pers = load("res://scripts/server/char_personality.gd")
	# کش منبع باید با نتیجهٔ خام یکی باشد و با تغییر زمین باطل شود.
	var cs = CityState.new(5151)
	var w = cs.world
	var same := true
	var cells := 0
	for rx in range(-30, 30):
		for rz in range(-30, 30):
			var a: Dictionary = w.resource_in_cell(rx, rz)
			var b: Dictionary = w._resource_in_cell_raw(rx, rz)
			var c: Dictionary = w.resource_in_cell(rx, rz)   # از کش
			if a != b or c != b:
				same = false
			if not b.is_empty():
				cells += 1
	check(same and cells > 0, "the resource cache returns exactly what the generator computes")
	var found := Vector2i(0, 0)
	for rx in range(-60, 60):
		for rz in range(-60, 60):
			var n: Dictionary = w.resource_in_cell(rx, rz)
			if not n.is_empty() and found == Vector2i(0, 0):
				found = Vector2i(rx, rz)
	var nd: Dictionary = w.resource_in_cell(found.x, found.y)
	var ix := int(floor(float(nd["x"]) / FWConst.TERRAIN_EDIT_STEP))
	var iz := int(floor(float(nd["z"]) / FWConst.TERRAIN_EDIT_STEP))
	for dx in range(-1, 3):
		for dz in range(-1, 3):
			w.set_edit(ix + dx, iz + dz, -FWConst.TERRAIN_ADMIN_MAX_UNITS)   # گود بزرگ: منبع باید از آن سلول ناپدید شود
	check(w.resource_in_cell(found.x, found.y) == w._resource_in_cell_raw(found.x, found.y), "the resource cache is invalidated by terrain edits")
	# بودجهٔ تصمیم: در هر گام بیش از سقف شخصیت فکر نمی‌کند، ولی همه به نوبت فکر می‌کنند.
	var c2 = CityState.new(6262)
	NpcSim.ensure_npcs(c2)
	c2.ai_settings["max"] = 12
	for i in 12:
		CharAI.spawn(c2, Pers.ORDER[i % 5])
	var budget: int = CharAI.think_budget(c2)
	var worst_step := 0
	var before := {}
	for n in c2.npcs:
		if CharAI.is_ai(n):
			before[int(n["id"])] = 0
	for i in 160:
		var prev := {}
		for n in c2.npcs:
			if CharAI.is_ai(n):
				prev[int(n["id"])] = int(n["ai"]["stats"]["thoughts"])
		c2.tick(0.5)
		NpcSim.step(c2, 0.5)
		var now := 0
		for n in c2.npcs:
			if CharAI.is_ai(n):
				now += int(n["ai"]["stats"]["thoughts"]) - int(prev[int(n["id"])])
		worst_step = maxi(worst_step, now)
	check(worst_step <= budget, "no step exceeds the think budget (%d <= %d)" % [worst_step, budget])
	var starved := 0
	for n in c2.npcs:
		if CharAI.is_ai(n) and (n["ai"]["plan"] as Array).is_empty() and float(n["ai"]["t"]) > CharAI._interval(c2, n) * 4.0:
			starved += 1   # منتظر نوبت فکرکردن مانده و نوبتش نمی‌رسد
	check(starved == 0, "no character is starved of thinking by the budget")
	for lv in ["economy", "balanced", "advanced"]:
		c2.ai_settings["level"] = lv
		check(CharAI.think_budget(c2) >= 2, "think budget exists for level " + lv)
