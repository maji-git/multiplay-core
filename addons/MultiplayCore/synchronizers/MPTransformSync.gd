@icon("res://addons/MultiplayCore/icons/MPTransformSync.svg")
extends MPSyncBase
## Network Transform Synchronizer
class_name MPTransformSync

## Enable lerp for sync?
@export var lerp_enabled: bool = true
## Determines lerp speed
@export var lerp_speed: int = 20

@export_subgroup("Sync Transform")
## Determines if position will be sync
@export var sync_position: bool = true
## Determines if rotation will be sync
@export var sync_rotation: bool = true
## Determines if scale will be sync
@export var sync_scale: bool = false

@export_subgroup("Sync Sensitivity")
## Determines the sync sensitivity of position
@export var position_sensitivity: float = 0.01
## Determines the sync sensitivity of rotation
@export var rotation_sensitivity: float = 0.01
## Determines the sync sensitivity of scale
@export var scale_sensitivity: float = 0.01

var _net_position = null
var _net_rotation = null
var _net_scale = null

var _old_position = null
var _old_rotation = null
var _old_scale = null

var _parent = null
var _sync_type = ""

func _ready():
	super()
	_parent = get_parent()
	
	if _parent is Node2D:
		_sync_type = "2d"
	elif _parent is Node3D:
		_sync_type = "3d"
	
	_net_position = _parent.position
	_net_rotation = _parent.rotation
	_net_scale = _parent.scale
	
	# Sync when new player joins
	if should_sync() and check_send_permission():
		MPIO.mpc.player_connected.connect(_on_player_connected)

func _on_player_connected(plr: MPPlayer):
	if sync_position:
		rpc_id(plr.player_id, "_recv_transform_reliable", "pos", _parent.position)
	
	if sync_rotation:
		rpc_id(plr.player_id, "_recv_transform_reliable", "rot", _parent.rotation)
	
	if sync_scale:
		rpc_id(plr.player_id, "_recv_transform_reliable", "scl", _parent.scale)

func _physics_process(delta):
	if !should_sync():
		return
	# Only watch for changes if is authority or server
	if check_send_permission():
		# Sync Position
		if sync_position and (_parent.position - _net_position).length() > position_sensitivity:
			rpc("_recv_transform", "pos", _parent.position)
	
		# Sync Rotation
		if sync_rotation:
			if _sync_type == "2d" and _parent.rotation - _net_rotation > rotation_sensitivity:
				rpc("_recv_transform", "rot", _parent.rotation)
			
			if _sync_type == "3d" and (_parent.rotation - _net_rotation).length() > rotation_sensitivity:
				rpc("_recv_transform", "rot", _parent.rotation)
		
		# Sync Scale
		if sync_scale and (_parent.scale - _net_scale).length() > scale_sensitivity:
			rpc("_recv_transform", "scl", _parent.scale)
	else:
		if lerp_enabled:
			# Sync all transforms w/lerp
			if sync_position:
				_parent.position = _parent.position.lerp(_net_position, delta * lerp_speed)
			if sync_rotation:
				_parent.rotation = lerp(_parent.rotation, _net_rotation, delta * lerp_speed)
			if sync_scale:
				_parent.scale = _parent.scale.lerp(_net_scale, delta * lerp_speed)
		else:
			# Sync all transforms
			if sync_position:
				_parent.position = _net_position
			if sync_rotation:
				_parent.rotation = _net_rotation
			if sync_scale:
				_parent.scale = _net_scale

## Set position of the 2D node, Server only.
func set_position_2d(to: Vector2):
	rpc("_recv_transform", "pos", to, true)

## Set rotation of the 2D node, Server only.
func set_rotation_2d(to: float):
	rpc("_recv_transform", "rot", to, true)

## Set scale of the 2D node, Server only.
func set_scale_2d(to: Vector2):
	rpc("_recv_transform", "scl", to, true)

## Set position of the 3D node, Server only.
func set_position_3d(to: Vector3):
	rpc("_recv_transform", "pos", to, true)

## Set rotation of the 3D node, Server only.
func set_rotation_3d(to: Vector3):
	rpc("_recv_transform", "rot", to, true)

## Set scale of the 3D node, Server only.
func set_scale_3d(to: Vector3):
	rpc("_recv_transform", "scl", to, true)

@rpc("any_peer", "call_local", "unreliable_ordered")
func _recv_transform(field: String, set_to = null, is_server_cmd = false):
	# Allow transform change from authority & server
	if !check_recv_permission(is_server_cmd):
		return
	
	if !is_server_cmd:
		if field == "pos":
			_net_position = set_to
		elif field == "rot":
			_net_rotation = set_to
		elif field == "scl":
			_net_scale = set_to
	else:
		if field == "pos":
			_parent.position = set_to
		elif field == "rot":
			_parent.rotation = set_to
		elif field == "scl":
			_parent.scale = set_to

@rpc("any_peer", "call_local", "reliable")
func _recv_transform_reliable(field: String, set_to = null, is_server_cmd = false):
	_recv_transform(field, set_to, is_server_cmd)
