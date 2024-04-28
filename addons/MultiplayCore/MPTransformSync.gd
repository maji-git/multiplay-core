@icon("res://addons/MultiplayCore/icons/MPTransformSync.svg")
extends MPBase
## Network Transform Synchronizer
class_name MPTransformSync

## Enable lerp for sync?
@export var lerp_enabled = true
## Determines lerp speed
@export var lerp_speed = 20

@export_subgroup("Sync Transform")
## Determines if position will be sync
@export var sync_position = true
## Determines if rotation will be sync
@export var sync_rotation = true
## Determines if scale will be sync
@export var sync_scale = false

@export_subgroup("Sync Sensitivity")
## Determines the sync sensitivity of position
@export var position_sensitivity = 0.01
## Determines the sync sensitivity of rotation
@export var rotation_sensitivity = 0.01
## Determines the sync sensitivity of scale
@export var scale_sensitivity = 0.01

var _net_position = null
var _net_rotation = null
var _net_scale = null

var _old_position = null
var _old_rotation = null
var _old_scale = null

var _parent = null
var _sync_type = ""

func _ready():
	_parent = get_parent()
	
	if _parent is Node2D:
		_sync_type = "2d"
	elif _parent is Node3D:
		_sync_type = "3d"
	
	_net_position = _parent.position
	_net_rotation = _parent.rotation
	_net_scale = _parent.scale

func _physics_process(delta):
	# Only watch for changes if is authority or server
	if multiplayer.get_unique_id() == get_multiplayer_authority() || multiplayer.get_unique_id() == 1:
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
		
		# Sync all transforms
		if sync_position:
			_parent.position = _net_position
		if sync_rotation:
			_parent.rotation = _net_rotation
		if sync_scale:
			_parent.scale = _net_scale
	else:
		if lerp_enabled:
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

@rpc("any_peer", "call_local", "unreliable_ordered")
func _recv_transform(field: String, set_to):
	# Allow transform change from authority & server
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority() || multiplayer.get_remote_sender_id() == 1:
		return
	if field == "pos":
		_net_position = set_to
	elif field == "rot":
		_net_rotation = set_to
	elif field == "scl":
		_net_scale = set_to
