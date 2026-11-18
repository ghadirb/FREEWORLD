extends CanvasLayer
## رابط درون‌بازی: نوار بالا، دکمه‌ها، پالت ساخت، پنل ساختمان، چت، پنل مدیر، منو و جوی‌استیک.

const FWConst = preload("res://scripts/core/const.gd")
const Loc = preload("res://scripts/client/loc.gd")
const Sfx = preload("res://scripts/client/sfx.gd")
const UiTheme = preload("res://scripts/client/ui_theme.gd")

signal disconnect_requested
signal quality_changed(q: int)
signal language_changed

const TYPES := ["house", "shop", "farm", "bakery", "road", "well"]

var client
var view
var root: Control
var _interactive: Array = []

var _money: Label
var _clock: Label
var _price: Label
var _online: Label
var _role: Label
var _mode_btn: Button
var _build_btn: Button
var _admin_btn: Button
var _palette: PanelContainer
var _hint: Label
var _type_btns: Dictionary = {}
var _confirm_btn: Button
var _info: PanelContainer
var _info_title: Label
var _info_body: Label
var _info_collect: Button
var _info_demolish: Button
var _info_id: int = -1
var _toasts: VBoxContainer
var _chat_log: RichTextLabel
var _chat_row: PanelContainer
var _chat_input: LineEdit
var _admin_panel: PanelContainer
var _admin_target: LineEdit
var _admin_log: RichTextLabel
var _menu_panel: PanelContainer
var host_info: String = ""  # آدرس میزبان برای نمایش به بازیکنان دیگر
var _stat_acc: float = 0.0
var _chat_lines: Array = []
var _joy_draw: Control


class JoystickDraw extends Control:
	var view

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if view == null or view.mode != "life":
			return
		var base: Vector2 = view.joy_origin if view.joy_active else Vector2(size.x * 0.14, size.y * 0.8)
		var a := 0.5 if view.joy_active else 0.18
		draw_circle(base, 70.0, Color(1, 1, 1, a * 0.35))
		draw_arc(base, 70.0, 0.0, TAU, 40, Color(1, 1, 1, a), 3.0)
		var knob: Vector2 = base + view.joy * 60.0
		draw_circle(knob, 30.0, Color(1, 1, 1, a + 0.15))


func setup(game_client, game_view) -> void:
	client = game_client
	view = game_view
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	_joy_draw = JoystickDraw.new()
	_joy_draw.view = view
	_joy_draw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_joy_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_joy_draw)
	_build_top_bar()
	_build_side_buttons()
	_build_palette()
	_build_info_panel()
	_build_toasts()
	_build_chat()
	_build_admin_panel()
	_build_menu_panel()
	view.is_over_ui = Callable(self, "is_over_ui")
	view.building_tapped.connect(_on_building_tapped)
	view.ghost_changed.connect(_on_ghost_changed)
	view.mode_changed.connect(_on_mode_changed)
	client.money_changed.connect(func(_m): _refresh_stats())
	client.notice.connect(_on_notice)
	client.chat_received.connect(_on_chat)
	client.role_changed.connect(func(_r): _refresh_role())
	client.player_joined.connect(func(n): toast(Loc.fmt("msg_joined", [n])); Sfx.play(self, "notify"))
	client.player_left.connect(func(n): toast(Loc.fmt("msg_left", [n])))
	client.audit_received.connect(_on_audit)
	root.resized.connect(_layout)
	_layout()
	_refresh_stats()
	_refresh_role()


func _layout() -> void:
	var s: Vector2 = root.size
	view.joy_zone = Rect2(0, s.y * 0.4, s.x * 0.45, s.y * 0.6)


func is_over_ui(p: Vector2) -> bool:
	for c in _interactive:
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


func _place(c: Control, ax: float, ay: float, mx: float = 12.0, my: float = 12.0) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.grow_horizontal = Control.GROW_DIRECTION_END if ax < 0.25 else (Control.GROW_DIRECTION_BEGIN if ax > 0.75 else Control.GROW_DIRECTION_BOTH)
	c.grow_vertical = Control.GROW_DIRECTION_END if ay < 0.25 else (Control.GROW_DIRECTION_BEGIN if ay > 0.75 else Control.GROW_DIRECTION_BOTH)
	var ox := mx if ax < 0.25 else (-mx if ax > 0.75 else 0.0)
	var oy := my if ay < 0.25 else (-my if ay > 0.75 else 0.0)
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy


