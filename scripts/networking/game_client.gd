extends Node
## منطق شبکهٔ کلاینت بدون وابستگی به رابط کاربری.
## هم صحنهٔ بازی و هم بات‌های تست از همین کلاس استفاده می‌کنند.

const FWConst = preload("res://scripts/core/const.gd")
const CityState = preload("res://scripts/server/city_state.gd")
const Placement = preload("res://scripts/shared/placement.gd")
const TlsSetup = preload("res://scripts/networking/tls_setup.gd")
const Settings = preload("res://scripts/client/settings.gd")

signal connection_failed
signal logged_in
signal login_failed(error: String)
signal disconnected
signal snapshot_received
signal building_added(b: Dictionary)
signal building_removed(id: int)
signal stocks_changed
signal market_changed
signal world_changed
signal job_changed
signal money_changed(money: int)
signal player_joined(player_name: String)
signal player_left(player_name: String)
signal notice(code: String, args: Dictionary)
signal chat_received(from_name: String, text: String)
signal role_changed(role: String)
signal audit_received(entries: Array)
signal teleported(pos: Vector2)
signal ticked

var net: Node
var local_server = null  # وقتی تک‌نفره/میزبان است، سرور همین پردازه
var mirror = null  # نسخهٔ محلی CityState برای پیش‌نمایش و پیش‌بینی حرکت
var my_name: String = ""
var token: String = ""
var role: String = FWConst.ROLE_PLAYER
var money: int = 0
var world_time: float = 0.0
var wheat_price: float = FWConst.WHEAT_BASE_PRICE
var bread_price: float = FWConst.BREAD_BASE_PRICE
var job_id: int = 0
var time_speed: float = 1.0
var weather: String = "clear"
var egg_price: float = 6.0
var milk_price: float = 14.0
var market_stock: Dictionary = {"wheat": 0, "bread": 0, "egg": 0, "milk": 0}
var players: Dictionary = {}  # نام -> {pos: Vector3, yaw: float, role: String}
var npcs: Array = []
var spawn: Vector2 = Vector2.ZERO
var is_logged_in: bool = false
var last_tick_msec: int = 0

var _pending_name: String = ""
var _pending_token: String = ""
var _connecting: bool = false
var _cert_sock: PacketPeerUDP = null  # دریافت گواهی سرور پیش از اتصال رمزشده
var _cert_host: String = ""
var _cert_port: int = 0
var _cert_wait: float = 0.0
var _cert_tries: int = 0


func setup(net_node: Node) -> void:
	net = net_node
	net.client = self


func connect_to(host: String, port: int, player_name: String, player_token: String) -> int:
	_pending_name = player_name
	_pending_token = player_token
	if not FWConst.USE_DTLS:
		return _open_enet(host, port, null)
	# مرحلهٔ ۱: گرفتن گواهی سرور (UDP، port+1)؛ مرحلهٔ ۲ در _on_cert_received.
	_cert_sock = PacketPeerUDP.new()
	if _cert_sock.set_dest_address(host, port + TlsSetup.CERT_PORT_OFFSET) != OK:
		_cert_sock = null
		return ERR_CANT_RESOLVE
	_cert_host = host
	_cert_port = port
	_cert_wait = 99.0  # بلافاصله بفرست
	_cert_tries = 0
	_connecting = true
	return OK


func _open_enet(host: String, port: int, tls: TLSOptions) -> int:
	if not is_inside_tree():
		return ERR_UNCONFIGURED
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(host, port)
	if err != OK:
		return err
	if tls != null and peer.host.dtls_client_setup(TlsSetup.CERT_CN, tls) != OK:
		return ERR_CANT_CONNECT
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	_connecting = true
	return OK


