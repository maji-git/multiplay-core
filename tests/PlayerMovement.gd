extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var on_ground = false

@onready var mpp: MPPlayer = get_node("../")

func _ready():
	mpp.player_ready.connect(_on_player_ready)
	mpp.handshake_ready.connect(_on_handshake_ready)
	mpp.swap_focused.connect(_on_swap_focused)
	mpp.swap_unfocused.connect(_on_swap_unfocused)

func _on_swap_focused():
	$playingThis.visible = true

func _on_swap_unfocused():
	$playingThis.visible = false

func _on_player_ready():
	print("player READY")
	
	print(mpp.translate_action("left"))

func _on_handshake_ready(hs):
	print("HANDSHAKE: ", hs)
	#$username.text = hs.username

func _physics_process(delta):
	if !mpp.is_ready:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed(mpp.ma("jump")) and is_on_floor():
		on_ground = false
		$PlayerAnim.play("jump")
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis(mpp.ma("left"), mpp.ma("right"))
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	if !is_on_floor() and on_ground:
		on_ground = false
	
	if is_on_floor() and on_ground == false:
		$PlayerAnim.play("jump_end")
		on_ground = true
