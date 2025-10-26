class_name Spell
extends CustomResource


## flag indicating whether the spell still exists.
@export var exists: bool

## the caster's UUID
@export var caster: String

## the [Spell]'s UUID.
@export var id: String

## the target's UUID
@export var target: String

## the caster's level
@export var caster_level: int

## the spell type
@export var spell_type: int

## the time the spell was created. could be in turns or milliseconds
@export var created_time: int

## the time the spell was last updated. could be in turns or milliseconds
@export var last_updated: int

## any spell flags
@export var flags: FlagSet = FlagSet.new()

## the spell's duration
@export var duration: int

## the time left a spell has
@export var time_to_live: int

## flag indicating whether the spell has a duration
@export var has_duration: bool = true

## spell effects. we'll deal with it when we get there
# CSpellFx	* pSpellFx;


func tick(delta: int) -> void:
	if not exists or not has_duration:
		return
	time_to_live = max(time_to_live - delta, 0)
	last_updated += delta
	if time_to_live <= 0:
		expire()
		
		
func elapsed_time() -> int:
	return max(0, created_time - last_updated)


func expire() -> void:
	exists = false
	time_to_live = 0


func is_expired() -> bool:
	return has_duration and time_to_live <= 0


func reset_timer() -> void:
	time_to_live = duration
	last_updated = created_time
	exists = true


func to_dict() -> Dictionary:
	return {
		"id": id,
		"caster": caster,
		"target": target,
		"caster_level": caster_level,
		"spell_type": spell_type,
		"created_time": created_time,
		"last_updated": last_updated,
		"flags": flags.get_mask(),
		"duration": duration,
		"time_to_live": time_to_live,
		"has_duration": has_duration,
		"exists": exists,
	}


func from_dict(d: Dictionary) -> void:
	id = d.get("id", id)
	caster = d.get("caster", caster)
	target = d.get("target", target)
	caster_level = int(d.get("caster_level", caster_level))
	spell_type = int(d.get("spell_type", spell_type))
	created_time = int(d.get("created_time", created_time))
	last_updated = int(d.get("last_updated", last_updated))
	flags.set_mask(d.get("flags", flags.get_mask()))
	duration = int(d.get("duration", duration))
	time_to_live = int(d.get("time_to_live", time_to_live))
	has_duration = bool(d.get("has_duration", has_duration))
	exists = bool(d.get("exists", exists))
