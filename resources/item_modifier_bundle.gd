## Bundle of stat modifiers and effect grants for an item.
## Attached to items to define what bonuses/effects they provide when equipped.
## Can be shared across multiple items of the same type via resource sharing.
class_name ItemModifierBundle
extends Resource

## Stat modifiers granted by this item
## Each entry is a StatModifierEntry resource
@export var stat_modifiers: Array[StatModifierEntry] = []

## Special effects granted by this item
## Each entry is an EffectGrant resource
@export var effect_grants: Array[EffectGrant] = []

## Requirements to use/equip this item (optional)
## Key: stat_id (StringName as String), Value: minimum required value
@export var requirements: Dictionary = {}


## —————————————————————————————————————————————
#region Application API
## —————————————————————————————————————————————

## Apply all stat modifiers to a StatsComponent.
## source_id: Identifier for removal later (typically item entity ID)
func apply_stat_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	if stats == null:
		return

	for mod in stat_modifiers:
		if mod.stat_id == &"":
			continue

		# Clone the entry and set source
		var entry := StatModifierEntry.new()
		entry.stat_id = mod.stat_id
		entry.source_id = source_id
		entry.amount = mod.amount
		entry.is_percentage = mod.is_percentage
		entry.stack_group = mod.stack_group
		entry.display_name = mod.display_name
		entry.icon_id = mod.icon_id
		entry.description = mod.description
		entry.duration_type = mod.duration_type

		stats.add_modifier_entry(mod.stat_id, entry)


## Remove all stat modifiers from a StatsComponent by source.
func remove_stat_modifiers(stats: StatsComponent, source_id: StringName) -> void:
	if stats == null:
		return

	stats.remove_modifiers_from_source(source_id)


## Apply all effect grants to an EffectsComponent.
## source_id: Identifier for removal later (typically item entity ID)
func apply_effects(effects: EffectsComponent, source_id: StringName) -> void:
	if effects == null:
		return

	for grant in effect_grants:
		effects.apply_effect(grant, source_id)


## Remove all effects from an EffectsComponent by source.
func remove_effects(effects: EffectsComponent, source_id: StringName) -> void:
	if effects == null:
		return

	effects.remove_effects_from_source(source_id, &"unequipped")


## Apply everything (stats + effects) to an entity.
## Convenience method for equipment system.
func apply_all(entity: Entity, source_id: StringName) -> void:
	var stats: StatsComponent = entity.get_component(&"StatsComponent") as StatsComponent
	var effects: EffectsComponent = entity.get_component(&"EffectsComponent") as EffectsComponent

	apply_stat_modifiers(stats, source_id)
	apply_effects(effects, source_id)


## Remove everything (stats + effects) from an entity.
func remove_all(entity: Entity, source_id: StringName) -> void:
	var stats: StatsComponent = entity.get_component(&"StatsComponent") as StatsComponent
	var effects: EffectsComponent = entity.get_component(&"EffectsComponent") as EffectsComponent

	remove_stat_modifiers(stats, source_id)
	remove_effects(effects, source_id)

#endregion

## —————————————————————————————————————————————
#region Requirements
## —————————————————————————————————————————————

## Check if an entity meets all requirements to use this item.
func meets_requirements(entity: Entity) -> bool:
	if requirements.is_empty():
		return true

	var stats: StatsComponent = entity.get_component(&"StatsComponent") as StatsComponent
	if stats == null:
		return false

	for stat_id_str in requirements:
		var stat_id := StringName(stat_id_str)
		var required_value: int = int(requirements[stat_id_str])
		var current_value := stats.get_value(stat_id, 0)

		if current_value < required_value:
			return false

	return true


## Get list of unmet requirements for UI display.
func get_unmet_requirements(entity: Entity) -> Array[Dictionary]:
	var unmet: Array[Dictionary] = []

	if requirements.is_empty():
		return unmet

	var stats: StatsComponent = entity.get_component(&"StatsComponent") as StatsComponent

	for stat_id_str in requirements:
		var stat_id := StringName(stat_id_str)
		var required_value: int = int(requirements[stat_id_str])
		var current_value := 0

		if stats:
			current_value = stats.get_value(stat_id, 0)

		if current_value < required_value:
			unmet.append({
				"stat_id": stat_id,
				"required": required_value,
				"current": current_value
			})

	return unmet

#endregion

## —————————————————————————————————————————————
#region Queries
## —————————————————————————————————————————————

## Check if this bundle modifies a specific stat
func modifies_stat(stat_id: StringName) -> bool:
	for mod in stat_modifiers:
		if mod.stat_id == stat_id:
			return true
	return false


## Check if this bundle grants a specific effect
func grants_effect(effect_id: StringName) -> bool:
	for grant in effect_grants:
		if grant.effect_id == effect_id:
			return true
	return false


## Get all modifiers for a specific stat
func get_modifiers_for_stat(stat_id: StringName) -> Array[StatModifierEntry]:
	var result: Array[StatModifierEntry] = []
	for mod in stat_modifiers:
		if mod.stat_id == stat_id:
			result.append(mod)
	return result


## Get total flat modifier for a specific stat (for preview/tooltip)
func get_stat_total(stat_id: StringName) -> int:
	var total := 0
	for mod in stat_modifiers:
		if mod.stat_id == stat_id and not mod.is_percentage:
			total += mod.amount
	return total


## Get total percentage modifier for a specific stat
func get_stat_percentage_total(stat_id: StringName) -> float:
	var total := 0.0
	for mod in stat_modifiers:
		if mod.stat_id == stat_id and mod.is_percentage:
			total += mod.amount
	return total


