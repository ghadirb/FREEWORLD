extends Node3D
## نمای معدن: (۱) درگاه غار روی کوه‌ها در جهان بیرون، (۲) تونل‌های زیرزمینی با سنگ معدن.
## منطق بازی اینجا نیست؛ سرور تصمیم می‌گیرد و این فقط وضعیت را نشان می‌دهد.
## داخل معدن همه‌چیز در یک چارچوب محلی ساخته می‌شود که در ORIGIN (بالای آسمان جهان) قرار دارد.

const FWConst = preload("res://scripts/core/const.gd")
const Mine = preload("res://scripts/shared/mine.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")
const Avatar = preload("res://scripts/client/avatar.gd")
const Loc = preload("res://scripts/client/loc.gd")

const ORIGIN := Vector3(900.0, 300.0, 900.0)
const WALL_H := 2.7
const PICK_RADIUS := 1.0
const SHOW_DISTANCE := 260.0

static var _mesh_cache: Dictionary = {}

var world
var mat: StandardMaterial3D
var _portals: Dictionary = {}          # id -> Node3D
var _root: Node3D                       # صحنهٔ زیرزمینی (فقط داخل معدن)
var _lamp: OmniLight3D
var _ore_nodes: Dictionary = {}        # idx -> MeshInstance3D
var _layout: Dictionary = {}
var _mine_id: String = ""
var _acc: float = 0.0


func setup(world_gen) -> void:
	world = world_gen
	mat = MeshBuilder.material()
	for e in world.mine_entrances():
		var n := _make_portal(e)
		add_child(n)
		_portals[str(e["id"])] = n


# ---------------- درگاه غار روی کوه ----------------

func _make_portal(e: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(float(e["x"]), float(e["y"]), float(e["z"]))
	n.rotation.y = float(e["yaw"])    # محور +Z گره به سمت بیرونِ کوه است
	var mi := MeshInstance3D.new()
	mi.mesh = _portal_mesh()
	mi.material_override = mat
	n.add_child(mi)
	var lbl := Label3D.new()
	lbl.text = Loc.t("mine_name")
	lbl.font = Avatar.font()
	lbl.font_size = 40
	lbl.pixel_size = 0.01
	lbl.outline_size = 10
	lbl.language = "fa" if Loc.lang == "fa" else ""
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 4.6, 0.8)
	lbl.modulate = Color("ffd24a")
	n.add_child(lbl)
	return n


static func _portal_mesh() -> ArrayMesh:
	if _mesh_cache.has("portal"):
		return _mesh_cache["portal"]
	var mb := MeshBuilder.new()
	var rock := Color("77736c")
	# ستون‌ها و سردر سنگی، تونل تاریک در عمق، قاب چوبی و چراغ.
	mb.add_box(Vector3(-1.7, 1.8, 0.2), Vector3(1.0, 3.6, 1.6), rock)
	mb.add_box(Vector3(1.7, 1.8, 0.2), Vector3(1.0, 3.6, 1.6), rock.darkened(0.08))
	mb.add_box(Vector3(0, 3.9, 0.2), Vector3(4.6, 1.0, 1.6), rock.lightened(0.05))
	mb.add_box(Vector3(0, 1.6, -0.4), Vector3(2.4, 3.2, 0.6), Color("0b0b0e"))
	mb.add_box(Vector3(-1.05, 1.5, 1.05), Vector3(0.22, 3.0, 0.22), Color("7a5230"))
	mb.add_box(Vector3(1.05, 1.5, 1.05), Vector3(0.22, 3.0, 0.22), Color("7a5230"))
	mb.add_box(Vector3(0, 3.1, 1.05), Vector3(2.5, 0.25, 0.25), Color("8a6038"))
	mb.add_box(Vector3(-1.3, 2.6, 1.15), Vector3(0.2, 0.3, 0.2), Color("ffcf5a"))
	mb.add_box(Vector3(1.3, 2.6, 1.15), Vector3(0.2, 0.3, 0.2), Color("ffcf5a"))
	# تخته‌سنگ‌های اطراف تا غار در کوه فرو رفته به نظر برسد.
	mb.add_box(Vector3(-3.0, 1.0, -0.4), Vector3(1.6, 2.0, 2.2), rock.darkened(0.15))
	mb.add_box(Vector3(3.0, 0.9, -0.2), Vector3(1.8, 1.8, 2.0), rock.darkened(0.1))
	mb.add_box(Vector3(0, 4.9, -0.8), Vector3(5.6, 1.6, 2.6), rock.darkened(0.2))
	var m := mb.build()
	_mesh_cache["portal"] = m
	return m


