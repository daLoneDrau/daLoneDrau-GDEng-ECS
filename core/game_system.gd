@abstract class_name GameSystem
extends Node

@export var enabled: bool = true:
	get:
		return enabled
	set(value):
		enabled = value
		if not value:
			_accum = 0.0

@export var tick_interval: float = 0.0  # 0 = every frame
var _accum: float = 0.0

func _ready() -> void:
	_on_ready()

func _on_ready() -> void:
	# override in concrete systems for setup (connect signals, cache nodes)
	pass

func update(delta: float) -> void:
	if not enabled:
		return
	if tick_interval <= 0.0:
		_process_system(delta)
	else:
		_accum += delta
		while _accum >= tick_interval:
			_process_system(tick_interval)
			_accum -= tick_interval

@abstract func _process_system(delta: float) -> void
