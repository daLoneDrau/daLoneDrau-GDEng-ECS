## Stores party-level data for a party entity.
## The party itself is an entity that references its members.
## Examples: Adventuring party, enemy squad, merchant caravan
class_name PartyComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when party membership changes
signal member_added(party_id: String, member_id: String, slot: int)
signal member_removed(party_id: String, member_id: String, reason: StringName)
signal leader_changed(party_id: String, old_leader_id: String, new_leader_id: String)

## Emitted when party state changes
signal party_state_changed(party_id: String, field: StringName, old_value: Variant, new_value: Variant)

## Emitted when party is full/has space
signal party_full(party_id: String)
signal party_has_space(party_id: String, open_slots: int)

## Emitted when party is disbanded
signal party_disbanded(party_id: String)

## —————————————————————————————————————————————
## Membership
## —————————————————————————————————————————————

## Entity ID of the party leader
@export var leader_id: String = "":
	set(value):
		if leader_id != value:
			var old := leader_id
			leader_id = value
			if _lifecycle_initialized:
				leader_changed.emit(parent_entity_id, old, value)
				_emit_change(&"leader_id", old, value)

## Entity IDs of all party members (includes leader)
@export var member_ids: Array[String] = []

## Maximum party size
@export var max_size: int = 4:
	set(value):
		if max_size != value:
			var old := max_size
			max_size = maxi(1, value)
			_emit_change(&"max_size", old, max_size)

## —————————————————————————————————————————————
## Formation & Tactics
## —————————————————————————————————————————————

@export_group("Formation")

## Current formation type
@export var formation: StringName = &"standard":
	set(value):
		if formation != value:
			var old := formation
			formation = value
			_emit_change(&"formation", old, value)

## Marching order (entity IDs in order, front to back)
@export var marching_order: Array[String] = []

## —————————————————————————————————————————————
## Party State
## —————————————————————————————————————————————

@export_group("State")

## Is the party currently in combat?
@export var in_combat: bool = false:
	set(value):
		if in_combat != value:
			var old := in_combat
			in_combat = value
			_emit_change(&"in_combat", old, value)

## Is the party resting?
@export var is_resting: bool = false:
	set(value):
		if is_resting != value:
			var old := is_resting
			is_resting = value
			_emit_change(&"is_resting", old, value)

## Is the party disbanded?
@export var is_disbanded: bool = false

## —————————————————————————————————————————————
## Shared Resources (Optional - can also use separate components)
## —————————————————————————————————————————————

@export_group("Shared Resources")

## Party treasury (shared gold)
@export var shared_gold: int = 0:
	set(value):
		if shared_gold != value:
			var old := shared_gold
			shared_gold = maxi(0, value)
			_emit_change(&"shared_gold", old, shared_gold)

## Whether to use shared gold vs individual gold
@export var use_shared_gold: bool = true


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init() -> void:
	super()
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"member_added",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"member_removed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"leader_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"party_state_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"party_full",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"party_has_space",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"party_disbanded",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "member_added")
	Switchboard_auto.remove_resource_broadcaster(self, "member_removed")
	Switchboard_auto.remove_resource_broadcaster(self, "leader_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "party_state_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "party_full")
	Switchboard_auto.remove_resource_broadcaster(self, "party_has_space")
	Switchboard_auto.remove_resource_broadcaster(self, "party_disbanded")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)


func on_removed(entity: Entity, em: EntityManager) -> void:
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()

#endregion

## —————————————————————————————————————————————
#region Member Management
## —————————————————————————————————————————————

## Add a member to the party. Returns slot index or -1 if failed.
func add_member(entity_id: String, make_leader: bool = false) -> int:
	if entity_id.is_empty():
		push_warning("PartyComponent: Cannot add member with empty ID")
		return -1

	if is_member(entity_id):
		push_warning("PartyComponent: Entity '%s' is already a member" % entity_id)
		return get_member_slot(entity_id)

	if is_full():
		push_warning("PartyComponent: Party is full (%d/%d)" % [member_ids.size(), max_size])
		return -1

	var slot := member_ids.size()
	member_ids.append(entity_id)

	# Add to marching order at the back
	if not marching_order.has(entity_id):
		marching_order.append(entity_id)

	# Set as leader if requested or if first member
	if make_leader or leader_id.is_empty():
		leader_id = entity_id

	if _lifecycle_initialized:
		member_added.emit(parent_entity_id, entity_id, slot)
		emit_update_signal()

		if is_full():
			party_full.emit(parent_entity_id)

	return slot


## Remove a member from the party. Returns true if successful.
func remove_member(entity_id: String, reason: StringName = &"left") -> bool:
	if not is_member(entity_id):
		return false

	var was_full := is_full()

	member_ids.erase(entity_id)
	marching_order.erase(entity_id)

	# Handle leader removal
	if leader_id == entity_id:
		_assign_new_leader()

	if _lifecycle_initialized:
		member_removed.emit(parent_entity_id, entity_id, reason)
		emit_update_signal()

		if was_full and not is_full():
			party_has_space.emit(parent_entity_id, get_open_slots())

	return true


