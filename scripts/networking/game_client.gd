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
signal inside_changed(building_id: int)
signal furn_changed
signal energy_changed
signal job_changed
signal money_changed(money: int)
signal player_joined(player_name: String)
signal player_left(player_name: String)
signal notice(code: String, args: Dictionary)
signal chat_received(from_name: String, text: String)
signal role_changed(role: String)
signal audit_received(entries: Array)
signal terrain_changed(x0: float, z0: float, x1: float, z1: float)
signal teleported(pos: Vector2)
signal ticked
signal god_changed
signal fire_changed
signal minigame_changed
signal disaster_changed
signal race_changed
signal boat_changed
signal horse_changed
signal car_changed
signal inventory_changed
signal blueprints_changed
signal book_changed
signal arenas_changed
signal blueprint_loaded(id: int, data: PackedInt32Array)
signal offer_received(data: Dictionary)
signal block_changed(pos: Vector3i, type_id: int, color: int)
signal blocks_loaded
signal resource_changed(rx: int, rz: int, alive: bool)
signal mine_changed(mine_id: String)
signal mine_node_changed(idx: int, alive: bool)

var net: Node
var creative: bool = false  # حالت خلاقانهٔ جهان (از سرور)
var forest_growth: bool = false  # قانون جهان: رشد جنگل (از سرور)
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
var inside_id: int = 0
var furn: Array = []   # مبلمان خانهٔ فعلی: [{t,x,z,r}]
## معدن زیرزمینی: شناسهٔ معدنی که داخلش هستیم ("" = بیرون) و سنگ‌های برداشت‌شدهٔ آن (idx -> true).
var mine_id: String = ""
var mine_depleted: Dictionary = {}
var energy: int = 100
var time_speed: float = 1.0
var weather: String = "clear"
var egg_price: float = 6.0
var milk_price: float = 14.0
var flour_price: float = 16.0
var cheese_price: float = 34.0
var market_stock: Dictionary = {"wheat": 0, "flour": 0, "bread": 0, "egg": 0, "milk": 0, "cheese": 0}
var players: Dictionary = {}  # نام -> {pos: Vector3, yaw: float, role: String}
var npcs: Array = []
var spawn: Vector2 = Vector2.ZERO
## کیف و قیمت فروش مواد (سرور می‌فرستد).
var inv: Dictionary = {}
var friends: Dictionary = {}
var god_list: Array = []
var nfire: Dictionary = {}  # "rx,rz" درخت‌های طبیعیِ در حال سوختن
var minigame: Dictionary = {"active": false, "t": 0.0, "score": 0, "coins": [], "best": 0, "board": []}
var disaster: Dictionary = {"kind": "", "t": 0.0}
var disaster_stamp: float = 0.0
var race: Dictionary = {"active": false, "t": 0.0, "next": 0, "pts": [], "best": 0, "board": []}
var race_stamp: float = 0.0
var mounted: bool = false   # سوار اسب (از سرور)
var _train_clock: float = 0.0
var _train_clock_msec: int = -1
var driving: bool = false   # پشت‌فرمان ماشین (از سرور)
var boating: bool = false   # سوار قایق (از سرور)
var minigame_stamp: float = 0.0   # لحظهٔ دریافت وضعیت؛ برای شمارش معکوس محلی
var sell_prices: Dictionary = {}
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

func send_move(x: float, z: float, yaw: float, alt: float = 0.0) -> void:
	if is_logged_in:
		_tx("c2s_move", [x, z, yaw, alt])


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


# ---------------- ساخت بلوکی و منابع ----------------

func place_block(v: Vector3i, type: String, color: int) -> void:
	if is_logged_in:
		_tx("c2s_place_block", [randi() % 2147483646 + 1, v.x, v.y, v.z, type, color])


func remove_block(v: Vector3i) -> void:
	if is_logged_in:
		_tx("c2s_remove_block", [v.x, v.y, v.z])


