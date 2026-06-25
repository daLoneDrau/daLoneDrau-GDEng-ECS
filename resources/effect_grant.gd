## Defines a special effect granted by an item, spell, or ability.
## Examples: Poison Immunity, Drain Life, Fire Resistance, See Invisible
class_name EffectGrant
extends Resource

## The effect identifier (e.g., &"poison_immunity", &"drain_life")
@export var effect_id: StringName = &""

## Display name for UI
@export var display_name: String = ""

## Description for tooltips
@export var description: String = ""

## Icon for buff bar / inventory display
@export var icon_id: StringName = &""

## Duration type hint (systems interpret this)
enum DurationType {
	PERMANENT,      # While equipped / always active
	TIMED,          # Expires after duration_seconds
	END_OF_COMBAT,  # Removed when combat ends
	USES,           # Expires after N uses
	CONDITIONAL     # Removed when condition no longer met
}
@export var duration_type: DurationType = DurationType.PERMANENT

## For TIMED effects: duration in seconds
@export var duration_seconds: float = 0.0

## For USES effects: number of uses
@export var uses: int = 0

## Effect-specific parameters
## Examples:
##   Drain Life: { "percent": 25 } - heal 25% of damage dealt
##   Fire Resistance: { "reduction": 50 } - 50% fire damage reduction
##   Poison: { "damage_per_tick": 2, "tick_interval": 1.0 }
@export var params: Dictionary = {}

## Stack behavior
enum StackBehavior {
	REPLACE,        # New application replaces old
	REFRESH,        # Reset duration, keep stacks
	STACK,          # Accumulate stacks (up to max_stacks)
	IGNORE          # Don't apply if already active
}
@export var stack_behavior: StackBehavior = StackBehavior.REPLACE
@export var max_stacks: int = 1


static func create(
	p_effect_id: StringName,
	p_display_name: String = "",
	p_params: Dictionary = {}
) -> EffectGrant:
	var grant := EffectGrant.new()
	grant.effect_id = p_effect_id
	grant.display_name = p_display_name if p_display_name else String(p_effect_id).capitalize()
	grant.params = p_params
	return grant


func _to_string() -> String:
	var duration_str := ""
	match duration_type:
		DurationType.TIMED:
			duration_str = " (%.1fs)" % duration_seconds
		DurationType.USES:
			duration_str = " (%d uses)" % uses
		DurationType.END_OF_COMBAT:
			duration_str = " (combat)"

	return "%s%s" % [StringName(display_name) if display_name else effect_id, duration_str]


func to_dict() -> Dictionary:
	return {
		"effect_id": String(effect_id),
		"display_name": display_name,
		"description": description,
		"icon_id": String(icon_id),
		"duration_type": duration_type,
		"duration_seconds": duration_seconds,
		"uses": uses,
		"params": params,
		"stack_behavior": stack_behavior,
		"max_stacks": max_stacks,
	}


static func from_dict(data: Dictionary) -> EffectGrant:
	var grant := EffectGrant.new()
	grant.effect_id = StringName(data.get("effect_id", ""))
	grant.display_name = data.get("display_name", "")
	grant.description = data.get("description", "")
	grant.icon_id = StringName(data.get("icon_id", ""))
	grant.duration_type = int(data.get("duration_type", DurationType.PERMANENT)) as DurationType
	grant.duration_seconds = float(data.get("duration_seconds", 0.0))
	grant.uses = int(data.get("uses", 0))
	grant.params = data.get("params", {})
	grant.stack_behavior = int(data.get("stack_behavior", StackBehavior.REPLACE)) as StackBehavior
	grant.max_stacks = int(data.get("max_stacks", 1))
	return grant