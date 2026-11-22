extends Node3D
## نمای روستاهای از پیش‌ساخته: خانه‌های ۵×۵ با سقف شیروانی، چاه و انبار کاه.
## فقط نمایش است؛ برخورد و ورود را سرور تصمیم می‌گیرد (WorldGenerator.village_solid_at).

const FWConst = preload("res://scripts/core/const.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")
const Avatar = preload("res://scripts/client/avatar.gd")
const Loc = preload("res://scripts/client/loc.gd")

const SHOW_DISTANCE := 280.0
const WALLS := [Color("e6d5b0"), Color("d9b98a"), Color("c9d2d8"), Color("cfe0b8")]
const ROOFS := [Color("a8483a"), Color("7a5a3c"), Color("56606c"), Color("b88a3c")]

static var _mesh_cache: Dictionary = {}

var world
var mat: StandardMaterial3D
var _nodes: Dictionary = {}    # id روستا -> Node3D
var _acc: float = 0.0


func setup(world_gen) -> void:
	world = world_gen
	mat = MeshBuilder.material()
	for v in world.villages():
		var n := Node3D.new()
		n.name = "V" + str(v["id"]).replace(",", "_").replace("-", "m")
		for h in v["houses"]:
			var mi := MeshInstance3D.new()
			mi.mesh = _house_mesh(int(h["tone"]))
			mi.material_override = mat
			mi.position = Vector3(float(h["cx"]), float(h["y"]), float(h["cz"]))
			mi.rotation.y = float(h["yaw"])
			n.add_child(mi)
		var well := MeshInstance3D.new()
		well.mesh = _well_mesh()
		well.material_override = mat
		well.position = Vector3(float(v["x"]), float(v["y"]), float(v["z"]))
		n.add_child(well)
		for k in range(2):
			var a: float = float(k) * 2.4 + float(absi(hash(str(v["id"]))) % 100) / 30.0
			var hx: float = float(v["x"]) + cos(a) * 4.6
			var hz: float = float(v["z"]) + sin(a) * 4.6
			var hay := MeshInstance3D.new()
			hay.mesh = _hay_mesh()
			hay.material_override = mat
			hay.position = Vector3(hx, world.base_height_at(hx, hz), hz)
			n.add_child(hay)
		var lbl := Label3D.new()
		lbl.text = Loc.t("village_name")
		lbl.font = Avatar.font()
		lbl.font_size = 44
		lbl.pixel_size = 0.012
		lbl.outline_size = 10
		lbl.language = "fa" if Loc.lang == "fa" else ""
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(float(v["x"]), float(v["y"]) + 7.5, float(v["z"]))
		lbl.modulate = Color("ffe9a8")
		n.add_child(lbl)
		add_child(n)
		_nodes[str(v["id"])] = {"node": n, "x": float(v["x"]), "z": float(v["z"])}


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f: Vector3 = cam.global_position
	for id in _nodes:
		var d: Dictionary = _nodes[id]
		d["node"].visible = Vector2(d["x"], d["z"]).distance_to(Vector2(f.x, f.z)) < SHOW_DISTANCE


