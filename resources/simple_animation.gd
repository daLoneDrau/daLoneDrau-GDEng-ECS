class_name SimpleAnimation
extends CustomResource


# the animation's name
var animation_name: String

# the current animation frame
var current_frame: int

# the number of frames in the animation
var frame_count: int

var frames: Array[Dictionary]

# the animation's size
var size: Vector2

# the animation's speed
var speed: int

# the animation's image file
var texture_name: String

# a flag indicating whether the animation repeats when it reaches the end. default is true
var repeats: bool = true


func _to_string() -> String:
	return "{} {} {} {}".format([animation_name, frame_count, str(frames), repeats], "{}")


func has_ended() -> void:
	pass


func update() -> void:
	pass
