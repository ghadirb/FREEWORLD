extends RefCounted
## پوستهٔ مشترک رابط: فونت فارسی، دکمه‌های درشت مناسب لمس و پنل‌های گرد.

const ACCENT := Color("f2b134")
const BG := Color(0.06, 0.09, 0.14, 0.86)
const BG_LIGHT := Color(0.13, 0.18, 0.26, 0.92)


static func box(color: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


static func make() -> Theme:
	var th := Theme.new()
	var f: Font = load("res://assets/fonts/Vazirmatn-Regular.ttf")
	th.default_font = f
	th.default_font_size = 24
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := BG_LIGHT
		var border := Color(1, 1, 1, 0.12)
		match state:
			"hover":
				c = BG_LIGHT.lightened(0.1)
			"pressed":
				c = ACCENT.darkened(0.25)
				border = ACCENT
			"disabled":
				c = BG.darkened(0.2)
			"focus":
				c = Color(0, 0, 0, 0)
				border = ACCENT
		var sb := box(c, 14, border, 2)
		th.set_stylebox(state, "Button", sb)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.4))
	th.set_stylebox("panel", "PanelContainer", box(BG, 18, Color(1, 1, 1, 0.1), 2))
	th.set_stylebox("normal", "LineEdit", box(Color(0.02, 0.04, 0.07, 0.9), 10, Color(1, 1, 1, 0.2), 2))
	th.set_stylebox("focus", "LineEdit", box(Color(0.02, 0.04, 0.07, 0.95), 10, ACCENT, 2))
	th.set_color("font_color", "Label", Color.WHITE)
	th.set_constant("outline_size", "Label", 0)
	return th


static func button(text: String, min_size: Vector2 = Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b
