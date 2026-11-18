extends RefCounted
## سازندهٔ مش low-poly با رنگ هر رأس. هر شیء یک مش و یک draw call است.
## جهت وجه‌ها خودکار از روی «نقطهٔ داخل شکل» درست می‌شود تا ترتیب رئوس مهم نباشد.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var idx := PackedInt32Array()


## چندضلعی محدب؛ inside یک نقطهٔ داخل شکل است تا جهت بیرونی مشخص شود.
func add_poly(points: Array, inside: Vector3, col: Color) -> void:
	var n: Vector3 = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	var centroid := Vector3.ZERO
	for p in points:
		centroid += p
	centroid /= float(points.size())
	var ordered: Array = points.duplicate()
	if n.dot(centroid - inside) < 0.0:
		n = -n
	else:
		# ترتیب فعلی خلاف‌ساعتگرد از بیرون است؛ گودو ساعتگرد را رو می‌داند.
		ordered.reverse()
	var base := verts.size()
	for p in ordered:
		verts.append(p)
		norms.append(n)
		cols.append(col)
	for i in range(1, ordered.size() - 1):
		idx.append(base)
		idx.append(base + i)
		idx.append(base + i + 1)


func add_box(center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := center
	var x := Vector3(h.x, 0, 0)
	var y := Vector3(0, h.y, 0)
	var z := Vector3(0, 0, h.z)
	add_poly([c + x - y - z, c + x + y - z, c + x + y + z, c + x - y + z], c, col)
	add_poly([c - x - y - z, c - x + y - z, c - x + y + z, c - x - y + z], c, col)
	add_poly([c - x + y - z, c + x + y - z, c + x + y + z, c - x + y + z], c, col.lightened(0.12))
	add_poly([c - x - y - z, c + x - y - z, c + x - y + z, c - x - y + z], c, col.darkened(0.3))
	add_poly([c - x - y + z, c + x - y + z, c + x + y + z, c - x + y + z], c, col.darkened(0.05))
	add_poly([c - x - y - z, c + x - y - z, c + x + y - z, c - x + y - z], c, col.darkened(0.05))


## استوانه/مخروط با محور Y؛ base مرکز قاعدهٔ پایین است.
func add_cylinder(base: Vector3, r_bottom: float, r_top: float, height: float, sides: int, col: Color) -> void:
	var inside := base + Vector3(0, height * 0.5, 0)
	for i in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var b0 := base + Vector3(cos(a0) * r_bottom, 0, sin(a0) * r_bottom)
		var b1 := base + Vector3(cos(a1) * r_bottom, 0, sin(a1) * r_bottom)
		var t0 := base + Vector3(cos(a0) * r_top, height, sin(a0) * r_top)
		var t1 := base + Vector3(cos(a1) * r_top, height, sin(a1) * r_top)
		var shade := col.darkened(0.12 * (0.5 + 0.5 * sin(a0 * 2.0)))
		if r_top <= 0.001:
			add_poly([b0, b1, t0], inside, shade)
		else:
			add_poly([b0, b1, t1, t0], inside, shade)
	if r_top > 0.001:
		var top_pts: Array = []
		for i in range(sides):
			var a := TAU * float(i) / float(sides)
			top_pts.append(base + Vector3(cos(a) * r_top, height, sin(a) * r_top))
		add_poly(top_pts, inside, col.lightened(0.1))


## سقف شیروانی؛ ریج در امتداد X.
func add_gable(center: Vector3, size: Vector3, col: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y0 := center.y - size.y * 0.5
	var y1 := center.y + size.y * 0.5
	var a := Vector3(center.x - hx, y0, center.z - hz)
	var b := Vector3(center.x + hx, y0, center.z - hz)
	var c := Vector3(center.x + hx, y0, center.z + hz)
	var d := Vector3(center.x - hx, y0, center.z + hz)
	var r0 := Vector3(center.x - hx, y1, center.z)
	var r1 := Vector3(center.x + hx, y1, center.z)
	var inside := Vector3(center.x, y0 + size.y * 0.3, center.z)
	add_poly([a, b, r1, r0], inside, col)
	add_poly([d, c, r1, r0], inside, col.darkened(0.12))
	add_poly([a, d, r0], inside, col.darkened(0.2))
	add_poly([b, c, r1], inside, col.darkened(0.2))
	add_poly([a, b, c, d], inside, col.darkened(0.4))


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func material(alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, alpha)
	return m
