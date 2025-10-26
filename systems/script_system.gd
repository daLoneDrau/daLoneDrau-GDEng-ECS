# res://ecs/systems/script_system.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Central ECS system responsible for managing entity-bound logic scripts.
## - Detects ScriptComponents when entities are added and instantiates their
##   EntityScript logic (main/master scripts).
## - Injects context references (entity_id, EntityManager, ScriptVariableSet).
## - Dispatches all ScriptEvent signals to subscribed scripts.
## - Supports both direct and generic ("script_event") signal entry points.
## - Handles multi-target events (explicit lists, groups, radius filters).
## - Maintains per-entity caches for fast dispatch and safe detach.
## In short: ScriptSystem is the runtime “conductor” that gives life to
## data-driven entity behavior through event-driven scripting.
@abstract class_name ScriptSystem
extends GameSystem


signal script_event(ctx: Dictionary)


# entity_id -> {instances, per_inst_subs, merged_subs}
var _cache: Dictionary = {}


## —————————————————————————————————————————————
#region System References. will be set in concrete implementations using Autoload instances
## —————————————————————————————————————————————

## the [EntityManager] instance
var _entity_manager: EntityManager

## the [PlayerSystem] instance
var _player_system: PlayerSystem

#endregion

## —————————————————————————————————————————————
#region Setup
## —————————————————————————————————————————————


func _enter_tree() -> void:
	if is_instance_valid(Switchboard_auto):
		# Generic unified event
		Switchboard_auto.connect_subscriber(self, "script_event", _on_script_event)

func _exit_tree() -> void:
	for id in _cache.keys():
		_detach_scripts(id)
	_cache.clear()

func on_entity_added(entity_id: StringName) -> void:
	_attach_scripts(entity_id)

func on_entity_removed(entity_id: StringName) -> void:
	_detach_scripts(entity_id)

#endregion


## —————————————————————————————————————————————
#region Script attachment lifecycle
## —————————————————————————————————————————————


func _attach_scripts(entity_id: StringName) -> void:
	if not _entity_manager or not _entity_manager.has_component(entity_id, ScriptComponent):
		return

	var sc: ScriptComponent = _entity_manager.get_component(entity_id, ScriptComponent) as ScriptComponent
	if not sc or not sc.enabled or not sc.has_any_scripts():
		return

	var instances: Array[EntityScript] = []
	var per_inst_subs: Array = []
	var merged: Dictionary = {}

	for script_class: Script in sc.get_script_chain():
		if script_class == null:
			continue
		var inst = script_class.new()
		if not (inst is EntityScript):
			push_warning("ScriptSystem: Script on %s not extending EntityScript: %s" % [str(entity_id), str(script_class)])
			continue

		inst.parent_component = sc
		inst.is_master = (script_class == sc.master_script)

		inst.on_attach(entity_id, _entity_manager)
		var subs: Array[int] = inst.subscribed_events()
		instances.append(inst)
		per_inst_subs.append(subs)
		for ev in subs:
			merged[ev] = true

	_cache[entity_id] = {
		"instances": instances,
		"per_inst_subs": per_inst_subs,
		"merged_subs": merged,
	}


func _detach_scripts(entity_id: StringName) -> void:
	if not _cache.has(entity_id):
		return
	var data = _cache[entity_id]
	for inst in data.get("instances", []):
		if inst and (inst is EntityScript):
			inst.on_detach()
	_cache.erase(entity_id)


func refresh_entity(entity_id: StringName) -> void:
	_detach_scripts(entity_id)
	_attach_scripts(entity_id)


## Generic script_event dispatcher (multi-target).
func _on_script_event(payload: Dictionary) -> void:
	var ev_type := int(payload.get("event_type", ScriptEvent.NONE))
	var source_id: StringName = payload.get("source_id", StringName())
	if ev_type == ScriptEvent.NONE or source_id == StringName():
		push_warning("ScriptSystem: invalid script_event payload: %s" % str(payload))
		return

	var targets: Array[StringName] = _resolve_targets(payload, source_id)
	if targets.is_empty():
		targets = [source_id]

	for tid in targets:
		var ctx := payload.duplicate(true)
		ctx["target_id"] = tid
		_dispatch(tid, ev_type, ctx)

#endregion


## —————————————————————————————————————————————
#region Target resolution (groups, radius, filters)
## —————————————————————————————————————————————


