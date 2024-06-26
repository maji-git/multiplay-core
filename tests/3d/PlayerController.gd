extends CharacterBody3D


const SPEED = 2.0
const SPRINT_SPEED = 4.0
const JUMP_VELOCITY = 4.5

@export var gdbot: GDbotSkin

var cur_speed = SPEED

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var mpp: MPPlayer = get_parent()

func _ready():
	gdbot.set_face("default")
	
	# Listen to MultiPlay Player Signals
	mpp.player_ready.connect(_on_player_ready)
	mpp.handshake_ready.connect(_on_handshake_ready)
	mpp.swap_focused.connect(_on_swap_focused)
	mpp.swap_unfocused.connect(_on_swap_unfocused)

# When swap mode focused on this player
func _on_swap_focused(_old_focus):
	pass

# When swap mode unfocused on this player
func _on_swap_unfocused(_new_focus):
	pass

# When player node is ready, this only emit locally.
func _on_player_ready():
	
	# Enable the camera
	$Camera.current = true
	
	# Set Player Position
	#position = Vector3(mpp.player_index * 40, 2, 0)

# On handshake data is ready. This emits to everyone in the server. You can also use it to init something for all players.
func _on_handshake_ready(hs):
	print(mpp.player_index)

func _physics_process(delta):
	if !mpp.is_local:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed(mpp.ma("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	if Input.is_action_pressed("sprint"):
		cur_speed = SPRINT_SPEED
		gdbot._set_walk_run_blending(1)
	else:
		cur_speed = SPEED
		gdbot._set_walk_run_blending(0)
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector(mpp.ma("left"), mpp.ma("right"), mpp.ma("up"), mpp.ma("down"))
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * cur_speed
		velocity.z = direction.z * cur_speed
		gdbot.walk()
	else:
		velocity.x = move_toward(velocity.x, 0, cur_speed)
		velocity.z = move_toward(velocity.z, 0, cur_speed)
		gdbot.idle()
	
	move_and_slide()
	
	if !is_on_floor():
		gdbot.fall()
