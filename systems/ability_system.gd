# AbilitySystem.gd
@abstract class_name AbilitySystem
extends GameSystem


## —————————————————————————————————————————————
#region Signals
## —————————————————————————————————————————————

signal cast_started(entity_id: String, ability_id: String)
signal cast_interrupted(entity_id: String, ability_id: String, reason: String)
signal cast_finished(entity_id: String, ability_id: String, result: Dictionary)
signal cooldowns_changed(entity_id: String)
signal resources_spent(entity_id: String, detail: Dictionary)

#endregion

@abstract func can_use(id: String, ability_id: String, ctx: Dictionary = {}) -> Dictionary
	# returns {"ok": bool, "reason": String}
	# check known, silenced, stance, weapon req, LoS/range (ask CombatSystem for targeting), cooldowns, costs

func use(id: String, ability_id: String, target: Dictionary = {}, ctx: Dictionary = {}) -> Dictionary:
	var ret_val: Dictionary = {"ok": true}
	var chk: Dictionary = can_use(id, ability_id, ctx)
	if not chk.ok:
		ret_val["ok"] = false
		ret_val["reason"] = chk.reason
	else:
		_start_cast(id, ability_id, target, ctx)
	return ret_val

func _start_cast(id: String, ability_id: String, target: Dictionary, ctx: Dictionary) -> void:
	cast_started.emit(id, ability_id)
	var cast_time := _get_cast_time(id, ability_id, ctx)
	if cast_time <= 0.0:
		_execute(id, ability_id, target, ctx)
	else:
		_set_cast_state(id, ability_id, cast_time, ctx)

func tick(delta: float) -> void:
	# advance CastState, channeling ticks, finish when time <= 0
	for id in _casting_entities():
		if _advance_cast(id, delta):
			var state := _get_cast_state(id)
			_execute(id, state.ability_id, state.target, state.ctx)

func interrupt(id: String, reason: String = "interrupted") -> void:
	if not _is_casting(id): return
	_clear_cast_state(id)
	cast_interrupted.emit(id, _last_ability(id), reason)

func _execute(id: String, ability_id: String, target: Dictionary, ctx: Dictionary) -> void:
	# 1) Pay costs & start GCD
	var paid := _pay_costs(id, ability_id, ctx)
	if not paid.ok:
		cast_interrupted.emit(id, ability_id, paid.reason)
		return
	resources_spent.emit(id, paid)

	# 2) Fire effects (one or many): damage, heal, apply_effect, summon, move, script_event
	var result: Dictionary = {}
	var parent_scene: Scene = get_parent() as Scene
	var damage_system: DamageSystem = parent_scene.get_damage_system()
	match _get_effect_type(ability_id):
		"damage":
			var packet := _build_damage_packet(id, ability_id, target, ctx)
			result.damage = damage_system.apply_damage(target.entity_id, packet)
		"heal":
			result.heal = damage_system.apply_heal(target.entity_id, _build_heal(ability_id, ctx))
		"apply_effect":
			#TODO - implement EffectsSystem
			pass
			# result.effect := EffectsSystem.apply_effect(target.entity_id, _effect_def(ability_id, ctx))
		_:
			result = _run_custom_executor(id, ability_id, target, ctx)

	# 3) Cooldowns
	_start_cooldowns(id, ability_id, ctx)
	cooldowns_changed.emit(id)

	# 4) Finish / channel maintain
	_clear_cast_state(id)
	cast_finished.emit(id, ability_id, result)

# --- abstract-ish hooks to implement in your concrete project ---
@abstract func _get_cast_time(id: String, ability_id: String, ctx: Dictionary) -> float
@abstract func _pay_costs(id: String, ability_id: String, ctx: Dictionary) -> Dictionary
@abstract func _build_damage_packet(id: String, ability_id: String, target: Dictionary, ctx: Dictionary) -> Dictionary
@abstract func _build_heal(ability_id: String, ctx: Dictionary) -> Dictionary
@abstract func _get_effect_type(ability_id: String) -> String
@abstract func _run_custom_executor(id: String, ability_id: String, target: Dictionary, ctx: Dictionary) -> Dictionary

# --- internal state helpers (backed by components you store in EntityManager) ---
@abstract func _get_cast_state(id: String) -> Dictionary
@abstract func _set_cast_state(id: String, ability_id: String, cast_time: float, ctx: Dictionary) -> void
@abstract func _advance_cast(id: String, delta: float) -> bool
@abstract func _clear_cast_state(id: String) -> void
@abstract func _is_casting(id: String) -> bool
@abstract func _last_ability(id: String) -> String
@abstract func _casting_entities() -> Array[String]
@abstract func _start_cooldowns(id: String, ability_id: String, ctx: Dictionary) -> void
