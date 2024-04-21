@icon("res://addons/MultiplayCore/icons/MultiPlayCore.svg")
@tool

extends MPBase
## Core of everything MultiPlay
class_name MultiPlayCore

## On network scene loaded
signal scene_loaded
## Emit when new player is connected to the server, Emit to all players in the server.
signal player_connected(player: MPPlayer)
## Emit when player has disconnected from the server, Emit to all players in the server.
signal player_disconnected(player: MPPlayer)
## Emit when client has connected to the server, Only emit locally.
signal connected_to_server(localplayer: MPPlayer)
## Emit when client has disconnected from the server, Only emit locally.
signal disconnected_from_server(reason: String)
## Emit when swap index has changed. Only emit in Swap Play mode
signal swap_changed(to_index: int, old_index: int)

## Methods to use for multiplayer game
enum PlayMode {
	## Network enabled multiplayer
	Online,
	## Single screen multiplayer. User can play with multiple controllers/devices.
	OneScreen,
	## Swap mode. Intended to be played with one player, user can switch to the peer they wanted to control.
	Swap,
	## Solo, self explanatory
	Solo
}

## Network Protocol to use in online games
enum NetworkProtocol {
	## Use ENet
	ENet,
	## Use WebSockets
	WebSockets,
}

@export_subgroup("Network")
## Determines which network protocol to use.
@export var network_protocol: NetworkProtocol
## Which port to use in online game host.
@export var port: int = 4200
## Max players for the game.
@export var max_players = 2

@export_subgroup("Spawn Meta")
## Your own template player scene.
@export var player_scene: PackedScene

@export_subgroup("Inputs")
## Which action key to use for swap mode.
@export var swap_input_action = ""

@export_subgroup("GUI")
## Enable Debug UI
@export var debug_gui_enabled = true

var _net_data = {
	current_scene_path = ""
}

## Current playmode
var mode = PlayMode.Online
## MultiplayerPeer for the game
var online_peer: MultiplayerPeer = null

## If conneccted in online mode
var online_connected = false

## Players Collection
var players: MPPlayersCollection = MPPlayersCollection.new()
var _players_node: Node
var _plr_spawner: MultiplayerSpawner
## Determines if MultiPlay has started
var started = false
## Determines if MultiPlay is running as server
var is_server = false
## The local player node
var local_player: MPPlayer = null
## Current player count
var player_count = 0
## Current scene node
var current_scene: Node = null

## Current swap index, Swap mode only.
var current_swap_index = 0

var _join_handshake_data = {}

func _ready():
	if Engine.is_editor_hint():
		return
	_presetup_nodes()
	
	if debug_gui_enabled:
		var dgui = preload("res://addons/MultiplayCore/debug_ui/debug_ui.tscn").instantiate()
		var bootui = dgui.get_node("Layout/BootUI")
		
		bootui.mpc = self
		
		if network_protocol == NetworkProtocol.WebSockets:
			bootui.join_address = "ws://localhost:" + str(port)
		elif network_protocol == NetworkProtocol.ENet:
			bootui.join_address = "127.0.0.1:" + str(port)
		
		add_child(dgui)

func _init_data():
	started = true
	InputMap.add_action("empty")
	_setup_nodes()

## Start one screen mode
func start_one_screen():
	mode = PlayMode.OneScreen
	_online_host()
	
	for i in range(0, max_players):
		create_player(i, {})

## Start solo mode
func start_solo():
	mode = PlayMode.Solo
	_online_host()
	
	create_player(1, {})

## Start swap mode
func start_swap():
	mode = PlayMode.Swap
	_online_host()
	
	if swap_input_action == "":
		MPIO.logwarn("swap_input_action currently not set. Please set it first in MultiplayCore Node")
	
	for i in range(0, max_players):
		create_player(i, {})

func _unhandled_input(event):
	if mode == PlayMode.Swap:
		if event.is_action_pressed(swap_input_action):
			swap_increment()

## Swap control to player according to index. Swap mode only
func swap_increment():
	if mode != PlayMode.Swap:
		MPIO.logwarn("swap_player: Not in swap mode")
	
	var old_index = current_swap_index
	current_swap_index = current_swap_index + 1
	if current_swap_index >= player_count:
		current_swap_index = 0
			
	swap_changed.emit(current_swap_index, old_index)

## Specifically Swap to index. Swap mode only
func swap_to(index):
	if mode != PlayMode.Swap:
		MPIO.logwarn("swap_player: Not in swap mode")
	
	var old_index = current_swap_index
	current_swap_index = index
	if current_swap_index >= player_count or current_swap_index < 0:
		current_swap_index = 0

	swap_changed.emit(current_swap_index, old_index)

func _presetup_nodes():
	_players_node = Node.new()
	_players_node.name = "Players"
	add_child(_players_node, true)
	
	_plr_spawner = MultiplayerSpawner.new()
	_plr_spawner.name = "PlayerSpawner"
	_plr_spawner.spawn_function = _player_spawned
	add_child(_plr_spawner, true)

func _setup_nodes():
	_plr_spawner.spawn_path = _players_node.get_path()
	_plr_spawner.spawned.connect(_debug_node_spawned)

func _debug_node_spawned(node: Node):
	MPIO.logdata("NODE SPAWND: " + str(node.name))

