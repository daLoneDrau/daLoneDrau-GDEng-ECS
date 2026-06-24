class_name SimpleAnimation
extends CustomResource


# the animation's name
var animation_name: String

# the current animation frame
var current_frame: int

var _finished: bool = false

var _accumulator: float = 0.0

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


func _init(p_name: String = "", p_texture: String = "") -> void:
	animation_name = p_name
	texture_name = p_texture
	current_frame = 0

func get_current_frame_rect() -> Rect2i:
	if frames.is_empty() or current_frame >= frames.size():
		return Rect2i()
	return frames[current_frame].get("rect", Rect2i())


func get_current_frame_texture(assets: AssetsLibrary) -> ImageTexture:
	return assets.get_texture(texture_name)


func _to_string() -> String:
	return "{} {} {} {}".format([animation_name, frame_count, str(frames), repeats], "{}")


func has_ended() -> bool:  # Should return bool, not void
	if repeats:
		return false
	return current_frame >= frame_count - 1


func reset() -> void:
	current_frame = 0
	_accumulator = 0.0
	_finished = false


func update(delta: float) -> void:
	if _finished or speed <= 0 or frames.is_empty():
		return
	
	_accumulator += delta
	var frame_duration := 1.0 / speed
	
	while _accumulator >= frame_duration:
		_accumulator -= frame_duration
		current_frame += 1
		
		if current_frame >= frames.size():
			if repeats:
				current_frame = 0
			else:
				current_frame = frames.size() - 1
				_finished = true
