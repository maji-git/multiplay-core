@icon("res://addons/MultiplayCore/icons/MultiPlayCore.svg")
@tool

extends MPBase
## Core of everything MultiPlay
class_name MultiPlayCore

## MultiPlay Core Version
const MP_VERSION = "0.2.4-dev-np"

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
## Emit when client faced connection error
signal connection_error(reason: ConnectionError)
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

## List of connection errors
enum ConnectionError {
	UNKNOWN,
	SERVER_FULL,
	AUTH_FAILED,
}

@export_subgroup("Network")
## Which ip to bind on in online game host.
@export var bind_address: String = "*"
## Which port to use in online game host.
@export_range(0, 65535) var port: int = 4200
## Max players for the game.
@export var max_players = 2

@export_subgroup("Spawn Meta")
## Your own template player scene.
@export var player_scene: PackedScene
## The first scene to load
@export var first_scene: PackedScene
## Should Client authority be assigned automatically?
@export var assign_client_authority: bool = true

@export_subgroup("Inputs")
## Which action key to use for swap mode.
@export var swap_input_action: String:
	get:
		return swap_input_action
	set(value):
		swap_input_action = value
		if Engine.is_editor_hint():
			update_configuration_warnings()

@export_subgroup("GUI")
## Enable Debug UI
@export var debug_gui_enabled: bool = true

func _get_configuration_warnings():
	var warns = []
	if swap_input_action == "":
		warns.append("Swap Input action currently not set.")
	
	var net_count = 0
	for c in get_children():
		if c is MPNetProtocolBase:
			net_count = net_count + 1
			if net_count > 1:
				break
	
	if net_count == 0:
		warns.append("No Net Protocol set for online mode, add one by Add Child Node > Type in search 'Protocol'")
	elif net_count > 1:
		warns.append("Only 1 Net Protocol can be set.")
	
	
	return warns

var _net_data = {
	current_scene_path = ""
}

## Current playmode
var mode: PlayMode = PlayMode.Online
## MultiplayerPeer for the game
var online_peer: MultiplayerPeer = null

## If conneccted in online mode
var online_connected: bool = false

## Players Collection
var players: MPPlayersCollection
var _plr_spawner: MultiplayerSpawner
## Determines if MultiPlay has started
var started: bool = false
## Determines if MultiPlay is running as server
var is_server: bool = false
## The local player node
var local_player: MPPlayer = null
## Current player count
var player_count: int = 0
## Current scene node
var current_scene: Node = null

## Current swap index, Swap mode only.
var current_swap_index: int = 0

var _join_handshake_data = {}
var _join_credentials_data = {}
var _extensions = []

var _net_protocol: MPNetProtocolBase = null

func _ready():
	if Engine.is_editor_hint():
		child_entered_tree.connect(_tool_child_refresh_warns)
		child_exiting_tree.connect(_tool_child_refresh_warns)
		return
	_presetup_nodes()
	
	
	if debug_gui_enabled and OS.is_debug_build():
		var dgui = preload("res://addons/MultiplayCore/debug_ui/debug_ui.tscn").instantiate()
		var bootui = dgui.get_node("Layout/BootUI")
		
		bootui.mpc = self
		
		var bind_address_url = bind_address
		
		if bind_address_url == "*":
			bind_address_url = "127.0.0.1"
		
		bootui.join_address = bind_address_url + ":" + str(port)
		
		add_child(dgui)
	
	# Parse CLI arguments
	var arguments = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			arguments[argument.lstrip("--")] = ""
	
	if arguments.has("port"):
		port = int(arguments.port)
	
	if arguments.has("server"):
		_online_host(arguments.has("act-client"))
	
	if arguments.has("client"):
		var client_url = ""
		if arguments.has("url"):
			client_url = arguments.url
		_online_join(client_url)

func _tool_child_refresh_warns(new_child):
	update_configuration_warnings()

func _init_data():
	print("MultiPlay Core v" + MP_VERSION + " - https://mpc.himaji.xyz - https://discord.gg/PXh9kZ9GzC")
	print("")
	started = true
	MPIO.mpc = self
	InputMap.add_action("empty")
	_setup_nodes()
	
	if mode == PlayMode.Online and _net_protocol == null:
		assert(false, "NetProtocol is current not set.")

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

func _report_extension(ext: MPExtension):
	_extensions.append(ext)
	
	if ext is MPNetProtocolBase:
		_net_protocol = ext

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
	players = MPPlayersCollection.new()
	players.name = "Players"
	add_child(players, true)
	
	_plr_spawner = MultiplayerSpawner.new()
	_plr_spawner.name = "PlayerSpawner"
	_plr_spawner.spawn_function = _player_spawned
	add_child(_plr_spawner, true)

func _setup_nodes():
	_plr_spawner.spawn_path = players.get_path()

## Start online mode as host
func start_online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}, act_client_credentials_data: Dictionary = {}):
	mode = PlayMode.Online
	_online_host(act_client, act_client_handshake_data, act_client_credentials_data)

## Start online mode as client
func start_online_join(url: String, handshake_data: Dictionary = {}, credentials_data: Dictionary = {}):
	mode = PlayMode.Online
	_online_join(url, handshake_data, credentials_data)

