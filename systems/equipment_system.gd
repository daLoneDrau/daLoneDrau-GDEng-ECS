# res://ecs/systems/EquipmentSystem.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Runtime logic for equipping/unequipping items on entities that
## have an EquipmentComponent. This class provides:
## - Slot validation & conflict resolution (two-hand, uniques, etc.)
## - Equip/unequip/swap public API with before/after hooks
## - Inventory handoff (move item in/out of InventoryComponent)
## - Modifier aggregation (merge ItemModifierBundle across slots)
## - Signals for PlayerSystem/UI/ScriptSystem listeners
## Subclass this to bind field names if your components differ.
## All "EXPECTS:" comments mark small glue you may need to adapt.
@abstract class_name EquipmentSystem
extends GameSystem


## —————————————————————————————————————————————
#region Signals
## —————————————————————————————————————————————


signal before_equip(entity_id: StringName, item_id: StringName, slot: int)
signal  after_equip(entity_id: StringName, item_id: StringName, slot: int)
signal before_unequip(entity_id: StringName, item_id: StringName, slot: int)
signal  after_unequip(entity_id: StringName, item_id: StringName, slot: int)

signal equipment_changed(entity_id: StringName)        # for PlayerSystem/UI
signal modifiers_changed(entity_id: StringName)        # when aggregate mods update
signal equip_failed(entity_id: StringName, item_id: StringName, reasons: Array[String])

#endregion


## —————————————————————————————————————————————
#region System References. will be set in concrete implementations using Autoload instances
## —————————————————————————————————————————————

## the [EntityManager] instance
var _entity_manager: EntityManager

## the [PlayerSystem] instance
var _player_system: PlayerSystem

#endregion

## —————————————————————————————————————————————
#region Cached state
## —————————————————————————————————————————————
# entity_id -> ItemModifierBundle (merged from all equipped items)
var _merged_cache: Dictionary = {}
# entity_id -> {slot:int -> item_id:StringName}
var _equipped_view: Dictionary = {}

#endregion

## —————————————————————————————————————————————
#region Tunables & Slot rules
## —————————————————————————————————————————————
enum Rule {
	TWO_HANDS_LOCK,     # two-handed item occupies both hands
	UNIQUE_PER_SLOT,    # disallow duplicate of same item id per slot family
	REQUIREMENTS_CHECK, # level/attribute/class/gender/etc requirements
	SCRIPT_GUARD,       # allow external scripts to veto equip
}

var enabled_rules: int = (
	1 << Rule.TWO_HANDS_LOCK |
	1 << Rule.UNIQUE_PER_SLOT |
	1 << Rule.REQUIREMENTS_CHECK |
	1 << Rule.SCRIPT_GUARD
)

# Define slot families to resolve conflicts (edit to match your EquipmentSlot.Enum)
var HAND_SLOTS: Array[int] = [
	EquipmentSlot.Enum.MAIN_HAND,
	EquipmentSlot.Enum.OFF_HAND
]

# If you have ring slots, helmets, etc., you can group them similarly.
var RING_SLOTS: Array[int] = [] # e.g., [EquipmentSlot.Enum.RING_L, EquipmentSlot.Enum.RING_R]

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————


## Called when the node enters the [SceneTree].
func _enter_tree() -> void:
	Switchboard_auto.add_node_broadcaster(self, "equip_failed", Switchboard.SubscriptionStrategy.UNLIMITED)
	# Clear caches on hot-reload
	_merged_cache.clear()
	_equipped_view.clear()

	
## Called when the node is about to leave the [SceneTree].
func _exit_tree() -> void:
	Switchboard_auto.remove_node_broadcaster(self, "equip_failed", Switchboard.SubscriptionStrategy.UNLIMITED)
	_merged_cache.clear()
	_equipped_view.clear()

#endregion

## —————————————————————————————————————————————
#region Public API
## —————————————————————————————————————————————

