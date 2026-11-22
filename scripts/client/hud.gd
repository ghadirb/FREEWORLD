extends CanvasLayer
## رابط درون‌بازی: نوار بالا، دکمه‌ها، پالت ساخت، پنل ساختمان، چت، پنل مدیر، منو و جوی‌استیک.

const FWConst = preload("res://scripts/core/const.gd")
const Loc = preload("res://scripts/client/loc.gd")
const Sfx = preload("res://scripts/client/sfx.gd")
const BlockView = preload("res://scripts/client/block_view.gd")
const UiTheme = preload("res://scripts/client/ui_theme.gd")

signal disconnect_requested
signal quality_changed(q: int)
signal language_changed

const TYPES := ["house", "shop", "farm", "coop", "barn", "mill", "dairy", "bakery", "road", "well"]

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
var _info_enter: Button
var _leave_btn: Button
var _mine_btn: Button
var _mine_acc: float = 0.0
var _info_demolish: Button
var _info_job: Button
var _info_id: int = -1
var _toasts: VBoxContainer
var _chat_log: RichTextLabel
var _chat_row: PanelContainer
var _chat_input: LineEdit
var _admin_panel: PanelContainer
var _admin_target: LineEdit
var _admin_log: RichTextLabel
var _menu_panel: PanelContainer
var _tools_btn: Button
var _view_btn: Button
var _inv_btn: Button
var _tools_panel: PanelContainer
var _hint_panel: PanelContainer
var _tool_btns: Dictionary = {}
var _tool_hint: Label
var _block_box: VBoxContainer
var _mode_btns: Dictionary = {}
var _block_btns: Dictionary = {}
var _color_row: HBoxContainer
var _color_btns: Array = []
var _inv_panel: PanelContainer
var _inv_rows: Dictionary = {}
var _god_panel: PanelContainer
var _god_btn: Button
var _mg_btn: Button
var _mg_panel: PanelContainer
var _mg_status: Label
var _mg_board: Label
var _mg_best: Label
var _mg_bar: Label
var _was_disaster: bool = false
var _race_btn: Button
var _fly_btn: Button
var _boat_btn: Button
var _fish_btn: Button
var _horse_btn: Button
var _car_btn: Button
var _shop_btn: Button
var _side_scroll: ScrollContainer
var _drawers: Array = []
var _race_title: Label
var _race_start_btn: Button
var _forest_btn: Button
var _fly_pad: HBoxContainer
var _race_panel: PanelContainer
var _race_best: Label
var _race_board: Label
var _race_bar: Label
var _god_btns: Dictionary = {}
var _npc_panel: PanelContainer
var _npc_title: Label
var _npc_body: Label
var _npc_item: OptionButton
var _npc_id: int = -1
var _offer_panel: PanelContainer
var _offer_label: Label
var _offer_queue: Array = []
var _offer_player: OptionButton
var _offer_item: OptionButton
var _offer_count: SpinBox
var _offer_price: SpinBox
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
	_build_tools_panel()
	_build_inventory_panel()
	_build_offer_panel()
	_build_info_panel()
	_build_npc_panel()
	_build_furn_panel()
	_build_bp_panel()
	_build_god_panel()
	_build_minigame()
	_build_race()
	_build_leave_button()
	_build_toasts()
	_build_chat()
	_build_admin_panel()
	_build_menu_panel()
	for dp in [_palette, _tools_panel, _inv_panel, _offer_panel, _npc_panel, _furn_panel, _bp_panel, _god_panel, _mg_panel, _race_panel, _admin_panel, _menu_panel]:
		_dock(dp)
	view.is_over_ui = Callable(self, "is_over_ui")
	view.building_tapped.connect(_on_building_tapped)
	view.npc_tapped.connect(_on_npc_tapped)
	client.inventory_changed.connect(_fill_npc)
	view.ghost_changed.connect(_on_ghost_changed)
	view.mode_changed.connect(_on_mode_changed)
	view.tool_changed.connect(_refresh_tools)
	view.perspective_changed.connect(_update_view_btn)
	_update_view_btn()
	client.offer_received.connect(_on_offer)
	client.inventory_changed.connect(func():
		_refresh_inventory()
		_refresh_tools())
	client.money_changed.connect(func(_m): _refresh_stats())
	client.notice.connect(_on_notice)
	client.blueprints_changed.connect(_fill_bp_list)
	client.blueprint_loaded.connect(_on_bp_loaded)
	client.inside_changed.connect(_on_inside_changed)
	client.mine_changed.connect(_on_mine_changed)
	client.energy_changed.connect(_refresh_stats)
	client.job_changed.connect(func(): if _info.visible and _info_id >= 0: _fill_info(_info_id))
	client.chat_received.connect(_on_chat)
	client.role_changed.connect(func(_r): _refresh_role())
	client.player_joined.connect(func(n): toast(Loc.fmt("msg_joined", [n])); Sfx.play(self, "notify"))
	client.player_left.connect(func(n): toast(Loc.fmt("msg_left", [n])))
	client.audit_received.connect(_on_audit)
	root.resized.connect(_layout)
	_layout()
	_refresh_stats()
	_refresh_role()
	_refresh_inventory()
	_refresh_tools()


func _layout() -> void:
	var s: Vector2 = root.size
	view.joy_zone = Rect2(0, s.y * 0.4, s.x * 0.45, s.y * 0.6)
	_refit_drawers()


## پنل بزرگ را کنار ستون دکمه‌ها (سمت راست، زیر نوار بالا) می‌چسباند و در صورت بلند بودن اسکرول می‌دهد؛
## وسط صفحه و جوی‌استیک آزاد می‌مانند.
func _dock(p: PanelContainer) -> void:
	var kids := p.get_children()
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var wrap := VBoxContainer.new()
	wrap.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	for k in kids:
		p.remove_child(k)
		wrap.add_child(k)
	sc.add_child(wrap)
	p.add_child(sc)
	p.layout_direction = Control.LAYOUT_DIRECTION_LTR
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_END
	p.offset_right = -(SIDE_W + 24.0)
	p.offset_left = p.offset_right
	p.offset_top = TOP_H
	p.offset_bottom = TOP_H
	_drawers.append({"panel": p, "scroll": sc, "wrap": wrap})
	wrap.minimum_size_changed.connect(_refit_drawers)
	p.visibility_changed.connect(_refit_drawers)


func _refit_drawers() -> void:
	if root == null:
		return
	var avail: float = maxf(160.0, root.size.y - TOP_H - 12.0)
	var max_w: float = maxf(200.0, root.size.x - SIDE_W - 48.0)
	for d in _drawers:
		var sc: ScrollContainer = d["scroll"]
		var wrap: Control = d["wrap"]
		if not is_instance_valid(sc) or not is_instance_valid(wrap):
			continue
		var m: Vector2 = wrap.get_combined_minimum_size()
		sc.custom_minimum_size = Vector2(minf(minf(m.x + 14.0, max_w), 440.0), minf(m.y, avail))


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
	# در حالت راست‌به‌چپ (فارسی) Godot مستطیل پنل را آینه می‌کند؛ لنگر را برعکس می‌دهیم تا جای دیداری درست بماند.
	_place(p, (1.0 - ax) if Loc.lang == "fa" else ax, ay)
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
	p.anchor_left = 0.0
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


const SIDE_BTN := Vector2(150, 50)
const SIDE_W := 2.0 * 150.0 + 8.0 + 14.0   # دو ستون + فاصله + نوار اسکرول
const TOP_H := 84.0


