## Tracks active effects on an entity (buffs, debuffs, immunities, etc.)
## Examples: Poison, Bless, Poison Immunity, Rage, Invisibility
class_name EffectsComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when an effect is added
## Parameters: entity_id, effect_id, source_id, stacks
signal effect_added(entity_id: String, effect_id: StringName, source_id: StringName, stacks: int)

## Emitted when an effect is removed
## Parameters: entity_id, effect_id, source_id, reason
signal effect_removed(entity_id: String, effect_id: StringName, source_id: StringName, reason: StringName)

## Emitted when an effect's stacks change
## Parameters: entity_id, effect_id, old_stacks, new_stacks
signal effect_stacks_changed(entity_id: String, effect_id: StringName, old_stacks: int, new_stacks: int)

## Emitted when an effect ticks (for DoT, HoT, etc.)
## Parameters: entity_id, effect_id, tick_data
signal effect_ticked(entity_id: String, effect_id: StringName, tick_data: Dictionary)

## Emitted when any effect changes (for general UI updates)
## Parameters: entity_id
signal effects_changed(entity_id: String)

## Active effects keyed by effect_id
## Each entry is an ActiveEffect instance
var _active_effects: Dictionary[StringName, ActiveEffect] = {}


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init() -> void:
	super()
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"effect_added",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"effect_removed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"effect_stacks_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"effect_ticked",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"effects_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "effect_added")
	Switchboard_auto.remove_resource_broadcaster(self, "effect_removed")
	Switchboard_auto.remove_resource_broadcaster(self, "effect_stacks_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "effect_ticked")
	Switchboard_auto.remove_resource_broadcaster(self, "effects_changed")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)


func on_removed(entity: Entity, em: EntityManager) -> void:
	# Clear all effects when component is removed
	clear_all_effects(&"component_removed")
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()

#endregion

## —————————————————————————————————————————————
#region Effect Management
## —————————————————————————————————————————————

## Apply an effect from an EffectGrant definition.
## source_id: Who/what applied this effect (item entity ID, spell ID, etc.)
## Returns true if effect was applied (may be false if ignored due to immunity or stack rules)
func apply_effect(grant: EffectGrant, source_id: StringName) -> bool:
	if grant == null or grant.effect_id == &"":
		push_warning("EffectsComponent: Cannot apply null or empty effect")
		return false

	var effect_id := grant.effect_id

	# Check for immunity
	if has_immunity_to(effect_id):
		return false

	# Handle existing effect
	if _active_effects.has(effect_id):
		return _handle_existing_effect(grant, source_id)

	# Create new active effect
	var active := ActiveEffect.new()
	active.effect_id = effect_id
	active.source_id = source_id
	active.display_name = grant.display_name
	active.description = grant.description
	active.icon_id = grant.icon_id
	active.duration_type = grant.duration_type
	active.duration_remaining = grant.duration_seconds
	active.uses_remaining = grant.uses
	active.params = grant.params.duplicate()
	active.stack_behavior = grant.stack_behavior
	active.max_stacks = grant.max_stacks
	active.stacks = 1
	active.applied_at = Time.get_ticks_msec()

	_active_effects[effect_id] = active

	effect_added.emit(parent_entity_id, effect_id, source_id, 1)
	effects_changed.emit(parent_entity_id)
	emit_update_signal()

	return true


## Apply effect using simple parameters (convenience method)
func apply_simple_effect(
	effect_id: StringName,
	source_id: StringName,
	display_name: String = "",
	duration_type: EffectGrant.DurationType = EffectGrant.DurationType.PERMANENT,
	duration_seconds: float = 0.0,
	params: Dictionary = {}
) -> bool:
	var grant := EffectGrant.new()
	grant.effect_id = effect_id
	grant.display_name = display_name if display_name else String(effect_id).capitalize()
	grant.duration_type = duration_type
	grant.duration_seconds = duration_seconds
	grant.params = params
	return apply_effect(grant, source_id)