func _process(delta: float) -> void:
	if _cert_sock == null:
		return
	if _cert_sock.get_available_packet_count() > 0:
		var pem: String = _cert_sock.get_packet().get_string_from_utf8()
		_cert_sock.close()
		_cert_sock = null
		_on_cert_received(pem)
		return
	_cert_wait += delta
	if _cert_wait >= 1.0:
		if _cert_tries >= 4:
			_cert_sock.close()
			_cert_sock = null
			_connecting = false
			connection_failed.emit()
			return
		_cert_sock.put_packet(TlsSetup.build_cert_request())
		_cert_tries += 1
		_cert_wait = 0.0


## اولین بار اثرانگشت ذخیره می‌شود؛ بعد از آن فقط همان گواهی پذیرفته می‌شود.
func _on_cert_received(pem: String) -> void:
	var fp := TlsSetup.fingerprint(pem)
	var pinned := Settings.pin_for(_cert_host, _cert_port)
	if pinned != "" and pinned != fp:
		_connecting = false
		login_failed.emit("cert_changed")
		return
	var tls: TLSOptions = TlsSetup.client_options_for(pem)
	if tls == null:
		_connecting = false
		connection_failed.emit()
		return
	if pinned == "":
		Settings.save_pin(_cert_host, _cert_port, fp)
	if _open_enet(_cert_host, _cert_port, tls) != OK:
		_connecting = false
		connection_failed.emit()


## اتصال مستقیم به سرور داخل همین برنامه (بدون شبکه).
func connect_local(server_node: Node, player_name: String, player_token: String) -> void:
	_pending_name = player_name
	_pending_token = player_token
	local_server = server_node
	local_server.attach_local(self)
	_tx("c2s_login", [player_name, player_token, FWConst.PROTOCOL_VERSION])


func _tx(method: String, args: Array) -> void:
	if local_server != null:
		local_server.local_call(method, args.duplicate(true))
	else:
		net.callv("rpc_id", [1, method] + args)


func disconnect_from_server() -> void:
	if _cert_sock != null:
		_cert_sock.close()
		_cert_sock = null
	if local_server != null:
		local_server.detach_local()
		local_server = null
		is_logged_in = false
		return
	if is_inside_tree() and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_logged_in = false


func _on_connected() -> void:
	_connecting = false
	_tx("c2s_login", [_pending_name, _pending_token, FWConst.PROTOCOL_VERSION])


func _on_connection_failed() -> void:
	_connecting = false
	connection_failed.emit()


func _on_server_disconnected() -> void:
	is_logged_in = false
	disconnected.emit()


# ---------------- درخواست‌ها ----------------

func send_move(x: float, z: float, yaw: float) -> void:
	if is_logged_in:
		_tx("c2s_move", [x, z, yaw])


func place(type: String, cx: int, cz: int) -> void:
	if is_logged_in:
		_tx("c2s_place", [randi() % 2147483646 + 1, type, cx, cz])


func remove(id: int) -> void:
	if is_logged_in:
		_tx("c2s_remove", [id])


func set_job(building_id: int) -> void:
	if is_logged_in:
		_tx("c2s_job", [building_id])


func on_job(building_id: int) -> void:
	job_id = building_id
	job_changed.emit()


func collect(id: int) -> void:
	if is_logged_in:
		_tx("c2s_collect", [id])


func send_chat(text: String) -> void:
	if is_logged_in:
		_tx("c2s_chat", [text])


func set_role(target: String, new_role: String) -> void:
	if is_logged_in:
		_tx("c2s_set_role", [target, new_role])


func request_audit() -> void:
	if is_logged_in:
		_tx("c2s_get_audit", [])


## خطای پیش‌نمایش محلی برای ساخت (رشتهٔ خالی = مجاز). تصمیم نهایی با سرور است.
func preview_error(type: String, cx: int, cz: int) -> String:
	if mirror == null:
		return "not_ready"
	var err: String = Placement.check(mirror.world, mirror.occupied, type, cx, cz, role)
	if err != "":
		return err
	if money < int(FWConst.BUILDING_TYPES[type]["cost"]):
		return "no_money"
	return ""


