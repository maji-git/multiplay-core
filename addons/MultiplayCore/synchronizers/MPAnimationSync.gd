@icon("res://addons/MultiplayCore/icons/MPAnimationSync.svg")
extends MPSyncBase
## Network Animation Synchronizer
class_name MPAnimationSync

var _net_current_animation = ""

var _parent: AnimationPlayer = null

func _ready():
	super()
	_parent = get_parent()
	
	if not _parent is AnimationPlayer:
		MPIO.logwarn("MPAnimationSync: Need to be parented to AnimationPlayer.")
		set_process(false)
		return

func _physics_process(delta):
	if !should_sync():
		return
	
	# Only watch for changes if is authority or server
	if check_send_permission():
		if _parent.current_animation != _net_current_animation:
			_net_current_animation = _parent.current_animation
			
			rpc("_recv_play_anim", _net_current_animation, _parent.get_playing_speed())

@rpc("any_peer", "call_local", "unreliable_ordered")
func _recv_play_anim(anim_name: String, anim_speed = 1.0):
	# Allow animation change from authority & server
	if !check_recv_permission():
		return
	
	_net_current_animation = anim_name
	
	if !check_is_local():
		_parent.speed_scale = 1
		if anim_name == "":
			_parent.stop(true)
		else:
			_parent.play(anim_name, -1, anim_speed)
