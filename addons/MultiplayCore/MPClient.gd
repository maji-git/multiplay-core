@icon("res://addons/MultiplayCore/icons/MPClient.svg")

extends MPBase
## MultiPlay Client Node
class_name MPClient

## Ping in ms
var ping_ms: int
## Handshake data (Client Data)
var handshake_data = {}
## Authentication Data (Client Auth Data)
var auth_data = {}
## Peer ID of the client. Can be used with Godot's built-in MP functions. ([code]rpc[/code]/[code]rpc_id[/code])
var client_id: int = 0

## Get MultiPlayCore
var mpc: MultiPlayCore
## Get MPPlayers of this client
var mpps = []
## Determines if this player is local
var is_local: bool = false
## Determines if this player network is ready
var is_ready: bool = false
var _internal_peer: MultiplayerPeer
var _initcount = 20

var _local_got_handshake = false

## On client ready. Only emit locally
signal client_ready
## On handshake data is ready. Emit to all players
signal handshake_ready(handshake_data: Dictionary)

var _player_spawner: MultiplayerSpawner

func _ready():
	_setup_nodes()
	
	_send_handshake_data(handshake_data)
	mpc.connected_to_server.emit()
	client_ready.emit()

func _setup_nodes():
	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	_player_spawner.spawn_function = _player_spawned
	_player_spawner.spawn_path = get_path_to(self.get_parent())
	_player_spawner.set_multiplayer_authority(1)
	add_child(_player_spawner, true)

func join_all(player_data: Dictionary = {}):
	_join_pass(player_data, 0, MultiPlayCore.InputType.All)

func join_keyboard(player_data: Dictionary = {}):
	_join_pass(player_data, -1, MultiPlayCore.InputType.Keyboard)

func join_joypad(player_data: Dictionary = {}, device_id: int = 0):
	_join_pass(player_data, device_id, MultiPlayCore.InputType.Joypad)

func _join_pass(player_data: Dictionary, device_id: int, input_type: MultiPlayCore.InputType):
	rpc_id(1, "_net_join_plr", player_data, device_id, input_type)

@rpc("authority", "call_local", "reliable")
func _net_join_plr(player_data: Dictionary, device_id: int, input_type: MultiPlayCore.InputType):
	if multiplayer.get_remote_sender_id() != client_id:
		return
	
	if mpps.size() >= mpc.max_players:
		MPIO.logerr("Reached maximum players")
		return
	
	if mpps.size() >= mpc.max_players_per_client:
		MPIO.logerr("Reached maximum players that this client can create")
		return
	
	var player_id = mpc.players._create_id()
	
	_player_spawner.spawn({
		player_data = player_data,
		pindex = 0,
		device_id = device_id,
		plr_id = player_id,
		input_type = input_type
	})

func _player_spawned(data):
	var player = MPPlayer.new()
	player.name = str(data.plr_id)
	player.player_id = data.plr_id
	player.client_id = client_id
	player.player_data = data.player_data
	player.player_index = data.pindex
	player.is_local = false
	player.client = self
	player.mpc = mpc
	
	# If is local
	if client_id == multiplayer.get_unique_id():
		player.is_local = true
		mpc.local_player = player
		mpc.local_players.append(player)
		player._internal_peer = player
		player.input_method = data.input_type
		player.device_id = data.device_id
	
	if mpc.player_scene:
		player.player_node_resource_path = mpc.player_scene.resource_path
		
		var pscene = mpc.player_scene.instantiate()
		player.add_child(pscene, true)
		
		player.player_node = pscene
	
	if mpc.assign_client_authority:
		player.set_multiplayer_authority(client_id, true)
	
	mpc.players._internal_add_player(player.player_id, player)
	mpps.append(player)
	
	if mpc.is_server:
		mpc.rpc("_net_broadcast_new_player", player.player_id)
	
	return player

@rpc("any_peer")
func _get_handshake_data():
	if is_local:
		rpc_id(multiplayer.get_remote_sender_id(), "_recv_handshake_data", handshake_data)

func _on_local_player_ready():
	pass

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
	return multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local")
func _send_handshake_data(data):
	handshake_data = data
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
			client_ready.emit()
			
			mpc._on_local_client_ready()
			
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
	rpc_id(client_id, "_net_kick", reason)

@rpc("any_peer", "call_local")
func _net_kick(reason: String = ""):
	if !_check_if_net_from_id(1):
		return
	
	MPIO.logdata("Kicked from the server: " + str(reason))
	
	if mpc.online_connected:
		mpc.online_connected = false
		mpc.disconnected_from_server.emit(reason)
	
	_internal_peer.close()