## نزدیک‌ترین ورودی در فاصلهٔ max_dist از نقطهٔ (x, z) بیرون؛ دیکشنری خالی اگر نبود.
func nearest_entrance(x: float, z: float, max_dist: float) -> Dictionary:
	return world.nearest_site(x, z, max_dist)


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.5 and _mine_id == "":
		_acc = 0.0
		var f: Vector3 = get_viewport().get_camera_3d().global_position if get_viewport().get_camera_3d() != null else Vector3.ZERO
		for id in _portals:
			var n: Node3D = _portals[id]
			n.visible = Vector2(n.position.x, n.position.z).distance_to(Vector2(f.x, f.z)) < SHOW_DISTANCE


## هنگام ورود به معدن درگاه‌های بیرون پنهان می‌شوند (مه و سایه هزینه ندارند).
func set_surface_visible(v: bool) -> void:
	for id in _portals:
		_portals[id].visible = v


# ---------------- صحنهٔ زیرزمینی ----------------

func in_mine() -> bool:
	return _mine_id != ""


func mine_id() -> String:
	return _mine_id


func layout() -> Dictionary:
	return _layout


func enter(id: String, depleted: Dictionary) -> void:
	leave()
	_layout = Mine.layout_of(world.seed_value, id)
	_mine_id = id
	_root = Node3D.new()
	_root.position = ORIGIN
	add_child(_root)
	var mi := MeshInstance3D.new()
	mi.mesh = _build_mesh(_layout)
	mi.material_override = mat
	_root.add_child(mi)
	for n in _layout["nodes"]:
		var idx: int = int(n["idx"])
		var node := MeshInstance3D.new()
		node.mesh = _ore_mesh(str(n["kind"]))
		node.material_override = mat
		node.position = Vector3(float(n["x"]), 0.0, float(n["z"]))
		node.rotation.y = 0.0 if id.begins_with("h") else float((idx * 97) % 360) * PI / 180.0
		node.visible = not depleted.has(idx)
		_root.add_child(node)
		_ore_nodes[idx] = node
	# درگاه خروج روی دیوار جنوبی، پشت کاشی ورودی.
	var ex: Vector2 = Mine.spawn_point(_layout)
	var door := MeshInstance3D.new()
	door.mesh = _exit_mesh()
	door.material_override = mat
	door.position = Vector3(ex.x, 0.0, ex.y + Mine.TILE * 0.5 + 0.1)
	_root.add_child(door)
	var lbl := Label3D.new()
	lbl.text = Loc.t("house_exit") if id.begins_with("h") else Loc.t("mine_exit")
	lbl.font = Avatar.font()
	lbl.font_size = 40
	lbl.pixel_size = 0.008
	lbl.outline_size = 10
	lbl.language = "fa" if Loc.lang == "fa" else ""
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(ex.x, 3.6, ex.y + Mine.TILE * 0.5 - 0.4)
	lbl.modulate = Color("9fe8a0")
	lbl.no_depth_test = true
	_root.add_child(lbl)
	_lamp = OmniLight3D.new()
	_lamp.omni_range = 14.0 if not id.begins_with("h") else 18.0
	_lamp.light_energy = 1.6 if not id.begins_with("h") else 0.9
	_lamp.light_color = Color(1.0, 0.86, 0.62)
	_lamp.position = ORIGIN + Vector3(ex.x, 2.6, ex.y)
	add_child(_lamp)
	set_surface_visible(false)


