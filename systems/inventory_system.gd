# res://ecs/systems/InventorySystem.gd

## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Central ECS system responsible for all **inventory logic** and item transactions.
## 
## Core responsibilities:
## - Manage adding, removing, moving, splitting, and merging item stacks.
## - Enforce slot capacity, filters, and stacking rules defined in `InventoryComponent`.
## - Handle transfers between entities (player ↔ container, party, or other entity).
## - Validate actions based on `ItemComponent` flags (e.g., NO_DROP, UNIQUE).
## - Emit granular signals for UI and other systems (`inventory_changed`, `item_added`, etc.).
## - Provide atomic transaction helpers and dry-run previews for systems or UI.
##
## Non-responsibilities:
## - Does *not* render UI or handle drag-drop input (UI panels subscribe to signals).
## - Does *not* handle equipment stat recalculations (delegated to EquipmentSystem).
## - Does *not* price or appraise items (delegated to Economy systems).
## - Does *not* simulate world placement of dropped items (delegated to Map or World systems).
##
## The `InventorySystem` serves as the **authoritative layer** ensuring inventories
## remain valid, synchronized, and rule-compliant across the entire ECS runtime.
@abstract class_name InventorySystem
extends GameSystem


## —————————————————————————————————————————————
#region Signals
## —————————————————————————————————————————————

signal inventory_changed(entity_id: StringName)
signal item_added(entity_id: StringName, slot: int, item_id: StringName, count: int)
signal item_removed(entity_id: StringName, slot: int, item_id: StringName, count: int)
signal item_moved(from_entity: StringName, from_slot: int, to_entity: StringName, to_slot: int, count: int)
signal stack_split(entity_id: StringName, from_slot: int, to_slot: int, count: int)
signal stack_merged(entity_id: StringName, source_slot: int, target_slot: int, total_count: int)
signal transfer_failed(context: Dictionary)

#endregion


## —————————————————————————————————————————————
#region Policy & Filter Maps
## —————————————————————————————————————————————

## a [Callable] defined at runtime that contains the logic for determing if two items are stackable.
## [Callable] signature is (item_1_id: StringName, item_2_id: StringName) -> bool
var stacking_policy: Callable         # (item_a: Dictionary, item_b: Dictionary) -> bool
var capacity_policy_map := {}         # entity_id -> Callable(weight, count, inv) -> bool
var slot_filter_map := {}             # entity_id -> {slot_idx: Callable(item) -> bool}

#endregion


## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func _enter_tree() -> void:
	# Connect to entity lifecycle events if needed
	pass

#endregion

## —————————————————————————————————————————————
#region Queries
## —————————————————————————————————————————————


## Finds all slot indices containing the given item_id.
## Returns an array of ints (empty if not found).
func find_item_slots(entity_id: StringName, item_id: StringName) -> Array[int]:
	var indices: Array[int] = []
	if item_id != "":
		var inventory := _get_inventory_component(entity_id)
		if inventory != null:
			for i in range(inventory.slots.size()):
				var slot: InventorySlot = inventory.slots[i]
				if slot.entity_id == item_id:
					indices.append(i)
	return indices


## Returns the number of slots currently occupied by any item.
func get_filled_slot_count(entity_id: StringName) -> int:
	var count := 0
	var inventory := _get_inventory_component(entity_id)
	if inventory != null:
		for slot: InventorySlot in inventory.slots:
			if slot.entity_id != "":
				count += 1
	return count


## Returns the total quantity (sum of stack counts) of a specific item_id.
func get_item_count(entity_id: StringName, item_id: StringName) -> int:
	var total: int = 0
	if item_id != "":
		var inventory := _get_inventory_component(entity_id)
		if inventory != null:
			for slot: InventorySlot in inventory.slots:
				if slot.entity_id == item_id:
					total += slot.quantity
	return total


## Returns the total number of items across all stacks (sum of counts).
func get_total_items(entity_id: StringName) -> int:
	var total := 0
	var inventory := _get_inventory_component(entity_id)
	if inventory != null:
		for slot: InventorySlot in inventory.slots:
			if slot.entity_id != "":
				total += slot.quantity
	return total


## Checks if the inventory has enough free space for an item.
@abstract func has_space(entity_id: StringName, item_id: StringName, count := 1, at_slot := -1) -> bool