## Check if entity is a party member
func is_member(entity_id: String) -> bool:
	return member_ids.has(entity_id)


## Check if entity is the party leader
func is_leader(entity_id: String) -> bool:
	return leader_id == entity_id


## Get member's slot index (-1 if not found)
func get_member_slot(entity_id: String) -> int:
	return member_ids.find(entity_id)


## Get member ID at a specific slot
func get_member_at_slot(slot: int) -> String:
	if slot < 0 or slot >= member_ids.size():
		return ""
	return member_ids[slot]


## Get all member IDs
func get_member_ids() -> Array[String]:
	return member_ids.duplicate()


## Get member count
func get_member_count() -> int:
	return member_ids.size()


## Check if party is empty
func is_empty() -> bool:
	return member_ids.is_empty()


## Check if party is at max capacity
func is_full() -> bool:
	return member_ids.size() >= max_size


## Get number of open slots
func get_open_slots() -> int:
	return maxi(0, max_size - member_ids.size())

#endregion

## —————————————————————————————————————————————
#region Leadership
## —————————————————————————————————————————————

## Promote a member to leader
func promote_to_leader(entity_id: String) -> bool:
	if not is_member(entity_id):
		push_warning("PartyComponent: Cannot promote non-member '%s' to leader" % entity_id)
		return false

	if is_leader(entity_id):
		return true  # Already leader

	leader_id = entity_id
	return true


## Assign new leader when current leader is removed
func _assign_new_leader() -> void:
	if member_ids.is_empty():
		leader_id = ""
		return

	# Promote first member in marching order, or first member
	for member_id in marching_order:
		if member_ids.has(member_id):
			leader_id = member_id
			return

	# Fallback to first member
	leader_id = member_ids[0]


## Get leader ID
func get_leader_id() -> String:
	return leader_id


## Check if party has a leader
func has_leader() -> bool:
	return not leader_id.is_empty() and is_member(leader_id)

#endregion

## —————————————————————————————————————————————
#region Formation & Marching Order
## —————————————————————————————————————————————

## Set marching order (front to back)
func set_marching_order(order: Array[String]) -> void:
	# Validate all IDs are members
	for entity_id in order:
		if not is_member(entity_id):
			push_warning("PartyComponent: Cannot set marching order with non-member '%s'" % entity_id)
			return

	marching_order = order.duplicate()
	_emit_change(&"marching_order", [], marching_order)


## Get entity at front of marching order
func get_front_member() -> String:
	if marching_order.is_empty():
		return leader_id
	return marching_order[0]


## Get entity at back of marching order
func get_back_member() -> String:
	if marching_order.is_empty():
		return leader_id
	return marching_order[marching_order.size() - 1]


## Move a member to a specific position in marching order
func set_marching_position(entity_id: String, position: int) -> bool:
	if not is_member(entity_id):
		return false

	marching_order.erase(entity_id)
	position = clampi(position, 0, marching_order.size())
	marching_order.insert(position, entity_id)
	_emit_change(&"marching_order", [], marching_order)
	return true


## Swap two members in marching order
func swap_marching_positions(entity_id_a: String, entity_id_b: String) -> bool:
	var index_a := marching_order.find(entity_id_a)
	var index_b := marching_order.find(entity_id_b)

	if index_a < 0 or index_b < 0:
		return false

	marching_order[index_a] = entity_id_b
	marching_order[index_b] = entity_id_a
	_emit_change(&"marching_order", [], marching_order)
	return true

#endregion

## —————————————————————————————————————————————
#region Shared Resources
## —————————————————————————————————————————————

## Add gold to party treasury
func add_shared_gold(amount: int) -> void:
	if amount > 0:
		shared_gold += amount


## Spend gold from party treasury (returns true if successful)
func spend_shared_gold(amount: int) -> bool:
	if amount > shared_gold:
		return false
	shared_gold -= amount
	return true


## Check if party can afford something
func can_afford(amount: int) -> bool:
	return shared_gold >= amount


## Split gold evenly among members (remainder stays in treasury)
func distribute_gold() -> Dictionary:
	if member_ids.is_empty() or shared_gold <= 0:
		return {}

	var per_member := shared_gold / member_ids.size()
	var remainder := shared_gold % member_ids.size()

	var distribution: Dictionary = {}
	for member_id in member_ids:
		distribution[member_id] = per_member

	shared_gold = remainder
	return distribution

#endregion

## —————————————————————————————————————————————
#region Party State
## —————————————————————————————————————————————

## Enter combat state for the party
func enter_combat() -> void:
	in_combat = true
	is_resting = false


