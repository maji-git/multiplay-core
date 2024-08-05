@icon("res://addons/MultiplayCore/icons/MPPeersCollection.svg")

extends MPBase
## Collection of players
class_name MPPlayersCollection

## Dictionary containing [MPPlayer]
var players: Dictionary = {}

## Get player by ID
func get_player_by_id(player_id: int) -> MPPlayer:
	if players.keys().has(player_id):
		return players[player_id]
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
	players.erase(player_id)

func _internal_clear_all():
	players.clear()

func _get_player_peer_ids():
	var p = multiplayer.get_peers()
	p.append(1)
	return p

func _internal_ping():
	for p in players.values():
		if p and is_instance_valid(p) and p.player_id in _get_player_peer_ids():
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
