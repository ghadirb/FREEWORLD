extends Node
## مدیر برنامهٔ کلاینت: منو -> اتصال -> بازی. قطع ارتباط به منو برمی‌گردد.
## آرگومان‌های آزمایشی: --connect host:port --name N --secret S --shot مسیر.png --shot-delay ثانیه
##   --shot-mode world --build house --quality N

const FWConst = preload("res://scripts/core/const.gd")
const NetScript = preload("res://scripts/networking/net.gd")
const GameClient = preload("res://scripts/networking/game_client.gd")
const Loc = preload("res://scripts/client/loc.gd")
const Settings = preload("res://scripts/client/settings.gd")
const MenuScreen = preload("res://scripts/client/menu_screen.gd")
const GameView = preload("res://scripts/client/game_view.gd")
const Hud = preload("res://scripts/client/hud.gd")
const ServerMain = preload("res://scripts/server/server_main.gd")
const LanDiscovery = preload("res://scripts/networking/lan_discovery.gd")
const WorldSlots = preload("res://scripts/client/world_slots.gd")

var net: Node
var client: Node
var menu: Control
var view: Node3D
var hud: CanvasLayer
var _host: String = ""
var _port: int = 0
var _name: String = ""
var _secret: String = ""
var _args: Dictionary = {}
var _shot_path: String = ""
var _in_game: bool = false
var _hosted_server: Node = null  # سرور داخل برنامه (تک‌نفره یا میزبان)
var _beacon: Node = null  # پخش آدرس بازی در شبکهٔ محلی
var _local: bool = false
var _hosting: bool = false


func _ready() -> void:
	Loc.lang = str(Settings.get_value("lang", "fa"))
	_parse_args()
	get_window().min_size = Vector2i(640, 360)
	net = get_tree().root.get_node_or_null("Net")
	if net == null:
		net = Node.new()
		net.set_script(NetScript)
		net.name = "Net"
		get_tree().root.add_child(net)
	_show_menu()
	if _shot_path != "" and not _args.has("connect") and not _args.has("solo"):
		_take_shot_later()
	if _args.has("solo"):
		_start_local(str(_args["solo"]), false)
	elif _args.has("connect"):
		var parts: PackedStringArray = str(_args["connect"]).split(":")
		_start_connect(parts[0], int(parts[1]) if parts.size() > 1 else FWConst.DEFAULT_PORT, str(_args.get("name", "tester")), str(_args.get("secret", "")))


func _parse_args() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			_args[a[i].substr(2)] = a[i + 1]
			i += 1
		i += 1
	_shot_path = str(_args.get("shot", ""))


func _show_menu(message: String = "", is_error: bool = false) -> void:
	_teardown_game()
	_stop_hosted()
	if menu != null:
		menu.queue_free()
	menu = MenuScreen.new()
	add_child(menu)
	menu.connect_requested.connect(_start_connect)
	menu.solo_requested.connect(func(n): _start_local(n, false))
	menu.host_requested.connect(func(n): _start_local(n, true))
	menu.language_toggled.connect(func():
		Loc.lang = "en" if Loc.lang == "fa" else "fa"
		Settings.set_value("lang", Loc.lang)
		_show_menu())
	if message != "":
		menu.set_status(message, is_error)


func _teardown_game() -> void:
	_in_game = false
	if hud != null:
		hud.queue_free()
		hud = null
	if view != null:
		view.queue_free()
		view = null
	if client != null:
		client.disconnect_from_server()
		client.queue_free()
		client = null


func _make_client() -> void:
	client = Node.new()
	client.set_script(GameClient)
	client.name = "GameClient"
	add_child(client)
	client.setup(net)
	client.logged_in.connect(_on_logged_in)
	client.login_failed.connect(func(e):
		_show_menu(Loc.err(e), true))
	client.connection_failed.connect(func():
		_show_menu(Loc.t("connect_failed"), true))
	client.disconnected.connect(func():
		if _in_game:
			_show_menu(Loc.t("disconnected"), true))


func _start_connect(host: String, port: int, player_name: String, secret: String) -> void:
	_teardown_game()
	_local = false
	_host = host
	_port = port
	_name = player_name
	_secret = secret
	_make_client()
	var token := secret if secret != "" else Settings.token_for(host, port, player_name)
	if client.connect_to(host, port, player_name, token) != OK:
		_show_menu(Loc.t("connect_failed"), true)
		return
	if menu != null:
		menu.set_busy(true)
		menu.set_status(Loc.t("connecting"))
	get_tree().create_timer(10.0).timeout.connect(func():
		if client != null and not client.is_logged_in and not _in_game and menu != null:
			_show_menu(Loc.t("connect_failed"), true))


