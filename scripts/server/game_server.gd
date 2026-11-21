extends Node
## سرور معتبر (Authoritative). همهٔ تصمیم‌ها اینجا و در CityState گرفته می‌شود؛
## کلاینت فقط درخواست می‌فرستد و نتیجه را می‌گیرد.

const FWConst = preload("res://scripts/core/const.gd")
const CityState = preload("res://scripts/server/city_state.gd")
const Persistence = preload("res://scripts/server/persistence.gd")
const NpcSim = preload("res://scripts/server/npc_sim.gd")
const TlsSetup = preload("res://scripts/networking/tls_setup.gd")

const NAME_PATTERN := "^[\\p{L}\\p{N}_]{3,16}$"
const AUTH_TIMEOUT_MSEC := 10000
const MAX_LOGIN_FAILURES := 5
const TICK_INTERVAL := 0.1
const STOCK_INTERVAL := 2.0
const AUTOSAVE_INTERVAL := 10.0  # SIGTERM بدون ذخیره می‌میرد؛ ضرر احتمالی ≤ ۱۰ ثانیه
const SAVE_DEBOUNCE_MSEC := 1000
## شناسهٔ بازیکن میزبان (همان گوشی). در ENet شناسهٔ ۱ همیشه خود سرور است و به هیچ کلاینت راه دوری داده نمی‌شود.
const LOCAL_PID := 1
const LOCAL_METHODS := [
	"c2s_login", "c2s_move", "c2s_place", "c2s_remove", "c2s_collect",
	"c2s_chat", "c2s_set_role", "c2s_get_audit", "c2s_job", "c2s_set_world", "c2s_enter", "c2s_leave",
	"c2s_place_block", "c2s_remove_block", "c2s_paint_block", "c2s_gather", "c2s_dig", "c2s_craft", "c2s_trade",
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
var _stock_acc: float = 0.0
var _autosave_acc: float = 0.0
var _last_stocks: Dictionary = {}
var _last_market: Dictionary = {}
var _cert_pem: String = ""
var _cert_sock := PacketPeerUDP.new()  # پاسخ به درخواست گواهی (port+1)


## مقدار برگشتی: OK یا کد خطا.
func start(port: int, seed_value: int, data_dir: String, admins: Array, tls_dir: String = "") -> int:
	_name_re.compile(NAME_PATTERN)
	save_path = data_dir.path_join("city_1.json")
	var loaded: Dictionary = Persistence.load_json(save_path)
	if loaded.is_empty() and (FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak")):
		push_error("[server] save file exists but cannot be read; refusing to start to protect data")
		return ERR_FILE_CORRUPT
	if loaded.is_empty():
		cs = CityState.new(seed_value)
		print("[server] new city, seed=%d" % seed_value)
	else:
		cs = CityState.from_dict(loaded)
		if cs == null:
			push_error("[server] save file is invalid; refusing to start to protect data")
			return ERR_FILE_CORRUPT
		print("[server] loaded city: %d accounts, %d buildings" % [cs.accounts.size(), cs.buildings.size()])
	for a in admins:
		cs.provision_admin(str(a[0]), str(a[1]))
	NpcSim.ensure_npcs(cs)
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
			var pos: Vector3 = p["pos"]
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
	NpcSim.step(cs, dt)
	_work_step(dt)
	var now := Time.get_ticks_msec()
	for pid in peers.keys():
		var p: Dictionary = peers[pid]
		if not p["auth"] and now - int(p["connected_at"]) > AUTH_TIMEOUT_MSEC:
			_kick(pid)
	_tick_acc += dt
	if _tick_acc >= TICK_INTERVAL:
		_tick_acc = 0.0
		_broadcast_tick()
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


func _work_step(dt: float) -> void:
	var positions: Dictionary = {}
	for pid in _auth_peers():
		var p: Dictionary = peers[pid]
		var pos: Vector3 = p["pos"]
		positions[p["name"]] = Vector2(pos.x, pos.z)
	var online: Dictionary = {}
	for pid in _auth_peers():
		online[peers[pid]["name"]] = int(peers[pid].get("inside", 0))
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
			"s2c_notice", "s2c_player_joined", "s2c_chat", "s2c_teleport":
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
		"s2c_notice", "s2c_player_joined", "s2c_chat", "s2c_teleport":
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
		var pos: Vector3 = p["pos"]
		out[p["name"]] = [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01),
			snappedf(float(p["yaw"]), 0.01), cs.role_of(p["name"]), int(p.get("inside", 0))]
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
		"pos": Vector3.ZERO, "yaw": 0.0, "failures": 0,
	}


