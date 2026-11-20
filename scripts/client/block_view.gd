extends Node3D
## نمایش بلوک‌های بازیکنان: هر ۱۶×۱۶ ستون یک چانک مش (فقط وجه‌های دیده‌شونده) + پیکینگ با پرتو.
## منطق بازی اینجا نیست؛ فقط وضعیت آینهٔ CityState کلاینت را نشان می‌دهد.

const FWConst = preload("res://scripts/core/const.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")

const CHUNK := 16
const MAX_REBUILDS_PER_FRAME := 2
const REINDEX_INTERVAL := 0.3

const BASE := {
	"dirt": Color("8b6a47"), "wood": Color("b98a55"), "stone": Color("8f9298"), "brick": Color("b5543f"),
	"glass": Color(0.66, 0.85, 0.94, 0.42), "window": Color(0.45, 0.72, 0.92, 0.5), "door": Color("7a4f2a"),
	"roof": Color("c4553c"), "fence": Color("a87a48"), "road": Color("6e6e74"), "lamp": Color("ffe9a6"),
}
## رنگ‌های ابزار رنگ‌آمیزی؛ اندیس ۰ = رنگ طبیعی بلوک.
const TINTS := [
	Color.WHITE, Color("d9483b"), Color("e8892b"), Color("f0c93a"), Color("5aae4a"), Color("2fa3a0"),
	Color("3d6fd1"), Color("8656c9"), Color("e078b0"), Color("f2f2ee"), Color("8a8d92"), Color("2e3035"),
]
const OPAQUE := ["dirt", "wood", "stone", "brick", "roof"]
const CLEAR := ["glass", "window"]

var mirror
var world
var _chunks: Dictionary = {}  # Vector2i -> {set: Dictionary, nodes: Array}
var _dirty: Dictionary = {}
var _mat_solid: StandardMaterial3D
var _mat_clear: StandardMaterial3D
var _mat_glow: StandardMaterial3D
var _reindex_pending: bool = false
var _reindex_wait: float = 0.0


static func color_of(type: String, tint: int) -> Color:
	var base: Color = BASE.get(type, Color.WHITE)
	if tint <= 0 or tint >= TINTS.size() or type == "lamp":
		return base
	var t: Color = TINTS[tint]
	return Color(t.r, t.g, t.b, base.a)


func setup(client) -> void:
	mirror = client.mirror
	world = client.mirror.world
	_mat_solid = MeshBuilder.material()
	_mat_clear = MeshBuilder.material()
	_mat_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_glow = MeshBuilder.material()
	_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	client.block_changed.connect(_on_block)
	client.blocks_loaded.connect(func(): _reindex_pending = true)
	_reindex()


func chunk_of(v: Vector3i) -> Vector2i:
	return Vector2i(int(floor(float(v.x) / float(CHUNK))), int(floor(float(v.z) / float(CHUNK))))


func _reindex() -> void:
	_reindex_pending = false
	for key in _chunks:
		for n in _chunks[key]["nodes"]:
			n.queue_free()
	_chunks.clear()
	_dirty.clear()
	for v in mirror.blocks:
		var k := chunk_of(v)
		if not _chunks.has(k):
			_chunks[k] = {"set": {}, "nodes": []}
		_chunks[k]["set"][v] = true
		_dirty[k] = true


func _on_block(v: Vector3i, type_id: int, _color: int) -> void:
	var k := chunk_of(v)
	if type_id >= 0:
		if not _chunks.has(k):
			_chunks[k] = {"set": {}, "nodes": []}
		_chunks[k]["set"][v] = true
	elif _chunks.has(k):
		_chunks[k]["set"].erase(v)
	_dirty[k] = true
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var nk := chunk_of(v + d)
		if nk != k and _chunks.has(nk):
			_dirty[nk] = true


func _process(delta: float) -> void:
	if _reindex_pending:
		_reindex_wait += delta
		if _reindex_wait >= REINDEX_INTERVAL:
			_reindex_wait = 0.0
			_reindex()
	var done := 0
	for k in _dirty.keys():
		if done >= MAX_REBUILDS_PER_FRAME:
			break
		_dirty.erase(k)
		_rebuild(k)
		done += 1


func pending_chunks() -> int:
	return _dirty.size()


func _type_at(v: Vector3i) -> String:
	var b = mirror.blocks.get(v)
	return "" if b == null else str(b[0])


