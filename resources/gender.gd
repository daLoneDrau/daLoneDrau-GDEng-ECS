class_name Gender


enum Enum {
	MALE,
	FEMALE,
	NEUTRAL,    # creatures/objects → it/its
	NONBINARY,  # people → they/them/their
}

const PRONOUNS := {
	Enum.MALE:      { "subject": "he",   "objective": "him",  "possessive": "his",   "possessive_objective": "his",    "reflexive": "himself"   },
	Enum.FEMALE:    { "subject": "she",  "objective": "her",  "possessive": "her",   "possessive_objective": "hers",   "reflexive": "herself"   },
	Enum.NEUTRAL:   { "subject": "it",   "objective": "it",   "possessive": "its",   "possessive_objective": "theirs", "reflexive": "itself"    },
	Enum.NONBINARY: { "subject": "they", "objective": "them", "possessive": "their", "possessive_objective": "theirs", "reflexive": "themselves"  },
}

const RELATIONS := {
	Enum.MALE:      { "parent": "father", "child": "son",       "sibling": "brother" },
	Enum.FEMALE:    { "parent": "mother", "child": "daughter",  "sibling": "sister"  },
	Enum.NEUTRAL:   { "parent": "parent", "child": "offspring", "sibling": "sibling" },
	Enum.NONBINARY: { "parent": "parent", "child": "offspring", "sibling": "sibling" },
}


static func child_relation(gender: Enum) -> String:
	return RELATIONS[gender]["child"]


static func objective(gender: Enum) -> String:
	return PRONOUNS[gender]["objective"]


static func parent_relation(gender: Enum) -> String:
	return RELATIONS[gender]["parent"]


static func possessive(gender: Enum) -> String:
	return PRONOUNS[gender]["possessive"]


static func possessive_objective(gender: Enum) -> String:
	return PRONOUNS[gender]["possessive_objective"]


static func pronoun(gender: Enum) -> String:
	return PRONOUNS[gender]["subject"]


static func reflexive(gender: Enum) -> String:
	return PRONOUNS[gender]["reflexive"]


static func sibling_relation(gender: Enum) -> String:
	return RELATIONS[gender]["sibling"]


static func verb_be(gender: Enum) -> String:
	return "are" if gender == Enum.NONBINARY else "is"


static func verb_have(gender: Enum) -> String:
	return "have" if gender == Enum.NONBINARY else "has"


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
		"[gender-sibling-relation]": sibling_relation(gender),
	}
	for k in map.keys():
		text = text.replacen(k, map[k])
	return text


static func title(gender: Enum) -> String:
	var ret_val: String
	match gender:
		Enum.MALE:      ret_val = "Male"
		Enum.FEMALE:    ret_val = "Female"
		Enum.NEUTRAL:   ret_val = "It"
		Enum.NONBINARY: ret_val = "Non-Binary"
		_:              ret_val =  "Unknown"
	return ret_val


static func to_key(gender: Enum) -> String:
	match gender:
		Enum.MALE:      return "MALE"
		Enum.FEMALE:    return "FEMALE"
		Enum.NEUTRAL:   return "NEUTRAL"
		Enum.NONBINARY: return "NONBINARY"
		_:              return "UNKNOWN"
