extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var mpp: MPPlayer = get_node("../")

func _ready():
	mpp.player_ready.connect(_on_player_ready)
	mpp.handshake_ready.connect(_on_handshake_ready)
	mpp.swap_focused.connect(_on_swap_focused)
	mpp.swap_unfocused.connect(_on_swap_unfocused)

# When swap mode focused on this player
func _on_swap_focused(_old_focus):
	$SwapIndicator.visible = true
	$Camera2D.enabled = true

# When swap mode unfocused on this player
func _on_swap_unfocused(_new_focus):
	$SwapIndicator.visible = false
	$Camera2D.enabled = false


# When player node is ready, this only emit locally.
func _on_player_ready():
	print("Player's now ready!")
	
	# We'll need to enable camera only when focused on swap mode
	if mpp.mpc.mode != mpp.mpc.PlayMode.Swap:
		$Camera2D.enabled = true

# On handshake data is ready. This emits to everyone in the server. You can also use it to init something for all players.
func _on_handshake_ready(hs):
	print(mpp.player_index)
	$PlayerLabel.text = "P" + str(mpp.player_index + 1)

func _physics_process(delta):
	if !mpp.is_ready:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed(mpp.ma("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis(mpp.ma("left"), mpp.ma("right"))
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if direction != 0:
		$Sprite.speed_scale = 1
		
		if direction == 1:
			$Sprite.flip_h = true
		else:
			$Sprite.flip_h = false
	else:
		$Sprite.speed_scale = 0
	
	move_and_slide()
