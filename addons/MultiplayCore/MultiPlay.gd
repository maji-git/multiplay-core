@icon("res://addons/MultiplayCore/icons/MultiPlayCore.svg")
@tool

extends MPBase
## Core of everything MultiPlay
class_name MultiPlayCore

## MultiPlay Core Version
const MP_VERSION = "1.0.0"

## MultiPlay Core Version Name
const MP_VERSION_NAME = "Envelope Puppet"

## On network scene loaded
signal scene_loaded
## Emit when new player has been added to the server, Emit to all players in the server.
signal player_added(player: MPPlayer)
## Emit when player has been removed from the server, Emit to all players in the server.
signal player_removed(player: MPPlayer)
## Emit when new client is connected to the server, Emit to all players in the server.
signal client_connected(client: MPClient)
## Emit when client has disconnected from the server, Emit to all players in the server.
signal client_disconnected(client: MPClient)
## Emit when client has connected to the server, Only emit locally.
signal connected_to_server()
## Emit when local player node is ready, Only emit locally.
signal localplayer_node_ready(local_player: MPPlayer)
## Emit when local client node is ready, Only emit locally.
signal localclient_node_ready(local_client: MPClient)
## Emit when client has disconnected from the server, Only emit locally.
signal disconnected_from_server(reason: String)
## Emit when client faced connection error
signal connection_error(reason: ConnectionError)
## Emit when swap index has changed. Only emit in Swap Play mode
signal swap_changed(to_index: int, old_index: int)

## Input method to use for MPPlayer's individual controls
enum InputType {
	## Control via keyboard/gamepad. This is useful if user were only allowed to create 1 client.
	All,
	## Control via keyboard
	Keyboard,
	## Control via gamepad
	Joypad,
}

## Session mode to use for multiplayer game
enum SessionMode {
	## Allow play modes to be mixed together in one session. (Swap is not supported in this mode)
	Joinable,
	## Fix to specific play mode only
	Fixed,
}

## List of connection errors
enum ConnectionError {
	## Unknown reason
	UNKNOWN,
	## The server's full
	SERVER_FULL,
	## Authentication Failure
	AUTH_FAILED,
	## Connection timed out
	TIMEOUT,
	## Failure during connection
	CONNECTION_FAILURE,
	## Internal handshake data cannot be readed by the server
	INVALID_HANDSHAKE,
	## Client's Multiplay version is not compatible with the server
	VERSION_MISMATCH,
}

@export_subgroup("Network")
## Which ip to bind on in online game host.
@export var bind_address: String = "*"
## Which port to use in online game host.
@export_range(0, 65535) var port: int = 4200
## Max players for the game.
@export var max_players: int = 4
## Maximum player node that client can create
@export var max_players_per_client: int = 2
## Max clients for the game.
@export var max_clients: int = 4
## Time in milliseconds before timing out the user.
@export var connect_timeout_ms: int = 50000

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

@export_subgroup("Debug Options")
## Enable Debug UI
@export var debug_gui_enabled: bool = true

var _rng = RandomNumberGenerator.new()

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

## MultiplayerPeer for the game
var online_peer: MultiplayerPeer = null

## If connected in online mode
var online_connected: bool = false

## If player node is ready
var player_client_ready: bool = false

## Players Collection
var players: MPPlayersCollection
var _client_spawner: MultiplayerSpawner
## Determines if MultiPlay has started
var started: bool = false
## Determines if MultiPlay is running as server
var is_server: bool = false
## The first local player node
var local_player: MPPlayer = null
## The list of local players
var local_players: Array = []
## The local client node
var local_client: MPClient = null
## Current player count
var player_count: int = 0
## Current client count
var client_count: int = 0
## Current scene node
var current_scene: Node = null

## Debug Status
var debug_status_txt = ""

## Current swap index, Swap mode only.
var current_swap_index: int = 0

var _join_handshake_data = {}
var _join_credentials_data = {}
var _extensions = []

var _net_protocol: MPNetProtocolBase = null
var _debug_join_address = ""

var _debug_bootui = null

