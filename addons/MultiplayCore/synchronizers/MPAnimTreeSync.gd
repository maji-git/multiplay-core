@icon("res://addons/MultiplayCore/icons/MPAnimTreeSync.svg")
extends MPSyncBase
## Network Animation Tree Synchronizer
class_name MPAnimTreeSync

var _parent: AnimationTree = null

var property_list = []

func _ready():
	super()
	_parent = get_parent()
	
	if not _parent is AnimationTree:
		MPIO.logwarn("MPAnimationSync: Need to be parented to AnimationTree.")
		set_process(false)
		return
	
	for p in _parent.get_property_list():
		if p.name.begins_with("parameters/"):
			property_list.append({
				data_type = p.class_name,
				path = p.name,
				obj = _parent.get(p.name),
				data = {
					temp_current_node = "",
					one_shot_active = false,
					old_val = null
				}
			})

func _physics_process(delta):
	if !should_sync():
		return
	
	# Only watch for changes if is authority or server
	if check_send_permission():
		for p in property_list:
			var obj = p.obj
			var path: String = p.path

			if obj is AnimationNodeStateMachinePlayback:
				# Sync state machine
				var current_anim = obj.get_current_node()
				
				if p.data.temp_current_node != current_anim:
					p.data.temp_current_node = current_anim
					
					rpc("_recv_play_anim_nsmp", p.path, current_anim)
			elif path.ends_with("/active"):
				# Sync one shot animations
				var val = _parent.get(path)
				
				if val:
					if !p.data.one_shot_active:
						p.data.one_shot_active = true
						rpc("_recv_oneshot_anim", path.trim_suffix("/active"))
				else:
					if p.data.one_shot_active:
						p.data.one_shot_active = false
			else:
				# Ignore time parameters
				if path.ends_with("/time"):
					continue
				
				# Sync any properties
				var val = _parent.get(path)
				
				var do_sync = false
				# Check for types
				if p.data.old_val == null:
					do_sync = true
				elif typeof(val) == typeof(p.data.old_val):
					if val != p.data.old_val:
						do_sync = true
				
				if do_sync:
					p.data.old_val = val
						
					rpc("_recv_prop_sync", path, val)


# Handle play animation for AnimationNodeStateMachinePlayback
@rpc("any_peer", "call_local", "unreliable_ordered")
func _recv_play_anim_nsmp(property_path: String, travel_to: String):
	# Allow animation change from authority & server
	if !check_recv_permission():
		return
	
	if !check_is_local():
		var anim_playback = _parent.get(property_path)
		
		if anim_playback is AnimationNodeStateMachinePlayback:
			if travel_to == "":
				anim_playback.stop()
			else:
				anim_playback.travel(travel_to)

# Handle play animation for One Shot properties
@rpc("any_peer", "call_local", "unreliable_ordered")
func _recv_oneshot_anim(property_path: String):
	# Allow animation change from authority & server
	if !check_recv_permission():
		return
	
	if !check_is_local():
		_parent.set(property_path + "/request", true)

# Handle property sync
@rpc("any_peer", "call_local", "unreliable_ordered")
func _recv_prop_sync(property_path: String, value):
	# Allow animation change from authority & server
	if !check_recv_permission():
		return
	
	if !check_is_local():
		_parent.set(property_path, value)