func _panel(ax: float, ay: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	root.add_child(p)
	_place(p, ax, ay)
	_interactive.append(p)
	return p


func _label(text: String, size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------- ساخت اجزا ----------------

func _build_top_bar() -> void:
	var p := _panel(0.0, 0.0)
	p.anchor_right = 1.0
	p.offset_left = 12
	p.offset_right = -12
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	_money = _label("", 26, Color("ffd24a"))
	_clock = _label("", 24)
	_price = _label("", 22, Color("c8f08a"))
	_online = _label("", 22)
	_role = _label("", 20, Color("9ad0ff"))
	for l in [_money, _clock, _price, _online, _role]:
		h.add_child(l)


func _build_side_buttons() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	_place(v, 1.0, 0.5)
	v.offset_top += 20
	v.offset_bottom += 20
	_mode_btn = UiTheme.button("", Vector2(180, 68))
	_mode_btn.pressed.connect(func(): Sfx.play(self, "click"); view.toggle_mode())
	_build_btn = UiTheme.button(Loc.t("build"), Vector2(180, 68))
	_build_btn.pressed.connect(_toggle_build)
	var chat_btn := UiTheme.button(Loc.t("chat"), Vector2(180, 68))
	chat_btn.pressed.connect(_toggle_chat)
	_admin_btn = UiTheme.button(Loc.t("admin"), Vector2(180, 68))
	_admin_btn.pressed.connect(func(): _admin_panel.visible = not _admin_panel.visible)
	var menu_btn := UiTheme.button(Loc.t("menu"), Vector2(180, 68))
	menu_btn.pressed.connect(func(): _menu_panel.visible = not _menu_panel.visible)
	for b in [_mode_btn, _build_btn, chat_btn, _admin_btn, menu_btn]:
		v.add_child(b)
		_interactive.append(b)
	_update_mode_btn()


func _build_palette() -> void:
	_palette = _panel(0.5, 1.0)
	_palette.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_palette.add_child(v)
	_hint = _label(Loc.t("tap_to_place"), 22, Color("d6e4ff"))
	v.add_child(_hint)
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for t in TYPES:
		var cost := int(FWConst.BUILDING_TYPES[t]["cost"])
		var b := UiTheme.button("%s\n%s" % [Loc.t("type_" + t), Loc.digits(str(cost))], Vector2(120, 84))
		b.add_theme_font_size_override("font_size", 22)
		b.toggle_mode = true
		b.pressed.connect(func(): _select_type(t))
		row.add_child(b)
		_type_btns[t] = b
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	v.add_child(row2)
	_confirm_btn = UiTheme.button("✓ " + Loc.t("confirm"), Vector2(0, 64))
	_confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_btn.pressed.connect(func(): view.confirm_build())
	var cancel := UiTheme.button("✕ " + Loc.t("cancel"), Vector2(0, 64))
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_toggle_build)
	row2.add_child(_confirm_btn)
	row2.add_child(cancel)


func _build_info_panel() -> void:
	_info = _panel(0.5, 1.0)
	_info.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_info.add_child(v)
	_info_title = _label("", 28, Color("ffd24a"))
	_info_body = _label("", 22)
	v.add_child(_info_title)
	v.add_child(_info_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_info_collect = UiTheme.button(Loc.t("collect"), Vector2(190, 64))
	_info_collect.pressed.connect(func(): client.collect(_info_id))
	_info_demolish = UiTheme.button(Loc.t("demolish"), Vector2(150, 64))
	_info_demolish.pressed.connect(func(): client.remove(_info_id); _info.visible = false)
	var close := UiTheme.button("✕", Vector2(64, 64))
	close.pressed.connect(func(): _info.visible = false)
	row.add_child(_info_collect)
	row.add_child(_info_demolish)
	row.add_child(close)


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	_place(_toasts, 0.5, 0.0, 0.0, 90.0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN


func _build_chat() -> void:
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = true
	_chat_log.scroll_active = false
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.custom_minimum_size = Vector2(420, 0)
	_chat_log.add_theme_font_size_override("normal_font_size", 22)
	_chat_log.add_theme_constant_override("outline_size", 6)
	_chat_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(_chat_log)
	_place(_chat_log, 0.0, 0.0, 12.0, 96.0)
	_chat_row = _panel(0.5, 1.0)
	_chat_row.visible = false
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_chat_row.add_child(h)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = Loc.t("chat_hint")
	_chat_input.custom_minimum_size = Vector2(480, 60)
	_chat_input.max_length = FWConst.CHAT_MAX
	_chat_input.text_submitted.connect(func(_t): _send_chat())
	var send := UiTheme.button(Loc.t("send"), Vector2(120, 60))
	send.pressed.connect(_send_chat)
	h.add_child(_chat_input)
	h.add_child(send)


func _build_admin_panel() -> void:
	_admin_panel = _panel(0.5, 0.5)
	_admin_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(520, 0)
	_admin_panel.add_child(v)
	v.add_child(_label(Loc.t("admin"), 30, Color("ffd24a")))
	_admin_target = LineEdit.new()
	_admin_target.placeholder_text = Loc.t("target_name")
	_admin_target.custom_minimum_size = Vector2(0, 58)
	v.add_child(_admin_target)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for r in FWConst.ROLES:
		var b := UiTheme.button(Loc.role_name(r), Vector2(0, 60))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): client.set_role(_admin_target.text.strip_edges(), r))
		row.add_child(b)
	var audit := UiTheme.button(Loc.t("audit"), Vector2(0, 60))
	audit.pressed.connect(func(): client.request_audit())
	v.add_child(audit)
	_admin_log = RichTextLabel.new()
	_admin_log.custom_minimum_size = Vector2(0, 220)
	_admin_log.add_theme_font_size_override("normal_font_size", 18)
	v.add_child(_admin_log)
	var close := UiTheme.button(Loc.t("back"), Vector2(0, 56))
	close.pressed.connect(func(): _admin_panel.visible = false)
	v.add_child(close)


func _build_menu_panel() -> void:
	_menu_panel = _panel(0.5, 0.5)
	_menu_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(440, 0)
	_menu_panel.add_child(v)
	v.add_child(_label(Loc.t("menu"), 30, Color("ffd24a")))
	if host_info != "":
		var hl := _label(host_info, 22, Color("9be3a0"))
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hl)
	var lang := UiTheme.button(Loc.t("language"), Vector2(0, 60))
	lang.pressed.connect(func():
		Loc.lang = "en" if Loc.lang == "fa" else "fa"
		language_changed.emit())
	v.add_child(lang)
	v.add_child(_label(Loc.t("quality"), 22))
	var q := HBoxContainer.new()
	q.add_theme_constant_override("separation", 8)
	v.add_child(q)
	for i in range(3):
		var b := UiTheme.button(Loc.t(["q_low", "q_med", "q_high"][i]), Vector2(0, 56))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): quality_changed.emit(i))
		q.add_child(b)
	var snd := UiTheme.button("♪", Vector2(0, 56))
	snd.pressed.connect(func(): Sfx.enabled = not Sfx.enabled)
	v.add_child(snd)
	var dc := UiTheme.button(Loc.t("disconnect"), Vector2(0, 60))
	dc.pressed.connect(func(): disconnect_requested.emit())
	v.add_child(dc)
	var close := UiTheme.button(Loc.t("back"), Vector2(0, 56))
	close.pressed.connect(func(): _menu_panel.visible = false)
	v.add_child(close)


