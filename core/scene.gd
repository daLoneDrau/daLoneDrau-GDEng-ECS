@abstract class_name Scene
extends Node


var current_frame: int = 0

## key name -> action id
var action_map: Dictionary[String, String] = {}

var ended: bool = false

var paused: bool = false


func _process(_delta: float) -> void:
	# common per-frame hooks (optional)
	pass


## Runs the frame update, calling Scene-specific Systems for update (GameEngine calls this if present)
@abstract func update(_delta: float) -> void


## —————————————————————————————————————————————
#region Actions API
## —————————————————————————————————————————————


## Performs a specific action that was registered with the scene
@abstract func do_action(_action: GameAction) -> void


##
func get_action(source: String) -> String:
	return action_map.get(source, "")


## Gets the action registered under a specific code.
func get_registered_action(code: String) -> String:
	return action_map.get(code, "")


## Determines if the scene has registered an action under a specific code.
func has_action(source: String) -> bool:
	return action_map.has(source)


## Registers that an input event should trigger a specific action.
func register_action(input: String, action: String) -> void:
	action_map[input] = action

#endregion

## —————————————————————————————————————————————
#region Systems access (override in concrete scenes)
## —————————————————————————————————————————————


## Gets the assigned combat system.
@abstract func get_combat_system() -> CombatSystem


## Gets the assigned damage system.
@abstract func get_damage_system() -> DamageSystem


## Gets the assigned equipment system.
@abstract func get_equipment_system() -> EquipmentSystem


## Gets the assigned inventory system.
@abstract func get_inventory_system() -> InventorySystem


## Gets the assigned scripting system.
@abstract func get_scripting_system() -> ScriptingSystem


## Gets the assigned spell system.
@abstract func get_spell_system() -> SpellSystem


## Gets the assigned player system.
@abstract func get_player_system() -> PlayerSystem

#endregion

## —————————————————————————————————————————————
#region Utilities
## —————————————————————————————————————————————


## Hide all child elements.
func hide_children() -> void:
	for child in get_children():
		if child is Control:
			(child as Control).hide()


func simulation(_cycles: int) -> void:
	# optional override for fixed-step sims/batch updates
	pass


## Adds local signals to broadcast.
@abstract func broadcast_signals() -> void


## Connects local canvas elements' signals.
@abstract func listen_for_broadcasts() -> void


## Takes a screenshot.
func take_screenshot() -> ImageTexture:
	var img: Image = get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(img)

#endregion
