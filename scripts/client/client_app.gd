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
	if menu != null:
		menu.queue_free()
	menu = MenuScreen.new()
	add_child(menu)
	menu.connect_requested.connect(_start_connect)
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


func _start_connect(host: String, port: int, player_name: String, secret: String) -> void:
	_teardown_game()
	_host = host
	_port = port
	_name = player_name
	_secret = secret
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


func _on_logged_in() -> void:
	if client.token != "" and _secret == "":
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
	add_child(hud)
	hud.setup(client, view)
	hud.disconnect_requested.connect(func(): _show_menu())
	hud.quality_changed.connect(func(nq):
		Settings.set_value("quality", nq)
		view.apply_quality(nq))
	hud.language_changed.connect(func():
		Settings.set_value("lang", Loc.lang)
		_teardown_game()
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
