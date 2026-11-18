extends RefCounted
## مش داخل ساختمان‌ها (اتاق ۸×۸ متری، نمای «خانهٔ عروسکی» با دیوار جلوی کوتاه).
## مبدأ: مرکز کف در y=0؛ در ورودی روی لبهٔ +Z.

const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")

const HALF := 4.0
const WALL_H := 3.2
## محدودهٔ حرکت شخصیت داخل اتاق (نسبت به مرکز).
const BOUND_X := 3.3
const BOUND_Z_BACK := -3.3
const BOUND_Z_FRONT := 3.6

static var _cache: Dictionary = {}


static func get_mesh(type: String) -> ArrayMesh:
	if not _cache.has(type):
		_cache[type] = _make(type)
	return _cache[type]


## نقطهٔ ورود (نسبت به مرکز اتاق).
static func entry_point() -> Vector3:
	return Vector3(0.0, 0.0, 3.0)


static func clamp_to_room(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -BOUND_X, BOUND_X), p.y, clampf(p.z, BOUND_Z_BACK, BOUND_Z_FRONT))


static func _make(type: String) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var floor_col := Color("b98f5e")
	var wall_col := Color("eadfc4")
	match type:
		"shop":
			floor_col = Color("a39f94")
			wall_col = Color("d9e3d0")
		"bakery":
			floor_col = Color("c9b08a")
			wall_col = Color("f0d9b0")
	# کف و دیوارها
	mb.add_box(Vector3(0, -0.1, 0), Vector3(HALF * 2.0 + 0.4, 0.2, HALF * 2.0 + 0.4), floor_col)
	mb.add_box(Vector3(0, WALL_H * 0.5, -HALF - 0.1), Vector3(HALF * 2.0 + 0.4, WALL_H, 0.2), wall_col)
	mb.add_box(Vector3(-HALF - 0.1, WALL_H * 0.5, 0), Vector3(0.2, WALL_H, HALF * 2.0), wall_col)
	mb.add_box(Vector3(HALF + 0.1, WALL_H * 0.5, 0), Vector3(0.2, WALL_H, HALF * 2.0), wall_col)
	mb.add_box(Vector3(0, 0.25, HALF + 0.1), Vector3(HALF * 2.0 + 0.4, 0.5, 0.2), wall_col.darkened(0.15))
	# پادری در ورودی
	mb.add_box(Vector3(0, 0.02, 3.5), Vector3(1.6, 0.04, 0.8), Color("6b4a2d"))
	match type:
		"house":
			mb.add_box(Vector3(-2.6, 0.3, -2.8), Vector3(2.0, 0.6, 1.0), Color("7a5230"))   # تخت
			mb.add_box(Vector3(-2.6, 0.7, -2.8), Vector3(1.9, 0.2, 0.95), Color("e8e0d0"))
			mb.add_box(Vector3(-3.3, 0.85, -2.8), Vector3(0.4, 0.2, 0.7), Color("9ac0e0"))   # بالش
			mb.add_box(Vector3(1.8, 0.4, -0.8), Vector3(1.6, 0.8, 1.6), Color("7a5230"))     # میز
			mb.add_box(Vector3(1.8, 0.85, -0.8), Vector3(0.4, 0.1, 0.4), Color("f6c445"))
			mb.add_box(Vector3(3.2, 1.1, -3.5), Vector3(1.2, 2.2, 0.6), Color("5c3f26"))     # کمد
			mb.add_box(Vector3(-0.2, 0.03, 0.2), Vector3(3.0, 0.06, 2.2), Color("b4523a"))   # فرش
			mb.add_box(Vector3(0.4, 1.9, -HALF + 0.02), Vector3(1.4, 1.0, 0.06), Color("9ad0e8"))  # پنجره
		"shop":
			mb.add_box(Vector3(0, 0.5, -0.8), Vector3(4.4, 1.0, 0.9), Color("7a5230"))       # پیشخوان
			mb.add_box(Vector3(0, 1.05, -0.8), Vector3(4.5, 0.1, 1.0), Color("c9b08a"))
			for i in range(3):
				var x := -2.6 + float(i) * 2.6
				mb.add_box(Vector3(x, 1.2, -3.6), Vector3(2.0, 2.4, 0.5), Color("5c3f26"))   # قفسه‌ها
				mb.add_box(Vector3(x, 1.6, -3.3), Vector3(1.7, 0.3, 0.2), Color("e8b04a"))
				mb.add_box(Vector3(x, 0.8, -3.3), Vector3(1.7, 0.3, 0.2), Color("7fb069"))
			mb.add_box(Vector3(3.0, 0.4, 1.0), Vector3(1.0, 0.8, 1.0), Color("a67c52"))      # جعبه
			mb.add_box(Vector3(-3.0, 0.4, 1.4), Vector3(1.0, 0.8, 1.0), Color("a67c52"))
		"bakery":
			mb.add_box(Vector3(-2.2, 0.9, -3.0), Vector3(2.4, 1.8, 1.6), Color("8a4a35"))    # تنور/اجاق
			mb.add_box(Vector3(-2.2, 0.9, -2.15), Vector3(1.2, 0.8, 0.1), Color("2b1d14"))
			mb.add_box(Vector3(-2.2, 2.2, -3.2), Vector3(0.7, 1.0, 0.7), Color("3b3b3b"))
			mb.add_box(Vector3(1.2, 0.5, -1.0), Vector3(3.0, 1.0, 1.0), Color("c9955e"))     # پیشخوان
			mb.add_box(Vector3(1.2, 1.05, -1.0), Vector3(3.1, 0.1, 1.1), Color("f2e2b8"))
			mb.add_box(Vector3(3.2, 1.2, -3.4), Vector3(1.2, 2.4, 0.6), Color("5c3f26"))     # قفسهٔ نان
			mb.add_box(Vector3(3.2, 1.6, -3.1), Vector3(1.0, 0.3, 0.3), Color("d9a24a"))
	return mb.build()
