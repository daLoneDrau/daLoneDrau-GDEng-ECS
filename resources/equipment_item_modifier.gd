## Defines a modifier applied by an equippable or carried item.
class_name EquipmentItemModifier
extends CustomResource


## —————————————————————————————————————————————
#region Basic properties
## —————————————————————————————————————————————

## true if the modifier is a percentage of the target stat’s base value.
@export var is_percentage: bool = false

## optional source tag to identify where this modifier came from.
## used by AbilitiesComponent.add_source/remove_source().
@export var source_tag: StringName = &"item_mod"

## true if this modifier represents a special effect (e.g., PARALYSIS, DRAIN_LIFE, POISON_IMMUNITY, etc.)
@export var special: bool = false

## identifies which ability or stat this affects (optional).
## example: &"STR", &"DEX", &"OXYGEN", etc.
@export var target_stat: StringName = &""

## the modifier value. can be positive or negative.
@export var value: int

#endregion

## —————————————————————————————————————————————
#region Optional metadata
## —————————————————————————————————————————————

## optional description or label for UI display.
@export var label: String = ""

## optional dictionary of parameters if this modifier represents a special effect.
## example: { "duration": 10, "damage_per_tick": 2 }
@export var effect_data: Dictionary[StringName, Variant] = {}

#endregion

## —————————————————————————————————————————————
#region Utility API
## —————————————————————————————————————————————

## Converts this modifier to a dictionary for save/export.
func to_dict() -> Dictionary:
	return {
		"value": value,
		"is_percentage": is_percentage,
		"special": special,
		"target_stat": target_stat,
		"source_tag": source_tag,
		"label": label,
		"effect_data": effect_data,
	}

## Restores modifier from dictionary data.
func from_dict(data: Dictionary) -> void:
	value = int(data.get("value", value))
	is_percentage = bool(data.get("is_percentage", is_percentage))
	special = bool(data.get("special", special))
	target_stat = data.get("target_stat", target_stat)
	source_tag = data.get("source_tag", source_tag)
	label = data.get("label", label)
	effect_data = data.get("effect_data", effect_data)

#endregion

## —————————————————————————————————————————————
#region Ability integration helpers
## —————————————————————————————————————————————

## Applies this modifier to an [AbilitiesComponent] (flat or percentage).
func apply_to_abilities(abilities: AbilitiesComponent, ability_id: int) -> void:
	if abilities != null:
		var s: AbilityScore = abilities.value(ability_id)
		if s != null:
			if is_percentage:
				var delta: int = int(round(s.base * (float(value) / 100.0)))
				s.add_source(source_tag, delta)
			else:
				s.add_source(source_tag, value)

## Removes this modifier from an [AbilitiesComponent].
func remove_from_abilities(abilities: AbilitiesComponent, ability_id: int) -> void:
	if abilities != null:
		var s: AbilityScore = abilities.value(ability_id)
		if s != null:
			s.remove_source(source_tag)

#endregion