func leave() -> void:
	_mine_id = ""
	_layout = {}
	_ore_nodes.clear()
	if _root != null:
		_root.queue_free()
		_root = null
	if _lamp != null:
		_lamp.queue_free()
		_lamp = null


## چراغ شخصیت: هر فریم دنبال او می‌آید (موقعیت جهانی).
func follow(p: Vector3) -> void:
	if _lamp != null:
		_lamp.position = p + Vector3(0, 2.7, 0)


func set_node_alive(idx: int, alive: bool) -> void:
	if _ore_nodes.has(idx):
		_ore_nodes[idx].visible = alive


## موقعیت محلی معدن ← موقعیت جهانی.
func to_world(mx: float, mz: float) -> Vector3:
	return ORIGIN + Vector3(mx, 0.0, mz)


func to_mine(p: Vector3) -> Vector2:
	return Vector2(p.x - ORIGIN.x, p.z - ORIGIN.z)


## پرتو را با سنگ‌های زندهٔ معدن می‌سنجد؛ نزدیک‌ترین idx یا -1.
func pick_node(ray_o: Vector3, ray_d: Vector3) -> int:
	var best := -1
	var best_t := 1.0e9
	for idx in _ore_nodes:
		var nd: MeshInstance3D = _ore_nodes[idx]
		if not nd.visible:
			continue
		var c: Vector3 = nd.global_position + Vector3(0, 0.7, 0)
		var t: float = (c - ray_o).dot(ray_d)
		if t <= 0.0:
			continue
		if (c - (ray_o + ray_d * t)).length() <= PICK_RADIUS and t < best_t:
			best_t = t
			best = int(idx)
	return best


func kind_of(idx: int) -> String:
	var n: Dictionary = Mine.node_of(_layout, idx)
	return str(n.get("kind", ""))


# ---------------- ساخت مش ----------------

static func _tile_hash(tx: int, tz: int) -> float:
	var v: int = (tx * 73856093) ^ (tz * 19349663)
	v = (v ^ (v >> 13)) * 1274126177
	return float((v ^ (v >> 16)) & 0xff) / 255.0


static func _build_mesh(l: Dictionary) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var T := Mine.TILE
	var house: bool = str(l.get("style", "")) == "house"
	for tz in range(Mine.SIZE):
		for tx in range(Mine.SIZE):
			var h := _tile_hash(tx, tz)
			var x0 := float(tx) * T
			var z0 := float(tz) * T
			if Mine.tile_open(l, tx, tz):
				var fc := Color("5b554d").lerp(Color("6d665c"), h)
				if house:
					fc = Color("a9784a").lerp(Color("b98a58"), float((tx + tz) % 2) * 0.6 + h * 0.2)
				var pts := [Vector3(x0, 0, z0), Vector3(x0 + T, 0, z0), Vector3(x0 + T, 0, z0 + T), Vector3(x0, 0, z0 + T)]
				mb.add_poly(pts, Vector3(x0 + T * 0.5, -1.0, z0 + T * 0.5), fc)
				if not house:
					_add_support(mb, l, tx, tz, x0, z0)
				continue
			# دیوار فقط جایی که به فضای باز می‌چسبد (هشت همسایه).
			var touches := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dz != 0) and Mine.tile_open(l, tx + dx, tz + dz):
						touches = true
			if not touches:
				continue
			var wc := Color("3c3834").lerp(Color("57514a"), h)
			var tall := WALL_H + (h - 0.5) * 0.5
			if house:
				wc = Color("e2d2ae").lerp(Color("d6c29a"), h)
				tall = WALL_H
			mb.add_box(Vector3(x0 + T * 0.5, tall * 0.5, z0 + T * 0.5), Vector3(T, tall, T), wc)
	if house:
		# میز و دو چهارپایه وسط اتاق.
		var c := Mine.tile_center(12, 12)
		mb.add_box(Vector3(c.x, 0.75, c.y), Vector3(1.8, 0.12, 1.1), Color("8a5a2c"))
		mb.add_box(Vector3(c.x - 0.75, 0.37, c.y - 0.4), Vector3(0.12, 0.74, 0.12), Color("6e4723"))
		mb.add_box(Vector3(c.x + 0.75, 0.37, c.y - 0.4), Vector3(0.12, 0.74, 0.12), Color("6e4723"))
		mb.add_box(Vector3(c.x - 0.75, 0.37, c.y + 0.4), Vector3(0.12, 0.74, 0.12), Color("6e4723"))
		mb.add_box(Vector3(c.x + 0.75, 0.37, c.y + 0.4), Vector3(0.12, 0.74, 0.12), Color("6e4723"))
		mb.add_box(Vector3(c.x - 1.3, 0.3, c.y + 0.9), Vector3(0.5, 0.6, 0.5), Color("7a5230"))
		mb.add_box(Vector3(c.x + 1.3, 0.3, c.y + 0.9), Vector3(0.5, 0.6, 0.5), Color("7a5230"))
		# فرش.
		mb.add_box(Vector3(c.x, 0.02, c.y + 0.1), Vector3(3.0, 0.04, 2.2), Color("a8483a"))
	return mb.build()