func _rebuild(key: Vector2i) -> void:
	if not _chunks.has(key):
		return
	var entry: Dictionary = _chunks[key]
	for n in entry["nodes"]:
		n.queue_free()
	entry["nodes"] = []
	if entry["set"].is_empty():
		_chunks.erase(key)
		return
	var solid := MeshBuilder.new()
	var clear := MeshBuilder.new()
	var glow := MeshBuilder.new()
	for v in entry["set"]:
		var b: Array = mirror.blocks[v]
		var t := str(b[0])
		var col := color_of(t, int(b[1]))
		var c := Vector3(v.x + 0.5, v.y + 0.5, v.z + 0.5)
		match t:
			"fence":
				_fence(solid, v, c, col)
			"door":
				_door(solid, v, c, col)
			"road":
				solid.add_box(Vector3(c.x, v.y + 0.075, c.z), Vector3(1.0, 0.15, 1.0), col)
			"lamp":
				solid.add_box(Vector3(c.x, v.y + 0.3, c.z), Vector3(0.18, 0.6, 0.18), Color("55555c"))
				glow.add_box(Vector3(c.x, v.y + 0.75, c.z), Vector3(0.42, 0.34, 0.42), col)
			"glass", "window":
				_cube(clear, v, c, col, true)
			_:
				_cube(solid, v, c, col, false)
	for pair in [[solid, _mat_solid], [clear, _mat_clear], [glow, _mat_glow]]:
		var mesh: ArrayMesh = pair[0].build()
		if mesh.get_surface_count() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		entry["nodes"].append(mi)


func _hidden(neighbor: String, clear_block: bool) -> bool:
	if neighbor == "":
		return false
	if clear_block:
		return CLEAR.has(neighbor)
	return OPAQUE.has(neighbor)


func _cube(mb, v: Vector3i, c: Vector3, col: Color, clear_block: bool) -> void:
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		if _hidden(_type_at(v + d), clear_block):
			continue
		_face(mb, c, d, col)


func _face(mb, c: Vector3, d: Vector3i, col: Color) -> void:
	var n := Vector3(d)
	var u := Vector3.RIGHT
	var w := Vector3.BACK
	if d.x != 0:
		u = Vector3.UP
	elif d.z != 0:
		w = Vector3.UP
	var f := c + n * 0.5
	var shade := col
	if d.y > 0:
		shade = col.lightened(0.12)
	elif d.y < 0:
		shade = col.darkened(0.3)
	else:
		shade = col.darkened(0.05 if d.x != 0 else 0.1)
	shade.a = col.a
	mb.add_poly([f - u * 0.5 - w * 0.5, f + u * 0.5 - w * 0.5, f + u * 0.5 + w * 0.5, f - u * 0.5 + w * 0.5], c, shade)


func _fence(mb, v: Vector3i, c: Vector3, col: Color) -> void:
	mb.add_box(Vector3(c.x, v.y + 0.5, c.z), Vector3(0.2, 1.0, 0.2), col)
	for d in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
		for sign in [1, -1]:
			if _type_at(v + d * sign) != "fence":
				continue
			var half := Vector3(d) * 0.25 * float(sign)
			var size := Vector3(0.5 if d.x != 0 else 0.08, 0.08, 0.5 if d.z != 0 else 0.08)
			for ry in [0.35, 0.75]:
				mb.add_box(Vector3(c.x, v.y + ry, c.z) + half, size, col.darkened(0.08))


func _door(mb, v: Vector3i, c: Vector3, col: Color) -> void:
	var along_x := FWConst.BLOCK_TYPES.has(_type_at(v + Vector3i(1, 0, 0))) and not FWConst.block_passable(_type_at(v + Vector3i(1, 0, 0)))
	along_x = along_x or (FWConst.BLOCK_TYPES.has(_type_at(v + Vector3i(-1, 0, 0))) and not FWConst.block_passable(_type_at(v + Vector3i(-1, 0, 0))))
	var size := Vector3(1.0, 1.0, 0.14) if along_x else Vector3(0.14, 1.0, 1.0)
	mb.add_box(c, size, col)
	var knob := Vector3(c.x + (0.3 if along_x else 0.1), c.y, c.z + (0.1 if along_x else 0.3))
	mb.add_box(knob, Vector3(0.1, 0.1, 0.1), Color("d8c06a"))


## پرتو دوربین را در شبکهٔ بلوک‌ها پیش می‌برد.
## خروجی: {kind: "block", hit: Vector3i, prev: Vector3i} یا {kind: "ground", cell: Vector3i, point: Vector3}
## یا {} اگر چیزی نبود. روی آب، سطح دریا (y=0) زمین حساب می‌شود تا بشود پل ساخت.
func raycast(o: Vector3, d: Vector3, max_dist: float = 45.0) -> Dictionary:
	var prev := Vector3i(int(floor(o.x)), int(floor(o.y)), int(floor(o.z)))
	var t := 0.0
	while t < max_dist:
		var p := o + d * t
		var cell := Vector3i(int(floor(p.x)), int(floor(p.y)), int(floor(p.z)))
		if cell != prev:
			if mirror.blocks.has(cell):
				return {"kind": "block", "hit": cell, "prev": prev}
			prev = cell
		var h: float = world.height_at(p.x, p.z)
		if p.y <= maxf(h, 0.0):
			var lv := 0 if h < 0.2 else maxi(0, int(floor(h)))
			return {"kind": "ground", "cell": Vector3i(cell.x, lv, cell.z), "point": p}
		t += 0.1
	return {}