func _on_peer_disconnected(pid: int) -> void:
	if not peers.has(pid):
		return
	var p: Dictionary = peers[pid]
	peers.erase(pid)
	if p["auth"] and by_name.get(p["name"], -1) == pid:
		by_name.erase(p["name"])
		var pos: Vector3 = p["pos"]
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
	}
	_send(pid, "s2c_login_result", true, "", info)
	_send(pid, "s2c_snapshot", cs.all_buildings_public(), NpcSim.public_list(cs), _players_public())
	for batch in cs.block_batches():
		_send(pid, "s2c_blocks", batch)
	_send(pid, "s2c_depleted", cs.depleted_flat())
	p["last_inv"] = cs.inv_public(player_name)
	_send(pid, "s2c_inv", p["last_inv"])
	_broadcast("s2c_player_joined", player_name, acc["role"], pid)
	_dirty = true
	print("[server] %s joined (%s)" % [player_name, acc["role"]])


# ---------------- اقدامات بازیکن ----------------

func on_move(pid: int, x: float, z: float, yaw: float) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if int(p.get("inside", 0)) > 0:
		return  # داخل ساختمان موقعیت بیرونی تغییر نمی‌کند
	if not (is_finite(x) and is_finite(z) and is_finite(yaw)):
		return
	var now := Time.get_ticks_msec()
	var dt: float = clampf(float(now - int(p["last_move"])) / 1000.0, 0.0, 0.5)
	p["last_move"] = now
	p["allow"] = minf(float(p["allow"]) + FWConst.PLAYER_SPEED * 1.3 * dt, 6.0)
	var cur: Vector3 = p["pos"]
	var d: float = Vector2(x, z).distance_to(Vector2(cur.x, cur.z))
	var lo: float = -FWConst.WORLD_LIMIT
	var hi: float = FWConst.CITY_SIZE + FWConst.WORLD_LIMIT
	var valid: bool = d <= float(p["allow"]) + 0.05 and x >= lo and x <= hi and z >= lo and z <= hi and cs.is_walkable(x, z, cur.y)
	if valid:
		p["allow"] = float(p["allow"]) - d
		p["pos"] = Vector3(x, cs.ground_height(x, z, cur.y), z)
		p["yaw"] = yaw
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
	if int(p.get("inside", 0)) > 0:
		_notice(pid, "already_inside")
		return
	var pos: Vector3 = p["pos"]
	var err: String = cs.enter_error(p["name"], id, Vector2(pos.x, pos.z))
	if err != "":
		_notice(pid, err)
		return
	p["inside"] = id
	_send(pid, "s2c_inside", id)


func on_leave(pid: int) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if int(p.get("inside", 0)) == 0:
		_notice(pid, "not_inside")
		return
	p["inside"] = 0
	_send(pid, "s2c_inside", 0)


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
	if int(p.get("inside", 0)) > 0:
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


func on_gather(pid: int, rx: int, rz: int, tool: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if int(p.get("inside", 0)) > 0:
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.gather(p["name"], rx, rz, tool, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]), {"tool": str(res.get("tool", ""))})
		return
	_broadcast("s2c_resource", PackedInt32Array([rx, rz, 0]))
	_push_inv(pid, p["name"])
	_notice(pid, "gathered", {"item": res["item"], "count": res["count"]})
	_dirty = true


func on_dig(pid: int, x: float, z: float, tool: String) -> void:
	var p := _player_of(pid)
	if p.is_empty():
		return
	if not _allow_action(p):
		_notice(pid, "rate_limited")
		return
	if int(p.get("inside", 0)) > 0 or not (is_finite(x) and is_finite(z)):
		return
	var pos: Vector3 = p["pos"]
	var res: Dictionary = cs.dig(p["name"], x, z, tool, Vector2(pos.x, pos.z))
	if not res["ok"]:
		_notice(pid, str(res["error"]), {"tool": str(res.get("tool", ""))})
		return
	_push_inv(pid, p["name"])
	_notice(pid, "gathered", {"item": res["item"], "count": res["count"]})
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
	_notice(pid, "crafted", {"item": res["item"], "count": res["count"]})
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
