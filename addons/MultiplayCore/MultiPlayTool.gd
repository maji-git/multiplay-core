@tool
extends EditorPlugin

const RESTART_POPUP = preload("res://addons/MultiplayCore/editor/window/first_restart.tscn")
const WELCOME_POPUP = preload("res://addons/MultiplayCore/editor/window/welcome_popup.tscn")
const UPDATE_POPUP = preload("res://addons/MultiplayCore/editor/window/update_popup.tscn")

func get_icon(n):
	return EditorInterface.get_base_control().get_theme_icon(n)

func _enter_tree():
	var submenu: PopupMenu = PopupMenu.new()
	submenu.add_item("Check for updates", 1)
	submenu.add_separator()
	submenu.add_item("Open Documentation", 8)
	submenu.add_item("Get Support", 9)
	
	submenu.id_pressed.connect(_toolmenu_pressed)
	
	add_tool_submenu_item("MultiPlay Core", submenu)
	
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

func _toolmenu_pressed(id):
	if id == 1:
		open_update_popup()
	
	if id == 8:
		OS.shell_open("https://mpc.himaji.xyz/docs/")
	
	if id == 9:
		OS.shell_open("https://mpc.himaji.xyz/docs/community/get-support/")

func set_firstrun(to):
	var fr = FileAccess.open("user://mpc_tool_firstrun", FileAccess.WRITE)
	fr.store_string(to)
	fr.close()

func open_update_popup():
	var popup = UPDATE_POPUP.instantiate()
	add_child(popup)
	popup.popup_centered()
	popup.check_updates()

func _exit_tree():
	remove_tool_menu_item("MultiPlay Core")
	print("goodbye!")
	
	remove_autoload_singleton("MPIO")
