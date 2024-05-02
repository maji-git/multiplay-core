@tool
@icon("res://addons/MultiplayCore/icons/LatencyNetProtocol.svg")
extends MPNetProtocolBase
## Network Protocol for simulating network latency, based on ENet/UDP. Intended for debuging purposes.
class_name LatencyNetProtocol

# Thanks to kraybit for the UDP latency simulation
# https://forum.godotengine.org/t/how-i-can-simulate-a-network-latency-and-packet-loss-between-client-and-server-peers/25012

## Simulate Network Latency in Microseconds
@export_range(0, 5000) var simulate_latency_ms : int = 100
## Simulate Chance of Network Loss
@export_range(0, 0.5) var simulate_loss : float = 0

var virtual_port = -1
var true_server_port = -1

var vserver_peer : PacketPeerUDP
var vserver_has_dest_address : bool = false
var vserver_first_client_port : int = -1
var vclient_peer : PacketPeerUDP

func _ready():
	super()
	if Engine.is_editor_hint():
		return
	
	true_server_port = mpc.port
	virtual_port = mpc.port + 1

	vserver_peer = PacketPeerUDP.new()
	vserver_peer.bind(virtual_port, "127.0.0.1")
	
	vclient_peer = PacketPeerUDP.new()
	vclient_peer.set_dest_address("127.0.0.1", mpc.port)

	if not OS.is_debug_build():
		MPIO.logwarn("LatencyNetProtocol is currently in use! Please change network protocol in the production build!")
		simulate_latency_ms = 0
		simulate_loss = 0

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	var peer = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_ip)
	peer.create_server(port, max_players)
	
	return peer

func join(address, port) -> MultiplayerPeer:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client("127.0.0.1", virtual_port)
	
	return peer

class QueueEntry :
	var byte_array : PackedByteArray
	var qued_at : int
	
	func _init(packet:PackedByteArray, time_now:int) :
		self.byte_array = packet
		self.qued_at = time_now

var client_to_server_queue : Array[QueueEntry]
var server_to_client_queue : Array[QueueEntry]

func _process(_delta : float) -> void :
	if Engine.is_editor_hint():
		return
	var now : int = Time.get_ticks_msec()
	var send_at_ms = now - simulate_latency_ms
	
	# Handle packets Client -> Server
	while vserver_peer.get_available_packet_count() > 0 :
		var packet = vserver_peer.get_packet()
		var err = vserver_peer.get_packet_error()
		if err != OK :
			push_error("DebugUDPLagger : Incoming packet error : ", err)
			continue
			
		var from_port = vserver_peer.get_packet_port()
		
		if not vserver_has_dest_address : 
			# Assume the first who send a packet to us is the True Client
			vserver_peer.set_dest_address("127.0.0.1", from_port)
			vserver_first_client_port = from_port
			vserver_has_dest_address = true
		elif vserver_first_client_port != from_port :
			push_warning("DebugUDPLagger : VServer got packet from unknown port, ignored.")
			continue
		
		client_to_server_queue.push_back(QueueEntry.new(packet, now))
	
	_process_queue(client_to_server_queue, vclient_peer, send_at_ms)
	
	# Ignore check for any incoming packets from the true server
	if not vserver_has_dest_address :
		return
	
	# Handle packets Server -> Client
	while vclient_peer.get_available_packet_count() > 0 :
		var packet = vclient_peer.get_packet()
		var err = vclient_peer.get_packet_error()
		if err != OK :
			push_error("DebugUDPLagger : Incoming packet error : ", err)
			continue
		
		var from_port = vclient_peer.get_packet_port()
		if from_port != true_server_port :
			push_warning("DebugUDPLagger : VClient got packet from unknown port, ignored.")
			continue
		
		server_to_client_queue.push_back(QueueEntry.new(packet, now))

	_process_queue(server_to_client_queue, vserver_peer, send_at_ms)
	
	
func _process_queue(que : Array[QueueEntry], to_peer : PacketPeerUDP, send_at_ms : int) :
	while not que.is_empty() :
		var front = que.front()
		if send_at_ms >= front.qued_at :
			if simulate_loss <= 0  ||  randf() >= simulate_loss:
				to_peer.put_packet(front.byte_array)
			que.pop_front()
		else :
			break
