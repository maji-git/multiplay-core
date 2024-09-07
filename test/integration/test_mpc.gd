extends GutTest

var mpc: MultiPlayCore
var enet: ENetProtocol
var mpcenv = preload("res://test/resources/mpc_testenv.tscn")
var viewport_3d: SubViewport

func before_all():
	DebugBridge.init()
	await DebugBridge.msgcap_initd
	
	mpc = mpcenv.instantiate()
	get_node("/root").add_child(mpc, true)
	MPIO.mpc = mpc
	
	viewport_3d = mpc.get_node("3dv/v")
	#await delay(0.3)
	
	#await mpc.ready
	if DebugBridge.role == "server":
		mpc.start_online_host(true)
	
	EngineDebugger.send_message("mpc_test:session_complete", [])
	await DebugBridge.msgcap_ready

func delay(sec):
	await get_tree().create_timer(sec).timeout

func join_host():
	mpc.start_online_join("127.0.0.1:" + str(mpc.port))
	#await mpc.connected_to_server
	await delay(1)

func disconnect_from_host():
	if is_instance_valid(mpc) and mpc.local_player and is_instance_valid(mpc.local_player):
		mpc.local_player.disconnect_player()
		await delay(0.3)

func after_each():
	if DebugBridge.role == "client":
		await disconnect_from_host()
	EngineDebugger.send_message("mpc_test:session_complete", [])
	await DebugBridge.msgcap_ready

func test_connectivity():
	if DebugBridge.role != "client":
		pass_test("client only test")
		return
	await join_host()
	
	assert_eq(mpc.online_connected, true, "Online Connected")
	assert_ne(mpc.local_player, null, "local_player not null")
	assert_ne(mpc.local_player._internal_peer, null, "_internal_peer not null")
	assert_ne(mpc.online_peer, null, "online_peer not null")

func test_disconnect():
	if DebugBridge.role != "client":
		pass_test("client only test")
		return
	#assert_ne(mpc.local_player._internal_peer, null, "internal peer not null")
	await join_host()
	await delay(1)
	await disconnect_from_host()
	assert_eq(mpc.local_player, null, "local_player null")

func test_transformsync_spawn_sync_2d():
	var test_transform = preload("res://test/resources/test_transform_2d.tscn").instantiate()
	test_transform.set_multiplayer_authority(1)
	mpc.add_child(test_transform, true)
	
	if DebugBridge.role == "server":
		test_transform.position = Vector2(200, 0)
		test_transform.rotation = 45
		test_transform.scale = Vector2(2, 2)
		pass_test("done")
	else:
		await delay(0.5)
		await join_host()
		await delay(1)
		assert_eq(round(test_transform.position.x), 200.0, "2D Position Spawn Check")
		assert_eq(round(test_transform.rotation), 45.0, "2D Rotation Spawn Check")
		assert_eq(round(test_transform.scale.x), 2.0, "2D Scale Spawn Check")

func test_transformsync_spawn_sync_3d():
	var test_transform = preload("res://test/resources/test_transform_3d.tscn").instantiate()
	test_transform.set_multiplayer_authority(1)
	viewport_3d.add_child(test_transform, true)
	
	if DebugBridge.role == "server":
		test_transform.position = Vector3(0, 1, 0)
		test_transform.rotation_degrees = Vector3(5, 5, 5)
		test_transform.scale = Vector3(2, 2, 2)
		pass_test("done")
	else:
		await delay(0.5)
		await join_host()
		await delay(1)
		assert_eq(round(test_transform.position.y), 1.0, "3D Position Spawn Check")
		assert_eq(round(test_transform.rotation_degrees.x), 5.0, "3D Rotation Spawn Check")
		assert_eq(round(test_transform.scale.x), 2.0, "3D Scale Spawn Check")

