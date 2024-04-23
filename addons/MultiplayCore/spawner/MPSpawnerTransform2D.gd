@icon("res://addons/MultiplayCore/icons/MPStartTransform2D.svg")
@tool
extends Node2D
## Start Transform of 2D [b]NOT READY TO BE USED[b]
## @experimental
class_name MPStartTransform2D


# Called when the node enters the scene tree for the first time.
func _ready():
	if Engine.is_editor_hint():
		pass
		#print(EditorInterface.get_editor_viewport_2d())


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _draw():
	if Engine.is_editor_hint():
		
		draw_set_transform_matrix(Transform2D.IDENTITY)
		
		draw_texture(preload("res://addons/MultiplayCore/gizmos/Spawner.svg"), Vector2(0,0))
		
