## Custom debugging node layer used to render guidelines or cell coordinates
class_name GridLayer extends Node2D


## The rendering system.
var rendering_system: RenderingSystem


## Called when [CanvasItem] has been requested to redraw (after [method queue_redraw] is called, either manually or by the engine).
func _draw() -> void:
	rendering_system.draw()
