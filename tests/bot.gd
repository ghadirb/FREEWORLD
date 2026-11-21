extends SceneTree
## بات تست یکپارچه. با tests/integration.sh اجرا می‌شود.
## godot --headless --path . --script res://tests/bot.gd -- --scenario builder --name alice --port 17777

const FWConst = preload("res://scripts/core/const.gd")
const NetScript = preload("res://scripts/networking/net.gd")
const GameClient = preload("res://scripts/networking/game_client.gd")
const Settings = preload("res://scripts/client/settings.gd")

var client
var net
var cfg: Dictionary = {}
var notices: Array = []
var chats: Array = []
var offers: Array = []
var teleports: int = 0
var login_error: String = ""
var failed: bool = false
var audit_entries: Array = []


func _initialize() -> void:
	Settings.persist = false  # پین گواهی‌ها در تنظیمات واقعی ذخیره نشوند
	_main.call_deferred()


func _arg(key: String, default: String = "") -> String:
	var a := OS.get_cmdline_user_args()
	var i := a.find("--" + key)
	if i >= 0 and i + 1 < a.size():
		return a[i + 1]
	return default


func log_line(msg: String) -> void:
	print("[bot %s/%s] %s" % [cfg["scenario"], cfg["name"], msg])


func fail(msg: String) -> void:
	failed = true
	print("[bot %s/%s] FAIL: %s" % [cfg["scenario"], cfg["name"], msg])


func expect(cond: bool, msg: String) -> void:
	if cond:
		log_line("ok: " + msg)
	else:
		fail(msg)


