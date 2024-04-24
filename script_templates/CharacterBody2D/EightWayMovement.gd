# meta-name: MultiPlay 8-way Movement
# meta-description: Prebuilt 8-way Movement script that supports MultiPlay inputs.
# meta-default: true

extends CharacterBody2D

const SPEED = 300.0

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
	pass

func _physics_process(delta):
	if !mpp.is_ready:
		return

	# Get the input vector
	# Using UI input actions because it's built-in.
	var input_direction = Input.get_vector(mpp.ma("ui_left"), mpp.ma("ui_right"), mpp.ma("ui_up"), mpp.ma("ui_down"))
	velocity = input_direction * SPEED
	
	move_and_slide()