## قاب چوبی در راهروهای مستقیم، هر چند کاشی یک‌بار.
static func _add_support(mb: MeshBuilder, l: Dictionary, tx: int, tz: int, x0: float, z0: float) -> void:
	var dist: int = int(l["dist"][Mine.tile_index(tx, tz)])
	if dist < 2 or dist % 5 != 0:
		return
	var T := Mine.TILE
	var wood := Color("7a5230")
	var ew: bool = Mine.tile_open(l, tx - 1, tz) and Mine.tile_open(l, tx + 1, tz) and not Mine.tile_open(l, tx, tz - 1) and not Mine.tile_open(l, tx, tz + 1)
	var ns: bool = Mine.tile_open(l, tx, tz - 1) and Mine.tile_open(l, tx, tz + 1) and not Mine.tile_open(l, tx - 1, tz) and not Mine.tile_open(l, tx + 1, tz)
	var cx := x0 + T * 0.5
	var cz := z0 + T * 0.5
	if ew:
		mb.add_box(Vector3(cx, 1.1, cz - 1.25), Vector3(0.22, 2.2, 0.22), wood)
		mb.add_box(Vector3(cx, 1.1, cz + 1.25), Vector3(0.22, 2.2, 0.22), wood)
		mb.add_box(Vector3(cx, 2.3, cz), Vector3(0.26, 0.26, 2.9), wood.lightened(0.1))
	elif ns:
		mb.add_box(Vector3(cx - 1.25, 1.1, cz), Vector3(0.22, 2.2, 0.22), wood)
		mb.add_box(Vector3(cx + 1.25, 1.1, cz), Vector3(0.22, 2.2, 0.22), wood)
		mb.add_box(Vector3(cx, 2.3, cz), Vector3(2.9, 0.26, 0.26), wood.lightened(0.1))


static func _exit_mesh() -> ArrayMesh:
	if _mesh_cache.has("exit"):
		return _mesh_cache["exit"]
	var mb := MeshBuilder.new()
	mb.add_box(Vector3(-1.1, 1.4, 0), Vector3(0.25, 2.8, 0.3), Color("7a5230"))
	mb.add_box(Vector3(1.1, 1.4, 0), Vector3(0.25, 2.8, 0.3), Color("7a5230"))
	mb.add_box(Vector3(0, 2.85, 0), Vector3(2.6, 0.3, 0.3), Color("8a6038"))
	mb.add_box(Vector3(0, 1.3, 0.05), Vector3(1.9, 2.6, 0.12), Color("b8dcff"))   # روشنایی بیرون
	var m := mb.build()
	_mesh_cache["exit"] = m
	return m