## Handle applying effect when one already exists
func _handle_existing_effect(grant: EffectGrant, source_id: StringName) -> bool:
	var active: ActiveEffect = _active_effects[grant.effect_id]
	var old_stacks := active.stacks

	match grant.stack_behavior:
		EffectGrant.StackBehavior.IGNORE:
			return false

		EffectGrant.StackBehavior.REPLACE:
			# Remove old and apply new
			_remove_effect_internal(grant.effect_id, &"replaced")
			return apply_effect(grant, source_id)

		EffectGrant.StackBehavior.REFRESH:
			# Reset duration, keep stacks
			active.duration_remaining = grant.duration_seconds
			active.uses_remaining = grant.uses
			active.source_id = source_id  # Update source
			effects_changed.emit(parent_entity_id)
			emit_update_signal()
			return true

		EffectGrant.StackBehavior.STACK:
			# Add stack up to max
			if active.stacks < active.max_stacks:
				active.stacks += 1
				active.source_id = source_id  # Update to latest source
				# Optionally refresh duration on stack
				if grant.duration_seconds > 0:
					active.duration_remaining = grant.duration_seconds
				effect_stacks_changed.emit(parent_entity_id, grant.effect_id, old_stacks, active.stacks)
				effects_changed.emit(parent_entity_id)
				emit_update_signal()
				return true
			return false

	return false


## Remove an effect by ID
## reason: Why it's being removed (e.g., "expired", "dispelled", "unequipped")
func remove_effect(effect_id: StringName, reason: StringName = &"removed") -> bool:
	return _remove_effect_internal(effect_id, reason)


func _remove_effect_internal(effect_id: StringName, reason: StringName) -> bool:
	if not _active_effects.has(effect_id):
		return false

	var active: ActiveEffect = _active_effects[effect_id]
	var source_id := active.source_id

	_active_effects.erase(effect_id)

	effect_removed.emit(parent_entity_id, effect_id, source_id, reason)
	effects_changed.emit(parent_entity_id)
	emit_update_signal()

	return true


## Remove all effects from a specific source (e.g., when item is unequipped)
func remove_effects_from_source(source_id: StringName, reason: StringName = &"source_removed") -> int:
	var to_remove: Array[StringName] = []

	for effect_id in _active_effects:
		if _active_effects[effect_id].source_id == source_id:
			to_remove.append(effect_id)

	for effect_id in to_remove:
		_remove_effect_internal(effect_id, reason)

	return to_remove.size()


## Remove all effects matching a tag/category
func remove_effects_by_tag(tag: StringName, reason: StringName = &"tag_cleared") -> int:
	var to_remove: Array[StringName] = []

	for effect_id in _active_effects:
		var active: ActiveEffect = _active_effects[effect_id]
		if active.has_tag(tag):
			to_remove.append(effect_id)

	for effect_id in to_remove:
		_remove_effect_internal(effect_id, reason)

	return to_remove.size()


## Clear all effects
func clear_all_effects(reason: StringName = &"cleared") -> void:
	var effect_ids := _active_effects.keys().duplicate()
	for effect_id in effect_ids:
		_remove_effect_internal(effect_id, reason)


## Reduce stacks of an effect. Removes if stacks reach 0.
func reduce_stacks(effect_id: StringName, amount: int = 1) -> bool:
	if not _active_effects.has(effect_id):
		return false

	var active: ActiveEffect = _active_effects[effect_id]
	var old_stacks := active.stacks
	active.stacks = maxi(0, active.stacks - amount)

	if active.stacks <= 0:
		_remove_effect_internal(effect_id, &"stacks_depleted")
	else:
		effect_stacks_changed.emit(parent_entity_id, effect_id, old_stacks, active.stacks)
		effects_changed.emit(parent_entity_id)
		emit_update_signal()

	return true


