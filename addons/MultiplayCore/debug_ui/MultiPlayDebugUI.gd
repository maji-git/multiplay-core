extends Control

var mpc: MultiPlayCore
@export var connect_address: LineEdit
@export var payload_input: TextEdit
var join_address = "ws://localhost:4200"

# Called when the node enters the scene tree for the first time.
func _ready():
	connect_address.text = join_address

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_host_pressed():
	mpc.start_online_host(false, JSON.parse_string(payload_input.text))
	_on_close_pressed()

func _on_host_act_pressed():
	mpc.start_online_host(true, JSON.parse_string(payload_input.text))
	_on_close_pressed()

func _on_connect_pressed():
	mpc.start_online_join(join_address, JSON.parse_string(payload_input.text))
	_on_close_pressed()

func _on_connect_address_text_changed(new_text):
	join_address = new_text


func _on_one_screen_pressed():
	mpc.start_one_screen()
	_on_close_pressed()


func _on_solo_pressed():
	mpc.start_solo()
	_on_close_pressed()


func _on_swap_pressed():
	mpc.start_swap()
	_on_close_pressed()


func _on_close_pressed():
	visible = false
