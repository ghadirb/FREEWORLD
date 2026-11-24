extends Control
## گالری جهان‌های آماده: هر جهان یک کارت با تصویر واقعی (از همان Seed و سازه‌ها)، توضیح و آمار.
## زدن روی تصویر یعنی ورود؛ جهان‌های ویژه (پرتر) بالا و با نشان ⭐ می‌آیند.

const Loc = preload("res://scripts/client/loc.gd")
const UiTheme = preload("res://scripts/client/ui_theme.gd")
const Scenarios = preload("res://scripts/shared/scenarios.gd")
const Entitlements = preload("res://scripts/client/entitlements.gd")
const WorldPreview = preload("res://scripts/client/world_preview.gd")

## fresh=true یعنی حتی اگر از این جهان دارید، یک نسخهٔ تازه بساز.
signal picked(scenario_id: String, fresh: bool)
signal closed

var _status: Label
var _have: Dictionary = {}   # scenario id -> true اگر کاربر از آن جهان دارد


func setup(existing_scenarios: Array) -> void:
	for id in existing_scenarios:
		_have[str(id)] = true


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.lang == "fa" else Control.LAYOUT_DIRECTION_LTR
	var bg := ColorRect.new()
	bg.color = Color("0d2230")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 8)
	add_child(root)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	var back := UiTheme.button("‹ " + Loc.t("gallery_back"), Vector2(150, 54))
	back.pressed.connect(func(): closed.emit())
	head.add_child(back)
	var title := Label.new()
	title.text = Loc.t("gallery_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	head.add_child(title)
	var hint := Label.new()
	hint.text = Loc.t("gallery_hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.add_theme_font_size_override("font_size", 18)
	root.add_child(hint)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 18)
	root.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	for premium in [true, false]:
		var ids: Array = []
		for id in Scenarios.ids():
			if Scenarios.is_premium(id) == premium:
				ids.append(id)
		if ids.is_empty():
			continue
		var h := Label.new()
		h.text = Loc.t("gallery_premium" if premium else "gallery_free")
		h.add_theme_font_size_override("font_size", 26)
		h.add_theme_color_override("font_color", UiTheme.ACCENT if premium else Color("9fd6a8"))
		col.add_child(h)
		var grid := GridContainer.new()
		grid.columns = 3 if (is_inside_tree() and get_viewport_rect().size.x >= 1100.0) else 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		col.add_child(grid)
		for id in ids:
			grid.add_child(_card(str(id)))


func _card(id: String) -> Control:
	var premium := Scenarios.is_premium(id)
	var locked := not Entitlements.is_unlocked(id)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UiTheme.box(UiTheme.BG, 18, UiTheme.ACCENT if premium else Color(1, 1, 1, 0.12), 3 if premium else 2)
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var frame := AspectRatioContainer.new()
	frame.ratio = float(WorldPreview.W) / float(WorldPreview.H)
	frame.custom_minimum_size = Vector2(0, 340)
	v.add_child(frame)
	var pic := TextureButton.new()
	pic.texture_normal = WorldPreview.texture(id)
	pic.ignore_texture_size = true
	pic.stretch_mode = TextureButton.STRETCH_SCALE
	pic.focus_mode = Control.FOCUS_NONE
	pic.pressed.connect(func(): _pick(id, false))
	frame.add_child(pic)
	var name := Label.new()
	var tag := ("⭐ " + Loc.t("scen_premium")) if premium else Loc.t("gallery_free_tag")
	name.text = "%s   %s" % [Loc.t("scen_" + id), tag]
	name.add_theme_font_size_override("font_size", 26)
	name.add_theme_color_override("font_color", UiTheme.ACCENT if premium else Color.WHITE)
	v.add_child(name)
	var st := WorldPreview.stats(id)
	var stats := Label.new()
	stats.text = Loc.t("gallery_stats") % [Loc.digits(str(st["structures"])), Loc.digits(str(st["npcs"])), Loc.digits(str(st["animals"])), Loc.digits(str(st["trees"]))]
	stats.add_theme_font_size_override("font_size", 16)
	stats.modulate = Color(1, 1, 1, 0.8)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(stats)
	var desc := Label.new()
	desc.text = Loc.t("scen_%s_desc" % id)
	desc.add_theme_font_size_override("font_size", 16)
	desc.modulate = Color(1, 1, 1, 0.7)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var have: bool = _have.has(id)
	var go := UiTheme.button(Loc.t("gallery_locked") if locked else Loc.t("gallery_continue" if have else "gallery_enter"), Vector2(0, 52))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = locked
	go.pressed.connect(func(): _pick(id, false))
	row.add_child(go)
	if have and not locked:
		var fresh := UiTheme.button(Loc.t("gallery_new"), Vector2(0, 52))
		fresh.pressed.connect(func(): _pick(id, true))
		row.add_child(fresh)
	return panel


func _pick(id: String, fresh: bool) -> void:
	picked.emit(id, fresh)


func set_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color("ff9a8a") if is_error else Color("d6e4ff"))
