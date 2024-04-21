@tool
extends EditorPlugin


func _enter_tree():
	add_autoload_singleton("MPIO", "res://addons/MultiplayCore/MPIO.gd")


func _exit_tree():
	remove_autoload_singleton("MPIO")
