class_name AssetsLibrary
extends Node


## the dictionary of all animations
var animations: Dictionary = {}

## the dictionary of all fonts
var fonts: Dictionary = {}

## the dictionary of all sounds
var sounds: Dictionary = {}

## the dictionary of all textures
var textures: Dictionary = {}


## Adds a [SimpleAnimation] asset.
func add_animation(animation_name: String, animation: SimpleAnimation) -> void:
	animations[animation_name] = animation


## Adds a [FontFile] asset.
func add_font(font_name: String, path: String) -> void:
	fonts[font_name] = load(path) as FontFile


func add_sound(_name: String, _path: String) -> void:
	pass


## Adds an [ImageTexture] asset.
func add_texture(texture_name: String, path: String) -> void:
	var image: Image          = Image.load_from_file(path)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	textures[texture_name] = texture


func add_texture_from_sprite_sheet(texture_name: String, sprite_sheet: String, rect2i: Rect2i) -> void:
	var image: Image = textures[sprite_sheet].get_image().get_region(rect2i)
	textures[texture_name] = ImageTexture.create_from_image(image)

func get_animation(animation_name: String) -> SimpleAnimation:
	return animations[animation_name]


func get_font(font_name: String) -> FontFile:
	return fonts[font_name]


func get_texture(texture_name: String) -> ImageTexture:
	return textures[texture_name]


## Determines if an Animation of a given name was stored in the [AssetsLibrary].
func has_animation(animation_name: String) -> bool:
	return animations.has(animation_name)


## Determines if a Font of a given name was stored in the [AssetsLibrary].
func has_font(font_name: String) -> bool:
	return fonts.has(font_name)


## Determines if an Texture of a given name was stored in the [AssetsLibrary].
func has_texture(texture_name: String) -> bool:
	return textures.has(texture_name)
