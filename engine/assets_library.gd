class_name AssetsLibrary
extends Node


## the dictionary of all animations
var animations: Dictionary[String, SimpleAnimation] = {}

## the dictionary of all fonts
var fonts: Dictionary[String, FontFile] = {}

## the dictionary of all sounds
var sounds: Dictionary[String, AudioStream] = {}

## the dictionary of all textures
var textures: Dictionary[String, ImageTexture] = {}

var _texture_paths: Dictionary[String, String] = {}


## Adds a [SimpleAnimation] asset.
func add_animation(animation_name: String, animation: SimpleAnimation) -> void:
	animations[animation_name] = animation


## Adds a [FontFile] asset.
func add_font(font_name: String, path: String) -> bool:
	if fonts.has(font_name):
		push_warning("AssetsLibrary: Overwriting font '%s'" % font_name)

	var font: FontFile = load(path) as FontFile
	if font == null:
		push_error("AssetsLibrary: Failed to load font at '%s'" % path)
		return false

	fonts[font_name] = font
	return true


func add_sound(sound_name: String, path: String) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream:
		sounds[sound_name] = stream
	else:
		push_error("AssetsLibrary: Failed to load sound at '%s'" % path)


## Adds an [ImageTexture] asset.
func add_texture(texture_name: String, path: String) -> bool:
	if textures.has(texture_name):
		push_warning("AssetsLibrary: Overwriting texture '%s'" % texture_name)

	var image: Image          = Image.load_from_file(path)
	if image == null:
		push_error("AssetsLibrary: Failed to load image at '%s'" % path)
		return false

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	textures[texture_name] = texture
	return true


func add_texture_from_sprite_sheet(texture_name: String, sprite_sheet: String, rect2i: Rect2i) -> void:
	var image: Image = textures[sprite_sheet].get_image().get_region(rect2i)
	textures[texture_name] = ImageTexture.create_from_image(image)


## Load multiple textures from a sprite sheet grid
func add_textures_from_grid(
	sprite_sheet_name: String,
	name_prefix: String,
	cell_size: Vector2i,
	count: int,
	columns: int
) -> void:
	if not textures.has(sprite_sheet_name):
		push_error("AssetsLibrary: Sprite sheet '%s' not loaded" % sprite_sheet_name)
		return

	for i in range(count):
		var col: int = i % columns
		var row: int = int(float(i) / columns)
		var rect := Rect2i(
			col * cell_size.x,
			row * cell_size.y,
			cell_size.x,
			cell_size.y
		)
		var texture_name := "%s_%d" % [name_prefix, i]
		add_texture_from_sprite_sheet(texture_name, sprite_sheet_name, rect)


func get_animation(animation_name: String, warn_if_missing: bool = true) -> SimpleAnimation:
	if animations.has(animation_name):
		return animations[animation_name]
	if warn_if_missing:
		push_warning("AssetsLibrary: Animation '%s' not found" % animation_name)
	return null


func get_font(font_name: String, warn_if_missing: bool = true) -> FontFile:
	if fonts.has(font_name):
		return fonts[font_name]
	if warn_if_missing:
		push_warning("AssetsLibrary: Font '%s' not found" % font_name)
	return null


func get_sound(sound_name: String, warn_if_missing: bool = true) -> AudioStream:
	if sounds.has(sound_name):
		return sounds[sound_name]
	if warn_if_missing:
		push_warning("AssetsLibrary: Sound '%s' not found" % sound_name)
	return null


func get_texture(texture_name: String, warn_if_missing: bool = true) -> ImageTexture:
	if textures.has(texture_name):
		return textures[texture_name]
	if warn_if_missing:
		push_warning("AssetsLibrary: Texture '%s' not found" % texture_name)
	return null


func get_texture_lazy(texture_name: String) -> ImageTexture:
	# Return cached if already loaded
	if textures.has(texture_name):
		return textures[texture_name]

	# Load on demand
	if _texture_paths.has(texture_name):
		add_texture(texture_name, _texture_paths[texture_name])
		return textures.get(texture_name)

	push_warning("AssetsLibrary: Texture '%s' not registered" % texture_name)
	return null


## Get texture or return a fallback (useful for graceful degradation).
func get_texture_or_default(texture_name: String, fallback: ImageTexture) -> ImageTexture:
	return textures.get(texture_name, fallback)


## Determines if an Animation of a given name was stored in the [AssetsLibrary].
func has_animation(animation_name: String) -> bool:
	return animations.has(animation_name)


## Determines if a Font of a given name was stored in the [AssetsLibrary].
func has_font(font_name: String) -> bool:
	return fonts.has(font_name)


## Determines if a Sound of a given name was stored in the [AssetsLibrary].
func has_sound(sound_name: String) -> bool:
	return sounds.has(sound_name)


## Determines if an Texture of a given name was stored in the [AssetsLibrary].
func has_texture(texture_name: String) -> bool:
	return textures.has(texture_name)


func register_texture(texture_name: String, path: String) -> void:
	_texture_paths[texture_name] = path

## —————————————————————————————————————————————
#region Clear/Unload Methods
## —————————————————————————————————————————————


func clear_all() -> void:
	animations.clear()
	fonts.clear()
	sounds.clear()
	textures.clear()


func clear_textures() -> void:
	textures.clear()


func remove_texture(texture_name: String) -> bool:
	return textures.erase(texture_name)

#endregion

## —————————————————————————————————————————————
#region Debug/Inspection Methods
## —————————————————————————————————————————————


func get_loaded_asset_counts() -> Dictionary:
	return {
		"animations": animations.size(),
		"fonts": fonts.size(),
		"sounds": sounds.size(),
		"textures": textures.size(),
	}


func print_loaded_assets() -> void:
	print("=== AssetsLibrary Contents ===")
	print("  Animations: %s" % str(animations.keys()))
	print("  Fonts: %s" % str(fonts.keys()))
	print("  Sounds: %s" % str(sounds.keys()))
	print("  Textures: %d loaded" % textures.size())

	#endregion
