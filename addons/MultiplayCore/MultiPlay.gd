@icon("res://addons/MultiplayCore/icons/MultiPlayCore.svg")
@tool

extends Node
class_name MultiPlayCore

signal scene_loaded
signal player_connected(player: MPPlayer)
signal player_disconnected(player: MPPlayer)
signal connect_to_server
signal disconnect_from_server
signal swap_changed(to_index: int, old_index: int)

enum PlayMode {
	Online,
	OneScreen,
	Swap,
	Solo
}

enum OneScreenMode {
	ExternalController,
	SameController
}

enum NetworkProtocol {
	WebSockets,
	ENet,
}

@export_subgroup("Network")
@export var network_protocol: NetworkProtocol
@export var port: int = 4200
@export var max_players = 2

@export_subgroup("Spawn Meta")
@export var player_scene: PackedScene
@export var auto_spawn_list: Array[String]

@export_subgroup("Inputs")
@export var swap_input_action = ""

var net_data = {
	current_scene_path = ""
}

var mode = PlayMode.Online
var online_peer: MultiplayerPeer = null

var players: MPPlayersCollection = MPPlayersCollection.new()
var _players_node: Node
var _plr_spawner: MultiplayerSpawner
var started = false
var is_server = false
var local_player: MPPlayer = null
var player_count = 0
var current_scene = null

var current_swap_index = 0

var _join_handshake_data = {}

func _ready():
	if Engine.is_editor_hint():
		return
	_presetup_nodes()

func _init_data():
	started = true
	InputMap.add_action("empty")
	_setup_nodes()

func start_one_screen():
	mode = PlayMode.OneScreen
	_online_host()
	
	for i in range(0, max_players):
		create_player(i, {})

func start_solo():
	mode = PlayMode.Solo
	_online_host()
	
	create_player(1, {})

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
			var old_index = current_swap_index
			current_swap_index = current_swap_index + 1
			if current_swap_index >= player_count:
				current_swap_index = 0
			
			swap_changed.emit(current_swap_index, old_index)
			print("current_swap_index: ", current_swap_index)

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

func start_online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}):
	mode = PlayMode.Online
	_online_host(act_client, act_client_handshake_data)

func start_online_join(url: String, handshake_data: Dictionary = {}):
	mode = PlayMode.Online
	_online_join(url, handshake_data)

func _online_host(act_client: bool = false, act_client_handshake_data: Dictionary = {}):
	_init_data()
	
	is_server = true
	
	if network_protocol == NetworkProtocol.ENet:
		online_peer = ENetMultiplayerPeer.new()
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
	
	online_peer = WebSocketMultiplayerPeer.new()
	online_peer.create_client(url)
	
	multiplayer.multiplayer_peer = online_peer
	multiplayer.connected_to_server.connect(_client_connected)

func create_player(player_id, handshake_data = {}):
	player_count = player_count + 1
	MPIO.logdata("Spawning " + str(player_id))
	_plr_spawner.spawn({player_id = player_id, handshake_data = handshake_data, pindex = player_count})
	player_connected.emit(player_id)

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
	
	
	if data.player_id == multiplayer.get_unique_id():
		player.is_local = true
		local_player = player
		player._internal_peer = player
	
	if player_scene:
		var pscene = player_scene.instantiate()
		player.add_child(pscene, true)
		
		player.player_node = pscene

	player.set_multiplayer_authority(data.player_id, true)
	players._internal_add_player(data.player_id, player)
	
	return player

func _network_player_connected(player_id):
	pass
	#create_player(player_id , {})
	#rpc_id(player_id, "_internal_recv_net_data", net_data)

func _network_player_disconnected(player_id):
	player_count = player_count - 1
	player_disconnected.emit(player_id)

@rpc("any_peer", "call_local", "reliable")
func _join_handshake(handshake_data):
	MPIO.plr_id = multiplayer.get_unique_id()
	MPIO.logdata("Creating Requested of id " + str(multiplayer.get_remote_sender_id()))
	create_player(multiplayer.get_remote_sender_id(), handshake_data)

@rpc("any_peer", "call_local", "reliable")
func _internal_recv_net_data(data):
	MPIO.plr_id = multiplayer.get_unique_id()
	MPIO.logdata("Data received")
	
	net_data = data
	if net_data.current_scene_path != "":
		_net_load_scene(net_data.current_scene_path)
	
	MPIO.logdata("Sending Join Handshake")
	rpc_id(1, "_join_handshake", _join_handshake_data)

func _client_connected():
	rpc_id(1, "_join_handshake", _join_handshake_data)
	#MPIO.logdata("Connection Successful! awaiting Server data...")

func _client_disconnected():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	if started and is_server:
		players._internal_ping()

func load_scene(scene_path: String):
	rpc("_net_load_scene", scene_path)

func _check_if_net_from_id(id):
	return mode == PlayMode.Online and multiplayer.get_remote_sender_id() == id

@rpc("authority", "call_local", "reliable")
func _net_load_scene(scene_path: String):
	net_data.current_scene_path = scene_path
	
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
	