## Consume a use of an effect. Removes if uses reach 0.
func consume_use(effect_id: StringName) -> bool:
	if not _active_effects.has(effect_id):
		return false

	var active: ActiveEffect = _active_effects[effect_id]

	if active.duration_type != EffectGrant.DurationType.USES:
		return false

	active.uses_remaining -= 1

	if active.uses_remaining <= 0:
		_remove_effect_internal(effect_id, &"uses_depleted")
	else:
		effects_changed.emit(parent_entity_id)
		emit_update_signal()

	return true

#endregion

## —————————————————————————————————————————————
#region Queries
## —————————————————————————————————————————————

## Check if entity has a specific effect active
func has_effect(effect_id: StringName) -> bool:
	return _active_effects.has(effect_id)


## Check if entity has any effect from a specific source
func has_effect_from_source(source_id: StringName) -> bool:
	for active in _active_effects.values():
		if active.source_id == source_id:
			return true
	return false


## Get an active effect by ID (returns null if not found)
func get_effect(effect_id: StringName) -> ActiveEffect:
	return _active_effects.get(effect_id)


## Get all active effect IDs
func get_effect_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_active_effects.keys())
	return ids


## Get all active effects
func get_all_effects() -> Array[ActiveEffect]:
	var effects: Array[ActiveEffect] = []
	for active in _active_effects.values():
		effects.append(active)
	return effects


## Get effects from a specific source
func get_effects_from_source(source_id: StringName) -> Array[ActiveEffect]:
	var effects: Array[ActiveEffect] = []
	for active in _active_effects.values():
		if active.source_id == source_id:
			effects.append(active)
	return effects


## Get current stack count for an effect (0 if not active)
func get_stacks(effect_id: StringName) -> int:
	var active := get_effect(effect_id)
	return active.stacks if active else 0


## Get effect parameter value
func get_effect_param(effect_id: StringName, param_key: String, default: Variant = null) -> Variant:
	var active := get_effect(effect_id)
	if active:
		return active.params.get(param_key, default)
	return default


## Get number of active effects
func get_effect_count() -> int:
	return _active_effects.size()


## Check if entity has no active effects
func is_empty() -> bool:
	return _active_effects.is_empty()

#endregion

## —————————————————————————————————————————————
#region Immunity System
## —————————————————————————————————————————————

## Common immunity effect IDs (convention: effect_id + "_immunity")
## Example: "poison" effect is blocked by "poison_immunity" effect

## Check if entity is immune to an effect
func has_immunity_to(effect_id: StringName) -> bool:
	var immunity_id := StringName(String(effect_id) + "_immunity")
	return has_effect(immunity_id)


## Grant immunity to an effect
func grant_immunity(effect_id: StringName, source_id: StringName, duration_type: EffectGrant.DurationType = EffectGrant.DurationType.PERMANENT, duration_seconds: float = 0.0) -> bool:
	var immunity_id := StringName(String(effect_id) + "_immunity")
	return apply_simple_effect(
		immunity_id,
		source_id,
		"%s Immunity" % String(effect_id).capitalize(),
		duration_type,
		duration_seconds,
			{ "immunity_to": effect_id }
	)


## Remove immunity to an effect
func remove_immunity(effect_id: StringName, reason: StringName = &"removed") -> bool:
	var immunity_id := StringName(String(effect_id) + "_immunity")
	return remove_effect(immunity_id, reason)

#endregion

## —————————————————————————————————————————————
#region Time/Tick Processing (called by EffectsSystem)
## —————————————————————————————————————————————

## Process time passage for timed effects. Returns effects that expired.
func tick_time(delta: float) -> Array[StringName]:
	var expired: Array[StringName] = []

	for effect_id in _active_effects:
		var active: ActiveEffect = _active_effects[effect_id]

		if active.duration_type != EffectGrant.DurationType.TIMED:
			continue

		active.duration_remaining -= delta

		if active.duration_remaining <= 0:
			expired.append(effect_id)

	# Remove expired effects
	for effect_id in expired:
		_remove_effect_internal(effect_id, &"expired")

	return expired


