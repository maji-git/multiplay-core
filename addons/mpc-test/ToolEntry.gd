@tool
extends EditorPlugin

var debugger: EditorDebuggerPlugin

# Called when the node enters the scene tree for the first time.
func _enter_tree():
	debugger = preload("res://addons/mpc-test/UnitTestDebuggerPlugin.gd").new()
	add_debugger_plugin(debugger)

func _exit_tree():
	remove_debugger_plugin(debugger)
