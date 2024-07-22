@tool
extends EditorDebuggerPlugin

var send_start_auto = false
var start_auto_i = 0

func _has_capture(prefix):
	return prefix == "mpc"

func _capture(message, data, session_id):
	var session = get_session(session_id)
	
	if message == "mpc:connected":
		var pid = data[0]
	
	if (message == "mpc:session_ready" and send_start_auto) or message == "mpc:debug_session_ready":
		start_auto_i = start_auto_i + 1
		if session_id == 0:
			session.send_message("mpc:start_server", [session_id])
		else:
			session.send_message("mpc:start_client", [session_id])
		
		if start_auto_i == get_sessions().size():
			start_auto_i = 0
			send_start_auto = false

func _setup_session(session_id):
	pass