func paint_block(v: Vector3i, color: int) -> void:
	if is_logged_in:
		_tx("c2s_paint_block", [v.x, v.y, v.z, color])


## ابزارهای دسته‌ای: op = "fill" | "walls" | "clear"
func build_region(op: String, a: Vector3i, b: Vector3i, type: String, color: int) -> void:
	if is_logged_in:
		_tx("c2s_build_region", [op, a.x, a.y, a.z, b.x, b.y, b.z, type, color])


## کپی: بلوک‌های جعبهٔ a..b را نسبت به گوشهٔ کم‌مختصات برمی‌گرداند (۵ عدد برای هر بلوک).
func copy_region(a: Vector3i, b: Vector3i) -> PackedInt32Array:
	var out := PackedInt32Array()
	if mirror == null:
		return out
	var cells: Array = CityState.region_cells(a, b)
	var lo := Vector3i(mini(a.x, b.x), mini(a.y, b.y), mini(a.z, b.z))
	for v in cells:
		if mirror.blocks.has(v):
			var e: Array = mirror.blocks[v]
			var tid: int = FWConst.BLOCK_ORDER.find(str(e[0]))
			if tid >= 0:
				out.append_array(PackedInt32Array([v.x - lo.x, v.y - lo.y, v.z - lo.z, tid, int(e[1])]))
	return out


func paste_blocks(origin: Vector3i, data: PackedInt32Array) -> void:
	if is_logged_in and data.size() > 0:
		_tx("c2s_paste", [origin.x, origin.y, origin.z, data])


## میدان‌های ساخته‌شده توسط بازیکن (پروتکل ۳۱)
var arenas: Array = []   # {id, name, owner, x, z, r, coins, time, reward, top: [نام, امتیاز]}


func arena_create(arena_name: String, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0, obstacles: int = 0) -> void:
	if is_logged_in:
		_tx("c2s_arena_create", [arena_name, radius, coins, time, reward, kind, win_pct, obstacles])


func arena_edit(id: int, arena_name: String, radius: float, coins: int, time: float, reward: int, kind: String = "coins", win_pct: int = 0, obstacles: int = 0) -> void:
	if is_logged_in:
		_tx("c2s_arena_edit", [id, arena_name, radius, coins, time, reward, kind, win_pct, obstacles])


func arena_import(code: String) -> void:
	if is_logged_in:
		_tx("c2s_arena_import", [code])


func arena_op(op: String, id: int = 0) -> void:
	if is_logged_in:
		_tx("c2s_arena_op", [op, id])


func on_arenas(list: Array) -> void:
	arenas = list
	arenas_changed.emit()


## کتابخانهٔ سازه‌ها
var blueprints: Array = []   # خلاصه‌ها: {id, name, author, shared, n, size}
## کتاب ماجراجویی: rows = [[id, روز بازشدن (۰ = باز نشده), جایزه, نقش راوی]]، done، total و roles (شناسهٔ NPC ← نقش)
var book: Dictionary = {"rows": [], "done": 0, "total": 0, "roles": {}, "quests": {}}


func bp_save(bp_name: String, data: PackedInt32Array, shared: bool) -> void:
	if is_logged_in and data.size() > 0:
		_tx("c2s_bp_save", [bp_name, data, shared])


func bp_op(op: String, id: int = 0) -> void:
	if is_logged_in:
		_tx("c2s_bp_op", [op, id])


func request_book() -> void:
	if is_logged_in:
		_tx("c2s_book", [])


func on_book(state: Dictionary) -> void:
	book = state
	book_changed.emit()


## نقش یک NPC (villager اگر نامشخص).
func npc_role(npc_id: int) -> String:
	return str(book.get("roles", {}).get(str(npc_id), "villager"))


func on_bp_list(list: Array) -> void:
	blueprints = list
	blueprints_changed.emit()


func on_bp_data(id: int, data: PackedInt32Array) -> void:
	blueprint_loaded.emit(id, data)


func undo_build() -> void:
	if is_logged_in:
		_tx("c2s_undo", [])


