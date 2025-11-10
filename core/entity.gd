class_name Entity
extends CustomResource


signal component_added(name: StringName, component: EntityComponent)
signal component_removed(name: StringName, component: EntityComponent)
signal destroyed(entity_id)
signal activity_changed(is_active: bool)
signal alive_changed(is_alive: bool)

## the set of [EntityComponent]s assigned to the [Entity].
@export var _components: Dictionary[StringName, EntityComponent] = {}

## the [Entity]'s Id.
@export var id: String

## the [Entity]'s flags.
@export var tags: FlagSet = FlagSet.new()

## flag indicator of whether the [Entity] is alive.
@export var alive: bool = true:
	get:
		return alive

	set(value):
		if alive != value:
			alive = value
			alive_changed.emit(value)

## flag indicator of whether the [Entity] is active.
@export var active: bool = true:
	get:
		return active

	set(value):
		if active != value:
			active = value
			activity_changed.emit(value)

## flag indicator of whether the [Entity] is active.
@export var is_active: bool = true

## groups to which the [Entity] belongs
@export var groups: Dictionary = {}


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


func _get(clazz_name: StringName) -> EntityComponent:
	return _components[clazz_name]


## Destroys an [Entity].
func destroy() -> void:
	if alive:
		alive = false
		
		# detach components (lets GC reclaim them if no other refs)
		for k in _components.keys():
			var c: EntityComponent = _components[k]
			if c:
				c.parent_entity_id = ""

		_components.clear()
		destroyed.emit(id)


## Gets an [EntityComponent] attached to an [Entity].
func get_component(clazz_name: StringName) -> EntityComponent:
	return _components[clazz_name]


## Gets all [EntityComponent]s attached to an [Entity].
func get_components() -> Dictionary:
	return _components


## Determines if an [Entity] has a specific component type.
func has_component(clazz: StringName) -> bool:
	return clazz in _components


## Removes an [EntityComponent] from an [Entity].
func remove_component(key: StringName) -> void:
	if _components.has(key):
		var prev: EntityComponent = _components[key]
		_components.erase(key)
		if prev:
			prev.parent_entity_id = ""  # or null it out
		component_removed.emit(key, prev)


## Sets a [EntityComponent] on an [Entity].
func set_component(component: EntityComponent) -> void:
	assert(component != null)
	var key: StringName = component.get_class_name()  # ensure your components implement this
	var existed: bool =   _components.has(key)
	if existed:
		var _old: EntityComponent = _components[key]  # maybe do something w/this eventually
		_components[key] = component
		component.parent_entity_id = id
		component_added.emit(key, component)  # treat replace as add for simplicity
	else:
		_components[key] = component
		component.parent_entity_id = id
		component_added.emit(key, component)
