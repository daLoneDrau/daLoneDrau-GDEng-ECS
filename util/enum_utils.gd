# res://ecs/util/EnumUtils.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Generic helper functions for ECS enum classes.
## Works with any type implementing:
##   - enum_values()
##   - to_key(value)
##   - display_name(value)
##
## Example usage:
##   EnumUtils.get_display_names(Race)
##   EnumUtils.to_string_safe(Gender, Gender.Enum.FEMALE)
##   EnumUtils.from_string_safe(Profession, "WARRIOR")
class_name EnumUtils


## —————————————————————————————————————————————
#region Public API
## —————————————————————————————————————————————

# Returns an array of all enum values.
static func get_values(enum_class: Object) -> Array[int]:
	if enum_class.has_method("enum_values"):
		return enum_class.enum_values()
	return []


# Returns an array of display names (UI labels) for dropdowns or lists.
static func get_display_names(enum_class: Object) -> Array[String]:
	if not enum_class.has_method("enum_values") or not enum_class.has_method("display_name"):
		return []
	var result: Array[String] = []
	for value in enum_class.enum_values():
		result.append(enum_class.display_name(value))
	return result


# Returns a dictionary mapping enum int → display name.
static func get_display_map(enum_class: Object) -> Dictionary:
	if not enum_class.has_method("enum_values") or not enum_class.has_method("display_name"):
		return {}
	var map := {}
	for value in enum_class.enum_values():
		map[value] = enum_class.display_name(value)
	return map


# Returns a dictionary mapping enum int → to_key key.
static func get_string_map(enum_class: Object) -> Dictionary:
	if not enum_class.has_method("enum_values") or not enum_class.has_method("to_key"):
		return {}
	var map := {}
	for value in enum_class.enum_values():
		map[value] = enum_class.to_key(value)
	return map


# Safe conversion from int → display_name (fallback: "Unknown")
static func display_name_safe(enum_class: Object, value: int) -> String:
	if enum_class.has_method("display_name"):
		return enum_class.display_name(value)
	return "Unknown"


# Safe conversion from int → string key (fallback: "UNKNOWN")
static func to_string_safe(enum_class: Object, value: int) -> String:
	if enum_class.has_method("to_key"):
		return enum_class.to_key(value)
	return "UNKNOWN"


# Reverse lookup: returns enum int by its string key.
# Returns -1 if not found.
static func from_string_safe(enum_class: Object, key: String) -> int:
	if not enum_class.has_method("enum_values") or not enum_class.has_method("to_key"):
		return -1
	for value in enum_class.enum_values():
		if enum_class.to_key(value) == key:
			return value
	return -1
	
#endregion
