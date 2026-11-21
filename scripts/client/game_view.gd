extends Node3D
## دنیای سه‌بعدی: زمین، ساختمان‌ها، بازیکنان، NPCها، دوربین، ورودی و حالت ساخت.
## منطق بازی اینجا نیست؛ فقط درخواست می‌فرستد و وضعیت سرور را نشان می‌دهد.

const FWConst = preload("res://scripts/core/const.gd")
const InteriorMesh = preload("res://scripts/client/interior_mesh.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const Loc = preload("res://scripts/client/loc.gd")
const Sfx = preload("res://scripts/client/sfx.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")
const BuildingMesh = preload("res://scripts/client/building_mesh.gd")
const Avatar = preload("res://scripts/client/avatar.gd")
const CameraRig = preload("res://scripts/client/camera_rig.gd")
const Streamer = preload("res://scripts/client/terrain_streamer.gd")
const BlockView = preload("res://scripts/client/block_view.gd")
const MineView = preload("res://scripts/client/mine_view.gd")
const Mine = preload("res://scripts/shared/mine.gd")

signal building_tapped(id: int)
signal npc_tapped(id: int)
signal ghost_changed(error: String)
signal mode_changed(new_mode: String)
signal tool_changed
signal perspective_changed

const HEIGHTS := {"house": 4.4, "shop": 4.0, "farm": 1.3, "road": 0.2, "well": 2.5, "bakery": 4.4, "coop": 2.6, "barn": 4.0}

var client
var world
var cam
var streamer
var sun: DirectionalLight3D
var env: Environment
var _rain: CPUParticles3D
## داخل ساختمان: اتاق بالای آسمان شهر ساخته می‌شود تا با زمین و آب قاطی نشود.
var inside_id: int = 0
var _interior: Node3D
var _interior_origin: Vector3 = Vector3(FWConst.CITY_SIZE * 0.5, 200.0, FWConst.CITY_SIZE * 0.5)
var _outside_pos: Vector3 = Vector3.ZERO
var sky_mat: ProceduralSkyMaterial
var water: MeshInstance3D
var my_avatar
var avatars: Dictionary = {}
var npc_avatars: Dictionary = {}
var god_kind: String = ""
var god_nodes: Dictionary = {}
var coin_nodes: Array = []
var race_nodes: Array = []
var _race_mesh_next: ArrayMesh
var _race_mesh_other: ArrayMesh
var _flash: float = 0.0   # برق طوفان؛ سریع محو می‌شود
var _coin_mesh: ArrayMesh
var _god_meshes: Dictionary = {}
var _god_mat: StandardMaterial3D
var building_nodes: Dictionary = {}
var mode: String = "life"
var my_pos: Vector3 = Vector3.ZERO
var my_yaw: float = 0.0
var joy: Vector2 = Vector2.ZERO
var joy_active: bool = false
var joy_origin: Vector2 = Vector2.ZERO
var joy_zone: Rect2 = Rect2()
var build_type: String = ""
var ghost_cell: Vector2i = Vector2i(-1, -1)
var ghost_err: String = "not_ready"
var is_over_ui: Callable = func(_p): return false
## ابزار دست در حالت زندگی: hand | axe | pickaxe | shovel | hammer | brush
const LONG_PRESS_MS := 450
var first_person: bool = false
var tool: String = "hand"
var block_type: String = "wood"
var paint_color: int = 0
var block_view
var mine_view
var quality: int = 1

var _ghost: MeshInstance3D
var _bmat: StandardMaterial3D
var _time: float = 8.0 * 3600.0
var _send_acc: float = 0.0
var _last_sent: Vector2 = Vector2(-9999, -9999)
var _touches: Dictionary = {}
var _joy_touch: int = -1
var _pinch_dist: float = 0.0
var _mouse_left: Dictionary = {}
var _label_acc: float = 0.0
var _built_initial: bool = false


func setup(game_client, quality_level: int) -> void:
	client = game_client
	world = client.mirror.world
	quality = quality_level
	_bmat = MeshBuilder.material()
	_setup_environment()
	streamer = Streamer.new()
	streamer.name = "Terrain"
	add_child(streamer)
	streamer.is_depleted = func(k: String) -> bool: return client.mirror.depleted.has(k)
	streamer.setup(world, _radius_for_quality())
	block_view = BlockView.new()
	block_view.name = "Blocks"
	add_child(block_view)
	block_view.setup(client)
	mine_view = MineView.new()
	mine_view.name = "Mines"
	add_child(mine_view)
	mine_view.setup(world)
	client.mine_changed.connect(_on_mine_changed)
	client.mine_node_changed.connect(func(idx: int, alive: bool): mine_view.set_node_alive(idx, alive))
	client.resource_changed.connect(func(rx: int, rz: int, _alive: bool): streamer.refresh_resource(rx, rz))
	client.terrain_changed.connect(streamer.invalidate_area)
	client.god_changed.connect(_sync_god)
	client.minigame_changed.connect(_sync_coins)
	client.race_changed.connect(_sync_race)
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	cam.setup(world)
	_setup_water()
	my_pos = Vector3(client.spawn.x, client.mirror.ground_height(client.spawn.x, client.spawn.y), client.spawn.y)
	my_avatar = Avatar.new()
	add_child(my_avatar)
	my_avatar.setup(client.my_name, Avatar.color_for(client.my_name), false)
	my_avatar.teleport_to(my_pos)
	my_avatar.label.modulate = Color("ffe9a6")
	cam.set_life_focus(my_pos)
	cam.snap(cam.focus)
	streamer.update_focus(my_pos)
	for id in client.mirror.buildings:
		_spawn_building(client.mirror.buildings[id], false)
	_built_initial = true
	client.snapshot_received.connect(_on_snapshot)
	client.building_added.connect(func(b): _spawn_building(b, true))
	client.building_removed.connect(_remove_building)
	client.stocks_changed.connect(_refresh_stock_labels)
	client.teleported.connect(_on_teleported)
	client.inside_changed.connect(_on_inside_changed)
	_ghost = MeshInstance3D.new()
	_ghost.visible = false
	add_child(_ghost)
	_build_plaza()


func _build_plaza() -> void:
	## میدان مرکزی (فقط مدیران حق ساخت دارند): کف سنگی + حوض.
	var lo := FWConst.PLAZA_MIN * FWConst.CELL_SIZE
	var size := float(FWConst.PLAZA_MAX - FWConst.PLAZA_MIN + 1) * FWConst.CELL_SIZE
	var hi_y := -INF
	for i in range(5):
		for j in range(5):
			hi_y = maxf(hi_y, world.height_at(lo + size * i / 4.0, lo + size * j / 4.0))
	var mb := MeshBuilder.new()
	var c := Vector3(lo + size * 0.5, hi_y, lo + size * 0.5)
	mb.add_box(c + Vector3(0, -0.9, 0), Vector3(size, 2.0, size), Color("c9c3b2"))
	mb.add_box(c + Vector3(0, 0.12, 0), Vector3(size - 0.8, 0.06, size - 0.8), Color("ddd7c6"))
	mb.add_cylinder(c + Vector3(0, 0.1, 0), 1.6, 1.5, 0.5, 10, Color("9a9a92"))
	mb.add_cylinder(c + Vector3(0, 0.5, 0), 1.3, 1.3, 0.08, 10, Color("4a97c4"))
	mb.add_cylinder(c + Vector3(0, 0.1, 0), 0.25, 0.2, 1.4, 6, Color("9a9a92"))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build()
	mi.material_override = _bmat
	add_child(mi)


func _on_snapshot() -> void:
	# snapshot بعد از سیگنال ورود می‌رسد؛ ساختمان‌های موجود را بدون انیمیشن بساز.
	for id in client.mirror.buildings:
		_spawn_building(client.mirror.buildings[id], false)


func _weather_fog() -> float:
	if client.disaster_kind() == "storm":
		return 3.0
	match client.weather:
		"rain":
			return 2.0
		"fog":
			return 4.5
	return 1.0


func _weather_light() -> float:
	if client.disaster_kind() == "storm":
		return 0.4 + _flash * 2.0
	match client.weather:
		"rain":
			return 0.55
		"fog":
			return 0.7
	return 1.0


## باران: ذره‌های سبک که دور کانون دوربین می‌افتند (فقط وقتی هوا بارانی است).
func _update_rain() -> void:
	if _rain == null:
		_rain = CPUParticles3D.new()
		_rain.amount = 350 if quality >= 1 else 160
		_rain.lifetime = 1.1
		_rain.preprocess = 1.0
		_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_rain.emission_box_extents = Vector3(24, 0.5, 24)
		_rain.direction = Vector3(0.1, -1, 0)
		_rain.spread = 2.0
		_rain.gravity = Vector3(0, -25, 0)
		_rain.initial_velocity_min = 14.0
		_rain.initial_velocity_max = 18.0
		var qm := QuadMesh.new()
		qm.size = Vector2(0.03, 0.7)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.material = mat
		_rain.mesh = qm
		add_child(_rain)
	_rain.emitting = client.weather == "rain" or client.disaster_kind() == "storm"
	_rain.position = cam.focus + Vector3(0, 18, 0)


func _fog_base() -> float:
	return 1.6 / (float(_radius_for_quality()) * FWConst.CHUNK_SIZE)


func _radius_for_quality() -> int:
	return [2, 3, 4][clampi(quality, 0, 2)]


func apply_quality(q: int) -> void:
	quality = q
	streamer.set_radius(_radius_for_quality())
	sun.shadow_enabled = quality >= 2
	env.fog_density = _fog_base()
	get_viewport().scaling_3d_scale = [0.75, 0.9, 1.0][clampi(quality, 0, 2)]


func _setup_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = quality >= 2
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_density = _fog_base()
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_sky_affect = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	get_viewport().scaling_3d_scale = [0.75, 0.9, 1.0][clampi(quality, 0, 2)]


func _setup_water() -> void:
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1400, 1400)
	water.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.45, 0.68, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.25
	m.metallic_specular = 0.8
	water.material_override = m
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


