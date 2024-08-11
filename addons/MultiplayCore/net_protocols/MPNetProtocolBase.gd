@tool
@icon("res://addons/MultiplayCore/icons/MPNetProtocolBase.svg")
extends MPExtension
## Base Class for all network protocols
class_name MPNetProtocolBase

var net_protocols = []

func _ready():
	super()
	mpc.register_net_extension(self)

## Debug URL Override
func _override_debug_url(bind_ip: String, port: int):
	return null

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	return OfflineMultiplayerPeer.new()

## Join Function
func join(address, port) -> MultiplayerPeer:
	return OfflineMultiplayerPeer.new()
