@abstract class_name EntityComponent
extends CustomResource


signal entity_data_update(entity_id: String, component: String)

## the parent entity's reference id
@export var parent_entity_id: String

## Quick toggle without removing the component.
@export var enabled: bool = true

## the CoreEngine instance to use
var engine_instance: GameEngine

## the current system's EntityManager
var entity_manager_instance: EntityManager


func _init() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"entity_data_update",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


## Emits a signal that the [PlayerComponent] was updated.
func emit_update_signal() -> void:
	entity_data_update.emit(parent_entity_id, get_class_name())


func _unregister_from_switchboard() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "entity_data_update")
	Switchboard_auto.remove_subscriber(self)

## —————————————————————————————————————————————
#region Lifecycle hooks (override in subclasses)
## —————————————————————————————————————————————


func on_added(_entity: Entity, _em: EntityManager) -> void:
	# e.g., subscribe to signals, allocate caches
	pass

func on_removed(_entity: Entity, _em: EntityManager) -> void:
	# e.g., unsubscribe, clear timers/state
	pass
	
#endregion

## —————————————————————————————————————————————
#region Utilities
## —————————————————————————————————————————————


func from_dict(_data: Dictionary) -> void:
	# Override in subclasses to restore state
	if _data.has("enabled"):
		enabled = bool(_data["enabled"])


func get_entity() -> Entity:
	if entity_manager_instance == null or parent_entity_id == "":
		return null
	return entity_manager_instance.get_entity_by_id(parent_entity_id)


func is_attached() -> bool:
	return parent_entity_id != ""


func clone(deep: bool = true) -> EntityComponent:
	# Use for templating: item blueprints, enemy archetypes, etc.
	return self.duplicate(deep) as EntityComponent


func to_dict() -> Dictionary:
	# Minimal default serialization (override to include state)
	return {
		"key": get_class_name(),
		"enabled": enabled
	}

#endregion