# ---------------- حالت‌ها ----------------

func toggle_mode() -> void:
	if inside_id > 0 or client.mine_id != "":
		return
	set_mode("world" if mode == "life" else "life")


func set_mode(m: String) -> void:
	if m == "world" and tool != "hand":
		tool = "hand"
		tool_changed.emit()
	if m == mode:
		return
	mode = m
	cam.mode = m
	_apply_perspective()
	if m == "life":
		cam.set_life_focus(my_pos)
		joy = Vector2.ZERO
		joy_active = false
		_joy_touch = -1
	else:
		cam.focus = Vector3(my_pos.x, my_pos.y, my_pos.z)
	mode_changed.emit(m)


func focus_on_player() -> void:
	cam.focus = my_pos
	cam.focus.y = my_pos.y


# ---------------- ساختمان‌ها ----------------

func _building_transform(type: String, cx: int, cz: int) -> Vector3:
	var fp := BuildingMesh.footprint_size(type)
	var by: float = Placement.base_height(world, type, cx, cz)
	return Vector3(cx * FWConst.CELL_SIZE + fp.x * 0.5, by, cz * FWConst.CELL_SIZE + fp.y * 0.5)


func _spawn_building(b: Dictionary, animate: bool) -> void:
	var id := int(b["id"])
	if building_nodes.has(id):
		return
	var type := str(b["type"])
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = BuildingMesh.get_mesh(type)
	mi.material_override = _bmat
	node.add_child(mi)
	node.position = _building_transform(type, int(b["cx"]), int(b["cz"]))
	var label_y: float = float(HEIGHTS.get(type, 3.0)) + 0.8
	if type != "road":
		var lbl := Label3D.new()
		lbl.name = "Owner"
		lbl.text = str(b["owner"])
		lbl.font = Avatar.font()
		lbl.font_size = 34
		lbl.pixel_size = 0.009
		lbl.outline_size = 9
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(0, label_y, 0)
		lbl.modulate = Color("fff1c4")
		node.add_child(lbl)
	if FWConst.PRODUCERS.has(type):
		var sl := Label3D.new()
		sl.name = "Stock"
		sl.font = Avatar.font()
		sl.font_size = 34
		sl.pixel_size = 0.009
		sl.outline_size = 9
		sl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sl.position = Vector3(0, label_y + 0.7, 0)
		sl.modulate = Color("c8f08a")
		node.add_child(sl)
	add_child(node)
	building_nodes[id] = node
	_update_stock_label(id)
	if animate and _built_initial:
		node.scale = Vector3(0.05, 0.05, 0.05)
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if str(b["owner"]) == client.my_name:
			Sfx.play(self, "place")


func _remove_building(id: int) -> void:
	if not building_nodes.has(id):
		return
	var node: Node3D = building_nodes[id]
	building_nodes.erase(id)
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
	tw.tween_callback(node.queue_free)


func _update_stock_label(id: int) -> void:
	if not building_nodes.has(id) or not client.mirror.buildings.has(id):
		return
	var sl: Label3D = building_nodes[id].get_node_or_null("Stock")
	if sl != null:
		sl.text = "%s: %s" % [Loc.t("stock"), Loc.digits(str(int(client.mirror.buildings[id]["stock"])))]


func _refresh_stock_labels() -> void:
	for id in building_nodes:
		_update_stock_label(id)


# ---------------- حالت ساخت ----------------

func set_build_type(t: String) -> void:
	if t != "":
		god_kind = ""
	build_type = t
	ghost_cell = Vector2i(-1, -1)
	_ghost.visible = false
	if t != "":
		_ghost.mesh = BuildingMesh.get_mesh(t)
		_auto_place_ghost()
	ghost_changed.emit("")