## Exit combat state
func exit_combat() -> void:
	in_combat = false


## Start resting
func start_rest() -> void:
	if not in_combat:
		is_resting = true


## Stop resting
func stop_rest() -> void:
	is_resting = false


## Disband the party
func disband() -> void:
	is_disbanded = true
	var members_copy := member_ids.duplicate()

	for member_id in members_copy:
		remove_member(member_id, &"disbanded")

	leader_id = ""

	if _lifecycle_initialized:
		party_disbanded.emit(parent_entity_id)
		emit_update_signal()


## Reform a disbanded party
func reform() -> void:
	is_disbanded = false
	_emit_change(&"is_disbanded", true, false)

#endregion

## —————————————————————————————————————————————
#region Queries
## —————————————————————————————————————————————

## Get members excluding leader
func get_non_leader_members() -> Array[String]:
	var result: Array[String] = []
	for member_id in member_ids:
		if member_id != leader_id:
			result.append(member_id)
	return result


## Check if all members satisfy a condition (via callback)
## Usage: party.all_members_satisfy(func(id): return em.get_entity_by_id(id).alive)
func all_members_satisfy(condition: Callable) -> bool:
	for member_id in member_ids:
		if not condition.call(member_id):
			return false
	return true


## Check if any member satisfies a condition
func any_member_satisfies(condition: Callable) -> bool:
	for member_id in member_ids:
		if condition.call(member_id):
			return true
	return false


## Filter members by condition
func filter_members(condition: Callable) -> Array[String]:
	var result: Array[String] = []
	for member_id in member_ids:
		if condition.call(member_id):
			result.append(member_id)
	return result

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_change(field: StringName, old_value: Variant, new_value: Variant) -> void:
	if _lifecycle_initialized:
		party_state_changed.emit(parent_entity_id, field, old_value, new_value)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	return {
		"key": get_class_name(),
		"enabled": enabled,
		"leader_id": leader_id,
		"member_ids": member_ids.duplicate(),
		"max_size": max_size,
		"formation": String(formation),
		"marching_order": marching_order.duplicate(),
		"in_combat": in_combat,
		"is_resting": is_resting,
		"is_disbanded": is_disbanded,
		"shared_gold": shared_gold,
		"use_shared_gold": use_shared_gold,
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	leader_id = data.get("leader_id", "")
	max_size = int(data.get("max_size", 4))
	formation = StringName(data.get("formation", "standard"))
	in_combat = bool(data.get("in_combat", false))
	is_resting = bool(data.get("is_resting", false))
	is_disbanded = bool(data.get("is_disbanded", false))
	shared_gold = int(data.get("shared_gold", 0))
	use_shared_gold = bool(data.get("use_shared_gold", true))

	member_ids.clear()
	for member_id in data.get("member_ids", []):
		member_ids.append(String(member_id))

	marching_order.clear()
	for member_id in data.get("marching_order", []):
		marching_order.append(String(member_id))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var status_parts: Array[String] = []
	if is_disbanded:
		status_parts.append("DISBANDED")
	if in_combat:
		status_parts.append("combat")
	if is_resting:
		status_parts.append("resting")

	var status_str := ", ".join(status_parts) if not status_parts.is_empty() else "active"
	return "PartyComponent[%s](%d/%d members, %s)" % [
	parent_entity_id, member_ids.size(), max_size, status_str
	]


func print_debug() -> void:
	print("=== PartyComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  --- Membership ---")
	print("    Leader: %s" % leader_id)
	print("    Members (%d/%d):" % [member_ids.size(), max_size])
	for i in range(member_ids.size()):
		var member_id := member_ids[i]
		var leader_marker := " [LEADER]" if member_id == leader_id else ""
		print("      [%d] %s%s" % [i, member_id, leader_marker])
	print("    Open Slots: %d" % get_open_slots())
	print("  --- Formation ---")
	print("    Type: %s" % formation)
	print("    Marching Order: %s" % marching_order)
	print("  --- State ---")
	print("    In Combat: %s" % in_combat)
	print("    Resting: %s" % is_resting)
	print("    Disbanded: %s" % is_disbanded)
	print("  --- Resources ---")
	print("    Shared Gold: %d" % shared_gold)
	print("    Use Shared Gold: %s" % use_shared_gold)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"leader_id": leader_id,
		"member_ids": member_ids.duplicate(),
		"member_count": member_ids.size(),
		"max_size": max_size,
		"open_slots": get_open_slots(),
		"is_full": is_full(),
		"is_empty": is_empty(),
		"formation": String(formation),
		"marching_order": marching_order.duplicate(),
		"front_member": get_front_member(),
		"back_member": get_back_member(),
		"in_combat": in_combat,
		"is_resting": is_resting,
		"is_disbanded": is_disbanded,
		"shared_gold": shared_gold,
	}

#endregion