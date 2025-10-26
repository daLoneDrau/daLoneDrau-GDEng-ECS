@abstract class_name PlayerSystem
extends GameSystem


## —————————————————————————————————————————————
#region Signals
## —————————————————————————————————————————————

signal stats_changed(entity_id: String)
signal resources_changed(entity_id: String)
signal effects_changed(entity_id: String)
signal cooldowns_changed(entity_id: String)
signal equipment_changed(entity_id: String)
signal inventory_changed(entity_id: String)
signal quest_flag_changed(entity_id: String, key: String)
signal death_state_changed(entity_id: String, is_dead: bool)

#endregion

var _recompute_queued_for: Dictionary = {}  # {entity_id: true}

func _enter_tree() -> void:
	if is_instance_valid(Switchboard_auto):
		Switchboard_auto.connect_subscriber(self, "damage_applied", _on_damage_applied)
		Switchboard_auto.connect_subscriber(self, "heal_applied", _on_heal_applied)
		Switchboard_auto.connect_subscriber(self, "death_state_changed", _on_death_changed)
		Switchboard_auto.connect_subscriber(self, "equipment_changed", _on_equipment_changed)


func _exit_tree() -> void:
	_recompute_queued_for.clear()
	
	if is_instance_valid(Switchboard_auto):
		Switchboard_auto.remove_from_waitlist("damage_applied", _on_damage_applied)
		Switchboard_auto.remove_from_waitlist("heal_applied", _on_heal_applied)
		Switchboard_auto.remove_from_waitlist("death_state_changed", _on_death_changed)
		Switchboard_auto.remove_from_waitlist("equipment_changed", _on_equipment_changed)


## —————————————————————————————————————————————
#region Abstract API
## —————————————————————————————————————————————

## —————————————————————————————————————————————
#region Skills
## —————————————————————————————————————————————


## Applies any skill modifiers.
@abstract func apply_skill_modifiers(_entity_id: String) -> void


## Applies any skill percentage modifiers.
@abstract func apply_skill_percentage_modifiers(_entity_id: String) -> void


## Clears any skill modifiers applied.
@abstract func clear_skill_modifiers(_entity_id: String) -> void

#endregion

## —————————————————————————————————————————————
#region Spells
## —————————————————————————————————————————————


## Applies any spell modifiers.
@abstract func apply_spell_modifiers(_entity_id: String) -> void


## Optional: clear spell modifiers (mirrors your clear_skill_modifiers).
@abstract func clear_spell_modifiers(_entity_id: String) -> void

#endregion

## —————————————————————————————————————————————
#region Stats
## —————————————————————————————————————————————


## Compute full stats (if you want a single-call façade).
func compute_full_stats(_entity_id: String) -> void:
	recompute_all(_entity_id)


## Computes secondary statistic values that should be calculated before modifiers are applied, such as max life, mana, poison resistance, etc...
@abstract func compute_secondary_stats(_entity_id: String) -> void


## Clamp to caps, compute deriveds that depend on the full pipeline (e.g., final speed).
@abstract func finalize_stats(_entity_id: String) -> void

#endregion

## —————————————————————————————————————————————
#region Equipment / Effects / Situational
## —————————————————————————————————————————————

## Buff/debuff/aura/corrosion/poison, etc.
@abstract func apply_effect_modifiers(_entity_id: String) -> void

## Equipment-only modifiers (hook into your EquipmentItemModifiers).
@abstract func apply_equipment_modifiers(_entity_id: String) -> void

## Posture, stance, cover, height, weather, time-of-day, party auras.
@abstract func apply_situational_modifiers(_entity_id: String) -> void

## Clears any transient modifiers besides skills/spells (effects, temp overrides).
@abstract func clear_transient_modifiers(_entity_id: String) -> void


func _on_equipment_changed(entity_id: StringName) -> void:
	recompute_all(entity_id)

## compute ability cooldowns
@abstract func get_effective_cooldown(entity_id: StringName, ability_id: StringName, base_seconds: float) -> float
#   var mods := _get_equipment_mods(entity_id)
#	var cd_map: Dictionary = mods.get("cooldown_mods", {})
#	var delta := float(cd_map.get(String(ability_id), 0.0))   # e.g., -0.10 for -10%
#	return max(0.0, base_seconds * (1.0 + delta))

@abstract func meets_item_requirements(entity_id: StringName, req: Dictionary) -> bool
# 	var level := int(_get_level(entity_id))
#	var attrs: Dictionary = _get_attributes(entity_id)   # e.g., { power, aim, speed, health }
#	var tags: Array[StringName] = _get_player_tags(entity_id)
#	var gender := int(_get_gender(entity_id))
#
#	if level < int(req.get("min_level", 0)):
#		return false
#	for k in req.get("attributes", {}):
#		if int(attrs.get(k, 0)) < int(req["attributes"][k]): return false
#	for t in req.get("tags_required", []):
#		if not tags.has(t): return false
#	for t in req.get("tags_forbidden", []):
#		if tags.has(t): return false
#	var g := int(req.get("gender", -1))
#	return (g == -1 or g == gender)