func _resolve_targets(payload: Dictionary, source_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var seen := {}

	if payload.has("targets"):
		for eid in payload["targets"]:
			var id: StringName = eid if (eid is StringName) else StringName(eid)
			if id != StringName() and not seen.has(id):
				seen[id] = true
				out.append(id)

	var group: StringName = payload.get("target_group", StringName())
	if group != StringName():
		for id in _find_entities_in_group(group):
			if not seen.has(id):
				seen[id] = true
				out.append(id)

	var radius := int(payload.get("radius", -1))
	if radius >= 0:
		out = _filter_by_radius(out, source_id, radius)

	var filter: Dictionary = payload.get("filter", {})
	out = _apply_filters(out, filter)

	if payload.get("exclude_source", true):
		var filtered: Array[StringName] = []
		for id in out:
			if id != source_id:
				filtered.append(id)
		out = filtered

	return out

func _find_entities_in_group(group_name: StringName) -> Array[StringName]:
	var results: Array[StringName] = []
	if not _entity_manager:
		return results
	for id in _entity_manager.get_all_entities():
		if _entity_manager.has_component(id, PartyComponent):
			var pc: PartyComponent = _entity_manager.get_component(id, PartyComponent) as PartyComponent
			if pc.group_name == group_name or pc.party_id == group_name:
				results.append(id)
	return results

func _filter_by_radius(ids: Array[StringName], source_id: StringName, radius: int) -> Array[StringName]:
	if radius < 0 or not _entity_manager:
		return ids
	if not _entity_manager.has_component(source_id, PositionComponent):
		return ids
	var src = _entity_manager.get_component(source_id, PositionComponent)
	var out: Array[StringName] = []
	for id in ids:
		if _entity_manager.has_component(id, PositionComponent):
			var p: PositionComponent = _entity_manager.get_component(id, PositionComponent)
			if _within_radius(src, p, radius):
				out.append(id)
	return out

@abstract func _within_radius(a, b, radius: int) -> bool

func _apply_filters(ids: Array[StringName], filter: Dictionary) -> Array[StringName]:
	if not _entity_manager:
		return ids
	var include_tags: PackedStringArray = filter.get("include_tags", PackedStringArray())
	var exclude_tags: PackedStringArray = filter.get("exclude_tags", PackedStringArray())
	var need_components: PackedStringArray = filter.get("has_components", PackedStringArray())

	var out: Array[StringName] = []
	for id in ids:
		var ok := true
		for c in need_components:
			if not _entity_manager.has_component(id, c):
				ok = false; break

		if ok and (include_tags.size() > 0 or exclude_tags.size() > 0):
			var tags := _collect_tags(id)
			for t in include_tags:
				if not tags.has(t): ok = false; break
			for t in exclude_tags:
				if tags.has(t): ok = false; break
		if ok: out.append(id)
	return out

func _collect_tags(id: StringName) -> Array:
	var tags: Array = []
	if _entity_manager.has_component(id, ItemComponent):
		var ic: ItemComponent = _entity_manager.get_component(id, ItemComponent) as ItemComponent
		for t in ic.tags: tags.append(t)
	if _entity_manager.has_component(id, PlayerComponent):
		var pc: PlayerComponent = _entity_manager.get_component(id, PlayerComponent) as PlayerComponent
		for t in pc.tags:
			tags.append(t)
	return tags

#endregion


## Dispatch (core).
func _dispatch(entity_id: StringName, ev_type: int, ctx: Dictionary) -> void:
	if entity_id == StringName():
		return
	if not _cache.has(entity_id):
		_attach_scripts(entity_id)
	if not _cache.has(entity_id):
		return

	var data = _cache[entity_id]
	var merged: Dictionary = data.get("merged_subs", {})
	if not merged.has(ev_type):
		return

	var instances: Array = data.get("instances", [])
	var per_inst_subs: Array = data.get("per_inst_subs", [])

	for i in instances.size():
		var inst: EntityScript = instances[i]
		var subs: Array[int] = per_inst_subs[i]
		if ev_type in subs:
			var result: Dictionary = inst.handle_event(ev_type, ctx)
			if result.get("consumed", false):
				break


## Optional helper to emit events from code
func emit_script_event(ev_type: int, source_id: StringName, data: Dictionary = {}, targets := [], target_group := StringName(), verb := "") -> void:
	if not is_instance_valid(Switchboard_auto):
		return
	script_event.emit({
		"event_type": ev_type,
		"source_id": source_id,
		"targets": targets,
		"target_group": target_group,
		"verb": verb,
		"data": data,
		"ts": Time.get_ticks_msec(),
	})
