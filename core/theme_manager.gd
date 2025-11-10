class_name ThemeManager
extends Node

var current_theme_name := "c64_pixel"
var _theme_paths := {
	"retro_crt": "res://themes/RetroCRTTheme.tres",
	"book_parchment": "res://themes/book/BookTheme.tres",
	"c64_pixel": "res://themes/c64/scenes/demo/C64ThemeDemo.tscn"
}

func apply_theme(root: Node) -> void:
	if not _theme_paths.has(current_theme_name):
		push_warning("Unknown theme: %s" % current_theme_name)
		return
	var theme_res := load(_theme_paths[current_theme_name])
	if theme_res:
		root.theme = theme_res