## تک‌نفره (بدون شبکه) یا میزبان (سرور در همین گوشی + پذیرش بازیکنان روی Wi‑Fi/هات‌اسپات).
func _start_local(player_name: String, hosted: bool) -> void:
	_teardown_game()
	_stop_hosted()
	_local = true
	_hosting = hosted
	_name = player_name
	# رمز مدیریتی این دستگاه: میزبان/بازیکن تک‌نفره مدیر جهان خودش است.
	var admin_secret := str(Settings.get_value("local_secret", ""))
	if admin_secret.length() < 16:
		var crypto := Crypto.new()
		admin_secret = crypto.generate_random_bytes(16).hex_encode()
		Settings.set_value("local_secret", admin_secret)
	_secret = admin_secret
	# جهان انتخاب‌شده در منو؛ اگر هیچ جهانی نیست یکی ساخته می‌شود.
	var worlds := WorldSlots.load_worlds()
	if worlds.is_empty():
		WorldSlots.add_world(worlds, Loc.t("default_world_name"), randi_range(1, 2147483000))
		WorldSlots.save_worlds(worlds)
	var world: Dictionary = WorldSlots.find(worlds, WorldSlots.current_id(worlds))
	if world.is_empty():
		world = worlds[0]
	WorldSlots.set_current(str(world["id"]))
	var seed_value := int(world["seed"])
	var cfg := {
		"port": FWConst.DEFAULT_PORT if hosted else 0, "seed": seed_value, "creative": bool(world.get("creative", false)), "creative_force": true, "scenario": str(world.get("scenario", "")),
		"data_dir": WorldSlots.data_dir(world), "tls_dir": "user://tls", "admins": [[player_name, admin_secret]], "max_seconds": 0.0,
	}
	_hosted_server = ServerMain.launch(self, cfg)
	if _hosted_server == null:
		_hosted_server = null
		_show_menu(Loc.t("host_failed") if hosted else Loc.t("offline_failed"), true)
		return
	if hosted:
		_beacon = LanDiscovery.new()
		add_child(_beacon)
		_beacon.start_broadcasting(_beacon_info())
		_update_beacon_later()
	_make_client()
	client.connect_local(_hosted_server, player_name, admin_secret)
	DisplayServer.screen_set_keep_on(true)


func _beacon_info() -> Dictionary:
	var n := 0
	if _hosted_server != null:
		n = _hosted_server.by_name.size()
	return {"name": _name, "port": FWConst.DEFAULT_PORT, "players": n, "max": FWConst.MAX_PLAYERS}


func _update_beacon_later() -> void:
	while _beacon != null and is_instance_valid(_beacon):
		await get_tree().create_timer(1.0).timeout
		if _beacon != null and is_instance_valid(_beacon):
			_beacon.update_info(_beacon_info())


func _stop_hosted() -> void:
	if _beacon != null:
		_beacon.stop()
		_beacon.queue_free()
		_beacon = null
	if _hosted_server != null:
		_hosted_server.stop()
		_hosted_server.queue_free()
		_hosted_server = null
	_hosting = false
	DisplayServer.screen_set_keep_on(false)


func _host_info_text() -> String:
	if not _hosting:
		return ""
	var ips := LanDiscovery.local_ipv4()
	var lines: Array = [Loc.t("host_started")]
	for ip in ips:
		lines.append("%s:%d" % [ip, FWConst.DEFAULT_PORT])
	lines.append(Loc.t("host_keep_open"))
	return "\n".join(lines)


func _on_logged_in() -> void:
	if client.token != "" and _secret == "" and not _local:
		Settings.save_token(_host, _port, _name, client.token)
	_in_game = true
	if menu != null:
		menu.queue_free()
		menu = null
	var q := int(_args.get("quality", Settings.get_value("quality", Settings.default_quality())))
	view = GameView.new()
	view.name = "GameView"
	add_child(view)
	view.setup(client, q)
	hud = Hud.new()
	hud.host_info = _host_info_text()
	add_child(hud)
	hud.setup(client, view)
	hud.disconnect_requested.connect(func(): _show_menu())
	hud.quality_changed.connect(func(nq):
		Settings.set_value("quality", nq)
		view.apply_quality(nq))
	hud.language_changed.connect(func():
		Settings.set_value("lang", Loc.lang)
		_teardown_game()
		if _local:
			_make_client()
			client.connect_local(_hosted_server, _name, _secret)
		else:
			_start_connect(_host, _port, _name, _secret))
	if _args.get("shot-mode", "") == "world":
		view.set_mode("world")
	if _args.has("build"):
		hud._toggle_build()
		hud._select_type(str(_args["build"]))
	if _args.has("ride"):
		# آزمایشی: فقط برای عکس، مدل اسب/قایق را زیر شخصیت نشان می‌دهد
		view.my_avatar.set_horse(str(_args["ride"]) == "horse")
		view.my_avatar.set_car(str(_args["ride"]) == "car")
		view.my_avatar.set_boat(str(_args["ride"]) == "boat")
	if _args.has("panel"):
		hud.debug_open_panel(str(_args["panel"]))
	if _args.has("enter") and client.local_server != null:
		_debug_enter(str(_args["enter"]))
	if _args.has("mine") and client.local_server != null:
		_debug_mine(str(_args["mine"]))
	elif _args.has("village"):
		_debug_village(str(_args["village"]))
	if _shot_path != "":
		_take_shot_later()


