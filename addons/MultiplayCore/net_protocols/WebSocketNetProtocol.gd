@tool
@icon("res://addons/MultiplayCore/icons/WebSocketNetProtocol.svg")
extends MPNetProtocolBase
## Websocket Network Protocol
class_name WebSocketNetProtocol

@export var secure: bool
@export_subgroup("Secure Options")
@export var server_private_key: CryptoKey
@export var ssl_certificate: X509Certificate

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	var server_tls_options = null
	
	if secure:
		server_tls_options = TLSOptions.server(server_private_key, ssl_certificate)
	
	var peer = WebSocketMultiplayerPeer.new()
	peer.create_server(port, bind_ip, server_tls_options)
	
	return peer

func join(address, port) -> MultiplayerPeer:
	var client_tls_options = null
	
	var protocol = "ws"
	
	if secure:
		client_tls_options = TLSOptions.client(ssl_certificate)
		protocol = "wss"
	
	var url = protocol + "://" + address + str(port)
	
	var peer = WebSocketMultiplayerPeer.new()
	peer.create_client(url, client_tls_options)
	
	return peer
