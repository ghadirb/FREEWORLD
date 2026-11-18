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
	label.font_size = 40
	label.pixel_size = 0.008
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.25, 0)
	label.no_depth_test = true
	label.modulate = Color("ffffff") if not is_npc else Color("bfe3ff")
	add_child(label)
	if is_npc:
		sub_label = Label3D.new()
		sub_label.font = font()
		sub_label.font_size = 30
		sub_label.pixel_size = 0.007
		sub_label.outline_size = 8
		sub_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sub_label.position = Vector3(0, 2.0, 0)
		sub_label.no_depth_test = true
		sub_label.modulate = Color("e8e8e8")
		add_child(sub_label)


static func color_for(player_name: String) -> Color:
	var h := float(hash(player_name) % 360) / 360.0
	return Color.from_hsv(h, 0.55, 0.85)


func teleport_to(p: Vector3) -> void:
	position = p
	target = p


func _process(delta: float) -> void:
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
