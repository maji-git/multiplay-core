@tool
extends Node

@export var http_request: HTTPRequest
@export var slidetxt_anim_play: AnimationPlayer
@export var status_label: Label
@export var main_title: Label
@export var current_version: Label

@export var update_btn: Button

@export var update_progress_bar: ProgressBar

const RELEASE_INFO_JSON = "https://mpc.himaji.xyz/static/releases/release-info.json"

var label_to_set = ""
var label_clr_to_set = Color.WHITE

var download_url = ""
var download_commit_hash = ""

var request_step = ""

func check_updates():
	current_version.text = "Current Version: " + MultiPlayCore.MP_VERSION + " - " + MultiPlayCore.MP_VERSION_NAME
	update_btn.disabled = true
	set_status("Checking for updates...")
	print("Update checker running...")
	request_step = "meta_fetch"
	http_request.request_completed.connect(_on_http_request_request_completed)
	http_request.request(RELEASE_INFO_JSON)

func anim_apply_status():
	status_label.text = label_to_set
	status_label.add_theme_color_override("font_color", label_clr_to_set)

func set_status(txt, color = Color.WHITE_SMOKE):
	label_clr_to_set = color
	label_to_set = txt
	slidetxt_anim_play.stop()
	slidetxt_anim_play.play("slide")
	
	await get_tree().create_timer(0.1).timeout
	anim_apply_status()

func _on_http_request_request_completed(result, response_code, headers, body):
	if request_step == "meta_fetch":
		if result == OK:
			set_status("")
			var data = JSON.parse_string(body.get_string_from_utf8())
			
			download_url = data.download_url
			download_commit_hash = data.download_commit_hash
			
			if data.version_string == MultiPlayCore.MP_VERSION:
				# Latest version already
				main_title.text = "You're up to date!"
				update_btn.text = "Reinstall"
				update_btn.disabled = false
			else:
				# New update
				var engine_info = Engine.get_version_info()
				var engine_required = str(data.godot_version).split(".")
				var engine_sub = str(engine_info.major) + "." + str(engine_info.minor)
				
				if int(engine_required[0]) > engine_info.major or int(engine_required[1]) > engine_info.minor:
					main_title.text = "Not compatible with Godot v" + str(engine_sub)
					update_btn.disabled = true
					set_status("Please update your Godot version to " + str(data.godot_version), Color.DARK_ORANGE)
				else:
					main_title.text = "Version " + str(data.version_string) + " is available!"
					update_btn.text = "Update"
					set_status("Press update to install the latest version.")
					update_btn.disabled = false

	if request_step == "update":
		var updatezip = FileAccess.open("user://mpc_update.zip", FileAccess.WRITE)
		updatezip.store_buffer(body)
		updatezip.close()
		set_status("Extracting...")
		
		var reader := ZIPReader.new()
		var err := reader.open("user://mpc_update.zip")
		if err != OK:
			set_status("Extraction Failed.", Color.INDIAN_RED)
		var files := reader.get_files()
		
		update_progress_bar.max_value = files.size()
		update_progress_bar.value = 0
		
		DirAccess.remove_absolute("res://addons/MultiplayCore")
		
		for f in files:
			var fp = f.trim_prefix("multiplay-core-" + download_commit_hash)
			
			var res := reader.read_file(f)
			
			var user_path = "res://" + fp
			if res.size() == 0:
				DirAccess.make_dir_recursive_absolute(user_path)
			else:
				var fs = FileAccess.open(user_path, FileAccess.WRITE)
				fs.store_buffer(res)
				fs.close()
			
			update_progress_bar.value = update_progress_bar.value + 1
		
		reader.close()
		
		set_status("Completed! Restart the Editor to finish installation :D", Color.LIME_GREEN)
		
		update_btn.text = "Save + Restart"
		update_btn.visible = true
		update_progress_bar.visible = false
		
		request_step = "restart"


func _on_update_button_pressed():
	if request_step == "restart":
		EditorInterface.restart_editor(true)
		return
	request_step = "update"
	update_btn.visible = false
	update_progress_bar.visible = true
	set_status("Downloading the latest version...")
	
	http_request.request(download_url)
