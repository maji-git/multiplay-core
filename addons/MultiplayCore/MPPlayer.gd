@icon("res://addons/MultiplayCore/icons/MPPlayer.svg")

extends MPBase
## MultiPlay Player Node
class_name MPPlayer

## Ping in ms, returns client's ping. see [member MPClient.ping_ms]
var ping_ms: int = 0 :
	get:
		return client.ping_ms
## Handshake data (Client Data). see [member MPClient.handshake_data]
var handshake_data = {} :
	get:
		return client.handshake_data
## User data (Player Data)
var player_data = {}
## Authentication Data (Client Auth Data). see [member MPClient.auth_data]
var auth_data = {}  :
	get:
		return client.auth_data
## ID associated with specific player node. Used to uniquely identify a player. Cannot be used with Godot's built-in MP.
var player_id: int = 0

## ID associated with specific client. Useable with Godot’s built-in MP (rpc/rpc_id)
var client_id: int = 0

## Get MultiPlayCore
var mpc: MultiPlayCore
## Get Owner Client of this player node
var client: MPClient
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

## Play Mode method that this node uses.
var playmode: MultiPlayCore.PlayMode

## Input method that this node uses.
var input_method: MultiPlayCore.InputType

## Controller Device ID to use (for one-screen/joinable)
var device_id: int = -1

var _local_got_handshake = false

var _ref_input_action_names: PackedStringArray = []

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
	is_ready = true
	player_ready.emit()
			
	client._on_local_player_ready()
	"""
	if playmode != mpc.PlayMode.Online:
		is_ready = true
		player_ready.emit()
		mpc.connected_to_server.emit()
	
	mpc.swap_changed.connect(_on_swap_changed)
	
	if playmode == mpc.PlayMode.Swap and mpc.current_swap_index == player_index:
		is_swap_focused = true
		swap_focused.emit(null)
	"""

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
	
	var action_name = origin_action + "_" + str(player_id)
	
	if !InputMap.has_action(action_name):
		var events = InputMap.action_get_events(origin_action)
		
		for e in events:
			if input_method == mpc.InputType.Joypad:
				if not (e is InputEventJoypadButton or e is InputEventJoypadMotion):
					continue
			
			if input_method == mpc.InputType.Keyboard:
				if not (e is InputEventKey):
					continue
			
			var nevent = e.duplicate(true)
			nevent.device = device_id
				
			if !InputMap.has_action(action_name):
				InputMap.add_action(action_name)
				InputMap.action_add_event(action_name, nevent)
				
				_ref_input_action_names.append(action_name)
				
		
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
	if handshake_data.keys().has("_net_internal"):
		if handshake_data._net_internal.keys().has("auth_data"):
			auth_data = handshake_data._net_internal.auth_data
	handshake_ready.emit(handshake_data)

func _check_if_net_from_id(id):
	if playmode != mpc.PlayMode.Online:
		return true
	return multiplayer.get_remote_sender_id() == id

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
		
		if is_local:
			player_ready.emit()
		
		if playmode == mpc.PlayMode.Swap:
			mpc.swap_to(0)
		
		player_node = pscene