func _ready():
	if Engine.is_editor_hint():
		child_entered_tree.connect(_tool_child_refresh_warns)
		child_exiting_tree.connect(_tool_child_refresh_warns)
		return
	_presetup_nodes()
	
	disconnected_from_server.connect(_on_local_disconnected)
	
	if OS.is_debug_build():
		var bind_address_url = bind_address
		
		if bind_address_url == "*":
			bind_address_url = "127.0.0.1"
		
		_debug_join_address = bind_address_url + ":" + str(port)
	
	if OS.is_debug_build():
		var debug_override = _net_protocol._override_debug_url(bind_address, port)
		
		if !debug_override:
			var bind_address_url = bind_address
		
			if bind_address_url == "*":
				bind_address_url = "127.0.0.1"
		
			_debug_join_address = bind_address_url + ":" + str(port)
		else:
			_debug_join_address = debug_override
	
	if debug_gui_enabled and OS.is_debug_build():
		var dgui = preload("res://addons/MultiplayCore/debug_ui/debug_ui.tscn").instantiate()
		_debug_bootui = dgui.get_node("Layout/BootUI")
		
		_debug_bootui.mpc = self
		_debug_bootui.join_address = _debug_join_address
		
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
	
	if OS.has_feature("debug"):
		EngineDebugger.register_message_capture("mpc", _debugger_msg_capture)
		EngineDebugger.send_message("mpc:session_ready", [])

func _debugger_msg_capture(msg, data):
	if msg.begins_with("start_"):
		var cred = {}
		var handsh = {}
		var session_id = data[0]
		
		# Load up debug configs
		var fp = FileAccess.open("user://mp_debug_configs", FileAccess.READ)
		if fp:
			var fp_data: Dictionary = JSON.parse_string(fp.get_as_text())
			fp.close()
			
			if fp_data.keys().has("debug_configs"):
				if fp_data.debug_configs.keys().has(str(session_id)):
					handsh = JSON.parse_string(fp_data.debug_configs[str(session_id)].handshake)
					cred = JSON.parse_string(fp_data.debug_configs[str(session_id)].credentials)
	
		if msg == "start_server":
			start_online_host(true, handsh, cred)
			if _debug_bootui:
				_debug_bootui.boot_close()
		if msg == "start_client":
			start_online_join(_debug_join_address, handsh, cred)
			if _debug_bootui:
				_debug_bootui.boot_close()
	return true

func _tool_child_refresh_warns(new_child):
	update_configuration_warnings()

func _init_data():
	print("MultiPlay Core v" + MP_VERSION + " - https://mpc.himaji.xyz - https://discord.gg/PXh9kZ9GzC")
	print("")
	started = true
	MPIO.mpc = self
	InputMap.add_action("empty")
	_setup_nodes()
	
	if _net_protocol == null:
		assert(false, "NetProtocol is current not set.")

## Start one screen mode
func start_one_screen():
	_online_host()
	
	for i in range(0, max_players):
		#create_player(i, {})
		pass

## Start solo mode
func start_solo():
	_online_host()
	
	#create_player(1, {})

func _report_extension(ext: MPExtension):
	_extensions.append(ext)
	
	if ext is MPNetProtocolBase:
		_net_protocol = ext

func join_keyboard(player_data: Dictionary = {}):
	local_client.join_keyboard(player_data)

func join_joypad(player_data: Dictionary = {}, device_id: int = 0):
	local_client.join_joypad(player_data, device_id)

func _presetup_nodes():
	players = MPPlayersCollection.new()
	players.name = "Clients"
	add_child(players, true)
	
	_client_spawner = MultiplayerSpawner.new()
	_client_spawner.name = "ClientSpawner"
	_client_spawner.spawn_function = _client_spawned
	add_child(_client_spawner, true)

func _setup_nodes():
	_client_spawner.spawn_path = players.get_path()

## Start online mode as host
func start_online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}, act_client_credentials_data: Dictionary = {}):
	_online_host(act_client, act_client_handshake_data, act_client_credentials_data)

## Start online mode as client
func start_online_join(url: String, handshake_data: Dictionary = {}, credentials_data: Dictionary = {}):
	_online_join(url, handshake_data, credentials_data)

