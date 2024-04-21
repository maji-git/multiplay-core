extends Node2D

@onready var mpc: MultiPlayCore = get_node("../MultiplayCore")

var oz = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_multiplay_core_player_connected(player):
	if oz:
		return
	oz = true
	#mpc.load_scene("res://another_scene.tscn")
	

func _on_multiplay_core_player_disconnected(player):
	pass # Replace with function body.
