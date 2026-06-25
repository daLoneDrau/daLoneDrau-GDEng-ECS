@abstract class_name GameSystem
extends Node


## Lower priority runs first (0 = highest priority)
@export var priority: int = 100

## Reference to owning scene
var scene: Scene = null

@export var enabled: bool = true:
	set(value):
		enabled = value
		if not value:
			_accum = 0.0

@export var tick_interval: float = 0.0  # 0 = every frame

var _accum: float = 0.0

func _ready() -> void:
	_on_ready()


## Override for node-level setup (runs when added to tree)
@abstract func _on_ready() -> void


## Called when system is registered to a scene
func initialize(owner_scene: Scene) -> void:
	scene = owner_scene
	_on_initialize()


## Override for system-specific initialization (after scene is set)
@abstract func _on_initialize() -> void


## Handle discrete game events (override in subclass)
@abstract func handle_event(_event_name: String, _payload: Dictionary = {}) -> void


func process(delta: float) -> void:
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


## Called when system is removed or scene exits
func cleanup() -> void:
	_on_cleanup()
	scene = null


## Override for system-specific cleanup
@abstract func _on_cleanup() -> void

## —————————————————————————————————————————————
#region Convenience Accessors
## —————————————————————————————————————————————


## Get EntityManager via scene
func get_entity_manager() -> EntityManager:
	if scene and scene._game_engine:
		return scene._game_engine.entity_manager
	return null


## Get entities with a specific component
func get_entities_with_component(component_name: String) -> Array[Entity]:
	var em := get_entity_manager()
	if em:
		return em.get_entities_with_component(component_name)
	return []


## Get another system from the scene
func get_system(system_name: StringName) -> GameSystem:
	if scene:
		return scene.get_registered_system(system_name)
	return null


## Emit event to all other systems in scene
func broadcast_event(event_name: String, payload: Dictionary = {}) -> void:
	if not scene:
		return
	for system in scene._systems.values():
		if system != self and system.enabled:
			system.handle_event(event_name, payload)

#endregion


func print_system_debug() -> void:
	print("=== %s ===" % get_script().get_global_name())
	print("  Enabled: %s" % enabled)
	print("  Priority: %d" % priority)
	print("  Tick interval: %s" % tick_interval)
	print("  Scene: %s" % (scene.name if scene else &"null"))
