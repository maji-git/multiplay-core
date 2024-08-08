@icon("res://addons/MultiplayCore/icons/MPExtension.svg")
@tool

extends MPBase
## Base for MultiPlay Extensions
class_name MPExtension

## Main MultiPlayCore node
var mpc: MultiPlayCore

func _ready():
	if get_parent() is MultiPlayCore:
		mpc = get_parent()

## Called by MultiPlay Core when it's ready
func _mpc_ready():
	pass

func _enter_tree():
	if Engine.is_editor_hint():
		update_configuration_warnings()

func _get_configuration_warnings():
	var warns = []
	if not get_parent() is MultiPlayCore:
		warns.append("MultiPlay extensions must be a child of MultiPlayCore")
	return warns
