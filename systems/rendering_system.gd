class_name RenderingSystem extends GameSystem


## the canves where rendering takes place
var canvas: CanvasItem

## the font size used to render the grid
var font_size: int = 7

## flag indicating whether the grid is oriented with the origin (0,0) in the top-left, or in the bottom-right
var top_down: bool = true


## Initializes the [RenderingSystem]
func _init(c: CanvasItem):
	canvas = c


## If a game canvas exists, trigger its redrawing method.
func render() -> void:
	if canvas != null:
		canvas.queue_redraw()


func draw() -> void:
	push_error(self.get_name() + ".draw() was left undefined!")
	assert(false, self.get_name() + ".replace_in_inventory() was left undefined!")
