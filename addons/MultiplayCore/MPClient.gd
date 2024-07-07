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
	client_ready.emit()
	_send_handshake_data(handshake_data)
	mpc.connected_to_server.emit()
	
	_setup_nodes()

func _setup_nodes():
	_player_spawner = MultiplayerSpawner.new()
	_player_spawner.name = "PlayerSpawner"
	#_player_spawner.spawn_function = _player_spawned
	add_child(_player_spawner, true)

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