# ---------------- رفتار ----------------

func toast(text: String, color: Color = Color.WHITE) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, 24, color)
	p.add_child(l)
	_toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		break


func _on_notice(code: String, args: Dictionary) -> void:
	match code:
		"collected":
			Sfx.play(self, "coin")
			var msg_key := "msg_collected_bread" if str(args.get("good", "wheat")) == "bread" else "msg_collected"
			toast(Loc.fmt(msg_key, [Loc.digits(str(args["count"])), Loc.digits(str(args["earned"]))]), Color("c8f08a"))
		"role_set":
			toast(Loc.fmt("msg_role_set", [args["target"], Loc.role_name(str(args["role"]))]))
		"your_building_removed":
			toast(Loc.fmt("msg_your_building_removed", [args["by"]]), Color("ff9a8a"))
		_:
			Sfx.play(self, "error")
			toast(Loc.err(code), Color("ff9a8a"))


func _refresh_stats() -> void:
	_money.text = "%s %s" % [Loc.digits(str(client.money)), Loc.t("coins")]
	_clock.text = Loc.clock(client.world_time)
	_price.text = "%s: %s  |  %s: %s" % [Loc.t("wheat_price"), Loc.digits("%.1f" % client.wheat_price),
		Loc.t("bread_price"), Loc.digits("%.1f" % client.bread_price)]
	_online.text = "%s: %s" % [Loc.t("online"), Loc.digits(str(client.players.size()))]
	if _info.visible and _info_id >= 0:
		_fill_info(_info_id)


