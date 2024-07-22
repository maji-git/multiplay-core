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
	
	viewport_3d = mpc.get_node("3dv/v")
	#await delay(0.3)
	
	#await mpc.ready
	if DebugBridge.role == "server":
		mpc.start_online_host(true)
	
	await get_tree().create_timer(0.5).timeout

func delay(sec):
	await get_tree().create_timer(sec).timeout

func join_host():
	mpc.start_online_join("127.0.0.1:" + str(mpc.port))
	await delay(0.3)

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

func test_disconnect():
	if DebugBridge.role != "client":
		pass_test("client only test")
		return
	print("mpc.local_player ", mpc.local_player)
	#assert_ne(mpc.local_player._internal_peer, null, "internal peer not null")
	await join_host()
	await delay(1)
	await disconnect_from_host()
	assert_eq(mpc.local_player, null, "local_player null")

func test_transformsync_spawn_sync_2d():
	var test_transform = preload("res://test/resources/test_transform_2d.tscn").instantiate()
	mpc.add_child(test_transform, true)
	
	if DebugBridge.role == "server":
		test_transform.position = Vector2(200, 0)
		test_transform.rotation = 45
		test_transform.scale = Vector2(1.2, 1.2)
		pass_test("done")
	else:
		await delay(0.5)
		await join_host()
		await delay(1)
		assert_eq(round(test_transform.position.x), 200, "2D Position Spawn Check")
		assert_eq(round(test_transform.rotation), 45, "2D Rotation Spawn Check")
		assert_eq(round(test_transform.scale.x), 1.2, "2D Scale Spawn Check")

func test_transformsync_spawn_sync_3d():
	var test_transform = preload("res://test/resources/test_transform_3d.tscn").instantiate()
	viewport_3d.add_child(test_transform, true)
	
	if DebugBridge.role == "server":
		test_transform.position = Vector3(0, 1, 0)
		test_transform.rotation_degrees = Vector3(5, 5, 5)
		test_transform.scale = Vector3(1.2, 1.2, 1.2)
		pass_test("done")
	else:
		await delay(0.5)
		await join_host()
		await delay(1)
		assert_eq(round(test_transform.position.y), 1, "3D Position Spawn Check")
		assert_eq(round(test_transform.rotation_degrees.x), 45, "3D Rotation Spawn Check")
		assert_eq(round(test_transform.scale.x), 1.2, "3D Scale Spawn Check")
		pass_test("okie")