func _build_side_buttons() -> void:
	# دکمه‌ها دو ستونه زیر نوار بالا و قابل اسکرول‌اند تا هیچ‌وقت از صفحه بیرون نزنند یا روی هم نیفتند.
	_side_scroll = ScrollContainer.new()
	_side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_side_scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	root.add_child(_side_scroll)
	_side_scroll.anchor_left = 1.0
	_side_scroll.anchor_right = 1.0
	_side_scroll.anchor_top = 0.0
	_side_scroll.anchor_bottom = 1.0
	_side_scroll.offset_left = -(SIDE_W + 12.0)
	_side_scroll.offset_right = -12.0
	_side_scroll.offset_top = TOP_H
	_side_scroll.offset_bottom = -12.0
	_interactive.append(_side_scroll)
	var v := GridContainer.new()
	v.columns = 2
	v.add_theme_constant_override("h_separation", 8)
	v.add_theme_constant_override("v_separation", 8)
	_side_scroll.add_child(v)
	_mode_btn = UiTheme.button("", SIDE_BTN)
	_mode_btn.pressed.connect(func(): Sfx.play(self, "click"); view.toggle_mode())
	_build_btn = UiTheme.button(Loc.t("build"), SIDE_BTN)
	_build_btn.pressed.connect(_toggle_build)
	_view_btn = UiTheme.button("", SIDE_BTN)
	_view_btn.pressed.connect(func():
		Sfx.play(self, "click")
		view.set_first_person(not view.first_person))
	_tools_btn = UiTheme.button(Loc.t("tools"), SIDE_BTN)
	_tools_btn.pressed.connect(_toggle_tools)
	_inv_btn = UiTheme.button(Loc.t("inventory"), SIDE_BTN)
	_inv_btn.pressed.connect(func():
		Sfx.play(self, "click")
		_inv_panel.visible = not _inv_panel.visible
		_refresh_offer_players())
	var chat_btn := UiTheme.button(Loc.t("chat"), SIDE_BTN)
	chat_btn.pressed.connect(_toggle_chat)
	_admin_btn = UiTheme.button(Loc.t("admin"), SIDE_BTN)
	_admin_btn.pressed.connect(func():
		_admin_panel.visible = not _admin_panel.visible
		if _forest_btn != null:
			_forest_btn.button_pressed = client.forest_growth)
	var menu_btn := UiTheme.button(Loc.t("menu"), SIDE_BTN)
	menu_btn.pressed.connect(func(): _menu_panel.visible = not _menu_panel.visible)
	_god_btn = UiTheme.button(Loc.t("god_tools"), SIDE_BTN)
	_god_btn.pressed.connect(_toggle_god)
	_mg_btn = UiTheme.button(Loc.t("minigame"), SIDE_BTN)
	_mg_btn.pressed.connect(func(): Sfx.play(self, "click"); _mg_panel.visible = not _mg_panel.visible; _refresh_minigame())
	_race_btn = UiTheme.button(Loc.t("race"), SIDE_BTN)
	_race_btn.pressed.connect(func(): Sfx.play(self, "click"); _race_panel.visible = not _race_panel.visible; _refresh_race())
	_fly_btn = UiTheme.button(Loc.t("fly"), SIDE_BTN)
	_fly_btn.pressed.connect(func(): Sfx.play(self, "click"); view.toggle_flight())
	_boat_btn = UiTheme.button(Loc.t("boat"), SIDE_BTN)
	_boat_btn.pressed.connect(func(): Sfx.play(self, "click"); client.toggle_boat())
	_horse_btn = UiTheme.button(Loc.t("horse"), SIDE_BTN)
	_horse_btn.pressed.connect(func(): Sfx.play(self, "click"); client.toggle_horse())
	client.horse_changed.connect(_on_horse_changed)
	_car_btn = UiTheme.button(Loc.t("car"), SIDE_BTN)
	_car_btn.pressed.connect(func(): Sfx.play(self, "click"); client.toggle_car())
	client.car_changed.connect(_on_car_changed)
	_fish_btn = UiTheme.button(Loc.t("fish"), SIDE_BTN)
	_fish_btn.pressed.connect(func(): client.fish())
	client.boat_changed.connect(_on_boat_changed)
	_fly_pad = HBoxContainer.new()
	_fly_pad.add_theme_constant_override("separation", 12)
	_fly_pad.visible = false
	root.add_child(_fly_pad)
	_place(_fly_pad, 1.0, 1.0, 12.0, 120.0)
	for dirn in [1.0, -1.0]:
		var ab := UiTheme.button("▲" if dirn > 0.0 else "▼", Vector2(96, 96))
		ab.button_down.connect(func(): view.fly_vert = dirn)
		ab.button_up.connect(func(): view.fly_vert = 0.0)
		_fly_pad.add_child(ab)
		_interactive.append(ab)
	view.fly_changed.connect(func(on: bool): _fly_btn.text = Loc.t("land") if on else Loc.t("fly"); _fly_pad.visible = on)
	for b in [_mode_btn, _view_btn, _build_btn, _tools_btn, _inv_btn, chat_btn, _admin_btn, _god_btn, _mg_btn, _race_btn, _boat_btn, _horse_btn, _car_btn, _fish_btn, _fly_btn, menu_btn]:
		b.add_theme_font_size_override("font_size", 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(b)
		_interactive.append(b)
	_update_mode_btn()


func _build_palette() -> void:
	_palette = _panel(0.5, 1.0)
	_palette.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_palette.add_child(v)
	_hint = _label(Loc.t("tap_to_place"), 20, Color("d6e4ff"))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(340, 0)
	v.add_child(_hint)
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for t in TYPES:
		var cost := int(FWConst.BUILDING_TYPES[t]["cost"])
		var b := UiTheme.button("%s\n%s" % [Loc.t("type_" + t), Loc.digits(str(cost))], Vector2(108, 66))
		b.add_theme_font_size_override("font_size", 20)
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


func _build_tools_panel() -> void:
	# ستون کوچک ابزارها و رنگ‌ها در لبهٔ چپ (زمین بازی دیده می‌شود)
	_tools_panel = _panel(0.0, 0.34)
	_tools_panel.visible = false
	_tools_panel.modulate = Color(1, 1, 1, 0.94)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	_tools_panel.add_child(hb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	hb.add_child(col)
	for t in FWConst.TOOLS:
		var tb := UiTheme.button(Loc.t("tool_" + t), Vector2(92, 46))
		tb.add_theme_font_size_override("font_size", 19)
		tb.toggle_mode = true
		tb.pressed.connect(func():
			Sfx.play(self, "click")
			view.set_tool(t))
		col.add_child(tb)
		_tool_btns[t] = tb
	var close := UiTheme.button("✕", Vector2(92, 40))
	close.pressed.connect(_toggle_tools)
	col.add_child(close)
	_color_row = HBoxContainer.new()
	hb.add_child(_color_row)
	var cg := GridContainer.new()
	cg.columns = 2
	cg.add_theme_constant_override("h_separation", 4)
	cg.add_theme_constant_override("v_separation", 4)
	_color_row.add_child(cg)
	for i in range(FWConst.COLOR_COUNT):
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(40, 34)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggle_mode = true
		var c: Color = BlockView.TINTS[i]
		if i == 0:
			cb.text = "∅"
			c = Color(0.35, 0.38, 0.45)
		for st in ["normal", "hover", "disabled", "focus"]:
			cb.add_theme_stylebox_override(st, UiTheme.box(c, 8, Color(1, 1, 1, 0.25), 2))
		cb.add_theme_stylebox_override("pressed", UiTheme.box(c, 8, UiTheme.ACCENT, 4))
		cb.pressed.connect(func():
			Sfx.play(self, "click")
			view.set_paint_color(i))
		cg.add_child(cb)
		_color_btns.append(cb)

	# نوار کوچک پایین: راهنما + انتخاب بلوک (قابل اسکرول افقی)
	_hint_panel = _panel(0.5, 1.0)
	_hint_panel.visible = false
	_hint_panel.modulate = Color(1, 1, 1, 0.94)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_hint_panel.add_child(v)
	_tool_hint = _label("", 17, Color("d6e4ff"))
	_tool_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tool_hint.custom_minimum_size = Vector2(620, 0)
	v.add_child(_tool_hint)
	_block_box = VBoxContainer.new()
	v.add_child(_block_box)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 66)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_block_box.add_child(sc)
	var msc := ScrollContainer.new()
	msc.custom_minimum_size = Vector2(620, 50)
	msc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_block_box.add_child(msc)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 5)
	msc.add_child(mrow)
	for m in FWConst.BUILD_MODES:
		var mb := UiTheme.button(Loc.t("mode_" + m), Vector2(96, 44))
		mb.add_theme_font_size_override("font_size", 16)
		mb.toggle_mode = true
		mb.pressed.connect(func():
			Sfx.play(self, "click")
			view.set_build_mode(m))
		mrow.add_child(mb)
		_mode_btns[m] = mb
	var ub := UiTheme.button(Loc.t("btn_undo"), Vector2(96, 44))
	ub.add_theme_font_size_override("font_size", 16)
	ub.pressed.connect(func():
		Sfx.play(self, "click")
		view.undo_build())
	mrow.add_child(ub)
	var lb := UiTheme.button(Loc.t("btn_library"), Vector2(110, 44))
	lb.add_theme_font_size_override("font_size", 16)
	lb.pressed.connect(func():
		Sfx.play(self, "click")
		_bp_panel.visible = not _bp_panel.visible
		if _bp_panel.visible:
			client.bp_op("list"))
	mrow.add_child(lb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	sc.add_child(row)
	for t in FWConst.BLOCK_ORDER:
		var b := UiTheme.button("", Vector2(86, 56))
		b.add_theme_font_size_override("font_size", 16)
		b.toggle_mode = true
		b.pressed.connect(func():
			Sfx.play(self, "click")
			view.set_block_type(t))
		row.add_child(b)
		_block_btns[t] = b


func _set_tools_visible(on: bool) -> void:
	_tools_panel.visible = on
	_hint_panel.visible = on


func _affordable(type: String) -> int:
	var cost: Dictionary = FWConst.BLOCK_TYPES[type]["cost"]
	if client.creative:
		return 999
	var n := 1 << 30
	for item in cost:
		n = mini(n, client.item_count(str(item)) / int(cost[item]))
	return n


func _refresh_tools() -> void:
	if _tools_panel == null:
		return
	for t in _tool_btns:
		_tool_btns[t].button_pressed = (t == view.tool)
	var hint := Loc.t("hint_" + view.tool)
	if view.tool == "hammer":
		var parts: Array = []
		var cost: Dictionary = FWConst.BLOCK_TYPES[view.block_type]["cost"]
		for item in cost:
			parts.append("%s %s" % [Loc.digits(str(cost[item])), Loc.t("item_" + str(item))])
		hint = "%s: %s  |  %s" % [Loc.t("block_" + view.block_type), " + ".join(parts), Loc.t("hold_remove")]
		if view.build_mode != "single":
			hint = Loc.t("hint_mode_" + view.build_mode)
			if view.region_has_a:
				hint += "  ←  " + Loc.t("msg_corner_set")
	_tool_hint.text = hint
	_hint_panel.visible = _tools_panel.visible
	_block_box.visible = view.tool == "hammer"
	_color_row.visible = view.tool == "hammer" or view.tool == "brush"
	for m in _mode_btns:
		_mode_btns[m].button_pressed = (m == view.build_mode)
	for t in _block_btns:
		var b: Button = _block_btns[t]
		b.text = "%s\n×%s" % [Loc.t("block_" + t), Loc.digits(str(_affordable(t)))]
		b.button_pressed = (t == view.block_type)
	for i in range(_color_btns.size()):
		_color_btns[i].button_pressed = (i == view.paint_color)


## آزمایشی (--panel tools|inv|menu|race|mg): پنل را برای عکس باز می‌کند.
func debug_open_panel(name: String) -> void:
	match name:
		"tools": _toggle_tools()
		"inv": _inv_panel.visible = true
		"menu": _menu_panel.visible = true
		"race": _race_panel.visible = true
		"mg": _mg_panel.visible = true
		"admin": _admin_panel.visible = true
	_refit_drawers()


func _toggle_tools() -> void:
	if view.inside_id > 0 or client.mine_id != "" or view.mode != "life":
		return
	Sfx.play(self, "click")
	var on := not _tools_panel.visible
	_set_tools_visible(on)
	if on:
		_palette.visible = false
		_info.visible = false
		view.set_build_type("")
		view.set_tool("axe")
	else:
		view.set_tool("hand")
	_refresh_tools()


func _build_inventory_panel() -> void:
	_inv_panel = _panel(0.5, 0.5)
	_inv_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(540, 0)
	_inv_panel.add_child(v)
	v.add_child(_label(Loc.t("inv_title"), 28, Color("ffd24a")))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 210)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	for item in FWConst.ITEM_ORDER:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		rows.add_child(r)
		var nm := _label(Loc.t("item_" + item), 22)
		nm.custom_minimum_size = Vector2(70, 0)
		nm.add_theme_font_size_override("font_size", 20)
		var cnt := _label("", 24, Color("ffd24a"))
		cnt.custom_minimum_size = Vector2(52, 0)
		var pr := _label("", 18, Color("c8f08a"))
		pr.custom_minimum_size = Vector2(120, 0)
		pr.add_theme_font_size_override("font_size", 16)
		var s1 := UiTheme.button(Loc.t("sell_one"), Vector2(76, 48))
		s1.pressed.connect(func(): client.trade(item, 1, false))
		var sa := UiTheme.button(Loc.t("sell_all"), Vector2(92, 48))
		sa.pressed.connect(func():
			var n: int = client.item_count(item)
			if n > 0:
				client.trade(item, mini(n, 500), false))
		var by := UiTheme.button(Loc.t("buy_one"), Vector2(76, 48))
		by.pressed.connect(func(): client.trade(item, 1, true))
		for c in [nm, cnt, pr, s1, sa, by]:
			if c is Button:
				c.add_theme_font_size_override("font_size", 18)
			r.add_child(c)
		_inv_rows[item] = {"count": cnt, "price": pr}
	v.add_child(_label(Loc.t("craft_title"), 22, Color("9ad0ff")))
	var crow := HFlowContainer.new()
	crow.add_theme_constant_override("h_separation", 8)
	crow.add_theme_constant_override("v_separation", 8)
	v.add_child(crow)
	for recipe in FWConst.RECIPES:
		var cb := UiTheme.button(Loc.t("craft_" + recipe), Vector2(0, 56))
		cb.custom_minimum_size = Vector2(200, 52)
		cb.add_theme_font_size_override("font_size", 17)
		cb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cb.pressed.connect(func(): client.craft(recipe, 1))
		crow.add_child(cb)
	v.add_child(_label(Loc.t("offer_title"), 22, Color("9ad0ff")))
	var orow := HFlowContainer.new()
	orow.add_theme_constant_override("h_separation", 6)
	orow.add_theme_constant_override("v_separation", 6)
	v.add_child(orow)
	_offer_player = OptionButton.new()
	_offer_player.custom_minimum_size = Vector2(170, 48)
	_offer_item = OptionButton.new()
	_offer_item.custom_minimum_size = Vector2(110, 48)
	for it in FWConst.ITEM_ORDER:
		_offer_item.add_item(Loc.t("item_" + it))
	_offer_count = SpinBox.new()
	_offer_count.min_value = 1
	_offer_count.max_value = 500
	_offer_count.value = 1
	_offer_count.prefix = Loc.t("offer_count") + " "
	_offer_price = SpinBox.new()
	_offer_price.min_value = 0
	_offer_price.max_value = FWConst.OFFER_MAX_PRICE
	_offer_price.value = 10
	_offer_price.prefix = Loc.t("offer_price") + " "
	var osend := UiTheme.button(Loc.t("offer_send"), Vector2(150, 48))
	osend.pressed.connect(_send_offer)
	for c in [_offer_player, _offer_item, _offer_count, _offer_price, osend]:
		orow.add_child(c)
	var close := UiTheme.button(Loc.t("back"), Vector2(0, 56))
	close.pressed.connect(func(): _inv_panel.visible = false)
	v.add_child(close)