static func _ore_mesh(kind: String) -> ArrayMesh:
	var key := "ore_" + kind
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mb := MeshBuilder.new()
	var rock := Color("8d8d92")
	match kind:
		"stone":
			mb.add_box(Vector3(0, 0.35, 0), Vector3(1.0, 0.7, 0.9), rock)
			mb.add_box(Vector3(0.35, 0.2, 0.3), Vector3(0.6, 0.4, 0.5), rock.darkened(0.12))
		"coal":
			mb.add_box(Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 0.9), Color("2d2d33"))
			mb.add_box(Vector3(-0.2, 0.55, 0.15), Vector3(0.45, 0.4, 0.4), Color("17171b"))
			mb.add_box(Vector3(0.3, 0.2, -0.2), Vector3(0.4, 0.3, 0.4), Color("3a3a42"))
		"iron":
			mb.add_box(Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 0.9), rock)
			mb.add_box(Vector3(0.25, 0.55, 0.46), Vector3(0.3, 0.25, 0.1), Color("d9955a"))
			mb.add_box(Vector3(-0.25, 0.3, 0.46), Vector3(0.22, 0.3, 0.1), Color("c9784a"))
			mb.add_box(Vector3(0.1, 0.65, -0.46), Vector3(0.3, 0.2, 0.1), Color("d9955a"))
		"gold":
			mb.add_box(Vector3(0, 0.4, 0), Vector3(1.0, 0.8, 0.9), rock.darkened(0.1))
			mb.add_box(Vector3(0.22, 0.55, 0.46), Vector3(0.32, 0.26, 0.1), Color("ffd24a"))
			mb.add_box(Vector3(-0.28, 0.32, 0.46), Vector3(0.24, 0.3, 0.1), Color("f2b82e"))
			mb.add_box(Vector3(0.0, 0.68, -0.46), Vector3(0.34, 0.2, 0.1), Color("ffd24a"))
		"gem":
			mb.add_box(Vector3(0, 0.25, 0), Vector3(0.9, 0.5, 0.8), rock.darkened(0.2))
			mb.add_cylinder(Vector3(-0.15, 0.4, 0.0), 0.2, 0.0, 0.9, 5, Color("5fe6ff"))
			mb.add_cylinder(Vector3(0.2, 0.4, 0.15), 0.16, 0.0, 0.65, 5, Color("a98bff"))
			mb.add_cylinder(Vector3(0.05, 0.4, -0.2), 0.13, 0.0, 0.5, 5, Color("7dffd6"))
		"bed":
			mb.add_box(Vector3(0, 0.25, 0), Vector3(1.3, 0.5, 2.2), Color("7a5230"))
			mb.add_box(Vector3(0, 0.6, 0.1), Vector3(1.2, 0.25, 1.9), Color("e9e4d8"))
			mb.add_box(Vector3(0, 0.82, -0.75), Vector3(0.9, 0.2, 0.4), Color("ffffff"))
			mb.add_box(Vector3(0, 0.72, 0.5), Vector3(1.22, 0.1, 1.0), Color("4a6fa8"))
		"chest", "hchest":
			mb.add_box(Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.65), Color("8a5a2c"))
			mb.add_box(Vector3(0, 0.68, 0), Vector3(1.04, 0.18, 0.69), Color("a56f38"))
			mb.add_box(Vector3(0, 0.45, 0.34), Vector3(0.16, 0.22, 0.05), Color("ffd24a"))
			mb.add_box(Vector3(-0.32, 0.4, 0), Vector3(0.1, 0.84, 0.7), Color("3a3a42"))
			mb.add_box(Vector3(0.32, 0.4, 0), Vector3(0.1, 0.84, 0.7), Color("3a3a42"))
		_:
			mb.add_box(Vector3(0, 0.35, 0), Vector3(0.8, 0.7, 0.8), rock)
	var m := mb.build()
	_mesh_cache[key] = m
	return m
