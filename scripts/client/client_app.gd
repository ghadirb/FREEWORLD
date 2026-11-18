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

const OFFLINE_DATA_DIR := "user://offline_world"

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
	if _shot_path != "" and not _args.has("connect"):
		_take_shot_later()
	if _args.has("connect"):
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
	var seed_value := int(Settings.get_value("local_seed", 0))
	if seed_value == 0:
		seed_value = randi_range(1, 2147483000)
		Settings.set_value("local_seed", seed_value)
	var cfg := {
		"port": FWConst.DEFAULT_PORT if hosted else 0, "seed": seed_value,
		"data_dir": OFFLINE_DATA_DIR, "admins": [[player_name, admin_secret]], "max_seconds": 0.0,
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
	if _shot_path != "":
		_take_shot_later()


func _take_shot_later() -> void:
	await get_tree().create_timer(float(_args.get("shot-delay", "4"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	print("[shot] saved ", _shot_path, " ", img.get_size())
	get_tree().quit(0)