static func _house_mesh(tone: int) -> ArrayMesh:
	var key := "house%d" % tone
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mb := MeshBuilder.new()
	var wall: Color = WALLS[tone % WALLS.size()]
	var roof: Color = ROOFS[tone % ROOFS.size()]
	var hf := FWConst.HOUSE_HALF
	# پی سنگی تا زمین ناهموار را بپوشاند.
	mb.add_box(Vector3(0, -0.9, 0), Vector3(hf * 2.0 + 0.3, 2.2, hf * 2.0 + 0.3), Color("7d7a73"))
	mb.add_box(Vector3(0, 1.4, 0), Vector3(hf * 2.0, 2.8, hf * 2.0), wall)
	mb.add_box(Vector3(0, 2.85, 0), Vector3(hf * 2.0 + 0.1, 0.12, hf * 2.0 + 0.1), wall.darkened(0.18))
	# شیروانی: دو شیب و دو سه‌گوش.
	var eave := 3.0
	var ex := hf + 0.4
	var ridge := 4.6
	var inside := Vector3(0, 2.6, 0)
	mb.add_poly([Vector3(-ex, 2.8, eave), Vector3(ex, 2.8, eave), Vector3(ex, ridge, 0), Vector3(-ex, ridge, 0)], inside, roof)
	mb.add_poly([Vector3(ex, 2.8, -eave), Vector3(-ex, 2.8, -eave), Vector3(-ex, ridge, 0), Vector3(ex, ridge, 0)], inside, roof.darkened(0.1))
	mb.add_poly([Vector3(hf, 2.8, -hf), Vector3(hf, 2.8, hf), Vector3(hf, 4.4, 0)], inside, wall.darkened(0.08))
	mb.add_poly([Vector3(-hf, 2.8, hf), Vector3(-hf, 2.8, -hf), Vector3(-hf, 4.4, 0)], inside, wall.darkened(0.08))
	# در (محور +Z)، پنجره‌ها و دودکش.
	mb.add_box(Vector3(0, 1.0, hf + 0.04), Vector3(1.2, 2.0, 0.12), Color("5a3a1e"))
	mb.add_box(Vector3(0.45, 1.0, hf + 0.12), Vector3(0.1, 0.12, 0.08), Color("ffcf5a"))
	mb.add_box(Vector3(-1.75, 1.7, hf + 0.04), Vector3(0.8, 0.8, 0.1), Color("a9cfe8"))
	mb.add_box(Vector3(1.75, 1.7, hf + 0.04), Vector3(0.8, 0.8, 0.1), Color("a9cfe8"))
	mb.add_box(Vector3(0, 0.12, hf + 0.5), Vector3(1.8, 0.24, 1.0), Color("8b887f"))
	mb.add_box(Vector3(1.4, 4.6, -0.8), Vector3(0.6, 1.4, 0.6), Color("85766a"))
	var m := mb.build()
	_mesh_cache[key] = m
	return m


static func _well_mesh() -> ArrayMesh:
	if _mesh_cache.has("well"):
		return _mesh_cache["well"]
	var mb := MeshBuilder.new()
	mb.add_cylinder(Vector3(0, -0.4, 0), 1.0, 1.0, 1.4, 10, Color("8b887f"))
	mb.add_cylinder(Vector3(0, 0.95, 0), 0.75, 0.75, 0.05, 10, Color("2f6f9f"))
	mb.add_box(Vector3(-0.9, 1.4, 0), Vector3(0.16, 2.0, 0.16), Color("7a5230"))
	mb.add_box(Vector3(0.9, 1.4, 0), Vector3(0.16, 2.0, 0.16), Color("7a5230"))
	mb.add_box(Vector3(0, 2.5, 0), Vector3(2.4, 0.16, 0.2), Color("8a6038"))
	mb.add_poly([Vector3(-1.4, 2.4, 1.0), Vector3(1.4, 2.4, 1.0), Vector3(1.4, 3.1, 0), Vector3(-1.4, 3.1, 0)], Vector3(0, 2.4, 0), Color("a8483a"))
	mb.add_poly([Vector3(1.4, 2.4, -1.0), Vector3(-1.4, 2.4, -1.0), Vector3(-1.4, 3.1, 0), Vector3(1.4, 3.1, 0)], Vector3(0, 2.4, 0), Color("8c3a2e"))
	var m := mb.build()
	_mesh_cache["well"] = m
	return m


static func _hay_mesh() -> ArrayMesh:
	if _mesh_cache.has("hay"):
		return _mesh_cache["hay"]
	var mb := MeshBuilder.new()
	mb.add_cylinder(Vector3(0, 0, 0), 0.8, 0.7, 1.1, 8, Color("d9b44a"))
	mb.add_cylinder(Vector3(0, 1.1, 0), 0.7, 0.0, 0.6, 8, Color("c9a23c"))
	var m := mb.build()
	_mesh_cache["hay"] = m
	return m