func _refresh_inventory() -> void:
	if _inv_panel == null:
		return
	for item in _inv_rows:
		var buy_p := int(ceil(float(FWConst.ITEMS[item]) * FWConst.BUY_MARKUP))
		_inv_rows[item]["count"].text = Loc.digits(str(client.item_count(item)))
		_inv_rows[item]["price"].text = Loc.fmt("price_fmt", [Loc.digits(str(int(client.sell_prices.get(item, 0)))), Loc.digits(str(buy_p))])


func _refresh_offer_players() -> void:
	var keep: String = _offer_player.get_item_text(_offer_player.selected) if _offer_player.item_count > 0 and _offer_player.selected >= 0 else ""
	_offer_player.clear()
	for n in client.players:
		if n != client.my_name:
			_offer_player.add_item(str(n))
	if _offer_player.item_count == 0:
		_offer_player.add_item(Loc.t("offer_no_players"))
		_offer_player.disabled = true
	else:
		_offer_player.disabled = false
		for i in range(_offer_player.item_count):
			if _offer_player.get_item_text(i) == keep:
				_offer_player.select(i)


func _send_offer() -> void:
	if _offer_player.disabled or _offer_player.item_count == 0:
		return
	Sfx.play(self, "click")
	client.offer(_offer_player.get_item_text(_offer_player.selected), str(FWConst.ITEM_ORDER[_offer_item.selected]), int(_offer_count.value), int(_offer_price.value))


