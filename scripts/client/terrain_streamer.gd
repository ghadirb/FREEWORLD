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
var _tree_mat: StandardMaterial3D


func setup(world_gen, view_radius: int) -> void:
	world = world_gen
	radius = view_radius
	_terrain_mat = MeshBuilder.material()
	_tree_mat = MeshBuilder.material()
	var mb := MeshBuilder.new()
	mb.add_cylinder(Vector3.ZERO, 0.2, 0.14, 1.3, 5, Color("6b4a2d"))
	mb.add_cylinder(Vector3(0, 0.9, 0), 1.25, 0.0, 2.2, 7, Color("2f7a3f"))
	mb.add_cylinder(Vector3(0, 1.9, 0), 0.95, 0.0, 1.8, 7, Color("3a8f4a"))
	_tree_mesh = mb.build()


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
	if trees_enabled:
		_add_trees(root, c, origin)
	return root


func _add_trees(root: Node3D, c: Vector2i, origin: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, world.seed_value))
	var xforms: Array = []
	for i in range(14):
		var x := origin.x + rng.randf() * FWConst.CHUNK_SIZE
		var z := origin.y + rng.randf() * FWConst.CHUNK_SIZE
		var chance := rng.randf()
		var scale := 0.8 + rng.randf() * 0.7
		var yaw := rng.randf() * TAU
		if not world.is_outside_city(x, z):
			continue
		var h: float = world.height_at(x, z)
		var biome: String = world.biome_from(h, world.moisture_at(x, z))
		var p := 0.0
		if biome == "forest":
			p = 0.95
		elif biome == "plain":
			p = 0.18
		if chance > p or h < 0.5 or h > 13.0:
			continue
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale)), Vector3(x, h - 0.1, z))
		xforms.append(xf)
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _tree_mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _tree_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
