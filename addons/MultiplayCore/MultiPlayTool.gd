@tool
extends EditorPlugin

const RESTART_POPUP = preload("res://addons/MultiplayCore/editor/window/first_restart.tscn")
const WELCOME_POPUP = preload("res://addons/MultiplayCore/editor/window/welcome_popup.tscn")

func _enter_tree():
	add_autoload_singleton("MPIO", "res://addons/MultiplayCore/MPIO.gd")
	
	if FileAccess.file_exists("user://mpc_tool_firstrun"):
		
		var fr = FileAccess.open("user://mpc_tool_firstrun", FileAccess.READ)
		var fr_val = fr.get_as_text()
		fr.close()
		
		if fr_val == "0":
			set_firstrun("1")
			var welcome_popup = WELCOME_POPUP.instantiate()
			add_child(welcome_popup)
			welcome_popup.popup_centered()
	else:
		# First run, require restart.
		
		var init_popup = RESTART_POPUP.instantiate()
		add_child(init_popup)
		
		init_popup.popup_centered()
		
		init_popup.confirmed.connect(_firstrun_restart_editor)

func _firstrun_restart_editor():
	set_firstrun("0")
	EditorInterface.restart_editor(true)

func set_firstrun(to):
	var fr = FileAccess.open("user://mpc_tool_firstrun", FileAccess.WRITE)
	fr.store_string(to)
	fr.close()

func _exit_tree():
	remove_autoload_singleton("MPIO")
