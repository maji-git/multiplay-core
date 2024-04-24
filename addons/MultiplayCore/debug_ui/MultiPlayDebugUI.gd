extends Control

var mpc: MultiPlayCore
@export var connect_address: LineEdit
@export var payload_input: TextEdit
@export var cert_input: TextEdit
@export var boot_ui: Control
@export var status_ui: Control
@export var status_text: Label
var join_address = "ws://localhost:4200"

# Called when the node enters the scene tree for the first time.
func _ready():
	connect_address.text = join_address
	
	var fp = FileAccess.open("user://mp_debug_bootui", FileAccess.READ)
	if fp:
		var fp_data = JSON.parse_string(fp.get_as_text())
		fp.close()
		payload_input.text = fp_data.payload_input
		cert_input.text = fp_data.cert_input
	
	boot_ui.visible = true
	status_ui.visible = false

func save_debug_cache():
	var fp = FileAccess.open("user://mp_debug_bootui", FileAccess.WRITE)
	fp.store_string(JSON.stringify({
		payload_input = payload_input.text,
		cert_input = cert_input.text
	}))
	fp.close()

func _on_host_pressed():
	mpc.start_online_host(false, JSON.parse_string(payload_input.text), JSON.parse_string(cert_input.text))
	boot_close()

func _on_host_act_pressed():
	mpc.start_online_host(true, JSON.parse_string(payload_input.text), JSON.parse_string(cert_input.text))
	boot_close()

func _on_connect_pressed():
	mpc.start_online_join(join_address, JSON.parse_string(payload_input.text), JSON.parse_string(cert_input.text))
	boot_close()

func _on_connect_address_text_changed(new_text):
	join_address = new_text

func _process(delta):
	update_status_text()

func update_status_text():
	if !mpc:
		return
	var s_array = []
	
	if mpc.online_connected:
		s_array.append("Connected!")
	else:
		s_array.append("Disconnected")
	
	s_array.append("Running as Server at " + str(mpc.port))
	
	s_array.append("Player Count: " + str(mpc.player_count))
	
	status_text.text = "\n".join(s_array)

func _on_one_screen_pressed():
	mpc.start_one_screen()
	boot_close()


func _on_solo_pressed():
	mpc.start_solo()
	boot_close()


func _on_swap_pressed():
	mpc.start_swap()
	boot_close()

func boot_close():
	save_debug_cache()
	boot_ui.visible = false
	status_ui.visible = true

func _on_close_pressed():
	visible = false
