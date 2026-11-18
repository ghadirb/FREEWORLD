extends SceneTree
## تست حالت آفلاین: (۱) تک‌نفره بدون شبکه، (۲) ماندگاری پس از راه‌اندازی مجدد،
## (۳) میزبان محلی + مهمان راه‌دور روی ENet. اجرا:
##   godot --headless --path . --script res://tests/local_test.gd

const FWConst = preload("res://scripts/core/const.gd")
const NetScript = preload("res://scripts/networking/net.gd")
const GameClient = preload("res://scripts/networking/game_client.gd")
const ServerMain = preload("res://scripts/server/server_main.gd")
const Placement = preload("res://scripts/shared/placement.gd")

var fails := 0
var net: Node


func _initialize() -> void:
	_run.call_deferred()


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		print("  FAIL ", msg)
		fails += 1


func wait_until(cond: Callable, secs: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
		if cond.call():
			return true
		await create_timer(0.05).timeout
	return cond.call()


func _mk_client() -> Node:
	var c := Node.new()
	c.set_script(GameClient)
	root.add_child(c)
	c.setup(net)
	return c


func _start_server(port: int, dir: String) -> Node:
	return ServerMain.launch(root, {"port": port, "seed": 777, "data_dir": dir, "admins": [["hosty", "secret-secret-1"]], "max_seconds": 0.0})


func _run() -> void:
	net = Node.new()
	net.set_script(NetScript)
	net.name = "Net"
	root.add_child(net)
	var dir := OS.get_user_data_dir().path_join("local_test_%d" % Time.get_ticks_msec())

	print("== solo (no network port) ==")
	var server := _start_server(0, dir)
	ok(server != null, "offline server starts")
	ok(get_multiplayer().multiplayer_peer is OfflineMultiplayerPeer, "no network peer is opened")
	var c := _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in, 3.0), "local login succeeds")
	ok(c.role == FWConst.ROLE_WORLD_ADMIN, "solo player is world admin")
	await wait_until(func(): return c.ticked.get_connections().size() >= 0 and c.last_tick_msec > 0, 3.0)
	ok(c.last_tick_msec > 0, "ticks are delivered")
	var before_money: int = c.money
	var spot := Vector2i(-1, -1)
	for cx in range(4, 20):
		for cz in range(4, 20):
			if c.preview_error("house", cx, cz) == "":
				spot = Vector2i(cx, cz)
				break
		if spot.x >= 0:
			break
	ok(spot.x >= 0, "found a free building spot")
	c.place("house", spot.x, spot.y)
	ok(await wait_until(func(): return c.money < before_money, 3.0), "house purchase is applied by the server")
	ok(server.cs.buildings.size() == 1, "server state has the building")
	# کلاینت نباید به حالت سرور دسترسی مشترک داشته باشد
	c.mirror.buildings.clear()
	ok(server.cs.buildings.size() == 1, "client mirror is isolated from server state")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout

	print("== restart keeps the world ==")
	server = _start_server(0, dir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in, 3.0), "login after restart")
	ok(server.cs.buildings.size() == 1, "building survived restart")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout

	print("== jobs over the local RPC path ==")
	var jdir := OS.get_user_data_dir().path_join("local_test_jobs_%d" % Time.get_ticks_msec())
	server = _start_server(0, jdir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in, 3.0), "login for the jobs test")
	var boss_tok: String = server.cs.authenticate("boss", "")["token"]
	server.cs.accounts["boss"]["money"] = 5000
	var spot2 := Vector2i(-1, -1)
	for cx in range(4, 30):
		for cz in range(4, 30):
			if spot2.x < 0 and Placement.check(server.cs.world, server.cs.occupied, "farm", cx, cz, FWConst.ROLE_PLAYER) == "":
				spot2 = Vector2i(cx, cz)
	ok(spot2.x >= 0, "found a spot for the boss farm")
	var placed: Dictionary = server.cs.place_building("boss", 0, "farm", spot2.x, spot2.y)
	ok(placed["ok"], "boss builds a farm on the server")
	var fid: int = int(placed["building"]["id"])
	var codes: Array = []
	c.notice.connect(func(code, _a): codes.append(code))
	var door: Vector2 = server.cs.door_point(server.cs.buildings[fid])
	server.peers[1]["pos"] = Vector3(door.x + 200.0, 0.0, door.y)
	c.set_job(fid)
	ok(await wait_until(func(): return codes.has("too_far"), 2.0), "cannot take a job while far away")
	ok(c.job_id == 0, "client has no job after the refusal")
	server.peers[1]["pos"] = Vector3(door.x, 0.0, door.y)
	await create_timer(0.3).timeout  # جلوگیری از محدودیت نرخ
	c.set_job(fid)
	ok(await wait_until(func(): return c.job_id == fid, 3.0), "job is confirmed to the client")
	ok(codes.has("job_taken"), "client got the job_taken notice")
	server.cs.wage_interval = 1.0
	var m0: int = c.money
	ok(await wait_until(func(): return c.money >= m0 + FWConst.WAGE_AMOUNT, 6.0), "wage reaches the client over the RPC path")
	ok(codes.has("wage"), "client got the wage notice")
	var boss_after: int = server.cs.money_of("boss")
	ok(boss_after <= 5000 - int(FWConst.BUILDING_TYPES["farm"]["cost"]) - FWConst.WAGE_AMOUNT, "the employer paid at least one wage (%d left)" % boss_after)
	c.remove(fid)
	ok(await wait_until(func(): return c.job_id == 0, 3.0), "job ends when the workplace is removed")
	ok(codes.has("job_lost"), "client got the job_lost notice")
	c.set_job(0)
	ok(await wait_until(func(): return codes.has("no_job"), 3.0), "quitting without a job reports no_job")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout

	print("== host + remote guest ==")
	var port := 17891
	server = _start_server(port, dir)
	ok(server != null, "host server listens")
	var host_c := _mk_client()
	host_c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return host_c.is_logged_in, 3.0), "host logs in locally")
	# مهمان: ENet واقعی روی همان سرور (کلاینت جدا با Net مشترک /root/Net کار نمی‌کند، پس پردازهٔ جدا لازم است)
	var out: Array = []
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/bot.gd", "--", "--scenario", "observer", "--name", "guesty", "--port", str(port)])
	ok(pid > 0, "guest process started")
	ok(await wait_until(func(): return host_c.players.has("guesty"), 15.0), "host sees the remote guest")
	host_c.send_chat("hello from host")
	await create_timer(1.0).timeout
	host_c.disconnect_from_server()
	server.stop()
	OS.kill(pid)
	print("RESULT: %s" % ("ALL PASSED" if fails == 0 else "%d FAILED" % fails))
	quit(fails)