## Start online mode as host
func start_online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}):
	mode = PlayMode.Online
	_online_host(act_client, act_client_handshake_data)

## Start online mode as client
func start_online_join(url: String, handshake_data: Dictionary = {}):
	mode = PlayMode.Online
	_online_join(url, handshake_data)

func _online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}):
	_init_data()
	
	is_server = true
	
	if network_protocol == NetworkProtocol.ENet:
		online_peer = ENetMultiplayerPeer.new()
		online_peer.create_server(port, max_players);
	elif network_protocol == NetworkProtocol.WebSockets:
		online_peer = WebSocketMultiplayerPeer.new()
		online_peer.create_server(port);
	
	print("Starting server at port ", port)
	
	multiplayer.multiplayer_peer = online_peer
	multiplayer.peer_connected.connect(_network_player_connected)
	multiplayer.peer_disconnected.connect(_network_player_disconnected)

	if act_client:
		_join_handshake_data = act_client_handshake_data
		#create_player(1, act_client_handshake_data)
		_network_player_connected(1)
		_client_connected()

func _online_join(url: String, handshake_data: Dictionary = {}):
	_init_data()
	
	_join_handshake_data = handshake_data
	
	if network_protocol == NetworkProtocol.ENet:
		var splitd = url.split(":")
		
		online_peer = ENetMultiplayerPeer.new()
		online_peer.create_client(splitd[0], int(splitd[1]));
	elif network_protocol == NetworkProtocol.WebSockets:
		online_peer = WebSocketMultiplayerPeer.new()
		online_peer.create_client(url)
	
	multiplayer.multiplayer_peer = online_peer
	multiplayer.connected_to_server.connect(_client_connected)
	multiplayer.server_disconnected.connect(_client_disconnected)

## Create player node
func create_player(player_id, handshake_data = {}):
	player_count = player_count + 1
	_plr_spawner.spawn({player_id = player_id, handshake_data = handshake_data, pindex = player_count})

@rpc("authority", "call_local", "reliable")
func _net_broadcast_new_player(peer_id):
	var target_plr = players.get_player_by_id(peer_id)
	
	if target_plr:
		player_connected.emit(target_plr)

@rpc("authority", "call_local", "reliable")
func _net_broadcast_remove_player(peer_id: int):
	var target_plr = players.get_player_by_id(peer_id)
	
	if target_plr:
		if !is_server:
			player_disconnected.emit(target_plr)
			players._internal_remove_player(peer_id)

func _player_spawned(data):
	MPIO.plr_id = multiplayer.get_unique_id()
	MPIO.logdata("player spawning " + str(data.player_id))
	var player = preload("res://addons/MultiplayCore/scenes/multiplay_player.tscn").instantiate()
	player.name = str(data.player_id)
	player.player_id = data.player_id
	player.handshake_data = data.handshake_data
	player.player_index = data.pindex - 1
	player.is_local = false
	player.mpc = self
	
	# If is local player
	if data.player_id == multiplayer.get_unique_id():
		player.is_local = true
		local_player = player
		player._internal_peer = player
	
	# First time init
	if player_scene:
		player.player_node_resource_path = player_scene.resource_path
		
		var pscene = player_scene.instantiate()
		player.add_child(pscene, true)
		
		player.player_node = pscene

	player.set_multiplayer_authority(data.player_id, true)
	players._internal_add_player(data.player_id, player)
	
	if is_server:
		rpc("_net_broadcast_new_player", player.player_id)
	
	return player

func _network_player_connected(player_id):
	if player_count >= max_players:
		online_peer.disconnect_peer(player_id)
		return
	rpc_id(player_id, "_internal_recv_net_data", _net_data)

func _network_player_disconnected(player_id):
	player_count = player_count - 1
	
	var target_plr = players.get_player_by_id(player_id)
	
	if target_plr:
		rpc("_net_broadcast_remove_player", player_id)
		player_disconnected.emit(target_plr)
		target_plr.queue_free()

@rpc("any_peer", "call_local", "reliable")
func _join_handshake(handshake_data):
	MPIO.plr_id = multiplayer.get_unique_id()
	create_player(multiplayer.get_remote_sender_id(), handshake_data)

@rpc("any_peer", "call_local", "reliable")
func _internal_recv_net_data(data):
	MPIO.plr_id = multiplayer.get_unique_id()
	MPIO.logdata("Data received")
	
	_net_data = data
	if _net_data.current_scene_path != "":
		_net_load_scene(_net_data.current_scene_path)
	
	MPIO.logdata("Sending Join Handshake")
	rpc_id(1, "_join_handshake", _join_handshake_data)

func _client_connected():
	MPIO.logdata("Connected")

func _client_disconnected():
	if online_connected:
		disconnected_from_server.emit("Unknown")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if started and is_server:
		players._internal_ping()

## Load scene for all players
func load_scene(scene_path: String):
	rpc("_net_load_scene", scene_path)

func _check_if_net_from_id(id):
	return mode == PlayMode.Online and multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local", "reliable")
func _net_load_scene(scene_path: String):
	_net_data.current_scene_path = scene_path
	
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	if !FileAccess.file_exists(scene_path):
		MPIO.logerr("Target scene doesn't exist")
		return
	
	var scene_pack = load(scene_path)
	var scene_node = scene_pack.instantiate()
	
	current_scene = scene_node
	
	add_child(scene_node)
	