## Checks if an inventory is completely empty (no items in any slot).
func is_inventory_empty(entity_id: StringName) -> bool:
	var ret_val: bool = true
	var inventory: InventoryComponent = _get_inventory_component(entity_id)
	if inventory != null:
		for slot: InventorySlot in inventory.slots:
			if slot.entity_id != "":
				ret_val = false
				break
	return ret_val


## Checks whether a specific item ID exists anywhere in the inventory.
func has_item(entity_id: StringName, item_id: StringName) -> bool:
	var ret_val: bool = false
	if item_id != "":
		var inventory: InventoryComponent = _get_inventory_component(entity_id)
		if inventory != null:
			for slot: InventorySlot in inventory.slots:
				if slot.entity_id == item_id:
					ret_val = true
					break
	return ret_val


## Iterates over all non-empty item IDs in the inventory.
## Returns an Array of StringNames representing each slot’s item_id (duplicates preserved).
## Example:
## ```
## for id in inventory_system.iter_item_ids(player_id):
##     print(id)
## ```
func iter_item_ids(entity_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var inventory := _get_inventory_component(entity_id)
	if inventory != null:
		for slot: InventorySlot in inventory.slots:
			if slot.entity_id != "":
				result.append(slot.entity_id)
	return result


## Iterates over all *unique* non-empty item IDs in the inventory.
## Preserves the order of first appearance.
## Example:
## ```
## var unique_ids = inventory_system.iter_unique_item_ids(player_id)
## for id in unique_ids:
##     print("Found:", id)
## ```
func iter_unique_item_ids(entity_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var inventory := _get_inventory_component(entity_id)
	if inventory != null:
		var seen := {}
		for slot: InventorySlot in inventory.slots:
			var id := slot.entity_id
			if id != "" and not seen.has(id):
				seen[id] = true
				result.append(id)
	return result
	
#endregion


## —————————————————————————————————————————————
#region Mutations
## —————————————————————————————————————————————

func add_item(entity_id: StringName, item_id: StringName, count: int = 1, prefer_slot: int = -1) -> Dictionary:
	if item_id == "" or count <= 0:
		return { "ok": false, "reason": &"invalid_args" }

	var inv := _get_inventory_component(entity_id)
	if inv == null:
		return { "ok": false, "reason": &"no_inventory" }

	# Capacity policy pre-check (coarse). Concrete impls may refine per-slot.
	if not _apply_capacity_policy(entity_id, item_id, count):
		return { "ok": false, "reason": &"capacity_denied" }

	var max_stack: int = max(1, _get_item_max_stack(item_id))
	var remaining := count
	var placements: Array = []  # [{slot, added}]

	# 1) Try preferred slot first (merge or place) if specified
	if prefer_slot >= 0 and prefer_slot < inv.slots.size():
		var s: InventorySlot = inv.slots[prefer_slot]
		if s.entity_id == "":
			var add_here: int = min(remaining, max_stack)
			s.item_id = item_id
			s.count = add_here
			placements.append({ "slot": prefer_slot, "added": add_here })
			item_added.emit(entity_id, prefer_slot, item_id, add_here)
			remaining -= add_here
		elif _stacking_compatible(s.item_id, item_id) and s.count < max_stack:
			var room := max_stack - s.quantity
			var add_here: int = min(room, remaining)
			if add_here > 0:
				s.count += add_here
				placements.append({ "slot": prefer_slot, "added": add_here })
				item_added.emit(entity_id, prefer_slot, item_id, add_here)
				remaining -= add_here

	# 2) Merge into existing stacks (excluding prefer_slot if already handled)
	if remaining > 0:
		for i in range(inv.slots.size()):
			if i == prefer_slot:
				continue
			var slot: InventorySlot = inv.slots[i]
			if slot.entity_id != "" and _stacking_compatible(slot.entity_id, item_id) and slot.quantity < max_stack:
				var room := max_stack - slot.quantity
				if room <= 0:
					continue
				var add_here: int = min(room, remaining)
				slot.quantity += add_here
				placements.append({ "slot": i, "added": add_here })
				item_added.emit(entity_id, i, item_id, add_here)
				remaining -= add_here
				if remaining == 0:
					break

	# 3) Place into empty slots as new stacks
	if remaining > 0:
		for i in range(inv.slots.size()):
			if i == prefer_slot:
				continue
			var slot: InventorySlot = inv.slots[i]
			if slot.entity_id == "":
				var add_here: int = min(remaining, max_stack)
				slot.entity_id = item_id
				slot.quantity = add_here
				placements.append({ "slot": i, "added": add_here })
				item_added.emit(entity_id, i, item_id, add_here)
				remaining -= add_here
				if remaining == 0:
					break

	# Outcome
	if placements.size() > 0:
		inventory_changed.emit(entity_id)
		if remaining == 0:
			return { "ok": true, "reason": &"added_full", "added": count, "placements": placements }
		else:
			return { "ok": true, "reason": &"added_partial", "added": count - remaining, "remaining": remaining, "placements": placements }
	else:
		return { "ok": false, "reason": &"no_space" }


func remove_item(entity_id: StringName, item_id: StringName, count := 1, prefer_slot := -1) -> Dictionary:
	if item_id == "" or count <= 0:
		return { "ok": false, "reason": &"invalid_args" }

	var inv := _get_inventory_component(entity_id)
	if inv == null:
		return { "ok": false, "reason": &"no_inventory" }

	var remaining := count
	var removals: Array = []  # [{slot, removed}]

	# 1) Prefer specific slot if provided and matches
	if prefer_slot >= 0 and prefer_slot < inv.slots.size():
		var s: InventorySlot = inv.slots[prefer_slot]
		if s.entity_id == item_id and s.count > 0:
			var take: int = min(s.quantity, remaining)
			var pre_id := s.entity_id
			var pre_ct := take
			s.count -= take
			if s.count == 0:
				s.item_id = ""
			removals.append({ "slot": prefer_slot, "removed": take })
			item_removed.emit(entity_id, prefer_slot, pre_id, pre_ct)
			remaining -= take

	# 2) Pull from any matching stacks, left→right
	if remaining > 0:
		for i in range(inv.slots.size()):
			if i == prefer_slot:
				continue
			var slot: InventorySlot = inv.slots[i]
			if slot.entity_id == item_id and slot.quantity > 0:
				var take2: int = min(slot.quantity, remaining)
				var pre_id2 := slot.entity_id
				var pre_ct2 := take2
				slot.quantity -= take2
				if slot.quantity == 0:
					slot.entity_id = ""
				removals.append({ "slot": i, "removed": take2 })
				item_removed.emit(entity_id, i, pre_id2, pre_ct2)
				remaining -= take2
				if remaining == 0:
					break

	# Outcome
	if removals.size() == 0:
		return { "ok": false, "reason": &"not_found" }

	inventory_changed.emit(entity_id)

	if remaining == 0:
		return { "ok": true, "reason": &"removed_full", "removed": count, "removals": removals }
	else:
		return { "ok": true, "reason": &"removed_partial", "removed": count - remaining, "remaining": remaining, "removals": removals }


func move_between_slots(entity_id: StringName, from_slot: int, to_slot: int, count: int = -1) -> Dictionary:
	var inv := _get_inventory_component(entity_id)
	if not _valid_slot(inv, from_slot) or not _valid_slot(inv, to_slot) or from_slot == to_slot:
		return { "ok": false, "reason": &"bad_slot" }

	var src: InventorySlot = inv.slots[from_slot]
	var dst: InventorySlot = inv.slots[to_slot]
	if src.entity_id == "" or src.quantity <= 0:
		return { "ok": false, "reason": &"empty_source" }

	var move_all := (count <= 0 or count >= src.quantity)
	var max_stack: int = max(1, _get_item_max_stack(src.entity_id))

	# Case A: destination empty → simple move (partial or full)
	if dst.entity_id == "":
		var to_move: int = src.quantity if move_all else min(count, src.quantity)
		dst.entity_id = src.entity_id
		dst.quantity = to_move
		src.quantity -= to_move
		if src.quantity == 0:
			src.entity_id = ""
		item_moved.emit(entity_id, from_slot, entity_id, to_slot, to_move)
		inventory_changed.emit(entity_id)
		return { "ok": true, "reason": &"moved", "moved": to_move }

	# Case B: destination same/stack-compatible → merge up to max_stack
	if _stacking_compatible(src.entity_id, dst.entity_id):
		var room := max_stack - dst.quantity
		if room <= 0:
			return { "ok": false, "reason": &"no_room_target" }
		var to_move2: int = min(src.quantity, room) if move_all else min(count, src.quantity, room)
		if to_move2 <= 0:
			return { "ok": false, "reason": &"nothing_to_move" }
		dst.quantity += to_move2
		src.quantity -= to_move2
		if src.quantity == 0:
			src.entity_id = ""
		item_moved.emit(entity_id, from_slot, entity_id, to_slot, to_move2)
		stack_merged.emit(entity_id, from_slot, to_slot, dst.quantity)
		inventory_changed.emit(entity_id)
		return { "ok": true, "reason": &"merged", "moved": to_move2 }

	# Case C: different items → allow whole-stack SWAP only
	if not move_all:
		return { "ok": false, "reason": &"partial_swap_disallowed" }
	# Swap full stacks
	var tmp_id := dst.entity_id
	var tmp_ct := dst.quantity
	dst.entity_id = src.entity_id
	dst.quantity = src.quantity
	src.entity_id = tmp_id
	src.quantity = tmp_ct
	item_moved.emit(entity_id, from_slot, entity_id, to_slot, dst.quantity)
	item_moved.emit(entity_id, to_slot, entity_id, from_slot, src.quantity)
	inventory_changed.emit(entity_id)
	return { "ok": true, "reason": &"swapped" }


func split_stack(entity_id: StringName, from_slot: int, to_slot: int, count: int) -> Dictionary:
	if count <= 0:
		return { "ok": false, "reason": &"invalid_count" }

	var inv := _get_inventory_component(entity_id)
	if not _valid_slot(inv, from_slot) or not _valid_slot(inv, to_slot) or from_slot == to_slot:
		return { "ok": false, "reason": &"bad_slot" }

	var src: InventorySlot = inv.slots[from_slot]
	var dst: InventorySlot = inv.slots[to_slot]
	if src.entity_id == "" or src.quantity <= 1:
		return { "ok": false, "reason": &"nothing_to_split" }

	var max_stack: int = max(1, _get_item_max_stack(src.entity_id))

	# If target empty → create new stack
	if dst.entity_id == "":
		var to_move: int = min(count, src.quantity - 1, max_stack)  # leave at least 1 in source
		if to_move <= 0:
			return { "ok": false, "reason": &"nothing_to_move" }
		dst.entity_id = src.entity_id
		dst.quantity = to_move
		src.quantity -= to_move
		stack_split.emit(entity_id, from_slot, to_slot, to_move)
		inventory_changed.emit(entity_id)
		return { "ok": true, "reason": &"split_new", "moved": to_move }

	# If target same item → top up target up to max_stack
	if _stacking_compatible(src.entity_id, dst.entity_id):
		var room := max_stack - dst.quantity
		if room <= 0:
			return { "ok": false, "reason": &"no_room_target" }
		var to_move2: int = min(count, src.quantity - 1, room)
		if to_move2 <= 0:
			return { "ok": false, "reason": &"nothing_to_move" }
		dst.quantity += to_move2
		src.quantity -= to_move2
		stack_split.emit(entity_id, from_slot, to_slot, to_move2)
		stack_merged.emit(entity_id, from_slot, to_slot, dst.quantity)
		inventory_changed.emit(entity_id)
		return { "ok": true, "reason": &"split_merged", "moved": to_move2 }

	# Target holds a different item → reject split
	return { "ok": false, "reason": &"target_occupied" }


func merge_slots(entity_id: StringName, source_slot: int, target_slot: int) -> Dictionary:
	var inv := _get_inventory_component(entity_id)
	if not _valid_slot(inv, source_slot) or not _valid_slot(inv, target_slot) or source_slot == target_slot:
		return { "ok": false, "reason": &"bad_slot" }

	var src: InventorySlot = inv.slots[source_slot]
	var dst: InventorySlot = inv.slots[target_slot]
	if src.entity_id == "" or src.quantity <= 0:
		return { "ok": false, "reason": &"empty_source" }

	# If target empty, this is just a move-all
	if dst.entity_id == "":
		dst.entity_id = src.entity_id
		dst.quantity = src.quantity
		var moved := src.quantity
		src.entity_id = ""
		src.quantity = 0
		item_moved.emit(entity_id, source_slot, entity_id, target_slot, moved)
		inventory_changed.emit(entity_id)
		return { "ok": true, "reason": &"moved", "moved": moved }

	# Must be stack-compatible to merge
	if not _stacking_compatible(src.entity_id, dst.entity_id):
		return { "ok": false, "reason": &"incompatible" }

	var max_stack: int = max(1, _get_item_max_stack(dst.entity_id))
	var room := max_stack - dst.quantity
	if room <= 0:
		return { "ok": false, "reason": &"no_room_target" }

	var to_move: int = min(src.quantity, room)
	dst.quantity += to_move
	src.quantity -= to_move
	item_moved.emit(entity_id, source_slot, entity_id, target_slot, to_move)
	stack_merged.emit(entity_id, source_slot, target_slot, dst.quantity)
	if src.quantity == 0:
		src.entity_id = ""
	inventory_changed.emit(entity_id)
	return { "ok": true, "reason": &"merged", "moved": to_move }


## Transfers items from a specific slot in one entity to a specific slot in another entity.
## - If from_entity == to_entity, defers to _move_between_slots_impl.
## - Supports partial moves (count > 0) and whole-stack moves (count <= 0).
## - Merges into compatible stacks, or fills an empty target slot.
## - Does not perform cross-entity swaps; incompatible target returns "target_occupied".
func transfer_slot(from_entity: StringName, from_slot: int, to_entity: StringName, to_slot: int, count := -1) -> Dictionary:
	if from_entity == to_entity:
		return move_between_slots(from_entity, from_slot, to_slot, count)
	
	var inv_from := _get_inventory_component(from_entity)
	var inv_to   := _get_inventory_component(to_entity)
	if not _valid_slot(inv_from, from_slot) or not _valid_slot(inv_to, to_slot):
		return { "ok": false, "reason": &"bad_slot" }

	var src: InventorySlot = inv_from.slots[from_slot]
	var dst: InventorySlot = inv_to.slots[to_slot]

	if src.entity_id == "" or src.quantity <= 0:
		return { "ok": false, "reason": &"empty_source" }

	var item_id := src.entity_id
	var max_stack: int = max(1, _get_item_max_stack(item_id))
	var move_all := (count <= 0 or count >= src.quantity)

	# Case A: destination empty
	if dst.entity_id == "":
		var to_move: int = src.quantity if move_all else min(count, src.quantity)
		# Capacity check on destination (if any policy is installed)
		if not _apply_capacity_policy(to_entity, item_id, to_move):
			return { "ok": false, "reason": &"capacity_denied" }

		# Move
		var pre_id := item_id
		var pre_ct := to_move
		dst.entity_id = item_id
		dst.quantity = to_move
		src.quantity -= to_move
		if src.quantity == 0:
			src.entity_id = ""

		# Signals
		item_removed.emit(from_entity, from_slot, pre_id, pre_ct)
		item_added.emit(to_entity, to_slot, item_id, to_move)
		item_moved.emit(from_entity, from_slot, to_entity, to_slot, to_move)
		inventory_changed.emit(from_entity)
		inventory_changed.emit(to_entity)
		return { "ok": true, "reason": &"moved", "moved": to_move }

	# Case B: destination stack-compatible → merge
	if _stacking_compatible(item_id, dst.entity_id):
		var room := max_stack - dst.quantity
		if room <= 0:
			return { "ok": false, "reason": &"no_room_target" }
		var to_move2: int = min(src.quantity, room) if move_all else min(count, src.quantity, room)
		if to_move2 <= 0:
			return { "ok": false, "reason": &"nothing_to_move" }

		# Capacity check on destination
		if not _apply_capacity_policy(to_entity, item_id, to_move2):
			return { "ok": false, "reason": &"capacity_denied" }

		# Merge
		var pre_id2 := item_id
		var pre_ct2 := to_move2
		dst.quantity += to_move2
		src.quantity -= to_move2
		if src.quantity == 0:
			src.entity_id = ""

		# Signals
		item_removed.emit(from_entity, from_slot, pre_id2, pre_ct2)
		item_added.emit(to_entity, to_slot, item_id, to_move2)
		item_moved.emit(from_entity, from_slot, to_entity, to_slot, to_move2)
		stack_merged.emit(to_entity, from_slot, to_slot, dst.quantity) # merged state is in dest
		inventory_changed.emit(from_entity)
		inventory_changed.emit(to_entity)
		return { "ok": true, "reason": &"merged", "moved": to_move2 }

	# Case C: different items → no cross-entity swap
	return { "ok": false, "reason": &"target_occupied" }


## Batch transfer by item_id across entities, merging into existing stacks and filling empties.
## - If allow_partial == false, succeeds only if full `count` can move atomically.
## - Uses capacity planning; checks destination capacity + (optional) capacity policy.
## - Emits granular signals via the underlying _remove/_add implementations.
func transfer_items(from_entity: StringName, to_entity: StringName, item_id: StringName, count := 1, allow_partial := false) -> Dictionary:
	if item_id == "" or count <= 0:
		return { "ok": false, "reason": &"invalid_args" }
	if from_entity == to_entity:
		# Same-entity "transfer" doesn't make sense by id; caller should use move/merge/split APIs.
		return { "ok": false, "reason": &"same_entity" }

	var inv_from := _get_inventory_component(from_entity)
	var inv_to   := _get_inventory_component(to_entity)
	if inv_from == null or inv_to == null:
		return { "ok": false, "reason": &"no_inventory" }

	# Phase 0: plan feasibility
	var available := _compute_available(inv_from, item_id)
	if available <= 0:
		return { "ok": false, "reason": &"not_found", "available": 0 }

	var add_capacity := _compute_add_capacity(inv_to, item_id)
	if add_capacity <= 0:
		return { "ok": false, "reason": &"no_space_dest", "available": available }

	# Max feasible given both source and dest constraints
	var feasible: int = min(available, add_capacity)

	# Respect capacity policy hook on destination (coarse total check)
	# If a stricter policy is needed (weight/slot-by-slot), override _apply_capacity_policy accordingly.
	if capacity_policy_map.has(to_entity) and capacity_policy_map[to_entity] is Callable:
		# Ask policy if moving `feasible` is allowed; if not, ratchet down to an allowed amount.
		# Fallback: binary step-down until allowed or zero.
		var allowed := 0
		var test := feasible
		while test > 0:
			if _apply_capacity_policy(to_entity, item_id, test):
				allowed = test
				break
			test -= 1
		feasible = allowed

	if feasible <= 0:
		return { "ok": false, "reason": &"capacity_denied" }

	var desired := count
	var to_move := desired

	if desired > feasible:
		if allow_partial:
			to_move = feasible
		else:
			return {
				"ok": false,
				"reason": &"insufficient_capacity_or_supply",
				"available": available,
				"dest_capacity": add_capacity
			}

	# Phase 1: remove from source (should remove exactly to_move)
	var removed_res := remove_item(from_entity, item_id, to_move, -1)
	if not removed_res.get("ok", false):
		return removed_res

	var actually_removed := int(removed_res.get("removed", 0))
	if actually_removed <= 0:
		return { "ok": false, "reason": &"remove_failed" }

	# Phase 2: add to destination
	var added_res := add_item(to_entity, item_id, actually_removed, -1)
	if not added_res.get("ok", false):
		# Try rollback: put items back to source
		var rollback_res := add_item(from_entity, item_id, actually_removed, -1)
		return {
			"ok": false,
			"reason": &"add_failed",
			"removed": actually_removed,
			"rollback_ok": rollback_res.get("ok", false)
		}

	var actually_added := int(added_res.get("added", 0))
	if actually_added != actually_removed:
		# Destination unexpectedly took less than we removed — attempt to return leftovers
		var leftover := actually_removed - actually_added
		if leftover > 0:
			add_item(from_entity, item_id, leftover, -1)  # best-effort
		return {
			"ok": false,
			"reason": &"mismatch_post_add",
			"removed": actually_removed,
			"added": actually_added
		}

	# Optional summary signal (we already have granular ones from add/remove).
	# Emit a single cross-entity move summary count; slots are aggregated.
	item_moved.emit(from_entity, -1, to_entity, -1, actually_added)
	# inventory_changed already emitted by add/remove hooks for both entities.

	var full := (actually_added == desired)
	return {
		"ok": true,
		"reason": &"transferred_full" if full else &"transferred_partial",
		"moved": actually_added,
		"requested": desired,
		"available": available
	}


## —————————————————————————————————————————————
## Clear / Reset
## —————————————————————————————————————————————
##
## Completely empties an entity’s inventory.
## Optionally emits per-item `item_removed` signals followed by one `inventory_changed`.
##
## Returns:
## ```
## {
##     "ok": bool,
##     "reason": StringName,
##     "removed": Array[Dictionary]  # [{slot, item_id, count}, ...]
## }
## ```
func clear_inventory(entity_id: StringName, emit_signals := true) -> Dictionary:
	var inventory := _get_inventory_component(entity_id)
	if inventory == null:
		return { "ok": false, "reason": &"no_inventory", "removed": [] }

	var removed: Array = []
	for i in range(inventory.slots.size()):
		var slot: InventorySlot = inventory.slots[i]
		if slot.entity_id != "":
			var removed_item_id := slot.entity_id
			var removed_count   := slot.quantity
			removed.append({
				"slot": i,
				"item_id": removed_item_id,
				"count": removed_count
			})
			slot.entity_id = ""
			slot.quantity = 0
			if emit_signals:
				item_removed.emit(entity_id, i, removed_item_id, removed_count)

	if emit_signals:
		inventory_changed.emit(entity_id)

	return { "ok": true, "reason": &"cleared", "removed": removed }

#endregion

## —————————————————————————————————————————————
#region Internal Implementation Hooks (override in subclass)
## —————————————————————————————————————————————


func _apply_capacity_policy(entity_id: StringName, delta_item_id: StringName, delta_count: int) -> bool:
	# If a policy exists for this entity, ask it; otherwise allow.
	if capacity_policy_map.has(entity_id) and capacity_policy_map[entity_id] is Callable:
		return capacity_policy_map[entity_id].call(delta_item_id, delta_count)
	return true


# How much of `item_id` can be added to `inv` right now (in units, not stacks)?
func _compute_add_capacity(inv, item_id: StringName) -> int:
	if inv == null:
		return 0
	var max_stack: int = max(1, _get_item_max_stack(item_id))
	var capacity := 0
	for s: InventorySlot in inv.slots:
		if s.entity_id == "":
			capacity += max_stack
		elif _stacking_compatible(s.entity_id, item_id):
			capacity += max(0, max_stack - s.quantity)
	return capacity


# Total available units of `item_id` present in `inv_from`.
func _compute_available(inv_from, item_id: StringName) -> int:
	if inv_from == null:
		return 0
	var total := 0
	for s: InventorySlot in inv_from.slots:
		if s.entity_id == item_id:
			total += s.quantity
	return total


## Gets the max number of an item that can be stacked.
func _get_item_max_stack(item_id: StringName) -> int:
	var total: int = 99
	var item := _get_item_component(item_id)
	if item != null:
		total = item.max_stack
	return total


func _stacking_compatible(item_a_id: StringName, item_b_id: StringName) -> bool:
	# If a custom stacking policy is provided, defer to it; otherwise same item_id stacks.
	if stacking_policy is Callable:
		# Minimal shape: pass item ids only; concrete impls can use item ids to pull component data
		return stacking_policy.call(item_a_id, item_b_id)
	return item_a_id == item_b_id


# Validates that the [InventoryComponent] has a [InventorySlot] at a specific index.
func _valid_slot(inv: InventoryComponent, idx: int) -> bool:
	return inv != null and idx >= 0 and idx < inv.slots.size()

#endregion

## —————————————————————————————————————————————
#region Component Fetchers
## —————————————————————————————————————————————
@abstract func _get_item_component(item_id: StringName) -> ItemComponent
#   var item: ItemComponent = _entity_manager.get_component(item_id, ItemComponent) as ItemComponent
#	return item

@abstract func _get_inventory_component(entity_id: StringName) -> InventoryComponent
#   var inv: InventoryComponent = _entity_manager.get_component(entity_id, InventoryComponent) as InventoryComponent
#	return inv

#endregion