func _build_offer_panel() -> void:
	_offer_panel = _panel(0.5, 0.0)
	_offer_panel.visible = false
	_offer_panel.offset_top = 84
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_offer_panel.add_child(v)
	_offer_label = _label("", 22, Color("ffe9a6"))
	_offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offer_label.custom_minimum_size = Vector2(560, 0)
	v.add_child(_offer_label)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var yes := UiTheme.button(Loc.t("offer_accept"), Vector2(0, 54))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func(): _answer_offer(true))
	var no := UiTheme.button(Loc.t("offer_decline"), Vector2(0, 54))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(func(): _answer_offer(false))
	h.add_child(yes)
	h.add_child(no)


func _on_offer(data: Dictionary) -> void:
	_offer_queue.append(data)
	Sfx.play(self, "notify")
	_show_offer()
	var id: int = int(data["id"])
	get_tree().create_timer(FWConst.OFFER_TTL).timeout.connect(func():
		for i in range(_offer_queue.size()):
			if int(_offer_queue[i]["id"]) == id:
				_offer_queue.remove_at(i)
				break
		_show_offer())


func _show_offer() -> void:
	if _offer_queue.is_empty():
		_offer_panel.visible = false
		return
	var o: Dictionary = _offer_queue[0]
	_offer_label.text = Loc.fmt("offer_incoming", [str(o["from"]), Loc.digits(str(o["n"])), Loc.t("item_" + str(o["item"])), Loc.digits(str(o["price"]))])
	_offer_panel.visible = true


func _answer_offer(accept: bool) -> void:
	if _offer_queue.is_empty():
		return
	Sfx.play(self, "click")
	var o: Dictionary = _offer_queue.pop_front()
	client.answer_offer(int(o["id"]), accept)
	_show_offer()


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
	_info_enter = UiTheme.button(Loc.t("enter"), Vector2(0, 64))
	_info_enter.pressed.connect(func():
		client.enter_building(_info_id)
		_info.visible = false)
	v.add_child(_info_enter)
	_info_job = UiTheme.button(Loc.t("job_take"), Vector2(0, 64))
	_info_job.pressed.connect(func(): client.set_job(0 if client.job_id == _info_id else _info_id))
	v.add_child(_info_job)


func _build_god_panel() -> void:
	_god_panel = _panel(0.5, 1.0)
	_god_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_god_panel.add_child(v)
	v.add_child(_label(Loc.t("god_hint"), 22, Color("d6e4ff")))
	var row := GridContainer.new()
	row.columns = 3
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for k in FWConst.GOD_STATIC + FWConst.GOD_ANIMALS.keys() + FWConst.GOD_SHAPES + FWConst.GOD_POWERS + ["remove"]:
		var b := UiTheme.button(Loc.t("god_" + str(k)), Vector2(120, 70))
		b.add_theme_font_size_override("font_size", 22)
		b.toggle_mode = true
		b.pressed.connect(func(): _select_god(str(k)))
		row.add_child(b)
		_god_btns[str(k)] = b


func _select_god(k: String) -> void:
	Sfx.play(self, "click")
	for t in _god_btns:
		_god_btns[t].button_pressed = (t == k and view.god_kind != k)
	for t in _type_btns:
		_type_btns[t].button_pressed = false
	view.set_god_kind("" if view.god_kind == k else k)


func _toggle_god() -> void:
	Sfx.play(self, "click")
	var on := not _god_panel.visible
	_god_panel.visible = on
	_info.visible = false
	_npc_panel.visible = false
	if on:
		_palette.visible = false
		view.set_build_type("")
	else:
		view.set_god_kind("")
		for t in _god_btns:
			_god_btns[t].button_pressed = false


