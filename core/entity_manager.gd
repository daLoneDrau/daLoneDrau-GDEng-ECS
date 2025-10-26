@abstract class_name EntityManager
extends Node

signal entity_added(e: Entity)
signal entity_removed(eid: String, e: Entity)
signal entity_destroyed(eid: String, e: Entity)


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
	entity_added.emit(e)


## Adds an entity immediately instead of waiting for the update.
func add_entity_immediately(eid: String) -> void:
	for i in len(entities_to_add):
		if entities_to_add[i].id == eid:
			var entity: Entity = entities_to_add[i]
			entities[entity.id] = entity
			entity_added.emit(entity)

			# emit the start event
			if is_pc(entity) or is_item(entity):
				send_init_script_event(entity)
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
	var e: Entity = null
	for id: String in entities:
		if id == eid:
			e = entities[id]
	return e


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


## Determines if an [Entity] is tagged as an PC.
@abstract func is_pc(_e: Entity) -> bool


## Determines if an [Entity] is tagged as an item.
@abstract func is_item(_e: Entity) -> bool


## Determines if an [Entity] is tagged as unique.
@abstract func is_unique(_e: Entity) -> bool


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



@abstract func kill_spells_on(_e_id: String)



func remove_entity(id: String) -> void:
	entities.erase(id)


func remove_all_entities() -> void:
	for id: String in entities:
		entities.erase(id)


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


func update() -> void:
	for entity in entities_to_add:
		entities[entity.id] = entity
		# emit the start event
		if is_pc(entity) or is_item(entity):
			send_init_script_event(entity)
	entities_to_add.clear()

	var kill_list: Array[String] = []
	for entity_id in entities:
		var e: Entity = entities[entity_id]
		if not e.alive:
			kill_list.append(entity_id)

	for entity_id in kill_list:
		var e: Entity = entities[entity_id]
		destroy_dynamic_entity(e)
		entities.erase(entity_id)


## —————————————————————————————————————————————
#region Internal — Component accessors
## —————————————————————————————————————————————


## Gets an [EntityComponent] assigned to an [Entity].
func get_component(id: String, script: Script) -> EntityComponent:
	var ret_val: EntityComponent = null
	if is_valid_entity(id):
		var entity: Entity = get_entity_by_id(id)
		if entity.has_component(script.get_global_name()):
			ret_val = entity.get_component(script.get_global_name())

	return ret_val
	
#endregion