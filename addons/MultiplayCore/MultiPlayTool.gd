@tool
extends EditorPlugin

const RESTART_POPUP = preload("res://addons/MultiplayCore/editor/window/first_restart.tscn")
const WELCOME_POPUP = preload("res://addons/MultiplayCore/editor/window/welcome_popup.tscn")
const UPDATE_POPUP = preload("res://addons/MultiplayCore/editor/window/update_popup.tscn")
const ICON_RUN = preload("res://addons/MultiplayCore/icons/MPDebugPlay.svg")
const ICON_RUN_PRESSED = preload("res://addons/MultiplayCore/icons/MPDebugPlay_Pressed.svg")

const MULTIPLAY_ASSETLIB_URL = "https://assets.mpc.himaji.xyz"

var before_export_checkout = null
var mprun_btn: PanelContainer = null

var icon_refresh

func get_icon(n):
	return EditorInterface.get_base_control().get_theme_icon(n)

func _enter_tree():
	add_autoload_singleton("MPIO", "res://addons/MultiplayCore/MPIO.gd")
	
	icon_refresh = get_icon("RotateLeft")
	
	if FileAccess.file_exists("user://mpc_tool_firstrun"):
		var fr = FileAccess.open("user://mpc_tool_firstrun", FileAccess.READ)
		var fr_val = fr.get_as_text()
		fr.close()
		
		if fr_val == "0":
			set_firstrun("1")
			var welcome_popup = WELCOME_POPUP.instantiate()
			add_child(welcome_popup)
			welcome_popup.popup_centered()
		
		_on_project_opened()
	else:
		# First run, require restart.
		
		var init_popup = RESTART_POPUP.instantiate()
		add_child(init_popup)
		
		init_popup.popup_centered()
		
		init_popup.confirmed.connect(_firstrun_restart_editor)

func _set_assetlib():
	var editor_settings = EditorInterface.get_editor_settings()
	var aburls: Dictionary = editor_settings.get_setting("asset_library/available_urls")
	
	if !aburls.keys().has("MultiPlay AssetLib"):
		aburls["MultiPlay AssetLib"] = MULTIPLAY_ASSETLIB_URL
		
		print("Installed MultiPlay Asset Library! If you don't see the option in the site dropdown, try to open and close editor settings menu.")
	else:
		print("MultiPlay Asset Library has been uninstalled")
		aburls.erase("MultiPlay AssetLib")

func _on_project_opened():
	#mprun_btn = _add_toolbar_button(_mprun_btn, ICON_RUN, ICON_RUN_PRESSED)
	#mprun_btn.tooltip_text = "MultiPlay Quick Run\nQuickly test online mode"
	
	var submenu: PopupMenu = PopupMenu.new()
	submenu.add_item("Check for updates", 1)
	submenu.add_item("Create Self Signed Certificate", 2)
	submenu.add_item("Toggle MPC Asset Library", 6)
	submenu.add_separator()
	submenu.add_item("Open Documentation", 8)
	submenu.add_item("Get Support", 9)
	
	submenu.id_pressed.connect(_toolmenu_pressed)
	
	add_tool_submenu_item("MultiPlay Core", submenu)
	
	before_export_checkout = preload("res://addons/MultiplayCore/editor/scripts/ExportCheckout.gd").new()
	add_export_plugin(before_export_checkout)

func _firstrun_restart_editor():
	set_firstrun("0")
	EditorInterface.save_all_scenes()
	EditorInterface.restart_editor()

func _mprun_btn():
	print("MULTIPLAY RUN")
	EditorInterface.save_all_scenes()
	
	mprun_btn.get_node("tbtn").texture_normal = icon_refresh
	
	var pids = []
	
	var wincount = 2
	
	var win_pos = []
	
	var screen_padding = 150
	
	var win_width = ProjectSettings.get_setting_with_override("display/window/size/viewport_width")
	var win_height = ProjectSettings.get_setting_with_override("display/window/size/viewport_height")
	var screen_size = DisplayServer.screen_get_size() - Vector2i(screen_padding, screen_padding)
	
	var win_spacing = 50
	
	var debug_win_width = (screen_size.x / 2)
	var debug_win_height = win_height
	
	if wincount > 2:
		debug_win_height = (screen_size.y / 2)
	
	var x = 0
	var y = 0
	
	for i in range(0, wincount):
		var args = [
			"--debug",
			"--mp-debug",
			"--win_width=" + str(debug_win_width - win_spacing),
			"--win_height=" + str(debug_win_height - win_spacing),
			"--win_x=" + str(x + win_spacing),
			"--win_y=" + str(y + win_spacing),
		]
		
		x = x + debug_win_width
		
		if x > debug_win_width:
			x = 0
			y = y + debug_win_height
		
		print(x, ", ", y)
		
		if i == 0:
			args.append("--server")
			args.append("--act-client")
		else:
			args.append("--client")
		
		var pid = OS.create_process(OS.get_executable_path(), args, false)
		pids.append(pid)

func _toolmenu_pressed(id):
	if id == 1:
		open_update_popup()
	
	if id == 2:
		run_devscript(preload("res://addons/MultiplayCore/dev_scripts/CertMake.gd"))
	
	if id == 6:
		_set_assetlib()
	
	if id == 8:
		OS.shell_open("https://mpc.himaji.xyz/docs/")
	
	if id == 9:
		OS.shell_open("https://mpc.himaji.xyz/docs/community/get-support/")

func set_firstrun(to):
	var fr = FileAccess.open("user://mpc_tool_firstrun", FileAccess.WRITE)
	fr.store_string(to)
	fr.close()

func _add_toolbar_button(action: Callable, icon_normal, icon_pressed):
	var panel = PanelContainer.new()
	var b = TextureButton.new();
	b.name = "tbtn"
	b.texture_normal = icon_normal
	b.texture_pressed = icon_pressed
	b.pressed.connect(action)
	panel.add_child(b)
	add_control_to_container(CONTAINER_TOOLBAR, panel)
	return panel

func run_devscript(script):
	await script.run()

func open_update_popup():
	var popup = UPDATE_POPUP.instantiate()
	add_child(popup)
	popup.popup_centered()
	popup.check_updates()

func _exit_tree():
	remove_tool_menu_item("MultiPlay Core")
	 
	remove_export_plugin(before_export_checkout)
	
	print("goodbye!")
	
	remove_autoload_singleton("MPIO")
	
	#remove_control_from_container(CONTAINER_TOOLBAR, mprun_btn)
	#mprun_btn.free()