## Try to equip an item to a specific or auto-resolved slot.
## Returns true on success; emits equip_failed with reasons on failure.
func equip(entity_id: StringName, item_id: StringName, desired_slot: int = -1) -> bool:
	var reasons: Array[String] = []
	
	## EXIT - ENTITYMANAGER INSTANCE NOT SET
	if _entity_manager == null:
		reasons.append("No EntityManager")
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	## EXIT - ENTITY NOT EXIST OR HAS NO EQUIPMENTCOMPONENT AND CANNOT EQUIP ITEMS
	if not _entity_manager.has_entity(entity_id) or not _has_equipment_component(entity_id):
		if not _entity_manager.has_entity(entity_id):
			reasons.append("Entity does not exist")
		else:
			reasons.append("Entity has no EquipmentComponent")
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	# Item lookups ----------------------------------------------------------
	## EXIT - ITEM DOES NOT EXIST OR HAS NO ITEMCOMPONENT
	if not _entity_manager.has_entity(item_id) or not _has_item_component(item_id):
		if not _entity_manager.has_entity(item_id):
			reasons.append("Item does not exist")
		else:
			reasons.append("Item has no ItemComponent")
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	var slots_for_item: Array[int] = _get_item_compatible_slots(item_id)
	## EXIT - NO COMPATIBLE SLOT TO EQUIP ITEM
	if slots_for_item.is_empty():
		reasons.append("Item cannot be equipped (no compatible slots)")
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	var slot_to_use := _resolve_slot(entity_id, item_id, desired_slot, slots_for_item, reasons)
	if slot_to_use == -1:
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	# Rule checks -----------------------------------------------------------
	if not _passes_all_rules(entity_id, item_id, slot_to_use, reasons):
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	# Inventory handoff (EXPECTS: InventoryComponent provides has/remove/add)
	if not _pull_from_inventory_if_present(entity_id, item_id, reasons):
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	# Perform equip ---------------------------------------------------------
	emit_signal("before_equip", entity_id, item_id, slot_to_use)
	_script_guard("before_equip", entity_id, item_id, slot_to_use) # optional external hook

	# Two-hand lock if needed
	var also_lock_slot := _maybe_lock_two_hands(entity_id, item_id, slot_to_use, reasons)
	if also_lock_slot == -2:
		emit_signal("before_unequip", entity_id, item_id, slot_to_use) # roll back signal symmetry
		_return_item_to_inventory(entity_id, item_id) # give back
		_emit_equip_failed(entity_id, item_id, reasons)
		return false

	_set_equipped_slot(entity_id, slot_to_use, item_id)
	if also_lock_slot >= 0:
		_set_equipped_slot(entity_id, also_lock_slot, item_id) # mirror item occupying both hands

	emit_signal("after_equip", entity_id, item_id, slot_to_use)
	_script_guard("after_equip", entity_id, item_id, slot_to_use)

	_recompute_and_emit(entity_id)
	return true


## Unequip the item currently in a slot (if any), returning it to inventory.
func unequip(entity_id: StringName, slot: int) -> bool:
	if not _has_equipment_component(entity_id):
		return false

	var current := _get_equipped_map(entity_id)
	if not current.has(slot):
		return true # nothing to do

	var item_id: StringName = current[slot]
	emit_signal("before_unequip", entity_id, item_id, slot)
	_script_guard("before_unequip", entity_id, item_id, slot)

	# If this is a two-hand occupancy, clear the paired slot too
	_maybe_clear_two_hand_pair(entity_id, slot, item_id)

	# Clear the primary slot
	_clear_equipped_slot(entity_id, slot)

	# Return to inventory
	_return_item_to_inventory(entity_id, item_id)

	emit_signal("after_unequip", entity_id, item_id, slot)
	_script_guard("after_unequip", entity_id, item_id, slot)

	_recompute_and_emit(entity_id)
	return true


## Swap two equipment slots on the same entity (if both present).
func swap_slots(entity_id: StringName, slot_a: int, slot_b: int) -> bool:
	if not _has_equipment_component(entity_id):
		return false
	if slot_a == slot_b:
		return true

	var map: Dictionary = _get_equipped_map(entity_id)
	var a: String = map.get(slot_a, "")
	var b: String = map.get(slot_b, "")

	# Naive swap with validation for destination compatibility
	if a != null:
		var reasons_a := []
		if not _slot_accepts_item(entity_id, slot_b, a, reasons_a):
			return false
	if b != null:
		var reasons_b := []
		if not _slot_accepts_item(entity_id, slot_a, b, reasons_b):
			return false

	_set_equipped_slot(entity_id, slot_a, b)
	_set_equipped_slot(entity_id, slot_b, a)
	_recompute_and_emit(entity_id)
	return true


