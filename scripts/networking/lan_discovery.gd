extends Node
## کشف بازی‌های شبکهٔ محلی (Wi‑Fi یا هات‌اسپات) بدون اینترنت و بدون سرور.
## میزبان هر ثانیه یک بستهٔ UDP پخش می‌کند؛ بازیکنان با شنیدن آن فهرست بازی‌ها را می‌بینند.

const FWConst = preload("res://scripts/core/const.gd")

const DISCOVERY_PORT := 7778
const BROADCAST_INTERVAL := 1.0
const ENTRY_TTL_MSEC := 4000
const MAGIC := "FREEWORLD"

signal games_changed

var games: Dictionary = {}  # ip -> {name, port, players, max, seen}

var _udp := PacketPeerUDP.new()
var _broadcasting: bool = false
var _listening: bool = false
var _acc: float = 0.0
var _info: Dictionary = {}


## آدرس‌های IPv4 خصوصی این دستگاه (برای نمایش به بازیکنان و پخش مستقیم).
static func local_ipv4() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		var s := str(a)
		if s.count(".") != 3:
			continue
		var p := s.split(".")
		var a0 := int(p[0])
		var a1 := int(p[1])
		var private_net: bool = a0 == 10 or (a0 == 192 and a1 == 168) or (a0 == 172 and a1 >= 16 and a1 <= 31)
		if private_net:
			out.append(s)
	return out


static func directed_broadcasts() -> Array:
	var out: Array = ["255.255.255.255"]
	for ip in local_ipv4():
		var p: PackedStringArray = str(ip).split(".")
		out.append("%s.%s.%s.255" % [p[0], p[1], p[2]])
	return out


func start_listening() -> bool:
	stop()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	var err := _udp.bind(DISCOVERY_PORT, "*")
	if err != OK:
		return false
	_listening = true
	return true


## info: {name, port, players, max}
func start_broadcasting(info: Dictionary) -> void:
	stop()
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_info = info
	_broadcasting = true
	_acc = BROADCAST_INTERVAL  # بلافاصله اولین بسته


func update_info(info: Dictionary) -> void:
	_info = info


func stop() -> void:
	if _udp != null:
		_udp.close()
	_broadcasting = false
	_listening = false
	games.clear()


func _process(delta: float) -> void:
	if _broadcasting:
		_acc += delta
		if _acc >= BROADCAST_INTERVAL:
			_acc = 0.0
			_broadcast()
	elif _listening:
		_poll()


func _broadcast() -> void:
	var payload := JSON.stringify({
		"g": MAGIC, "v": FWConst.PROTOCOL_VERSION, "port": int(_info.get("port", FWConst.DEFAULT_PORT)),
		"name": str(_info.get("name", "")), "players": int(_info.get("players", 0)),
		"max": int(_info.get("max", FWConst.MAX_PLAYERS)),
	}).to_utf8_buffer()
	for dest in directed_broadcasts():
		_udp.set_dest_address(str(dest), DISCOVERY_PORT)
		_udp.put_packet(payload)


func _poll() -> void:
	var changed := false
	while _udp.get_available_packet_count() > 0:
		var pkt := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		if ip == "" or pkt.size() > 512:
			continue
		var data: Variant = JSON.parse_string(pkt.get_string_from_utf8())
		if not (data is Dictionary) or data.get("g", "") != MAGIC:
			continue
		if int(data.get("v", -1)) != FWConst.PROTOCOL_VERSION:
			continue
		var port := int(data.get("port", 0))
		if port <= 0 or port > 65535:
			continue
		var entry := {
			"name": str(data.get("name", "")).substr(0, 24), "port": port,
			"players": int(data.get("players", 0)), "max": int(data.get("max", FWConst.MAX_PLAYERS)),
			"seen": Time.get_ticks_msec(),
		}
		if not games.has(ip) or games[ip]["name"] != entry["name"] or games[ip]["players"] != entry["players"] or games[ip]["port"] != port:
			changed = true
		games[ip] = entry
	var now := Time.get_ticks_msec()
	for ip in games.keys():
		if now - int(games[ip]["seen"]) > ENTRY_TTL_MSEC:
			games.erase(ip)
			changed = true
	if changed:
		games_changed.emit()
