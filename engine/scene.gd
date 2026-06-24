@abstract class_name Scene
extends Node


const FIXED_DELTA: float = 1.0 / 60.0

var frame_count: int = 0

## key name -> action id
var action_map: Dictionary[String, String] = {}

var _game_engine: GameEngine

var ended: bool = false

var paused: bool = false

# Systems owned by this scene
var _systems: Dictionary[StringName, GameSystem] = {}


## Called by GameEngine each frame. Increments frame count and calls _update().
func update(delta: float) -> void:
	if paused:
		return
	frame_count += 1
	_update(delta)


## Override this in subclasses for scene-specific per-frame logic
func _update(delta: float) -> void:
	# Get systems sorted by priority
	var sorted_systems: Array = _systems.values()
	sorted_systems.sort_custom(func(a, b): return a.priority < b.priority)

	# Process all enabled systems
	for system in sorted_systems:
		system.process(delta)  # process() checks enabled internally


## —————————————————————————————————————————————
#region Actions API
## —————————————————————————————————————————————


## Clears all action mappings
func clear_actions() -> void:
	action_map.clear()


## Performs a specific action that was registered with the scene
@abstract func do_action(_action: GameAction) -> void


##
func get_action(source: String) -> String:
	return action_map.get(source, "")


## Determines if the scene has registered an action under a specific code.
func has_action(source: String) -> bool:
	return action_map.has(source)


## Registers that an input event should trigger a specific action.
func register_action(input: String, action: String) -> void:
	action_map[input] = action


## Unregisters an action mapping
func unregister_action(input: String) -> void:
	action_map.erase(input)

#endregion

## —————————————————————————————————————————————
#region Lifecycle Hooks
## —————————————————————————————————————————————


## Called when scene becomes the primary scene
func on_enter() -> void:
	pass  # Override in subclass


## Called before scene is removed or replaced
func on_exit() -> void:
	pass  # Override in subclass


## Called when an overlay is pushed on top of this scene
func on_pause() -> void:
	paused = true  # Use existing paused flag


## Called when overlay is popped and this scene regains focus
func on_resume() -> void:
	paused = false

#endregion

## —————————————————————————————————————————————
#region Entity Helpers
## —————————————————————————————————————————————


## Gets all entities relevant to this scene (override to customize query)
func get_scene_entities() -> Array[Entity]:
	# Default: return all entities. Override in subclass for filtering.
	return _game_engine.entity_manager.get_entities()


## Convenience: Get the player entity
func get_player() -> Entity:
	var players := _game_engine.entity_manager.get_entities_by_tag(PlayerTags.Tag.PC)
	if players.size() > 0:
		return players[0]
	return null


## Convenience: Get entity by ID
func get_entity(id: String) -> Entity:
	return _game_engine.entity_manager.get_entity_by_id(id)

#endregion

## —————————————————————————————————————————————
#region Systems access (override in concrete scenes)
## —————————————————————————————————————————————


## Gets a registered [GameSystem].
func get_registered_system(sys: StringName) -> GameSystem:
	return _systems.get(sys, null)


## Registers a [GameSystem].
func register_system(sys: GameSystem) -> void:
	var sys_name: StringName = sys.get_script().get_global_name()
	_systems[sys_name] = sys
	sys.initialize(self)

#endregion

## —————————————————————————————————————————————
#region Utilities
## —————————————————————————————————————————————


## Hide all child elements.
func hide_children() -> void:
	for child in get_children():
		if child is Control:
			(child as Control).hide()


func set_engine(engine: GameEngine) -> void:
	_game_engine = engine


## Runs multiple update cycles (useful for testing, turn resolution, fast-forward)
func simulate(cycles: int) -> void:
	for i in cycles:
		update(FIXED_DELTA)
		if _game_engine.entity_manager:
			_game_engine.entity_manager.update()


## Takes a screenshot.
func take_screenshot() -> ImageTexture:
	var img: Image = get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img)

#endregion


func print_scene_debug() -> void:
	print("=== Scene Debug: %s ===" % name)
	print("  Frame count: %d" % frame_count)
	print("  Paused: %s" % paused)
	print("  Ended: %s" % ended)
	print("  Actions: %s" % action_map.keys())
	print("  Systems: %s" % _systems.keys())
