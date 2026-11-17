extends Node
## نقطهٔ ورود: با --server سرور اختصاصی اجرا می‌شود، در غیر این صورت بازی کلاینت.

const ServerMain = preload("res://scripts/server/server_main.gd")


func _ready() -> void:
	# ریشهٔ درخت هنگام _ready مشغول است؛ راه‌اندازی به فریم بعد می‌رود.
	_boot.call_deferred()


func _boot() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var cfg: Dictionary = ServerMain.parse_args(args)
		if ServerMain.launch(self, cfg) == null:
			get_tree().quit(2)
		return
	var ui_script = load("res://scripts/client/client_app.gd")
	var app := Node.new()
	app.set_script(ui_script)
	app.name = "ClientApp"
	add_child(app)
