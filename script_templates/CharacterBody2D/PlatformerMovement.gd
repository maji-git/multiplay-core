# meta-name: MultiPlay Platformer Movement
# meta-description: Prebuilt Platformer Movement script that supports MultiPlay inputs.
# meta-default: true

extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Get the MultiPlay Player node, It's the parent of this node!
@onready var mpp: MPPlayer = get_parent()

func _ready():
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
	print("Player's now ready!")

# On handshake data is ready. This emits to everyone in the server. You can also use it to init something for all players.
func _on_handshake_ready(hs):
	print(mpp.player_index)

func _physics_process(delta):
	if !mpp.is_ready:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed(mpp.ma("ui_accept")) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration
	# Using UI input actions because it's built-in.
	var direction = Input.get_axis(mpp.ma("ui_left"), mpp.ma("ui_right"))
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
