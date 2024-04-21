extends Node

@onready var mpc: MultiPlayCore = get_node("../MultiplayCore")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	mpc.host(true, {username = "The Host"})


func _on_button_2_pressed():
	mpc.join("ws://localhost:4200", {username = "The user"})