## بعد از انتخاب نوع ساختمان، نزدیک‌ترین جای معتبر جلوی بازیکن را خودکار پیشنهاد می‌دهد
## تا دکمهٔ تأیید بلافاصله قابل استفاده باشد. لمس زمین همچنان جای ساختمان را عوض می‌کند.
func _auto_place_ghost() -> void:
	var size: Array = FWConst.building_size(build_type)
	# جهت نگاه دوربین روی زمین (نه جهت بدن بازیکن) تا پیشنهاد همیشه جلوی چشم باشد
	var look: Vector3 = -cam.camera.global_transform.basis.z
	var fwd := Vector2(look.x, look.z)
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector2(sin(my_yaw), cos(my_yaw))
	var base := Vector2(my_pos.x, my_pos.z) + fwd * 6.0
	var best := Vector2i(-1, -1)
	var best_d := 1.0e9
	var c0 := Vector2i(int(floor(base.x / FWConst.CELL_SIZE)), int(floor(base.y / FWConst.CELL_SIZE)))
	for dz in range(-8, 9):
		for dx in range(-8, 9):
			var cx := c0.x + dx - ((int(size[0]) - 1) >> 1)
			var cz := c0.y + dz - ((int(size[1]) - 1) >> 1)
			var d := float(dx * dx + dz * dz)
			if d < best_d and client.preview_error(build_type, cx, cz) == "":
				best_d = d
				best = Vector2i(cx, cz)
	if best.x >= 0:
		_set_ghost(best)


func _set_ghost(cell: Vector2i) -> void:
	ghost_cell = cell
	ghost_err = client.preview_error(build_type, cell.x, cell.y)
	_ghost.position = _building_transform(build_type, cell.x, cell.y)
	var m := MeshBuilder.material(0.6)
	m.albedo_color = Color(0.5, 1.0, 0.5, 0.6) if ghost_err == "" else Color(1.0, 0.35, 0.3, 0.6)
	_ghost.material_override = m
	_ghost.visible = true
	ghost_changed.emit(ghost_err)


func confirm_build() -> bool:
	if build_type == "" or ghost_cell.x < 0:
		return false
	if ghost_err != "":
		Sfx.play(self, "error")
		return false
	client.place(build_type, ghost_cell.x, ghost_cell.y)
	_ghost.visible = false
	ghost_cell = Vector2i(-1, -1)
	ghost_changed.emit("")
	return true


# ---------------- ابزارهای دست (تبر، کلنگ، بیل، چکش، قلم‌مو) ----------------

## جابه‌جایی بین دید سوم‌شخص و اول‌شخص (فقط در حالت زندگی و بیرون از ساختمان).
func set_first_person(on: bool) -> void:
	first_person = on
	_apply_perspective()
	perspective_changed.emit()


func _apply_perspective() -> void:
	var fp: bool = first_person and mode == "life" and inside_id == 0 and client.mine_id == ""
	cam.first_person = fp
	if fp:
		cam.fp_pitch = 0.0
	if my_avatar != null:
		my_avatar.visible = not fp


func set_tool(t: String) -> void:
	if not FWConst.TOOLS.has(t):
		return
	tool = t
	if t != "hand" and build_type != "":
		set_build_type("")
	tool_changed.emit()


func set_block_type(t: String) -> void:
	if FWConst.BLOCK_TYPES.has(t):
		block_type = t
		tool_changed.emit()


func set_paint_color(c: int) -> void:
	paint_color = clampi(c, 0, FWConst.COLOR_COUNT - 1)
	tool_changed.emit()


## جهت نگاه دوربین (۰=+z، ۱=+x، ۲=−z، ۳=−x)؛ پله به‌سمت جلوی دوربین بالا می‌رود.
func _facing() -> int:
	var f: Vector3 = -cam.camera.global_transform.basis.z
	if absf(f.x) > absf(f.z):
		return 1 if f.x > 0.0 else 3
	return 0 if f.z > 0.0 else 2


func _in_reach(cell: Vector3i) -> bool:
	var c := Vector3(cell.x + 0.5, cell.y + 0.5, cell.z + 0.5)
	return Vector3(my_pos.x, my_pos.y + 1.0, my_pos.z).distance_to(c) <= FWConst.BLOCK_REACH


func _feedback(code: String) -> void:
	client.notice.emit(code, {})


## نزدیک‌ترین گرهٔ منبع (درخت/سنگ/خاک رس) که پرتو لمس از کنارش می‌گذرد.
func _pick_resource(o: Vector3, d: Vector3, only_kind: String = "") -> Dictionary:
	var per := FWConst.RESOURCE_CELL
	var r0 := int(floor(my_pos.x / per))
	var r1 := int(floor(my_pos.z / per))
	var span := int(ceil(FWConst.GATHER_RANGE / per)) + 1
	var best := {}
	var best_d := 1.0e9
	for rz in range(r1 - span, r1 + span + 1):
		for rx in range(r0 - span, r0 + span + 1):
			if client.mirror.depleted.has("%d,%d" % [rx, rz]):
				continue
			var n: Dictionary = world.resource_in_cell(rx, rz)
			if n.is_empty():
				continue
			var kind: String = n["kind"]
			if only_kind != "" and kind != only_kind:
				continue
			var up: float = 1.4 if kind == "tree" else (0.45 if kind in ["rock", "iron_ore", "gold_ore", "chest"] else 0.15)
			var radius: float = 1.5 if kind == "tree" else 1.1
			var p := Vector3(float(n["x"]), float(n["y"]) + up * float(n["s"]), float(n["z"]))
			var t := (p - o).dot(d)
			if t < 0.0:
				continue
			var miss := (p - (o + d * t)).length()
			if miss <= radius and miss < best_d:
				best_d = miss
				best = {"rx": rx, "rz": rz, "x": float(n["x"]), "z": float(n["z"])}
	return best


