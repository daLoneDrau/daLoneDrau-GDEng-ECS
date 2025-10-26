@abstract class_name SpellSystem
extends GameSystem


var _entity_manager: EntityManager

## the parent scene
var parent: Scene

## the list of all spells
var spells: Array[Spell]


## Initializes the [DungeonSpellSystem]
func _init(p: Scene, emi: EntityManager):
	parent = p
	_entity_manager = emi
	init_spell_list()


## Adds a [Spell] on the target.
func add_spell_on(target_id: String, spell_index: int) -> void:
	if _entity_manager.is_valid_entity(target_id):
		var entity: Entity = _entity_manager.get_entity_by_id(target_id)
		entity.spells_on.append(spell_index)
		if entity.has_component("PlayerComponent"):
			var player_data: PlayerComponent = entity.get_component("PlayerComponent") as PlayerComponent
			player_data.emit_update_signal()


## Cancels all current spells.
func cancel_all() -> void:
	for spell: Spell in spells:
		if spell.exists:
			spell.time_to_live = 0

	# update()

	# TODO - remove all spells on the player, if there is only one


## Clears all spells.
func clear_all() -> void:
	for spell: Spell in spells:
		if spell.exists:
			spell.time_to_live = 0
			spell.exists = false
			# TODO - clear spell effects

	var entities: Array[Entity] = _entity_manager.get_entities()
	for entity: Entity in entities:
		if _entity_manager.is_valid_entity(entity.id):
			remove_all_spells_on(entity)


## Checks for an existing instance of this spelltype
func exist_any_instance(type: int) -> bool:
	var exists: bool = false
	for spell: Spell in spells:
		if spell.exists and spell.spell_type == type:
			exists = true
	return exists


## Gets the index of the first instance of a [Spell] of a specific type. If none was found, returns -1.
func get_instance(type: int) -> int:
	var index: int = -1
	for i in range(len(spells)):
		if spells[i].exists and spells[i].spell_type == type:
			index = i
	return index


## Gets the index of the first instance of a [Spell] of a specific type from a specific caster. If none was found, returns -1.
func get_instance_for_this_caster(type: int, caster: String) -> int:
	var index: int = -1
	for i in range(len(spells)):
		if spells[i].exists and spells[i].spell_type == type and spells[i].caster == caster:
			index = i
	return index


## Determines if any instance of a [Spell] type exists for a caster.
func exist_any_instance_for_this_caster(type: int, caster: String) -> bool:
	var exists: bool = false
	for i in range(len(spells)):
		if spells[i].exists and spells[i].spell_type == type and spells[i].caster == caster:
			exists = true
	return exists


## Gets a free spell slot.
func get_free() -> int:
	var index: int = -1
	for i in range(len(spells)):
		if !spells[i].exists:
			index = i
			break

	return index


func get_max_spells() -> int:
	push_error(self.get_name() + ".get_max_spells() not defined ")
	assert(false, self.get_name() + ".get_max_spells() was left undefined!")
	return -1


## Gets the reference index of a [Spell] on the target [Entity]. -1 means no spell exists.
func get_spell_on(target: Entity, spell_type: int) -> int:
	var spell_id: int = -1
	if _entity_manager.is_valid_entity(target.id):
		for spell_index: int in target.spells_on:
			var spell: Spell = spells[spell_index]
			if spell.spell_type == spell_type and spell.exists:
				spell_id = spell_index
				break

	return spell_id


func init_spell_list() -> void:
	push_error(self.get_name() + ".init_spell_list() not defined ")
	assert(false, self.get_name() + ".init_spell_list() was left undefined!")


## Launches a spell.
func launch_spell(_type: int, _source: String, _flags: int, _level: int, _target: String, _duration: int) -> int:
	push_error(self.get_name() + ".launch_spell() not defined ")
	assert(false, self.get_name() + ".launch_spell() was left undefined!")
	return -1


## Notifies all Entities that a [Spell] was cast.
func notify_spellcast(spell_index: int) -> void:
	var spell: Spell = spells[spell_index]
	var entities: Array[Entity] = _entity_manager.get_entities()
	for entity: Entity in entities:
		parent.get_scripting_system().send_script_event(
			spell.caster,
			entity.id,
			GlobalUtils.SM_SPELLCAST,
			GlobalUtils.ScriptMessageAudience.SINGLE_ENTITY,
			{
				"spell_type": spell.spell_type,
				"caster_level": spell.caster_level
			}
		)


## Notifies the target [Entity] that a [Spell] was cast.
func notify_only_target_spellcast(spell_index: int) -> void:
	var spell: Spell = spells[spell_index]
	if spell.target != "":
		parent.get_scripting_system().send_script_event(
			spell.caster,
			spell.target,
			GlobalUtils.SM_SPELLCAST,
			GlobalUtils.ScriptMessageAudience.SINGLE_ENTITY,
			{
				"spell_type": spell.spell_type,
				"caster_level": spell.caster_level
			}
		)


## Notifies all Entities that a [Spell] has ended.
func notify_spellend(spell_index: int) -> void:
	var spell: Spell = spells[spell_index]
	var entities: Array[Entity] = _entity_manager.get_entities()
	for entity: Entity in entities:
		parent.get_scripting_system().send_script_event(
			spell.caster,
			entity.id,
			GlobalUtils.SM_SPELLEND,
			GlobalUtils.ScriptMessageAudience.SINGLE_ENTITY,
			{
				"spell_type": spell.spell_type,
				"caster_level": spell.caster_level
			}
		)


## Removes all [Spell]s on a single [Entity].
func remove_all_spells_on(entity: Entity) -> void:
	entity.spells_on.clear()


## Removes a [Spell] on the target [Entity].
func remove_spell_on(target_id: String, spell_index: int) -> void:
	if _entity_manager.is_valid_entity(target_id):
		var entity: Entity = _entity_manager.get_entity_by_id(target_id)
		if len(entity.spells_on) > 0:
			var index: int = -1
			for i in range(len(entity.spells_on)):
				if entity.spells_on[i] == spell_index:
					index = i
					break
			if index >= 0:
				entity.spells_on.remove_at(index)
				if entity.has_component("PlayerComponent"):
					var player_data: PlayerComponent = entity.get_component("PlayerComponent") as PlayerComponent
					player_data.emit_update_signal()


## Removes a [Spell] that was targeting multiple Entities.
func remove_spell_on_all_entities(spell_index: int) -> void:
	var entities: Array[Entity] = _entity_manager.get_entities()
	for entity: Entity in entities:
		remove_spell_on(entity.id, spell_index)
