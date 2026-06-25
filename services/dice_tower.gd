class_name DiceTower
extends Node

## Dice Tower - Advanced dice rolling utility (Autoload Singleton)
##
## Supports expressions like:
##   "3d6"         - Roll 3 six-sided dice
##   "2d4+1"       - Roll 2d4 and add 1
##   "3d6+2d4+5"   - Multiple dice groups with modifier
##   "4d6kh3"      - Roll 4d6, keep highest 3
##   "4d6dl1"      - Roll 4d6, drop lowest 1
##   "2d20kl1"     - Roll 2d20, keep lowest 1 (disadvantage)AC
##   "2d20kh1"     - Roll 2d20, keep highest 1 (advantage)
##   "d20"         - Single die (1d20)
##   "3d6!"        - Exploding dice (reroll and add on max)
##   "1d10!>=9"    - Exploding on 9 or higher
##   "3d6r1"       - Reroll 1s once
##   "(2d6+1)+d4"  - Parenthetical expressions
##
## Usage:
##   var result = DiceTower.roll_result("3d6+2")
##   print(result.total)
##   print(result.get_breakdown())
##
##   var total = DiceTower.roll("2d6+3")  # Quick integer result

signal dice_rolled(result: DiceResult)

## Random number generator (use exclusively for consistent seeding)
static var _rng := RandomNumberGenerator.new()


## Set a fixed seed for reproducible rolls (useful for testing)
static func seed(v: int = 0) -> void:
	_rng.seed = v


## Randomize the RNG (call to reset to non-deterministic)
static func randomize_seed() -> void:
	_rng.randomize()


## Get current RNG state (for save/load)
static func get_rng_state() -> int:
	return _rng.state


## Set RNG state (for save/load)
static func set_rng_state(state: int) -> void:
	_rng.state = state


func _ready() -> void:
	# Ensure RNG is randomized if no explicit seed was set
	if _rng.seed == 0:
		_rng.randomize()


## —————————————————————————————————————————————
#region Public API - Core Rolling
## —————————————————————————————————————————————


## Roll and return a structured DiceResult object
func roll_result(expr: String) -> DiceResult:
	var parser := ExpressionParser.new(self, expr)
	var result := parser.parse_to_result()
	dice_rolled.emit(result)
	return result


## Roll and return an integer total (backward compatible)
func roll(expr: String) -> int:
	return roll_result(expr).total


## Roll and return a dictionary with total and breakdown (backward compatible)
func roll_breakdown(expr: String) -> Dictionary:
	var result := roll_result(expr)
	return {
		"total": result.total,
		"breakdown": result.breakdown,
		"text": result.breakdown  # Legacy key
	}


## Roll against a target number, returns DiceResult with success flag
func roll_check(expr: String, target: int) -> DiceResult:
	var result := roll_result(expr)
	result.target = target
	result.success = result.total >= target
	return result


## Roll against a target where lower is better (e.g., roll-under systems)
func roll_check_under(expr: String, target: int) -> DiceResult:
	var result := roll_result(expr)
	result.target = target
	result.success = result.total <= target
	return result

#endregion

## —————————————————————————————————————————————
#region Public API - D20 Helpers
## —————————————————————————————————————————————


## Roll with advantage (2d20, keep highest) + modifier
func adv(mod: int = 0) -> int:
	var expr := "2d20kh1" + _format_modifier(mod)
	return roll(expr)


## Roll with advantage, return full result
func adv_result(mod: int = 0) -> DiceResult:
	var expr := "2d20kh1" + _format_modifier(mod)
	return roll_result(expr)


## Roll with disadvantage (2d20, keep lowest) + modifier
func dis(mod: int = 0) -> int:
	var expr := "2d20kl1" + _format_modifier(mod)
	return roll(expr)


## Roll with disadvantage, return full result
func dis_result(mod: int = 0) -> DiceResult:
	var expr := "2d20kl1" + _format_modifier(mod)
	return roll_result(expr)


