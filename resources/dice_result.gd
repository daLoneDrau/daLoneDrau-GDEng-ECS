class_name DiceResult
extends RefCounted

## Structured result from a dice roll expression.
##
## Contains the original expression, individual die results grouped by type,
## kept/dropped dice for kh/kl/dh/dl operations, modifiers, and final total.

## The original expression that was rolled
var expression: String = ""

## Individual die results grouped by die type: {"d6": [3, 5, 2], "d4": [1, 4]}
var rolls: Dictionary[String, Array] = {}

## Flat modifier sum (the +5 in "2d6+5")
var modifier: int = 0

## Final total after all calculations
var total: int = 0

## Human-readable breakdown string for tooltips/logs
var breakdown: String = ""

## Whether the roll succeeded (for target number checks)
var success: bool = false

## Optional target number that was checked against
var target: int = 0

## Rolls that were dropped (for kh/kl/dh/dl operations)
var dropped: Dictionary[String, Array] = {}

## Rolls that were kept (for kh/kl/dh/dl operations)
var kept: Dictionary[String, Array] = {}

## Rolls added from explosions
var explosions: Dictionary[String, Array] = {}

## Rolls that were rerolled (original values before reroll)
var rerolled: Dictionary[String, Array] = {}


func _init(expr: String = "") -> void:
	expression = expr


## Initialize with an expression string
func with_expression(expr: String) -> DiceResult:
	expression = expr
	return self


## Returns all individual die results as a flat array
func get_all_rolls() -> Array[int]:
	var all_rolls: Array[int] = []
	for die_type in rolls:
		for roll_value in rolls[die_type]:
			all_rolls.append(roll_value)
	return all_rolls


## Returns the sum of just the dice (excluding modifier)
func get_dice_total() -> int:
	return total - modifier


## Returns a formatted string of the roll breakdown
func get_breakdown() -> String:
	if not breakdown.is_empty():
		return breakdown

	var parts: Array[String] = []

	for die_type in rolls:
		var die_rolls: Array = rolls[die_type]
		if die_rolls.size() > 0:
			var rolls_str: String = "[" + ", ".join(die_rolls.map(func(x): return str(x))) + "]"
			parts.append("%dd%s: %s" % [die_rolls.size(), die_type.trim_prefix("d"), rolls_str])

	if modifier != 0:
		var mod_sign: String = "+" if modifier > 0 else ""
		parts.append("mod: %s%d" % [mod_sign, modifier])

	return " | ".join(parts) + " = %d" % total


## Returns a compact string representation
func _to_string() -> String:
	return "DiceResult(%s = %d)" % [expression, total]


## Serializes the result to a dictionary
func to_dict() -> Dictionary:
	return {
		"expression": expression,
		"rolls": rolls.duplicate(true),
		"modifier": modifier,
		"total": total,
		"breakdown": breakdown,
		"success": success,
		"target": target,
		"dropped": dropped.duplicate(true),
		"kept": kept.duplicate(true),
		"explosions": explosions.duplicate(true),
		"rerolled": rerolled.duplicate(true),
	}


## Creates a DiceResult from a dictionary
static func from_dict(data: Dictionary) -> DiceResult:
	var result := DiceResult.new().with_expression(data.get("expression", ""))
	result.rolls = data.get("rolls", {})
	result.modifier = data.get("modifier", 0)
	result.total = data.get("total", 0)
	result.breakdown = data.get("breakdown", "")
	result.success = data.get("success", false)
	result.target = data.get("target", 0)
	result.dropped = data.get("dropped", {})
	result.kept = data.get("kept", {})
	result.explosions = data.get("explosions", {})
	result.rerolled = data.get("rerolled", {})
	return result