# ---------------- پاسخ‌های سرور ----------------

func on_login_result(ok: bool, error: String, info: Dictionary) -> void:
	if not ok:
		login_failed.emit(error)
		return
	my_name = info["name"]
	if str(info["token"]) != "":
		token = str(info["token"])
	else:
		token = _pending_token
	role = info["role"]
	money = int(info["money"])
	world_time = float(info["time"])
	wheat_price = float(info["price"])
	_apply_market(info.get("market", {}))
	_apply_world(info.get("world", {}))
	job_id = int(info.get("job", 0))
	spawn = Vector2(info["pos"][0], info["pos"][1])
	mirror = CityState.new(int(info["seed"]), str(info["city_id"]))
	is_logged_in = true
	logged_in.emit()


func on_snapshot(buildings: Array, npc_list: Array, player_dict: Dictionary) -> void:
	for b in buildings:
		mirror.apply_add(b)
	npcs = npc_list
	players.clear()
	_apply_players(player_dict)
	snapshot_received.emit()


func _apply_players(player_dict: Dictionary) -> void:
	for n in player_dict:
		var a: Array = player_dict[n]
		var entry: Dictionary = players.get(n, {})
		entry["pos"] = Vector3(a[0], a[1], a[2])
		entry["yaw"] = float(a[3])
		entry["role"] = str(a[4])
		players[n] = entry
	for n in players.keys():
		if not player_dict.has(n):
			players.erase(n)


func on_building_added(b: Dictionary) -> void:
	mirror.apply_add(b)
	building_added.emit(b)


func on_building_removed(id: int) -> void:
	mirror.apply_remove(id)
	building_removed.emit(id)


func _apply_market(mk: Dictionary) -> void:
	if mk.is_empty():
		return
	wheat_price = float(mk.get("wheat_price", wheat_price))
	bread_price = float(mk.get("bread_price", bread_price))
	egg_price = float(mk.get("egg_price", egg_price))
	milk_price = float(mk.get("milk_price", milk_price))
	market_stock = {"wheat": int(mk.get("wheat", 0)), "bread": int(mk.get("bread", 0)),
		"egg": int(mk.get("egg", 0)), "milk": int(mk.get("milk", 0))}


func _apply_world(w: Dictionary) -> void:
	time_speed = float(w.get("time_speed", time_speed))
	weather = str(w.get("weather", weather))


func on_world(w: Dictionary) -> void:
	_apply_world(w)
	world_changed.emit()


func set_world(key: String, value: Variant) -> void:
	if is_logged_in:
		_tx("c2s_set_world", [key, value])


func on_market(mk: Dictionary) -> void:
	_apply_market(mk)
	market_changed.emit()


func on_stocks(stocks: Dictionary) -> void:
	for id in stocks:
		if mirror.buildings.has(int(id)):
			mirror.buildings[int(id)]["stock"] = float(stocks[id])
	stocks_changed.emit()


func on_money(m: int) -> void:
	money = m
	money_changed.emit(m)


func on_player_joined(player_name: String, new_role: String) -> void:
	player_joined.emit(player_name)


func on_player_left(player_name: String) -> void:
	players.erase(player_name)
	player_left.emit(player_name)


func on_notice(code: String, args: Dictionary) -> void:
	notice.emit(code, args)


func on_chat(from_name: String, text: String) -> void:
	chat_received.emit(from_name, text)


func on_role(new_role: String) -> void:
	role = new_role
	role_changed.emit(new_role)


func on_audit(entries: Array) -> void:
	audit_received.emit(entries)


func on_teleport(x: float, z: float) -> void:
	teleported.emit(Vector2(x, z))


func on_tick(t: float, price: float, player_dict: Dictionary, npc_list: Array) -> void:
	world_time = t
	wheat_price = price
	npcs = npc_list
	last_tick_msec = Time.get_ticks_msec()
	_apply_players(player_dict)
	ticked.emit()
