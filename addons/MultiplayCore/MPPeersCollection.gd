extends Node
class_name MPPlayersCollection

var players = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func get_player_by_id(player_id: int):
	if players.keys().has(player_id):
		return players[player_id]
	return null

func get_player_by_index(player_index: int):
	for p in players.values():
		if p.player_index == player_index:
			return p
	
	return null

func get_players():
	return players

func _internal_add_player(player_id, player: MPPlayer):
	players[player_id] = player

func _internal_ping():
	for p in players.values():
		p.rpc("_internal_ping", Time.get_unix_time_from_system())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
