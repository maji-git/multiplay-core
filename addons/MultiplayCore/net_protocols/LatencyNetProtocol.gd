@tool
@icon("res://addons/MultiplayCore/icons/LatencyNetProtocol.svg")
extends ENetProtocol
## Network Protocol for simulating network latency, based on ENet/UDP. Intended for debuging purposes.
class_name LatencyNetProtocol

# Thanks to kraybit for the UDP latency simulation
# https://forum.godotengine.org/t/how-i-can-simulate-a-network-latency-and-packet-loss-between-client-and-server-peers/25012

## Simulate Network Latency in Microseconds
@export_range(0, 5000) var simulate_latency_ms : int = 100
## Simulate Chance of Network Loss
@export_range(0, 0.5) var simulate_loss : float = 0

var _virtual_port = -1
var _true_server_port = -1

var _vserver_peer : PacketPeerUDP
var _vserver_has_dest_address : bool = false
var _vserver_first_client_port : int = -1
var _vclient_peer : PacketPeerUDP

func _ready():
	super()
	if Engine.is_editor_hint():
		return
	
	_true_server_port = mpc.port
	_virtual_port = mpc.port + 1

	_vserver_peer = PacketPeerUDP.new()
	_vserver_peer.bind(_virtual_port, "127.0.0.1")
	
	_vclient_peer = PacketPeerUDP.new()
	_vclient_peer.set_dest_address("127.0.0.1", mpc.port)

	if not OS.is_debug_build():
		MPIO.logwarn("LatencyNetProtocol is currently in use! Please change network protocol in the production build!")
		simulate_latency_ms = 0
		simulate_loss = 0

## Host function
func host(port, bind_ip, max_players) -> MultiplayerPeer:
	return super(port, bind_ip, max_players)

func join(address, port) -> MultiplayerPeer:
	return super("127.0.0.1", _virtual_port)

class QueueEntry :
	var byte_array : PackedByteArray
	var qued_at : int
	
	func _init(packet:PackedByteArray, time_now:int) :
		self.byte_array = packet
		self.qued_at = time_now

var _client_to_server_queue : Array[QueueEntry]
var _server_to_client_queue : Array[QueueEntry]

func _process(_delta : float) -> void :
	if Engine.is_editor_hint():
		return
	var now : int = Time.get_ticks_msec()
	var send_at_ms = now - simulate_latency_ms
	
	# Handle packets Client -> Server
	while _vserver_peer.get_available_packet_count() > 0 :
		var packet = _vserver_peer.get_packet()
		var err = _vserver_peer.get_packet_error()
		if err != OK :
			push_error("DebugUDPLagger : Incoming packet error : ", err)
			continue
			
		var from_port = _vserver_peer.get_packet_port()
		
		if not _vserver_has_dest_address : 
			# Assume the first who send a packet to us is the True Client
			_vserver_peer.set_dest_address("127.0.0.1", from_port)
			_vserver_first_client_port = from_port
			_vserver_has_dest_address = true
		elif _vserver_first_client_port != from_port :
			push_warning("DebugUDPLagger : VServer got packet from unknown port, ignored.")
			continue
		
		_client_to_server_queue.push_back(QueueEntry.new(packet, now))
	
	_process_queue(_client_to_server_queue, _vclient_peer, send_at_ms)
	
	# Ignore check for any incoming packets from the true server
	if not _vserver_has_dest_address :
		return
	
	# Handle packets Server -> Client
	while _vclient_peer.get_available_packet_count() > 0 :
		var packet = _vclient_peer.get_packet()
		var err = _vclient_peer.get_packet_error()
		if err != OK :
			push_error("DebugUDPLagger : Incoming packet error : ", err)
			continue
		
		var from_port = _vclient_peer.get_packet_port()
		if from_port != _true_server_port :
			push_warning("DebugUDPLagger : VClient got packet from unknown port, ignored.")
			continue
		
		_server_to_client_queue.push_back(QueueEntry.new(packet, now))

	_process_queue(_server_to_client_queue, _vserver_peer, send_at_ms)
	
	
func _process_queue(que : Array[QueueEntry], to_peer : PacketPeerUDP, send_at_ms : int) :
	while not que.is_empty() :
		var front = que.front()
		if send_at_ms >= front.qued_at :
			if simulate_loss <= 0  ||  randf() >= simulate_loss:
				to_peer.put_packet(front.byte_array)
			que.pop_front()
		else :
			break
