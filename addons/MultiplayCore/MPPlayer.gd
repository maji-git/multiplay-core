@icon("res://addons/MultiplayCore/icons/MPPlayer.svg")

extends MPBase
## MultiPlay Player Node
class_name MPPlayer

## Ping in ms
@export var ping_ms: int
## Handshake data
@export var handshake_data = {}
## ID of the player
@export var player_id = 0
## Get MultiPlayCore
var mpc: MultiPlayCore
## The player node created from the template, see [member MultiPlayCore.player_scene]
var player_node: Node
## Determines if this player is local
var is_local = false
## Determines if this player network is ready
var is_ready = false
## Determines the player index, not to be confused with player_id.
var player_index = 0
var _internal_peer: MultiplayerPeer
var _initcount = 20
## Determines if swap is focusing this player, Swap mode only.
var is_swap_focused = false
## The resource path of the template player.
var player_node_resource_path = ""

## On player ready. Only emit locally
signal player_ready
## On handshake data is ready. Emit to all players
signal handshake_ready(handshake_data: Dictionary)
## On swap focused, Swap mode only
signal swap_focused
## On swap unfocused, Swap mode only
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
	
	mpc.online_connected = true

func _on_swap_changed(new, _old):
	if new == player_index:
		is_swap_focused = true
		swap_focused.emit()
	
	if new != player_index and is_swap_focused == true:
		is_swap_focused = false
		swap_unfocused.emit()

## Translate input action to the intended ones.
##
## In Online/Solo, it'll return the same input action name[br]
## In One Screen, it'll return new input action, each assigned to it's own device index.[br]
## In Swap, if swap is active on this player, it'll return the same input action name. If not, it'll return the "empty" action.[br]
##
func translate_action(origin_action: StringName) -> StringName:
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

## Just like translate_action, but in shorter format
func ma(action_name: StringName):
	return translate_action(action_name)

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
			
			mpc.connected_to_server.emit(self)
			
			rpc("_send_handshake_data", handshake_data)
		else:
			_initcount = _initcount - 1

## Disconnect the player, this is intended for local use.
func disconnect_player():
	if _internal_peer:
		if mpc.online_connected:
			mpc.online_connected = false
			mpc.disconnected_from_server.emit("USER_REQUESTED_DISCONNECT")
		
		_internal_peer.close()

## Kick the player, Server only.
func kick(reason: String = ""):
	rpc_id(1, "_net_kick", reason)

## Respawn player node, Server only.
func respawn_node():
	rpc_id(1, "_net_respawn")

## Despawn player node, Server only.
func despawn_node():
	rpc_id(1, "_net_despawn")

## Spawn player node, Server only.
func spawn_node():
	rpc_id(1, "_net_spawn_node")

@rpc("any_peer", "call_local")
func _net_kick(reason: String = ""):
	if !_check_if_net_from_id(1):
		return
	
	MPIO.logdata("Kicked from the server: " + str(reason))
	
	if mpc.online_connected:
		mpc.online_connected = false
		mpc.disconnected_from_server.emit(reason)
	
	_internal_peer.close()

@rpc("any_peer", "call_local")
func _net_respawn():
	if !_check_if_net_from_id(1):
		return
	
	_net_despawn()
	_net_spawn_node()

@rpc("any_peer", "call_local")
func _net_despawn():
	if !_check_if_net_from_id(1):
		return
	
	if player_node:
		player_node.queue_free()
		player_node = null

@rpc("any_peer", "call_local")
func _net_spawn_node():
	if !_check_if_net_from_id(1):
		return
	
	if player_node and is_instance_valid(player_node):
		MPIO.logwarn("spawn_node: Player node already exists. Free it first with despawn_node or use respawn_node")
		return
	
	if player_node_resource_path:
		var packed_load = load(player_node_resource_path)
		var pscene = packed_load.instantiate()
		add_child(pscene, true)
		
		player_node = pscene

