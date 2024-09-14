extends Node2D

@onready var mpc: MultiPlayCore = get_node("../MultiplayCore")

var oz = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_multiplay_core_player_connected(player):
	print(player, " joined")
	oz = oz + 1
	
	if oz == 1:
		print("LOAD SCENE PLEASE")
		mpc.load_scene("res://tests/another_scene.tscn")
		return

func _on_multiplay_core_player_disconnected(player: MPPlayer):
	print(player.player_id, " disconnected")
