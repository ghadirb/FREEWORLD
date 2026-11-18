extends Control
## صفحهٔ اصلی: نام، آدرس سرور و اتصال.

const Loc = preload("res://scripts/client/loc.gd")
const UiTheme = preload("res://scripts/client/ui_theme.gd")
const Settings = preload("res://scripts/client/settings.gd")
const LanDiscovery = preload("res://scripts/networking/lan_discovery.gd")
const WorldSlots = preload("res://scripts/client/world_slots.gd")

signal connect_requested(host: String, port: int, player_name: String, secret: String)
signal language_toggled
signal solo_requested(player_name: String)
signal host_requested(player_name: String)

var _name: LineEdit
var _host: LineEdit
var _port: LineEdit
var _secret: LineEdit
var _status: Label
var _connect: Button
var _games_box: VBoxContainer
var _discovery: Node
var _worlds: Array = []
var _world_idx: int = 0
var _world_label: Label
var _world_name: LineEdit
var _delete_btn: Button
var _delete_armed: bool = false


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	var bg := ColorRect.new()
	bg.color = Color("12303f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var glow := ColorRect.new()
	glow.color = Color("1f6f8b", 0.35)
	glow.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	glow.custom_minimum_size = Vector2(0, 260)
	add_child(glow)
	# صفحهٔ افقی موبایل: دو ستون تا همه‌چیز بدون اسکرول دیده شود؛ اسکرول لمسی فقط پشتیبان است.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	panel.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(500, 0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(500, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)

	# ---- ستون اول: عنوان، نام، تک‌نفره، میزبان ----
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(icon)
	var title := Label.new()
	title.text = Loc.t("app_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	left.add_child(title)
	var sub := Label.new()
	sub.text = "FREEWORLD"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	left.add_child(sub)
	_name = _field(left, Loc.t("player_name"), str(Settings.get_value("name", "")))
	var solo := UiTheme.button(Loc.t("solo"), Vector2(0, 66))
	solo.add_theme_font_size_override("font_size", 28)
	solo.pressed.connect(func(): _emit_local(solo_requested))
	left.add_child(solo)
	var host_btn := UiTheme.button(Loc.t("host"), Vector2(0, 66))
	host_btn.add_theme_font_size_override("font_size", 26)
	host_btn.pressed.connect(func(): _emit_local(host_requested))
	left.add_child(host_btn)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 52)
	left.add_child(_status)
	_build_world_picker(left)

	# ---- ستون دوم: بازی‌های شبکهٔ محلی، اتصال دستی، زبان ----
	var gt := Label.new()
	gt.text = Loc.t("join_title")
	gt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt.modulate = Color(1, 1, 1, 0.8)
	right.add_child(gt)
	_games_box = VBoxContainer.new()
	_games_box.add_theme_constant_override("separation", 6)
	right.add_child(_games_box)
	var mt := Label.new()
	mt.text = Loc.t("join_manual")
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mt.modulate = Color(1, 1, 1, 0.8)
	right.add_child(mt)
	_host = _field(right, Loc.t("server"), str(Settings.get_value("host", "192.168.")))
	_port = _field(right, Loc.t("port"), str(Settings.get_value("port", 7777)))
	_secret = _field(right, Loc.t("secret"), "")
	_secret.secret = true
	_connect = UiTheme.button(Loc.t("connect"), Vector2(0, 58))
	_connect.add_theme_font_size_override("font_size", 26)
	_connect.pressed.connect(_on_connect)
	right.add_child(_connect)
	var forget := UiTheme.button(Loc.t("forget_certs"), Vector2(0, 44))
	forget.add_theme_font_size_override("font_size", 18)
	forget.pressed.connect(func():
		Settings.clear_pins()
		set_status(Loc.t("certs_forgotten")))
	right.add_child(forget)
	var lang := UiTheme.button(Loc.t("language"), Vector2(0, 50))
	lang.pressed.connect(func(): language_toggled.emit())
	right.add_child(lang)
	_discovery = LanDiscovery.new()
	add_child(_discovery)
	_discovery.games_changed.connect(_refresh_games)
	_discovery.start_listening()
	_refresh_games()


# ---- انتخاب و مدیریت جهان‌های آفلاین ----
func _build_world_picker(parent: Control) -> void:
	_worlds = WorldSlots.load_worlds()
	var cur := WorldSlots.current_id(_worlds)
	_world_idx = 0
	for i in _worlds.size():
		if str(_worlds[i]["id"]) == cur:
			_world_idx = i
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var prev := UiTheme.button("‹", Vector2(56, 50))
	prev.pressed.connect(func(): _select_world(_world_idx - 1))
	row.add_child(prev)
	_world_label = Label.new()
	_world_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_label.clip_text = true
	row.add_child(_world_label)
	var next := UiTheme.button("›", Vector2(56, 50))
	next.pressed.connect(func(): _select_world(_world_idx + 1))
	row.add_child(next)
	_delete_btn = UiTheme.button(Loc.t("world_delete"), Vector2(0, 50))
	_delete_btn.add_theme_font_size_override("font_size", 20)
	_delete_btn.pressed.connect(_on_delete_world)
	row.add_child(_delete_btn)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	parent.add_child(row2)
	_world_name = LineEdit.new()
	_world_name.placeholder_text = Loc.t("world_name_hint")
	_world_name.custom_minimum_size = Vector2(0, 50)
	_world_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_name.max_length = WorldSlots.NAME_MAX
	row2.add_child(_world_name)
	var create := UiTheme.button(Loc.t("world_new"), Vector2(0, 50))
	create.add_theme_font_size_override("font_size", 20)
	create.pressed.connect(_on_create_world)
	row2.add_child(create)
	_refresh_world_label()


func _refresh_world_label() -> void:
	_delete_armed = false
	if _worlds.is_empty():
		_world_label.text = Loc.t("world_none")
		_world_label.add_theme_font_size_override("font_size", 16)
		_delete_btn.disabled = true
		return
	_world_idx = clampi(_world_idx, 0, _worlds.size() - 1)
	_world_label.remove_theme_font_size_override("font_size")
	_world_label.text = "%s %s" % [Loc.t("world_label"), str(_worlds[_world_idx]["name"])]
	_delete_btn.disabled = false
	WorldSlots.set_current(str(_worlds[_world_idx]["id"]))


func _select_world(i: int) -> void:
	if _worlds.is_empty():
		return
	_world_idx = posmod(i, _worlds.size())
	_refresh_world_label()


func _on_create_world() -> void:
	var r := WorldSlots.add_world(_worlds, _world_name.text, randi_range(1, 2147483000))
	if not r["ok"]:
		set_status(Loc.err(str(r["error"])), true)
		return
	WorldSlots.save_worlds(_worlds)
	_world_idx = _worlds.size() - 1
	_world_name.text = ""
	_refresh_world_label()
	set_status(Loc.t("world_created"))


func _on_delete_world() -> void:
	if _worlds.is_empty():
		return
	if not _delete_armed:
		_delete_armed = true
		set_status(Loc.t("world_delete_confirm"), true)
		return
	var w: Dictionary = _worlds[_world_idx]
	WorldSlots.erase_files(w)
	WorldSlots.remove_world(_worlds, str(w["id"]))
	WorldSlots.save_worlds(_worlds)
	_refresh_world_label()
	set_status(Loc.t("world_deleted"))


func _exit_tree() -> void:
	if _discovery != null:
		_discovery.stop()


func _refresh_games() -> void:
	for c in _games_box.get_children():
		c.queue_free()
	if _discovery == null or _discovery.games.is_empty():
		var l := Label.new()
		l.text = Loc.t("no_games")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate = Color(1, 1, 1, 0.5)
		_games_box.add_child(l)
		return
	for ip in _discovery.games:
		var g: Dictionary = _discovery.games[ip]
		var txt := "%s  —  %s/%s %s" % [g["name"], Loc.digits(str(g["players"])), Loc.digits(str(g["max"])), Loc.t("players_count")]
		var b := UiTheme.button(txt, Vector2(0, 58))
		var host_ip: String = ip
		var host_port: int = int(g["port"])
		b.pressed.connect(func(): _join_game(host_ip, host_port))
		_games_box.add_child(b)


func _valid_name() -> String:
	var n := _name.text.strip_edges()
	if n.length() < 3 or n.length() > 16:
		set_status(Loc.err("bad_name"), true)
		return ""
	Settings.set_value("name", n)
	return n


func _emit_local(sig: Signal) -> void:
	var n := _valid_name()
	if n != "":
		sig.emit(n)


func _join_game(ip: String, port: int) -> void:
	var n := _valid_name()
	if n == "":
		return
	set_status(Loc.t("connecting"))
	connect_requested.emit(ip, port, n, "")


func _field(parent: Control, hint: String, text: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = hint
	le.text = text
	le.custom_minimum_size = Vector2(0, 50)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(le)
	return le


func set_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color("ff9a8a") if is_error else Color("d6e4ff"))


func set_busy(busy: bool) -> void:
	_connect.disabled = busy


func prefill(player_name: String, host: String, port: int) -> void:
	_name.text = player_name
	_host.text = host
	_port.text = str(port)


func _on_connect() -> void:
	var n := _name.text.strip_edges()
	var h := _host.text.strip_edges()
	var p := int(_port.text)
	if n.length() < 3 or n.length() > 16:
		set_status(Loc.err("bad_name"), true)
		return
	if h == "" or p <= 0 or p > 65535:
		set_status(Loc.t("connect_failed"), true)
		return
	Settings.set_value("name", n)
	Settings.set_value("host", h)
	Settings.set_value("port", p)
	set_status(Loc.t("connecting"))
	connect_requested.emit(h, p, n, _secret.text)