## Check if bundle is empty (no modifiers or effects)
func is_empty() -> bool:
	return stat_modifiers.is_empty() and effect_grants.is_empty()


## Get count of all modifiers and effects
func get_total_count() -> int:
	return stat_modifiers.size() + effect_grants.size()

#endregion

## —————————————————————————————————————————————
#region Merging / Combining
## —————————————————————————————————————————————

## Create a new bundle that combines this bundle with another.
## Useful for items with multiple modifier sources.
func merge(other: ItemModifierBundle) -> ItemModifierBundle:
	var merged := ItemModifierBundle.new()

	# Copy stat modifiers
	for mod in stat_modifiers:
		merged.stat_modifiers.append(mod)
	for mod in other.stat_modifiers:
		merged.stat_modifiers.append(mod)

	# Copy effect grants
	for grant in effect_grants:
		merged.effect_grants.append(grant)
	for grant in other.effect_grants:
		merged.effect_grants.append(grant)

	# Merge requirements (take higher value if both have same stat)
	for key in requirements:
		merged.requirements[key] = requirements[key]
	for key in other.requirements:
		if merged.requirements.has(key):
			merged.requirements[key] = maxi(
				int(merged.requirements[key]),
				int(other.requirements[key])
			)
		else:
			merged.requirements[key] = other.requirements[key]

	return merged


## Create a copy of this bundle
func duplicate_bundle() -> ItemModifierBundle:
	var copy := ItemModifierBundle.new()

	for mod in stat_modifiers:
		copy.stat_modifiers.append(mod)

	for grant in effect_grants:
		copy.effect_grants.append(grant)

	copy.requirements = requirements.duplicate()

	return copy

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	var mods_data: Array[Dictionary] = []
	for mod in stat_modifiers:
		mods_data.append(mod.to_dict())

	var grants_data: Array[Dictionary] = []
	for grant in effect_grants:
		grants_data.append(grant.to_dict())

	return {
		"stat_modifiers": mods_data,
		"effect_grants": grants_data,
		"requirements": requirements,
	}


func from_dict(data: Dictionary) -> void:
	stat_modifiers.clear()
	for mod_data in data.get("stat_modifiers", []):
		stat_modifiers.append(StatModifierEntry.from_dict(mod_data))

	effect_grants.clear()
	for grant_data in data.get("effect_grants", []):
		effect_grants.append(EffectGrant.from_dict(grant_data))

	requirements = data.get("requirements", {})


## Create from simple dictionary format (for data-driven item definitions)
## Example:
## {
##   "stats": { "skill": 2, "luck": -1 },
##   "stats_percent": { "stamina": 10 },
##   "effects": ["poison_immunity", "see_invisible"],
##   "requires": { "skill": 8 }
## }
static func from_simple(data: Dictionary) -> ItemModifierBundle:
	var bundle := ItemModifierBundle.new()

	# Parse flat stat modifiers
	var stats_data: Dictionary = data.get("stats", {})
	for stat_id_str in stats_data:
		var mod := StatModifierEntry.create(
			StringName(stat_id_str),
			int(stats_data[stat_id_str]),
			false
		)
		bundle.stat_modifiers.append(mod)

	# Parse percentage stat modifiers
	var stats_pct_data: Dictionary = data.get("stats_percent", {})
	for stat_id_str in stats_pct_data:
		var mod := StatModifierEntry.create(
			StringName(stat_id_str),
			int(stats_pct_data[stat_id_str]),
			true
		)
		bundle.stat_modifiers.append(mod)

	# Parse effects (simple string array or full dictionaries)
	var effects_data: Array = data.get("effects", [])
	for effect_entry in effects_data:
		if effect_entry is String:
			var grant := EffectGrant.create(StringName(effect_entry))
			bundle.effect_grants.append(grant)
		elif effect_entry is Dictionary:
			bundle.effect_grants.append(EffectGrant.from_dict(effect_entry))

	# Parse requirements
	bundle.requirements = data.get("requires", data.get("requirements", {}))

	return bundle

#endregion

## —————————————————————————————————————————————
#region Display / Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var parts: Array[String] = []

	for mod in stat_modifiers:
		parts.append(str(mod))

	for grant in effect_grants:
		parts.append(grant.display_name if grant.display_name else String(grant.effect_id))

	if parts.is_empty():
		return "ItemModifierBundle(empty)"

	return "ItemModifierBundle(%s)" % ", ".join(parts)


## Get a formatted string for tooltip display
func get_tooltip_text() -> String:
	var lines: Array[String] = []

	# Stat modifiers
	for mod in stat_modifiers:
		var sign := "+" if mod.amount >= 0 else ""
		var suffix := "%" if mod.is_percentage else ""
		var stat_name := String(mod.stat_id).capitalize()
		lines.append("%s%d%s %s" % [sign, mod.amount, suffix, stat_name])

	# Effects
	for grant in effect_grants:
		var name := grant.display_name if grant.display_name else String(grant.effect_id).capitalize()
		lines.append(name)

	# Requirements
	if not requirements.is_empty():
		lines.append("")
		lines.append("Requires:")
		for stat_id_str in requirements:
			var stat_name := String(stat_id_str).capitalize()
			lines.append("  %s %d" % [stat_name, requirements[stat_id_str]])

	return "\n".join(lines)


func print_debug() -> void:
	print("=== ItemModifierBundle Debug ===")
	print("  Stat Modifiers (%d):" % stat_modifiers.size())
	for mod in stat_modifiers:
		print("    %s" % mod)
	print("  Effect Grants (%d):" % effect_grants.size())
	for grant in effect_grants:
		print("    %s" % grant)
	if not requirements.is_empty():
		print("  Requirements: %s" % requirements)

#endregion