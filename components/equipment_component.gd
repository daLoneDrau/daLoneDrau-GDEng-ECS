# res://ecs/components/EquipmentComponent.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Defines the current loadout of equipped items for an entity.
## Pure data container; no logic or modifier application.
## Systems (EquipmentSystem, PlayerSystem) interpret this data.
@abstract class_name EquipmentComponent
extends EntityComponent


## —————————————————————————————————————————————
#region Equipment Slots
## —————————————————————————————————————————————
# Dictionary mapping slot name → item entity_id
# Example: { EquipmentSlot.Enum.HEAD: &"item_helmet_01", EquipmentSlot.Enum.MAIN_HAND: &"item_sword_iron", EquipmentSlot.Enum.OFF_HAND: &"" }
@export var slots: Dictionary[int, String] = {}

# List of allowed slot names for this entity type
# Example: ["HEAD", "CHEST", "MAIN_HAND", "OFF_HAND", "LEGS", "RING_L", "RING_R", "AMULET"]
@export var allowed_slots: Array[StringName] = []

#endregion


## —————————————————————————————————————————————
#region Active / State Flags
## —————————————————————————————————————————————
@export var active_weapon_slot: StringName = &"MAIN_HAND"
@export var active_spell_focus: StringName = &""
@export var auto_equip: bool = false
@export var two_handed_locked: bool = false
@export var is_dirty: bool = false  # Systems mark this when modifiers need recalculation

#endregion


## —————————————————————————————————————————————
#region Meta
## —————————————————————————————————————————————
@export var last_updated_timestamp: float = 0.0

#endregion
