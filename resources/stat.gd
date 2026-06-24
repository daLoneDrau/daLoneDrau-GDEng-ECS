## Defines a single stat/ability score with base value and tracked modifiers.
## Examples: Strength, Skill, Stamina, Luck, Lockpicking, Perception
class_name Stat
extends Resource

signal value_changed(old_value: int, new_value: int)
signal base_changed(old_base: int, new_base: int)
signal modifiers_changed()

## The unmodified base value
@export var base_value: int = 0:
	set(value):
		if base_value == value:
			return
		var old := base_value
		base_value = value
		base_changed.emit(old, base_value)
		_recalculate()

## Bounds (-1 = unbounded)
@export var min_value: int = 0
@export var max_value: int = -1

## Cached computed total
var _cached_total: int = 0

## All registered modifiers by source_id
var _modifiers: Dictionary[StringName, StatModifierEntry] = {}


var total: int:
	get:
		return _cached_total


## Alias for total
var value: int:
	get:
		return _cached_total


func _init(initial_base: int = 0) -> void:
	base_value = initial_base
	_cached_total = initial_base


## Add or replace a modifier from a source.
func add_modifier_entry(entry: StatModifierEntry) -> void:
	if entry.source_id == &"":
		push_warning("Stat: Cannot add modifier with empty source_id")
		return

	_modifiers[entry.source_id] = entry
	modifiers_changed.emit()
	_recalculate()


## Convenience: add a simple flat modifier
func add_modifier(source_id: StringName, amount: int, is_percentage: bool = false, stack_group: StringName = &"") -> void:
	var entry := StatModifierEntry.create(source_id, amount, is_percentage, stack_group)
	add_modifier_entry(entry)


## Remove modifier by source. Returns true if found.
func remove_modifier(source_id: StringName) -> bool:
	if _modifiers.erase(source_id):
		modifiers_changed.emit()
		_recalculate()
		return true
	return false


## Remove all modifiers matching a stack group
func remove_modifiers_in_group(stack_group: StringName) -> int:
	var removed := 0
	var to_remove: Array[StringName] = []

	for source_id in _modifiers:
		if _modifiers[source_id].stack_group == stack_group:
			to_remove.append(source_id)

	for source_id in to_remove:
		_modifiers.erase(source_id)
		removed += 1

	if removed > 0:
		modifiers_changed.emit()
		_recalculate()

	return removed


func has_modifier(source_id: StringName) -> bool:
	return _modifiers.has(source_id)


func get_modifier(source_id: StringName) -> StatModifierEntry:
	return _modifiers.get(source_id)


func clear_modifiers() -> void:
	if _modifiers.is_empty():
		return
	_modifiers.clear()
	modifiers_changed.emit()
	_recalculate()


func get_modifiers() -> Dictionary[StringName, StatModifierEntry]:
	return _modifiers.duplicate()


func get_modifier_sources() -> Array[StringName]:
	var sources: Array[StringName] = []
	sources.assign(_modifiers.keys())
	return sources


## Calculate effective modifiers considering stack groups.
## Returns { "flat": int, "percentage": float }
func _calculate_effective_modifiers() -> Dictionary:
	# Group modifiers by stack_group
	# Empty stack_group = always applies
	# Non-empty stack_group = only highest in group applies

	var ungrouped_flat := 0
	var ungrouped_pct := 0.0

	# stack_group -> { "flat": best_flat_entry, "pct": best_pct_entry }
	var grouped: Dictionary[StringName, Dictionary] = {}

	for entry in _modifiers.values():
		if entry.stack_group == &"":
			# No group - always stacks
			if entry.is_percentage:
				ungrouped_pct += entry.amount
			else:
				ungrouped_flat += entry.amount
		else:
			# Has group - track best per group
			if not grouped.has(entry.stack_group):
				grouped[entry.stack_group] = {"flat": null, "pct": null}

			var group_data: Dictionary = grouped[entry.stack_group]

			if entry.is_percentage:
				var current: StatModifierEntry = group_data["pct"]
				if current == null or entry.amount > current.amount:
					group_data["pct"] = entry
			else:
				var current: StatModifierEntry = group_data["flat"]
				if current == null or entry.amount > current.amount:
					group_data["flat"] = entry

	# Sum up the best from each group
	var grouped_flat := 0
	var grouped_pct := 0.0

	for group_data in grouped.values():
		var flat_entry: StatModifierEntry = group_data["flat"]
		var pct_entry: StatModifierEntry = group_data["pct"]
		if flat_entry:
			grouped_flat += flat_entry.amount
		if pct_entry:
			grouped_pct += pct_entry.amount

	return {
		"flat": ungrouped_flat + grouped_flat,
		"percentage": ungrouped_pct + grouped_pct
	}


func _recalculate() -> void:
	var old_total := _cached_total

	var effective := _calculate_effective_modifiers()
	var flat_total: int = effective["flat"]
	var pct_total: float = effective["percentage"]

	# Apply: (base + flat) * (1 + pct/100)
	var computed := base_value + flat_total
	if pct_total != 0.0:
		computed = int(float(computed) * (1.0 + pct_total / 100.0))

	# Clamp to bounds
	if min_value > -999999:  # Treat very negative as "no minimum"
		computed = maxi(computed, min_value)
	if max_value >= 0:
		computed = mini(computed, max_value)

	_cached_total = computed

	if old_total != _cached_total:
		value_changed.emit(old_total, _cached_total)


## Get breakdown for UI/debugging
func get_breakdown() -> Dictionary:
	var effective := _calculate_effective_modifiers()
	return {
		"base": base_value,
		"flat_modifiers": effective["flat"],
		"percentage_modifiers": effective["percentage"],
		"total": _cached_total,
		"modifier_count": _modifiers.size(),
		"bounds": {"min": min_value, "max": max_value}
	}


func _to_string() -> String:
	var breakdown := get_breakdown()
	var parts: Array[String] = ["%d base" % base_value]

	if breakdown["flat_modifiers"] != 0:
		parts.append("%+d flat" % breakdown["flat_modifiers"])
	if breakdown["percentage_modifiers"] != 0.0:
		parts.append("%+.0f%%" % breakdown["percentage_modifiers"])

	return "Stat(%s = %d)" % [", ".join(parts), _cached_total]


func to_dict() -> Dictionary:
	var mods: Array[Dictionary] = []
	for source_id in _modifiers:
		mods.append(_modifiers[source_id].to_dict())

	return {
		"base": base_value,
		"min": min_value,
		"max": max_value,
		"modifiers": mods
	}


func from_dict(data: Dictionary) -> void:
	min_value = data.get("min", 0)
	max_value = data.get("max", -1)
	_modifiers.clear()

	for mod_data in data.get("modifiers", []):
		var entry := StatModifierEntry.from_dict(mod_data)
		if entry.source_id != &"":
			_modifiers[entry.source_id] = entry

	# Set base last to trigger recalculation
	base_value = data.get("base", 0)