func _build_minigame() -> void:
	_mg_panel = _panel(0.5, 1.0)
	_mg_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_mg_panel.add_child(v)
	v.add_child(_label(Loc.t("mg_title"), 28, Color("ffd24a")))
	_mg_best = _label("", 22)
	_mg_status = _label("", 22)
	_mg_board = _label("", 20)
	v.add_child(_mg_best)
	v.add_child(_mg_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var start := UiTheme.button(Loc.t("mg_start"), Vector2(0, 64))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(func(): client.minigame_start(); _mg_panel.visible = false)
	var close := UiTheme.button("✕", Vector2(64, 64))
	close.pressed.connect(func(): _mg_panel.visible = false)
	row.add_child(start)
	row.add_child(close)
	v.add_child(_label(Loc.t("mg_board"), 22, Color("c8f08a")))
	v.add_child(_mg_board)
	# نوار امتیاز و زمان بالای صفحه، فقط وسط دور
	_mg_bar = _label("", 30, Color("ffd24a"))
	root.add_child(_mg_bar)
	_place(_mg_bar, 0.5, 0.0, 0.0, 90.0)
	_mg_bar.visible = false
	client.minigame_changed.connect(_refresh_minigame)
	client.disaster_changed.connect(_on_disaster_changed)


func _build_race() -> void:
	_race_panel = _panel(0.5, 1.0)
	_race_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_race_panel.add_child(v)
	_race_title = _label(Loc.t("race_title"), 28, Color("ffd24a"))
	v.add_child(_race_title)
	_race_best = _label("", 22)
	_race_board = _label("", 20)
	v.add_child(_race_best)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var start := UiTheme.button(Loc.t("race_start"), Vector2(0, 64))
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_race_start_btn = start
	start.pressed.connect(func(): client.race_start(); _race_panel.visible = false)
	var close := UiTheme.button("✕", Vector2(64, 64))
	close.pressed.connect(func(): _race_panel.visible = false)
	row.add_child(start)
	row.add_child(close)
	var grp := UiTheme.button(Loc.t("group_race"), Vector2(0, 56))
	grp.pressed.connect(func(): client.group_race(); _race_panel.visible = false)
	v.add_child(grp)
	v.add_child(_label(Loc.t("race_board"), 22, Color("c8f08a")))
	v.add_child(_race_board)
	_race_bar = _label("", 30, Color("ffd24a"))
	root.add_child(_race_bar)
	_place(_race_bar, 0.5, 0.0, 0.0, 90.0)
	_race_bar.visible = false
	client.race_changed.connect(_refresh_race)


static func race_time_text(cs: int) -> String:
	return Loc.digits("%.2f" % (float(cs) / 100.0))


func _refresh_race() -> void:
	if _race_panel == null:
		return
	var r: Dictionary = client.race
	var on_boat: bool = client.boating
	var on_car: bool = client.driving and not on_boat
	_race_title.text = Loc.t("boat_race_title") if on_boat else (Loc.t("car_race_title") if on_car else Loc.t("race_title"))
	_race_start_btn.text = Loc.t("boat_race_start") if on_boat else (Loc.t("car_race_start") if on_car else Loc.t("race_start"))
	var b: int = int(r.get("boat_best" if on_boat else ("car_best" if on_car else "best"), 0))
	_race_best.text = Loc.fmt("race_best", [race_time_text(b)]) if b > 0 else Loc.t("race_none")
	var lines: Array = []
	var rank := 1
	for row in r.get("boat_board" if on_boat else ("car_board" if on_car else "board"), []):
		lines.append("%s. %s — %s" % [Loc.digits(str(rank)), str(row[0]), race_time_text(int(row[1]))])
		rank += 1
	_race_board.text = "\n".join(lines) if not lines.is_empty() else "—"
	_update_race_bar()


func _update_race_bar() -> void:
	if _race_bar == null:
		return
	var active: bool = client.race_active()
	_race_bar.visible = active
	if active:
		_race_bar.text = Loc.fmt("race_status", [Loc.digits(str(int(client.race.get("next", 0)) + 1)), Loc.digits(str(FWConst.RACE_GATES)), Loc.digits("%.1f" % client.race_elapsed())])


func _on_horse_changed() -> void:
	_horse_btn.text = Loc.t("horse_leave") if client.mounted else Loc.t("horse")
	_fly_btn.visible = view.mode == "life" and client.creative and not client.boating and not client.mounted and not client.driving


func _on_car_changed() -> void:
	_car_btn.text = Loc.t("car_leave") if client.driving else Loc.t("car")
	_refresh_race()
	_fly_btn.visible = view.mode == "life" and client.creative and not client.boating and not client.mounted and not client.driving


func _on_boat_changed() -> void:
	_boat_btn.text = Loc.t("boat_leave") if client.boating else Loc.t("boat")
	_fly_btn.visible = view.mode == "life" and client.creative and not client.boating and not client.mounted and not client.driving
	_refresh_race()


func _on_disaster_changed() -> void:
	var k: String = client.disaster_kind()
	if k != "":
		Sfx.play(self, "error")
		toast(Loc.t("msg_disaster_" + k), Color("ff9a8a"))
	elif _was_disaster:
		toast(Loc.t("msg_disaster_over"), Color("c8f08a"))
	_was_disaster = k != ""


func _refresh_minigame() -> void:
	if _mg_panel == null:
		return
	var mg: Dictionary = client.minigame
	_mg_best.text = Loc.fmt("mg_best", [Loc.digits(str(int(mg.get("best", 0))))])
	_mg_status.text = ""
	var lines: Array = []
	var rank := 1
	for row in mg.get("board", []):
		lines.append("%s. %s — %s" % [Loc.digits(str(rank)), str(row[0]), Loc.digits(str(int(row[1])))])
		rank += 1
	_mg_board.text = "\n".join(lines) if not lines.is_empty() else "—"
	_update_mg_bar()


func _update_mg_bar() -> void:
	if _mg_bar == null:
		return
	var active := bool(client.minigame.get("active", false))
	_mg_bar.visible = active
	if active:
		_mg_bar.text = Loc.fmt("mg_status", [Loc.digits(str(int(client.minigame.get("score", 0)))), Loc.digits(str(int(ceil(client.minigame_time_left()))))])


func _build_npc_panel() -> void:
	_npc_panel = _panel(0.5, 1.0)
	_npc_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_npc_panel.add_child(v)
	_npc_title = _label("", 28, Color("ffd24a"))
	_npc_body = _label("", 22)
	v.add_child(_npc_title)
	v.add_child(_npc_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var talk := UiTheme.button(Loc.t("npc_talk"), Vector2(190, 64))
	talk.pressed.connect(func(): client.npc_interact(_npc_id, ""))
	var close := UiTheme.button("✕", Vector2(64, 64))
	close.pressed.connect(func(): _npc_panel.visible = false)
	row.add_child(talk)
	row.add_child(close)
	var grow := HBoxContainer.new()
	grow.add_theme_constant_override("separation", 8)
	v.add_child(grow)
	_npc_item = OptionButton.new()
	_npc_item.custom_minimum_size = Vector2(170, 56)
	for it in FWConst.ITEM_ORDER:
		_npc_item.add_item(Loc.t("item_" + it))
	grow.add_child(_npc_item)
	var gift := UiTheme.button(Loc.t("npc_gift"), Vector2(0, 56))
	gift.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gift.pressed.connect(func(): client.npc_interact(_npc_id, str(FWConst.ITEM_ORDER[_npc_item.selected])))
	grow.add_child(gift)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	v.add_child(srow)
	for amount in [1, 10]:
		var sb := UiTheme.button(Loc.t("npc_sell%d" % amount), Vector2(0, 56))
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func(): client.npc_sell(_npc_id, str(FWConst.ITEM_ORDER[_npc_item.selected]), amount))
		srow.add_child(sb)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	v.add_child(brow)
	for amount in [1, 10]:
		var bb := UiTheme.button(Loc.t("npc_buy%d" % amount), Vector2(0, 56))
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.pressed.connect(func():
			var it: String = str(FWConst.ITEM_ORDER[_npc_item.selected])
			if not FWConst.NPC_SELLS.has(it):
				toast(Loc.t("err_npc_not_selling"), Color("ff9a8a"))
				return
			client.npc_buy(_npc_id, it, amount))
		brow.add_child(bb)


func _on_npc_tapped(id: int) -> void:
	_npc_id = id
	_info.visible = false
	_fill_npc()
	_npc_panel.visible = true


func _fill_npc() -> void:
	if _npc_panel == null or not _npc_panel.visible and _npc_id < 0:
		return
	var nm := ""
	for n in client.npcs:
		if int(n[0]) == _npc_id:
			nm = str(n[4])
	_npc_title.text = nm
	var pts: int = int(client.friends.get(str(_npc_id), 0))
	var lv := 0
	for t in FWConst.FRIEND_LEVELS:
		if pts >= int(t):
			lv += 1
	_npc_body.text = "%s: %s (%s/%s)\n%s" % [Loc.t("npc_friendship"), Loc.t("npc_level_%d" % lv), Loc.digits(str(pts)), Loc.digits(str(FWConst.FRIEND_MAX)),
		Loc.fmt("npc_bonus", [Loc.digits(str(int(round(float(FWConst.NPC_TRADE_BONUS[lv]) * 100.0))))])]


var _furn_btn: Button
var _furn_panel: PanelContainer
var _furn_type: OptionButton
var _furn_rot: int = 0
var _furn_rot_btn: Button


## مبلمان خانه: انتخاب نوع، چرخش، «بگذار» (جلوی بازیکن) و «بردار» (نزدیک‌ترین). قیمت‌ها و جا را سرور می‌سنجد.
func _build_furn_panel() -> void:
	_furn_btn = UiTheme.button(Loc.t("furn_open"), Vector2(220, 76))
	_furn_btn.visible = false
	_furn_btn.pressed.connect(func():
		Sfx.play(self, "click")
		_furn_panel.visible = not _furn_panel.visible)
	root.add_child(_furn_btn)
	_place(_furn_btn, 1.0, 1.0, 12.0, 40.0)
	_interactive.append(_furn_btn)
	_furn_panel = _panel(0.5, 1.0)
	_furn_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_furn_panel.add_child(v)
	v.add_child(_label(Loc.t("furn_title"), 28, Color("ffd24a")))
	_furn_type = OptionButton.new()
	_furn_type.custom_minimum_size = Vector2(300, 56)
	for t in FWConst.FURNITURE_ORDER:
		_furn_type.add_item("%s — %s" % [Loc.t("furn_" + t), Loc.digits(str(FWConst.FURNITURE[t]["cost"]))])
	v.add_child(_furn_type)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_furn_rot_btn = UiTheme.button(Loc.fmt("furn_rotate", [Loc.digits("0")]), Vector2(0, 60))
	_furn_rot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_furn_rot_btn.pressed.connect(func():
		_furn_rot = (_furn_rot + 1) % 4
		_furn_rot_btn.text = Loc.fmt("furn_rotate", [Loc.digits(str(_furn_rot * 90))]))
	row.add_child(_furn_rot_btn)
	var place_b := UiTheme.button(Loc.t("furn_place"), Vector2(0, 60))
	place_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	place_b.pressed.connect(_furn_place_pressed)
	row.add_child(place_b)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	v.add_child(row2)
	var rem_b := UiTheme.button(Loc.t("furn_remove"), Vector2(0, 60))
	rem_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rem_b.pressed.connect(_furn_remove_pressed)
	row2.add_child(rem_b)
	var close := UiTheme.button("✕", Vector2(64, 60))
	close.pressed.connect(func(): _furn_panel.visible = false)
	row2.add_child(close)


var _bp_panel: PanelContainer
var _bp_name: LineEdit
var _bp_shared: CheckBox
var _bp_rows: VBoxContainer


func _build_bp_panel() -> void:
	_bp_panel = _panel(0.5, 1.0)
	_bp_panel.visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(560, 0)
	_bp_panel.add_child(v)
	v.add_child(_label(Loc.t("bp_title"), 28, Color("ffd24a")))
	var hint := _label(Loc.t("bp_hint"), 17, Color("d6e4ff"))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(540, 0)
	v.add_child(hint)
	_bp_name = LineEdit.new()
	_bp_name.placeholder_text = Loc.t("bp_name_hint")
	_bp_name.max_length = 24
	_bp_name.custom_minimum_size = Vector2(0, 56)
	v.add_child(_bp_name)
	_bp_shared = CheckBox.new()
	_bp_shared.text = Loc.t("bp_share_check")
	_bp_shared.add_theme_font_size_override("font_size", 20)
	v.add_child(_bp_shared)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var save_b := UiTheme.button(Loc.t("bp_save"), Vector2(0, 60))
	save_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_b.pressed.connect(func():
		Sfx.play(self, "click")
		if view.clipboard.is_empty():
			Sfx.play(self, "error")
			toast(Loc.err("clipboard_empty"), Color("ff9a8a"))
			return
		client.bp_save(_bp_name.text, view.clipboard, _bp_shared.button_pressed)
		_bp_name.text = "")
	row.add_child(save_b)
	var close := UiTheme.button("✕", Vector2(64, 60))
	close.pressed.connect(func(): _bp_panel.visible = false)
	row.add_child(close)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 220)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_bp_rows = VBoxContainer.new()
	_bp_rows.add_theme_constant_override("separation", 6)
	_bp_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_bp_rows)


