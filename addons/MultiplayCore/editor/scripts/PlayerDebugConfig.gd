@tool
extends Node

@export var handshake_edit: TextEdit
@export var credentials_edit: TextEdit

@export var session_id = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	if not EditorPlugin:
		return
	load_data()
	
	handshake_edit.focus_exited.connect(apply_configs)
	credentials_edit.focus_exited.connect(apply_configs)

func apply_configs():
	var fp_data = read_config_file()
	
	if fp_data == null:
		fp_data = {}
	
	if !fp_data.keys().has("debug_configs"):
		fp_data.debug_configs = {}
	
	fp_data.debug_configs[str(session_id)] = {
		handshake = handshake_edit.text,
		credentials = credentials_edit.text
	}
	
	var fp = FileAccess.open("user://mp_debug_configs", FileAccess.WRITE)
	fp.store_string(JSON.stringify(fp_data))
	fp.close()

func load_data():
	var fp_data = read_config_file()
	if fp_data:
		
		if fp_data.keys().has("debug_configs"):
			if fp_data.debug_configs.keys().has(str(session_id)):
				handshake_edit.text = fp_data.debug_configs[str(session_id)].handshake
				credentials_edit.text = fp_data.debug_configs[str(session_id)].credentials

func read_config_file():
	var fp = FileAccess.open("user://mp_debug_configs", FileAccess.READ)
	if fp:
		var fp_data: Dictionary = JSON.parse_string(fp.get_as_text())
		fp.close()
		
		return fp_data
	
	return null
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