## Query the merged modifiers for an entity (cached).
func get_merged_modifiers(entity_id: StringName) -> ItemModifierBundle:
	if _merged_cache.has(entity_id):
		return _merged_cache[entity_id]
	# Compute on demand if missing
	return _recompute_merged(entity_id)


## Convenience: returns {slot:int -> item_id:StringName}
func get_equipped(entity_id: StringName) -> Dictionary:
	return _get_equipped_map(entity_id).duplicate()


## Validate whether an item *could* be equipped into a given or auto slot.
## Returns a dictionary: { ok: bool, resolved_slot: int, reasons: Array[String] }
func can_equip(entity_id: StringName, item_id: StringName, desired_slot: int = -1) -> Dictionary:
	var reasons: Array[String] = []
	var slots_for_item := _get_item_compatible_slots(item_id)
	if slots_for_item.is_empty():
		reasons.append("Item cannot be equipped (no compatible slots)")
		return { ok = false, resolved_slot = -1, reasons = reasons }

	var slot_to_use := _resolve_slot(entity_id, item_id, desired_slot, slots_for_item, reasons)
	if slot_to_use == -1:
		return { ok = false, resolved_slot = -1, reasons = reasons }

	if not _passes_all_rules(entity_id, item_id, slot_to_use, reasons):
		return { ok = false, resolved_slot = -1, reasons = reasons }

	return { ok = true, resolved_slot = slot_to_use, reasons = reasons }


## Force a full rebuild of the aggregate modifiers (and emit signals).
func recompute_modifiers(entity_id: StringName) -> void:
	_recompute_and_emit(entity_id)

## —————————————————————————————————————————————
#region Internal — Validation & Rules
## —————————————————————————————————————————————

func _passes_all_rules(entity_id: StringName, item_id: StringName, slot: int, reasons: Array[String]) -> bool:
	if (enabled_rules & (1 << Rule.REQUIREMENTS_CHECK)) != 0:
		if not _requirements_ok(entity_id, item_id, reasons):
			return false

	if (enabled_rules & (1 << Rule.UNIQUE_PER_SLOT)) != 0:
		if not _unique_in_family_ok(entity_id, item_id, slot, reasons):
			return false

	if (enabled_rules & (1 << Rule.TWO_HANDS_LOCK)) != 0:
		if not _two_hand_ok(entity_id, item_id, slot, reasons):
			return false

	if (enabled_rules & (1 << Rule.SCRIPT_GUARD)) != 0:
		if not _script_guard("can_equip", entity_id, item_id, slot):
			reasons.append("Script veto: can_equip")
			return false

	return true


func _requirements_ok(entity_id: StringName, item_id: StringName, reasons: Array[String]) -> bool:
	# EXPECTS: ItemComponent may carry fields like required_level, tags, class, gender, etc.
	# Stub always true by default. Override in subclass if you have real requirements.
	var ic: ItemComponent = _entity_manager.get_component(item_id, ItemComponent) as ItemComponent
	if ic == null:
		return true
	var req: Dictionary = ic.requirements
	
	# Ask PlayerSystem to evaluate
	if _player_system != null:
		if not _player_system.meets_item_requirements(entity_id, req):
			reasons.append("Requirements not met")
			return false
	return true


func _unique_in_family_ok(entity_id: StringName, item_id: StringName, slot: int, reasons: Array[String]) -> bool:
	# Example rule: prevent equipping same exact item_id in both hand slots simultaneously
	if HAND_SLOTS.has(slot):
		var map := _get_equipped_map(entity_id)
		for s in HAND_SLOTS:
			if map.get(s, &"") == item_id:
				reasons.append("Duplicate item in hand family")
				return false
	return true


func _two_hand_ok(entity_id: StringName, item_id: StringName, slot: int, reasons: Array[String]) -> bool:
	# EXPECTS: ItemComponent exposes a boolean like is_two_handed
	var is_two_handed := _item_is_two_handed(item_id)
	if not is_two_handed:
		return true
	# If two-handed, we must occupy *both* hand slots (if you have hands)
	if not HAND_SLOTS.has(slot):
		reasons.append("Two-handed item must be placed in a hand slot")
		return false

	var other := _other_hand_slot(slot)
	var map := _get_equipped_map(entity_id)
	# ok if other hand is empty or will be replaced by same item during equip step
	if map.has(other) and map[other] != null and map[other] != &"" and map[other] != item_id:
		reasons.append("Off-hand occupied (two-handed conflict)")
		return false

	return true


