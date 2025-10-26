# res://ecs/types/EquipmentSlot.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Defines standardized slot types for equipment layout.
## Used by EquipmentComponent and related systems to constrain item placement.
## Each slot can only hold one equipped item.
class_name EquipmentSlot


## —————————————————————————————————————————————
#region Slot Definitions
## —————————————————————————————————————————————

enum Enum {
	HEAD,
	CHEST,
	LEGS,
	FEET,
	MAIN_HAND,
	OFF_HAND,
	RING_L,
	RING_R,
	AMULET,
	BELT,
}
#endregion

## —————————————————————————————————————————————
#region Utility Methods
## —————————————————————————————————————————————


static func enum_values() -> Array[Enum]:
	return [
		Enum.HEAD,
		Enum.CHEST,
		Enum.LEGS,
		Enum.FEET,
		Enum.MAIN_HAND,
		Enum.OFF_HAND,
		Enum.RING_L,
		Enum.RING_R,
		Enum.AMULET,
		Enum.BELT,
	]

	
static func to_key(value: int) -> String:
	match value:
		Enum.HEAD:       return "HEAD"
		Enum.CHEST:      return "CHEST"
		Enum.LEGS:       return "LEGS"
		Enum.FEET:       return "FEET"
		Enum.MAIN_HAND:  return "MAIN_HAND"
		Enum.OFF_HAND:   return "OFF_HAND"
		Enum.RING_L:     return "RING_L"
		Enum.RING_R:     return "RING_R"
		Enum.AMULET:     return "AMULET"
		Enum.BELT:       return "BELT"
		_:               return "UNKNOWN"

		
static func display_name(value: int) -> String:
	match value:
		Enum.HEAD:       return "Head"
		Enum.CHEST:      return "Chest"
		Enum.LEGS:       return "Legs"
		Enum.FEET:       return "Feet"
		Enum.MAIN_HAND:  return "Main Hand"
		Enum.OFF_HAND:   return "Off Hand"
		Enum.RING_L:     return "Left Ring"
		Enum.RING_R:     return "Right Ring"
		Enum.AMULET:     return "Amulet"
		Enum.BELT:       return "Belt"
		_:               return "Unknown Slot"


static func from_string(slot_name: String) -> int:
	var name := slot_name.strip_edges().to_lower()
	match name:
		"head":                     return Enum.HEAD
		"chest":                    return Enum.CHEST
		"legs":                     return Enum.LEGS
		"feet":                     return Enum.FEET
		"main hand", "main_hand":   return Enum.MAIN_HAND
		"off hand", "off_hand":     return Enum.OFF_HAND
		"left ring", "left_ring":   return Enum.RING_L
		"right ring", "right_ring": return Enum.RING_R
		"amulet":                   return Enum.AMULET
		"belt":                     return Enum.BELT
		_:                          return -1
		
#endregion

static var _name_to_value: Dictionary
static var _value_to_name: Dictionary

static func _build_maps() -> void:
	if _name_to_value != null: # already built
		return
	_name_to_value = {}
	_value_to_name = {}

	# Reflect over the enum to build lookup tables
	# Assumes your enum is `enum Enum { ... }`
	for k in Enum:
		var v: int = Enum[k]
		_name_to_value[to_key(k)] = v
		_value_to_name[v] = to_key(k)


static func value_or_minus_one(name: String) -> int:
	_build_maps()
	name = name.strip_edges()
	if _name_to_value.has(name):
		return int(_name_to_value[name])
	# Accept lowercase / kebab / mixed by normalizing
	var normalized := name.to_upper().replace("-", "_").replace(" ", "_")
	return int(_name_to_value.get(normalized, -1))


static func name_or_unknown(value: int) -> String:
	_build_maps()
	return String(_value_to_name.get(value, "UNKNOWN"))


static func all_slot_names() -> Array[String]:
	_build_maps()
	return _name_to_value.keys()


static func is_hand_slot(value: int) -> bool:
	# Adjust if your hand slots are named differently
	_build_maps()
	var name := name_or_unknown(value)
	return name == "MAIN_HAND" or name == "OFF_HAND"
