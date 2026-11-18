extends RefCounted
## مش ساختمان‌ها. مبدأ: مرکز زیربنا در صفحهٔ XZ و y=0 روی ارتفاع پایه؛ پی تا ۱٫۶ متر پایین می‌رود.

const FWConst = preload("res://scripts/core/const.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")

static var _cache: Dictionary = {}

const STONE := Color("8b8b84")
const WALL := Color("e9dcb8")
const ROOF := Color("b4523a")
const WOOD := Color("7a5230")


static func get_mesh(type: String) -> ArrayMesh:
	if not _cache.has(type):
		_cache[type] = _make(type)
	return _cache[type]


static func footprint_size(type: String) -> Vector2:
	var s: Array = FWConst.building_size(type)
	return Vector2(float(s[0]), float(s[1])) * FWConst.CELL_SIZE


static func _foundation(mb, fp: Vector2, inset: float = 0.0) -> void:
	mb.add_box(Vector3(0, -0.8, 0), Vector3(fp.x - inset, 1.6, fp.y - inset), STONE)


static func _make(type: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var fp := footprint_size(type)
	match type:
		"house":
			_foundation(mb, fp, 0.1)
			mb.add_box(Vector3(0, 1.2, 0), Vector3(3.3, 2.4, 3.3), WALL)
			mb.add_gable(Vector3(0, 2.4 + 0.7, 0), Vector3(4.0, 1.4, 3.9), ROOF)
			mb.add_box(Vector3(0, 0.85, 1.68), Vector3(0.8, 1.7, 0.08), WOOD)
			mb.add_box(Vector3(-1.0, 1.5, 1.68), Vector3(0.6, 0.6, 0.06), Color("7fb2d4"))
			mb.add_box(Vector3(1.0, 1.5, 1.68), Vector3(0.6, 0.6, 0.06), Color("7fb2d4"))
			mb.add_box(Vector3(1.0, 3.6, -0.5), Vector3(0.5, 1.2, 0.5), STONE)
		"shop":
			_foundation(mb, fp, 0.1)
			mb.add_box(Vector3(0, 1.4, -0.2), Vector3(3.6, 2.8, 3.2), Color("f0d9a8"))
			mb.add_box(Vector3(0, 3.0, -0.2), Vector3(3.9, 0.4, 3.5), Color("5c6f8a"))
			mb.add_box(Vector3(0, 2.35, 1.55), Vector3(3.8, 0.12, 1.1), Color("c4443a"))
			mb.add_box(Vector3(-1.2, 1.1, 1.62), Vector3(0.1, 2.2, 0.1), WOOD)
			mb.add_box(Vector3(1.2, 1.1, 1.62), Vector3(0.1, 2.2, 0.1), WOOD)
			mb.add_box(Vector3(0, 1.0, 1.42), Vector3(1.0, 2.0, 0.08), WOOD)
			mb.add_box(Vector3(-1.1, 1.4, 1.42), Vector3(0.9, 0.9, 0.06), Color("9ad0e8"))
			mb.add_box(Vector3(1.1, 1.4, 1.42), Vector3(0.9, 0.9, 0.06), Color("9ad0e8"))
			mb.add_box(Vector3(0, 3.5, 1.0), Vector3(1.6, 0.5, 0.1), Color("f6c445"))
		"farm":
			mb.add_box(Vector3(0, -0.8, 0), Vector3(fp.x - 0.2, 1.6, fp.y - 0.2), Color("6b4a2d"))
			mb.add_box(Vector3(0, 0.04, 0), Vector3(fp.x - 0.4, 0.08, fp.y - 0.4), Color("7b5634"))
			for i in range(6):
				var z := -2.4 + float(i) * 0.96
				mb.add_box(Vector3(0, 0.3, z), Vector3(fp.x - 1.0, 0.5, 0.5), Color("c9b447").lerp(Color("8ab04a"), float(i % 2) * 0.5))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					mb.add_box(Vector3(sx * (fp.x * 0.5 - 0.2), 0.5, sz * (fp.y * 0.5 - 0.2)), Vector3(0.18, 1.0, 0.18), WOOD)
			mb.add_box(Vector3(0, 0.9, fp.y * 0.5 - 0.2), Vector3(fp.x - 0.4, 0.1, 0.1), WOOD)
		"bakery":
			_foundation(mb, fp, 0.1)
			mb.add_box(Vector3(0, 1.3, -0.1), Vector3(3.5, 2.6, 3.3), Color("c98b5e"))
			mb.add_gable(Vector3(0, 2.6 + 0.6, -0.1), Vector3(4.0, 1.2, 3.8), Color("7a3f2b"))
			mb.add_box(Vector3(-1.1, 3.9, -0.9), Vector3(0.7, 1.8, 0.7), STONE)
			mb.add_box(Vector3(-1.1, 4.9, -0.9), Vector3(0.9, 0.2, 0.9), Color("3b3b3b"))
			mb.add_box(Vector3(0, 0.9, 1.58), Vector3(0.9, 1.8, 0.08), WOOD)
			mb.add_box(Vector3(1.05, 1.4, 1.58), Vector3(0.9, 0.9, 0.06), Color("ffe3a0"))
			mb.add_box(Vector3(-1.05, 1.4, 1.58), Vector3(0.9, 0.9, 0.06), Color("ffe3a0"))
			mb.add_box(Vector3(0, 2.3, 1.75), Vector3(3.6, 0.1, 0.9), Color("f2e2b8"))
			mb.add_box(Vector3(0, 2.75, 1.5), Vector3(1.4, 0.4, 0.1), Color("e8b04a"))
		"coop":
			_foundation(mb, fp, 0.1)
			mb.add_box(Vector3(0, 0.9, 0), Vector3(fp.x - 0.7, 1.8, fp.y - 0.9), Color("d9b36a"))
			mb.add_gable(Vector3(0, 1.8 + 0.4, 0), Vector3(fp.x - 0.3, 0.9, fp.y - 0.5), Color("a6452f"))
			mb.add_box(Vector3(0, 0.6, fp.y * 0.5 - 0.42), Vector3(0.6, 1.0, 0.08), WOOD)
			mb.add_box(Vector3(1.2, 0.25, fp.y * 0.5 - 0.1), Vector3(0.9, 0.5, 0.5), Color("f4f0e0"))
		"barn":
			_foundation(mb, fp, 0.1)
			mb.add_box(Vector3(0, 1.4, 0), Vector3(fp.x - 0.6, 2.8, fp.y - 0.6), Color("b23b2e"))
			mb.add_gable(Vector3(0, 2.8 + 0.7, 0), Vector3(fp.x - 0.2, 1.4, fp.y - 0.2), Color("5a3a2a"))
			mb.add_box(Vector3(0, 1.0, fp.y * 0.5 - 0.3), Vector3(1.6, 2.0, 0.1), Color("f4f0e0"))
			mb.add_box(Vector3(fp.x * 0.5 - 0.2, 1.6, 0), Vector3(0.6, 3.2, 0.6), Color("c9c9c9"))
		"road":
			mb.add_box(Vector3(0, -0.8, 0), Vector3(fp.x, 1.6, fp.y), Color("5f5f5f"))
			mb.add_box(Vector3(0, 0.05, 0), Vector3(fp.x, 0.1, fp.y), Color("707070"))
			mb.add_box(Vector3(0, 0.11, 0), Vector3(0.12, 0.02, fp.y * 0.6), Color("e8d76a"))
		"well":
			mb.add_box(Vector3(0, -0.8, 0), Vector3(fp.x - 0.4, 1.6, fp.y - 0.4), STONE)
			mb.add_cylinder(Vector3(0, 0, 0), 0.75, 0.7, 0.8, 8, Color("a39f94"))
			mb.add_cylinder(Vector3(0, 0.7, 0), 0.5, 0.5, 0.12, 8, Color("3b7fa8"))
			mb.add_box(Vector3(-0.7, 1.2, 0), Vector3(0.12, 1.4, 0.12), WOOD)
			mb.add_box(Vector3(0.7, 1.2, 0), Vector3(0.12, 1.4, 0.12), WOOD)
			mb.add_gable(Vector3(0, 2.1, 0), Vector3(1.8, 0.7, 1.6), ROOF)
	return mb.build()
