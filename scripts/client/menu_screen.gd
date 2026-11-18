extends Control
## صفحهٔ اصلی: نام، آدرس سرور و اتصال.

const Loc = preload("res://scripts/client/loc.gd")
const UiTheme = preload("res://scripts/client/ui_theme.gd")
const Settings = preload("res://scripts/client/settings.gd")

signal connect_requested(host: String, port: int, player_name: String, secret: String)
signal language_toggled

var _name: LineEdit
var _host: LineEdit
var _port: LineEdit
var _secret: LineEdit
var _status: Label
var _connect: Button


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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(560, 0)
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.custom_minimum_size = Vector2(72, 72)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(icon)
	var title := Label.new()
	title.text = Loc.t("app_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "FREEWORLD"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate = Color(1, 1, 1, 0.6)
	v.add_child(sub)
	_name = _field(v, Loc.t("player_name"), str(Settings.get_value("name", "")))
	_host = _field(v, Loc.t("server"), str(Settings.get_value("host", "127.0.0.1")))
	_port = _field(v, Loc.t("port"), str(Settings.get_value("port", 7777)))
	_secret = _field(v, Loc.t("secret"), "")
	_secret.secret = true
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 28)
	v.add_child(_status)
	_connect = UiTheme.button(Loc.t("connect"), Vector2(0, 62))
	_connect.add_theme_font_size_override("font_size", 28)
	_connect.pressed.connect(_on_connect)
	v.add_child(_connect)
	var lang := UiTheme.button(Loc.t("language"), Vector2(0, 50))
	lang.pressed.connect(func(): language_toggled.emit())
	v.add_child(lang)


func _field(parent: Control, hint: String, text: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = hint
	le.text = text
	le.custom_minimum_size = Vector2(0, 54)
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
