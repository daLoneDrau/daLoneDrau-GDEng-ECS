# res://ecs/types/ItemFlags.gd

## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Centralized flag definitions for items.
## These enums provide bit positions used as int bitmask “FlagSet”s across the ECS.
## Keep logic minimal here; systems should interpret and apply behavior.
class_name ItemFlags


## —————————————————————————————————————————————
#region Category (high-level item types)
## —————————————————————————————————————————————
enum Category {
	WEAPON       = 1 << 0,
	ARMOR        = 1 << 1,
	CONSUMABLE   = 1 << 2,
	QUEST_ITEM   = 1 << 3,
	CONTAINER    = 1 << 4,
	MAGIC        = 1 << 5,
	MATERIAL     = 1 << 6,
	KEY          = 1 << 7,
	RANGED_AMMO  = 1 << 8,
	ACCESSORY    = 1 << 9,
	TOOL         = 1 << 10,
	SCRIPTED     = 1 << 11,
}
#endregion

## —————————————————————————————————————————————
#region WeaponType (subtypes; only applies if Category.WEAPON is set)
## —————————————————————————————————————————————
enum WeaponType {
	SWORD        = 1 << 0,
	AXE          = 1 << 1,
	MACE         = 1 << 2,
	DAGGER       = 1 << 3,
	SPEAR        = 1 << 4,
	BOW          = 1 << 5,
	CROSSBOW     = 1 << 6,
	STAFF        = 1 << 7,
	WAND         = 1 << 8,
	HAMMER       = 1 << 9,
	POLEARM      = 1 << 10,
	SLING        = 1 << 11,
	UNARMED      = 1 << 12,
	THROWN       = 1 << 13,
}
#endregion
