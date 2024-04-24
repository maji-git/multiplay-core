# meta-name: MultiPlay Authenticator
# meta-description: Empty MultiPlay Authenticator

extends Node

# Assign this variable to MPAuth node
@export var auth: MPAuth

func _ready():
	auth.authenticate_function = _auth_check

func _auth_check(plr_id: int, credentials_data: Dictionary, handshake_data: Dictionary):
	# Return authentication data, otherwise if failed, return false.
	return {}
