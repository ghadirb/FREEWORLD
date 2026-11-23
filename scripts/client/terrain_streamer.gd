extends Node3D
## بارگذاری و تخلیهٔ چانک‌های زمین (۳۲×۳۲ متر) اطراف کانون دید + درخت‌ها (MultiMesh).

const FWConst = preload("res://scripts/core/const.gd")
const WorldGen = preload("res://scripts/world/world_generator.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")

const RES := 16
const MAX_BUILDS_PER_FRAME := 2

var world
var radius: int = 3
var trees_enabled: bool = true
var _chunks: Dictionary = {}
var _queue: Array = []
var _center := Vector2i(1 << 20, 1 << 20)
var _terrain_mat: StandardMaterial3D
var _tree_mesh: ArrayMesh
var _rock_mesh: ArrayMesh
var _clay_mesh: ArrayMesh
var _iron_mesh: ArrayMesh
var _gold_mesh: ArrayMesh
var _chest_mesh: ArrayMesh
var _tree_mat: StandardMaterial3D
## کلید «rx,rz» ← آیا این منبع هنوز برداشت‌شده است؟ (کلاینت می‌دهد)
var is_depleted: Callable = func(_k: String) -> bool: return false


func setup(world_gen, view_radius: int) -> void:
	world = world_gen
	radius = view_radius
	_terrain_mat = MeshBuilder.material()
	_tree_mat = MeshBuilder.material()
	var mb := MeshBuilder.new()
	match str(world.climate):
		"winter":
			# کاج برفی: سه طبقهٔ مخروطی تیره با کلاه سفید
			mb.add_cylinder(Vector3.ZERO, 0.2, 0.14, 1.1, 5, Color("5a4030"))
			mb.add_cylinder(Vector3(0, 0.7, 0), 1.2, 0.0, 1.7, 7, Color("2d5f48"))
			mb.add_cylinder(Vector3(0, 1.5, 0), 0.95, 0.0, 1.5, 7, Color("34705a"))
			mb.add_cylinder(Vector3(0, 2.3, 0), 0.65, 0.0, 1.3, 7, Color("3c8068"))
			mb.add_cylinder(Vector3(0, 3.0, 0), 0.3, 0.0, 0.6, 7, Color("f4f8fb"))
		"desert":
			# نخل: تنهٔ بلند و باریک با تاج پهن
			mb.add_cylinder(Vector3.ZERO, 0.17, 0.1, 3.3, 5, Color("9a7248"))
			mb.add_cylinder(Vector3(0, 3.0, 0), 1.5, 0.15, 0.45, 8, Color("4f8f3a"))
			mb.add_cylinder(Vector3(0, 3.3, 0), 0.9, 0.0, 0.5, 8, Color("68a748"))
		_:
			mb.add_cylinder(Vector3.ZERO, 0.2, 0.14, 1.3, 5, Color("6b4a2d"))
			mb.add_cylinder(Vector3(0, 0.9, 0), 1.25, 0.0, 2.2, 7, Color("2f7a3f"))
			mb.add_cylinder(Vector3(0, 1.9, 0), 0.95, 0.0, 1.8, 7, Color("3a8f4a"))
	_tree_mesh = mb.build()
	var rb := MeshBuilder.new()
	rb.add_cylinder(Vector3.ZERO, 0.95, 0.55, 0.9, 6, Color("8f9298"))
	rb.add_cylinder(Vector3(0.5, 0.0, 0.3), 0.5, 0.3, 0.55, 5, Color("7c8086"))
	_rock_mesh = rb.build()
	var cb := MeshBuilder.new()
	cb.add_cylinder(Vector3.ZERO, 1.0, 0.85, 0.22, 8, Color("c2784a"))
	cb.add_cylinder(Vector3(0.0, 0.2, 0.0), 0.6, 0.45, 0.14, 8, Color("d38b5b"))
	_clay_mesh = cb.build()
	var ib := MeshBuilder.new()
	ib.add_cylinder(Vector3.ZERO, 0.95, 0.55, 0.9, 6, Color("8f9298"))
	ib.add_cylinder(Vector3(0.35, 0.35, 0.2), 0.32, 0.2, 0.5, 5, Color("b5643c"))
	ib.add_cylinder(Vector3(-0.3, 0.3, -0.25), 0.26, 0.16, 0.45, 5, Color("c4764a"))
	_iron_mesh = ib.build()
	var gb := MeshBuilder.new()
	gb.add_cylinder(Vector3.ZERO, 0.95, 0.55, 0.9, 6, Color("7c8086"))
	gb.add_cylinder(Vector3(0.35, 0.35, 0.2), 0.32, 0.2, 0.5, 5, Color("f2c230"))
	gb.add_cylinder(Vector3(-0.3, 0.3, -0.25), 0.26, 0.16, 0.45, 5, Color("ffd84a"))
	_gold_mesh = gb.build()
	var xb := MeshBuilder.new()
	xb.add_cylinder(Vector3.ZERO, 0.7, 0.7, 0.55, 4, Color("7a4a24"))
	xb.add_cylinder(Vector3(0, 0.5, 0), 0.62, 0.45, 0.22, 4, Color("8f5a2c"))
	xb.add_cylinder(Vector3(0, 0.3, 0), 0.74, 0.74, 0.1, 4, Color("e0b030"))
	_chest_mesh = xb.build()


