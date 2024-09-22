@icon("res://addons/MultiplayCore/icons/MPPlayer.svg")

extends MPBase
## MultiPlay Player Node
class_name MPPlayer

## Ping in ms
@export var ping_ms: int
## Handshake data
@export var handshake_data = {}
## Authentication Data
var auth_data = {}
## ID of the player
@export var player_id: int = 0
## Get MultiPlayCore
var mpc: MultiPlayCore
## The player node created from the template, see [member MultiPlayCore.player_scene]
var player_node: Node
## Determines if this player is local
var is_local: bool = false
## Determines if this player network is ready
var is_ready: bool = false
## Determines the player index, not to be confused with player_id.
var player_index: int = 0
var _internal_peer: MultiplayerPeer
var _initcount = 20
## Determines if swap is focusing this player, Swap mode only.
var is_swap_focused: bool = false
## The resource path of the template player.
var player_node_resource_path: String = ""

var _local_got_handshake = false
# Determine if handshake event has already been emitted
var _handshake_is_ready = false

## On player ready. Only emit locally
signal player_ready
## On handshake data is ready. Emit to all players
signal handshake_ready(handshake_data: Dictionary)
## On swap focused, Swap mode only
signal swap_focused(old_swap: MPPlayer)
## On swap unfocused, Swap mode only
signal swap_unfocused(new_swap: MPPlayer)

# Called when the node enters the scene tree for the first time.
func _ready():
	if mpc.mode != mpc.PlayMode.Online:
		is_ready = true
		player_ready.emit()
		_send_handshake_data(handshake_data)
		mpc.connected_to_server.emit(self)
	
	_internal_peer = multiplayer.multiplayer_peer
	#_internal_peer = multiplayer.multiplayer_peer
	
	mpc.swap_changed.connect(_on_swap_changed)
	
	if mpc.mode == mpc.PlayMode.Swap and mpc.current_swap_index == player_index:
		is_swap_focused = true
		swap_focused.emit(null)

func _on_swap_changed(new, old):
	var new_focus = mpc.players.get_player_by_index(new)
	var old_focus = mpc.players.get_player_by_index(old)
	
	if new == player_index:
		is_swap_focused = true
		swap_focused.emit(old_focus)
	
	if new != player_index and is_swap_focused == true:
		is_swap_focused = false
		swap_unfocused.emit(new_focus)

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
				if not (e is InputEventJoypadButton or e is InputEventJoypadMotion):
					continue
				
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
	_on_handshake_ready()

func _on_handshake_ready():
	if _handshake_is_ready:
		return
	if handshake_data.keys().has("_net_internal"):
		if handshake_data._net_internal.keys().has("auth_data"):
			auth_data = handshake_data._net_internal.auth_data
	handshake_ready.emit(handshake_data)
	_handshake_is_ready = true

func _check_if_net_from_id(id):
	if mpc.mode != mpc.PlayMode.Online:
		return true
	return multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local")
func _send_handshake_data(data):
	handshake_data = data
	_handshake_is_ready = false
	_on_handshake_ready()

@rpc("any_peer", "call_local")
func _internal_ping(server_time: float):
	if !_check_if_net_from_id(1):
		return
	if !is_local:
		if not _local_got_handshake:
			_local_got_handshake = true
			rpc("_get_handshake_data")
		return
	var current_time = Time.get_unix_time_from_system()
	
	ping_ms = int(round((current_time - server_time) * 1000))
	
	if not is_ready:
		if _initcount < 1:
			# Connnection Ready!
			is_ready = true
			player_ready.emit()
			
			mpc._on_local_player_ready()
			
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
	rpc_id(player_id, "_net_kick", reason)

## Respawn player node, Server only.
func respawn_node():
	rpc("_net_despawn")
	rpc("_net_spawn_node")

## Despawn player node, Server only.
func despawn_node():
	rpc("_net_despawn")

## Spawn player node, Server only.
func spawn_node():
	rpc("_net_spawn_node")

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
func _net_despawn():
	if !_check_if_net_from_id(1):
		return
	
	if player_node:
		player_node.free()
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
		
		if mpc.assign_client_authority:
			pscene.set_multiplayer_authority(player_id, true)
		
		add_child(pscene, true)
		
		is_ready = true
		_send_handshake_data(handshake_data)
		
		if is_local:
			player_ready.emit()
		
		if mpc.mode == mpc.PlayMode.Swap:
			mpc.swap_to(0)
		
		player_node = pscene
