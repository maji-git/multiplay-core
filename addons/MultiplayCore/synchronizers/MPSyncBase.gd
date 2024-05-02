@icon("res://addons/MultiplayCore/icons/MPSyncBase.svg")
extends MPBase
## Base class of Network Synchronizers
class_name MPSyncBase

## Check network send permission
func check_send_permission():
	return multiplayer.get_unique_id() == get_multiplayer_authority()

## Check receive permission
func check_recv_permission(is_server_cmd: bool = false):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id != get_multiplayer_authority():
		if is_server_cmd and sender_id == 1:
			return true
		else:
			return false
	return true
