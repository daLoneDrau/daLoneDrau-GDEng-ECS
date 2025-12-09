class_name FloatingImageParagraph
extends VBoxContainer

@export var text_top: RichTextLabel
@export var text_bottom: RichTextLabel
@export var left_image: TextureRect
@export var right_image: TextureRect
@export var top_row: HBoxContainer

## flag indicating the image floats to the left of the text; if false the image floats to the right
@export var is_left: bool

var _full_text: String = ""

func _ready() -> void:
	# Re-layout whenever this control resizes (window resize, etc.)
	connect("resized", Callable(self, "_queue_layout"))


func set_content(text: String, image: Texture2D) -> void:
	_full_text = text
	left_image.visible = false
	right_image.visible = false
	var img := right_image
	if is_left:
		img = left_image

	img.texture = image
	img.visible = true

	# Defer layout so size and image size are valid
	_queue_layout()


func _queue_layout() -> void:
	# Let the engine finish one frame of layout, then compute
	await get_tree().process_frame
	_layout_text()


func _layout_text() -> void:
	if _full_text.is_empty():
		text_top.text = ""
		text_bottom.text = ""
		return

	# Make sure we have a valid width
	var total_width := size.x
	if total_width <= 0.0:
		return

	var img := right_image
	if is_left:
		img = left_image

	# Width available to the text next to the image
	var image_width := img.size.x
	if image_width <= 0.0 and img.texture:
		image_width = img.texture.get_width()

	var padding := 8.0  # whatever spacing you use between text and image
	var float_width: float = max(0.0, total_width - image_width - padding)
	if float_width <= 0.0:
		# No space to float; just put all text below.
		text_top.text = ""
		text_bottom.text = _full_text
		return

	# Height available for lines next to the image
	var image_height := img.size.y
	if image_height <= 0.0 and img.texture:
		image_height = img.texture.get_height()

	if image_height <= 0.0:
		# No height information yet; fallback: put everything below.
		text_top.text = ""
		text_bottom.text = _full_text
		return

	# Use TextParagraph to lay out the text for float_width
	var para := TextParagraph.new()

	var font: Font = text_top.get_theme_font("font") if text_top.has_theme_font("font") else get_theme_default_font()
	var font_size: int = text_top.get_theme_font_size("font_size") if text_top.has_theme_font("font_size") else 16

	para.add_string(_full_text, font, font_size)
	para.set_width(float_width)

	var line_count := para.get_line_count()
	if line_count == 0:
		text_top.text = ""
		text_bottom.text = ""
		return

	var used_height := 0.0
	var break_char_index := _full_text.length()  # default: everything fits

	for line in range(line_count):
		var line_size: Vector2 = para.get_line_size(line)
		var next_height := used_height + line_size.y

		if next_height <= image_height:
			# This whole line fits next to the image; extend break to end of this line
			var line_range: Vector2i = para.get_line_range(line)
			# range.x = start char, range.y = end char (exclusive)
			break_char_index = line_range.y
			used_height = next_height
		else:
			break

	if break_char_index >= _full_text.length():
		# All text fits beside the image; nothing below.
		text_top.text = _full_text
		text_bottom.text = ""
	elif break_char_index <= 0:
		# No line fits beside the image; everything below.
		text_top.text = ""
		text_bottom.text = _full_text
	else:
		var top_text := _full_text.substr(0, break_char_index)
		var bottom_text := _full_text.substr(break_char_index)

		# Strip a leading space or newline from the bottom to avoid weird indent
		bottom_text = bottom_text.strip_edges(true)

		text_top.text = top_text
		text_bottom.text = bottom_text