## آزمایشی (--enter house): ساختمان می‌سازد و وارد آن می‌شود تا داخلش در CI عکس گرفته شود.
func _debug_enter(type: String) -> void:
	var spot := Vector2i(-1, -1)
	for cx in range(4, 28):
		for cz in range(4, 28):
			if client.preview_error(type, cx, cz) == "":
				spot = Vector2i(cx, cz)
				break
		if spot.x >= 0:
			break
	if spot.x < 0:
		return
	client.place(type, spot.x, spot.y)
	var srv = client.local_server
	var t0 := Time.get_ticks_msec()
	while srv.cs.buildings.is_empty() and Time.get_ticks_msec() - t0 < 3000:
		await get_tree().create_timer(0.1).timeout
	if srv.cs.buildings.is_empty():
		return
	var id: int = srv.cs.buildings.keys()[0]
	var d: Vector2 = srv.cs.door_point(srv.cs.buildings[id])
	srv.peers[1]["pos"] = Vector3(d.x, 0.0, d.y)
	client.enter_building(id)


## آزمایشی (--mine surface|inside|deep): جلوی ورودی معدن می‌رود، وارد می‌شود یا کنار سنگ ارزشمند می‌ایستد.
func _debug_mine(mode: String) -> void:
	var srv = client.local_server
	var ents: Array = srv.cs.world.mine_entrances()
	if ents.is_empty():
		return
	var e: Dictionary = ents[0]
	await get_tree().create_timer(0.5).timeout
	var out := Vector2(float(e["x"]), float(e["z"])) + Vector2(sin(float(e["yaw"])), cos(float(e["yaw"]))) * (10.0 if mode == "surface" else 3.5)
	srv.peers[1]["pos"] = Vector3(out.x, 0.0, out.y)
	srv._send(1, "s2c_teleport", out.x, out.y)
	if mode == "surface":
		view.cam.yaw = float(e["yaw"])
		return
	await get_tree().create_timer(0.4).timeout
	client.enter_mine(str(e["id"]))
	if mode != "deep":
		return
	await get_tree().create_timer(0.6).timeout
	var lay: Dictionary = srv.cs.mine_layout(str(e["id"]))
	var pick: Dictionary = {}
	for n in lay["nodes"]:
		if n["kind"] == "gem" or n["kind"] == "gold":
			pick = n
			break
	if pick.is_empty():
		return
	var c := Vector2((float(pick["tx"]) + 0.5) * FWConst.MINE_TILE, (float(pick["tz"]) + 0.5) * FWConst.MINE_TILE)
	srv.peers[1]["mpos"] = Vector3(c.x, 0.0, c.y)
	srv._send(1, "s2c_teleport", c.x, c.y)


## آزمایشی (--village surface|inside): جلوی نخستین خانهٔ روستا می‌رود یا وارد آن می‌شود.
func _debug_village(mode: String) -> void:
	var srv = client.local_server
	var vs: Array = srv.cs.world.villages()
	if vs.is_empty():
		return
	var h: Dictionary = vs[0]["houses"][0]
	await get_tree().create_timer(0.5).timeout
	var out := Vector2(float(h["x"]), float(h["z"])) + Vector2(sin(float(h["yaw"])), cos(float(h["yaw"]))) * (9.0 if mode == "surface" else 3.0)
	srv.peers[1]["pos"] = Vector3(out.x, 0.0, out.y)
	srv._send(1, "s2c_teleport", out.x, out.y)
	if mode == "surface":
		view.cam.yaw = float(h["yaw"])
		return
	await get_tree().create_timer(0.4).timeout
	client.enter_mine(str(h["id"]))


func _take_shot_later() -> void:
	await get_tree().create_timer(float(_args.get("shot-delay", "4"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("[shot] saved ", _shot_path, " ", img.get_size())
	get_tree().quit(0)