func _fill_bp_list() -> void:
	if _bp_rows == null:
		return
	for c in _bp_rows.get_children():
		c.queue_free()
	if client.blueprints.is_empty():
		_bp_rows.add_child(_label(Loc.t("bp_empty"), 18, Color("aab6c8")))
		return
	var is_admin: bool = FWConst.is_admin(client.role)
	for b in client.blueprints:
		var id: int = int(b["id"])
		var mine: bool = str(b["author"]) == client.my_name
		var box := VBoxContainer.new()
		_bp_rows.add_child(box)
		var sz: Array = b["size"]
		var title := "%s%s" % [str(b["name"]), "  🌐" if bool(b["shared"]) else ""]
		var sub := "%s: %s  ·  %s %s  ·  %s×%s×%s" % [Loc.t("bp_author"), str(b["author"]), Loc.digits(str(b["n"])), Loc.t("bp_blocks"),
			Loc.digits(str(sz[0])), Loc.digits(str(sz[1])), Loc.digits(str(sz[2]))]
		box.add_child(_label(title, 22, Color("ffd24a")))
		box.add_child(_label(sub, 15, Color("aab6c8")))
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		box.add_child(r)
		var use := UiTheme.button(Loc.t("bp_use"), Vector2(0, 48))
		use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use.pressed.connect(func():
			Sfx.play(self, "click")
			client.bp_op("load", id))
		r.add_child(use)
		if mine:
			var sh := UiTheme.button(Loc.t("bp_unshare") if bool(b["shared"]) else Loc.t("bp_share"), Vector2(0, 48))
			sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sh.pressed.connect(func():
				Sfx.play(self, "click")
				client.bp_op("unshare" if bool(b["shared"]) else "share", id))
			r.add_child(sh)
		if mine or is_admin:
			var del := UiTheme.button("🗑", Vector2(64, 48))
			del.pressed.connect(func():
				Sfx.play(self, "click")
				client.bp_op("delete", id))
			r.add_child(del)


func _on_bp_loaded(_id: int, data: PackedInt32Array) -> void:
	view.clipboard = data
	view.set_build_mode("paste")
	_bp_panel.visible = false
	Sfx.play(self, "click")
	toast(Loc.fmt("msg_bp_loaded", [Loc.digits(str(data.size() / 5))]), Color("c8f08a"))


func _furn_place_pressed() -> void:
	var t: String = str(FWConst.FURNITURE_ORDER[_furn_type.selected])
	var me: Vector2 = view.room_pos()
	var h := FWConst.furn_half(t, _furn_rot)
	var fwd := Vector2(sin(view.my_yaw), cos(view.my_yaw))
	var at := me + fwd * (maxf(h.x, h.y) + 0.7)
	Sfx.play(self, "click")
	client.furn_place(t, at.x, at.y, _furn_rot)


func _furn_remove_pressed() -> void:
	var me: Vector2 = view.room_pos()
	var best := -1
	var best_d := 2.5
	for i in client.furn.size():
		var d: float = Vector2(float(client.furn[i]["x"]), float(client.furn[i]["z"])).distance_to(me)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		toast(Loc.t("furn_none_near"), Color("ff9a8a"))
		return
	Sfx.play(self, "click")
	client.furn_remove(best)


