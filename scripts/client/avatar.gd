extends Node3D
## شخصیت بازیکن یا NPC با برچسب نام. حرکت نرم به سمت target.

const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")

static var _font: Font = null

var target: Vector3 = Vector3.ZERO
var target_yaw: float = 0.0
var label: Label3D
var sub_label: Label3D
var body: MeshInstance3D
var _phase: float = 0.0
var _moving: bool = false
var boat_node: MeshInstance3D = null
var horse_node: MeshInstance3D = null
var _boat_t: float = 0.0


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Vazirmatn-Regular.ttf")
	return _font


func setup(display_name: String, shirt: Color, is_npc: bool) -> void:
	var mb := MeshBuilder.new()
	var skin := Color("e0b48a") if not is_npc else Color("d9a87c")
	mb.add_box(Vector3(-0.14, 0.4, 0), Vector3(0.22, 0.8, 0.24), Color("3d4a66"))
	mb.add_box(Vector3(0.14, 0.4, 0), Vector3(0.22, 0.8, 0.24), Color("3d4a66"))
	mb.add_box(Vector3(0, 1.1, 0), Vector3(0.62, 0.7, 0.34), shirt)
	mb.add_box(Vector3(-0.4, 1.1, 0), Vector3(0.14, 0.62, 0.2), shirt.darkened(0.15))
	mb.add_box(Vector3(0.4, 1.1, 0), Vector3(0.14, 0.62, 0.2), shirt.darkened(0.15))
	mb.add_box(Vector3(0, 1.67, 0), Vector3(0.38, 0.38, 0.38), skin)
	mb.add_box(Vector3(0, 1.87, -0.02), Vector3(0.42, 0.14, 0.42), Color("3b2a1e"))
	body = MeshInstance3D.new()
	body.mesh = mb.build()
	body.material_override = MeshBuilder.material()
	add_child(body)
	label = Label3D.new()
	label.text = display_name
	label.font = font()
	label.font_size = 64
	label.pixel_size = 0.005
	label.outline_size = 8
	label.language = "fa" if _has_arabic(display_name) else ""
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.55 if is_npc else 2.3, 0)
	label.no_depth_test = true
	label.modulate = Color("ffffff") if not is_npc else Color("bfe3ff")
	add_child(label)
	if is_npc:
		sub_label = Label3D.new()
		sub_label.font = font()
		sub_label.font_size = 44
		sub_label.pixel_size = 0.004
		sub_label.outline_size = 6
		sub_label.language = "fa"
		sub_label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sub_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sub_label.position = Vector3(0, 2.2, 0)
		sub_label.no_depth_test = true
		sub_label.modulate = Color("e8e8e8")
		add_child(sub_label)


static func _has_arabic(t: String) -> bool:
	for ch in t:
		var c: int = ch.unicode_at(0)
		if c >= 0x0600 and c <= 0x06FF:
			return true
	return false


static func color_for(player_name: String) -> Color:
	var h := float(hash(player_name) % 360) / 360.0
	return Color.from_hsv(h, 0.55, 0.85)


## قایق زیر پای شخصیت (پروتکل ۲۴): بدنه و دماغهٔ low-poly، بالای آب کمی تکان می‌خورد.
func set_boat(on: bool) -> void:
	if on == (boat_node != null):
		return
	if not on:
		boat_node.queue_free()
		boat_node = null
		return
	var mb := MeshBuilder.new()
	var wood := Color("8a5a35")
	var dark := Color("5e3b22")
	mb.add_box(Vector3(0, 0.05, 0), Vector3(1.2, 0.4, 2.2), wood)
	mb.add_box(Vector3(0, 0.05, 1.35), Vector3(0.7, 0.36, 0.7), wood)
	mb.add_box(Vector3(0, 0.05, 1.8), Vector3(0.3, 0.32, 0.4), wood)
	mb.add_box(Vector3(-0.62, 0.3, 0), Vector3(0.1, 0.16, 2.2), dark)
	mb.add_box(Vector3(0.62, 0.3, 0), Vector3(0.1, 0.16, 2.2), dark)
	mb.add_box(Vector3(0, 0.3, -1.1), Vector3(1.34, 0.16, 0.1), dark)
	boat_node = MeshInstance3D.new()
	boat_node.mesh = mb.build()
	boat_node.material_override = MeshBuilder.material()
	boat_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(boat_node)


## اسب زیر شخصیت (پروتکل ۲۶): بدنه، گردن و سر، چهار پا و دم؛ سوار روی آن می‌نشیند.
func set_horse(on: bool) -> void:
	if on == (horse_node != null):
		return
	if not on:
		horse_node.queue_free()
		horse_node = null
		return
	var mb := MeshBuilder.new()
	var coat := Color("8b5a2b")
	var dark := Color("3b2412")
	mb.add_box(Vector3(0, 0.62, 0), Vector3(0.55, 0.5, 1.5), coat)           # بدنه
	mb.add_box(Vector3(0, 0.95, 0.85), Vector3(0.3, 0.6, 0.35), coat)        # گردن
	mb.add_box(Vector3(0, 1.2, 1.1), Vector3(0.28, 0.3, 0.55), coat)         # سر
	mb.add_box(Vector3(0, 0.95, 0.55), Vector3(0.12, 0.3, 0.35), dark)       # یال
	mb.add_box(Vector3(0, 0.8, -0.85), Vector3(0.12, 0.5, 0.15), dark)       # دم
	for lx in [-0.18, 0.18]:
		for lz in [-0.55, 0.55]:
			mb.add_box(Vector3(lx, 0.18, lz), Vector3(0.14, 0.4, 0.14), dark)
	mb.add_box(Vector3(0, 0.9, 0.0), Vector3(0.6, 0.06, 0.5), Color("9a2f2f"))  # زین
	horse_node = MeshInstance3D.new()
	horse_node.mesh = mb.build()
	horse_node.material_override = MeshBuilder.material()
	horse_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(horse_node)


func teleport_to(p: Vector3) -> void:
	position = p
	target = p


func _process(delta: float) -> void:
	if boat_node != null:
		_boat_t += delta
		boat_node.position.y = -0.12 + sin(_boat_t * 2.1) * 0.03
		boat_node.rotation.z = sin(_boat_t * 1.4) * 0.025
	var k := 1.0 - exp(-12.0 * delta)
	var before := position
	position = position.lerp(target, k)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))
	var speed := before.distance_to(position) / maxf(delta, 0.0001)
	_moving = speed > 0.4
	if _moving:
		_phase += delta * 11.0
		body.position.y = absf(sin(_phase)) * 0.07
		body.rotation.z = sin(_phase) * 0.04
	else:
		body.position.y = lerpf(body.position.y, 0.0, 0.2)
		body.rotation.z = lerpf(body.rotation.z, 0.0, 0.2)
