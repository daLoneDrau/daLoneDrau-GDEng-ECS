class_name StatModifierEntry
extends Resource

## Who/what applied this modifier (for removal)
var source_id: StringName = &""

## The modification amount
var amount: int = 0

## If true, amount is a percentage of base
var is_percentage: bool = false

## For stacking rules: same group = only highest applies
## Empty = always stacks additively
var stack_group: StringName = &""

## UI/display hints (optional - systems can ignore)
var display_name: String = ""  # "Ring of Strength +1"
var icon_id: StringName = &""  # For buff bar display

## Duration hint (interpreted by systems, not by Stat)
enum DurationType { PERMANENT, TIMED, END_OF_COMBAT, CONDITIONAL }
var duration_type: DurationType = DurationType.PERMANENT

## Optional: for debugging/tooltips
var description: String = ""


static func create(
	p_source: StringName,
	p_amount: int,
	p_is_percentage: bool = false,
	p_stack_group: StringName = &""
) -> StatModifierEntry:
	var entry := StatModifierEntry.new()
	entry.source_id = p_source
	entry.amount = p_amount
	entry.is_percentage = p_is_percentage
	entry.stack_group = p_stack_group
	return entry


func _to_string() -> String:
	var suffix := "%" if is_percentage else ""
	var op_sign := "+" if amount >= 0 else ""
	return "%s%d%s from %s" % [op_sign, amount, suffix, source_id]


func to_dict() -> Dictionary:
	return {
		"source_id": String(source_id),
		"amount": amount,
		"is_percentage": is_percentage,
		"stack_group": String(stack_group),
		"display_name": display_name,
		"icon_id": String(icon_id),
		"duration_type": duration_type,
		"description": description,
	}


static func from_dict(data: Dictionary) -> StatModifierEntry:
	var entry := StatModifierEntry.new()
	entry.source_id = StringName(data.get("source_id", ""))
	entry.amount = int(data.get("amount", 0))
	entry.is_percentage = bool(data.get("is_percentage", false))
	entry.stack_group = StringName(data.get("stack_group", ""))
	entry.display_name = data.get("display_name", "")
	entry.icon_id = StringName(data.get("icon_id", ""))
	entry.duration_type = int(data.get("duration_type", DurationType.PERMANENT)) as DurationType
	entry.description = data.get("description", "")
	return entry
