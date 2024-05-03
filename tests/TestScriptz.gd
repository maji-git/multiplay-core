extends Node2D

@onready var mpc: MultiPlayCore = get_node("../MultiplayCore")

var oz = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	mpc.PlayMode.OneScreen


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_multiplay_core_player_connected(player):
	if oz == 0:
		#mpc.load_scene("res://another_scene.tscn")
		return
	oz = oz - 1

func _on_multiplay_core_player_disconnected(player: MPPlayer):
	print(player.player_id, " disconnected")