func gather(rx: int, rz: int, tool: String) -> void:
	if is_logged_in:
		_tx("c2s_gather", [rx, rz, tool])


func dig(x: float, z: float) -> void:
	if is_logged_in:
		_tx("c2s_dig", [x, z, "shovel"])


func fill(x: float, z: float) -> void:
	if is_logged_in:
		_tx("c2s_fill", [x, z, "shovel"])


func on_terrain(flat: PackedInt32Array) -> void:
	if mirror == null:
		return
	mirror.world.edits.clear()
	_apply_terrain(flat)


func on_terrain_edit(flat: PackedInt32Array) -> void:
	if mirror == null:
		return
	_apply_terrain(flat)


func _apply_terrain(flat: PackedInt32Array) -> void:
	if flat.size() < 3:
		return
	var st := FWConst.TERRAIN_EDIT_STEP
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var i := 0
	while i + 2 < flat.size():
		mirror.world.set_edit(flat[i], flat[i + 1], flat[i + 2])
		lo = Vector2(minf(lo.x, float(flat[i]) * st), minf(lo.y, float(flat[i + 1]) * st))
		hi = Vector2(maxf(hi.x, float(flat[i]) * st), maxf(hi.y, float(flat[i + 1]) * st))
		i += 3
	terrain_changed.emit(lo.x - st, lo.y - st, hi.x + st, hi.y + st)


func craft(recipe: String, times: int = 1) -> void:
	if is_logged_in:
		_tx("c2s_craft", [recipe, times])


func god(action: String, kind: String, x: float, z: float) -> void:
	if is_logged_in:
		_tx("c2s_god", [action, kind, x, z])


func on_fire(flat: PackedInt32Array) -> void:
	nfire.clear()
	var i := 0
	while i + 1 < flat.size():
		nfire["%d,%d" % [flat[i], flat[i + 1]]] = true
		i += 2
	fire_changed.emit()


func on_god(list: Array) -> void:
	god_list = list
	god_changed.emit()


func on_minigame(data: Dictionary) -> void:
	minigame = data
	minigame_stamp = Time.get_ticks_msec() / 1000.0
	minigame_changed.emit()


func on_disaster(data: Dictionary) -> void:
	disaster = data
	disaster_stamp = Time.get_ticks_msec() / 1000.0
	disaster_changed.emit()


func start_disaster(kind: String) -> void:
	if is_logged_in:
		_tx("c2s_disaster", [kind])


func disaster_kind() -> String:
	return str(disaster.get("kind", ""))


func on_race(data: Dictionary) -> void:
	race = data
	race_stamp = Time.get_ticks_msec() / 1000.0
	race_changed.emit()


func on_boat(on: bool) -> void:
	boating = on
	boat_changed.emit()


func on_horse(on: bool) -> void:
	mounted = on
	horse_changed.emit()


func toggle_horse() -> void:
	if is_logged_in:
		_tx("c2s_horse", [])


## ساعت قطار از سرور؛ بین دو پیام با ساعت محلی جلو می‌رود تا حرکت روان بماند.
func on_trains(clock: float) -> void:
	_train_clock = clock
	_train_clock_msec = Time.get_ticks_msec()


func train_clock_now() -> float:
	if _train_clock_msec < 0:
		return 0.0
	return _train_clock + float(Time.get_ticks_msec() - _train_clock_msec) / 1000.0


func on_car(on: bool) -> void:
	driving = on
	car_changed.emit()


func toggle_car() -> void:
	if is_logged_in:
		_tx("c2s_car", [])


func fish() -> void:
	if is_logged_in:
		_tx("c2s_fish", [])


func toggle_boat() -> void:
	if is_logged_in:
		_tx("c2s_boat", [])


func race_start() -> void:
	if is_logged_in:
		_tx("c2s_race_start", [])


func group_race() -> void:
	if is_logged_in:
		_tx("c2s_grace", [])


func race_active() -> bool:
	return bool(race.get("active", false))


