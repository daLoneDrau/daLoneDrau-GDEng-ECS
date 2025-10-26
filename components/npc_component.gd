class_name NpcComponent
extends EntityComponent


signal entity_data_update(entity_id: String)

## The npc's current life.
var life: int:
	get:
		return life
	set(value):
		life = value
		emit_update_signal()

## The npc's max life.
@export var max_life: int:
	get:
		return max_life
	set(value):
		max_life = value
		emit_update_signal()

## The npc's current mana.
var mana: int:
	get:
		return mana
	set(value):
		mana = value
		emit_update_signal()

## The npc's max mana.
@export var max_mana: int:
	get:
		return max_mana
	set(value):
		max_mana = value
		emit_update_signal()

## The npc's weapon.
@export var weapon: Entity:
	get:
		return weapon
	set(value):
		weapon = value
		emit_update_signal()

## The npc's xp value.
@export var xp_value: int


func _init() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"entity_data_update",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


## Emits a signal that the [PlayerComponent] was updated.
func emit_update_signal() -> void:
	entity_data_update.emit(parent_entity_id)
