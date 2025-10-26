class_name EquipmentItemModifiers
extends CustomResource


## any modifiers to apply.
var modifiers: Dictionary[int, Array] = {}


func _get(property: StringName) -> EquipmentItemModifier:
	if property.is_valid_int():
		return modifiers.get(property.to_int(), null)
	return modifiers.get(property, null)


func _set(property: StringName, value: Variant) -> bool:
	var property_mods: Array
	if property.is_valid_int():
		if property.to_int() not in modifiers:
			modifiers[property.to_int()] = []
			property_mods = modifiers[property.to_int()]

	# check to see if modifier w/same source was already added
	var found: bool = false
	var new_mod: EquipmentItemModifier = value as EquipmentItemModifier
	for i in property_mods.size():
		var old_mod: EquipmentItemModifier = property_mods[i]
		if new_mod.source_tag == old_mod.source_tag:
			# remove old mod, add new mod
			property_mods.remove_at(i)
			property_mods.append(new_mod)
			found = true
			break
	if not found:
		property_mods.append(new_mod)
	return true


# --- PATCH: add these helpers anywhere in EquipmentItemModifiers.gd ---

## Applies all stored modifiers to the given AbilitiesComponent.
func apply_all(abilities: AbilitiesComponent) -> void:
	if abilities == null:
		return
	for key in modifiers.keys():
		var ability_id := _key_to_ability_id(key)
		if ability_id < 0:
			continue
		var entry = modifiers[key]
		if entry is Array:
			for m in entry:
				if m is EquipmentItemModifier:
					m.apply_to_abilities(abilities, ability_id)
		elif entry is EquipmentItemModifier:
			entry.apply_to_abilities(abilities, ability_id)


func merge(other: EquipmentItemModifiers) -> EquipmentItemModifiers:
	var merged := EquipmentItemModifiers.new()

	for k in modifiers.keys():
		merged.modifiers[k] = modifiers[k] + other.modifiers.get(k, [])

	return merged


## Removes all stored modifiers from the given AbilitiesComponent.
func remove_all(abilities: AbilitiesComponent) -> void:
	if abilities == null:
		return
	for key in modifiers.keys():
		var ability_id := _key_to_ability_id(key)
		if ability_id < 0:
			continue
		var entry = modifiers[key]
		if entry is Array:
			for m in entry:
				if m is EquipmentItemModifier:
					m.remove_from_abilities(abilities, ability_id)
		elif entry is EquipmentItemModifier:
			entry.remove_from_abilities(abilities, ability_id)


## Converts a dictionary key (int or string-like) to an ability id (int), or -1 if unknown.
func _key_to_ability_id(key: Variant) -> int:
	if typeof(key) == TYPE_INT:
		return int(key)
	if typeof(key) == TYPE_STRING_NAME or typeof(key) == TYPE_STRING:
		var s := str(key)
		if s.is_valid_int():
			return int(s.to_int())
	return -1