## زمان سپری‌شدهٔ مسابقه (ثانیه)، شمارش محلی از آخرین وضعیت سرور.
func race_elapsed() -> float:
	if not race_active():
		return 0.0
	var left: float = maxf(0.0, float(race.get("t", 0.0)) - (Time.get_ticks_msec() / 1000.0 - race_stamp))
	return float(race.get("total", FWConst.RACE_TIME)) - left


func minigame_start() -> void:
	if is_logged_in:
		_tx("c2s_minigame_start", [])


## ثانیه‌های باقی‌ماندهٔ دور (شمارش معکوس محلی از آخرین وضعیت سرور؛ سرور تعیین‌کنندهٔ پایان است).
func minigame_time_left() -> float:
	if not bool(minigame.get("active", false)):
		return 0.0
	return maxf(0.0, float(minigame.get("t", 0.0)) - (Time.get_ticks_msec() / 1000.0 - minigame_stamp))


func npc_interact(npc_id: int, item: String = "") -> void:
	if is_logged_in:
		_tx("c2s_npc", [npc_id, item])


func quest_turn_in(npc_id: int) -> void:
	if is_logged_in:
		_tx("c2s_quest", [npc_id])


## تعداد مرحله‌های تمام‌شدهٔ مأموریت این نقش.
func quest_done(role: String) -> int:
	return int(book.get("quests", {}).get(role, 0))


func npc_sell(npc_id: int, item: String, n: int) -> void:
	if is_logged_in:
		_tx("c2s_npc_sell", [npc_id, item, n])


func npc_buy(npc_id: int, item: String, n: int) -> void:
	if is_logged_in:
		_tx("c2s_npc_buy", [npc_id, item, n])


func furn_place(type: String, x: float, z: float, rot: int) -> void:
	if is_logged_in:
		_tx("c2s_furn_place", [type, x, z, rot])


func furn_remove(idx: int) -> void:
	if is_logged_in:
		_tx("c2s_furn_remove", [idx])


func on_furn(data: Dictionary) -> void:
	if int(data.get("id", 0)) != inside_id:
		return
	furn = data.get("items", [])
	furn_changed.emit()


func trade(item: String, n: int, buy: bool) -> void:
	if is_logged_in:
		_tx("c2s_trade", [item, n, buy])


func offer(to_name: String, item: String, n: int, price: int) -> void:
	if is_logged_in:
		_tx("c2s_offer", [to_name, item, n, price])


func answer_offer(id: int, accept: bool) -> void:
	if is_logged_in:
		_tx("c2s_offer_answer", [id, accept])


func on_offer(data: Dictionary) -> void:
	offer_received.emit(data)


func item_count(item: String) -> int:
	return int(inv.get(item, 0))


## خطای پیش‌نمایش برای قرار دادن بلوک (خالی = مجاز). تصمیم نهایی با سرور است.
func block_preview_error(v: Vector3i, type: String) -> String:
	if mirror == null:
		return "not_ready"
	var err: String = mirror.check_block(role, v.x, v.y, v.z, type)
	if err != "":
		return err
	if not mirror.has_items(inv, FWConst.BLOCK_TYPES[type]["cost"]):
		return "no_items"
	return ""


func on_inv(data: Dictionary) -> void:
	inv = data.get("inv", {})
	sell_prices = data.get("sell", {})
	friends = data.get("friends", {})
	inventory_changed.emit()


func on_block(data: PackedInt32Array) -> void:
	if data.size() < 5 or mirror == null:
		return
	mirror.apply_block(data[0], data[1], data[2], data[3], data[4])
	block_changed.emit(Vector3i(data[0], data[1], data[2]), data[3], data[4])


func on_blocks(batch: PackedInt32Array) -> void:
	if mirror == null:
		return
	var i := 0
	while i + 4 < batch.size():
		mirror.apply_block(batch[i], batch[i + 1], batch[i + 2], batch[i + 3], batch[i + 4])
		i += 5
	blocks_loaded.emit()


