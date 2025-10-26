# res://ecs/types/PartyTags.gd
class_name PartyTags


enum Tag {
	STORY_LOCKED = 1 << 0,
	IRONMAN      = 1 << 1,
	HARDCORE     = 1 << 2,
}

static func enum_values() -> Array[Tag]:
	return [Tag.STORY_LOCKED, Tag.IRONMAN, Tag.HARDCORE]
	

static func to_key(value: int) -> String:
	for t in enum_values():
		if t == value: return str(t)
	return "UNKNOWN"


static func display_name(value: int) -> String:
	match value:
		Tag.STORY_LOCKED: return "Story-Locked"
		Tag.IRONMAN:      return "Ironman"
		Tag.HARDCORE:     return "Hardcore"
		_:                return "Unknown"