func _online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}, act_client_credentials_data: Dictionary = {}):
	_init_data()
	
	debug_status_txt = "Server Started!"
	
	connected_to_server.emit()
	
	is_server = true
	
	online_peer = await _net_protocol.host(port, bind_address, max_clients)
	
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
	
	debug_status_txt = "Connecting to " + address + "..."
	
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
	var port_num = 80
	
	if portsplit.size() > 1:
		port_num = int(portsplit[1])
	
	online_peer = await _net_protocol.join(real_hostname + url_path, port_num)
	
	multiplayer.multiplayer_peer = online_peer
	multiplayer.connected_to_server.connect(_client_connected)
	multiplayer.server_disconnected.connect(_client_disconnected)
	multiplayer.connection_failed.connect(_client_connect_failed)

## Create player node
func create_client(client_id, handshake_data = {}):
	var assign_plrid = 0
	
	# Find available ID to assign
	for i in range(0, max_players):
		if players.get_player_by_index(i) == null:
			assign_plrid = i
			break
	
	_rng.randomize()
	_client_spawner.spawn({client_id = client_id, handshake_data = handshake_data})

@rpc("authority", "call_local", "reliable")
func _net_broadcast_new_player(peer_id):
	var target_plr = players.get_player_by_id(peer_id)
	
	if target_plr:
		player_added.emit(target_plr)

@rpc("authority", "call_local", "reliable")
func _net_broadcast_remove_player(peer_id: int):
	var target_plr = players.get_player_by_id(peer_id)
	
	if target_plr:
		player_count = player_count - 1
		
		if !is_server:
			player_removed.emit(target_plr)
			players._internal_remove_player(peer_id)

@rpc("authority", "call_local", "reliable")
func _net_broadcast_connected_client(peer_id):
	var target_client = players.get_client_by_id(peer_id)
	
	if target_client:
		client_connected.emit(target_client)

@rpc("authority", "call_local", "reliable")
func _net_broadcast_disconnected_client(peer_id):
	var target_client = players.get_client_by_id(peer_id)
	
	if target_client:
		client_count = client_count - 1
		
		if !is_server:
			client_disconnected.emit(target_client)
			players._internal_remove_client(peer_id)

func _client_spawned(data):
	MPIO.plr_id = multiplayer.get_unique_id()
	var client = MPClient.new()
	client.name = str(data.client_id)
	client.client_id = data.client_id
	client.handshake_data = data.handshake_data
	#player.player_index = data.pindex
	client.is_local = false
	#player.device_id = 
	client.mpc = self
	
	client_count = client_count + 1
	
	# If is local player
	if data.client_id == multiplayer.get_unique_id():
		client.is_local = true
		local_client = client
		client._internal_peer = client
		
		debug_status_txt = "Pinging..."
	
	client.set_multiplayer_authority(data.client_id, true)
	
	players._internal_add_client(data.client_id, client)
	
	if is_server:
		rpc("_net_broadcast_new_player", client.client_id)
	
	return client

func _on_local_client_ready():
	EngineDebugger.send_message("mpc:connected", [local_client.client_id])
	
	# Add node that tells what pid session is in scene session tab
	var viewnode = Node.new()
	if is_server:
		viewnode.name = "Server Session"
	else:
		viewnode.name = "Client ID " + str(local_client.client_id)
	get_node("/root").add_child(viewnode, true)
	
	if _debug_bootui:
		_debug_bootui.boot_close()
	
	localclient_node_ready.emit(local_client)
	player_client_ready = true
	debug_status_txt = "Connected!"

func _network_player_connected(player_id):
	pass

func _find_key(dictionary, value):
	var index = dictionary.values().find(value)
	return dictionary.keys()[index]

func _kick_player_handshake(plr_id: int, reason: ConnectionError):
	var player_node = players.get_player_by_id(plr_id)
	
	if !player_node:
		players._internal_remove_player(plr_id)
		
	rpc_id(plr_id, "_handshake_disconnect_peer", reason)

@rpc("authority", "call_local")
func _handshake_disconnect_peer(reason: ConnectionError):
	var reason_str = str(_find_key(ConnectionError, reason))
	MPIO.logerr("Connection Error: " + reason_str)
	online_connected = false
	connection_error.emit(reason)
	disconnected_from_server.emit(reason_str)
	online_peer.close()

