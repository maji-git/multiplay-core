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
	
	var url = ""
	
	var ip_split = Array(address.split("/"))
	var hostname = ip_split[0]
	
	ip_split.pop_front()
	
	var url_path = "/".join(PackedStringArray(ip_split))
	
	var port_string = ""
	
	if port:
		port_string = ":" + str(port)
	
	url = protocol + "://" + hostname + port_string + "/" + url_path
	
	var peer = WebSocketMultiplayerPeer.new()
	peer.create_client(url, client_tls_options)
	
	return peer