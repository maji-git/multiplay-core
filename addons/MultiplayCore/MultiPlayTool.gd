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

var debugger = null

func get_icon(n):
	return EditorInterface.get_base_control().get_theme_icon(n)

func _enter_tree():
	if not ProjectSettings.has_setting("autoload/MPIO"):
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
	mprun_btn = _add_toolbar_button(_mprun_btn, ICON_RUN, ICON_RUN_PRESSED)
	mprun_btn.tooltip_text = "MultiPlay Quick Run\nQuickly test online mode"
	mprun_btn.gui_input.connect(_mprun_gui_input)
	
	var submenu: PopupMenu = PopupMenu.new()
	submenu.add_item("Check for updates", 1)
	submenu.add_item("Create Self Signed Certificate", 2)
	submenu.add_item("Configure Debug Data", 3)
	submenu.add_item("Toggle MPC Asset Library", 6)
	submenu.add_separator()
	submenu.add_item("Open Documentation", 8)
	submenu.add_item("Get Support", 9)
	
	submenu.id_pressed.connect(_toolmenu_pressed)
	
	add_tool_submenu_item("MultiPlay Core", submenu)
	
	before_export_checkout = preload("res://addons/MultiplayCore/editor/scripts/ExportCheckout.gd").new()
	add_export_plugin(before_export_checkout)
	
	debugger = preload("res://addons/MultiplayCore/editor/scripts/DebuggerPlugin.gd").new()
	add_debugger_plugin(debugger)

func _firstrun_restart_editor():
	set_firstrun("0")
	
	EditorInterface.save_all_scenes()
	
	# Handle Plugin Saving
	var config = ConfigFile.new()
	var err = config.load("res://project.godot")

	if err == OK:
		var editor_plugins: PackedStringArray = config.get_value("editor_plugins", "enabled", PackedStringArray())
		
		if !editor_plugins.has("res://addons/MultiplayCore/plugin.cfg"):
			editor_plugins.append("res://addons/MultiplayCore/plugin.cfg")
			
		var saveerr = config.save("res://project.godot")
			
		if saveerr == OK:
			print("MPC Plugin Saved")
		else:
			print("MPC Plugin Save Failed")
	
	print("Restarting...")
	await get_tree().create_timer(1).timeout
	
	EditorInterface.restart_editor(false)

func _mprun_btn():
	EditorInterface.save_all_scenes()
	
	debugger.send_start_auto = true
	
	EditorInterface.play_main_scene()

func open_run_debug_config():
	EditorInterface.popup_dialog_centered(preload("res://addons/MultiplayCore/editor/window/debug_configs.tscn").instantiate())

func _mprun_gui_input(e):
	if e is InputEventMouseButton:
		
		if e.button_index == 2 and e.pressed:
			open_run_debug_config()

func _unhandled_input(event):
	if event is InputEventKey:
		if event.ctrl_pressed && event.keycode == KEY_F5:
			_mprun_btn()

func _toolmenu_pressed(id):
	if id == 1:
		open_update_popup()
	
	if id == 2:
		run_devscript(preload("res://addons/MultiplayCore/dev_scripts/CertMake.gd"))
	
	if id == 3:
		open_run_debug_config()

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
	remove_debugger_plugin(debugger)
	
	remove_control_from_container(CONTAINER_TOOLBAR, mprun_btn)
	mprun_btn.free()
