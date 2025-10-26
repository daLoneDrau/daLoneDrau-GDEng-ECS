# res://ecs/types/PlayerTags.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Centralized flag definitions for player traits, status,
## and gameplay meta-tags. Used as a bitmask FlagSet in PlayerComponent.
class_name PlayerTags

enum Tag {
# Identity and role
	PC            = 1 << 0,   # Player-controlled entity
	MAIN_PROTAG   = 1 << 1,   # Main story protagonist
	NPC           = 1 << 2,   # Non-player recruitable character
	RECRUITABLE   = 1 << 3,   # Appears in roster but not yet recruited
	
	# Archetype flags
	MAGIC_USER    = 1 << 4,
	DIVINE_USER   = 1 << 5,
	MARTIAL       = 1 << 6,
	ROGUEISH      = 1 << 7,
	
	# Game mode / state
	HARDCORE      = 1 << 8,   # Perma-death
	IRONMAN       = 1 << 9,   # Single-save restriction
	STORY_LOCKED  = 1 << 10,  # Cannot be dismissed
	STARTER       = 1 << 11,  # Starting roster member
	IMPORTED      = 1 << 12,  # From another save
}

static func enum_values() -> Array[Tag]:
	return [
		Tag.PC,
		Tag.MAIN_PROTAG,
		Tag.NPC,
		Tag.RECRUITABLE,
		Tag.MAGIC_USER,
		Tag.DIVINE_USER,
		Tag.MARTIAL,
		Tag.ROGUEISH,
		Tag.HARDCORE,
		Tag.IRONMAN,
		Tag.STORY_LOCKED,
		Tag.STARTER,
		Tag.IMPORTED,
	]

static func to_key(value: int) -> String:
	for tag in enum_values():
		if value == tag:
			return str(tag)
	return "UNKNOWN"


static func display_name(value: int) -> String:
	match value:
		Tag.PC:           return "Player Character"
		Tag.MAIN_PROTAG:  return "Main Protagonist"
		Tag.NPC:          return "Non-Player Character"
		Tag.RECRUITABLE:  return "Recruitable"
		Tag.MAGIC_USER:   return "Magic User"
		Tag.DIVINE_USER:  return "Divine Caster"
		Tag.MARTIAL:      return "Martial Fighter"
		Tag.ROGUEISH:     return "Rogue"
		Tag.HARDCORE:     return "Hardcore Mode"
		Tag.IRONMAN:      return "Ironman Mode"
		Tag.STORY_LOCKED: return "Story-Locked"
		Tag.STARTER:      return "Starting Member"
		Tag.IMPORTED:     return "Imported Character"
		_:                return "Unknown Tag"