func _resolve_slot(entity_id: StringName, item_id: StringName, desired_slot: int, slots_for_item: Array[int], reasons: Array[String]) -> int:
	# If user specified slot, validate it first
	if desired_slot != -1:
		if not slots_for_item.has(desired_slot):
			reasons.append("Item not compatible with desired slot")
			return -1
		var r := []
		if not _slot_accepts_item(entity_id, desired_slot, item_id, r):
			reasons.append_array(r)
			return -1
		return desired_slot

	# Otherwise auto-pick: prefer empty compatible slot
	var map := _get_equipped_map(entity_id)
	for s in slots_for_item:
		if not map.has(s) or map[s] == null or map[s] == &"":
			var r := []
			if _slot_accepts_item(entity_id, s, item_id, r):
				return s

	# If all occupied, allow replacing first compatible slot (policy choice)
	for s in slots_for_item:
		var r2 := []
		if _slot_accepts_item(entity_id, s, item_id, r2):
			return s

	reasons.append("No suitable slot available")
	return -1


@abstract func _slot_accepts_item(entity_id: StringName, slot: int, item_id: StringName, reasons: Array[String]) -> bool
	# Hook point if certain slots reject certain subtypes beyond compatibility list
	# Default true; subclass if you have armor proficiencies etc.


func _item_is_two_handed(item_id: StringName) -> bool:
	# EXPECTS: ItemComponent boolean field like `two_handed` or subtype check
	var comp: ItemComponent = _entity_manager.get_component(item_id, ItemComponent)
	if comp == null:
		return false

	return comp.two_handed

func _other_hand_slot(slot: int) -> int:
	if HAND_SLOTS.is_empty():
		return -1
	if slot == HAND_SLOTS[0] and HAND_SLOTS.size() > 1:
		return HAND_SLOTS[1]
	if slot == HAND_SLOTS[1]:
		return HAND_SLOTS[0]
	return -1


func _maybe_lock_two_hands(entity_id: StringName, item_id: StringName, primary_slot: int, reasons: Array[String]) -> int:
	if not _item_is_two_handed(item_id):
		return -1
	if HAND_SLOTS.is_empty():
		return -1
	var other := _other_hand_slot(primary_slot)
	if other == -1:
		reasons.append("Two-handed lock failed (no paired slot)")
		return -2
	# Clear anything in the other hand (auto-unequip back to inventory)
	var map := _get_equipped_map(entity_id)
	if map.has(other) and map[other] != null and map[other] != &"" and map[other] != item_id:
		_return_item_to_inventory(entity_id, map[other])
		_clear_equipped_slot(entity_id, other)
	# Return which slot we also mark with this item
	return other


func _maybe_clear_two_hand_pair(entity_id: StringName, slot: int, item_id: StringName) -> void:
	if not _item_is_two_handed(item_id):
		return
	var other := _other_hand_slot(slot)
	if other == -1:
		return
	var map := _get_equipped_map(entity_id)
	if map.get(other, &"") == item_id:
		_clear_equipped_slot(entity_id, other)

## —————————————————————————————————————————————
#region Internal — Inventory handoff
## —————————————————————————————————————————————


# Equip the first compatible item from inventory into a given slot (or auto).
func equip_any_from_inventory(entity_id: StringName, desired_slot: int = -1) -> bool:
	var inv: InventoryComponent = _entity_manager.get_component(entity_id, InventoryComponent) as InventoryComponent
	if inv == null or not inv.has_method("iter_item_ids"):
		return false

	for item_id in inv.iter_item_ids():           # EXPECTS: yields item StringNames
		var can := can_equip(entity_id, item_id, desired_slot)
		if can.ok:
			return equip(entity_id, item_id, can.resolved_slot)
	return false


func _pull_from_inventory_if_present(entity_id: StringName, item_id: StringName, _reasons: Array[String]) -> bool:
	var inv: InventoryComponent = _entity_manager.get_component(entity_id, InventoryComponent)
	if inv == null:
		# No inventory: allow equipping if item is already "owned/attached"
		return true
	# EXPECTS: your InventoryComponent to offer has/remove semantics.
	# If inv.has_item(item_id): inv.remove_item(item_id)
	if inv.has_method("has_item") and inv.has_method("remove_item"):
		if inv.has_item(item_id):
			return inv.remove_item(item_id)
	return true


