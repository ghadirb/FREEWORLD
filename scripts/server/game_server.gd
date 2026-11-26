extends Node
## سرور معتبر (Authoritative). همهٔ تصمیم‌ها اینجا و در CityState گرفته می‌شود؛
## کلاینت فقط درخواست می‌فرستد و نتیجه را می‌گیرد.

const Boat = preload("res://scripts/shared/boat.gd")
const FWConst = preload("res://scripts/core/const.gd")
const CityState = preload("res://scripts/server/city_state.gd")
const Persistence = preload("res://scripts/server/persistence.gd")
const NpcSim = preload("res://scripts/server/npc_sim.gd")
const Book = preload("res://scripts/server/book.gd")
const Arenas = preload("res://scripts/server/arenas.gd")
const ScenarioApply = preload("res://scripts/server/scenario_apply.gd")
const TlsSetup = preload("res://scripts/networking/tls_setup.gd")
const Mine = preload("res://scripts/shared/mine.gd")

const NAME_PATTERN := "^[\\p{L}\\p{N}_]{3,16}$"
const AUTH_TIMEOUT_MSEC := 10000
const MAX_LOGIN_FAILURES := 5
const TICK_INTERVAL := 0.1
const STOCK_INTERVAL := 2.0
## هر چند ثانیه دستاوردهای کتاب برای همهٔ بازیکنان آنلاین سنجیده می‌شود (ارزان: فقط شمارش و مقایسه).
const BOOK_INTERVAL := 4.0
const AUTOSAVE_INTERVAL := 10.0  # SIGTERM بدون ذخیره می‌میرد؛ ضرر احتمالی ≤ ۱۰ ثانیه
const SAVE_DEBOUNCE_MSEC := 1000
## شناسهٔ بازیکن میزبان (همان گوشی). در ENet شناسهٔ ۱ همیشه خود سرور است و به هیچ کلاینت راه دوری داده نمی‌شود.
const LOCAL_PID := 1
const LOCAL_METHODS := [
	"c2s_login", "c2s_move", "c2s_place", "c2s_remove", "c2s_collect",
	"c2s_chat", "c2s_set_role", "c2s_get_audit", "c2s_job", "c2s_set_world", "c2s_enter", "c2s_leave",
	"c2s_place_block", "c2s_remove_block", "c2s_paint_block", "c2s_build_region", "c2s_paste", "c2s_bp_save", "c2s_bp_op", "c2s_arena_create", "c2s_arena_edit", "c2s_arena_import", "c2s_arena_op", "c2s_civ", "c2s_undo", "c2s_gather", "c2s_dig", "c2s_fill", "c2s_craft", "c2s_trade", "c2s_offer", "c2s_offer_answer", "c2s_npc", "c2s_npc_sell", "c2s_npc_buy", "c2s_furn_place", "c2s_furn_remove", "c2s_minigame_start", "c2s_race_start", "c2s_grace", "c2s_boat", "c2s_horse", "c2s_car", "c2s_fish", "c2s_disaster", "c2s_god",
	"c2s_mine_enter", "c2s_mine_leave", "c2s_mine_gather", "c2s_book", "c2s_quest",
]

var net: Node
var cs
var save_path: String = ""
var peers: Dictionary = {}
var by_name: Dictionary = {}
var running: bool = false
var local_client = null  # GameClient همین پردازه (حالت تک‌نفره یا میزبان)

var _listening: bool = false
var _name_re := RegEx.new()
var _dirty: bool = false
var _last_save_msec: int = 0
var _tick_acc: float = 0.0
var _train_acc: float = FWConst.TRAIN_CLOCK_INTERVAL   # بلافاصله بعد از شروع یک بار می‌فرستد
var _god_acc: float = 0.0
var _stock_acc: float = 0.0
var _book_acc: float = 0.0
var _autosave_acc: float = 0.0
var _last_stocks: Dictionary = {}
var _last_market: Dictionary = {}
var _cert_pem: String = ""
var _cert_sock := PacketPeerUDP.new()  # پاسخ به درخواست گواهی (port+1)


## مقدار برگشتی: OK یا کد خطا.
func start(port: int, seed_value: int, data_dir: String, admins: Array, tls_dir: String = "", creative: bool = false, force_creative: bool = false, scenario: String = "") -> int:
	_name_re.compile(NAME_PATTERN)
	save_path = data_dir.path_join("city_1.json")
	var loaded: Dictionary = Persistence.load_json(save_path)
	if loaded.is_empty() and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")):
		push_error("[server] save file exists but cannot be read; refusing to start to protect data")
		return ERR_FILE_CORRUPT
	if loaded.is_empty():
		cs = CityState.new(seed_value)
		cs.creative = creative
		if scenario != "":
			var n: int = ScenarioApply.apply(cs, scenario)
			print("[server] scenario %s: %d blocks" % [scenario, n])
		print("[server] new city, seed=%d%s" % [seed_value, " (creative)" if creative else ""])
	else:
		cs = CityState.from_dict(loaded)
		if cs == null:
			push_error("[server] save file is invalid; refusing to start to protect data")
			return ERR_FILE_CORRUPT
		if force_creative:
			cs.creative = creative   # جهان محلی: انتخاب منو برای جهان‌های قدیمی هم اعمال می‌شود
		print("[server] loaded city: %d accounts, %d buildings" % [cs.accounts.size(), cs.buildings.size()])
	for a in admins:
		cs.provision_admin(str(a[0]), str(a[1]))
	NpcSim.ensure_npcs(cs)
	cs.seed_village_life()
	if port > 0:
		var peer := ENetMultiplayerPeer.new()
		var err: int = peer.create_server(port, FWConst.MAX_PLAYERS + 6)
		if err != OK:
			return err
		if FWConst.USE_DTLS:
			var kc: Dictionary = TlsSetup.load_or_create(tls_dir if tls_dir != "" else data_dir)
			var tls: TLSOptions = TlsSetup.server_options(kc)
			if tls == null or peer.host.dtls_server_setup(tls) != OK:
				push_error("[server] cannot enable network encryption (DTLS); refusing to listen unencrypted")
				return ERR_CANT_CREATE
			_cert_pem = TlsSetup.cert_pem(kc)
			if _cert_sock.bind(port + TlsSetup.CERT_PORT_OFFSET) != OK:
				push_error("[server] cannot open the certificate port %d" % (port + TlsSetup.CERT_PORT_OFFSET))
				return ERR_ALREADY_IN_USE
		multiplayer.multiplayer_peer = peer
		multiplayer.server_relay = false
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_listening = true
		print("[server] listening on port %d" % port)
	else:
		print("[server] offline mode (no network port)")
	_save()
	running = true
	return OK


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and running:
		shutdown()
	elif what == NOTIFICATION_APPLICATION_PAUSED and running:
		_save()  # اندروید ممکن است برنامه را در پس‌زمینه ببندد


## توقف کامل سرور داخل برنامه (بازگشت به منو). ذخیره می‌کند و پورت را آزاد می‌کند.
func stop() -> void:
	if running:
		shutdown()
	if _cert_sock.is_bound():
		_cert_sock.close()
	if _listening:
		if multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.disconnect(_on_peer_connected)
		if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		_listening = false
	local_client = null
	peers.clear()
	by_name.clear()
	if net != null:
		net.server = null


# ---------------- بازیکن محلی (بدون شبکه) ----------------

func attach_local(client_node: Node) -> void:
	local_client = client_node
	_on_peer_connected(LOCAL_PID)


func detach_local() -> void:
	if local_client != null:
		local_client = null
		_on_peer_disconnected(LOCAL_PID)


## درخواست کلاینت محلی؛ همان مسیر RPC اما بدون شبکه. نتیجه همیشه از on_* سرور می‌گذرد.
func local_call(method: String, args: Array) -> void:
	if not running or local_client == null or not LOCAL_METHODS.has(method):
		return
	callv("on_" + method.substr(4), [LOCAL_PID] + args)


func _deliver_local(method: String, args: Array) -> void:
	if local_client == null:
		return
	var copy: Array = []
	for v in args:
		copy.append(v.duplicate(true) if (v is Array or v is Dictionary) else v)
	Callable(local_client, "on_" + method.substr(4)).bindv(copy).call_deferred()


func _kick(pid: int) -> void:
	if pid == LOCAL_PID or not _listening:
		return
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(pid)


func shutdown() -> void:
	if not running:
		return
	running = false
	_sync_positions()
	_save()
	print("[server] saved and stopped")