func _tool_tap(pos: Vector2) -> void:
	var o: Vector3 = cam.camera.project_ray_origin(pos)
	var d: Vector3 = cam.camera.project_ray_normal(pos)
	match tool:
		"axe", "pickaxe", "shovel":
			var res := _pick_resource(o, d)
			if not res.is_empty():
				if Vector2(my_pos.x, my_pos.z).distance_to(Vector2(res["x"], res["z"])) > FWConst.GATHER_RANGE:
					Sfx.play(self, "error")
					_feedback("too_far")
					return
				Sfx.play(self, "click")
				client.gather(res["rx"], res["rz"], tool)
				return
			var hit: Dictionary = block_view.raycast(o, d)
			if tool == "pickaxe" and hit.get("kind", "") == "block":
				if not _in_reach(hit["hit"]):
					Sfx.play(self, "error")
					_feedback("too_far")
					return
				Sfx.play(self, "click")
				client.remove_block(hit["hit"])
				return
			if tool == "shovel" and hit.get("kind", "") == "ground":
				var pt: Vector3 = hit["point"]
				if Vector2(my_pos.x, my_pos.z).distance_to(Vector2(pt.x, pt.z)) > FWConst.GATHER_RANGE:
					Sfx.play(self, "error")
					_feedback("too_far")
					return
				Sfx.play(self, "click")
				client.dig(pt.x, pt.z)
				return
			Sfx.play(self, "error")
			_feedback("no_target")
		"fill":
			var fhit: Dictionary = block_view.raycast(o, d)
			if fhit.get("kind", "") != "ground":
				Sfx.play(self, "error")
				_feedback("no_target")
				return
			var fpt: Vector3 = fhit["point"]
			if Vector2(my_pos.x, my_pos.z).distance_to(Vector2(fpt.x, fpt.z)) > FWConst.GATHER_RANGE:
				Sfx.play(self, "error")
				_feedback("too_far")
				return
			Sfx.play(self, "click")
			client.fill(fpt.x, fpt.z)
		"hammer":
			var hit: Dictionary = block_view.raycast(o, d)
			if hit.is_empty():
				return
			var cell: Vector3i = hit["prev"] if hit["kind"] == "block" else hit["cell"]
			if not _in_reach(cell):
				Sfx.play(self, "error")
				_feedback("too_far")
				return
			var err: String = client.block_preview_error(cell, block_type)
			if err != "":
				Sfx.play(self, "error")
				_feedback(err)
				return
			Sfx.play(self, "place")
			client.place_block(cell, block_type, paint_color + (16 * _facing() if block_type == "stairs" else 0))
		"brush":
			var hit: Dictionary = block_view.raycast(o, d)
			if hit.get("kind", "") != "block":
				return
			if not _in_reach(hit["hit"]):
				Sfx.play(self, "error")
				_feedback("too_far")
				return
			Sfx.play(self, "click")
			client.paint_block(hit["hit"], paint_color)


# ---------------- پیکینگ ----------------

func ground_hit(screen_pos: Vector2) -> Variant:
	var o: Vector3 = cam.camera.project_ray_origin(screen_pos)
	var d: Vector3 = cam.camera.project_ray_normal(screen_pos)
	var prev := 0.0
	var t := 0.0
	while t < 600.0:
		var p := o + d * t
		var h: float = world.height_at(p.x, p.z)
		if p.y <= h:
			var lo := prev
			var hi := t
			for i in range(10):
				var mid := (lo + hi) * 0.5
				var q := o + d * mid
				if q.y <= world.height_at(q.x, q.z):
					hi = mid
				else:
					lo = mid
			var r := o + d * hi
			r.y = world.height_at(r.x, r.z)
			return r
		prev = t
		t += 1.0 if t < 80.0 else 3.0
	return null


func _pick_building(screen_pos: Vector2, max_dist: float) -> int:
	var o: Vector3 = cam.camera.project_ray_origin(screen_pos)
	var d: Vector3 = cam.camera.project_ray_normal(screen_pos)
	var best := -1
	var best_t := max_dist
	for id in client.mirror.buildings:
		var b: Dictionary = client.mirror.buildings[id]
		var fp := BuildingMesh.footprint_size(b["type"])
		var base: float = Placement.base_height(world, b["type"], b["cx"], b["cz"])
		var box := AABB(Vector3(b["cx"] * FWConst.CELL_SIZE, base - 0.2, b["cz"] * FWConst.CELL_SIZE),
			Vector3(fp.x, float(HEIGHTS.get(b["type"], 3.0)) + 0.4, fp.y))
		var hit = box.intersects_ray(o, d)
		if hit != null:
			var dist := o.distance_to(hit)
			if dist < best_t:
				best_t = dist
				best = id
	return best


func _tap(pos: Vector2) -> void:
	if client.mine_id != "":
		_mine_tap(pos)
		return
	if inside_id > 0:
		return
	if mode == "life" and tool != "hand" and build_type == "":
		_tool_tap(pos)
		return
	if mode == "world" and god_kind != "" and build_type == "":
		var gh = ground_hit(pos)
		if gh != null:
			Sfx.play(self, "click")
			if god_kind == "remove":
				client.god("remove", "", gh.x, gh.z)
			else:
				client.god("add", god_kind, gh.x, gh.z)
		return
	if mode == "life" and tool == "hand" and build_type == "":
		var ro: Vector3 = cam.camera.project_ray_origin(pos)
		var rd: Vector3 = cam.camera.project_ray_normal(pos)
		var best_npc := -1
		var best_t := 1.0e9
		for nid in npc_avatars:
			var c: Vector3 = npc_avatars[nid].position + Vector3(0, 1.0, 0)
			var t := (c - ro).dot(rd)
			if t > 0.0 and (c - (ro + rd * t)).length() <= 1.1 and t < best_t:
				best_t = t
				best_npc = int(nid)
		if best_npc >= 0:
			Sfx.play(self, "click")
			npc_tapped.emit(best_npc)
			return
		var chest := _pick_resource(cam.camera.project_ray_origin(pos), cam.camera.project_ray_normal(pos), "chest")
		if not chest.is_empty():
			if Vector2(my_pos.x, my_pos.z).distance_to(Vector2(chest["x"], chest["z"])) > FWConst.GATHER_RANGE:
				Sfx.play(self, "error")
				_feedback("too_far")
				return
			Sfx.play(self, "click")
			client.gather(chest["rx"], chest["rz"], "hand")
			return
	var hit = ground_hit(pos)
	var ground_t := 1.0e9
	if hit != null:
		ground_t = cam.camera.global_position.distance_to(hit)
	if build_type != "":
		if hit == null:
			return
		var size: Array = FWConst.building_size(build_type)
		var cx := int(floor(hit.x / FWConst.CELL_SIZE)) - ((int(size[0]) - 1) >> 1)
		var cz := int(floor(hit.z / FWConst.CELL_SIZE)) - ((int(size[1]) - 1) >> 1)
		_set_ghost(Vector2i(cx, cz))
		Sfx.play(self, "click")
		return
	var id := _pick_building(pos, ground_t + 2.0)
	if id >= 0:
		Sfx.play(self, "click")
	building_tapped.emit(id)


# ---------------- ورودی ----------------