func _build_leave_button() -> void:
	_leave_btn = UiTheme.button(Loc.t("leave"), Vector2(260, 76))
	_leave_btn.visible = false
	_leave_btn.pressed.connect(func():
		Sfx.play(self, "click")
		if client.mine_id != "":
			client.leave_mine()
		else:
			client.leave_building())
	root.add_child(_leave_btn)
	_place(_leave_btn, 0.5, 1.0, 0.0, 40.0)
	_interactive.append(_leave_btn)
	# دکمهٔ «ورود به معدن» فقط جلوی ورودی معدن نمایان می‌شود.
	_mine_btn = UiTheme.button(Loc.t("enter_mine"), Vector2(300, 76))
	_mine_btn.visible = false
	_mine_btn.pressed.connect(func():
		Sfx.play(self, "click")
		var mid: String = view.near_mine_id()
		if mid != "":
			client.enter_mine(mid))
	root.add_child(_mine_btn)
	_place(_mine_btn, 0.5, 1.0, 0.0, 130.0)
	_interactive.append(_mine_btn)
	# داخل مغازه: دکمهٔ «خرید و فروش کالا» بازار شهر (کیف و بازار) را باز می‌کند.
	_shop_btn = UiTheme.button(Loc.t("shop_goods"), Vector2(300, 76))
	_shop_btn.visible = false
	_shop_btn.pressed.connect(func():
		Sfx.play(self, "click")
		_inv_panel.visible = not _inv_panel.visible
		_refresh_offer_players())
	root.add_child(_shop_btn)
	_place(_shop_btn, 0.5, 1.0, 0.0, 130.0)
	_interactive.append(_shop_btn)


func _on_mine_changed(id: String) -> void:
	_leave_btn.visible = id != "" or client.inside_id > 0
	_mine_btn.visible = false
	_info.visible = false
	if id != "":
		_set_tools_visible(false)
		_inv_panel.visible = false
		view.set_tool("hand")
		_palette.visible = false
		toast(Loc.t("msg_mine_entered"), Color("c8f08a"))
	_refresh_stats()