func wait_until(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		if cond.call():
			return true
		await create_timer(0.05).timeout
	return cond.call()


func _main() -> void:
	cfg = {
		"scenario": _arg("scenario", "builder"), "name": _arg("name", "alice"),
		"port": int(_arg("port", "17777")), "token_file": _arg("token-file", ""),
		"secret": _arg("secret", ""),
	}
	var guard := create_timer(45.0)
	guard.timeout.connect(func():
		print("[bot] TIMEOUT")
		quit(3))
	net = Node.new()
	net.set_script(NetScript)
	net.name = "Net"
	root.add_child(net)
	client = Node.new()
	client.set_script(GameClient)
	client.name = "GameClient"
	root.add_child(client)
	client.setup(net)
	client.notice.connect(func(code, _args): notices.append(code))
	client.offer_received.connect(func(d): offers.append(d))
	client.chat_received.connect(func(from_name, text): chats.append([from_name, text]))
	client.teleported.connect(func(_p): teleports += 1)
	client.login_failed.connect(func(e): login_error = e)

	var token := ""
	if cfg["secret"] != "":
		token = cfg["secret"]
	elif cfg["token_file"] != "" and FileAccess.file_exists(cfg["token_file"]):
		token = FileAccess.get_file_as_string(cfg["token_file"]).strip_edges()
	if client.connect_to("127.0.0.1", cfg["port"], cfg["name"], token) != OK:
		fail("cannot create client")
		quit(1)
		return

	if cfg["scenario"] == "badauth":
		await wait_until(func(): return login_error != "", 8.0)
		expect(login_error == "bad_token", "wrong token rejected (%s)" % login_error)
		quit(1 if failed else 0)
		return

	var ok: bool = await wait_until(func(): return client.is_logged_in, 8.0)
	if not ok:
		fail("login did not succeed (%s)" % login_error)
		quit(1)
		return
	await wait_until(func(): return client.mirror != null and client.npcs.size() > 0, 5.0)
	if cfg["token_file"] != "" and client.token != "":
		var f := FileAccess.open(cfg["token_file"], FileAccess.WRITE)
		f.store_string(client.token)
		f.close()
	log_line("logged in as %s role=%s money=%d" % [client.my_name, client.role, client.money])

	match cfg["scenario"]:
		"builder":
			await _builder()
		"observer":
			await _observer()
		"persist":
			await _persist()
		"admin":
			await _admin()
		"village":
			await _village()
	client.disconnect_from_server()
	await create_timer(0.3).timeout
	quit(1 if failed else 0)


func _find_cell(type: String) -> Vector2i:
	for cz in range(8, 56, 3):
		for cx in range(8, 56, 3):
			if client.preview_error(type, cx, cz) == "":
				return Vector2i(cx, cz)
	return Vector2i(-1, -1)


func _builder() -> void:
	expect(client.money == FWConst.START_MONEY, "new account starts with %d" % FWConst.START_MONEY)
	var start: Vector2 = client.spawn
	var pos := start
	for i in range(30):
		var next := pos + Vector2(0.2, 0.0)
		if client.mirror.is_walkable(next.x, next.y):
			pos = next
		client.send_move(pos.x, pos.y, 0.0)
		await create_timer(0.033).timeout
	await create_timer(0.5).timeout
	expect(teleports == 0, "legit walking is not corrected")
	var seen: Vector3 = client.players.get(client.my_name, {}).get("pos", Vector3.ZERO)
	expect(Vector2(seen.x, seen.z).distance_to(pos) < 1.5, "server tracks my position")
	client.send_move(pos.x + 120.0, pos.y, 0.0)
	var tp: bool = await wait_until(func(): return teleports > 0, 3.0)
	expect(tp, "speed-hack teleport is rejected by the server")
	var cell := _find_cell("house")
	expect(cell.x >= 0, "found a free building cell")
	client.place("house", cell.x, cell.y)
	var built: bool = await wait_until(func(): return client.money == FWConst.START_MONEY - 300, 4.0)
	expect(built, "house paid for (money=%d)" % client.money)
	client.place("road", 31, 31)
	var rej: bool = await wait_until(func(): return "reserved" in notices, 3.0)
	expect(rej, "player cannot build in the reserved plaza")
	client.send_chat("salam")
	client.offer("bob", "wood", 5, 0)
	var sent: bool = await wait_until(func(): return "offer_sent" in notices, 3.0)
	expect(sent, "my trade offer to bob was sent")
	# زمین: کندن با بیل در نزدیکی خودم؛ همهٔ بازیکنان باید تغییر را ببینند (پروتکل ۱۶)
	var spot := _dig_spot(pos)
	expect(spot.x > -9000.0, "found open ground to dig")
	if spot.x > -9000.0:
		var tv: Vector2i = client.mirror.terrain_vertex(spot.x, spot.y)
		client.dig(spot.x, spot.y)
		var dug: bool = await wait_until(func(): return client.mirror.world.edit_units(tv.x, tv.y) < 0, 4.0)
		expect(dug, "my dig lowered the ground on my own client")
		var pre: int = client.mirror.world.edit_units(tv.x, tv.y)
		client.fill(spot.x, spot.y)
		var filled: bool = await wait_until(func(): return client.mirror.world.edit_units(tv.x, tv.y) > pre, 4.0)
		expect(filled, "filling raised the ground again")
		client.dig(spot.x, spot.y)
		await wait_until(func(): return client.mirror.world.edit_units(tv.x, tv.y) <= pre, 4.0)
	await create_timer(6.0).timeout


func _dig_spot(from: Vector2) -> Vector2:
	for r in [3.0, 4.0, 5.0, 6.0]:
		for a in range(0, 360, 30):
			var p: Vector2 = from + Vector2(r, 0.0).rotated(deg_to_rad(float(a)))
			if client.mirror.world.height_at(p.x, p.y) < 1.0:
				continue
			if client.mirror.terrain_check("player", client.mirror.terrain_vertex(p.x, p.y)) == "":
				return p
	return Vector2(-9999.0, -9999.0)


func _observer() -> void:
	var start: Vector2 = client.spawn
	var found: bool = await wait_until(func():
		if not client.players.has("alice"):
			return false
		for id in client.mirror.buildings:
			if client.mirror.buildings[id]["owner"] == "alice":
				return true
		return false, 20.0)
	expect(found, "I can see alice and her building")
	var apos: Vector3 = client.players.get("alice", {}).get("pos", Vector3.ZERO)
	expect(absf(apos.x - start.x) > 3.0, "alice's movement is visible to me (dx=%.1f)" % (apos.x - start.x))
	var heard: bool = await wait_until(func(): return chats.size() > 0, 12.0)
	expect(heard and chats[0][0] == "alice" and chats[0][1] == "salam", "chat from alice received")
	var target := -1
	for id in client.mirror.buildings:
		if client.mirror.buildings[id]["owner"] == "alice":
			target = id
	client.remove(target)
	var forbid: bool = await wait_until(func(): return "forbidden" in notices, 3.0)
	expect(forbid, "I cannot demolish alice's building")
	expect(client.mirror.buildings.has(target), "alice's building still exists")
	client.set_role("alice", "world_admin")
	await create_timer(0.5).timeout
	expect("forbidden" in notices and notices.count("forbidden") >= 2, "a player cannot grant roles")
	var terr: bool = await wait_until(func(): return not client.mirror.world.edits.is_empty(), 10.0)
	expect(terr, "I can see the terrain alice dug (%d edited vertices)" % client.mirror.world.edits.size())
	var got: bool = await wait_until(func(): return offers.size() > 0, 10.0)
	expect(got and offers[0]["from"] == "alice" and offers[0]["item"] == "wood", "I received alice's trade offer")
	if got:
		var wood0: int = client.item_count("wood")
		client.answer_offer(int(offers[0]["id"]), true)
		var moved: bool = await wait_until(func(): return client.item_count("wood") == wood0 + 5, 4.0)
		expect(moved, "accepted trade moved the materials to me (wood=%d)" % client.item_count("wood"))


func _persist() -> void:
	expect(client.money == FWConst.START_MONEY - 300, "money persisted across restart (money=%d)" % client.money)
	var mine := 0
	for id in client.mirror.buildings:
		if client.mirror.buildings[id]["owner"] == client.my_name:
			mine += 1
	expect(mine == 1, "my building persisted")
	expect(client.npcs.size() == FWConst.NPC_COUNT, "npcs exist after restart")
	expect(not client.mirror.world.edits.is_empty(), "terrain edits persisted across restart (%d vertices)" % client.mirror.world.edits.size())
	expect(client.spawn.x > client.mirror.spawn_position().x + 3.0, "my position persisted")


func _admin() -> void:
	expect(client.role == FWConst.ROLE_WORLD_ADMIN, "provisioned admin has world_admin role")
	client.set_role("bob", "city_admin")
	var set_ok: bool = await wait_until(func(): return "role_set" in notices, 3.0)
	expect(set_ok, "world admin can grant city_admin")
	var victim := -1
	for id in client.mirror.buildings:
		if client.mirror.buildings[id]["owner"] == "alice":
			victim = id
	expect(victim >= 0, "alice's building is visible to admin")
	client.remove(victim)
	var gone: bool = await wait_until(func(): return not client.mirror.buildings.has(victim), 3.0)
	expect(gone, "admin can remove another player's building")
	client.audit_received.connect(func(e): audit_entries = e)
	client.request_audit()
	await wait_until(func(): return audit_entries.size() > 0, 3.0)
	var actions: Array = []
	for e in audit_entries:
		actions.append(e["action"])
	expect("admin_remove" in actions and "set_role" in actions, "admin actions are in the audit log")


func _village() -> void:
	## چند ساختمان نزدیک میدان می‌سازد (برای تست بصری).
	var plan := [["house", 36, 36], ["house", 40, 36], ["farm", 44, 36], ["well", 36, 40],
		["road", 38, 40], ["road", 39, 40], ["road", 40, 40], ["road", 41, 40], ["road", 42, 40]]
	for e in plan:
		var err: String = client.preview_error(e[0], e[1], e[2])
		if err != "":
			log_line("skip %s at %d,%d: %s" % [e[0], e[1], e[2], err])
			continue
		client.place(e[0], e[1], e[2])
		await create_timer(0.25).timeout
	await create_timer(1.0).timeout
	expect(client.mirror.buildings.size() >= 5, "village built (%d buildings)" % client.mirror.buildings.size())