func _input(event: InputEvent) -> void:
	if not is_inside_tree() or client == null:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_on_mouse_motion(event)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if is_over_ui.call(e.position):
			return
		var role := "cam"
		if mode == "life" and _joy_touch == -1 and joy_zone.has_point(e.position):
			role = "joy"
			_joy_touch = e.index
			joy_origin = e.position
			joy_active = true
		_touches[e.index] = {"start": e.position, "pos": e.position, "t0": Time.get_ticks_msec(), "role": role, "moved": 0.0, "fired": false}
		_pinch_dist = 0.0
	elif _touches.has(e.index):
		var t: Dictionary = _touches[e.index]
		if t["role"] == "joy":
			_joy_touch = -1
			joy = Vector2.ZERO
			joy_active = false
		elif _touches.size() == 1 and not bool(t.get("fired", false)) and float(t["moved"]) < 24.0 and Time.get_ticks_msec() - int(t["t0"]) < 400:
			_tap(e.position)
		_touches.erase(e.index)
		_pinch_dist = 0.0


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var t: Dictionary = _touches[e.index]
	t["pos"] = e.position
	t["moved"] = float(t["moved"]) + e.relative.length()
	if t["role"] == "joy":
		joy = ((e.position - joy_origin) / 80.0).limit_length(1.0)
		return
	var cams: Array = []
	for k in _touches:
		if _touches[k]["role"] == "cam":
			cams.append(_touches[k])
	if cams.size() >= 2:
		var d: float = cams[0]["pos"].distance_to(cams[1]["pos"])
		if _pinch_dist > 0.0 and d > 1.0:
			cam.zoom_by(_pinch_dist / d)
		_pinch_dist = d
	elif mode == "life":
		cam.rotate_by(e.relative.x * 0.006, e.relative.y * 0.004)
	else:
		var k: float = cam.world_distance * 0.0014
		cam.pan(-e.relative.x * k, e.relative.y * k)


