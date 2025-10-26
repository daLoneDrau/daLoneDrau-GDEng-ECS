## Defines a single slot in the inventory grid.
class_name InventorySlot
extends CustomResource


## The reference id of the entity in the [InventorySlot]. An empty string means the slot is empty.
@export var entity_id: String

## Whether the entity in this slot should be visible in the UI.
@export var visible: bool = true

## Optional metadata — e.g., quantity or slot index.
@export var quantity: int = 1
@export var index: int = -1


## —————————————————————————————————————————————
#region Helpers
## —————————————————————————————————————————————

## Returns true if the slot is empty.
func is_empty() -> bool:
	return entity_id == "" or entity_id == null


## Clears the slot.
func clear() -> void:
	entity_id = ""
	quantity = 0
	visible = false


## Sets the slot to reference a given entity.
func set_entity(id: String, qty: int = 1, show: bool = true) -> void:
	entity_id = id
	quantity = qty
	visible = show

#endregion