## Standard D&D ability score roll (4d6, drop lowest)
func roll_ability_score() -> DiceResult:
	return roll_result("4d6dl1")

#endregion

## —————————————————————————————————————————————
#region Public API - Fighting Fantasy Helpers
## —————————————————————————————————————————————


## Roll initial SKILL (1d6 + 6)
func roll_skill() -> DiceResult:
	return roll_result("1d6+6")


## Roll initial STAMINA (2d6 + 12)
func roll_stamina() -> DiceResult:
	return roll_result("2d6+12")


## Roll initial LUCK (1d6 + 6)
func roll_luck() -> DiceResult:
	return roll_result("1d6+6")


## Test your Luck - roll 2d6, succeed if <= current luck
func test_luck(current_luck: int) -> DiceResult:
	var result := roll_result("2d6")
	result.target = current_luck
	result.success = result.total <= current_luck
	return result


## Attack roll (2d6 + skill) for Attack Strength calculation
func roll_attack(skill: int) -> DiceResult:
	return roll_result("2d6+%d" % skill)


## Combat round - returns attacker and defender Attack Strengths
func roll_combat(attacker_skill: int, defender_skill: int) -> Dictionary:
	var attacker := roll_attack(attacker_skill)
	var defender := roll_attack(defender_skill)

	var winner: String = "tie"
	if attacker.total > defender.total:
		winner = "attacker"
	elif defender.total > attacker.total:
		winner = "defender"

	return {
		"attacker": attacker,
		"defender": defender,
		"winner": winner
	}

#endregion

## —————————————————————————————————————————————
#region Public API - Simple Die Rollers
## —————————————————————————————————————————————


## Roll a single die with N sides
func roll_die(sides: int) -> int:
	return _roll_single(sides)


## Rolls an x-sided die (alias for roll_die)
func roll_dx(faces: int) -> int:
	return _roll_single(faces)


## Rolls an x-sided die plus a modifier
func roll_dx_plus_y(faces: int, modifier: int) -> int:
	return _roll_single(faces) + modifier


## Roll multiple dice of the same type, return array
func roll_dice(n: int, sides: int) -> Array:
	var arr: Array = []
	for i in n:
		arr.append(_roll_single(sides))
	return arr


## Rolls x dice of y sides and returns the sum
func roll_x_dy(rolls: int, faces: int) -> int:
	var sum: int = 0
	for x in range(rolls):
		sum += _roll_single(faces)
	return sum


## Roll a percentile (1-100)
func roll_percentile() -> int:
	return _roll_single(100)


## Coin flip (returns true for heads/high)
func flip_coin() -> bool:
	return _roll_single(2) == 2

#endregion

## —————————————————————————————————————————————
#region Public API - Random Selection
## —————————————————————————————————————————————


## Get a random value from a dictionary
func get_random_from_dictionary(dict: Dictionary) -> Variant:
	if dict.is_empty():
		return null
	var keys := dict.keys()
	return dict[keys[_rng.randi() % keys.size()]]


## Get a random element from an array
func get_random_from_list(list: Array) -> Variant:
	if list.is_empty():
		return null
	return list[_rng.randi() % list.size()]


## Pick N random items from an array (no duplicates)
func pick_random(array: Array, count: int = 1) -> Array:
	if array.is_empty():
		return []

	var available := array.duplicate()
	var picked: Array = []
	var to_pick := mini(count, available.size())

	for i in to_pick:
		var index := _rng.randi() % available.size()
		picked.append(available[index])
		available.remove_at(index)

	return picked


## Weighted choice from dictionary: {"option_key": {"weight": N, ...}, ...}
func weighted_choice(options: Dictionary) -> String:
	if options.is_empty():
		return ""

	var total: int = 0
	for k in options.keys():
		var weight_val = options[k]
		if weight_val is Dictionary:
			total += int(weight_val.get("weight", 1))
		else:
			total += int(weight_val)

	if total <= 0:
		return options.keys()[0]

	var die_roll := _rng.randi() % total
	var running: int = 0

	for k in options.keys():
		var weight_val = options[k]
		if weight_val is Dictionary:
			running += int(weight_val.get("weight", 1))
		else:
			running += int(weight_val)
		if die_roll < running:
			return k

	return options.keys()[0]


