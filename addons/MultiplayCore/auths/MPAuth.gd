@icon("res://addons/MultiplayCore/icons/MPAuth.svg")
@tool

extends MPExtension
## Middleware to check player's credentials before connecting. 
## @experimental
class_name MPAuth

## Authenticate function, this must be set.
##
## Callable will be called will the following args:[br]
## [code]plr_id[/code] The player id[br]
## [code]credentials_data[/code] Credentials data from the player[br]
## [code]handshake_data[/code] Handshake data from the player[br]
##
## Return false if fail, otherwise return the data
##
var authenticate_function: Callable

func authenticate(plr_id, credentials_data, handshake_data):
	if !authenticate_function:
		MPIO.logwarn("authenticate: authenticate_function has not been set. Allowing user in by default.")
		return true
	
	var result = await authenticate_function.call(plr_id, credentials_data, handshake_data)
	return result