func on_depleted(flat: PackedInt32Array) -> void:
	if mirror == null:
		return
	mirror.depleted.clear()
	var i := 0
	while i + 1 < flat.size():
		mirror.depleted["%d,%d" % [flat[i], flat[i + 1]]] = 1.0
		resource_changed.emit(flat[i], flat[i + 1], false)
		i += 2


func on_resource(data: PackedInt32Array) -> void:
	if data.size() < 3 or mirror == null:
		return
	var key := "%d,%d" % [data[0], data[1]]
	if data[2] == 1:
		mirror.depleted.erase(key)
	else:
		mirror.depleted[key] = 1.0
	resource_changed.emit(data[0], data[1], data[2] == 1)


## خطای پیش‌نمایش محلی برای ساخت (رشتهٔ خالی = مجاز). تصمیم نهایی با سرور است.
func preview_error(type: String, cx: int, cz: int) -> String:
	if mirror == null:
		return "not_ready"
	var err: String = Placement.check(mirror.world, mirror.occupied, type, cx, cz, role)
	if err != "":
		return err
	if mirror.blocks_in_footprint(type, cx, cz):
		return "blocks_in_way"
	if not creative and money < int(FWConst.BUILDING_TYPES[type]["cost"]):
		return "no_money"
	return ""


# ---------------- پاسخ‌های سرور ----------------

func on_login_result(ok: bool, error: String, info: Dictionary) -> void:
	boating = false
	mounted = false
	driving = false
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
	mirror.set_climate(str(info.get("climate", "temperate")))
	mirror.track_nav = false
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
		entry["inside"] = int(a[5]) if a.size() > 5 else 0
		entry["mine"] = str(a[6]) if a.size() > 6 else ""
		entry["alt"] = float(a[7]) if a.size() > 7 else 0.0
		entry["boat"] = int(a[8]) == 1 if a.size() > 8 else false
		entry["horse"] = int(a[9]) == 1 if a.size() > 9 else false
		entry["car"] = int(a[10]) == 1 if a.size() > 10 else false
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
	flour_price = float(mk.get("flour_price", flour_price))
	cheese_price = float(mk.get("cheese_price", cheese_price))
	market_stock = {"wheat": int(mk.get("wheat", 0)), "flour": int(mk.get("flour", 0)), "bread": int(mk.get("bread", 0)),
		"egg": int(mk.get("egg", 0)), "milk": int(mk.get("milk", 0)), "cheese": int(mk.get("cheese", 0))}


func _apply_world(w: Dictionary) -> void:
	creative = bool(w.get("creative", creative))
	forest_growth = bool(w.get("forest_growth", forest_growth))
	time_speed = float(w.get("time_speed", time_speed))
	weather = str(w.get("weather", weather))


func on_world(w: Dictionary) -> void:
	_apply_world(w)
	world_changed.emit()


func enter_mine(id: String) -> void:
	if is_logged_in:
		_tx("c2s_mine_enter", [id])


func leave_mine() -> void:
	if is_logged_in:
		_tx("c2s_mine_leave", [])


func mine_gather(idx: int) -> void:
	if is_logged_in:
		_tx("c2s_mine_gather", [idx])


func on_mine(id: String, depleted: PackedInt32Array) -> void:
	mine_id = id
	mine_depleted.clear()
	for i in depleted:
		mine_depleted[int(i)] = true
	mine_changed.emit(id)


func on_mine_node(idx: int, alive: bool) -> void:
	if alive:
		mine_depleted.erase(idx)
	else:
		mine_depleted[idx] = true
	mine_node_changed.emit(idx, alive)


func enter_building(id: int) -> void:
	if is_logged_in:
		_tx("c2s_enter", [id])


func leave_building() -> void:
	if is_logged_in:
		_tx("c2s_leave", [])


func on_inside(id: int) -> void:
	inside_id = id
	if id == 0:
		furn = []
	inside_changed.emit(id)


func on_energy(v: int) -> void:
	energy = v
	energy_changed.emit()


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
