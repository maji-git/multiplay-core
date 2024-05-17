@tool
@icon("res://addons/MultiplayCore/icons/ENetProtocol.svg")
extends MPNetProtocolBase
## Websocket Network Protocol
class_name ENetProtocol

## Set ENet host compression mode
@export var compression_mode: ENetConnection.CompressionMode = ENetConnection.COMPRESS_ZLIB

func _ready():
	super()

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	var peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	peer.create_server(port, max_players)
	
	peer.host.compress(compression_mode)
	
	return peer

func join(address, port) -> MultiplayerPeer:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	
	peer.host.compress(compression_mode)
	
	return peer
