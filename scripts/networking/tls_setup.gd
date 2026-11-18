extends RefCounted
## رمزنگاری ترافیک شبکه (DTLS روی ENet) با پین‌کردن گواهی در اولین اتصال (TOFU).
## - سرور یک گواهی خودامضا می‌سازد و نگه می‌دارد.
## - Godot 4.3 در DTLS اجازهٔ «بدون تأیید» نمی‌دهد (client_unsafe کار نمی‌کند)، پس کلاینت باید گواهی را بشناسد.
##   کلاینت پیش از اتصال، گواهی را از پورت (port+1، UDP) می‌گیرد و اثرانگشتش را ذخیره می‌کند.
##   در اتصال‌های بعدی فقط همان گواهی پذیرفته می‌شود؛ اگر عوض شده باشد اتصال رد می‌شود.
## - محدودیت: اگر مهاجم دقیقاً در «اولین» اتصال وسط راه باشد، نمی‌توان تشخیص داد.
## - درخواست گواهی باید حداقل CERT_REQUEST_MIN بایت باشد تا سرور ابزار تقویت حملهٔ DDoS نشود.

const CERT_PORT_OFFSET := 1
const CERT_REQUEST_MIN := 1200
const CERT_MAGIC := "FWCERT1"
const CERT_CN := "freeworld"

const KEY_FILE := "tls_server.key"
const CERT_FILE := "tls_server.crt"
const CERT_DAYS := 3650


## کلید و گواهی را می‌خواند؛ اگر نبود یا خراب بود می‌سازد. خروجی: {key, cert} یا {} در شکست.
static func load_or_create(data_dir: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(data_dir)
	var key_path := data_dir.path_join(KEY_FILE)
	var cert_path := data_dir.path_join(CERT_FILE)
	var key := CryptoKey.new()
	var cert := X509Certificate.new()
	if FileAccess.file_exists(key_path) and FileAccess.file_exists(cert_path):
		if key.load(key_path) == OK and cert.load(cert_path) == OK:
			return {"key": key, "cert": cert}
	var crypto := Crypto.new()
	key = crypto.generate_rsa(2048)
	if key == null:
		return {}
	var now := int(Time.get_unix_time_from_system())
	var not_before := Time.get_datetime_string_from_unix_time(now - 86400).replace("-", "").replace("T", "").replace(":", "")
	var not_after := Time.get_datetime_string_from_unix_time(now + CERT_DAYS * 86400).replace("-", "").replace("T", "").replace(":", "")
	cert = crypto.generate_self_signed_certificate(key, "CN=%s,O=FREEWORLD" % CERT_CN, not_before, not_after)
	if cert == null:
		return {}
	if key.save(key_path) != OK or cert.save(cert_path) != OK:
		push_warning("TLS: cannot store the certificate; using an in-memory one for this run")
	return {"key": key, "cert": cert}


static func server_options(kc: Dictionary) -> TLSOptions:
	if kc.is_empty():
		return null
	return TLSOptions.server(kc["key"], kc["cert"])


static func cert_pem(kc: Dictionary) -> String:
	return "" if kc.is_empty() else kc["cert"].save_to_string()


static func fingerprint(pem: String) -> String:
	return pem.sha256_text()


## گواهی دریافتی را به گزینه‌های TLS کلاینت تبدیل می‌کند (null اگر PEM نامعتبر باشد).
static func client_options_for(pem: String) -> TLSOptions:
	var cert := X509Certificate.new()
	if cert.load_from_string(pem) != OK:
		return null
	return TLSOptions.client(cert, CERT_CN)


static func build_cert_request() -> PackedByteArray:
	var b := CERT_MAGIC.to_utf8_buffer()
	b.resize(CERT_REQUEST_MIN)
	return b


static func is_cert_request(pkt: PackedByteArray) -> bool:
	return pkt.size() >= CERT_REQUEST_MIN and pkt.slice(0, CERT_MAGIC.length()).get_string_from_utf8() == CERT_MAGIC
