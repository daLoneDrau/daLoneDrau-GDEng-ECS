## Defines an ability score, including base value and modifiers.
class_name AbilityScore
extends CustomResource


## the internal base [AbilityScore] value
@export var _base: int

## the internal total value of all modifiers applied to the [AbilityScore]
@export var _modifier: int = 0

## the [SetOfAbilities] this [AbilityScore] belongs to
var _parent: AbilitiesComponent

## Optional: track individual modifiers by source (e.g., "ring_of_power", "poison", "aura_blss")
var _sources: Dictionary[StringName, int] = {}  # source -> amount

## the base [AbilityScore] value
var base: int:
	get: return _base
	set(value):
		if _base == value: return
		_base = value
		_emit_change()

## the total value of all modifiers applied to the [AbilityScore]
var modifier: int:
	get: return _modifier
	set(value):
		if _modifier == value: return
		_modifier = value
		_emit_change()

## the [AbilityScore]'s full value after modifiers have been applied
var full: int:
	get: return _base + _modifier

## Called when the object's script is instantiated.
func _init(abilities_component: AbilitiesComponent) -> void:
	_parent = abilities_component


func add_modifier(amount: int) -> void:
	modifier = _modifier + amount

func add_source(src: StringName, amount: int) -> void:
	_sources[src] = int(amount)
	_recalc_modifier()

	
## Clears all source modifiers.
func clear_sources() -> void:
	if _sources.is_empty():
		return
	_sources.clear()
	_recalc_modifier()


func _emit_change() -> void:
	if _parent != null and _parent.has_method("emit_update_signal"):
		_parent.emit_update_signal()

func remove_source(src: StringName) -> void:
	if _sources.erase(src):
		_recalc_modifier()

func get_sources() -> Dictionary:
	return _sources.duplicate()

	
# Recalculates modifiers by source.
func _recalc_modifier() -> void:
	var sum: int = 0
	for k in _sources:
		sum += _sources[k]
	_modifier = sum
	_emit_change()

func set_base(value: int) -> void:
	base = value