## Weighted choice from simple dictionary: {"option": weight, ...}
func weighted_choice_simple(options: Dictionary) -> Variant:
	if options.is_empty():
		return null

	var total: float = 0.0
	for weight in options.values():
		total += float(weight)

	if total <= 0:
		return options.keys()[0]

	var roll_value: float = _rng.randf() * total
	var cumulative: float = 0.0

	for option in options:
		cumulative += float(options[option])
		if roll_value <= cumulative:
			return option

	return options.keys()[0]


## Shuffle an array in place and return it
func shuffle(array: Array) -> Array:
	# Fisher-Yates shuffle using our RNG
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp
	return array

#endregion

## —————————————————————————————————————————————
#region Internal Helpers
## —————————————————————————————————————————————


## Single die roll using consistent RNG
func _roll_single(sides: int) -> int:
	if sides <= 0:
		push_warning("DiceTower: Invalid die sides: %d" % sides)
		return 0
	return _rng.randi_range(1, sides)


func _format_modifier(mod: int) -> String:
	if mod == 0:
		return ""
	elif mod > 0:
		return "+%d" % mod
	else:
		return "%d" % mod

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————


func print_roll_debug(expression: String) -> void:
	var result := roll_result(expression)
	print("=== DiceTower Debug ===")
	print("  Expression: %s" % expression)
	print("  Breakdown: %s" % result.breakdown)
	print("  Rolls: %s" % result.rolls)
	if not result.dropped.is_empty():
		print("  Dropped: %s" % result.dropped)
	if not result.kept.is_empty():
		print("  Kept: %s" % result.kept)
	if not result.explosions.is_empty():
		print("  Explosions: %s" % result.explosions)
	if not result.rerolled.is_empty():
		print("  Rerolled: %s" % result.rerolled)
	print("  Modifier: %d" % result.modifier)
	print("  Total: %d" % result.total)

#endregion