func set_radius(r: int) -> void:
	radius = r
	_center = Vector2i(1 << 20, 1 << 20)


func update_focus(pos: Vector3) -> void:
	var c := Vector2i(int(floor(pos.x / FWConst.CHUNK_SIZE)), int(floor(pos.z / FWConst.CHUNK_SIZE)))
	if c != _center:
		_center = c
		_refresh_queue()
	var built := 0
	while built < MAX_BUILDS_PER_FRAME and not _queue.is_empty():
		var key: Vector2i = _queue.pop_front()
		if _chunks.has(key) or _dist(key) > radius:
			continue
		_chunks[key] = _build_chunk(key)
		add_child(_chunks[key])
		built += 1


func loaded_count() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _queue.size()


func _dist(key: Vector2i) -> int:
	return maxi(absi(key.x - _center.x), absi(key.y - _center.y))


func _refresh_queue() -> void:
	for key in _chunks.keys():
		if _dist(key) > radius + 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
	_queue.clear()
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var k := Vector2i(_center.x + dx, _center.y + dz)
			if not _chunks.has(k):
				_queue.append(k)
	_queue.sort_custom(func(a, b): return _dist(a) * 1000 + absi(a.x - _center.x) + absi(a.y - _center.y) < _dist(b) * 1000 + absi(b.x - _center.x) + absi(b.y - _center.y))