#endregion

## —————————————————————————————————————————————
#region Death flow
## —————————————————————————————————————————————


func _on_damage_applied(entity_id: String, _result: Dictionary) -> void:
	if _is_player(entity_id):
		resources_changed.emit(entity_id)
		# perk procs, shake, SFX, logs, conditional recompute if effects changed


func _on_heal_applied(entity_id: String, _result: Dictionary) -> void:
	if _is_player(entity_id):
		resources_changed.emit(entity_id)


func _on_death_changed(entity_id: String, is_dead: bool) -> void:
	if _is_player(entity_id) and is_dead:
		becomes_dead(entity_id)
		# Keep this emit ONLY if your UI listens to PlayerSystem.
		death_state_changed.emit(entity_id, true)


## Called When player has just died.
@abstract func becomes_dead(_entity_id: String) -> void


## Determines if a player is dead.
@abstract func is_player_dead(_entity_id: String) -> bool

@abstract func try_rest(entity_id: String) -> bool

#endregion

## —————————————————————————————————————————————
#region PROGRESSION
## —————————————————————————————————————————————


@abstract func grant_xp(entity_id: String, amount: int) -> void

#endregion

## —————————————————————————————————————————————
#region QUESTS & FLAGS
## —————————————————————————————————————————————


@abstract func set_flag(entity_id: String, key: String, value) -> void

@abstract func get_flag(entity_id: String, key: String, default_val = null) -> Variant

#endregion

#endregion

## Call this whenever inventory/equipment/effects change (or on load).
func recompute_all(entity_id: String) -> void:
	if not _recompute_queued_for.has(entity_id):
		_recompute_queued_for[entity_id] = true
		call_deferred("_recompute_now", entity_id)

## Re-computes player ability scores and skills.
func _recompute_now(entity_id: String) -> void:
	_recompute_queued_for.erase(entity_id)

	# 1) Reset transient math
	clear_skill_modifiers(entity_id)
	clear_spell_modifiers(entity_id)
	clear_transient_modifiers(entity_id)

	# 2) Base & secondary (pre-modifier) compute
	compute_secondary_stats(entity_id)

	# 3) Additive/Multiplicative layers in a fixed order
	apply_equipment_modifiers(entity_id)          # items/gear only
	apply_skill_modifiers(entity_id)              # flat skill bonuses
	apply_spell_modifiers(entity_id)              # flat spell buffs
	apply_effect_modifiers(entity_id)             # buffs/debuffs/aura tags
	apply_skill_percentage_modifiers(entity_id)   # % skill-based scaling
	apply_situational_modifiers(entity_id)        # terrain, posture, weather, etc.

	# 4) Clamp/caps/derived
	finalize_stats(entity_id)

	stats_changed.emit(entity_id)

	# If something re-queued during the pipeline, run again next idle
	if _recompute_queued_for.has(entity_id) and not Engine.is_editor_hint():
		call_deferred("_recompute_now", entity_id)


func recompute_after_load(entity_ids: Array[String]) -> void:
	for id in entity_ids:
		clear_skill_modifiers(id)
		clear_spell_modifiers(id)
		clear_transient_modifiers(id)
		compute_secondary_stats(id)
		apply_equipment_modifiers(id)
		apply_skill_modifiers(id)
		apply_spell_modifiers(id)
		apply_effect_modifiers(id)
		apply_skill_percentage_modifiers(id)
		apply_situational_modifiers(id)
		finalize_stats(id)
		stats_changed.emit(id)


## —————————————————————————————————————————————
#region RUNTIME / TICK HOOKS
## —————————————————————————————————————————————

## Handle durations, expirations; emit effects_changed as needed.
@abstract func _tick_effects(_entity_id: String, delta: float) -> void


## Handle item/ability cooldowns; emit cooldowns_changed as needed.
@abstract func _tick_cooldowns(_entity_id: String, delta: float) -> void


## Regen/degeneration for HP/MP/Stamina/O₂/etc.; emit resources_changed.
@abstract func _tick_regen(_entity_id: String, delta: float) -> void


## Per-frame or per-tick hook from GameSystem
func on_tick(delta: float) -> void:
	for id in _players():
		if id == "" or not _is_player(id):
			continue

		_tick_regen(id, delta)
		_tick_effects(id, delta)
		_tick_cooldowns(id, delta)

#endregion


## —————————————————————————————————————————————
#region HELPERS
## —————————————————————————————————————————————


## Return list of player entity ids (query your EntityManager Player tag/component).
@abstract func _players() -> Array[String]

@abstract func _is_player(id: String) -> bool

func _focused_player_id() -> String:
	# Override if multiple players; otherwise return the sole player id
	var ids: Array[String] = _players()
	return ids[0] if ids.size() > 0 else ""

#endregion