## —————————————————————————————————————————————
## Expression Parser (Inner Class)
## —————————————————————————————————————————————
class ExpressionParser:
	var tower: DiceTower
	var expr: String
	var s: String
	var pos: int
	var _debug: bool = false

	# Accumulate data for DiceResult
	var _result: DiceResult

	func _init(_tower: DiceTower, _expr: String):
		tower = _tower
		expr = _expr


	func parse_to_result() -> DiceResult:
		_result = DiceResult.new(expr)

		if _debug:
			print("\tparse expression\n", expr)

		s = expr.strip_edges().replace(" ", "").to_lower()
		pos = 0

		if s.is_empty():
			_result.breakdown = "(empty)"
			return _result

		var out: Dictionary = parse_expr()

		# Leftover characters warning
		if pos < s.length():
			push_warning("Unparsed trailing input at %d in '%s'" % [pos, expr])

		_result.total = int(out.get("total", 0))
		_result.breakdown = out.get("text", str(_result.total))

		if _debug:
			print("\tparsed expression\n", out)

		return _result


	## Peeks at the next character in the string.
	func peek() -> String:
		return "" if pos >= s.length() else s[pos]


	## Gets the next character and advances position.
	func consume() -> String:
		if pos >= s.length():
			return ""
		var ch: String = s[pos]
		pos += 1
		return ch


	## Parses an integer from current position.
	func parse_number() -> int:
		var start: int = pos
		while pos < s.length() and s[pos].is_valid_int():
			pos += 1
		if start == pos:
			push_error("Expected number at %d in '%s'" % [pos, expr])
			return 0
		return int(s.substr(start, pos - start))


	## Parses a comparison expression: >=5, >5, =5
	func parse_cmp() -> Dictionary:
		if pos >= s.length():
			return {}

		var op: String = ""
		if pos + 1 < s.length() and s.substr(pos, 2) == ">=":
			op = ">="
			pos += 2
		elif s[pos] == ">":
			op = ">"
			pos += 1
		elif s[pos] == "=":
			op = "="
			pos += 1
		else:
			return {}

		var t: int = parse_number()
		return {"operation": op, "threshold": t}


	## Checks if a value passes a comparison for explosion.
	func cmp_pass(val: int, cmp: Dictionary, sides: int) -> bool:
		var passes: bool = val == sides  # Default: explode on max
		if not cmp.is_empty():
			match cmp["operation"]:
				">=":
					passes = val >= int(cmp["threshold"])
				">":
					passes = val > int(cmp["threshold"])
				"=":
					passes = val == int(cmp["threshold"])
				_:
					passes = false
		return passes


	## Main expression parser - handles +, -, * chains
	func parse_expr() -> Dictionary:
		var parts: Array = []

		while pos < s.length():
			if _debug:
				print("\tpos", pos)

			var term: Dictionary = parse_term()

			if _debug:
				print("\tterm", term)

			if term.size() > 0:
				parts.append(term)
			else:
				var op: String = peek()
				if op in ["+", "-", "*"]:
					consume()
					var mode: String = ""
					match op:
						"+": mode = "add"
						"-": mode = "subtract"
						"*": mode = "multiply"
					parts.append({"type": "operation", "mode": mode})
				elif op == "(":
					consume()
					parts.append(parse_expr())
				elif op == ")":
					consume()
					break
				else:
					break

		# Evaluate the parts chain
		return _evaluate_parts(parts)


	## Evaluates a chain of parts with operations
	func _evaluate_parts(parts: Array) -> Dictionary:
		if parts.is_empty():
			return {"total": 0, "text": "0"}

		if parts.size() == 1:
			return parts[0]

		# Process left-to-right (no operator precedence for simplicity)
		var result: Dictionary = parts[0]
		var result_text: String = result.get("text", str(result.get("total", 0)))
		var i: int = 1

		while i < parts.size() - 1:
			var op: Dictionary = parts[i]
			var right: Dictionary = parts[i + 1]
			var right_total: int = int(right.get("total", 0))
			var right_text: String = right.get("text", str(right_total))

			var op_symbol: String = "+"
			match op.get("mode", ""):
				"add":
					result["total"] = int(result["total"]) + right_total
					op_symbol = "+"
				"subtract":
					result["total"] = int(result["total"]) - right_total
					op_symbol = "-"
				"multiply":
					result["total"] = int(result["total"]) * right_total
					op_symbol = "*"

			result_text = "%s %s %s" % [result_text, op_symbol, right_text]
			i += 2

		result["text"] = result_text + " = " + str(result["total"])
		return result


	## Parse a term (factor or grouped expression)
	func parse_term() -> Dictionary:
		var factors: Array = []
		var factor: Dictionary = parse_factor()

		while factor.size() > 0:
			factors.append(factor)

			# Check if next char could start another factor
			if peek() in ["d", "("] or (peek().is_valid_int() and _looks_like_dice()):
				factor = parse_factor()
			else:
				break

		if factors.is_empty():
			return {}

		# Build term from factors
		return _build_term_from_factors(factors)


	## Check if current position looks like start of dice expression
	func _looks_like_dice() -> bool:
		var save := pos
		while pos < s.length() and s[pos].is_valid_int():
			pos += 1
		var has_d := pos < s.length() and s[pos] == "d"
		pos = save
		return has_d


	## Build a term from parsed factors
	func _build_term_from_factors(factors: Array) -> Dictionary:
		if factors.size() == 1:
			var f: Dictionary = factors[0]
			if f.get("type") == "dice":
				return _roll_dice_term(1, f)
			elif f.get("type") == "const":
				# Track modifier in result
				_result.modifier += f["value"]
				return {"total": f["value"], "text": str(f["value"]), "type": "const"}
			else:
				return f

		if factors.size() == 2:
			if factors[0].get("type") == "const" and factors[1].get("type") == "dice":
				return _roll_dice_term(factors[0]["value"], factors[1])

		# Fallback: sum all factors
		var total: int = 0
		var texts: Array = []
		for f in factors:
			total += int(f.get("total", f.get("value", 0)))
			texts.append(f.get("text", str(f.get("value", 0))))
		return {"total": total, "text": " ".join(texts)}


	## Parse a single factor (number, dice, or parenthetical)
	func parse_factor() -> Dictionary:
		# Skip whitespace
		while peek() == " ":
			consume()

		# Parenthetical expression
		if peek() == "(":
			consume()
			var inner: Dictionary = parse_expr()
			if peek() == ")":
				consume()
			else:
				push_error("Expected ')' at %d in '%s'" % [pos, expr])
			return inner

		# Number
		if peek().is_valid_int():
			var n: int = parse_number()
			# Check if followed by 'd' (dice notation)
			if peek() == "d":
				# This is the count for dice, return as const to be combined
				return {"type": "const", "value": n}
			else:
				return {"type": "const", "value": n, "total": n, "text": str(n)}

		# Dice: [N]d[S][!][cmp][kh/kl/dh/dl N][rN]
		if peek() == "d":
			consume()

			if pos >= s.length() or not s[pos].is_valid_int():
				push_error("Expected sides after 'd' at %d in '%s'" % [pos, expr])
				return {"total": 0, "text": "d?"}

			var sides: int = parse_number()

			var dice_info: Dictionary = {
											"type": "dice",
											"sides": sides,
											"explode": {"enabled": false, "comparison": {"operation": "=", "threshold": sides}},
										}

			# Explode modifier: !
			if peek() == "!":
				dice_info["explode"]["enabled"] = true
				consume()
				var cmp_dict: Dictionary = parse_cmp()
				if not cmp_dict.is_empty():
					dice_info["explode"]["comparison"] = cmp_dict

			# Keep/drop modifier: kh, kl, dh, dl
			if pos + 1 < s.length():
				var two := s.substr(pos, 2)
				if two in ["kh", "kl", "dh", "dl"]:
					pos += 2
					var kd_n: int = parse_number()
					match two:
						"kh":
							dice_info["keep"] = {"mode": "highest", "number": kd_n}
						"kl":
							dice_info["keep"] = {"mode": "lowest", "number": kd_n}
						"dh":
							dice_info["drop"] = {"mode": "highest", "number": kd_n}
						"dl":
							dice_info["drop"] = {"mode": "lowest", "number": kd_n}

			# Reroll modifier: rN
			if peek() == "r":
				consume()
				dice_info["reroll"] = parse_number()

			return dice_info

		return {}


	## Roll dice and build result
	func _roll_dice_term(count: int, dice_info: Dictionary) -> Dictionary:
		var sides: int = dice_info["sides"]
		var die_key: String = "d%d" % sides

		# Initial rolls
		var rolls: Array = tower.roll_dice(count, sides)

		# Handle rerolls (rN = reroll Ns once)
		var rerolled_values: Array = []
		if "reroll" in dice_info:
			var reroll_val: int = dice_info["reroll"]
			for i in range(rolls.size()):
				if rolls[i] == reroll_val:
					rerolled_values.append(rolls[i])
					rolls[i] = tower._roll_single(sides)

		# Store rerolled info
		if not rerolled_values.is_empty():
			if not _result.rerolled.has(die_key):
				_result.rerolled[die_key] = []
			_result.rerolled[die_key].append_array(rerolled_values)

		# Handle explosions
		var explosion_rolls: Array = []
		if dice_info["explode"]["enabled"]:
			var cmp: Dictionary = dice_info["explode"]["comparison"]
			for roll_val in rolls:
				explosion_rolls.append_array(_explode_roll(roll_val, sides, cmp))

		# Combine rolls with explosions for keep/drop calculations
		var all_rolls: Array = rolls + explosion_rolls

		# Store explosion info
		if not explosion_rolls.is_empty():
			if not _result.explosions.has(die_key):
				_result.explosions[die_key] = []
			_result.explosions[die_key].append_array(explosion_rolls)

		# Handle keep/drop
		var kept_rolls: Array = all_rolls.duplicate()
		var dropped_rolls: Array = []

		if "keep" in dice_info or "drop" in dice_info:
			kept_rolls.sort()

			if "keep" in dice_info:
				var keep_n: int = dice_info["keep"]["number"]
				match dice_info["keep"]["mode"]:
					"highest":
						dropped_rolls = kept_rolls.slice(0, max(0, kept_rolls.size() - keep_n))
						kept_rolls = kept_rolls.slice(max(0, kept_rolls.size() - keep_n))
					"lowest":
						dropped_rolls = kept_rolls.slice(min(keep_n, kept_rolls.size()))
						kept_rolls = kept_rolls.slice(0, min(keep_n, kept_rolls.size()))
			elif "drop" in dice_info:
				var drop_n: int = dice_info["drop"]["number"]
				match dice_info["drop"]["mode"]:
					"highest":
						dropped_rolls = kept_rolls.slice(max(0, kept_rolls.size() - drop_n))
						kept_rolls = kept_rolls.slice(0, max(0, kept_rolls.size() - drop_n))
					"lowest":
						dropped_rolls = kept_rolls.slice(0, min(drop_n, kept_rolls.size()))
						kept_rolls = kept_rolls.slice(min(drop_n, kept_rolls.size()))

		# Store in result
		if not _result.rolls.has(die_key):
			_result.rolls[die_key] = []
		_result.rolls[die_key].append_array(all_rolls)

		if not dropped_rolls.is_empty():
			if not _result.dropped.has(die_key):
				_result.dropped[die_key] = []
			_result.dropped[die_key].append_array(dropped_rolls)

		if dropped_rolls.size() > 0:
			if not _result.kept.has(die_key):
				_result.kept[die_key] = []
			_result.kept[die_key].append_array(kept_rolls)

		# Calculate total
		var total: int = 0
		for v in kept_rolls:
			total += int(v)

		# Build text breakdown
		var txt: String = "%dd%d" % [count, sides]
		if dice_info["explode"]["enabled"]:
			txt += "!"
			var cmp: Dictionary = dice_info["explode"]["comparison"]
			if cmp.get("threshold", sides) != sides or cmp.get("operation", "=") != "=":
				txt += "%s%d" % [cmp["operation"], int(cmp["threshold"])]
		if "keep" in dice_info:
			txt += "%s%d" % ["kh" if dice_info["keep"]["mode"] == "highest" else "kl", dice_info["keep"]["number"]]
		if "drop" in dice_info:
			txt += "%s%d" % ["dh" if dice_info["drop"]["mode"] == "highest" else "dl", dice_info["drop"]["number"]]
		if "reroll" in dice_info:
			txt += "r%d" % dice_info["reroll"]

		txt += " → [" + ", ".join(all_rolls.map(func(x): return str(x))) + "]"

		if not dropped_rolls.is_empty():
			txt += " keep [" + ", ".join(kept_rolls.map(func(x): return str(x))) + "]"

		txt += " = " + str(total)

		return {"total": total, "text": txt, "type": "dice"}


	## Recursively explode a die roll
	func _explode_roll(rolled_value: int, sides: int, comparison: Dictionary) -> Array:
		var explosions: Array = []
		if cmp_pass(rolled_value, comparison, sides):
			var new_roll: int = tower._roll_single(sides)
			explosions.append(new_roll)
			explosions.append_array(_explode_roll(new_roll, sides, comparison))
		return explosions