func _return_item_to_inventory(entity_id: StringName, item_id: StringName) -> void:
	var inv: InventoryComponent = _entity_manager.get_component(entity_id, InventoryComponent)
	if inv == null:
		return
	# EXPECTS: add_item(item_id) or add_stack(item_id, qty)
	if inv.has_method("add_item"):
		inv.add_item(item_id)
	elif inv.has_method("add_stack"):
		inv.add_stack(item_id, 1)

## —————————————————————————————————————————————
#region Internal — Component accessors
## —————————————————————————————————————————————


## Utility to check if an [Entity] has an [EquipmentComponent].
func _has_equipment_component(entity_id: StringName) -> bool:
	return _entity_manager != null and _entity_manager.get_component(entity_id, EquipmentComponent) != null


## Utility to check if an [Entity] has an [ItemComponent].
func _has_item_component(entity_id: StringName) -> bool:
	return _entity_manager != null and _entity_manager.get_component(entity_id, ItemComponent) != null
	
#endregion

## —————————————————————————————————————————————
#region Equipment Slot/Equipment cache accessors
## —————————————————————————————————————————————


## Clears an equipment slot for an [Entity]'s [EquipmentComponent].
func _clear_equipped_slot(entity_id: StringName, slot: int) -> void:
	var map := _get_equipped_map(entity_id)
	map.erase(slot)
	_write_equipped_to_component(entity_id, map)


## Gets an [Entity]'s equipment slots from their [EquipmentComponent]; uses the cached version if available, otherwise reads it fresh and caches that.
func _get_equipped_map(entity_id: StringName) -> Dictionary:
	# Fast view cache; fall back to component if absent
	if _equipped_view.has(entity_id):
		return _equipped_view[entity_id]
	var map := _read_equipped_from_component(entity_id)
	_equipped_view[entity_id] = map
	return map


## Reads the equipment slots [Dictionary] from an [Entity]'s [EquipmentComponent] and returns a copy of it.
func _read_equipped_from_component(entity_id: StringName) -> Dictionary[int, String]:
	# EXPECTS: EquipmentComponent stores a slot->item_id dictionary (e.g., `slots`)
	var comp: EquipmentComponent = _entity_manager.get_component(entity_id, EquipmentComponent)
	if comp == null:
		return {}
	var store: Dictionary= comp.slots
	if typeof(store) == TYPE_DICTIONARY:
		return store.duplicate()
	return {}


## Sets the value in an equipment slot for an [Entity]'s [EquipmentComponent].
func _set_equipped_slot(entity_id: StringName, slot: int, item_id: StringName) -> void:
	var map := _get_equipped_map(entity_id)
	map[slot] = item_id
	_write_equipped_to_component(entity_id, map)


## Writes changes to an [Entity]'s [EquipmentComponent]'s equipment slots [Dictionary].
func _write_equipped_to_component(entity_id: StringName, data: Dictionary) -> void:
	var comp: EquipmentComponent = _entity_manager.get_component(entity_id, EquipmentComponent)
	if comp == null:
		return
	comp.slots = data.duplicate()
	_equipped_view[entity_id] = data.duplicate()

#endregion

## —————————————————————————————————————————————
#region Internal — Item compatibility
## —————————————————————————————————————————————


## Gets compatible [EquipmentSlot]s assigned to an item.
func _get_item_compatible_slots(item_id: StringName) -> Array[int]:
	# EXPECTS: ItemComponent has `equip_slots: Array[int]` listing EquipmentSlot.Enum values
	var comp: ItemComponent = _entity_manager.get_component(item_id, ItemComponent)
	if comp == null:
		return []
	var arr := comp.equip_slots
	if typeof(arr) == TYPE_ARRAY:
		return arr.duplicate()
	return []

#endregion

## —————————————————————————————————————————————
#region Internal — Modifiers aggregation
## —————————————————————————————————————————————

func _recompute_and_emit(entity_id: StringName) -> void:
	_recompute_merged(entity_id)
	emit_signal("modifiers_changed", entity_id)
	emit_signal("equipment_changed", entity_id)
	# Optional: notify a global bus (ScriptSystem listeners etc.)
	_script_guard("equipment_changed", entity_id, &"", -1)


