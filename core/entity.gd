class_name Entity
extends CustomResource


signal component_added(name: StringName, component: EntityComponent)
signal component_removed(name: StringName, component: EntityComponent)
signal destroyed(entity_id: String)
signal activity_changed(is_active: bool)
signal alive_changed(is_alive: bool)

## the set of [EntityComponent]s assigned to the [Entity].
@export var _components: Dictionary[StringName, EntityComponent] = {}

## the [Entity]'s Id.
@export var id: String

## the [Entity]'s flags.
@export var tags: FlagSet = FlagSet.new()

## flag indicator of whether the [Entity] is alive.
var _alive: bool = true

@export var alive: bool = true:
	get:
		return _alive
	set(value):
		if _alive != value:
			_alive = value
			alive_changed.emit(value)

## flag indicator of whether the [Entity] is active.
var _active: bool = true

@export var active: bool = true:
	get:
		return _active
	set(value):
		if _active != value:
			_active = value
			activity_changed.emit(value)

## groups to which the [Entity] belongs
@export var groups: Dictionary = {}


## Called when the object's script is instantiated.
func _init():
	Switchboard_auto.add_resource_broadcaster(
		self,
		"component_added",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"component_removed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"destroyed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"activity_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"alive_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _to_string() -> String:
	return "Entity(id=%s, alive=%s, active=%s, components=%d)" % [
	id, _alive, _active, _components.size()
	]


## Destroys an [Entity].
## Internal use only - call EntityManager.remove_entity() instead
func _internal_destroy() -> void:
	if not alive:
		return  # Already destroyed

	alive = false

	# detach components (lets GC reclaim them if no other refs)
	for k in _components.keys():
		var c: EntityComponent = _components[k]
		if c:
			c.parent_entity_id = ""
			c._unregister_from_switchboard()  # <-- Ensure component cleanup

	_components.clear()
	destroyed.emit(id)

	# Unregister from Switchboard
	for sig in ["component_added", "component_removed", "destroyed", "activity_changed", "alive_changed"]:
		Switchboard_auto.remove_resource_broadcaster(self, sig)

	Switchboard_auto.remove_subscriber(self)  # <-- Add this for entity-level subscriptions


## Gets an [EntityComponent] attached to an [Entity].
func get_component(clazz_name: StringName, warn_if_missing: bool = true) -> EntityComponent:
	var component: EntityComponent = _components.get(clazz_name)
	if component == null and warn_if_missing:
		push_warning("Entity %s: Component '%s' not found" % [id, clazz_name])
	return component


## Gets number of components.
func get_component_count() -> int:
	return _components.size()


## Type-safe component getter using class reference
## Example: var health = entity.get_component_typed(HealthComponent)
func get_component_typed(component_class: GDScript) -> EntityComponent:
	return get_component(component_class.get_global_name())


## Gets all [EntityComponent]s attached to an [Entity].
func get_components() -> Dictionary[StringName, EntityComponent]:
	return _components


## Determines if an [Entity] has a specific component type.
func has_component(clazz: StringName) -> bool:
	return clazz in _components


## Checks if entity has ALL components in signature.
func has_components(component_names: Array[StringName]) -> bool:
	for name in component_names:
		if not has_component(name):
			return false
	return true


## Removes an [EntityComponent] from an [Entity].
func remove_component(key: StringName) -> bool:
	if not _components.has(key):
		return false

	var prev: EntityComponent = _components[key]
	_components.erase(key)
	if prev:
		prev.parent_entity_id = ""  # or null it out
	component_removed.emit(key, prev)
	return true


## Sets a [EntityComponent] on an [Entity].
func set_component(component: EntityComponent) -> void:
	assert(component != null, "Component cannot be null")
	assert(id != "", "Entity must have an ID before adding components")
	var key: StringName = component.get_class_name()  # ensure your components implement this

	var old_component: EntityComponent = _components[key]  # maybe do something w/this eventually
	if old_component:
		old_component.parent_entity_id = ""  # Detach old component
		component_removed.emit(key, old_component)

	_components[key] = component
	component.parent_entity_id = id
	component_added.emit(key, component)  # treat replace as add for simplicity


## Sets multiple components at once
func set_components(components: Array[EntityComponent]) -> void:
	for component in components:
		set_component(component)
