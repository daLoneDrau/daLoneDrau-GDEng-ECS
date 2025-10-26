class_name DiceTower extends Node


## the singleton instance
static var instance: DiceTower

static var _rng := RandomNumberGenerator.new()

static func seed(v: int = 0) -> void:
	_rng.seed = v

static func randomize() -> void:
	_rng.randomize()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	instance = self
	# Ensure RNG is randomized if no explicit seed was set
	if _rng.seed == 0:
		_rng.randomize()


# ────────────────────────────────────────────────────────────────────────────
# Internal: expression evaluation
# Grammar (simplified):
#   EXPR := TERM (('+'|'-') TERM)*
#   TERM := FACTOR | '(' EXPR ')'
#   FACTOR := DICE | NUMBER
#   DICE := [N]? 'd' S [EXPLODE] [KEEPDROP]
#   EXPLODE := '!' [CMP]
#   CMP := '>=T' | '>T' | '=T'
#   KEEPDROP := ('kh'|'kl'|'dh'|'dl') N
# Examples:
#   4d6kh3, 4d6dl1, 1d10!>=9, d8!, 2d6+3, (2d6+1)+d4
# ────────────────────────────────────────────────────────────────────────────

func _eval(expr: String) -> Dictionary:
	var parser: ExpressionParser = ExpressionParser.new(self, expr)
	return parser.parse()


## Quick helpers for d20 advantage.
func adv(mod: int = 0) -> int:
	var a: Array[int] = roll_dice(2, 20)
	var keep = max(a[0], a[1])
	return keep + mod


## Quick helpers for d20 disadvantage.
func dis(mod: int = 0) -> int:
	var a: Array[int] = roll_dice(2, 20)
	var keep = min(a[0], a[1])
	return keep + mod

func get_random_from_dictionary(dict: Dictionary) -> Variant:
	return dict.values()[randi() % dict.size()]


func get_random_from_list(list: Array) -> Variant:
	return list[randi() % list.size()]


## Roll and return an integer total. Raises push_error on parse issues.
func roll(expr: String) -> int:
	var result: Dictionary = _eval(expr)
	return int(result["total"])


## Roll and also return a human-readable breakdown (for tooltips/logs).
## Returns: {"total": int, "breakdown": String}
func roll_breakdown(expr: String) -> Dictionary:
	return _eval(expr)

# Core rollers
func roll_dice(n: int, sides: int) -> Array:
	var arr: Array = []
	for i in n:
		arr.append(_rng.randi_range(1, max(1, sides)))
	return arr


## Rolls an x-sided die.
func roll_dx(faces: int) -> int:
	return randi() % faces + 1


## Rolls an x-sided die plus a modifier.
func roll_dx_plus_y(faces: int, modifier: int) -> int:
	return randi() % faces + 1 + modifier


## Rolls an x-sided die, y number of times
func roll_x_dy(rolls: int, faces: int) -> int:
	var sum: int = 0
	for x in range(rolls):
		sum += roll_dx(faces)
	return sum


func weighted_choice(options: Dictionary) -> String:
	var total: int = 0
	for k in options.keys():
		total += int(options[k]["weight"])
	var die_roll         = randi() % total
	var running: int = 0
	for k in options.keys():
		running += int(options[k]["weight"])
		if die_roll < running:
			return k
	return options.keys()[0]  # fallback


