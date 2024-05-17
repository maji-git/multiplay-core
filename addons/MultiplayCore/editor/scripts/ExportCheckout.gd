@tool
extends EditorExportPlugin

var post_build_log = {}
var is_debug = false

func _export_begin(features, is_debug_build, path, flags):
	is_debug = is_debug_build
	
	if features.has("android"):
		if get_option("permissions/internet") == false:
			add_post_log("Android: Internet permission not enabled", [
				"Internet permission is currently not enabled. This will cause multiplayer not to work.",
			])

func add_post_log(title, logs):
	post_build_log[title] = logs

func _export_file(path, type, features):
	# Prevent exposing private key files in client builds
	if path.ends_with(".key") and is_debug == false:
		if not features.has("headless") and not features.has("server"):
			skip()
		
			add_post_log("Key ignored warning", [
				"Key files (.key) are ignored in this build to prevent private key exposure in client exports.",
				"To prevent this, Add 'headless' or 'server' to export features, or ignore the key files in export resources tab."
			])

func _export_end():
	if post_build_log.size() > 0:
		print_rich("\n[color=#FFB800]⚠️[/color] [b]Multiplay Export Warnings[/b] ----\n")
		for k in post_build_log.keys():
			var v = post_build_log[k]
			
			print_rich("[color=#FFB800]•[/color] [b]" + k + "[/b]")
			
			for l in v:
				print_rich("\t", l)
			
			print("")


func _get_name():
	return "mpc_build_checkout"
