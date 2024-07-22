@tool
extends EditorDebuggerPlugin

var ready_i = 0

func _has_capture(prefix):
	return prefix == "mpc_test"

func _capture(message, data, session_id):
	var session = get_session(session_id)
	
	if message == "mpc_test:debug_session_ready":
		if session_id == 0:
			session.send_message("mpc_test:start_server", [session_id])
		else:
			session.send_message("mpc_test:start_client", [session_id])
	
	if message == "mpc_test:session_complete":
		ready_i = ready_i + 1
		
		if ready_i == 2:
			
			print("********")
			print("ready_i: ", ready_i)
			
			ready_i = 0
			
			for s in get_sessions():
				s.send_message("mpc_test:start_next")

func _setup_session(session_id):
	ready_i = 0
