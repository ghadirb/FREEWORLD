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
