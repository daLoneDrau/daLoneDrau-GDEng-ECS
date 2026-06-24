@abstract class_name EntityComponent
extends CustomResource


signal entity_data_update(entity_id: String, component: String)

## the parent entity's reference id
@export var parent_entity_id: String

## Quick toggle without removing the component.
@export var enabled: bool = true

var _lifecycle_initialized: bool = false


func _init() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"entity_data_update",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_from_switchboard() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "entity_data_update")
	Switchboard_auto.remove_subscriber(self)


## Emits a signal that the [EntityComponent] was updated.
func emit_update_signal() -> void:
	entity_data_update.emit(parent_entity_id, get_class_name())

## —————————————————————————————————————————————
#region Lifecycle hooks (override in subclasses)
## —————————————————————————————————————————————


func on_added(_entity: Entity, _em: EntityManager) -> void:
	if _lifecycle_initialized:
		push_warning("on_added called twice on %s" % get_class_name())
		return
	_lifecycle_initialized = true


func on_removed(_entity: Entity, _em: EntityManager) -> void:
	if not _lifecycle_initialized:
		push_warning("on_removed called on uninitialized %s" % get_class_name())
		return
	_lifecycle_initialized = false

#endregion

## —————————————————————————————————————————————
#region Utilities
## —————————————————————————————————————————————


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


func from_dict(_data: Dictionary) -> void:
	# Override in subclasses to restore state
	if _data.has("enabled"):
		enabled = bool(_data["enabled"])

		#endregion