func _online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}, act_client_credentials_data: Dictionary = {}):
	_init_data()
	
	is_server = true
	
	online_peer = _net_protocol.host(port, bind_address, max_players)
	
	MPIO.logdata("Starting server at port " + str(port))
	
	multiplayer.multiplayer_peer = online_peer
	multiplayer.peer_connected.connect(_network_player_connected)
	multiplayer.peer_disconnected.connect(_network_player_disconnected)
	
	if first_scene:
		load_scene(first_scene.resource_path)
	
	if act_client:
		_join_handshake_data = act_client_handshake_data
		_join_credentials_data = act_client_credentials_data
		#create_player(1, act_client_handshake_data)
		_network_player_connected(1)
		_client_connected()

func _online_join(address: String, handshake_data: Dictionary = {}, credentials_data: Dictionary = {}):
	_init_data()
	
	_join_handshake_data = handshake_data
	_join_credentials_data = credentials_data
	
	var result_url = ""
	
	var ip_split = Array(address.split("/"))
	var hostname = ip_split[0]
	var real_hostname = hostname.split(":")[0]
	
	ip_split.pop_front()
	
	var url_path = "/".join(PackedStringArray(ip_split))
	
	if url_path.length() > 0:
		url_path = "/" + url_path
	
	var portsplit = hostname.split(":")
	var port_num = null
	
	if portsplit.size() > 1:
		port_num = int(portsplit[1])
	
	online_peer = await _net_protocol.join(real_hostname + url_path, port_num)
	
	multiplayer.multiplayer_peer = online_peer
	multiplayer.connected_to_server.connect(_client_connected)
	multiplayer.server_disconnected.connect(_client_disconnected)

## Create player node
func create_player(player_id, handshake_data = {}):
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
		player_count = player_count - 1
		
		if !is_server:
			player_disconnected.emit(target_plr)
			players._internal_remove_player(peer_id)

func _player_spawned(data):
	MPIO.plr_id = multiplayer.get_unique_id()
	var player = preload("res://addons/MultiplayCore/scenes/multiplay_player.tscn").instantiate()
	player.name = str(data.player_id)
	player.player_id = data.player_id
	player.handshake_data = data.handshake_data
	player.player_index = data.pindex
	player.is_local = false
	player.mpc = self
	
	player_count = player_count + 1
	
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

	if assign_client_authority:
		player.set_multiplayer_authority(data.player_id, true)
	
	players._internal_add_player(data.player_id, player)
	
	if is_server:
		rpc("_net_broadcast_new_player", player.player_id)
	
	return player

func _network_player_connected(player_id):
	pass

func _find_key(dictionary, value):
	var index = dictionary.values().find(value)
	return dictionary.keys()[index]

@rpc("authority", "call_local")
func _handshake_disconnect_peer(reason: ConnectionError):
	MPIO.logerr("Connection Error: " + str(_find_key(ConnectionError, reason)))
	online_connected = false
	connection_error.emit(reason)
	online_peer.close()

func _network_player_disconnected(player_id):
	var target_plr = players.get_player_by_id(player_id)
	
	if target_plr:
		rpc("_net_broadcast_remove_player", player_id)
		player_disconnected.emit(target_plr)
		target_plr.queue_free()

# Init player
@rpc("any_peer", "call_local", "reliable")
func _join_handshake(handshake_data, credentials_data):
	var from_id = multiplayer.get_remote_sender_id()
	
	var existing_plr = players.get_player_by_id(from_id)
	
	if existing_plr:
		return
	
	if player_count >= max_players:
		rpc_id(from_id, "_handshake_disconnect_peer", ConnectionError.SERVER_FULL)
		return
	
	var auth_data = {}
	
	# Clear internal data, this is reserved
	if handshake_data.keys().has("_net_internal"):
		handshake_data._net_internal = {}
	
	handshake_data._net_internal = {
		auth_data = {}
	}
	
	# Authenticate client
	for ext in _extensions:
		if ext is MPAuth:
			var auth_result = await ext.authenticate(from_id, credentials_data, handshake_data)
			if typeof(auth_result) == TYPE_BOOL and auth_result == false:
				rpc_id(from_id, "_handshake_disconnect_peer", ConnectionError.AUTH_FAILED)
				return
				
			auth_data = auth_result
				
			break
	
	handshake_data._net_internal.auth_data = auth_data
	
	rpc_id(from_id, "_internal_recv_net_data", _net_data)
	create_player(from_id, handshake_data)

@rpc("any_peer", "call_local", "reliable")
func _internal_recv_net_data(data):
	MPIO.plr_id = multiplayer.get_unique_id()
	
	_net_data = data
	if _net_data.current_scene_path != "":
		_net_load_scene(_net_data.current_scene_path)

func _client_connected():
	print("CLIENT CONNECTED")
	rpc_id(1, "_join_handshake", _join_handshake_data, _join_credentials_data)

func _client_disconnected():
	if online_connected:
		disconnected_from_server.emit("Unknown")

# Ping player
func _physics_process(delta):
	if started and is_server:
		players._internal_ping()

## Load scene for all players
func load_scene(scene_path: String, respawn_players = true):
	rpc("_net_load_scene", scene_path, respawn_players)

func _check_if_net_from_id(id):
	if mode != PlayMode.Online:
		return true
	return multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local", "reliable")
func _net_load_scene(scene_path: String, respawn_players = true):
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
	
	if respawn_players:
		players.respawn_node_all()
	
	scene_loaded.emit()