func _network_player_disconnected(player_id):
	var target_plr = players.get_player_by_id(player_id)
	
	if target_plr:
		rpc("_net_broadcast_remove_player", player_id)
		player_removed.emit(target_plr)
		target_plr.queue_free()

# Validate network join internal data
func _check_join_internal(handshake_data):
	if !handshake_data.keys().has("_net_join_internal"):
		return false
	
	if !handshake_data._net_join_internal.keys().has("mp_version"):
		return false
	
	return true

## Get Joypad device ID which is currently not used.
func get_available_joypad():
	var joypads = Input.get_connected_joypads()
	
	var result_joypad = null
	
	for i in joypads:
		var check_joypad = func(p: MPPlayer):
			return p.device_id == i
	
		var plr = players.find_player(check_joypad)
		
		if plr == null:
			result_joypad = i
			break
	
	print("result_joypad: ", result_joypad)
	
	return result_joypad

# Init player
@rpc("any_peer", "call_local", "reliable")
func _join_handshake(handshake_data: Dictionary, credentials_data):
	var from_id = multiplayer.get_remote_sender_id()
	
	var existing_client = players.get_client_by_id(from_id)
	
	# Prevent existing client from init
	if existing_client:
		return
	
	if client_count >= max_clients:
		_kick_player_handshake(from_id, ConnectionError.SERVER_FULL)
		return
	
	# Kick if no join data present
	if !_check_join_internal(handshake_data):
		_kick_player_handshake(from_id, ConnectionError.INVALID_HANDSHAKE)
		return
	
	# Check Multiplay version, kick if mismatch
	if handshake_data._net_join_internal.mp_version != MP_VERSION:
		_kick_player_handshake(from_id, ConnectionError.VERSION_MISMATCH)
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
				_kick_player_handshake(from_id, ConnectionError.AUTH_FAILED)
				return
				
			auth_data = auth_result
				
			break
	
	handshake_data._net_internal.auth_data = auth_data
	
	rpc_id(from_id, "_internal_recv_net_data", _net_data)
	
	create_client(from_id, handshake_data)

@rpc("any_peer", "call_local", "reliable")
func _internal_recv_net_data(data):
	debug_status_txt = "Waiting for player node..."
	
	MPIO.plr_id = multiplayer.get_unique_id()
	
	_net_data = data
	if _net_data.current_scene_path != "" and is_server == false:
		_net_load_scene(_net_data.current_scene_path)

func _client_connected():
	debug_status_txt = "Awaiting server data..."
	online_connected = true
	
	# Clear net join internals, this is reserved
	if _join_handshake_data.keys().has("_net_join_internal"):
		_join_handshake_data._net_join_internal = {}
	
	_join_handshake_data._net_join_internal = {
		mp_version = MP_VERSION
	}
	
	rpc_id(1, "_join_handshake", _join_handshake_data, _join_credentials_data)


func _client_disconnected():
	if online_connected:
		disconnected_from_server.emit("Unknown")

func _client_connect_failed():
	disconnected_from_server.emit("Connection Failure")
	connection_error.emit(ConnectionError.CONNECTION_FAILURE)

func _on_local_disconnected(reason):
	debug_status_txt = "Disconnected: " + str(reason)

# Ping player
func _physics_process(delta):
	if started and is_server:
		players._internal_ping()

## Load scene for all players
func load_scene(scene_path: String, respawn_players = true):
	rpc("_net_load_scene", scene_path, respawn_players)

func _check_if_net_from_id(id):
	return multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local", "reliable")
func _net_load_scene(scene_path: String, respawn_players = true):
	_net_data.current_scene_path = scene_path
	
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	if !FileAccess.file_exists(scene_path):
		if !FileAccess.file_exists(scene_path + ".remap"):
			MPIO.logerr("Target scene doesn't exist")
			return
	
	var scene_pack = load(scene_path)
	var scene_node = scene_pack.instantiate()
	
	add_child(scene_node, true)
	
	current_scene = scene_node
	
	if respawn_players:
		players.respawn_node_all()
	
	scene_loaded.emit()