func _on_mouse_button(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		if not is_over_ui.call(e.position):
			cam.zoom_by(0.9)
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		if not is_over_ui.call(e.position):
			cam.zoom_by(1.1)
	elif e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if is_over_ui.call(e.position):
				return
			_mouse_left = {"t0": Time.get_ticks_msec(), "moved": 0.0, "pos": e.position, "fired": false}
		elif not _mouse_left.is_empty():
			if not bool(_mouse_left.get("fired", false)) and float(_mouse_left["moved"]) < 8.0 and Time.get_ticks_msec() - int(_mouse_left["t0"]) < 500:
				_tap(e.position)
			_mouse_left = {}


func _on_mouse_motion(e: InputEventMouseMotion) -> void:
	var left := not _mouse_left.is_empty()
	var right := (e.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
	if left:
		_mouse_left["moved"] = float(_mouse_left["moved"]) + e.relative.length()
	if right or (left and mode == "life" and float(_mouse_left.get("moved", 0.0)) > 8.0):
		cam.rotate_by(e.relative.x * 0.005, e.relative.y * 0.004)
	elif left and mode == "world" and float(_mouse_left["moved"]) > 8.0:
		var k: float = cam.world_distance * 0.0016
		cam.pan(-e.relative.x * k, e.relative.y * k)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.keycode == KEY_TAB:
			toggle_mode()


# ---------------- به‌روزرسانی هر فریم ----------------

func _keyboard_vector() -> Vector2:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		return Vector2.ZERO
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v


func _check_long_press() -> void:
	var now := Time.get_ticks_msec()
	if _touches.size() == 1:
		for k in _touches:
			var t: Dictionary = _touches[k]
			if t["role"] == "cam" and not bool(t.get("fired", false)) and float(t["moved"]) < 24.0 and now - int(t["t0"]) >= LONG_PRESS_MS:
				t["fired"] = true
				_long_press(t["pos"])
	if not _mouse_left.is_empty() and not bool(_mouse_left.get("fired", false)) and float(_mouse_left["moved"]) < 8.0 and now - int(_mouse_left["t0"]) >= LONG_PRESS_MS:
		_mouse_left["fired"] = true
		_long_press(_mouse_left["pos"])


## نگه داشتن روی یک بلوک (با چکش، کلنگ یا قلم‌مو) آن را برمی‌دارد و موادش برمی‌گردد.
func _long_press(pos: Vector2) -> void:
	if mode != "life" or inside_id > 0 or client.mine_id != "" or not (tool == "hammer" or tool == "pickaxe" or tool == "brush"):
		return
	var hit: Dictionary = block_view.raycast(cam.camera.project_ray_origin(pos), cam.camera.project_ray_normal(pos))
	if hit.get("kind", "") != "block":
		return
	if not _in_reach(hit["hit"]):
		Sfx.play(self, "error")
		_feedback("too_far")
		return
	Input.vibrate_handheld(35)
	Sfx.play(self, "click")
	client.remove_block(hit["hit"])


func _process(delta: float) -> void:
	if client == null or not client.is_logged_in:
		return
	_check_long_press()
	var dt := minf(delta, 0.1)
	var kb := _keyboard_vector()
	if not (get_viewport().gui_get_focus_owner() is LineEdit):
		if Input.is_key_pressed(KEY_Q):
			cam.yaw += dt * 1.8
		if Input.is_key_pressed(KEY_E):
			cam.yaw -= dt * 1.8
	if mode == "life":
		_move_player(dt, joy + kb)
		cam.set_life_focus(my_pos)
	else:
		if kb.length() > 0.0:
			var speed: float = cam.world_distance * 0.9 * dt
			cam.pan(kb.x * speed, -kb.y * speed)
	var underground: bool = client.mine_id != ""
	if inside_id == 0 and not underground:
		streamer.update_focus(cam.focus)
	if underground:
		mine_view.follow(my_pos)
	# دوربین نمای شهر دور است؛ مه را کم می‌کنیم تا رنگ‌ها شسته نشوند.
	env.fog_density = lerpf(env.fog_density, _fog_base() * _weather_fog() * (1.0 if mode == "life" else 0.22), minf(dt * 3.0, 1.0))
	if not underground:
		_update_rain()
	water.position = Vector3(snappedf(cam.focus.x, 16.0), 0.0, snappedf(cam.focus.z, 16.0))
	_time = lerpf(_time + dt * FWConst.TIME_SCALE * client.time_speed, client.world_time, minf(dt * 0.5, 1.0))
	if not underground:
		_update_sky(fposmod(_time, 86400.0) / 3600.0)
	_sync_remote(dt)
	_label_acc += dt
	if _label_acc > 0.25:
		_label_acc = 0.0
		_update_label_visibility()


func _move_player(dt: float, input: Vector2) -> void:
	var len := minf(input.length(), 1.0)
	if len < 0.08:
		return
	if inside_id > 0:
		var d: Vector3 = (cam.right_flat() * input.x + cam.forward_flat() * (-input.y)).normalized()
		var rel: Vector3 = InteriorMesh.clamp_to_room(my_pos - _interior_origin + d * FWConst.PLAYER_SPEED * 0.6 * len * dt)
		my_pos = _interior_origin + rel
		my_yaw = atan2(d.x, d.z)
		my_avatar.position = my_pos
		my_avatar.target = my_pos
		my_avatar.target_yaw = my_yaw
		return
	if client.mine_id != "" and mine_view.in_mine():
		_move_in_mine(dt, len, (cam.right_flat() * input.x + cam.forward_flat() * (-input.y)).normalized())
		return
	var dir: Vector3 = (cam.right_flat() * input.x + cam.forward_flat() * (-input.y)).normalized()
	var step := dir * FWConst.PLAYER_SPEED * (FWConst.RACE_SPEED_MULT if client.race_active() else 1.0) * len * dt
	var nx := my_pos.x + step.x
	var nz := my_pos.z + step.z
	var lo := -FWConst.WORLD_LIMIT
	var hi := FWConst.CITY_SIZE + FWConst.WORLD_LIMIT
	var mirror = client.mirror
	if mirror.is_walkable(nx, nz, my_pos.y) and nx > lo and nx < hi and nz > lo and nz < hi:
		my_pos.x = nx
		my_pos.z = nz
	elif mirror.is_walkable(nx, my_pos.z, my_pos.y):
		my_pos.x = nx
	elif mirror.is_walkable(my_pos.x, nz, my_pos.y):
		my_pos.z = nz
	else:
		return
	my_pos.y = client.mirror.ground_height(my_pos.x, my_pos.z, my_pos.y)
	my_yaw = atan2(dir.x, dir.z)
	my_avatar.position = my_pos
	my_avatar.target = my_pos
	my_avatar.target_yaw = my_yaw
	_send_acc += dt
	if _send_acc >= 0.05:
		_send_acc = 0.0
		var cur := Vector2(my_pos.x, my_pos.z)
		if cur.distance_to(_last_sent) > 0.01:
			_last_sent = cur
			client.send_move(my_pos.x, my_pos.z, my_yaw)


func _on_inside_changed(id: int) -> void:
	if id > 0 and client.mirror.buildings.has(id):
		_enter_interior(id)
	else:
		_exit_interior()


func _enter_interior(id: int) -> void:
	var type: String = str(client.mirror.buildings[id]["type"])
	_outside_pos = my_pos
	inside_id = id
	_apply_perspective()
	build_type = ""
	_ghost.visible = false
	if _interior != null:
		_interior.queue_free()
	_interior = Node3D.new()
	_interior.position = _interior_origin
	add_child(_interior)
	var mi := MeshInstance3D.new()
	mi.mesh = InteriorMesh.get_mesh(type)
	mi.material_override = _bmat
	_interior.add_child(mi)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 3.0, 0.5)
	lamp.omni_range = 16.0
	lamp.light_energy = 1.1
	_interior.add_child(lamp)
	set_mode("life")
	joy = Vector2.ZERO
	my_pos = _interior_origin + InteriorMesh.entry_point()
	my_avatar.teleport_to(my_pos)
	cam.life_distance = 6.5
	cam.set_life_focus(my_pos)
	cam.snap(cam.focus)


func _exit_interior() -> void:
	if inside_id == 0:
		return
	inside_id = 0
	_apply_perspective()
	if _interior != null:
		_interior.queue_free()
		_interior = null
	cam.life_distance = 9.0
	my_pos = _outside_pos
	my_avatar.teleport_to(my_pos)
	cam.set_life_focus(my_pos)
	cam.snap(cam.focus)
	streamer.update_focus(my_pos)
	_last_sent = Vector2(-9999, -9999)


## نزدیک‌ترین ورودی معدن در برد ورود (برای دکمهٔ «ورود به معدن»)؛ "" اگر نبود.
func near_mine_id() -> String:
	if client == null or client.mine_id != "" or inside_id > 0 or mode != "life":
		return ""
	var e: Dictionary = mine_view.nearest_entrance(my_pos.x, my_pos.z, FWConst.MINE_ENTER_RANGE)
	return str(e.get("id", ""))


func _on_mine_changed(id: String) -> void:
	if id != "":
		_enter_mine(id)
	else:
		_exit_mine()


func _enter_mine(id: String) -> void:
	_outside_pos = my_pos
	build_type = ""
	_ghost.visible = false
	set_mode("life")
	joy = Vector2.ZERO
	mine_view.enter(id, client.mine_depleted)
	_set_underground(true)
	var sp: Vector2 = Mine.spawn_point(mine_view.layout())
	my_pos = mine_view.to_world(sp.x, sp.y)
	my_yaw = PI
	_apply_perspective()
	my_avatar.teleport_to(my_pos)
	my_avatar.target_yaw = my_yaw
	cam.life_distance = 8.5
	cam.life_pitch_min = -34.0
	cam.life_pitch_offset = -30.0
	cam.yaw = 0.0
	cam.set_life_focus(my_pos)
	cam.snap(cam.focus)
	_last_sent = Vector2(-9999, -9999)


func _exit_mine() -> void:
	if not mine_view.in_mine():
		return
	var e: Dictionary = world.mine_entrance(mine_view.mine_id())
	mine_view.leave()
	_set_underground(false)
	if e.is_empty():
		my_pos = _outside_pos
	else:
		my_pos = Vector3(float(e["ex"]), client.mirror.ground_height(float(e["ex"]), float(e["ez"])), float(e["ez"]))
		my_yaw = float(e["yaw"])
	_apply_perspective()
	my_avatar.teleport_to(my_pos)
	cam.life_distance = 9.0
	cam.life_pitch_min = -20.0
	cam.life_pitch_offset = 0.0
	cam.yaw = my_yaw + PI
	cam.set_life_focus(my_pos)
	cam.snap(cam.focus)
	streamer.update_focus(my_pos)
	mine_view.set_surface_visible(true)
	_last_sent = Vector2(-9999, -9999)


## زیرزمین: آسمان و خورشید و مه خاموش، فقط چراغ شخصیت و نور محیطی ضعیف.
func _set_underground(on: bool) -> void:
	if on:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.012, 0.012, 0.018)
		env.ambient_light_color = Color(0.34, 0.33, 0.4)
		env.ambient_light_energy = 1.0
		env.fog_enabled = false
		sun.light_energy = 0.0
		sun.shadow_enabled = false
		water.visible = false
		if _rain != null:
			_rain.emitting = false
	else:
		env.background_mode = Environment.BG_SKY
		env.fog_enabled = true
		sun.shadow_enabled = quality >= 2
		water.visible = true


func _move_in_mine(dt: float, len: float, d: Vector3) -> void:
	var lay: Dictionary = mine_view.layout()
	var cur: Vector2 = mine_view.to_mine(my_pos)
	var nxt: Vector2 = cur + Vector2(d.x, d.z) * FWConst.PLAYER_SPEED * len * dt
	if Mine.walkable(lay, nxt.x, nxt.y):
		cur = nxt
	elif Mine.walkable(lay, nxt.x, cur.y):
		cur.x = nxt.x
	elif Mine.walkable(lay, cur.x, nxt.y):
		cur.y = nxt.y
	else:
		return
	my_pos = mine_view.to_world(cur.x, cur.y)
	my_yaw = atan2(d.x, d.z)
	my_avatar.position = my_pos
	my_avatar.target = my_pos
	my_avatar.target_yaw = my_yaw
	_send_acc += dt
	if _send_acc >= 0.05:
		_send_acc = 0.0
		if cur.distance_to(_last_sent) > 0.01:
			_last_sent = cur
			client.send_move(cur.x, cur.y, my_yaw)


