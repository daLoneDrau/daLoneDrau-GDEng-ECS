# res://ecs/scripts/EntityScript.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Base class for all logic scripts.
## - Automatically subscribes to events based on `on_<event>` methods.
## - Called by ScriptSystem when a subscribed event fires.
## - Provides helpers for component and variable access.
@abstract class_name EntityScript
extends RefCounted


# Context injected on attach
var entity_id: StringName
var vars: ScriptVariableSet
var parent_component: ScriptComponent = null
var is_master: bool = false

# Internal caches
var _event_method: Dictionary = {}  # {event_id: "method_name"}
var _subscriptions: Array = []

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————


func on_attach(_entity_id: StringName, entity_manager: EntityManager) -> void:
	entity_id = _entity_id
	if entity_manager and entity_manager.has_component(entity_id, "ScriptVariableSet"):
		vars = entity_manager.get_component(entity_id, ScriptVariableSet)
	_build_event_method_map()
	_build_subscriptions()

func on_detach() -> void:
	_event_method.clear()
	_subscriptions.clear()

#endregion

## —————————————————————————————————————————————
#region Subscription / Dispatch
## —————————————————————————————————————————————


func subscribed_events() -> Array:
	return _subscriptions

func manual_subscriptions() -> Array[int]:
	return []

func handle_event(event_type: int, ctx: Dictionary) -> Dictionary:
	var method_name: String = _event_method.get(event_type, "")
	if method_name == "" or not has_method(method_name):
		return {}
	return call(method_name, ctx)

#endregion

## —————————————————————————————————————————————
#region Helpers
## —————————————————————————————————————————————


func get_var(key: String, default_value = null):
	if vars:
		if vars.has(key):
			return vars.get_variable(key).value
	return default_value

func set_var(key: String, value) -> void:
	if vars:
		vars.set_variable(key, value)

func bump_var(key: String, delta: int, default_value := 0) -> int:
	var v = int(get_var(key, default_value)) + delta
	set_var(key, v)
	return v

func get_parent_component() -> ScriptComponent:
	return parent_component

func is_master_script() -> bool:
	return is_master

func is_main_script() -> bool:
	return not is_master

#endregion

## —————————————————————————————————————————————
#region Internal builders
## —————————————————————————————————————————————


func _build_event_method_map() -> void:
	_event_method.clear()
	var registry: Dictionary = ScriptEvent.all()
	for name in registry.keys():
		var event_id: int = registry[name]
		var method_name := "on_%s" % name.to_lower()
		if has_method(method_name):
			_event_method[event_id] = method_name


func _build_subscriptions() -> void:
	var auto: Array = _event_method.keys()
	var extra: Array[int] = manual_subscriptions()
	var subscription_set := {}
	for ev in auto: subscription_set[ev] = true
	for ev in extra: subscription_set[ev] = true
	_subscriptions = subscription_set.keys()
	
#endregion
