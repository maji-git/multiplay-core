@tool
@icon("res://addons/MultiplayCore/icons/MPNetProtocolBase.svg")
extends MPExtension
## Base Class for all network protocols
class_name MPNetProtocolBase

var net_protocols = []

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	return OfflineMultiplayerPeer.new()

func join(address, port) -> MultiplayerPeer:
	return OfflineMultiplayerPeer.new()