## لمس در معدن: سنگ معدن را برمی‌دارد (ابزار را سرور از نوع سنگ می‌فهمد).
func _mine_tap(pos: Vector2) -> void:
	var idx: int = mine_view.pick_node(cam.camera.project_ray_origin(pos), cam.camera.project_ray_normal(pos))
	if idx < 0:
		return
	var n: Dictionary = Mine.node_of(mine_view.layout(), idx)
	if mine_view.to_mine(my_pos).distance_to(Vector2(float(n["x"]), float(n["z"]))) > FWConst.MINE_GATHER_RANGE:
		Sfx.play(self, "error")
		_feedback("too_far")
		return
	Sfx.play(self, "click")
	client.mine_gather(idx)


func _on_teleported(p: Vector2) -> void:
	if client.mine_id != "" and mine_view.in_mine():
		my_pos = mine_view.to_world(p.x, p.y)
		my_avatar.teleport_to(my_pos)
		_last_sent = p
		return
	if inside_id > 0:
		return
	my_pos = Vector3(p.x, client.mirror.ground_height(p.x, p.y), p.y)
	my_avatar.teleport_to(my_pos)
	_last_sent = p


func set_god_kind(k: String) -> void:
	god_kind = k
	if k != "":
		set_build_type("")


func _god_mesh(kind: String) -> ArrayMesh:
	if _god_meshes.has(kind):
		return _god_meshes[kind]
	var mb := MeshBuilder.new()
	match kind:
		"sheep":
			mb.add_box(Vector3(0, 0.55, 0), Vector3(0.7, 0.55, 1.0), Color("f2f0e8"))
			mb.add_box(Vector3(0, 0.75, 0.6), Vector3(0.35, 0.35, 0.35), Color("3a3a3a"))
			for lx in [-0.22, 0.22]:
				for lz in [-0.35, 0.35]:
					mb.add_box(Vector3(lx, 0.15, lz), Vector3(0.12, 0.3, 0.12), Color("3a3a3a"))
		"deer":
			mb.add_box(Vector3(0, 1.0, 0), Vector3(0.55, 0.6, 1.3), Color("a8703c"))
			mb.add_box(Vector3(0, 1.55, 0.75), Vector3(0.28, 0.6, 0.28), Color("a8703c"))
			mb.add_box(Vector3(0, 1.95, 0.8), Vector3(0.3, 0.3, 0.4), Color("8f5a2c"))
			for lx in [-0.18, 0.18]:
				for lz in [-0.5, 0.5]:
					mb.add_box(Vector3(lx, 0.35, lz), Vector3(0.1, 0.7, 0.1), Color("6b4a2d"))
		"rabbit":
			mb.add_box(Vector3(0, 0.22, 0), Vector3(0.3, 0.3, 0.45), Color("d9cfc0"))
			mb.add_box(Vector3(0, 0.4, 0.25), Vector3(0.22, 0.22, 0.22), Color("d9cfc0"))
			mb.add_box(Vector3(-0.06, 0.65, 0.25), Vector3(0.06, 0.28, 0.06), Color("d9cfc0"))
			mb.add_box(Vector3(0.06, 0.65, 0.25), Vector3(0.06, 0.28, 0.06), Color("d9cfc0"))
		"tree":
			_god_meshes[kind] = streamer._tree_mesh
			return streamer._tree_mesh
		_:
			_god_meshes[kind] = streamer._rock_mesh
			return streamer._rock_mesh
	var m := mb.build()
	_god_meshes[kind] = m
	return m


func _sync_god() -> void:
	if _god_mat == null:
		_god_mat = MeshBuilder.material()
	var seen := {}
	for e in client.god_list:
		var id := int(e[0])
		seen[id] = true
		var kind := str(e[1])
		var gx := float(e[2])
		var gz := float(e[3])
		var node: MeshInstance3D = god_nodes.get(id)
		if node == null:
			node = MeshInstance3D.new()
			node.mesh = _god_mesh(kind)
			node.material_override = _god_mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.position = Vector3(gx, world.height_at(gx, gz) - 0.1, gz)
			node.set_meta("kind", kind)
			add_child(node)
			god_nodes[id] = node
		node.set_meta("tx", gx)
		node.set_meta("tz", gz)
	for id in god_nodes.keys():
		if not seen.has(id):
			god_nodes[id].queue_free()
			god_nodes.erase(id)


func _sync_coins() -> void:
	for n in coin_nodes:
		n.queue_free()
	coin_nodes.clear()
	if not bool(client.minigame.get("active", false)):
		return
	if _coin_mesh == null:
		var mb := MeshBuilder.new()
		mb.add_box(Vector3(0, 0.9, 0), Vector3(0.5, 0.5, 0.12), Color("ffd24a"))
		mb.add_box(Vector3(0, 0.9, 0), Vector3(0.3, 0.3, 0.16), Color("fff1a8"))
		_coin_mesh = mb.build()
	if _god_mat == null:
		_god_mat = MeshBuilder.material()
	for c in client.minigame.get("coins", []):
		var node := MeshInstance3D.new()
		node.mesh = _coin_mesh
		node.material_override = _god_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = Vector3(float(c[0]), world.height_at(float(c[0]), float(c[1])), float(c[1]))
		add_child(node)
		coin_nodes.append(node)


func _sync_race() -> void:
	for n in race_nodes:
		n.queue_free()
	race_nodes.clear()
	if not client.race_active():
		return
	if _race_mesh_next == null:
		var a := MeshBuilder.new()
		a.add_box(Vector3(-1.2, 2.0, 0), Vector3(0.3, 4.0, 0.3), Color("ffd24a"))
		a.add_box(Vector3(1.2, 2.0, 0), Vector3(0.3, 4.0, 0.3), Color("ffd24a"))
		a.add_box(Vector3(0, 4.0, 0), Vector3(2.7, 0.35, 0.3), Color("ffd24a"))
		_race_mesh_next = a.build()
		var b := MeshBuilder.new()
		b.add_box(Vector3(-1.2, 1.5, 0), Vector3(0.25, 3.0, 0.25), Color("6f8fb8"))
		b.add_box(Vector3(1.2, 1.5, 0), Vector3(0.25, 3.0, 0.25), Color("6f8fb8"))
		b.add_box(Vector3(0, 3.0, 0), Vector3(2.65, 0.3, 0.25), Color("6f8fb8"))
		_race_mesh_other = b.build()
	if _god_mat == null:
		_god_mat = MeshBuilder.material()
	var nxt: int = int(client.race.get("next", 0))
	var pts: Array = client.race.get("pts", [])
	for i in range(nxt, pts.size()):
		var node := MeshInstance3D.new()
		node.mesh = _race_mesh_next if i == nxt else _race_mesh_other
		node.material_override = _god_mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var gx := float(pts[i][0])
		var gz := float(pts[i][1])
		node.position = Vector3(gx, world.height_at(gx, gz), gz)
		var prev: Vector2 = Vector2(float(pts[i - 1][0]), float(pts[i - 1][1])) if i > 0 else Vector2(my_pos.x, my_pos.z)
		node.rotation.y = atan2(gx - prev.x, gz - prev.y)
		add_child(node)
		race_nodes.append(node)