func _build_chunk(c: Vector2i) -> Node3D:
	var root := Node3D.new()
	var origin := Vector2(c.x, c.y) * FWConst.CHUNK_SIZE
	var step := FWConst.CHUNK_SIZE / float(RES)
	var n1 := RES + 1
	var heights := PackedFloat32Array()
	heights.resize(n1 * n1)
	for j in range(n1):
		for i in range(n1):
			heights[j * n1 + i] = world.height_at(origin.x + i * step, origin.y + j * step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(RES):
		for i in range(RES):
			var x0 := origin.x + i * step
			var z0 := origin.y + j * step
			var ha := heights[j * n1 + i]
			var hb := heights[j * n1 + i + 1]
			var hc := heights[(j + 1) * n1 + i]
			var hd := heights[(j + 1) * n1 + i + 1]
			var a := Vector3(x0, ha, z0)
			var b := Vector3(x0 + step, hb, z0)
			var cc := Vector3(x0, hc, z0 + step)
			var d := Vector3(x0 + step, hd, z0 + step)
			var avg := (ha + hb + hc + hd) * 0.25
			var biome: String = world.biome_from(avg, world.moisture_at(x0 + step * 0.5, z0 + step * 0.5))
			var col: Color = WorldGen.biome_color(biome)
			if biome == "water":
				col = Color("c8b88a")
			col = _climate_tint(col, biome, avg)
			var jitter := float(absi(((i * 73856093) ^ (j * 19349663) ^ (c.x * 83492791) ^ (c.y * 2654435761)) % 100)) / 100.0
			col = col.darkened(0.06 * jitter).lightened(0.04 * (1.0 - jitter))
			for p in [a, b, cc]:
				st.set_color(col)
				st.add_vertex(p)
			for p in [b, d, cc]:
				st.set_color(col.darkened(0.03))
				st.add_vertex(p)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_add_resources(root, c)
	return root


## رنگ زمین بر اساس اقلیم: قلهٔ برفی و ساحل یخ‌زده در زمستان، ساحل روشن‌تر در صحرا.
func _climate_tint(col: Color, biome: String, h: float) -> Color:
	match str(world.climate):
		"winter":
			if biome == "mountain":
				return col.lerp(Color("f4f8fb"), smoothstep(14.0, 20.0, h))
			if biome == "beach":
				return col.lerp(Color("d4dde4"), 0.7)
			if biome == "water":
				return Color("9fb0b8")
		"desert":
			if biome == "beach":
				return col.lerp(Color("eed9a0"), 0.5)
	return col


## منابع قابل برداشت این چانک (درخت، سنگ، خاک رس). برداشت‌شده‌ها کشیده نمی‌شوند.
func _add_resources(root: Node3D, c: Vector2i) -> void:
	var holder := Node3D.new()
	holder.name = "res"
	root.add_child(holder)
	var per := int(FWConst.CHUNK_SIZE / FWConst.RESOURCE_CELL)
	var lists := {"tree": [], "rock": [], "clay": [], "iron_ore": [], "gold_ore": [], "chest": []}
	for j in range(per):
		for i in range(per):
			var rx := c.x * per + i
			var rz := c.y * per + j
			var n: Dictionary = world.resource_in_cell(rx, rz)
			if n.is_empty() or is_depleted.call("%d,%d" % [rx, rz]):
				continue
			var sc: float = float(n["s"])
			var basis := Basis(Vector3.UP, float(n["rot"])).scaled(Vector3(sc, sc, sc))
			lists[n["kind"]].append(Transform3D(basis, Vector3(float(n["x"]), float(n["y"]) - 0.1, float(n["z"]))))
	for kind in lists:
		var xforms: Array = lists[kind]
		if xforms.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		match kind:
			"tree": mm.mesh = _tree_mesh
			"rock": mm.mesh = _rock_mesh
			"iron_ore": mm.mesh = _iron_mesh
			"gold_ore": mm.mesh = _gold_mesh
			"chest": mm.mesh = _chest_mesh
			_: mm.mesh = _clay_mesh
		mm.instance_count = xforms.size()
		for k in range(xforms.size()):
			mm.set_instance_transform(k, xforms[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _tree_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)


## پس از تغییر زمین (کندن/پر کردن): چانک‌های درگیر حذف می‌شوند و با ارتفاع تازه دوباره ساخته می‌شوند.
func invalidate_area(x0: float, z0: float, x1: float, z1: float) -> void:
	var cs := FWConst.CHUNK_SIZE
	var cx0 := int(floor(x0 / cs))
	var cx1 := int(floor(x1 / cs))
	var cz0 := int(floor(z0 / cs))
	var cz1 := int(floor(z1 / cs))
	for cz in range(cz0, cz1 + 1):
		for cx in range(cx0, cx1 + 1):
			var key := Vector2i(cx, cz)
			if _chunks.has(key):
				_chunks[key].queue_free()
				_chunks.erase(key)
				if _dist(key) <= radius and not _queue.has(key):
					_queue.push_front(key)


## پس از برداشت یا رویش دوباره، فقط منابع همان چانک دوباره ساخته می‌شوند.
func refresh_resource(rx: int, rz: int) -> void:
	var per := int(FWConst.CHUNK_SIZE / FWConst.RESOURCE_CELL)
	var key := Vector2i(int(floor(float(rx) / float(per))), int(floor(float(rz) / float(per))))
	if not _chunks.has(key):
		return
	var root: Node3D = _chunks[key]
	var old := root.get_node_or_null("res")
	if old != null:
		root.remove_child(old)
		old.queue_free()
	_add_resources(root, key)
