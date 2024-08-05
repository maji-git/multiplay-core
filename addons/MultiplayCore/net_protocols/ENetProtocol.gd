@tool
@icon("res://addons/MultiplayCore/icons/ENetProtocol.svg")
extends MPNetProtocolBase
## Websocket Network Protocol
class_name ENetProtocol

## Set ENet host compression mode
@export var compression_mode: ENetConnection.CompressionMode = ENetConnection.COMPRESS_ZLIB

@export_subgroup("Bandwidth")
## Bandwidth In Limit
@export var bandwidth_in_limit: int = 0
## Bandwidth Out Limit
@export var bandwidth_out_limit: int = 0

@export_subgroup("Secure Options")
## Specify if you needs encryption in your ENet
@export var secure: bool
## Secure Private key for server
@export var server_private_key: CryptoKey
## Trusted SSL certificate for server & client
@export var ssl_certificate: X509Certificate

var role = ""

func _ready():
	super()

func _apply_peer_config(peer: ENetMultiplayerPeer, address: String):
	peer.host.compress(compression_mode)
	peer.host.bandwidth_limit(bandwidth_in_limit, bandwidth_out_limit)
	
	if secure:
		if role == "server":
			# Server setup
			peer.host.dtls_server_setup(TLSOptions.server(server_private_key, ssl_certificate))
		else:
			# Client setup
			peer.host.dtls_client_setup(address, TLSOptions.client(ssl_certificate))

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	role = "server"
	var peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	var err = peer.create_server(port, max_players)
	
	_apply_peer_config(peer, bind_ip)
	
	if err != OK:
		MPIO.logerr("Server host failed")
	
	return peer

func join(address, port) -> MultiplayerPeer:
	role = "client"
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	
	_apply_peer_config(peer, address)
	
	if err != OK:
		MPIO.logerr("Client connect failed")
	
	return peer
