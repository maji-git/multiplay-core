extends Node

var auth: MPAuth

# Called when the node enters the scene tree for the first time.
func _ready():
	auth = get_parent()
	
	auth.authenticate_function = _auth_check

func _auth_check(plr_id, credentials_data, handshake_data):
	print(credentials_data)
	if !credentials_data.keys().has("password"):
		return false
	return {username = credentials_data.password }

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