func _on_inside_changed(id: int) -> void:
	_leave_btn.visible = id > 0 or client.mine_id != ""
	_info.visible = false
	var in_house: bool = id > 0 and str(client.mirror.buildings.get(id, {}).get("type", "")) == "house"
	_furn_btn.visible = in_house
	var in_shop: bool = id > 0 and str(client.mirror.buildings.get(id, {}).get("type", "")) == "shop"
	_shop_btn.visible = in_shop
	if not in_house:
		_furn_panel.visible = false
	if id > 0:
		_set_tools_visible(false)
		_inv_panel.visible = false
		view.set_tool("hand")
		_palette.visible = false
		var b: Dictionary = client.mirror.buildings.get(id, {})
		toast(Loc.fmt("msg_entered", [Loc.t("type_" + str(b.get("type", "house")))]))
		if b.get("type", "") == "house":
			toast(Loc.t("msg_resting"), Color("c8f08a"))
	_refresh_stats()


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
	v.add_child(_label(Loc.t("time_speed"), 22, Color("c8f08a")))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	v.add_child(srow)
	for sp in FWConst.TIME_SPEEDS:
		var txt: String = Loc.t("time_paused") if float(sp) == 0.0 else "×" + Loc.digits(str(int(sp)))
		var sb := UiTheme.button(txt, Vector2(0, 56))
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.pressed.connect(func(): client.set_world("time_speed", sp))
		srow.add_child(sb)
	v.add_child(_label(Loc.t("weather"), 22, Color("c8f08a")))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 8)
	v.add_child(wrow)
	for w in FWConst.WEATHERS:
		var wb := UiTheme.button(Loc.t("weather_" + w), Vector2(0, 56))
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wb.pressed.connect(func(): client.set_world("weather", w))
		wrow.add_child(wb)
	v.add_child(_label(Loc.t("world_laws"), 22, Color("c8f08a")))
	_forest_btn = UiTheme.button(Loc.t("law_forest_growth"), Vector2(0, 56))
	_forest_btn.toggle_mode = true
	_forest_btn.pressed.connect(func(): client.set_world("forest_growth", not client.forest_growth))
	v.add_child(_forest_btn)
	client.world_changed.connect(func(): _forest_btn.button_pressed = client.forest_growth)
	v.add_child(_label(Loc.t("disasters"), 22, Color("c8f08a")))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	v.add_child(drow)
	for dk in FWConst.DISASTERS:
		var db := UiTheme.button(Loc.t("disaster_" + str(dk)), Vector2(0, 56))
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.pressed.connect(func(): client.start_disaster(str(dk)))
		drow.add_child(db)
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
			var good_name := str(args.get("good", "wheat"))
			var msg_key := "msg_collected" if good_name == "wheat" else "msg_collected_" + good_name
			toast(Loc.fmt(msg_key, [Loc.digits(str(args["count"])), Loc.digits(str(args["earned"]))]), Color("c8f08a"))
		"job_taken":
			Sfx.play(self, "notify")
			toast(Loc.fmt("msg_job_taken", [args["employer"]]), Color("c8f08a"))
		"job_quit":
			toast(Loc.t("msg_job_quit"))
		"job_lost":
			Sfx.play(self, "error")
			toast(Loc.t("msg_job_lost"), Color("ff9a8a"))
		"wage":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_wage", [Loc.digits(str(args["amount"]))]), Color("c8f08a"))
		"employer_broke":
			toast(Loc.fmt("msg_employer_broke", [args["employer"]]), Color("ff9a8a"))
		"gathered":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_gathered", [Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"]))]), Color("c8f08a"))
		"filled":
			Sfx.play(self, "click")
			toast(Loc.fmt("msg_filled", [Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"]))]), Color("c8f08a"))
		"npc_talk":
			Sfx.play(self, "coin" if int(args["reward"]) > 0 else "click")
			toast(Loc.fmt("msg_npc_talk", [str(args["npc"]), Loc.digits(str(args["reward"]))]) if int(args["reward"]) > 0 else Loc.fmt("msg_npc_talk0", [str(args["npc"])]), Color("c8f08a"))
		"npc_sold":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_npc_sold", [str(args["npc"]), Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"])), Loc.digits(str(args["total"]))]), Color("c8f08a"))
		"npc_bought":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_npc_bought", [str(args["npc"]), Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"])), Loc.digits(str(args["total"]))]), Color("c8f08a"))
		"minigame_end":
			Sfx.play(self, "coin")
			var txt: String = Loc.fmt("msg_mg_end_reward", [Loc.digits(str(args["score"])), Loc.digits(str(args["reward"]))]) if int(args["reward"]) > 0 else Loc.fmt("msg_mg_end", [Loc.digits(str(args["score"]))])
			if bool(args["new_best"]):
				txt += " " + Loc.t("msg_mg_new_best")
			toast(txt, Color("ffd84a"))
		"race_end":
			var rtxt: String
			if bool(args["finished"]):
				Sfx.play(self, "coin")
				var tt: String = race_time_text(int(args["time"]))
				rtxt = Loc.fmt("msg_race_end_reward", [tt, Loc.digits(str(args["reward"]))]) if int(args["reward"]) > 0 else Loc.fmt("msg_race_end", [tt])
				if bool(args.get("group", false)):
					rtxt = Loc.fmt("msg_group_rank", [Loc.digits(str(args["rank"])), Loc.digits(str(args["of"]))]) + " " + rtxt
				elif bool(args.get("boat", false)):
					rtxt = Loc.t("msg_boat_prefix") + " " + rtxt
				elif bool(args.get("car", false)):
					rtxt = Loc.t("msg_car_prefix") + " " + rtxt
				if bool(args["new_best"]):
					rtxt += " " + Loc.t("msg_race_new_best")
			else:
				Sfx.play(self, "error")
				rtxt = Loc.t("msg_race_fail")
			toast(rtxt, Color("ffd84a"))
		"npc_gift":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_npc_gift", [str(args["npc"]), Loc.t("item_" + str(args["item"]))]), Color("ffd84a"))
		"grace_lobby":
			toast(Loc.fmt("msg_grace_lobby", [str(args["host"]), Loc.digits(str(args["n"])), Loc.digits(str(args["t"]))]), Color("8fd8ff"))
		"grace_start":
			Sfx.play(self, "click")
			toast(Loc.fmt("msg_grace_start", [Loc.digits(str(args["n"]))]), Color("ffd84a"))
		"grace_cancel":
			toast(Loc.t("msg_grace_cancel"), Color("ff9a8a"))
		"unlocked":
			Sfx.play(self, "coin")
			toast(Loc.t("msg_unlocked_" + str(args["what"])), Color("ffd84a"))
		"fished":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_fished", [Loc.digits(str(args["count"]))]), Color("8fd8ff"))
		"upgraded":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_upgraded", [Loc.t("tool_" + str(args["tool"]))]), Color("ffd84a"))
		"rested":
			Sfx.play(self, "coin")
			toast(Loc.t("msg_rested"), Color("c8f08a"))
		"treasure":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_treasure", [Loc.digits(str(args["reward"]))]), Color("ffd84a"))
		"crafted":
			Sfx.play(self, "place")
			toast(Loc.fmt("msg_crafted", [Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"]))]), Color("c8f08a"))
		"sold":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_sold", [Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"])), Loc.digits(str(args["total"]))]), Color("c8f08a"))
		"bought":
			Sfx.play(self, "click")
			toast(Loc.fmt("msg_bought", [Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"])), Loc.digits(str(args["total"]))]))
		"offer_sent":
			toast(Loc.fmt("msg_offer_sent", [str(args["to"])]))
		"offer_declined":
			toast(Loc.fmt("msg_offer_declined", [str(args["to"])]), Color("ff9a8a"))
		"offer_done":
			Sfx.play(self, "coin")
			toast(Loc.fmt("msg_offer_done", [Loc.digits(str(args["count"])), Loc.t("item_" + str(args["item"])), Loc.digits(str(args["price"]))]), Color("c8f08a"))
		"wrong_tool":
			Sfx.play(self, "error")
			var need := str(args.get("tool", ""))
			toast(Loc.fmt("msg_need_tool", [Loc.t("tool_" + need)]) if need != "" else Loc.err(code), Color("ff9a8a"))
		"batch_done":
			Sfx.play(self, "place")
			var bt: String = Loc.fmt("msg_batch_done", [Loc.digits(str(args["n"]))])
			if int(args.get("skipped", 0)) > 0:
				bt += " " + Loc.fmt("msg_batch_skipped", [Loc.digits(str(args["skipped"]))])
			toast(bt, Color("c8f08a"))
		"bp_saved":
			Sfx.play(self, "place")
			toast(Loc.t("msg_bp_saved"), Color("c8f08a"))
		"corner_set":
			toast(Loc.t("msg_corner_set"))
		"copied":
			toast(Loc.fmt("msg_copied", [Loc.digits(str(args["n"]))]), Color("c8f08a"))
		"role_set":
			toast(Loc.fmt("msg_role_set", [args["target"], Loc.role_name(str(args["role"]))]))
		"your_building_removed":
			toast(Loc.fmt("msg_your_building_removed", [args["by"]]), Color("ff9a8a"))
		_:
			Sfx.play(self, "error")
			toast(Loc.err(code), Color("ff9a8a"))


func _refresh_stats() -> void:
	_money.text = Loc.t("creative_badge") if client.creative else "%s %s" % [Loc.digits(str(client.money)), Loc.t("coins")]
	_clock.text = "%s   %s: %s" % [Loc.clock(client.world_time), Loc.t("energy"), Loc.digits(str(client.energy))]
	_price.text = "%s: %s  |  %s: %s" % [Loc.t("wheat_price"), Loc.digits("%.1f" % client.wheat_price),
		Loc.t("bread_price"), Loc.digits("%.1f" % client.bread_price)]
	_price.text += "  |  %s: %s  |  %s: %s" % [Loc.t("egg_price"), Loc.digits("%.1f" % client.egg_price),
		Loc.t("milk_price"), Loc.digits("%.1f" % client.milk_price)]
	_price.text += "  |  %s: %s  |  %s: %s" % [Loc.t("flour_price"), Loc.digits("%.1f" % client.flour_price),
		Loc.t("cheese_price"), Loc.digits("%.1f" % client.cheese_price)]
	_online.text = "%s: %s" % [Loc.t("online"), Loc.digits(str(client.players.size()))]
	if _info.visible and _info_id >= 0:
		_fill_info(_info_id)


func _refresh_role() -> void:
	_role.text = Loc.role_name(client.role)
	_admin_btn.visible = FWConst.is_admin(client.role)
	_god_btn.visible = FWConst.is_admin(client.role) and view.mode == "world"
	if not _god_btn.visible and _god_panel.visible:
		_toggle_god()


func _process(delta: float) -> void:
	_stat_acc += delta
	if _stat_acc > 0.4:
		_stat_acc = 0.0
		_refresh_stats()
	_update_mg_bar()
	_update_race_bar()
	_update_race_bar()
	_mine_acc += delta
	if _mine_acc > 0.25:
		_mine_acc = 0.0
		var nid: String = view.near_mine_id()
		_mine_btn.visible = nid != ""
		_mine_btn.text = Loc.t("enter_house") if nid.begins_with("h") else Loc.t("enter_mine")


func _update_mode_btn() -> void:
	_mode_btn.text = Loc.t("world_mode") if view.mode == "life" else Loc.t("life_mode")


func _update_view_btn() -> void:
	_view_btn.text = Loc.t("view_third") if view.first_person else Loc.t("view_first")
	_view_btn.visible = view.mode == "life"


func _on_mode_changed(_m: String) -> void:
	_update_mode_btn()
	_update_view_btn()
	_tools_btn.visible = view.mode == "life"
	_mg_btn.visible = view.mode == "life"
	_race_btn.visible = view.mode == "life"
	_fly_btn.visible = view.mode == "life" and client.creative and not client.boating and not client.mounted and not client.driving
	_boat_btn.visible = view.mode == "life"
	_fish_btn.visible = view.mode == "life"
	_horse_btn.visible = view.mode == "life"
	_car_btn.visible = view.mode == "life"
	_refresh_role()
	if view.mode == "world":
		_set_tools_visible(false)
	if view.mode == "world":
		toast(Loc.t("world_mode"))
	else:
		toast(Loc.t("life_mode"))


func _toggle_build() -> void:
	if view.inside_id > 0 or client.mine_id != "":
		return
	Sfx.play(self, "click")
	var on := not _palette.visible
	_palette.visible = on
	_info.visible = false
	if on:
		_set_tools_visible(false)
		view.set_tool("hand")
		_select_type("house")
	else:
		view.set_build_type("")


func _select_type(t: String) -> void:
	Sfx.play(self, "click")
	if t != "":
		_god_panel.visible = false
		view.set_god_kind("")
		for g in _god_btns:
			_god_btns[g].button_pressed = false
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
	if FWConst.PRODUCERS.has(str(b["type"])):
		body += "\n%s: %s" % [Loc.t("stock"), Loc.digits(str(int(b["stock"])))]
	if b["type"] == "bakery":
		body += "\n%s: %s" % [Loc.t("market_wheat"), Loc.digits(str(int(client.market_stock["wheat"])))]
	_info_body.text = body
	var mine: bool = b["owner"] == client.my_name
	_info_collect.visible = mine and FWConst.PRODUCERS.has(str(b["type"]))
	_info_enter.visible = FWConst.ENTERABLE.has(str(b["type"])) and (mine or str(b["type"]) != "house")
	var employed_here: bool = client.job_id == id
	if employed_here:
		body += "\n" + Loc.t("job_here")
		_info_body.text = body
	_info_job.visible = employed_here or (not mine and FWConst.JOB_TYPES.has(str(b["type"])))
	_info_job.text = Loc.t("job_quit_btn") if employed_here else Loc.t("job_take")
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
