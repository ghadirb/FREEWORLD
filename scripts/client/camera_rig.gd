extends Node3D
## دوربین دوحالته: «زندگی» (سوم‌شخص دور شخصیت) و «شهر» (نمای مدیریتی از بالا با جابه‌جایی آزاد).

const FWConst = preload("res://scripts/core/const.gd")

const LIFE_PITCH := -22.0
const WORLD_PITCH := -58.0

var camera: Camera3D
var world
var mode: String = "life"
var focus: Vector3 = Vector3.ZERO      # کانون هدف
var yaw: float = 0.0                   # رادیان
var life_distance: float = 9.0
var world_distance: float = 42.0

var _cur_focus: Vector3 = Vector3.ZERO
var _cur_yaw: float = 0.0
var _cur_pitch: float = LIFE_PITCH
var _cur_dist: float = 9.0
## دید اول‌شخص (فقط در حالت زندگی): دوربین در چشم شخصیت است.
var first_person: bool = false
var fp_pitch: float = 0.0  # درجه؛ مثبت = نگاه به بالا


func setup(world_gen) -> void:
	world = world_gen
	camera = Camera3D.new()
	camera.current = true
	camera.near = 0.2
	camera.far = 600.0
	camera.fov = 65.0
	add_child(camera)


func snap(f: Vector3) -> void:
	focus = f
	_cur_focus = f
	_cur_yaw = yaw
	_apply()


func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx
	if first_person and mode == "life":
		fp_pitch = clampf(fp_pitch - dy * 40.0, -80.0, 80.0)
	elif mode == "life":
		life_pitch_offset = clampf(life_pitch_offset - dy * 30.0, -20.0, 45.0)
	else:
		world_pitch_offset = clampf(world_pitch_offset - dy * 30.0, -25.0, 20.0)


var life_pitch_offset: float = 0.0
var world_pitch_offset: float = 0.0


func zoom_by(factor: float) -> void:
	if first_person and mode == "life":
		return
	if mode == "life":
		life_distance = clampf(life_distance * factor, 4.0, 22.0)
	else:
		world_distance = clampf(world_distance * factor, 14.0, 160.0)


## جابه‌جایی کانون در حالت شهر؛ delta بر حسب متر در دستگاه مختصات صفحه (راست، جلو).
func pan(right_m: float, forward_m: float) -> void:
	var r := Vector3(cos(yaw), 0, -sin(yaw))
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	focus += r * right_m + f * forward_m
	focus.x = clampf(focus.x, -FWConst.WORLD_LIMIT, FWConst.CITY_SIZE + FWConst.WORLD_LIMIT)
	focus.z = clampf(focus.z, -FWConst.WORLD_LIMIT, FWConst.CITY_SIZE + FWConst.WORLD_LIMIT)
	focus.y = world.height_at(focus.x, focus.z)


func set_life_focus(p: Vector3) -> void:
	focus = p + Vector3(0, 1.3, 0)


## بردارهای افقی جلو/راست دوربین برای حرکت شخصیت.
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


var shake: float = 0.0   # قدرت لرزش (زلزله)؛ هر فریم کم می‌شود مگر بیرون تنظیم شود


func _shake_camera() -> void:
	if shake > 0.001:
		camera.global_position += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * shake


func _process(delta: float) -> void:
	if first_person and mode == "life":
		_cur_focus = focus
		_cur_yaw = yaw
		_apply()
		_shake_camera()
		return
	var k := 1.0 - exp(-9.0 * delta)
	var target_pitch := (LIFE_PITCH + life_pitch_offset) if mode == "life" else (WORLD_PITCH + world_pitch_offset)
	var target_dist := life_distance if mode == "life" else world_distance
	_cur_focus = _cur_focus.lerp(focus, k if mode == "world" else 1.0 - exp(-16.0 * delta))
	_cur_yaw = lerp_angle(_cur_yaw, yaw, k)
	_cur_pitch = lerpf(_cur_pitch, target_pitch, k)
	_cur_dist = lerpf(_cur_dist, target_dist, k)
	_apply()
	_shake_camera()


func _apply() -> void:
	if first_person and mode == "life":
		var p := deg_to_rad(fp_pitch)
		var look := Vector3(-sin(_cur_yaw) * cos(p), sin(p), -cos(_cur_yaw) * cos(p))
		var eye := _cur_focus + Vector3(0, 0.3, 0)
		camera.fov = 78.0
		camera.global_position = eye
		camera.look_at(eye + look, Vector3.UP)
		return
	camera.fov = 65.0
	var pitch := deg_to_rad(_cur_pitch)
	var dir := Vector3(sin(_cur_yaw) * cos(pitch), -sin(pitch), cos(_cur_yaw) * cos(pitch))
	var pos := _cur_focus + dir * _cur_dist
	var ground: float = world.height_at(pos.x, pos.z) + 1.2
	pos.y = maxf(pos.y, ground)
	camera.global_position = pos
	camera.look_at(_cur_focus, Vector3.UP)