class ExpressionParser:
	var tower: DiceTower
	var expr: String
	var s: String
	var pos: int
	var _debug: bool = false

	func _init(_tower: DiceTower, _expr: String):
		tower = _tower
		expr = _expr

	func parse() -> Dictionary:
		if _debug:
			print("\tparse expression\n", expr)
		s = expr.strip_edges().replace(" ", "")
		pos = 0

		var out: Dictionary = parse_expr()
		# leftover characters?
		if pos < s.length():
			push_warning("Unparsed trailing input at %d in '%s'" % [pos, expr])

		if _debug:
			print("\tparsed expression\n", out)
		return out

	## Peeks at the next character in the string.
	func peek() -> String:
		return "" if pos >= s.length() else s[pos]


	## Gets the next character in the expression and moves the position up by 1.
	func consume() -> String:
		if pos >= s.length():
			return ""
		var ch: String = s[pos]
		pos += 1
		return ch


	## Gets a number from the expression and moves the position up by to the end of the number.
	func parse_number() -> int:
		var start: int = pos
		while pos < s.length() and s[pos].is_valid_int():
			pos += 1
		if start == pos:
			push_error("Expected number at %d in '%s'" % [pos, expr])
			return 0
		return int(s.substr(start, pos - start))


	## Parses a comparison expression, such as >=5, or =27 and returns it as a dictionary with two keys: "operation" (=, >, >=) and "threshold".
	func parse_cmp() -> Dictionary:
		# returns {"op": String, "t": int} or {}
		if pos >= s.length():
			return {}
		# operators we support: >=, >, =
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

	## Checks to see if a comparison passes.
	func cmp_pass(val: int, cmp: Dictionary, sides: int) -> bool:
		var passes: bool = val == sides  # default explode on max
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

	func parse_expr() -> Dictionary:
		var ret_val: Dictionary = {}
		# Splits the string into parts — numbers, operators, and dice terms.
		# Builds a tree or linear representation of operations.
		var parts: Array = []
		while pos < s.length():
			if _debug:
				print("\tpos", pos)
			var term: Dictionary = parse_term()
			if _debug:
				print("\tterm", term)

			# was this a term?
			if term.size() > 0:
				parts.append(term)
			else:
				# not a term
				var op: String = peek()
				if op == "+" or op == "-" or op == "*":
					# reading an operation. save the operation type and keep processing
					if op == "+":
						consume()
						parts.append({
							"type": "operation",
							"mode": "add"
						})
					elif op == "-":
						consume()
						parts.append({
							"type": "operation",
							"mode": "subtract"
						})
					elif op == "*":
						consume()
						parts.append({
							"type": "operation",
							"mode": "multiply"
						})
				else:
					if op == "(" or op == ")":
						# reading an expression
						consume()
						if op == "(":
							# starting a new expression. call the parser again
							parts.append(parse_expr())
						else:
							# ended an inner expression. get out of the loop and return
							break

		if parts.size() == 1:
			ret_val = parts[0]
		elif parts.size() == 3:
			ret_val = {
				"type": "",
				"terms": []
			}
			for part in parts:
				if part["type"] == "operation":
					ret_val["type"] = part["mode"]
				else:
					ret_val["terms"].append(part)

			if ret_val["type"] == "add":
				ret_val["total"] = ret_val["terms"][0]["total"] + ret_val["terms"][1]["total"]
			elif ret_val["type"] == "subtract":
				ret_val["total"] = ret_val["terms"][0]["total"] - ret_val["terms"][1]["total"]
			elif ret_val["type"] == "multiply":
				ret_val["total"] = ret_val["terms"][0]["total"] * ret_val["terms"][1]["total"]

		return ret_val


	## FACTOR | '(' EXPR ')'
	func parse_term() -> Dictionary:
		var term: Dictionary = {}
		# a term is a factor or an expression.
		# a factor is a number, or a die-value
		var factors: Array = []
		var factor: Dictionary = parse_factor_2()
		while factor.size() > 0:
			# add the last factor
			factors.append(factor)

			# get the next one
			factor = parse_factor_2()

		if _debug:
			print("\tfactors\n", factor)

		# build the factors into a term
		if factors.size() == 1:
			if factors[0]["type"] == "dice":
				term = {
					"type": "dice",
					"count": 1,
					"sides": factors[0]["sides"],
					"explode": factors[0]["explode"],
				}
				if "keep" in factors[0]:
					term["keep"] = factors[0]["keep"]
				if "drop" in factors[0]:
					term["drop"] = factors[0]["drop"]
				roll_dice_term(term)
			elif factors[0]["type"] == "const":
				term = factors[0]
				term["total"] = term["value"]
		elif factors.size() == 2:
			if factors[0]["type"] == "const" and factors[1]["type"] == "dice":
				term = {
					"type": "dice",
					"count": factors[0]["value"],
					"sides": factors[1]["sides"],
					"explode": factors[1]["explode"],
				}
				if "keep" in factors[1]:
					term["keep"] = factors[1]["keep"]
				if "drop" in factors[1]:
					term["drop"] = factors[1]["drop"]
				roll_dice_term(term)

		return term

	func parse_factor_2() -> Dictionary:
		var ret_val: Dictionary[Variant, Variant] = {}

		# space
		if pos < s.length() and s[pos] == " ":
			consume()

		# number
		if pos < s.length() and s[pos].is_valid_int():
			ret_val = {"type": "const", "value": parse_number()}

		# dice
		if ret_val.size() == 0 and pos < s.length() and s[pos].to_lower() == "d":
			consume()

			# if expression is empty after the 'd', return an error
			if pos >= s.length() or not s[pos].is_valid_int():
				push_error("Expected sides after 'd' at %d in '%s'" % [pos, expr])
				ret_val = {"total": 0, "text": "d?"}

			# no error, keep processing
			if ret_val.size() == 0:
				ret_val = {
					"type": "dice",
					"sides": parse_number(),
				}
				ret_val["explode"] = {
					"enabled": false,
					"comparison": {
						"operation": "=",
						"threshold": ret_val["sides"]
					}
				}
				# explode?
				if peek() == "!":
					ret_val["explode"]["enabled"] = true
					consume()
					var cmp_dict: Dictionary = parse_cmp()
					if cmp_dict.size() > 0:
						ret_val["explode"]["comparison"] = cmp_dict

				# keep/drop?
				var kd_n: int = 0
				if pos + 1 <= s.length() - 1:
					var two = s.substr(pos, 2).to_lower()
					if two in ["kh","kl","dh","dl"]:
						pos += 2
						kd_n = parse_number()
						match two:
							"kh":
								ret_val["keep"] = {
									"mode": "highest",
									"number": kd_n
								}
							"kl":
								ret_val["keep"] = {
									"mode": "lowest",
									"number": kd_n
								}
							"dh":
								ret_val["drop"] = {
									"mode": "highest",
									"number": kd_n
								}
							"dl":
								ret_val["drop"] = {
									"mode": "lowest",
									"number": kd_n
								}

		return ret_val


	## Explodes a roll, returning an array containing all exploded rolls.
	func explode_rolls(rolled_value: int, sides: int, comparison: Dictionary) -> Array:
		var ret_val: Array = []
		if cmp_pass(rolled_value, comparison, sides):
			ret_val = tower.roll_dice(1, sides)
			ret_val += explode_rolls(ret_val[0], sides, comparison)

		return ret_val


	func roll_dice_term(term: Dictionary):
		term["rolls"] = tower.roll_dice(term["count"], term["sides"])

		# make a deep copy of the rolls array
		term["adjusted_rolls"] = term["rolls"].duplicate(true)
		if term["explode"]["enabled"]:
			var explosions: Array = []
			for rolled_value in term["adjusted_rolls"]:
				explosions += explode_rolls(
					rolled_value,
					term["sides"],
					term["explode"]["comparison"]
				)
			term["adjusted_rolls"] += explosions
		if "keep" in term or "drop" in term:
			# sort array from lowest to highest - [10, 5, 2.5, 8] becomes [2.5, 5, 8, 10]
			term["adjusted_rolls"].sort()
			if "keep" in term:
				var drop_number: int = term["adjusted_rolls"].size() - term["keep"]["number"]
				match term["keep"]["mode"]:
					"highest":
						for i in range(drop_number):
							# drop the lowest values from the front of the array
							term["adjusted_rolls"].pop_front()
					"lowest":
						for i in range(drop_number):
							# drop the highest values from the front of the array
							term["adjusted_rolls"].pop_back()
			else:
				var drop_number: int = term["drop"]["number"]
				match term["drop"]["mode"]:
					"highest":
						for i in range(drop_number):
							# drop the highest values from the front of the array
							term["adjusted_rolls"].pop_back()
					"lowest":
						for i in range(drop_number):
							# drop the lowest values from the front of the array
							term["adjusted_rolls"].pop_front()
		var total: int = 0
		for i in range(term["adjusted_rolls"].size()):
			total += term["adjusted_rolls"][i]
		term["total"] = total

	func parse_factor() -> Dictionary:
		# number
		if pos < s.length() and s[pos].is_valid_int():
			var n: int = parse_number()
			return {"type": "const", "value": n}

		# parentheses
		if peek() == "(":
			consume() # '('
			var inner: Dictionary = parse_expr()
			if peek() != ")":
				push_error("Expected ')' at %d in '%s'" % [pos, expr])
			else:
				consume()
			return inner

		# dice: [N]? 'd' S [! [cmp]] [ (kh|kl|dh|dl) N ]
		# Examples: d6, 2d6, 4d6kh3, 1d10!>=9
		var save: int = pos
		var count: int = 1
		# optional leading number
		if pos < s.length() and s[pos].is_valid_int():
			count = parse_number()

		if peek().to_lower() != "d":
			# not dice; rewind if we consumed a number incorrectly
			pos = save
			push_error("Expected 'd' for dice at %d in '%s'" % [pos, expr])
			return {"total": 0, "text": "?"}
		consume() # 'd'
		if pos >= s.length() or not s[pos].is_valid_int():
			push_error("Expected sides after 'd' at %d in '%s'" % [pos, expr])
			return {"total": 0, "text": "d?"}
		var sides: int = parse_number()
		if sides <= 0:
			push_error("Dice sides must be > 0")
			sides = 1

		# explode?
		var explode: bool = false
		var cmp: Dictionary = {}
		if peek() == "!":
			explode = true
			consume()
			cmp = parse_cmp()

		# keep/drop?
		var kd: String = "" # "kh"|"kl"|"dh"|"dl"
		var kd_n: int = 0
		if pos + 1 <= s.length() - 1:
			var two = s.substr(pos, 2).to_lower()
			if two in ["kh","kl","dh","dl"]:
				kd = two
				pos += 2
				kd_n = parse_number()

		# Roll dice
		var rolls: Array = tower.roll_dice(count, sides)
		var _all_rolls: Array = rolls.duplicate()

		# exploding logic
		if explode:
			var i: int = 0
			while i < rolls.size():
				var v: int = rolls[i]
				if cmp_pass(v, cmp, sides):
					var extra = tower._rng.randi_range(1, sides)
					rolls.append(extra)
				# keep checking the newly added result
				i += 1

		var kept: Array = rolls.duplicate()
		# apply keep/drop
		if kd != "":
			kept.sort() # ascending
			match kd:
				"kh":
					# keep highest N
					kept = kept.slice(max(0, kept.size() - kd_n), kept.size())
				"kl":
					# keep lowest N
					kept = kept.slice(0, min(kd_n, kept.size()))
				"dh":
					# drop highest N
					kept = kept.slice(0, max(0, kept.size() - kd_n))
				"dl":
					# drop lowest N
					kept = kept.slice(min(kd_n, kept.size()), kept.size())

		var subtotal: int = 0
		for v in kept:
			subtotal += int(v)

		# build text breakdown
		var txt: String = "%dd%d" % [count, sides]
		if explode:
			txt += "!"
			if not cmp.is_empty():
				txt += "%s%d" % [cmp["operation"], int(cmp["threshold"])]
		if kd != "":
			txt += "%s%d" % [kd, kd_n]
		txt += " → [" + ", ".join(rolls) + "]"
		if kd != "":
			txt += " keep [" + ", ".join(kept) + "]"
		txt += " = " + str(subtotal)

		return {"total": subtotal, "text": txt}

		# ────────────────────────────────────────────────────────────────────────────