func _save() -> void:
	_dirty = false
	_last_save_msec = Time.get_ticks_msec()
	_sync_positions()
	if not Persistence.save_json(save_path, cs.to_dict()):
		push_error("[server] SAVE FAILED")


func _sync_positions() -> void:
	for pid in peers:
		var p: Dictionary = peers[pid]
		if p["auth"] and cs.accounts.has(p["name"]):
			var pos: Vector3 = _rest_pos(p)
			cs.accounts[p["name"]]["pos"] = [pos.x, pos.y, pos.z]


## فقط درخواست‌های به‌اندازهٔ کافی بزرگ پاسخ می‌گیرند (ضد تقویت DDoS).
func _serve_cert_requests() -> void:
	var n := 0
	while _cert_sock.is_bound() and _cert_sock.get_available_packet_count() > 0 and n < 8:
		n += 1
		var pkt: PackedByteArray = _cert_sock.get_packet()
		if TlsSetup.is_cert_request(pkt) and _cert_pem != "":
			_cert_sock.set_dest_address(_cert_sock.get_packet_ip(), _cert_sock.get_packet_port())
			_cert_sock.put_packet(_cert_pem.to_utf8_buffer())


func _process(delta: float) -> void:
	_serve_cert_requests()
	if not running:
		return
	var dt: float = minf(delta, 0.25)
	cs.tick(dt)
	if not cs.respawned.is_empty():
		for key in cs.respawned:
			var parts: PackedStringArray = str(key).split(",")
			_broadcast("s2c_resource", PackedInt32Array([int(parts[0]), int(parts[1]), 1]))
		cs.respawned.clear()
		_dirty = true
	if not cs.mine_respawned.is_empty():
		for mr in cs.mine_respawned:
			_send_to_mine(str(mr[0]), "s2c_mine_node", int(mr[1]), true)
		cs.mine_respawned.clear()
		_dirty = true
	NpcSim.step(cs, dt)
	cs.god_step(dt)
	if cs.fire_step(dt) or cs.growth_step(dt):
		_broadcast("s2c_god", cs.god_public())
		_dirty = true
	_flush_fire()
	_god_acc += dt
	if _god_acc >= 1.0:
		_god_acc = 0.0
		if cs.god_has_animals():
			_broadcast("s2c_god", cs.god_public())
	_work_step(dt)
	_minigame_step(dt)
	_race_step(dt)
	if cs.civ_step(dt):
		_broadcast("s2c_civ", cs.civ_public())
		_dirty = true
	if cs.disaster_step(dt):
		_broadcast("s2c_disaster", cs.disaster_public())
	var now := Time.get_ticks_msec()
	for pid in peers.keys():
		var p: Dictionary = peers[pid]
		if not p["auth"] and now - int(p["connected_at"]) > AUTH_TIMEOUT_MSEC:
			_kick(pid)
	_tick_acc += dt
	if _tick_acc >= TICK_INTERVAL:
		_tick_acc = 0.0
		_broadcast_tick()
	_train_acc += dt
	if _train_acc >= FWConst.TRAIN_CLOCK_INTERVAL:
		_train_acc = 0.0
		_broadcast("s2c_trains", snappedf(cs.train_clock, 0.01))
	_book_acc += dt
	if _book_acc >= BOOK_INTERVAL:
		_book_acc = 0.0
		for bpid in _auth_peers():
			_check_book(bpid)
	_stock_acc += dt
	if _stock_acc >= STOCK_INTERVAL:
		_stock_acc = 0.0
		_broadcast_stocks()
	_autosave_acc += dt
	if _autosave_acc >= AUTOSAVE_INTERVAL:
		_autosave_acc = 0.0
		_dirty = true
	if _dirty and now - _last_save_msec >= SAVE_DEBOUNCE_MSEC:
		_save()


func _minigame_step(dt: float) -> void:
	if cs.minigame.runs.is_empty():
		return
	var positions: Dictionary = {}
	for pid in _auth_peers():
		var pos: Vector3 = peers[pid]["pos"]
		positions[peers[pid]["name"]] = Vector2(pos.x, pos.z)
	for ev in cs.minigame_step(dt, positions):
		var nm: String = ev["name"]
		if not by_name.has(nm):
			continue
		var pid: int = by_name[nm]
		_send(pid, "s2c_minigame", cs.minigame.public_state(nm))
		if ev["kind"] == "coin" and bool(ev.get("adv", false)) and int(ev["n"]) < int(ev["of"]):
			_notice(pid, "arena_stage", {"n": ev["n"], "of": ev["of"]})
		if ev["kind"] == "hit":
			_notice(pid, "arena_hit")
		if ev["kind"] == "bonus":
			_notice(pid, "arena_bonus")
		if ev["kind"] == "end":
			if int(ev["reward"]) > 0:
				_send(pid, "s2c_money", int(ev["money"]))
				if ev.has("arena") and by_name.has(str(ev["owner"])):
					_send(by_name[str(ev["owner"])], "s2c_money", cs.money_of(str(ev["owner"])))
			if ev.has("arena"):
				_broadcast_arenas()
			_notice(pid, "minigame_end", {"score": ev["score"], "best": ev["best"], "new_best": ev["new_best"], "reward": ev["reward"], "time": ev.get("time", 0.0), "new_time": ev.get("new_time", false), "goal": ev.get("goal", 0), "won": ev.get("won", true)})
			_dirty = true
	# بازیکنی که خارج شد و دورش لغو شد، در حالت‌های بعدی وضعیت تازه می‌گیرد؛ نیازی به ارسال نیست.


