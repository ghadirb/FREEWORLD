extends HBoxContainer
## عددگیر لمسی با دکمهٔ «−» و «+» (به‌جای SpinBox): کیبورد گوشی باز نمی‌شود و صفحه را نمی‌پوشاند.
## با نگه‌داشتن دکمه مقدار پشت‌سرهم تغییر می‌کند. API مثل SpinBox: min_value، max_value، step، value.

signal value_changed(v: float)

const UiTheme = preload("res://scripts/client/ui_theme.gd")
const Loc = preload("res://scripts/client/loc.gd")

var min_value: float = 0.0
var max_value: float = 100.0
var step: float = 1.0
var value: float = 0.0:
	set(v):
		value = clampf(snappedf(v, step), min_value, max_value)
		if _label != null:
			_label.text = _fmt(value)
		value_changed.emit(value)

var _label: Label
var _hold_dir: int = 0
var _hold_time: float = 0.0
var _repeat: float = 0.0


func setup(lo: float, hi: float, val: float, stp: float = 1.0) -> void:
	min_value = lo
	max_value = hi
	step = stp
	add_theme_constant_override("separation", 4)
	custom_minimum_size = Vector2(190, 52)
	var minus := _make_btn("−", -1)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(70, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	var plus := _make_btn("+", 1)
	add_child(minus)
	add_child(_label)
	add_child(plus)
	value = val


func _make_btn(txt: String, dir: int) -> Button:
	var b := UiTheme.button(txt, Vector2(52, 52))
	b.add_theme_font_size_override("font_size", 26)
	b.button_down.connect(func():
		_nudge(dir)
		_hold_dir = dir
		_hold_time = 0.0
		_repeat = 0.0)
	b.button_up.connect(func(): _hold_dir = 0)
	return b


func _nudge(dir: int) -> void:
	value = value + float(dir) * step


func _process(dt: float) -> void:
	if _hold_dir == 0:
		return
	_hold_time += dt
	if _hold_time < 0.4:
		return
	_repeat += dt
	var gap: float = 0.07 if _hold_time > 1.5 else 0.14
	if _repeat >= gap:
		_repeat = 0.0
		_nudge(_hold_dir)


func _fmt(v: float) -> String:
	var txt: String = str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
	return Loc.digits(txt)
