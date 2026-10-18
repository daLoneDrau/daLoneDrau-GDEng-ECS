# res://ecs/types/PartyTags.gd
class_name EntityTags


enum Tag {
	PC 		= 1 << 0,
	ITEM	= 1 << 1,
	NPC     = 1 << 2,
	UNIQUE	= 1 << 3,
}

static func enum_values() -> Array[Tag]:
	return [Tag.PC, Tag.ITEM, Tag.NPC]
	

static func to_key(value: int) -> String:
	for t in enum_values():
		if t == value: return str(t)
	return "UNKNOWN"


static func display_name(value: int) -> String:
	match value:
		Tag.PC:		return "Player Character"
		Tag.ITEM:	return "Item"
		Tag.NPC:    return "Non-Player Character"
		_:          return "Unknown"
