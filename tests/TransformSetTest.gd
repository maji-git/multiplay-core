extends Area2D

func _ready():
	body_entered.connect(_body_entered)

func _body_entered(body: Node2D):
	# Ignore if server, set transform is only callable in the server
	if !MPIO.mpc.is_server:
		return
	
	# If body is player
	if body.is_in_group("player"):
		body.get_node("MPTransformSync").set_position_2d(Vector2(0,5))
