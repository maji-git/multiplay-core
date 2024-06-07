@tool
@icon("res://addons/MultiplayCore/icons/WebSocketNetProtocol.svg")
extends MPNetProtocolBase
## Websocket Network Protocol
class_name WebSocketNetProtocol

## Specify if you needs encryption in your web socket
@export var secure: bool
@export_subgroup("Secure Options")

## Secure Private key for server
@export var server_private_key: CryptoKey
## Trusted SSL certificate for server & client
@export var ssl_certificate: X509Certificate

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	var server_tls_options = null
	
	if secure and server_private_key and ssl_certificate:
		server_tls_options = TLSOptions.server(server_private_key, ssl_certificate)
	
	var peer = WebSocketMultiplayerPeer.new()
	peer.create_server(port, bind_ip, server_tls_options)
	
	return peer

func join(address, port) -> MultiplayerPeer:
	var client_tls_options = null
	
	var protocol = "ws"
	
	if secure:
		if ssl_certificate:
			client_tls_options = TLSOptions.client(ssl_certificate)
		protocol = "wss"
	
	var portstr = ""
	
	if port:
		portstr = ":" + str(port)
	
	var url = protocol + "://" + address + portstr
	
	var peer = WebSocketMultiplayerPeer.new()
	peer.create_client(url, client_tls_options)
	
	return peer