## Process periodic tick for DoT/HoT effects. Returns tick data for each effect that ticked.
func tick_periodic(delta: float) -> Array[Dictionary]:
	var tick_results: Array[Dictionary] = []

	for effect_id in _active_effects:
		var active: ActiveEffect = _active_effects[effect_id]

		var tick_interval: float = active.params.get("tick_interval", 0.0)
		if tick_interval <= 0:
			continue

		active.tick_accumulator += delta

		while active.tick_accumulator >= tick_interval:
			active.tick_accumulator -= tick_interval
			active.tick_count += 1

			var tick_data := {
				"effect_id": effect_id,
				"stacks": active.stacks,
				"tick_count": active.tick_count,
				"params": active.params
			}

			tick_results.append(tick_data)
			effect_ticked.emit(parent_entity_id, effect_id, tick_data)

	return tick_results


## Called when combat ends (removes END_OF_COMBAT effects)
func on_combat_end() -> void:
	var to_remove: Array[StringName] = []

	for effect_id in _active_effects:
		var active: ActiveEffect = _active_effects[effect_id]
		if active.duration_type == EffectGrant.DurationType.END_OF_COMBAT:
			to_remove.append(effect_id)

	for effect_id in to_remove:
		_remove_effect_internal(effect_id, &"combat_ended")

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	var effects_data: Array[Dictionary] = []
	for effect_id in _active_effects:
		effects_data.append(_active_effects[effect_id].to_dict())

	return {
		"key": get_class_name(),
		"enabled": enabled,
		"effects": effects_data
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	_active_effects.clear()

	for effect_data in data.get("effects", []):
		var active := ActiveEffect.from_dict(effect_data)
		if active.effect_id != &"":
			_active_effects[active.effect_id] = active

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	if _active_effects.is_empty():
		return "EffectsComponent[%s](empty)" % parent_entity_id

	var effect_names: Array[String] = []
	for active in _active_effects.values():
		var name_str: String = active.display_name if active.display_name else String(active.effect_id)
		if active.stacks > 1:
			name_str += " x%d" % active.stacks
		effect_names.append(name_str)

	return "EffectsComponent[%s](%s)" % [parent_entity_id, ", ".join(effect_names)]


func print_debug() -> void:
	print("=== EffectsComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Active Effects (%d):" % _active_effects.size())

	for effect_id in _active_effects:
		var active: ActiveEffect = _active_effects[effect_id]
		print("    %s:" % effect_id)
		print("      Display: %s" % active.display_name)
		print("      Source: %s" % active.source_id)
		print("      Stacks: %d / %d" % [active.stacks, active.max_stacks])
		print("      Duration: %s" % _format_duration(active))
		if not active.params.is_empty():
			print("      Params: %s" % active.params)


func _format_duration(active: ActiveEffect) -> String:
	match active.duration_type:
		EffectGrant.DurationType.PERMANENT:
			return "Permanent"
		EffectGrant.DurationType.TIMED:
			return "%.1fs remaining" % active.duration_remaining
		EffectGrant.DurationType.USES:
			return "%d uses remaining" % active.uses_remaining
		EffectGrant.DurationType.END_OF_COMBAT:
			return "Until combat ends"
		EffectGrant.DurationType.CONDITIONAL:
			return "Conditional"
	return "Unknown"


## Get summary for UI display
func get_summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for effect_id in _active_effects:
		var active: ActiveEffect = _active_effects[effect_id]
		result.append({
			"entity_id": parent_entity_id,
			"effect_id": effect_id,
			"display_name": active.display_name,
			"description": active.description,
			"icon_id": active.icon_id,
			"stacks": active.stacks,
			"max_stacks": active.max_stacks,
			"duration_type": active.duration_type,
			"duration_remaining": active.duration_remaining,
			"uses_remaining": active.uses_remaining,
			"source_id": active.source_id,
		})

	return result

	#endregion