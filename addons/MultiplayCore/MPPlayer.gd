@icon("res://addons/MultiplayCore/icons/MPPlayer.svg")

extends Node
class_name MPPlayer

@export var ping_ms: int
@export var handshake_data = {}
@export var player_id = 0
var mpc: MultiPlayCore
var player_node: Node
var is_local = false
var is_ready = false
var player_index = 0
var _internal_peer: MultiplayerPeer
var _initcount = 20
var is_swap_focused = false
signal player_ready
signal handshake_ready(handshake_data: Dictionary)
signal swap_focused
signal swap_unfocused

# Called when the node enters the scene tree for the first time.
func _ready():
	if mpc.mode == mpc.PlayMode.Online:
		MPIO.logdata(str(player_id) + " local is " + str(is_local))
		if !is_local:
			pass
			#rpc("_get_handshake_data")
	else:
		is_ready = true
		player_ready.emit()
		_send_handshake_data(handshake_data)
		mpc.connect_to_server.emit()
	
	mpc.swap_changed.connect(_on_swap_changed)
	
	if mpc.mode == mpc.PlayMode.Swap and mpc.current_swap_index == player_index:
		is_swap_focused = true
		swap_focused.emit()

func _on_swap_changed(new, _old):
	if new == player_index:
		is_swap_focused = true
		swap_focused.emit()
	
	if new != player_index and is_swap_focused == true:
		is_swap_focused = false
		swap_unfocused.emit()

func ma(action_name: StringName):
	return translate_action(action_name)

func translate_action(origin_action: StringName):
	if mpc.mode == mpc.PlayMode.Online:
		if !is_local:
			return "empty"
		return origin_action
	
	if mpc.mode == mpc.PlayMode.Swap:
		if mpc.current_swap_index == player_index:
			return origin_action
		return "empty"
	
	if mpc.mode == mpc.PlayMode.OneScreen:
		var action_name = origin_action + "_" + str(player_index)
		
		if !InputMap.has_action(action_name):
			var events = InputMap.action_get_events(origin_action)
		
			for e in events:
				var nevent = e.duplicate(true)
				nevent.device = player_index
				
				if !InputMap.has_action(action_name):
					InputMap.add_action(action_name)
					InputMap.action_add_event(action_name, nevent)
		
		return action_name
	
	return origin_action

@rpc("any_peer")
func _get_handshake_data():
	if is_local:
		rpc_id(multiplayer.get_remote_sender_id(), "_recv_handshake_data", handshake_data)

@rpc("any_peer")
func _recv_handshake_data(hs):
	handshake_data = hs
	handshake_ready.emit(handshake_data)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _check_if_net_from_id(id):
	return mpc.mode == mpc.PlayMode.Online and multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local")
func _send_handshake_data(data):
	handshake_data = data
	handshake_ready.emit(data)

@rpc("any_peer", "call_local")
func _internal_ping(server_time: float):
	if !_check_if_net_from_id(1):
		return
	if !is_local:
		return
	var current_time = Time.get_unix_time_from_system()
	
	ping_ms = int(round((current_time - server_time) * 1000))
	
	if not is_ready:
		if _initcount < 1:
			is_ready = true
			player_ready.emit()
			
			mpc.connect_to_server.emit()
			
			rpc("_send_handshake_data", handshake_data)
		else:
			_initcount = _initcount - 1

@rpc("any_peer")
func kick():
	if !_check_if_net_from_id(1):
		return

func respawn():
	if !_check_if_net_from_id(1):
		return
