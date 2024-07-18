@icon("res://addons/MultiplayCore/icons/MPPeersCollection.svg")

extends MPBase
## Collection of players
class_name MPPlayersCollection

## Dictionary containing [MPPlayer]
var players: Dictionary = {}

## Dictionary containing [MPClient]
var clients: Dictionary = {}

## Get player by ID
func get_player_by_id(player_id: int) -> MPPlayer:
	if players.keys().has(player_id):
		if is_instance_valid(players[player_id]):
			return players[player_id]
	return null

## Get client by ID
func get_client_by_id(client_id: int) -> MPPlayer:
	if clients.keys().has(client_id):
		if is_instance_valid(players[client_id]):
			return players[client_id]
	return null

## Find player that matches the specific callable
func find_player(callable: Callable) -> MPPlayer:
	for p in players.values():
		if p and is_instance_valid(p) and callable.call(p):
			return p
	return null

## Get player by index
func get_player_by_index(player_index: int) -> MPPlayer:
	for p in players.values():
		if p and is_instance_valid(p) and p.player_index == player_index:
			return p
	
	return null

## Get all players
func get_players() -> Dictionary:
	return players

func _internal_add_player(player_id, player: MPPlayer):
	players[player_id] = player

func _internal_remove_player(player_id):
	players[player_id] = null

func _internal_add_client(player_id, client: MPClient):
	clients[player_id] = client

func _internal_remove_client(player_id):
	clients[player_id] = null

func _get_unique_id():
	return 

func _get_player_peer_ids():
	var p = multiplayer.get_peers()
	p.append(1)
	return p

func _internal_ping():
	for p in clients.values():
		if p and is_instance_valid(p) and p.client_id in _get_player_peer_ids():
			p.rpc("_internal_ping", Time.get_unix_time_from_system())

## Despawn all player's node
func despawn_node_all():
	for p in players.values():
		if is_instance_valid(p):
			p.despawn_node()

## Respawn all player's node
func respawn_node_all():
	for p in players.values():
		if is_instance_valid(p):
			p.respawn_node()

## Spawn all player's node
func spawn_node_all():
	for p in players.values():
		if is_instance_valid(p):
			p.spawn_node()
