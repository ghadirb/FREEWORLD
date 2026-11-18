extends Node3D
## دنیای سه‌بعدی: زمین، ساختمان‌ها، بازیکنان، NPCها، دوربین، ورودی و حالت ساخت.
## منطق بازی اینجا نیست؛ فقط درخواست می‌فرستد و وضعیت سرور را نشان می‌دهد.

const FWConst = preload("res://scripts/core/const.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const Loc = preload("res://scripts/client/loc.gd")
const Sfx = preload("res://scripts/client/sfx.gd")
const MeshBuilder = preload("res://scripts/client/mesh_builder.gd")
const BuildingMesh = preload("res://scripts/client/building_mesh.gd")
const Avatar = preload("res://scripts/client/avatar.gd")
const CameraRig = preload("res://scripts/client/camera_rig.gd")
const Streamer = preload("res://scripts/client/terrain_streamer.gd")

signal building_tapped(id: int)
signal ghost_changed(error: String)
signal mode_changed(new_mode: String)

const HEIGHTS := {"house": 4.4, "shop": 4.0, "farm": 1.3, "road": 0.2, "well": 2.5, "bakery": 4.4}

var client
var world
var cam
var streamer
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var water: MeshInstance3D
var my_avatar
var avatars: Dictionary = {}
var npc_avatars: Dictionary = {}
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
	streamer.setup(world, _radius_for_quality())
	cam = CameraRig.new()
	cam.name = "CameraRig"
	add_child(cam)
	cam.setup(world)
	_setup_water()
	my_pos = Vector3(client.spawn.x, world.height_at(client.spawn.x, client.spawn.y), client.spawn.y)
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
	set_mode("world" if mode == "life" else "life")


func set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	cam.mode = m
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
	if type == "farm" or type == "bakery":
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
		_touches[e.index] = {"start": e.position, "pos": e.position, "t0": Time.get_ticks_msec(), "role": role, "moved": 0.0}
		_pinch_dist = 0.0
	elif _touches.has(e.index):
		var t: Dictionary = _touches[e.index]
		if t["role"] == "joy":
			_joy_touch = -1
			joy = Vector2.ZERO
			joy_active = false
		elif _touches.size() == 1 and float(t["moved"]) < 24.0 and Time.get_ticks_msec() - int(t["t0"]) < 400:
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
			_mouse_left = {"t0": Time.get_ticks_msec(), "moved": 0.0}
		elif not _mouse_left.is_empty():
			if float(_mouse_left["moved"]) < 8.0 and Time.get_ticks_msec() - int(_mouse_left["t0"]) < 500:
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


func _process(delta: float) -> void:
	if client == null or not client.is_logged_in:
		return
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
	streamer.update_focus(cam.focus)
	# دوربین نمای شهر دور است؛ مه را کم می‌کنیم تا رنگ‌ها شسته نشوند.
	env.fog_density = lerpf(env.fog_density, _fog_base() * (1.0 if mode == "life" else 0.22), minf(dt * 3.0, 1.0))
	water.position = Vector3(snappedf(cam.focus.x, 16.0), 0.0, snappedf(cam.focus.z, 16.0))
	_time = lerpf(_time + dt * FWConst.TIME_SCALE, client.world_time, minf(dt * 0.5, 1.0))
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
	var dir: Vector3 = (cam.right_flat() * input.x + cam.forward_flat() * (-input.y)).normalized()
	var step := dir * FWConst.PLAYER_SPEED * len * dt
	var nx := my_pos.x + step.x
	var nz := my_pos.z + step.z
	var lo := -FWConst.WORLD_LIMIT
	var hi := FWConst.CITY_SIZE + FWConst.WORLD_LIMIT
	var mirror = client.mirror
	if mirror.is_walkable(nx, nz) and nx > lo and nx < hi and nz > lo and nz < hi:
		my_pos.x = nx
		my_pos.z = nz
	elif mirror.is_walkable(nx, my_pos.z):
		my_pos.x = nx
	elif mirror.is_walkable(my_pos.x, nz):
		my_pos.z = nz
	else:
		return
	my_pos.y = world.height_at(my_pos.x, my_pos.z)
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


func _on_teleported(p: Vector2) -> void:
	my_pos = Vector3(p.x, world.height_at(p.x, p.y), p.y)
	my_avatar.teleport_to(my_pos)
	_last_sent = p


func _sync_remote(_dt: float) -> void:
	for pname in client.players:
		if pname == client.my_name:
			continue
		var data: Dictionary = client.players[pname]
		var av = avatars.get(pname)
		if av == null:
			av = Avatar.new()
			add_child(av)
			av.setup(pname, Avatar.color_for(pname), false)
			av.teleport_to(data["pos"])
			avatars[pname] = av
		if data["role"] != FWConst.ROLE_PLAYER:
			av.label.modulate = Color("ffd24a")
		av.target = data["pos"]
		av.target_yaw = data["yaw"]
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
	sun.light_energy = lerpf(0.2, 0.85, light)
	var top := Color(0.02, 0.03, 0.09).lerp(Color(0.26, 0.52, 0.88), light)
	var horizon := Color(0.05, 0.07, 0.15).lerp(Color(0.7, 0.84, 0.95), light).lerp(Color(0.96, 0.58, 0.34), dusk * 0.7)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = top.darkened(0.3)
	env.ambient_light_color = Color(0.13, 0.17, 0.32).lerp(Color(0.62, 0.68, 0.78), light)
	env.ambient_light_energy = lerpf(0.9, 0.7, light)
	env.fog_light_color = horizon
