extends SceneTree
## تست حالت آفلاین: (۱) تک‌نفره بدون شبکه، (۲) ماندگاری پس از راه‌اندازی مجدد،
## (۳) میزبان محلی + مهمان راه‌دور روی ENet. اجرا:
##   godot --headless --path . --script res://tests/local_test.gd

const FWConst = preload("res://scripts/core/const.gd")
const NetScript = preload("res://scripts/networking/net.gd")
const GameClient = preload("res://scripts/networking/game_client.gd")
const ServerMain = preload("res://scripts/server/server_main.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const Mine = preload("res://scripts/shared/mine.gd")
const GameViewScript = preload("res://scripts/client/game_view.gd")
const HudScript = preload("res://scripts/client/hud.gd")

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

	print("== entering buildings over the local RPC path ==")
	var edir := OS.get_user_data_dir().path_join("local_test_enter_%d" % Time.get_ticks_msec())
	server = _start_server(0, edir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in, 3.0), "login for the enter test")
	var espot := Vector2i(-1, -1)
	for cx in range(4, 20):
		for cz in range(4, 20):
			if c.preview_error("house", cx, cz) == "":
				espot = Vector2i(cx, cz)
				break
		if espot.x >= 0:
			break
	c.place("house", espot.x, espot.y)
	ok(await wait_until(func(): return server.cs.buildings.size() == 1, 3.0), "house exists for the enter test")
	var hid: int = server.cs.buildings.keys()[0]
	var edoor: Vector2 = server.cs.door_point(server.cs.buildings[hid])
	server.peers[1]["pos"] = Vector3(edoor.x + 40.0, 0.0, edoor.y)
	c.enter_building(hid)
	await create_timer(0.3).timeout
	ok(c.inside_id == 0, "cannot enter from far away")
	server.peers[1]["pos"] = Vector3(edoor.x, 0.0, edoor.y)
	c.enter_building(hid)
	ok(await wait_until(func(): return c.inside_id == hid, 3.0), "enter succeeds next to the door")
	var pos_before: Vector3 = server.peers[1]["pos"]
	c.send_move(edoor.x + 3.0, edoor.y, 0.0)
	await create_timer(0.3).timeout
	ok((server.peers[1]["pos"] as Vector3).distance_to(pos_before) < 0.01, "moves are ignored while inside")
	server.cs.accounts["hosty"]["energy"] = 20.0
	ok(await wait_until(func(): return c.energy > 25, 6.0), "energy is restored and reported to the client while resting")
	c.leave_building()
	ok(await wait_until(func(): return c.inside_id == 0, 3.0), "leave succeeds")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout

	print("== blocks, gathering and trade over the local RPC path ==")
	var bdir := OS.get_user_data_dir().path_join("local_test_blocks_%d" % Time.get_ticks_msec())
	server = _start_server(0, bdir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in and not c.inv.is_empty(), 3.0), "login delivers the inventory")
	var ppos: Vector3 = server.peers[1]["pos"]
	var bcell := Vector3i(int(floor(ppos.x)) + 3, maxi(0, int(floor(server.cs.world.height_at(ppos.x + 3.5, ppos.z + 0.5)))), int(floor(ppos.z)))
	var wood0: int = c.item_count("wood")
	c.place_block(bcell, "wood", 3)
	ok(await wait_until(func(): return c.mirror.blocks.has(bcell), 3.0), "placed block arrives on the client mirror")
	ok(c.item_count("wood") == wood0 - 1, "inventory update arrives after placing")
	ok(server.cs.blocks.has(bcell) and server.cs.blocks[bcell][1] == 3, "server holds the block with its colour")
	c.paint_block(bcell, 5)
	ok(await wait_until(func(): return int(c.mirror.blocks[bcell][1]) == 5, 3.0), "paint is broadcast")
	var far := Vector3i(bcell.x + 60, bcell.y, bcell.z)
	c.place_block(far, "wood", 0)
	await create_timer(0.3).timeout
	ok(not server.cs.blocks.has(far), "blocks out of reach are refused by the server")
	var money0: int = c.money
	c.trade("wood", 5, false)
	ok(await wait_until(func(): return c.money > money0, 3.0), "selling materials pays coins")
	ok(c.item_count("wood") == wood0 - 1 - 5, "sold materials leave the bag")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout
	server = _start_server(0, bdir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in and c.mirror.blocks.has(bcell), 3.0), "blocks are sent again after a restart")
	ok(server.cs.blocks.has(bcell), "blocks survive a restart")
	c.remove_block(bcell)
	ok(await wait_until(func(): return not c.mirror.blocks.has(bcell), 3.0), "removing a block is applied")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()

	print("== batch build tools: fill, copy/paste, clear, undo (protocol 20) ==")
	var cdir := OS.get_user_data_dir().path_join("local_test_batch_%d" % Time.get_ticks_msec())
	server = ServerMain.launch(root, {"port": 0, "seed": 777, "data_dir": cdir, "admins": [["hosty", "secret-secret-1"]], "max_seconds": 0.0, "creative": true})
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in and not c.inv.is_empty(), 3.0), "creative login works")
	var pp: Vector3 = server.peers[1]["pos"]
	var o := Vector3i(-999, 0, 0)
	for ddx in range(3, 9):
		for ddz in range(-6, 7):
			var gx := int(floor(pp.x)) + ddx
			var gz := int(floor(pp.z)) + ddz
			var h0: float = server.cs.world.height_at(gx + 0.5, gz + 0.5)
			var lv := maxi(0, int(floor(h0)))
			var good: bool = h0 >= 0.2 and o.x == -999
			for ax in range(3):
				for az in range(3):
					var hh: float = server.cs.world.height_at(gx + ax + 0.5, gz + az + 0.5)
					if hh < 0.2 or maxi(0, int(floor(hh))) != lv or server.cs.check_block("admin", gx + ax, lv, gz + az, "stone") != "":
						good = false
			if good:
				o = Vector3i(gx, lv, gz)
	ok(o.x != -999, "found a flat 3x3 patch near the player")
	var o2 := o + Vector3i(2, 0, 2)
	c.build_region("fill", o, o2, "stone", 2)
	ok(await wait_until(func(): return server.cs.blocks.size() == 9 and c.mirror.blocks.size() == 9, 3.0), "fill: 9 blocks on server and client mirror")
	var clip: PackedInt32Array = c.copy_region(o, o2)
	ok(clip.size() == 45, "copy captures 9 blocks (5 ints each)")
	c.undo_build()
	ok(await wait_until(func(): return server.cs.blocks.is_empty() and c.mirror.blocks.is_empty(), 3.0), "undo removes the fill")
	c.paste_blocks(o, clip)
	ok(await wait_until(func(): return server.cs.blocks.size() == 9 and c.mirror.blocks.size() == 9, 3.0), "paste rebuilds the copy")
	ok(int(server.cs.blocks[o][1]) == 2, "paste keeps block colours")
	c.build_region("clear", o, o2, "", 0)
	ok(await wait_until(func(): return server.cs.blocks.is_empty() and c.mirror.blocks.is_empty(), 3.0), "clear removes the blocks")
	c.undo_build()
	ok(await wait_until(func(): return server.cs.blocks.size() == 9, 3.0), "undo of clear brings them back")
	c.build_region("fill", o, o + Vector3i(40, 0, 0), "stone", 0)
	await create_timer(0.4).timeout
	ok(server.cs.blocks.size() == 9, "oversized region is refused by the server")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout

	print("== tools UI smoke (real GameView + HUD) ==")
	var udir := OS.get_user_data_dir().path_join("local_test_ui_%d" % Time.get_ticks_msec())
	server = _start_server(0, udir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in and not c.inv.is_empty(), 3.0), "ui: login")
	var gv: Node3D = GameViewScript.new()
	root.add_child(gv)
	gv.setup(c, 0)
	var hud_node: Node = HudScript.new()
	root.add_child(hud_node)
	hud_node.setup(c, gv)
	await create_timer(0.3).timeout
	gv.set_tool("hammer")
	gv.set_block_type("stone")
	gv.set_paint_color(4)
	ok(gv.tool == "hammer" and gv.block_type == "stone", "ui: tool selection works")
	var gp: Vector3 = gv.my_pos
	var ucell := Vector3i(int(floor(gp.x)) + 2, maxi(0, int(floor(gv.world.height_at(gp.x + 2.5, gp.z + 0.5)))), int(floor(gp.z)))
	c.place_block(ucell, "stone", 4)
	ok(await wait_until(func(): return c.mirror.blocks.has(ucell), 3.0), "ui: block placed")
	await create_timer(0.5).timeout
	ok(gv.block_view.get_child_count() > 0, "ui: block mesh is built")
	var ray: Dictionary = gv.block_view.raycast(Vector3(ucell.x + 0.5, ucell.y + 5.0, ucell.z + 0.5), Vector3.DOWN)
	ok(ray.get("kind", "") == "block" and ray["hit"] == ucell, "ui: ray hits the block from above")
	gv.set_tool("pickaxe")
	gv._long_press(Vector2(640, 360))
	gv._check_long_press()
	ok(true, "ui: long press and hold check do not crash")
	gv.set_first_person(true)
	await create_timer(0.2).timeout
	ok(gv.cam.first_person and not gv.my_avatar.visible, "ui: first person hides the avatar and moves the camera into the head")
	var eye: Vector3 = gv.cam.camera.global_position
	ok(eye.distance_to(gv.my_pos + Vector3(0, 1.6, 0)) < 0.2, "ui: first-person camera sits at eye height")
	gv.cam.rotate_by(0.0, -0.5)
	ok(gv.cam.fp_pitch > 0.0, "ui: dragging up looks up")
	gv.set_mode("world")
	ok(not gv.cam.first_person and gv.my_avatar.visible, "ui: world mode returns to the normal camera")
	gv.set_mode("life")
	gv.set_first_person(false)
	ok(gv.my_avatar.visible, "ui: third person shows the avatar again")
	gv.set_tool("hand")
	var node_found := false
	for rx in range(-40, 40):
		if node_found:
			break
		for rz in range(-40, 40):
			if not gv.world.resource_in_cell(rx, rz).is_empty():
				gv.streamer.refresh_resource(rx, rz)
				node_found = true
				break
	ok(node_found, "ui: resource refresh does not crash")
	hud_node.queue_free()
	gv.queue_free()
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

	print("== mine over the local RPC path ==")
	var mdir := OS.get_user_data_dir().path_join("local_test_mine_%d" % Time.get_ticks_msec())
	server = _start_server(0, mdir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in and not c.inv.is_empty(), 3.0), "login for the mine test")
	var ents: Array = server.cs.world.mine_entrances()
	ok(ents.size() > 0, "the world has mine entrances")
	var ent: Dictionary = ents[0]
	var mid: String = str(ent["id"])
	c.enter_mine(mid)
	await create_timer(0.3).timeout
	ok(c.mine_id == "", "cannot enter a mine from far away")
	server.peers[1]["pos"] = Vector3(float(ent["x"]) + 2.0, 0.0, float(ent["z"]))
	c.enter_mine(mid)
	ok(await wait_until(func(): return c.mine_id == mid, 3.0), "entering works next to the entrance")
	ok(str(server.peers[1]["mine"]) == mid, "server records that the player is in the mine")
	var lay: Dictionary = server.cs.mine_layout(mid)
	var sp: Vector2 = Mine.spawn_point(lay)
	ok((server.peers[1]["mpos"] as Vector3).distance_to(Vector3(sp.x, 0.0, sp.y)) < 0.01, "player starts at the mine entry tile")
	# شیء بیرونی در معدن کار نمی‌کند
	var out_pos: Vector3 = server.peers[1]["pos"]
	var bcell2 := Vector3i(int(floor(out_pos.x)) + 3, maxi(0, int(floor(server.cs.world.height_at(out_pos.x + 3.5, out_pos.z + 0.5)))), int(floor(out_pos.z)))
	c.place_block(bcell2, "wood", 0)
	await create_timer(0.3).timeout
	ok(not server.cs.blocks.has(bcell2), "surface actions are refused while inside the mine")
	# عبور از دیوار رد می‌شود
	var before_m: Vector3 = server.peers[1]["mpos"]
	c.send_move(0.5, 0.5, 0.0)
	await create_timer(0.3).timeout
	ok((server.peers[1]["mpos"] as Vector3).distance_to(before_m) < 0.01, "walking into rock is refused")
	# نزدیک‌ترین سنگ معمولی را پیدا کن و مسیرش را راه برو
	var target: Dictionary = {}
	for n in lay["nodes"]:
		if n["kind"] != "chest" and (target.is_empty() or int(n["depth"]) < int(target["depth"])):
			target = n
	var path: Array = []
	var cur := Vector2i(int(target["tx"]), int(target["tz"]))
	while int(lay["dist"][Mine.tile_index(cur.x, cur.y)]) > 0:
		path.append(cur)
		var d0: int = int(lay["dist"][Mine.tile_index(cur.x, cur.y)])
		for dd in Mine.DIRS:
			var nb: Vector2i = cur + dd
			if Mine.tile_open(lay, nb.x, nb.y) and int(lay["dist"][Mine.tile_index(nb.x, nb.y)]) == d0 - 1:
				cur = nb
				break
	path.reverse()
	var at := sp
	for tile in path:
		var goal: Vector2 = Mine.tile_center(tile.x, tile.y)
		while at.distance_to(goal) > 0.01:
			at = at.move_toward(goal, 0.5)
			c.send_move(at.x, at.y, 0.0)
			await create_timer(0.07).timeout
	await create_timer(0.2).timeout
	var srv_m: Vector3 = server.peers[1]["mpos"]
	ok(Vector2(srv_m.x, srv_m.z).distance_to(at) < 0.6, "walking the tunnels is accepted by the server (%d tiles)" % path.size())
	var kind_item: String = FWConst.MINE_ORES[str(target["kind"])]["item"]
	var have0: int = c.item_count(kind_item)
	server.cs.accounts["hosty"]["tools"] = {"pickaxe": true}
	c.mine_gather(int(target["idx"]))
	ok(await wait_until(func(): return c.mine_depleted.has(int(target["idx"])), 3.0), "mined ore is reported depleted to the client")
	ok(await wait_until(func(): return c.item_count(kind_item) > have0, 3.0), "mined ore lands in the bag")
	c.mine_gather(int(target["idx"]))
	await create_timer(0.3).timeout
	ok(c.item_count(kind_item) <= have0 + int(target["n"]) + 1, "an empty ore gives nothing more")
	c.leave_mine()
	ok(await wait_until(func(): return c.mine_id == "", 3.0), "leaving the mine works")
	ok(str(server.peers[1]["mine"]) == "", "server clears the mine state")
	ok(Vector2((server.peers[1]["pos"] as Vector3).x, (server.peers[1]["pos"] as Vector3).z).distance_to(Vector2(float(ent["x"]), float(ent["z"]))) < 6.0, "player is back in front of the entrance")
	c.disconnect_from_server()
	server.stop()
	server.queue_free()
	c.queue_free()
	await create_timer(0.3).timeout

	print("== village house over the local RPC path ==")
	var house_dir := OS.get_user_data_dir().path_join("local_test_house_%d" % Time.get_ticks_msec())
	server = _start_server(0, house_dir)
	c = _mk_client()
	c.connect_local(server, "hosty", "secret-secret-1")
	ok(await wait_until(func(): return c.is_logged_in and not c.inv.is_empty(), 3.0), "login for the house test")
	var house_vs: Array = server.cs.world.villages()
	ok(house_vs.size() > 0, "the world has villages")
	var house_h: Dictionary = house_vs[0]["houses"][0]
	var house_id: String = str(house_h["id"])
	ok(server.cs.god.size() > 0, "villages come with animals")
	c.enter_mine(house_id)
	await create_timer(0.3).timeout
	ok(c.mine_id == "", "cannot enter a house from far away")
	server.peers[1]["pos"] = Vector3(float(house_h["ex"]), 0.0, float(house_h["ez"]))
	c.enter_mine(house_id)
	ok(await wait_until(func(): return c.mine_id == house_id, 3.0), "entering a house works at the door")
	var house_lay: Dictionary = server.cs.mine_layout(house_id)
	var house_sp: Vector2 = Mine.spawn_point(house_lay)
	var bed: Dictionary = house_lay["nodes"][0]
	server.cs.accounts["hosty"]["energy"] = 20.0
	var at2 := house_sp
	var bgoal := Vector2(float(bed["x"]), float(bed["z"]) + 1.0)
	while at2.distance_to(bgoal) > 0.01:
		at2 = at2.move_toward(bgoal, 0.5)
		c.send_move(at2.x, at2.y, 0.0)
		await create_timer(0.07).timeout
	c.mine_gather(0)
	ok(await wait_until(func(): return float(server.cs.accounts["hosty"]["energy"]) >= FWConst.ENERGY_MAX - 0.5, 3.0), "sleeping in the bed restores energy")
	c.leave_mine()
	ok(await wait_until(func(): return c.mine_id == "", 3.0), "leaving the house works")
	ok(Vector2((server.peers[1]["pos"] as Vector3).x, (server.peers[1]["pos"] as Vector3).z).distance_to(Vector2(float(house_h["ex"]), float(house_h["ez"]))) < 1.0, "player stands outside the door")
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
