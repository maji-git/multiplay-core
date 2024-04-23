extends Area2D

@export var scene_to_load = ""

# Called when the node enters the scene tree for the first time.
func _ready():
	body_entered.connect(_body_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _body_entered(body: Node2D):
	if !MPIO.mpc.is_server:
		return
	
	if body.is_in_group("player"):
		MPIO.mpc.load_scene(scene_to_load)