func on_disaster(pid: int, kind: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.start_disaster(p["name"], kind)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_disaster", res["disaster"])
	_dirty = true


func _race_step(dt: float) -> void:
	if not cs.race.lobby.is_empty():
		var present: Array = []
		for pid in _auth_peers():
			present.append(peers[pid]["name"])
		for ev in cs.race.lobby_step(dt, present):
			_group_event(ev)
	if cs.race.runs.is_empty():
		return
	var positions: Dictionary = {}
	for pid in _auth_peers():
		var pos: Vector3 = peers[pid]["pos"]
		positions[peers[pid]["name"]] = Vector2(pos.x, pos.z)
	for ev in cs.race_step(dt, positions):
		var nm: String = ev["name"]
		if not by_name.has(nm):
			continue
		var pid: int = by_name[nm]
		_send(pid, "s2c_race", cs.race.public_state(nm))
		if ev["kind"] == "end":
			if int(ev["reward"]) > 0:
				_send(pid, "s2c_money", int(ev["money"]))
			_notice(pid, "race_end", {"boat": ev.get("boat", false), "car": ev.get("car", false), "group": ev.get("group", false), "rank": ev.get("rank", 0), "of": ev.get("of", 0), "finished": ev["finished"], "time": ev["time"], "best": ev["best"], "new_best": ev["new_best"], "reward": ev["reward"]})
			_dirty = true


## سالن انتظار مسابقهٔ گروهی را به همهٔ بازیکنان اعلام می‌کند.
func _announce_lobby() -> void:
	var info: Dictionary = cs.race.lobby_info()
	if info.is_empty():
		return
	for pid in _auth_peers():
		_notice(pid, "grace_lobby", info)


func _group_event(ev: Dictionary) -> void:
	if ev["kind"] == "cancel":
		for nm in ev["members"]:
			if by_name.has(nm):
				_notice(by_name[nm], "grace_cancel")
		return
	var members: Array = ev["members"]
	var center: Vector2 = ev["pos"]
	for i in members.size():
		var nm: String = members[i]
		if not by_name.has(nm):
			continue
		var pid: int = by_name[nm]
		var p: Dictionary = peers[pid]
		var a: float = TAU * float(i) / float(members.size())
		var x: float = center.x + cos(a) * 1.5
		var z: float = center.y + sin(a) * 1.5
		if not cs.is_walkable(x, z, float(p["pos"].y)):
			x = center.x
			z = center.y
		p["pos"] = Vector3(x, cs.ground_height(x, z, float(p["pos"].y)), z)
		p["last_move"] = Time.get_ticks_msec()
		_send(pid, "s2c_teleport", x, z)
		_send(pid, "s2c_race", cs.race.public_state(nm))
		_notice(pid, "grace_start", {"n": members.size()})
	_dirty = true


## مسابقهٔ گروهی هم‌زمان (پروتکل ۲۹): اولین نفر سالن را باز می‌کند؛ بقیه با همین دکمه می‌پیوندند.
func on_grace(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var nm: String = p["name"]
	if _indoors(p) or str(p.get("mine", "")) != "" or bool(p.get("boat", false)) or bool(p.get("horse", false)) or bool(p.get("car", false)) \
			or float(p.get("alt", 0.0)) > FWConst.FLY_MIN_ALT or cs.race.is_running(nm) or cs.minigame.is_running(nm):
		_notice(pid, "grace_busy")
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.race_group(nm, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_announce_lobby()


func on_race_start(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	if bool(p.get("horse", false)):
		_notice(pid, "horse_busy")
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.race_start(p["name"], Vector2(pos.x, pos.z), bool(p.get("boat", false)), bool(p.get("car", false)))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_race", cs.race.public_state(p["name"]))


func on_boat(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var nm: String = p["name"]
	if cs.race.is_running(nm) or cs.minigame.is_running(nm):
		_notice(pid, "boat_busy")
		return
	var pos: Vector3 = p["pos"]
	var here := Vector2(pos.x, pos.z)
	if bool(p.get("boat", false)):
		var land: Vector2 = Boat.find_land_near(cs, here, FWConst.BOAT_BOARD_RANGE, pos.y)
		if not Boat.found(land):
			_notice(pid, "boat_no_shore")
			return
		p["boat"] = false
		p["pos"] = Vector3(land.x, cs.ground_height(land.x, land.y), land.y)
		_send(pid, "s2c_boat", false)
		_send(pid, "s2c_teleport", land.x, land.y)
	else:
		if float(p.get("alt", 0.0)) > FWConst.FLY_MIN_ALT:
			_notice(pid, "boat_busy")
			return
		if bool(p.get("horse", false)) or bool(p.get("car", false)):
			_notice(pid, "boat_busy")
			return
		if not cs.has_boat(cs.accounts[nm]):
			_notice(pid, "need_boat")
			return
		var water: Vector2 = Boat.find_water_near(cs, here, FWConst.BOAT_BOARD_RANGE)
		if not Boat.found(water):
			_notice(pid, "boat_no_water")
			return
		p["boat"] = true
		p["pos"] = Vector3(water.x, FWConst.SEA_LEVEL, water.y)
		_send(pid, "s2c_boat", true)
		_send(pid, "s2c_teleport", water.x, water.y)
	_dirty = true


func on_horse(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var nm: String = p["name"]
	if bool(p.get("horse", false)):
		p["horse"] = false
		_send(pid, "s2c_horse", false)
		_dirty = true
		return
	if _indoors(p) or str(p.get("mine", "")) != "" or bool(p.get("boat", false)) or bool(p.get("car", false)) or float(p.get("alt", 0.0)) > FWConst.FLY_MIN_ALT \
			or cs.race.is_running(nm) or cs.minigame.is_running(nm):
		_notice(pid, "horse_busy")
		return
	if not cs.has_horse(cs.accounts[nm]):
		_notice(pid, "need_horse")
		return
	p["horse"] = true
	_send(pid, "s2c_horse", true)
	_dirty = true


## ماشین (پروتکل ۲۷): مثل اسب ولی سریع‌تر؛ فقط روی خشکی، بدون ساختمان/معدن/قایق/پرواز/مسابقه.
func on_car(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var nm: String = p["name"]
	if bool(p.get("car", false)):
		if cs.race.is_running(nm):
			_notice(pid, "car_busy")   # وسط مسابقه از ماشین پیاده نمی‌شود
			return
		p["car"] = false
		_send(pid, "s2c_car", false)
		_dirty = true
		return
	if _indoors(p) or str(p.get("mine", "")) != "" or bool(p.get("boat", false)) or bool(p.get("horse", false)) or float(p.get("alt", 0.0)) > FWConst.FLY_MIN_ALT \
			or cs.race.is_running(nm) or cs.minigame.is_running(nm):
		_notice(pid, "car_busy")
		return
	if not cs.has_car(cs.accounts[nm]):
		_notice(pid, "need_car")
		return
	p["car"] = true
	_send(pid, "s2c_car", true)
	_dirty = true


func on_fish(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var nm: String = p["name"]
	var pos: Vector3 = p["pos"]
	if _indoors(p) or str(p.get("mine", "")) != "" or float(p.get("alt", 0.0)) > FWConst.FLY_MIN_ALT:
		_notice(pid, "fish_no_water")
		return
	if not bool(p.get("boat", false)) and not Boat.found(Boat.find_water_near(cs, Vector2(pos.x, pos.z), FWConst.FISH_RANGE)):
		_notice(pid, "fish_no_water")
		return
	var now := Time.get_ticks_msec()
	if now - int(p.get("last_fish", 0)) < FWConst.FISH_COOLDOWN_MS:
		_notice(pid, "fish_wait")
		return
	p["last_fish"] = now
	var res: Dictionary = cs.fish(nm, randf())
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	if int(res["count"]) == 0:
		_notice(pid, "fish_none")
		return
	_push_inv(pid, nm)
	_notice(pid, "fished", {"count": res["count"]})
	_dirty = true


func _broadcast_arenas() -> void:
	var list: Array = cs.arenas_public()
	for q in _auth_peers():
		_send(q, "s2c_arenas", list)


## ساخت میدان در موقعیت فعلی بازیکن (پروتکل ۳۱).
func on_arena_create(pid: int, arena_name: String, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0, obstacles: int = 0, diff: int = 1) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.arena_create(p["name"], arena_name, Vector2(pos.x, pos.z), radius, coins, time, reward, kind, win_pct, obstacles, diff)
	if not bool(res["ok"]):
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_notice(pid, "arena_created")
	_dirty = true
	_broadcast_arenas()


## درون‌ریزی میدان از کد اشتراک (پروتکل ۴۰).
func on_arena_import(pid: int, code: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.arena_import(p["name"], code.substr(0, FWConst.ARENA_CODE_MAX + 1), Vector2(pos.x, pos.z))
	if not bool(res["ok"]):
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_notice(pid, "arena_imported")
	_dirty = true
	_broadcast_arenas()


## ویرایش میدان خود (یا هر میدان برای مدیر)؛ رایگان.
func on_arena_edit(pid: int, id: int, arena_name: String, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0, obstacles: int = 0, diff: int = 1) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var err: String = cs.arena_edit(p["name"], id, arena_name, radius, coins, time, reward, kind, win_pct, obstacles, diff)
	if err != "":
		_notice(pid, err)
		return
	_dirty = true
	_notice(pid, "arena_edited")
	_broadcast_arenas()
	for q in _auth_peers():
		_send(q, "s2c_minigame", cs.minigame.public_state(peers[q]["name"]))


## op: list | play | delete
func on_arena_op(pid: int, op: String, id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	match op:
		"list":
			_send(pid, "s2c_arenas", cs.arenas_public())
		"play":
			if not _allow_action(p):
				_notice(pid, "rate_limited")
				return
			if _indoors(p):
				return
			var pos: Vector3 = p["pos"]
			var res: Dictionary = cs.arena_play(p["name"], id, Vector2(pos.x, pos.z))
			if not bool(res["ok"]):
				_notice(pid, str(res["error"]))
				return
			_send(pid, "s2c_minigame", cs.minigame.public_state(p["name"]))
			_notice(pid, "arena_started", {"parkour": Arenas.clean_kind(cs.arenas.items[id].get("kind", "coins")) == "parkour", "race": Arenas.clean_kind(cs.arenas.items[id].get("kind", "coins")) == "race", "football": Arenas.clean_kind(cs.arenas.items[id].get("kind", "coins")) == "football", "survival": Arenas.clean_kind(cs.arenas.items[id].get("kind", "coins")) == "survival", "adventure": Arenas.clean_kind(cs.arenas.items[id].get("kind", "coins")) == "adventure"})
		"prop_bonus", "prop_hazard", "prop_undo":
			if not _allow_action(p):
				_notice(pid, "rate_limited")
				return
			var ppos: Vector3 = p["pos"]
			var perr: String = cs.arena_prop(p["name"], id, op, Vector2(ppos.x, ppos.z))
			if perr != "":
				_notice(pid, perr)
				return
			_dirty = true
			_notice(pid, "arena_prop_ok")
			_broadcast_arenas()
			for q in _auth_peers():
				_send(q, "s2c_minigame", cs.minigame.public_state(peers[q]["name"]))
		"respawn":
			if not _allow_action(p):
				_notice(pid, "rate_limited")
				return
			var rp: Variant = cs.minigame.respawn_point(p["name"])
			if rp == null:
				return
			var rx: float = rp.x
			var rz: float = rp.y
			p["pos"] = Vector3(rx, cs.ground_height(rx, rz, float(p["pos"].y)), rz)
			p["last_move"] = Time.get_ticks_msec()
			cs.minigame.apply_respawn_penalty(p["name"])
			_send(pid, "s2c_teleport", rx, rz)
			_send(pid, "s2c_minigame", cs.minigame.public_state(p["name"]))
			_notice(pid, "arena_respawned")
		"rate_1", "rate_2", "rate_3", "rate_4", "rate_5":
			if not _allow_action(p):
				_notice(pid, "rate_limited")
				return
			var rerr: String = cs.arena_rate(p["name"], id, int(op.substr(5)))
			if rerr != "":
				_notice(pid, rerr)
				return
			_dirty = true
			_notice(pid, "arena_rated")
			_broadcast_arenas()
		"delete":
			if not _allow_action(p):
				_notice(pid, "rate_limited")
				return
			var err: String = cs.arena_remove(p["name"], id)
			if err != "":
				_notice(pid, err)
				return
			_dirty = true
			_notice(pid, "arena_deleted")
			_broadcast_arenas()
			for q in _auth_peers():
				_send(q, "s2c_minigame", cs.minigame.public_state(peers[q]["name"]))


func on_minigame_start(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.minigame_start(p["name"], Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_minigame", cs.minigame.public_state(p["name"]))


func _work_step(dt: float) -> void:
	var positions: Dictionary = {}
	for pid in _auth_peers():
		var p: Dictionary = peers[pid]
		var pos: Vector3 = p["pos"]
		positions[p["name"]] = Vector2(pos.x, pos.z)
	var online: Dictionary = {}
	for pid in _auth_peers():
		online[peers[pid]["name"]] = -1 if str(peers[pid].get("mine", "")) != "" else int(peers[pid].get("inside", 0))
	cs.energy_step(dt, online)
	for ev in cs.work_step(dt, positions):
		var worker: String = ev["worker"]
		if int(ev["amount"]) > 0:
			if by_name.has(worker):
				_send(by_name[worker], "s2c_money", cs.money_of(worker))
				_notice(by_name[worker], "wage", {"amount": ev["amount"]})
			var employer: String = ev["employer"]
			if by_name.has(employer):
				_send(by_name[employer], "s2c_money", cs.money_of(employer))
			_dirty = true
		elif by_name.has(worker):
			_notice(by_name[worker], "employer_broke", {"employer": ev["employer"]})


# ---------------- ابزارها ----------------

func _auth_peers() -> Array:
	var out: Array = []
	for pid in peers:
		if peers[pid]["auth"]:
			out.append(pid)
	return out


func _send(pid: int, method: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
	if pid == LOCAL_PID:
		match method:
			"s2c_login_result", "s2c_snapshot":
				_deliver_local(method, [a, b, c])
			"s2c_tick":
				_deliver_local(method, [a, b, c, d])
			"s2c_notice", "s2c_player_joined", "s2c_chat", "s2c_teleport", "s2c_mine", "s2c_mine_node", "s2c_bp_data":
				_deliver_local(method, [a, b])
			_:
				_deliver_local(method, [a])
		return
	if not _listening:
		return
	match method:
		"s2c_login_result":
			net.rpc_id(pid, method, a, b, c)
		"s2c_snapshot":
			net.rpc_id(pid, method, a, b, c)
		"s2c_tick":
			net.rpc_id(pid, method, a, b, c, d)
		"s2c_notice", "s2c_player_joined", "s2c_chat", "s2c_teleport", "s2c_mine", "s2c_mine_node", "s2c_bp_data":
			net.rpc_id(pid, method, a, b)
		_:
			net.rpc_id(pid, method, a)


func _broadcast(method: String, a: Variant = null, b: Variant = null, except: int = -1) -> void:
	for pid in _auth_peers():
		if pid != except:
			_send(pid, method, a, b)


func _notice(pid: int, code: String, args: Dictionary = {}) -> void:
	_send(pid, "s2c_notice", code, args)


func _player_of(pid: int) -> Dictionary:
	if peers.has(pid) and peers[pid]["auth"]:
		return peers[pid]
	return {}


func _allow_action(p: Dictionary) -> bool:
	var now := Time.get_ticks_msec()
	var elapsed: float = float(now - int(p["bucket_t"])) / 1000.0
	p["bucket_t"] = now
	p["bucket"] = minf(10.0, float(p["bucket"]) + elapsed * 5.0)
	if float(p["bucket"]) < 1.0:
		return false
	p["bucket"] = float(p["bucket"]) - 1.0
	return true


func _players_public() -> Dictionary:
	var out: Dictionary = {}
	for pid in _auth_peers():
		var p: Dictionary = peers[pid]
		var mine: String = str(p.get("mine", ""))
		var pos: Vector3 = p["mpos"] if mine != "" else p["pos"]   # داخل معدن: مختصات محلی معدن
		out[p["name"]] = [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01),
			snappedf(float(p["yaw"]), 0.01), cs.role_of(p["name"]), int(p.get("inside", 0)), mine,
			snappedf(float(p.get("alt", 0.0)), 0.1), 1 if bool(p.get("boat", false)) else 0, 1 if bool(p.get("horse", false)) else 0,
			1 if bool(p.get("car", false)) else 0]
	return out


func _broadcast_tick() -> void:
	var pl := _players_public()
	var np := NpcSim.public_list(cs)
	for pid in _auth_peers():
		_send(pid, "s2c_tick", cs.world_time, snappedf(cs.wheat_price, 0.01), pl, np)


func _broadcast_stocks() -> void:
	var stocks: Dictionary = {}
	for id in cs.buildings:
		var b: Dictionary = cs.buildings[id]
		if FWConst.PRODUCERS.has(str(b["type"])):
			stocks[id] = int(floor(float(b["stock"])))
	if stocks != _last_stocks:
		_last_stocks = stocks
		_broadcast("s2c_stocks", stocks)
	for pid in _auth_peers():
		var pe: Dictionary = peers[pid]
		var ev: int = int(round(float(cs.accounts[pe["name"]]["energy"])))
		if ev != int(pe.get("last_energy", -1)):
			pe["last_energy"] = ev
			_send(pid, "s2c_energy", ev)
	for pid in _auth_peers():
		var pe2: Dictionary = peers[pid]
		var inv_now: Dictionary = cs.inv_public(pe2["name"])
		if inv_now != pe2.get("last_inv", {}):
			pe2["last_inv"] = inv_now
			_send(pid, "s2c_inv", inv_now)
	var mk: Dictionary = cs.market_public()
	if mk != _last_market:
		_last_market = mk
		_broadcast("s2c_market", mk)


# ---------------- اتصال ----------------

func _on_peer_connected(pid: int) -> void:
	peers[pid] = {
		"name": "", "auth": false, "connected_at": Time.get_ticks_msec(),
		"bucket": 10.0, "bucket_t": Time.get_ticks_msec(),
		"allow": 6.0, "last_move": Time.get_ticks_msec(), "last_tp": 0,
		"pos": Vector3.ZERO, "yaw": 0.0, "alt": 0.0, "failures": 0,
		"mine": "", "mpos": Vector3.ZERO, "boat": false, "horse": false, "car": false,
	}


func _on_peer_disconnected(pid: int) -> void:
	if not peers.has(pid):
		return
	var p: Dictionary = peers[pid]
	peers.erase(pid)
	if p["auth"] and by_name.get(p["name"], -1) == pid:
		by_name.erase(p["name"])
		var pos: Vector3 = _rest_pos(p)
		cs.accounts[p["name"]]["pos"] = [pos.x, pos.y, pos.z]
		_broadcast("s2c_player_left", p["name"])
		_dirty = true
		print("[server] %s left" % p["name"])


func on_login(pid: int, player_name: String, token: String, proto: int) -> void:
	if not peers.has(pid) or peers[pid]["auth"]:
		return
	var p: Dictionary = peers[pid]
	if proto != FWConst.PROTOCOL_VERSION:
		_send(pid, "s2c_login_result", false, "version", {})
		return
	if not _name_re.search(player_name) or token.length() > 128:
		_send(pid, "s2c_login_result", false, "bad_name", {})
		return
	var exists: bool = cs.accounts.has(player_name)
	if not exists and cs.accounts.size() >= FWConst.MAX_ACCOUNTS:
		_send(pid, "s2c_login_result", false, "server_busy", {})
		return
	if not by_name.has(player_name) and _auth_peers().size() >= FWConst.MAX_PLAYERS:
		_send(pid, "s2c_login_result", false, "server_full", {})
		return
	var res: Dictionary = cs.authenticate(player_name, token)
	if not res["ok"]:
		p["failures"] = int(p["failures"]) + 1
		_send(pid, "s2c_login_result", false, str(res["error"]), {})
		if int(p["failures"]) >= MAX_LOGIN_FAILURES:
			_kick(pid)
		return
	if by_name.has(player_name):
		var old: int = by_name[player_name]
		by_name.erase(player_name)
		peers.erase(old)
		_kick(old)
	var acc: Dictionary = cs.accounts[player_name]
	var sp: Array = acc["pos"]
	var pos := Vector3(sp[0], sp[1], sp[2])
	if not cs.is_walkable(pos.x, pos.z, pos.y):
		pos = cs.spawn_position()
	p["name"] = player_name
	p["auth"] = true
	p["pos"] = pos
	by_name[player_name] = pid
	var info := {
		"name": player_name, "token": res["token"], "seed": cs.seed_value, "city_id": cs.city_id,
		"role": acc["role"], "money": acc["money"], "pos": [pos.x, pos.z],
		"time": cs.world_time, "price": cs.wheat_price, "market": cs.market_public(),
		"job": cs.job_of(player_name), "world": cs.world_public(),
		"climate": cs.world.climate,
	}
	_send(pid, "s2c_login_result", true, "", info)
	_send(pid, "s2c_snapshot", cs.all_buildings_public(), NpcSim.public_list(cs), _players_public())
	for batch in cs.block_batches():
		_send(pid, "s2c_blocks", batch)
	_send(pid, "s2c_depleted", cs.depleted_flat())
	_send(pid, "s2c_terrain", cs.terrain_flat())
	_send(pid, "s2c_god", cs.god_public())
	_send(pid, "s2c_fire", cs.nfire_flat())
	_send(pid, "s2c_minigame", cs.minigame.public_state(player_name))
	_send(pid, "s2c_arenas", cs.arenas_public())
	_send(pid, "s2c_civ", cs.civ_public())
	_send(pid, "s2c_disaster", cs.disaster_public())
	_send(pid, "s2c_race", cs.race.public_state(player_name))
	_send(pid, "s2c_book", Book.public_state(cs, player_name))
	p["last_inv"] = cs.inv_public(player_name)
	_send(pid, "s2c_inv", p["last_inv"])
	_broadcast("s2c_player_joined", player_name, acc["role"], pid)
	_dirty = true
	print("[server] %s joined (%s)" % [player_name, acc["role"]])


# ---------------- اقدامات بازیکن ----------------

func on_move(pid: int, x: float, z: float, yaw: float, alt: float = 0.0) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if str(p.get("mine", "")) != "":
		_move_in_mine(pid, p, x, z, yaw)
		return
	if int(p.get("inside", 0)) > 0:
		return  # داخل ساختمان موقعیت بیرونی تغییر نمی‌کند
	if not (is_finite(x) and is_finite(z) and is_finite(yaw) and is_finite(alt)):
		return
	var boating: bool = bool(p.get("boat", false))
	# پرواز فقط در جهان خلاقانه و نه سوار قایق؛ در غیر این صورت ارتفاع نادیده گرفته می‌شود.
	var driving: bool = bool(p.get("car", false))
	var mounted: bool = bool(p.get("horse", false)) or driving
	var flying: bool = cs.creative and alt > FWConst.FLY_MIN_ALT and not boating and not mounted
	var now := Time.get_ticks_msec()
	var dt: float = clampf(float(now - int(p["last_move"])) / 1000.0, 0.0, 0.5)
	p["last_move"] = now
	var speed_mult: float = FWConst.RACE_SPEED_MULT if cs.race.is_running(str(p["name"])) or cs.minigame.is_arena_race(str(p["name"])) else 1.0
	if boating:
		speed_mult = FWConst.BOAT_SPEED_MULT
	elif driving:
		speed_mult = FWConst.CAR_SPEED_MULT
		speed_mult *= cs.car_surface_mult(x, z)
	elif mounted:
		speed_mult = FWConst.HORSE_SPEED_MULT
	if flying:
		speed_mult *= FWConst.FLY_SPEED_MULT
	p["allow"] = minf(float(p["allow"]) + FWConst.PLAYER_SPEED * 1.3 * speed_mult * dt, 6.0 * speed_mult)
	var cur: Vector3 = p["pos"]
	var d: float = Vector2(x, z).distance_to(Vector2(cur.x, cur.z))
	var lo: float = -FWConst.WORLD_LIMIT
	var hi: float = FWConst.CITY_SIZE + FWConst.WORLD_LIMIT
	var in_bounds: bool = x >= lo and x <= hi and z >= lo and z <= hi
	var terrain_ok: bool
	var beaching := false
	if boating:
		# قایق فقط روی آب می‌رود؛ رسیدن به ساحل (بیرون از مسابقه) پیاده می‌کند.
		terrain_ok = Boat.is_water(cs, x, z)
		if not terrain_ok and not cs.race.is_running(str(p["name"])) and cs.is_walkable(x, z, cur.y):
			terrain_ok = true
			beaching = true
	else:
		terrain_ok = flying or cs.is_walkable(x, z, cur.y)
	var valid: bool = d <= float(p["allow"]) + 0.05 and in_bounds and terrain_ok
	if valid:
		p["alt"] = clampf(alt, 0.0, FWConst.FLY_MAX_ALT) if flying else 0.0
		p["allow"] = float(p["allow"]) - d
		if boating and not beaching:
			p["pos"] = Vector3(x, FWConst.SEA_LEVEL, z)
		else:
			p["pos"] = Vector3(x, cs.ground_height(x, z, cur.y), z)
		p["yaw"] = yaw
		if beaching:
			p["boat"] = false
			_send(pid, "s2c_boat", false)
	elif d > 0.001 and now - int(p["last_tp"]) > 500:
		p["last_tp"] = now
		_send(pid, "s2c_teleport", cur.x, cur.z)


func on_place(pid: int, req_id: int, type: String, cx: int, cz: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.place_building(p["name"], req_id, type, cx, cz)
	if not res["ok"]:
		if not res.get("silent", false):
			_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_building_added", cs.building_public(res["building"]))
	_send(pid, "s2c_money", int(res["money"]))
	_dirty = true


func on_remove(pid: int, id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.remove_building(p["name"], id)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_building_removed", id)
	for w in res["fired"]:
		if by_name.has(w):
			_send(by_name[w], "s2c_job", 0)
			_notice(by_name[w], "job_lost")
	var owner_name: String = res["owner"]
	if by_name.has(owner_name):
		_send(by_name[owner_name], "s2c_money", cs.money_of(owner_name))
		if owner_name != p["name"]:
			_notice(by_name[owner_name], "your_building_removed", {"by": p["name"]})
	_dirty = true


func on_collect(pid: int, id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if not cs.buildings.has(id):
		_notice(pid, "no_building")
		return
	var door: Vector2 = cs.door_point(cs.buildings[id])
	var pos: Vector3 = p["pos"]
	if Vector2(pos.x, pos.z).distance_to(door) > FWConst.INTERACT_RANGE:
		_notice(pid, "too_far")
		return
	var res: Dictionary = cs.collect(p["name"], id)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_notice(pid, "collected", {"good": res["good"], "count": res["count"], "earned": res["earned"]})
	_dirty = true


func on_chat(pid: int, text: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	var clean := ""
	for ch in text.substr(0, FWConst.CHAT_MAX):
		if ch.unicode_at(0) >= 32:
			clean += ch
	clean = clean.strip_edges()
	if clean == "":
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	_broadcast("s2c_chat", p["name"], clean)


func on_set_role(pid: int, target: String, role: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	var res: Dictionary = cs.set_role(p["name"], target, role)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	if by_name.has(target):
		_send(by_name[target], "s2c_role", role)
	_notice(pid, "role_set", {"target": target, "role": role})
	_dirty = true


func on_set_world(pid: int, key: String, value: Variant) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.set_world(p["name"], key, value)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_world", res["world"])
	_dirty = true


func on_enter(pid: int, id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		_notice(pid, "already_inside")
		return
	if bool(p.get("boat", false)) or bool(p.get("horse", false)) or bool(p.get("car", false)):
		_notice(pid, "boat_busy")
		return
	var pos: Vector3 = p["pos"]
	var err: String = cs.enter_error(p["name"], id, Vector2(pos.x, pos.z))
	if err != "":
		_notice(pid, err)
		return
	p["inside"] = id
	_send(pid, "s2c_inside", id)
	if cs.buildings[id]["type"] == "house":
		_send(pid, "s2c_furn", {"id": id, "items": cs.furn_of(id)})


func on_leave(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if int(p.get("inside", 0)) == 0:
		_notice(pid, "not_inside")
		return
	p["inside"] = 0
	_send(pid, "s2c_inside", 0)


## داخل ساختمان یا معدن؟ در این حالت اقدام‌های دنیای بیرون (ساخت، برداشت، مینی‌بازی…) رد می‌شوند.
## جایی که موقعیت بازیکن ذخیره می‌شود: سوار قایق نزدیک‌ترین ساحل، تا بعداً وسط آب بیدار نشود.
func _rest_pos(p: Dictionary) -> Vector3:
	var pos: Vector3 = p["pos"]
	if not bool(p.get("boat", false)):
		return pos
	var land: Vector2 = Boat.find_land_near(cs, Vector2(pos.x, pos.z), 30.0)
	if Boat.found(land):
		return Vector3(land.x, cs.ground_height(land.x, land.y), land.y)
	return cs.spawn_position()


func _indoors(p: Dictionary) -> bool:
	return int(p.get("inside", 0)) > 0 or str(p.get("mine", "")) != ""


## همهٔ بازیکنانی که الان داخل معدن mine_id هستند پیام می‌گیرند.
func _send_to_mine(mine_id: String, method: String, a: Variant, b: Variant) -> void:
	for pid in _auth_peers():
		if str(peers[pid].get("mine", "")) == mine_id:
			_send(pid, method, a, b)


func _move_in_mine(pid: int, p: Dictionary, x: float, z: float, yaw: float) -> void:
	if not (is_finite(x) and is_finite(z) and is_finite(yaw)):
		return
	var now := Time.get_ticks_msec()
	var dt: float = clampf(float(now - int(p["last_move"])) / 1000.0, 0.0, 0.5)
	p["last_move"] = now
	p["allow"] = minf(float(p["allow"]) + FWConst.PLAYER_SPEED * 1.3 * dt, 6.0)
	var cur: Vector3 = p["mpos"]
	var d: float = Vector2(x, z).distance_to(Vector2(cur.x, cur.z))
	var layout: Dictionary = cs.mine_layout(str(p["mine"]))
	if d <= float(p["allow"]) + 0.05 and Mine.walkable(layout, x, z):
		p["allow"] = float(p["allow"]) - d
		p["mpos"] = Vector3(x, 0.0, z)
		p["yaw"] = yaw
	elif d > 0.001 and now - int(p["last_tp"]) > 500:
		p["last_tp"] = now
		_send(pid, "s2c_teleport", cur.x, cur.z)


func on_mine_enter(pid: int, mine_id: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		_notice(pid, "already_inside")
		return
	var nm: String = p["name"]
	if cs.race.is_running(nm) or cs.minigame.is_running(nm) or bool(p.get("boat", false)) or bool(p.get("horse", false)) or bool(p.get("car", false)):
		_notice(pid, "mine_busy")
		return
	var pos: Vector3 = p["pos"]
	var err: String = cs.mine_enter_error(nm, mine_id, Vector2(pos.x, pos.z))
	if err != "":
		_notice(pid, err)
		return
	var e: Dictionary = cs.world.mine_entrance(mine_id)
	var sp: Vector2 = Mine.spawn_point(cs.mine_layout(mine_id))
	p["mine"] = mine_id
	p["mpos"] = Vector3(sp.x, 0.0, sp.y)
	p["yaw"] = PI
	p["allow"] = 6.0
	p["last_move"] = Time.get_ticks_msec()
	# اگر قطع شود یا سرور ببندد، بازیکن جلوی ورودی معدن (روی زمین بیرون) برمی‌گردد.
	p["pos"] = Vector3(float(e["ex"]), cs.ground_height(float(e["ex"]), float(e["ez"])), float(e["ez"]))
	_send(pid, "s2c_mine", mine_id, cs.mine_depleted_list(mine_id))


func on_mine_leave(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if str(p.get("mine", "")) == "":
		_notice(pid, "not_in_mine")
		return
	p["mine"] = ""
	p["mpos"] = Vector3.ZERO
	_send(pid, "s2c_mine", "", PackedInt32Array())
	var pos: Vector3 = p["pos"]
	_send(pid, "s2c_teleport", pos.x, pos.z)


func on_mine_gather(pid: int, idx: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var mine_id: String = str(p.get("mine", ""))
	if mine_id == "":
		_notice(pid, "not_in_mine")
		return
	var mp: Vector3 = p["mpos"]
	var res: Dictionary = cs.mine_gather(p["name"], mine_id, idx, Vector2(mp.x, mp.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]), {"tool": "pickaxe"})
		return
	_send_to_mine(mine_id, "s2c_mine_node", idx, false)
	if res.get("rested", false):
		_notice(pid, "rested")
	elif res.get("treasure", false):
		_send(pid, "s2c_money", int(res["money"]))
		_notice(pid, "treasure", {"reward": res["reward"]})
	else:
		_push_inv(pid, p["name"])
		_notice(pid, "gathered", {"item": res["item"], "count": res["count"]})
	_dirty = true


func on_get_audit(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not FWConst.is_admin(cs.role_of(p["name"])):
		_notice(pid, "forbidden")
		return
	_send(pid, "s2c_audit", cs.audit.slice(maxi(0, cs.audit.size() - 50)))


## id > 0: شغل گرفتن در آن ساختمان (باید نزدیک باشد)؛ id == 0: ترک شغل.
func on_job(pid: int, id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if id == 0:
		var q: Dictionary = cs.quit_job(p["name"])
		if not q["ok"]:
			_notice(pid, str(q["error"]))
			return
		_send(pid, "s2c_job", 0)
		_notice(pid, "job_quit")
		_dirty = true
		return
	if not cs.buildings.has(id):
		_notice(pid, "no_building")
		return
	var door: Vector2 = cs.door_point(cs.buildings[id])
	var pos: Vector3 = p["pos"]
	if Vector2(pos.x, pos.z).distance_to(door) > FWConst.INTERACT_RANGE:
		_notice(pid, "too_far")
		return
	var res: Dictionary = cs.take_job(p["name"], id)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_job", id)
	_notice(pid, "job_taken", {"employer": cs.buildings[id]["owner"]})
	_dirty = true


# ---------------- ساخت بلوکی و منابع ----------------

func _push_inv(pid: int, name: String) -> void:
	var inv: Dictionary = cs.inv_public(name)
	if peers.has(pid):
		peers[pid]["last_inv"] = inv
	_send(pid, "s2c_inv", inv)


func _near(p: Dictionary, x: float, y: float, z: float, reach: float) -> bool:
	var pos: Vector3 = p["pos"]
	return Vector3(pos.x, pos.y + 1.0, pos.z).distance_to(Vector3(x, y, z)) <= reach


## بلوک نباید روی خود بازیکنان آنلاین قرار بگیرد (گیر می‌افتند).
func _player_in_cell(x: int, y: int, z: int) -> bool:
	for pid in _auth_peers():
		var pos: Vector3 = peers[pid]["pos"]
		if int(floor(pos.x)) == x and int(floor(pos.z)) == z and y >= int(floor(pos.y)) - 0 and y <= int(floor(pos.y)) + 1:
			return true
	return false


func on_place_block(pid: int, req_id: int, x: int, y: int, z: int, type: String, color: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	if not _near(p, float(x) + 0.5, float(y) + 0.5, float(z) + 0.5, FWConst.BLOCK_REACH):
		_notice(pid, "too_far")
		return
	if _player_in_cell(x, y, z):
		_notice(pid, "player_in_way")
		return
	var res: Dictionary = cs.place_block(p["name"], req_id, x, y, z, type, color)
	if not res["ok"]:
		if not res.get("silent", false):
			_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_block", PackedInt32Array([x, y, z, FWConst.BLOCK_ORDER.find(type), color]))
	_push_inv(pid, p["name"])
	_dirty = true


func on_remove_block(pid: int, x: int, y: int, z: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if not _near(p, float(x) + 0.5, float(y) + 0.5, float(z) + 0.5, FWConst.BLOCK_REACH):
		_notice(pid, "too_far")
		return
	var res: Dictionary = cs.remove_block(p["name"], x, y, z)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_block", PackedInt32Array([x, y, z, -1, 0]))
	var owner_name: String = res["owner"]
	if by_name.has(owner_name):
		_push_inv(by_name[owner_name], owner_name)
	_dirty = true


func on_paint_block(pid: int, x: int, y: int, z: int, color: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if not _near(p, float(x) + 0.5, float(y) + 0.5, float(z) + 0.5, FWConst.BLOCK_REACH):
		_notice(pid, "too_far")
		return
	var res: Dictionary = cs.paint_block(p["name"], x, y, z, color)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_block", PackedInt32Array([x, y, z, FWConst.BLOCK_ORDER.find(str(res["type"])), color]))
	_dirty = true


## ---------------- ابزارهای ساخت دسته‌ای (پروتکل ۲۰) ----------------

func _can_build_cell(p: Dictionary, v: Vector3i) -> bool:
	return _near(p, float(v.x) + 0.5, float(v.y) + 0.5, float(v.z) + 0.5, FWConst.BLOCK_REACH) and not _player_in_cell(v.x, v.y, v.z)


## نتیجهٔ عمل دسته‌ای را به همه می‌فرستد (چند بسته)، موجودی‌ها را تازه می‌کند و پیام خلاصه می‌دهد.
func _finish_batch(pid: int, p: Dictionary, res: Dictionary) -> void:
	var flat := PackedInt32Array()
	for ch in res["changed"]:
		var v: Vector3i = ch[0]
		flat.append_array(PackedInt32Array([v.x, v.y, v.z, int(ch[1]), int(ch[2])]))
		if flat.size() >= FWConst.BLOCK_SEND_BATCH * 5:
			_broadcast("s2c_blocks", flat)
			flat = PackedInt32Array()
	if flat.size() > 0:
		_broadcast("s2c_blocks", flat)
	_push_inv(pid, p["name"])
	for owner_name in res.get("owners", {}):
		if str(owner_name) != str(p["name"]) and by_name.has(owner_name):
			_push_inv(by_name[owner_name], owner_name)
	var n: int = int(res["placed"]) + int(res["removed"])
	if n > 0:
		_notice(pid, "batch_done", {"n": n, "skipped": int(res["skipped"])})
		_dirty = true
	elif str(res["error"]) != "":
		_notice(pid, str(res["error"]))
	else:
		_notice(pid, "no_target")


## op: fill (پر کردن), walls (فقط پوسته), clear (پاک کردن). دو گوشهٔ جعبه.
func on_build_region(pid: int, op: String, x1: int, y1: int, z1: int, x2: int, y2: int, z2: int, type: String, color: int) -> void:
	var p := _player_of(pid)
	if p.is_empty() or _indoors(p):
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if not (op == "fill" or op == "walls" or op == "clear"):
		return
	var cells: Array = CityState.region_cells(Vector3i(x1, y1, z1), Vector3i(x2, y2, z2), op == "walls")
	if cells.is_empty():
		_notice(pid, "region_too_big")
		return
	var reachable: Array = []
	for v in cells:
		if _near(p, float(v.x) + 0.5, float(v.y) + 0.5, float(v.z) + 0.5, FWConst.BLOCK_REACH):
			reachable.append(v)
	if reachable.is_empty():
		_notice(pid, "too_far")
		return
	var res: Dictionary
	if op == "clear":
		res = cs.batch_remove(p["name"], reachable)
	else:
		if not FWConst.BLOCK_TYPES.has(type) or not FWConst.meta_valid(color):
			return
		var entries: Array = []
		for v in reachable:
			entries.append([v, type, color])
		res = cs.batch_place(p["name"], entries, func(v: Vector3i) -> bool: return not _player_in_cell(v.x, v.y, v.z))
	_finish_batch(pid, p, res)


## data: هر ۵ عدد یک بلوک: [dx, dy, dz, نوع, رنگ] نسبت به مبدأ (ox, oy, oz).
func on_paste(pid: int, ox: int, oy: int, oz: int, data: PackedInt32Array) -> void:
	var p := _player_of(pid)
	if p.is_empty() or _indoors(p):
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if data.size() == 0 or data.size() % 5 != 0 or data.size() > FWConst.REGION_MAX_VOLUME * 5:
		_notice(pid, "region_too_big")
		return
	var entries: Array = []
	var seen: Dictionary = {}
	var i := 0
	while i < data.size():
		var dx := data[i]
		var dy := data[i + 1]
		var dz := data[i + 2]
		var tid := data[i + 3]
		var col := data[i + 4]
		i += 5
		if absi(dx) > 2 * FWConst.REGION_MAX_SIDE or absi(dy) > 2 * FWConst.REGION_MAX_SIDE or absi(dz) > 2 * FWConst.REGION_MAX_SIDE:
			continue
		if tid < 0 or tid >= FWConst.BLOCK_ORDER.size() or not FWConst.meta_valid(col):
			continue
		var v := Vector3i(ox + dx, oy + dy, oz + dz)
		if seen.has(v):
			continue
		seen[v] = true
		if _near(p, float(v.x) + 0.5, float(v.y) + 0.5, float(v.z) + 0.5, FWConst.BLOCK_REACH):
			entries.append([v, str(FWConst.BLOCK_ORDER[tid]), col])
	if entries.is_empty():
		_notice(pid, "too_far")
		return
	var res: Dictionary = cs.batch_place(p["name"], entries, func(v: Vector3i) -> bool: return not _player_in_cell(v.x, v.y, v.z))
	_finish_batch(pid, p, res)


## ذخیرهٔ سازه در کتابخانهٔ شهر (داده همان خروجی کپی است). دوباره‌کاری اعتبارسنجی در blueprints.gd.
func on_bp_save(pid: int, bp_name: String, data: PackedInt32Array, shared: bool) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.blueprints.save(p["name"], bp_name, data, shared)
	if not bool(res["ok"]):
		_notice(pid, str(res["error"]))
		return
	cs._log(p["name"], "blueprint_save", {"id": res["id"], "shared": shared})
	_dirty = true
	_notice(pid, "bp_saved")
	_send(pid, "s2c_bp_list", cs.blueprints.list_for(p["name"]))


## op: list | load | delete | share | unshare
func on_bp_op(pid: int, op: String, id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	var who: String = p["name"]
	match op:
		"list":
			_send(pid, "s2c_bp_list", cs.blueprints.list_for(who))
			return
		"load":
			var d: PackedInt32Array = cs.blueprints.data_for(who, id)
			if d.is_empty():
				_notice(pid, "bp_missing")
				return
			_send(pid, "s2c_bp_data", id, d)
			return
		"delete":
			if not _allow_action(p):
				_notice(pid, "rate_limited")
				return
			var err: String = cs.blueprints.remove(who, id, FWConst.is_admin(cs.role_of(who)))
			if err != "":
				_notice(pid, err)
				return
			cs._log(who, "blueprint_delete", {"id": id})
		"share", "unshare":
			var err2: String = cs.blueprints.set_shared(who, id, op == "share")
			if err2 != "":
				_notice(pid, err2)
				return
			cs._log(who, "blueprint_" + op, {"id": id})
		_:
			return
	_dirty = true
	_send(pid, "s2c_bp_list", cs.blueprints.list_for(who))


func on_undo(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty() or _indoors(p):
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.undo_last(p["name"], func(v: Vector3i) -> bool: return _can_build_cell(p, v))
	if int(res["placed"]) + int(res["removed"]) == 0 and str(res["error"]) == "":
		res["error"] = "nothing_to_undo"
	_finish_batch(pid, p, res)


func on_gather(pid: int, rx: int, rz: int, tool: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.gather(p["name"], rx, rz, tool, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]), {"tool": str(res.get("tool", ""))})
		return
	_broadcast("s2c_resource", PackedInt32Array([rx, rz, 0]))
	if res.get("cleared", false):
		_notice(pid, "cleared")
		_dirty = true
		return
	if res.get("treasure", false):
		_send(pid, "s2c_money", int(res["money"]))
		_notice(pid, "treasure", {"reward": res["reward"]})
		_dirty = true
		return
	_push_inv(pid, p["name"])
	_notice(pid, "gathered", {"item": res["item"], "count": res["count"]})
	_dirty = true


func on_dig(pid: int, x: float, z: float, tool: String) -> void:
	_terraform_request(pid, x, z, tool, true)


func on_fill(pid: int, x: float, z: float, tool: String) -> void:
	_terraform_request(pid, x, z, tool, false)


func _terraform_request(pid: int, x: float, z: float, tool: String, digging: bool) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p) or not (is_finite(x) and is_finite(z)):
		return
	var pos: Vector3 = p["pos"]
	var at := Vector2(pos.x, pos.z)
	var res: Dictionary = cs.dig(p["name"], x, z, tool, at) if digging else cs.fill(p["name"], x, z, tool, at)
	if not res["ok"]:
		_notice(pid, str(res["error"]), {"tool": str(res.get("tool", ""))})
		return
	var flat := PackedInt32Array()
	for c in res["changes"]:
		flat.append(int(c[0]))
		flat.append(int(c[1]))
		flat.append(int(c[2]))
	_broadcast("s2c_terrain_edit", flat)
	_push_inv(pid, p["name"])
	_notice(pid, "gathered" if digging else "filled", {"item": res["item"], "count": res["count"]})
	_dirty = true


func on_craft(pid: int, recipe: String, times: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.craft(p["name"], recipe, times)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_push_inv(pid, p["name"])
	if res.has("unlock"):
		_notice(pid, "unlocked", {"what": res["unlock"]})
	elif res.has("upgrade"):
		_notice(pid, "upgraded", {"tool": res["upgrade"]})
	else:
		_notice(pid, "crafted", {"item": res["item"], "count": res["count"]})
	_dirty = true


## درخت‌های طبیعیِ سوخته را مثل درخت قطع‌شده حذف و فهرست درخت‌های در حال سوختن را پخش می‌کند.
func _flush_fire() -> void:
	if not cs.burned.is_empty():
		for key in cs.burned:
			var parts: PackedStringArray = str(key).split(",")
			_broadcast("s2c_resource", PackedInt32Array([int(parts[0]), int(parts[1]), 0]))
		cs.burned.clear()
		_dirty = true
	if cs.nfire_dirty:
		cs.nfire_dirty = false
		_broadcast("s2c_fire", cs.nfire_flat())


func on_god(pid: int, action: String, kind: String, x: float, z: float) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if action == "shape":
		var sres: Dictionary = cs.shape_terrain(p["name"], kind, x, z)
		if not sres["ok"]:
			_notice(pid, str(sres["error"]))
			return
		var sflat := PackedInt32Array()
		for c in sres["changes"]:
			sflat.append(int(c[0]))
			sflat.append(int(c[1]))
			sflat.append(int(c[2]))
		_broadcast("s2c_terrain_edit", sflat)
		_dirty = true
		return
	if action == "ignite" or action == "grove":
		var pres: Dictionary = cs.ignite(p["name"], x, z) if action == "ignite" else cs.plant_grove(p["name"], x, z)
		if not pres["ok"]:
			_notice(pid, str(pres["error"]))
			return
		_broadcast("s2c_god", cs.god_public())
		_flush_fire()
		_dirty = true
		return
	var res: Dictionary = cs.god_action(p["name"], action, kind, x, z)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_god", cs.god_public())
	_dirty = true


## تمدن‌سازی (پروتکل ۴۵): فرمان مدیر؛ شبیه‌سازی در سرور جلو می‌رود و وضعیت برای همه پخش می‌شود.
func on_civ(pid: int, op: String, a: int, b: int, x: float, z: float) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.civ_action(p["name"], op.substr(0, 12), a, b, x, z)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_broadcast("s2c_civ", cs.civ_public())
	_dirty = true


func on_npc(pid: int, npc_id: int, item: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.npc_interact(p["name"], npc_id, item, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_push_inv(pid, p["name"])
	if int(res["reward"]) > 0:
		_send(pid, "s2c_money", int(res["money"]))
	_notice(pid, "npc_talk" if res["kind"] == "talk" else "npc_gift",
		{"npc": res["npc"], "points": res["points"], "level": res["level"], "reward": res["reward"], "item": res["item"],
		"role": res["role"], "line": res["line"], "hint": res["hint"], "entry": res["entry"]})
	_check_book(pid)
	_dirty = true


## دستاوردهای تازه را می‌سنجد و برای هر کدام جایزه، اعلان و وضعیت تازهٔ کتاب می‌فرستد.
func _check_book(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty() or _indoors(p):
		return
	var ctx := {"pos": p["pos"], "mine": str(p.get("mine", ""))}
	var got: Array = Book.evaluate(cs, p["name"], ctx)
	if got.is_empty():
		return
	for g in got:
		_notice(pid, "book_unlock", {"id": g["id"], "reward": g["reward"], "bonus_item": g.get("bonus_item", ""), "bonus_n": g.get("bonus_n", 0)})
	_push_inv(pid, p["name"])
	_send(pid, "s2c_money", cs.money_of(p["name"]))
	_send(pid, "s2c_book", Book.public_state(cs, p["name"]))
	_dirty = true


## درخواست دیدن کتاب ماجراجویی (فقط خواندن؛ نرخ‌محدود مثل بقیهٔ درخواست‌ها).
func on_book(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	_check_book(pid)
	_send(pid, "s2c_book", Book.public_state(cs, p["name"]))


func on_npc_sell(pid: int, npc_id: int, item: String, n: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.npc_sell(p["name"], npc_id, item, n, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_push_inv(pid, p["name"])
	_notice(pid, "npc_bought", {"npc": res["npc"], "item": res["item"], "count": res["count"], "total": res["total"]})
	_dirty = true


func on_quest(pid: int, npc_id: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.quest_turn_in(p["name"], npc_id, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_push_inv(pid, p["name"])
	_notice(pid, "quest_done", {"npc": res["npc"], "step": res["step"], "total": res["total"], "reward": res["reward"],
		"item": res["item"], "n": res["n"], "bonus_item": res["bonus_item"], "bonus_n": res["bonus_n"]})
	_check_book(pid)
	_send(pid, "s2c_book", Book.public_state(cs, p["name"]))
	_dirty = true


func on_npc_buy(pid: int, npc_id: int, item: String, n: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if _indoors(p):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.npc_buy(p["name"], npc_id, item, n, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_push_inv(pid, p["name"])
	_notice(pid, "npc_sold", {"npc": res["npc"], "item": res["item"], "count": res["count"], "total": res["total"]})
	_dirty = true


## مبلمان فقط وقتی بازیکن داخل همان خانه است و فقط برای صاحب آن.
func on_furn_place(pid: int, type: String, x: float, z: float, rot: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var bid := int(p.get("inside", 0))
	if bid <= 0:
		_notice(pid, "not_inside")
		return
	var res: Dictionary = cs.furn_place(p["name"], bid, type, x, z, rot)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_send(pid, "s2c_furn", {"id": bid, "items": res["furn"]})
	_dirty = true


func on_furn_remove(pid: int, idx: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var bid := int(p.get("inside", 0))
	if bid <= 0:
		_notice(pid, "not_inside")
		return
	var res: Dictionary = cs.furn_remove(p["name"], bid, idx)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_send(pid, "s2c_furn", {"id": bid, "items": res["furn"]})
	_dirty = true


func on_trade(pid: int, item: String, n: int, buy: bool) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	var res: Dictionary = cs.trade(p["name"], item, n, buy)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	_send(pid, "s2c_money", int(res["money"]))
	_push_inv(pid, p["name"])
	_notice(pid, "bought" if buy else "sold", {"item": item, "count": n, "total": res["total"]})
	_dirty = true


func on_offer(pid: int, to_name: String, item: String, n: int, price: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if not by_name.has(to_name):
		_notice(pid, "offer_offline")
		return
	var res: Dictionary = cs.make_offer(p["name"], to_name, item, n, price)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	var o: Dictionary = res["offer"]
	_send(by_name[to_name], "s2c_offer", {"id": res["id"], "from": o["from"], "item": item, "n": n, "price": price})
	_notice(pid, "offer_sent", {"to": to_name})


func on_offer_answer(pid: int, id: int, accept: bool) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	var res: Dictionary = cs.answer_offer(p["name"], id, accept)
	if not res["ok"]:
		_notice(pid, str(res["error"]))
		return
	var o: Dictionary = res["offer"]
	var seller_pid: int = by_name.get(o["from"], -1)
	if not res["accepted"]:
		if seller_pid >= 0:
			_notice(seller_pid, "offer_declined", {"to": o["to"]})
		return
	for who in [o["from"], o["to"]]:
		if by_name.has(who):
			var wp: int = by_name[who]
			_send(wp, "s2c_money", cs.money_of(who))
			_push_inv(wp, who)
	_notice(pid, "offer_done", {"item": o["item"], "count": o["n"], "price": o["price"]})
	if seller_pid >= 0:
		_notice(seller_pid, "offer_done", {"item": o["item"], "count": o["n"], "price": o["price"]})
	_dirty = true
