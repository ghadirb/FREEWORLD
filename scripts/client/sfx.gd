extends RefCounted
## جلوه‌های صوتی ساده که در کد تولید می‌شوند (بدون فایل صوتی).

static var _cache: Dictionary = {}
static var enabled: bool = true
const RATE := 22050


static func _tone(freq: float, secs: float, decay: float, noise: float = 0.0, square: bool = false) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var s := sin(TAU * freq * t)
		if square:
			s = 1.0 if s > 0.0 else -1.0
		s = s * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		out[i] = s * exp(-t * decay)
	return out


static func _make(kind: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match kind:
		"click":
			samples = _tone(1100.0, 0.05, 60.0)
		"coin":
			samples = _tone(988.0, 0.09, 18.0)
			samples.append_array(_tone(1319.0, 0.22, 10.0))
		"place":
			samples = _tone(110.0, 0.25, 12.0, 0.35)
		"error":
			samples = _tone(180.0, 0.16, 14.0, 0.0, true)
		"notify":
			samples = _tone(660.0, 0.1, 14.0)
			samples.append_array(_tone(880.0, 0.12, 14.0))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		bytes.encode_s16(i * 2, int(clampf(samples[i] * 0.5, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


static func play(owner: Node, kind: String) -> void:
	if not enabled or owner == null or not owner.is_inside_tree():
		return
	if not _cache.has(kind):
		_cache[kind] = _make(kind)
	var p := AudioStreamPlayer.new()
	p.stream = _cache[kind]
	p.volume_db = -6.0
	owner.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