func _refresh_role() -> void:
	_role.text = Loc.role_name(client.role)
	_admin_btn.visible = FWConst.is_admin(client.role)


func _process(delta: float) -> void:
	_stat_acc += delta
	if _stat_acc > 0.4:
		_stat_acc = 0.0
		_refresh_stats()


func _update_mode_btn() -> void:
	_mode_btn.text = Loc.t("world_mode") if view.mode == "life" else Loc.t("life_mode")


func _on_mode_changed(_m: String) -> void:
	_update_mode_btn()
	if view.mode == "world":
		toast(Loc.t("world_mode"))
	else:
		toast(Loc.t("life_mode"))


func _toggle_build() -> void:
	Sfx.play(self, "click")
	var on := not _palette.visible
	_palette.visible = on
	_info.visible = false
	if on:
		_select_type("house")
	else:
		view.set_build_type("")


func _select_type(t: String) -> void:
	Sfx.play(self, "click")
	for k in _type_btns:
		_type_btns[k].button_pressed = (k == t)
	view.set_build_type(t)


func _on_ghost_changed(err: String) -> void:
	if view.build_type == "":
		return
	if view.ghost_cell.x < 0:
		_hint.text = Loc.t("tap_to_place")
		_hint.add_theme_color_override("font_color", Color("d6e4ff"))
	elif err == "":
		_hint.text = "✓ " + Loc.t("ghost_ok")
		_hint.add_theme_color_override("font_color", Color("a8f0a0"))
	else:
		_hint.text = Loc.err(err)
		_hint.add_theme_color_override("font_color", Color("ff9a8a"))
	_confirm_btn.disabled = (view.ghost_cell.x < 0 or err != "")


func _on_building_tapped(id: int) -> void:
	if id < 0 or not client.mirror.buildings.has(id):
		_info.visible = false
		return
	_info_id = id
	_fill_info(id)
	_info.visible = true


func _fill_info(id: int) -> void:
	if not client.mirror.buildings.has(id):
		_info.visible = false
		return
	var b: Dictionary = client.mirror.buildings[id]
	_info_title.text = Loc.t("type_" + str(b["type"]))
	var body := "%s: %s" % [Loc.t("owner"), b["owner"]]
	if b["type"] == "farm" or b["type"] == "bakery":
		body += "\n%s: %s" % [Loc.t("stock"), Loc.digits(str(int(b["stock"])))]
	if b["type"] == "bakery":
		body += "\n%s: %s" % [Loc.t("market_wheat"), Loc.digits(str(int(client.market_stock["wheat"])))]
	_info_body.text = body
	var mine: bool = b["owner"] == client.my_name
	_info_collect.visible = mine and (b["type"] == "farm" or b["type"] == "bakery")
	_info_demolish.visible = mine or FWConst.is_admin(client.role)


func _toggle_chat() -> void:
	Sfx.play(self, "click")
	_chat_row.visible = not _chat_row.visible
	if _chat_row.visible:
		_chat_input.grab_focus()


func _send_chat() -> void:
	var t := _chat_input.text.strip_edges()
	if t != "":
		client.send_chat(t)
	_chat_input.text = ""
	_chat_input.release_focus()
	_chat_row.visible = false


func _on_chat(from_name: String, text: String) -> void:
	var color := "ffd24a" if from_name == client.my_name else "9ad0ff"
	_chat_lines.append("[color=#%s]%s:[/color] %s" % [color, from_name, text.replace("[", "［")])
	while _chat_lines.size() > 6:
		_chat_lines.pop_front()
	_chat_log.text = ""
	_chat_log.append_text("\n".join(_chat_lines))
	if from_name != client.my_name:
		Sfx.play(self, "notify")


func _on_audit(entries: Array) -> void:
	var lines: Array = []
	for e in entries:
		lines.append("#%d %s → %s %s" % [int(e["n"]), e["actor"], e["action"], JSON.stringify(e["detail"])])
	_admin_log.text = ""
	_admin_log.append_text("\n".join(lines))
