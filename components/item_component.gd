# res://ecs/components/ItemComponent.gd

## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Pure data container describing a single item entity.
## - No logic, no signals.
## - Uses flag bitmasks (“FlagSet”) for category/subtype classification.
## - Supports nested inventory linkage (for bags/containers).
## - Compatible with EquipmentItemModifiers for stat effects.
## Systems are responsible for:
## - Interpreting flags (equip/use rules, filters).
## - Enforcing stack rules, max_count, and slot capacity.
## - Managing nested inventories (create/attach the child entity).
## - Save/load and data migration.
@abstract class_name ItemComponent
extends EntityComponent


## —————————————————————————————————————————————
#region Fields
## —————————————————————————————————————————————

## Display/localization key for the item.
var item_name: String = ""

## Optional description text for tooltips/codex/debug.
var description: String = ""

## Resource path to the item’s icon (e.g., "res://ui/icons/items/sword.png").
var icon_path: String = ""

## FlagSet (int bitmask) of high-level categories from ItemFlags.Category (e.g., WEAPON|MAGIC).
## Stored as an int for serialization; refer to ItemFlags for constants.
var item_type: FlagSet = FlagSet.new()

## FlagSet (int bitmask) of weapon subtypes from ItemFlags.WeaponType (e.g., SWORD|ONE_HANDED).
## Leave 0 for non-weapons.
var weapon_type_flags: FlagSet = FlagSet.new()

## Can this item stack in a single inventory slot?
var stackable: bool = false

## Per-slot maximum items if stackable (default 1).
var max_stack: int = 1

## Maximum total number of this item type the entity can hold across all slots.
## Use -1 to indicate "unlimited".
var max_count: int = -1

## the item's price.
var price: float

## Current count for this instance/stack (systems maintain/clamp).
var quantity: int = 1

## Optional reference to stat modifiers applied when equipped/used (interpreted by systems).
var modifiers: EquipmentItemModifiers = null

## the array of [EquipmentSlot]s the item can be equipped in (left or right hand, one or more fingers, or head, etc...)
var equip_slots: Array[int]

## If this item acts as a container (bag/chest), this links to the child entity’s id
## that owns its InventoryComponent. Leave empty if not applicable.
var nested_inventory_id: String = ""

## flag indicating whether an item needs to be carried in two hands.
var two_handed: bool

## the item's weight.
var weight: float = 0.0

## ItemRarity.Enum.
var rarity: int = ItemRarity.Enum.COMMON

## Optional (if using durability)
var durability_max: int = 0     # 0 = ignore durability system
var durability: int = 0
# Suggested keys: min_level:int, attributes:Dictionary (e.g., { power: 10, aim: 6 }), tags_required:Array[StringName], tags_forbidden:Array[StringName], gender: Gender.Enum|-1
var requirements := {           # flexible schema; see validator below
	"min_level": 0,
	"attributes": {},           # e.g. {"power": 8, "aim": 4}
	"tags_required": [],        # e.g. ["order:warrior_monk"]
	"tags_forbidden": [],
	"gender": -1,               # use Gender.Enum or -1 = any
}
# (empty if not part of a set)
var set_id: StringName = &""
# (thresholded modifiers) e.g., [ {pieces:2, mods:{ ... }}, {pieces:4, mods:{ ... }} ]
var set_bonuses: Array = []     # [{pieces:int, mods:Dictionary|EquipmentItemModifiers}, ...]

## Schema version for migration.
var version: int = 1

# (soulbound)
var bound_to_entity: StringName = &""
# (cannot unequip unless cleansed)
var cursed: bool = false
# (enforce only one copy equipped/owned)
var unique_instance: bool = false

#endregion

## —————————————————————————————————————————————
## Notes
## —————————————————————————————————————————————
## - FlagSet is represented as an int bitmask. Use ItemFlags constants to set/test bits.
## - For containers: systems should ensure item_type includes ItemFlags.Category.CONTAINER
##   when nested_inventory_id is non-empty.
## - Quantity and stacking are system-policed (no checks here by design).