func _recompute_merged(entity_id: StringName) -> ItemModifierBundle:
	var merged := ItemModifierBundle.new()  # EXPECTS: has add_from(other) or similar
	var map := _get_equipped_map(entity_id)
	var set_counts := {}   # set_id -> pieces

	# 1) Merge per-item mods & count sets
	for slot in map.keys():
		var item_id: StringName = map[slot]
		var mods := _mods_for_item(item_id)
		if mods != null:
			_add_mods(merged, mods)
		var set_id := _item_set_id(item_id)
		if set_id != &"":
			set_counts[set_id] = int(set_counts.get(set_id, 0)) + 1

	# 2) Apply set thresholds
	for sid in set_counts.keys():
		var pieces := int(set_counts[sid])
		var bonuses := _item_set_bonuses_for(sid) # [{pieces:int, mods:EquipMods|Dictionary}, ...]
		for b in bonuses:
			var req := int(b.get("pieces", 0))
			if pieces >= req:
				_add_mods(merged, _coerce_mods(b.get("mods", {})))

	# Cache & return
	_merged_cache[entity_id] = merged
	return merged


func _item_set_id(item_id: StringName) -> StringName:
	var ic: ItemComponent = _entity_manager.get_component(item_id, ItemComponent) as ItemComponent
	return ic.set_id if ic != null else &""

func _item_set_bonuses_for(set_id: StringName) -> Array:
	# Pull from any *equipped* item with this set_id. (Uniform data per set)
	# Simpler: scan equipped again for first match
	# You can also keep a global set registry if you prefer.
	return _find_any_set_bonuses(set_id)

@abstract func _find_any_set_bonuses(set_id: StringName) -> Array
# 	# naive scan: in a real build cache this per set_id
#	for eid in _get_equipped_map().keys():
#		var m: Dictionary = _get_equipped_map(eid)
#		for s in m.keys():
#			var it = m[s]
#			var ic: ItemComponent = _entity_manager.get_component(it, ItemComponent) as ItemComponent
#			if ic != null and ic.set_id == set_id:
#				return ic.set_bonuses
#	return []

func _coerce_mods(v) -> ItemModifierBundle:
	if v is ItemModifierBundle:
		return v
	# v is Dictionary — build a temp EquipmentItemMods
	var tmp: ItemModifierBundle = ItemModifierBundle.new()
	for k in v.keys():
		tmp.set(k, v[k])
	return tmp


func _mods_for_item(item_id: StringName) -> ItemModifierBundle:
	# EXPECTS: ItemComponent either embeds modifiers or references a child resource.
	var item: ItemComponent = _entity_manager.get_component(item_id, ItemComponent)
	if item == null:
		return null

	var mods := item.modifiers
	return mods if (mods is ItemModifierBundle) else null


func _add_mods(into: ItemModifierBundle, from: ItemModifierBundle) -> void:
	# EXPECTS: ItemModifierBundle defines an API like: into.merge(from) or into.add_from(from)
	into.merge(from)

## —————————————————————————————————————————————
#region Internal — Script hooks (optional)
## —————————————————————————————————————————————


func _script_guard(phase: String, entity_id: StringName, item_id: StringName, slot: int) -> bool:
	# phase is one of: "can_equip", "before_equip", "after_equip", "equipment_changed"
	var payload := {
		"entity_id": entity_id,
		"item_id": item_id,
		"slot": slot
	}
	# Expect Switchboard to return bool for veto-able phases; otherwise ignore result
	var channel := "equipment_" + phase
	
	#TODO - fix this so it calls _script_system and checks the return value for pass/fail
	# _script_system._dispatch(entity_id, 
	if Switchboard_auto.has_method("dispatch_bool"):
		return bool(Switchboard_auto.dispatch_bool(channel, payload, true)) # default allow
	Switchboard_auto.emit_signal(channel, payload) # fire-and-forget
	return true

## —————————————————————————————————————————————
#region Internal — Utilities
## —————————————————————————————————————————————
func _emit_equip_failed(entity_id: StringName, item_id: StringName, reasons: Array[String]) -> void:
	equip_failed.emit(entity_id, item_id, reasons)

