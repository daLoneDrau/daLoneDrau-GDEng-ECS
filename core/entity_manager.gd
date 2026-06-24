@abstract class_name EntityManager
extends Node

signal entity_added(e: Entity)
signal entity_removed(eid: String, e: Entity)
signal entity_destroyed(eid: String, e: Entity)
signal script_event(ctx: Dictionary)


var ascii_letters_and_digits: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var entities: Dictionary[String, Entity] = {}

var entities_to_add: Array[Entity] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("EntityManager._ready()")
	Switchboard_auto.add_node_broadcaster(
		self,
		"entity_added",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_node_broadcaster(
		self,
		"entity_removed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_node_broadcaster(
		self,
		"entity_destroyed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_node_broadcaster(
		self,
		"script_event",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func gen_unique_string(length: int) -> String:
	var result: String = ""
	for i in range(length):
		result += ascii_letters_and_digits[randi() % ascii_letters_and_digits.length()]
	return result


## generates a UUID
func uuidv4() -> String:
	return gen_unique_string(8) + gen_unique_string(4) + "4" + gen_unique_string(3) + gen_unique_string(4) + gen_unique_string(12)


func add_entity(e: Entity) -> void:
	entities_to_add.append(e)


## Adds an entity immediately instead of waiting for the update.
func add_entity_immediately(eid: String) -> void:
	for i in len(entities_to_add):
		if entities_to_add[i].id == eid:
			var entity: Entity = entities_to_add[i]
			entities[entity.id] = entity

			# Call lifecycle hooks on all components
			_notify_components_added(entity)

			entity_added.emit(entity)
			script_event.emit({
				"source_id": eid,
				"event_type": ScriptEvent.INITIALIZED,
			})

			entities_to_add.remove_at(i)
			break


func destroy_dynamic_entity(e: Entity) -> void:
	if e != null and is_valid_entity(e.id):
		for entity_id in entities:
			var entity: Entity = entities[entity_id]
			if is_pc(entity):
				var player_data: PlayerComponent = entity.get_component("PlayerComponent") as PlayerComponent
				for slot: int in player_data.equipped_items:
					if player_data.equipped_items[slot] == e.id:
						unequip_from_inventory(entity, e)
						break

		# TODO - release any speech that the entity is involved with

		# TODO - clear any scripted events

		# kill all spells
		kill_spells_on(e.id)


## Gets an entity by its id.
func get_entity_by_id(eid: String) -> Entity:
	return entities.get(eid, null)


## Gets all entities.
func get_entities() -> Array[Entity]:
	var ret_list: Array[Entity] = []
	for id in entities:
		ret_list.append(entities[id])
	return ret_list


## Gets all entities that have a specfific tag.
func get_entities_by_tag(tag: int) -> Array[Entity]:
	var entities_by_tag: Array[Entity] = []
	for id in entities:
		if entities[id].tags.has(tag):
			entities_by_tag.append(entities[id])
	return entities_by_tag


## Gets all entities that have a specific componenent type.
func get_entities_with_component(component_name: String) -> Array[Entity]:
	var entities_with_component: Array[Entity] = []
	for id in entities:
		if entities[id].has_component(component_name):
			entities_with_component.append(entities[id])
	return entities_with_component


## Determines if a specific [Entity] has a component.
func has_component(eid: String, component_name: String) -> bool:
	var has := false
	var e := get_entity_by_id(eid)
	if e != null:
		has = e.has_component(component_name)
	return has


## Determines if two entities represent the same item.
func is_same_entity(entity_0: Entity, entity_1: Entity) -> bool:
	# if either of the entities is NULL, return false
	if entity_0 == null or entity_1 == null:
		return false

	# if either of the entities is meant to be UNIQUE, return false
	if is_unique(entity_0) or is_unique(entity_1):
		return false

	if is_item(entity_0) and is_item(entity_1):
		# both entities are items
		if entity_0.has_component("ScriptData") and entity_1.has_component("ScriptData"):
			# both items have scripts
			# var script_0: ScriptData = entity_0.get_component("ScriptData") as ScriptData
			# var script_1: ScriptData = entity_1.get_component("ScriptData") as ScriptData
			# if script_0.script_name == script_1.script_name:
			# both scripts share the same name
			#	return true
			pass

	return false


## Validates that an entity exists in the system.
func is_valid_entity(id: String) -> bool:
	return entities.has(id)


## Kills all entities
func kill_all_entities() -> void:
	for id in entities:
		entities[id].alive = false


func remove_entity(id: String) -> void:
	if not entities.has(id):
		return

	var entity: Entity = entities[id]

	_notify_components_removed(entity)

	entity._internal_destroy()  # Use internal method
	entities.erase(id)
	entity_removed.emit(id, entity)  # Now actually emitted


func remove_all_entities() -> void:
	for id: String in entities.keys():  # .keys() to avoid modification during iteration
		remove_entity(id)

## —————————————————————————————————————————————
#region API
## —————————————————————————————————————————————


## Determines if an [Entity] is tagged as an PC.
@abstract func is_pc(_e: Entity) -> bool


## Determines if an [Entity] is tagged as an item.
@abstract func is_item(_e: Entity) -> bool


## Determines if an [Entity] is tagged as unique.
@abstract func is_unique(_e: Entity) -> bool


@abstract func kill_spells_on(_e_id: String)


## Unequips an item from a player's inventory.
@abstract func unequip_from_inventory(_player_entity: Entity, _item_entity: Entity) -> bool
#	var removed: bool = false
#	var player: PlayerData = player_entity.get_component("PlayerData") as PlayerData
#	# check to see if player was equipped with the item
#	for item_id: String in player.equipped_items:
#		if item_id == item_entity.id:
#			# have player unequip
#			var _item: ItemData = item_entity.get_component("ItemData") as ItemData
#			# item.unequip(item_entity, true)
#			removed = true
#			break
#	return removed


@abstract func send_init_script_event(_entity: Entity) -> void
#	var obj_data: PlayerData = entity.get_component("PlayerData") as PlayerData
#
#	# broadcast a signal that the entity needs to be initialized.
#	# if it has a script, it will react to the signal
#	obj_data.engine_instance.script_system.send_script_event(
#		"",
#		entity.id,
#		GlobalUtils.SM_INIT
#	)

#endregion


func update() -> void:
	for entity in entities_to_add:
		entities[entity.id] = entity

		_notify_components_added(entity)

		entity_added.emit(entity)
		script_event.emit({
			"source_id": entity.id,
			"event_type": ScriptEvent.INITIALIZED,
		})
	entities_to_add.clear()

	var kill_list: Array[String] = []
	for entity_id in entities:
		var e: Entity = entities[entity_id]
		if not e.alive:
			kill_list.append(entity_id)

	for entity_id in kill_list:
		var e: Entity = entities[entity_id]

		# Notify components before destruction
		_notify_components_removed(e)

		destroy_dynamic_entity(e)
		entities.erase(entity_id)

		entity_destroyed.emit(entity_id, e)  # Now actually emitted


## —————————————————————————————————————————————
#region Internal — Component accessors
## —————————————————————————————————————————————


## Assigns an [EntityComponent] to an entity with the matching reference id. This should be used for existing entities only.
## To add components to new entities, write the code in the creation methods.
func add_component(eid: String, comp: EntityComponent) -> void:
	# --- Safety checks ---
	if not is_valid_entity(eid):
		push_error("EntityManager.add_component: entity %s not found." % eid)
		return

	if comp == null:
		push_error("EntityManager.add_component: null component for %s" % eid)
		return

	var cname := comp.get_class_name()
	var entity: Entity = get_entity_by_id(eid)

	# Handle replacement
	if entity.has_component(cname):
		var old_comp: EntityComponent = entity.get_component(cname)
		old_comp.on_removed(entity, self)
		push_warning("Entity %s already has component %s. Replacing." % [eid, cname])

	entity.set_component(comp)
	comp.on_added(entity, self)


## Gets an [EntityComponent] assigned to an [Entity].
func get_component(id: String, script: Script) -> EntityComponent:
	var ret_val: EntityComponent = null
	if is_valid_entity(id):
		var entity: Entity = get_entity_by_id(id)
		if entity.has_component(script.get_global_name()):
			ret_val = entity.get_component(script.get_global_name())

	return ret_val


## Returns all component instances attached to the given entity.
func get_components(entity_id: String) -> Array:
	if not entities.has(entity_id):
		return []
	var entry: Entity = entities[entity_id]
	return entry.get_components().values()


## Removes a component from an entity.
func remove_component(eid: String, component_name: StringName) -> bool:
	if not is_valid_entity(eid):
		return false

	var entity: Entity = get_entity_by_id(eid)
	if not entity.has_component(component_name):
		return false

	var comp: EntityComponent = entity.get_component(component_name)
	comp.on_removed(entity, self)

	return entity.remove_component(component_name)

#endregion

## —————————————————————————————————————————————
#region Lifecycle Helpers
## —————————————————————————————————————————————


func _notify_components_added(entity: Entity) -> void:
	for comp in entity.get_components().values():
		comp.on_added(entity, self)


func _notify_components_removed(entity: Entity) -> void:
	for comp in entity.get_components().values():
		comp.on_removed(entity, self)

#endregion

func to_dict() -> Dictionary:
	var out := {"entities": []}
	# Fallback path using common ECS helpers; adapt if your API differs

	for eid in entities:
		var e_dict := {"id": str(eid), "components": {}}
		# pull component list
		var comps: Array = get_components(eid)
		for c in comps:
			var cname = c.get_class() if c.has_method("get_class") else c.get_script().resource_path.get_file()
			var payload = c.to_dict() if c and c.has_method("to_dict") else {}
			e_dict["components"][cname] = payload
		out["entities"].append(e_dict)
	return out

func from_dict(snapshot: Dictionary) -> bool:
	# Fallback rebuild: clear and re-create entities
	remove_all_entities()

	var ents: Array = snapshot.get("entities", [])
	for ed in ents:
		var eid: StringName = StringName(ed.get("id", ""))
		if eid == &"":
			eid = StringName("E" + str(ents.hash()))
		var _new_id := eid
	#TODO - create logic to load entities from dictionary
	# if em.has_method("create_entity_with_id"):
	#			new_id = em.create_entity_with_id(eid)
	#		elif em.has_method("create_entity"):
	#			new_id = em.create_entity(eid)
	#
	#		# Reattach components
	#		var comps: Dictionary = ed.get("components", {})
	#		for cname in comps.keys():
	#			var payload: Dictionary = comps[cname]
	#			# Resolve script by name or keep a registry map here if you have one.
	#			var script_path := _resolve_component_script_path(cname)
	#			if script_path == "":
	#				push_warning("Unknown component '%s' during load; skipped" % cname)
	#				continue
	#			var comp = load(script_path).new()
	#			if comp.has_method("from_dict"):
	#				comp.from_dict(payload)
	#			if em.has_method("add_component"):
	#				em.add_component(new_id, comp)

	return true