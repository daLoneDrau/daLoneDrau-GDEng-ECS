class_name Gender


enum Enum {
	MALE,
	FEMALE,
	NEUTRAL,    # creatures/objects → it/its
	NONBINARY,  # people → they/them/their
}

static func enum_values() -> Array[Enum]:
	return [
		Enum.MALE,
		Enum.FEMALE,
		Enum.NEUTRAL,
		Enum.NONBINARY
	]


static func child_relation(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:
			ret_val = "son"
		Enum.FEMALE:
			ret_val = "daughter"
		Enum.NEUTRAL, Enum.NONBINARY:
			ret_val = "offspring"
	return ret_val


static func objective(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "him"
		Enum.FEMALE:    ret_val = "her"
		Enum.NEUTRAL:   ret_val = "it"
		Enum.NONBINARY: ret_val = "them"
	return ret_val


static func parent_relation(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:
			ret_val = "father"
		Enum.FEMALE:
			ret_val = "mother"
		Enum.NEUTRAL, Enum.NONBINARY:
			ret_val = "parent"
	return ret_val


static func possessive(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "his"
		Enum.FEMALE:    ret_val = "her"
		Enum.NEUTRAL:   ret_val = "its"
		Enum.NONBINARY: ret_val = "their"
	return ret_val


static func possessive_objective(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "his"
		Enum.FEMALE:    ret_val = "hers"
		Enum.NEUTRAL:   ret_val = "theirs"
		Enum.NONBINARY: ret_val = "theirs"
	return ret_val


static func pronoun(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "he"
		Enum.FEMALE:    ret_val = "she"
		Enum.NEUTRAL:   ret_val = "it"
		Enum.NONBINARY: ret_val = "they"
	return ret_val


static func reflexive(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "himself"
		Enum.FEMALE:    ret_val = "herself"
		Enum.NEUTRAL:   ret_val = "itself"
		Enum.NONBINARY: ret_val = "themself" # or "themselves", your style
	return ret_val


static func replace_tokens(gender: Enum, text: String) -> String:
	var map: Dictionary = {
		"[gender-child-relation]": child_relation(gender),
		"[gender-child-relation-capitalize]": child_relation(gender).capitalize(),
		"[gender-parent-relation]": parent_relation(gender),
		"[gender-title]": title(gender),
		"[gender-objective]": objective(gender),
		"[gender-possessive]": possessive(gender),
		"[gender-possessive-capitalize]": possessive(gender).capitalize(),
		"[gender-possessive-objective]": possessive_objective(gender),
		"[gender-pronoun]": pronoun(gender),
		"[gender-pronoun-capitalize]": pronoun(gender).capitalize(),
		"[gender-reflexive]": reflexive(gender),
	}
	for k in map.keys():
		text = text.replacen(k, map[k])
	return text


static func sibling_relation(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:
			ret_val = "brother"
		Enum.FEMALE:
			ret_val = "sister"
		Enum.NEUTRAL, Enum.NONBINARY:
			ret_val = "sibling"
	return ret_val


static func title(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "Male"
		Enum.FEMALE:    ret_val = "Female"
		Enum.NEUTRAL:   ret_val = "It"
		Enum.NONBINARY: ret_val = "Non-Binary"
	return ret_val


static func to_key(value: int) -> String:
	match value:
		Enum.MALE:      return "MALE"
		Enum.FEMALE:    return "FEMALE"
		Enum.NEUTRAL:   return "NEUTRAL"
		Enum.NONBINARY: return "NONBINARY"
		_:              return "UNKNOWN"

static func display_name(value: int) -> String:
	match value:
		Enum.MALE:      return "Male"
		Enum.FEMALE:    return "Female"
		Enum.NEUTRAL:   return "It"
		Enum.NONBINARY: return "Nonbinary"
		_:              return "Unknown"
