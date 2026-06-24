## Runtime state for an active effect on an entity.
## Created when an EffectGrant is applied, tracks duration, stacks, etc.
class_name ActiveEffect
extends RefCounted

## Effect identifier
var effect_id: StringName = &""

## Who/what applied this effect
var source_id: StringName = &""

## Display info
var display_name: String = ""
var description: String = ""
var icon_id: StringName = &""

## Duration tracking
var duration_type: EffectGrant.DurationType = EffectGrant.DurationType.PERMANENT
var duration_remaining: float = 0.0  # For TIMED
var uses_remaining: int = 0          # For USES

## Stack tracking
var stack_behavior: EffectGrant.StackBehavior = EffectGrant.StackBehavior.REPLACE
var stacks: int = 1
var max_stacks: int = 1

## Effect parameters (copied from EffectGrant)
var params: Dictionary = {}

## Tags for categorization (e.g., "buff", "debuff", "poison", "magic")
var tags: Array[StringName] = []

## Timing
var applied_at: int = 0  # Time.get_ticks_msec() when applied
var tick_accumulator: float = 0.0  # For periodic effects
var tick_count: int = 0  # How many times this effect has ticked


## Check if effect has a specific tag
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Add a tag
func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)


## Get time since effect was applied (milliseconds)
func get_elapsed_time() -> int:
	return Time.get_ticks_msec() - applied_at


## Check if effect is beneficial (buff) vs harmful (debuff)
## Convention: params["beneficial"] = true/false, or check tags
func is_beneficial() -> bool:
	if params.has("beneficial"):
		return bool(params["beneficial"])
	return has_tag(&"buff") or not has_tag(&"debuff")


## Get a parameter value with default
func get_param(key: String, default: Variant = null) -> Variant:
	return params.get(key, default)


func _to_string() -> String:
	var stack_str := " x%d" % stacks if stacks > 1 else ""
	var duration_str := ""

	match duration_type:
		EffectGrant.DurationType.TIMED:
			duration_str = " (%.1fs)" % duration_remaining
		EffectGrant.DurationType.USES:
			duration_str = " (%d uses)" % uses_remaining

	return "%s%s%s from %s" % [
	display_name if display_name else effect_id,
	stack_str,
	duration_str,
	source_id
	]


func to_dict() -> Dictionary:
	return {
		"effect_id": String(effect_id),
		"source_id": String(source_id),
		"display_name": display_name,
		"description": description,
		"icon_id": String(icon_id),
		"duration_type": duration_type,
		"duration_remaining": duration_remaining,
		"uses_remaining": uses_remaining,
		"stack_behavior": stack_behavior,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"params": params,
		"tags": tags.map(func(t): return String(t)),
		"applied_at": applied_at,
		"tick_accumulator": tick_accumulator,
		"tick_count": tick_count,
	}


static func from_dict(data: Dictionary) -> ActiveEffect:
	var active := ActiveEffect.new()
	active.effect_id = StringName(data.get("effect_id", ""))
	active.source_id = StringName(data.get("source_id", ""))
	active.display_name = data.get("display_name", "")
	active.description = data.get("description", "")
	active.icon_id = StringName(data.get("icon_id", ""))
	active.duration_type = int(data.get("duration_type", EffectGrant.DurationType.PERMANENT))
	active.duration_remaining = float(data.get("duration_remaining", 0.0))
	active.uses_remaining = int(data.get("uses_remaining", 0))
	active.stack_behavior = int(data.get("stack_behavior", EffectGrant.StackBehavior.REPLACE))
	active.stacks = int(data.get("stacks", 1))
	active.max_stacks = int(data.get("max_stacks", 1))
	active.params = data.get("params", {})
	active.applied_at = int(data.get("applied_at", 0))
	active.tick_accumulator = float(data.get("tick_accumulator", 0.0))
	active.tick_count = int(data.get("tick_count", 0))

	var tags_data: Array = data.get("tags", [])
	for tag in tags_data:
		active.tags.append(StringName(tag))

	return active