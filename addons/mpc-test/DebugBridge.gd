extends Node

signal msgcap_initd
signal msgcap_ready

var role = ""
var step_i = 0
var initd = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func init():
	if initd:
		msgcap_initd.emit()
		return
	initd = true
	EngineDebugger.register_message_capture("mpc_test", _debugger_msg_capture)
	EngineDebugger.send_message("mpc_test:debug_session_ready", [])

func set_title():
	DisplayServer.window_set_title(role + " - " + str(step_i))

func _debugger_msg_capture(msg, data):
	if msg == "start_server":
		role = "server"
		msgcap_initd.emit()
	
	if msg == "start_client":
		role = "client"
		msgcap_initd.emit()
	
	if msg == "start_next":
		step_i = step_i + 1
		msgcap_ready.emit()
		set_title()
	
	return true