func _update_disaster(dt: float) -> void:
	var kind: String = client.disaster_kind()
	_flash = maxf(0.0, _flash - dt * 4.0)
	if kind == "storm" and randf() < dt * 0.3:
		_flash = 1.0
	cam.shake = 0.12 if kind == "quake" else 0.0


func _update_god(dt: float) -> void:
	_update_disaster(dt)
	for n in coin_nodes:
		n.rotation.y += dt * 3.0
	for node in god_nodes.values():
		if not FWConst.GOD_ANIMALS.has(str(node.get_meta("kind"))):
			continue
		var tx: float = float(node.get_meta("tx"))
		var tz: float = float(node.get_meta("tz"))
		var cur := Vector2(node.position.x, node.position.z)
		var tgt := Vector2(tx, tz)
		if cur.distance_to(tgt) > 0.02:
			var nxt: Vector2 = cur.move_toward(tgt, float(FWConst.GOD_ANIMALS[str(node.get_meta("kind"))]) * 1.3 * dt)
			node.rotation.y = lerp_angle(node.rotation.y, atan2(nxt.x - cur.x, nxt.y - cur.y), minf(dt * 8.0, 1.0))
			node.position = Vector3(nxt.x, world.height_at(nxt.x, nxt.y) - 0.05, nxt.y)


func _sync_remote(_dt: float) -> void:
	_update_god(_dt)
	for pname in client.players:
		if pname == client.my_name:
			continue
		var data: Dictionary = client.players[pname]
		var av = avatars.get(pname)
		if av == null:
			av = Avatar.new()
			add_child(av)
			av.setup(pname, Avatar.color_for(pname), false)
			var first_pos: Vector3 = data["pos"]
			if str(data.get("mine", "")) != "":
				first_pos = mine_view.to_world(first_pos.x, first_pos.z)
			av.teleport_to(first_pos)
			av.set_meta("space", str(data.get("mine", "")))
			avatars[pname] = av
		if data["role"] != FWConst.ROLE_PLAYER:
			av.label.modulate = Color("ffd24a")
		# بازیکن داخل معدن مختصات محلی دارد؛ فقط کسانی که در همان معدن‌اند دیده می‌شوند.
		var their_mine: String = str(data.get("mine", ""))
		var rpos: Vector3 = data["pos"]
		if their_mine != "":
			rpos = mine_view.to_world(rpos.x, rpos.z)
		if str(av.get_meta("space", "")) != their_mine:
			av.set_meta("space", their_mine)
			av.teleport_to(rpos)
		av.target = rpos
		av.target_yaw = data["yaw"]
		av.visible = int(data.get("inside", 0)) == 0 and their_mine == client.mine_id
	for pname in avatars.keys():
		if not client.players.has(pname):
			avatars[pname].queue_free()
			avatars.erase(pname)
	for n in client.npcs:
		var nid := int(n[0])
		var nv = npc_avatars.get(nid)
		var npos := Vector3(float(n[1]), world.height_at(float(n[1]), float(n[2])), float(n[2]))
		if nv == null:
			nv = Avatar.new()
			add_child(nv)
			nv.setup(str(n[4]), Color.from_hsv(float(nid) * 0.19, 0.25, 0.8), true)
			nv.teleport_to(npos)
			npc_avatars[nid] = nv
		var old: Vector3 = nv.target
		if Vector2(old.x, old.z).distance_to(Vector2(npos.x, npos.z)) > 0.05:
			nv.target_yaw = atan2(npos.x - old.x, npos.z - old.z)
		nv.target = npos
		nv.sub_label.text = Loc.t("state_" + str(n[3]))


## شفافیت نام NPC بر حسب فاصله: ۱ تا ۶۰٪ فاصلهٔ مجاز، سپس خطی تا ۰ در فاصلهٔ مجاز.
static func npc_label_alpha(dist: float, limit: float) -> float:
	var start := limit * 0.6
	return clampf((limit - dist) / maxf(limit - start, 0.001), 0.0, 1.0)


func _update_label_visibility() -> void:
	var f: Vector3 = cam.focus
	var limit: float = 38.0 if mode == "life" else cam.world_distance * 0.9
	for id in building_nodes:
		var node: Node3D = building_nodes[id]
		var show: bool = Vector2(node.position.x, node.position.z).distance_to(Vector2(f.x, f.z)) < limit
		for c in node.get_children():
			if c is Label3D:
				c.visible = show
	for av in avatars.values():
		av.label.visible = av.position.distance_to(f) < 70.0 or mode == "world"
	# نام NPCهای دور به‌تدریج محو می‌شود (از ۶۰٪ تا ۱۰۰٪ فاصلهٔ مجاز)، نه ناگهانی.
	var npc_end: float = 45.0 if mode == "life" else cam.world_distance * 0.9
	for nv in npc_avatars.values():
		var a := npc_label_alpha(nv.position.distance_to(f), npc_end)
		for l in [nv.label, nv.sub_label]:
			if l != null:
				l.visible = a > 0.01
				l.modulate.a = a


func _update_sky(h: float) -> void:
	var day := clampf(sin((h - 6.0) / 12.0 * PI), -1.0, 1.0)
	var light := clampf(day * 1.6, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(day) / 0.4, 0.0, 1.0)
	var elev := lerpf(38.0, 68.0, clampf(day, 0.0, 1.0)) if day > 0.0 else 38.0
	var az := lerpf(-100.0, 100.0, clampf((h - 6.0) / 12.0, 0.0, 1.0))
	sun.rotation_degrees = Vector3(-elev, az, 0.0)
	var day_col := Color(1.0, 0.97, 0.9)
	var dusk_col := Color(1.0, 0.7, 0.45)
	var night_col := Color(0.45, 0.55, 1.0)
	var col := night_col.lerp(day_col, light).lerp(dusk_col, dusk * 0.6 * light)
	sun.light_color = col
	sun.light_energy = lerpf(0.2, 0.85, light) * _weather_light()
	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.26, 0.52, 0.88), light)
	var horizon := Color(0.05, 0.07, 0.15).lerp(Color(0.7, 0.84, 0.95), light).lerp(Color(0.96, 0.58, 0.34), dusk * 0.7)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = top.darkened(0.3)
	env.ambient_light_color = Color(0.13, 0.17, 0.32).lerp(Color(0.62, 0.68, 0.78), light)
	env.ambient_light_energy = lerpf(0.9, 0.7, light)
	env.fog_light_color = horizon
