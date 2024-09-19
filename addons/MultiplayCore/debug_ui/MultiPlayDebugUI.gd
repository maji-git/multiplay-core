extends Control

var mpc: MultiPlayCore
@export var connect_address: LineEdit
@export var payload_input: TextEdit
@export var cert_input: TextEdit
@export var boot_ui: Control
@export var status_ui: Control
@export var status_text: Label
var join_address = "ws://localhost:4200"

# Used to make frequent data update slower
var delta_step = 0

# delta max in frames
const DELTA_STEP_MAX = 100

# String array line count
const STRING_ARRAY_SLOT = 6

var s_array = []

var worst_ping = 0

func _ready():
	s_array.resize(STRING_ARRAY_SLOT + 1)
	s_array.fill("")
	connect_address.text = join_address
	
	var fp = FileAccess.open("user://mp_debug_bootui", FileAccess.READ)
	if fp:
		var fp_data = JSON.parse_string(fp.get_as_text())
		fp.close()
		payload_input.text = get_or_empty(fp_data, "payload_input")
		cert_input.text = get_or_empty(fp_data, "cert_input")
	
	boot_ui.visible = true
	status_ui.visible = false
	
	mpc.connected_to_server.connect(mpc_started_entry)

func get_or_empty(data: Dictionary, field: String):
	if data.keys().has(field):
		return data[field]
	return ""

func save_debug_cache():
	var fp = FileAccess.open("user://mp_debug_bootui", FileAccess.WRITE)
	fp.store_string(JSON.stringify({
		payload_input = payload_input.text,
		cert_input = cert_input.text
	}))
	fp.close()

func parse_json_or_none(data):
	var d = JSON.parse_string(data)
	
	if d:
		return d
	
	if data != "":
		print("Got Invalid JSON data, join data ignored")
	
	return {}

func _on_host_pressed():
	mpc.start_online_host(false, parse_json_or_none(payload_input.text), parse_json_or_none(cert_input.text))
	boot_close()

func _on_host_act_pressed():
	mpc.start_online_host(true, parse_json_or_none(payload_input.text), parse_json_or_none(cert_input.text))
	boot_close()

func _on_connect_pressed():
	mpc.start_online_join(join_address, parse_json_or_none(payload_input.text), parse_json_or_none(cert_input.text))
	boot_close()

func _on_connect_address_text_changed(new_text):
	join_address = new_text

func _process(delta):
	update_status_text()

func update_status_text():
	if !mpc:
		return
	
	s_array[0] = mpc.debug_status_txt
	
	if mpc.is_server:
		s_array[1] = "Running as Server at " + str(mpc.port)
	else:
		s_array[1] = "Running as client"
	
	s_array[2] = "Player Count: " + str(mpc.player_count)
	
	delta_step = delta_step + 1
	
	# Update frequent data on delta step max
	if delta_step >= DELTA_STEP_MAX:
		delta_step = 0
		
		# Update ping count
		if is_instance_valid(mpc.local_player) and !mpc.is_server:
			var ping_ms = mpc.local_player.ping_ms
			s_array[3] = "Ping: " + str(ping_ms) + "ms"
			
			if ping_ms > worst_ping:
				worst_ping = ping_ms
			
			s_array[4] = " ▸ Worst Ping: " + str(worst_ping) + "ms"
	
	var result_txt = ""
	
	for s in s_array:
		if s != "":
			result_txt = result_txt + s + "\n"
	
	status_text.text = result_txt

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

func mpc_started_entry(player):
	boot_ui.visible = false
	status_ui.visible = true

func _on_close_pressed():
	visible = false