func test_animsync_oneshot():
	var test_animplay = preload("res://test/resources/test_anim_play.tscn").instantiate()
	test_animplay.set_multiplayer_authority(1)
	add_child_autofree(test_animplay, true)
	
	var anim: AnimationPlayer = test_animplay.get_node("AnimationPlayer")
	
	await delay(1)
	
	if DebugBridge.role == "server":
		await delay(0.5)
		
		anim.play("anim_oneshot")
		pass_test("done")
	else:
		await join_host()
		await delay(0.3)
		
		assert_eq(anim.current_animation, "anim_oneshot", "Animation Oneshot")

func test_animsync_loop():
	var test_animplay = preload("res://test/resources/test_anim_play.tscn").instantiate()
	test_animplay.set_multiplayer_authority(1)
	add_child_autofree(test_animplay, true)
	
	var anim: AnimationPlayer = test_animplay.get_node("AnimationPlayer")
	
	await delay(1)
	
	if DebugBridge.role == "server":
		await delay(0.5)
		
		anim.play("anim_loop")
		pass_test("done")
	else:
		await join_host()
		await delay(0.4)
		
		assert_eq(anim.current_animation, "anim_loop", "Animation Looped")

func test_animtree_sync():
	var test_animtree = preload("res://test/resources/test_animtree.tscn").instantiate()
	test_animtree.set_multiplayer_authority(1, true)
	mpc.add_child(test_animtree, true)
	
	var anim: AnimationTree = test_animtree.get_node("AnimationTree")
	
	await delay(1)
	
	if DebugBridge.role == "server":
		await delay(0.5)
		
		anim.set("parameters/Add2/add_amount", 1)
		anim.set("parameters/Add3/add_amount", 1)
		anim.set("parameters/Blend2/blend_amount", 1)
		anim.set("parameters/Blend3/blend_amount", 1)
		anim.set("parameters/BlendSpace1D/blend_position", 1)
		anim.set("parameters/BlendSpace2D/blend_position", Vector2(1,1))
		anim.set("parameters/StateMachine/conditions/sync1", true)
		pass_test("done")
	else:
		await join_host()
		await delay(0.4)
		
		assert_eq(anim.get("parameters/Add2/add_amount"), 1, "Add2")
		assert_eq(anim.get("parameters/Add3/add_amount"), 1, "Add3")
		assert_eq(anim.get("parameters/Blend2/blend_amount"), 1, "Blend2")
		assert_eq(anim.get("parameters/Blend3/blend_amount"), 1, "Blend3")
		assert_eq(anim.get("parameters/BlendSpace1D/blend_position"), 1, "BlendSpace1D")
		assert_eq(anim.get("parameters/BlendSpace2D/blend_position"), Vector2(1,1), "BlendSpace2D")
		assert_eq(anim.get("parameters/StateMachine/conditions/sync1"), true, "State Machine")

func test_signals():
	
	if DebugBridge.role == "server":
		watch_signals(mpc)
		await delay(1)
		assert_signal_emitted(mpc, "player_connected", "Player Connected Signal")
		await delay(1.6)
		assert_signal_emitted(mpc, "player_disconnected", "Player Disconnected Signal")
	elif DebugBridge.role == "client":
		watch_signals(mpc)
		await join_host()
		await delay(1)
		assert_signal_emitted(mpc, "connected_to_server", "Connected to server")
		mpc.local_player.disconnect_player()
		await delay(1)
		assert_signal_emitted(mpc, "disconnected_from_server")

func test_server_close():
	if DebugBridge.role == "server":
		await delay(1.5)
		mpc.close_server()
		assert_eq(mpc.online_connected, false, "Online Disconnected")
	elif DebugBridge.role == "client":
		await join_host()
		await delay(1)
		assert_eq(mpc.online_connected, false, "Online Disconnected")
	"""
	await join_host()
	
	assert_eq(mpc.online_connected, true, "Online Connected")
	assert_ne(mpc.local_player, null, "local_player not null")
	assert_ne(mpc.local_player._internal_peer, null, "_internal_peer not null")
	assert_ne(mpc.online_peer, null, "online_peer not null")
	"""
