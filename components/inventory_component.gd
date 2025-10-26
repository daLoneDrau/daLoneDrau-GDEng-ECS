# res://ecs/components/InventoryComponent.gd

## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Pure data container for an entity’s inventory state.
## - Fixed capacity (set at runtime by a system/factory).
## - No logic, no signals.
## - No currency/weight/categories.
## - Supports nested inventories (bag-in-bag) via slot → child-entity mapping.
## Systems are responsible for:
## - Initializing capacity and sizing slots.
## - Adding/removing/moving/stacking items.
## - Validating slot indices and stack rules.
## - Creating/attaching child entities that hold nested inventories.
## - Saving/loading and migration between versions.
class_name InventoryComponent
extends EntityComponent


## —————————————————————————————————————————————
#region Fields
## —————————————————————————————————————————————

## Fixed slot capacity. Must be set by a system at runtime.
## Systems should also size `slots` to match this capacity.
var capacity: int = 0

## [Array] of [InventorySlot] or null placeholders, length == capacity.
## Systems should treat out-of-range or mismatched sizes as invalid state and correct them.
var slots: Array = []  # Array[InventorySlot | null], pre-sized to `capacity` with nulls if empty.

## Optional human-readable label for UI/debug (not required by logic).
var label: String = ""

## Support for nested inventories:
## Maps a slot index (int) → child entity_id (String) that owns another InventoryComponent.
## Example: if slots[5] holds a “Leather Bag” item whose entity has its own InventoryComponent,
## then nested_by_slot[5] = "<child_entity_id_for_that_bag>"
var nested_by_slot: Dictionary = {}  # { int: String }

## Optional version for data migration if you evolve the schema.
var version: int = 1

#endregion

## —————————————————————————————————————————————
## Notes
## —————————————————————————————————————————————
## 1) Systems should:
##    - Set `capacity` and then ensure `slots.size() == capacity` (fill with nulls).
##    - Maintain invariants when moving/stacking items.
##    - Create/attach/detach child entities for nested inventories and update `nested_by_slot`.
##
## 2) This component intentionally does NOT contain:
##    - Methods (add/remove/move/etc.)
##    - Gold/weight/category tracking
##    - Signals
##
## 3) Ownership:
##    - This component is attached to exactly one entity (enforced by ECS composition).
