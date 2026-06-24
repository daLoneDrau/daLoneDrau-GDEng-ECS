## Tracks an entity's membership in a party.
## Attached to players, companions, NPCs who are party members.
## References the party entity rather than duplicating party data.
class_name PartyMembershipComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when party membership changes
signal joined_party(entity_id: String, party_entity_id: String)
signal left_party(entity_id: String, party_entity_id: String, reason: StringName)
signal party_role_changed(entity_id: String, field: StringName, old_value: Variant, new_value: Variant)

## Entity ID of the party this member belongs to
@export var party_entity_id: String = "":
	set(value):
		if party_entity_id != value:
			var old := party_entity_id
			party_entity_id = value
			if _lifecycle_initialized:
				if old.is_empty() and not value.is_empty():
					joined_party.emit(parent_entity_id, value)
				elif not old.is_empty() and value.is_empty():
					left_party.emit(parent_entity_id, old, &"removed")
				_emit_change(&"party_entity_id", old, value)

## Slot/position in the party (0 = first slot, usually leader position)
@export var party_slot: int = 0:
	set(value):
		if party_slot != value:
			var old := party_slot
			party_slot = maxi(0, value)
			_emit_change(&"party_slot", old, party_slot)

## Role within the party (e.g., "tank", "healer", "scout", "leader")
@export var party_role: StringName = &"":
	set(value):
		if party_role != value:
			var old := party_role
			party_role = value
			_emit_change(&"party_role", old, value)

## Position in marching order (separate from slot, for travel/exploration)
@export var marching_position: int = 0:
	set(value):
		if marching_position != value:
			var old := marching_position
			marching_position = maxi(0, value)
			_emit_change(&"marching_position", old, marching_position)

## When this member joined the party (for ordering, seniority)
@export var joined_at: int = 0

## Whether this member is temporarily away (e.g., captured, separated)
@export var is_away: bool = false:
	set(value):
		if is_away != value:
			var old := is_away
			is_away = value
			_emit_change(&"is_away", old, value)

## Reason for being away (if is_away is true)
@export var away_reason: StringName = &""


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init() -> void:
	super()
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"joined_party",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"left_party",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"party_role_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "joined_party")
	Switchboard_auto.remove_resource_broadcaster(self, "left_party")
	Switchboard_auto.remove_resource_broadcaster(self, "party_role_changed")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)


func on_removed(entity: Entity, em: EntityManager) -> void:
	# Notify that we're leaving the party
	if not party_entity_id.is_empty() and _lifecycle_initialized:
		left_party.emit(parent_entity_id, party_entity_id, &"component_removed")
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()

#endregion

## —————————————————————————————————————————————
#region Membership Queries
## —————————————————————————————————————————————

## Check if this entity is in a party
func is_in_party() -> bool:
	return not party_entity_id.is_empty()


## Check if this entity is in a specific party
func is_in_party_with_id(check_party_id: String) -> bool:
	return party_entity_id == check_party_id


## Check if this entity is the party leader
## Requires EntityManager to look up the party entity
func is_party_leader(em: EntityManager) -> bool:
	if party_entity_id.is_empty():
		return false

	var party_entity := em.get_entity_by_id(party_entity_id)
	if party_entity == null:
		return false

	var party_comp: PartyComponent = party_entity.get_component(&"PartyComponent") as PartyComponent
	if party_comp == null:
		return false

	return party_comp.is_leader(parent_entity_id)


## Get the party entity (requires EntityManager)
func get_party_entity(em: EntityManager) -> Entity:
	if party_entity_id.is_empty():
		return null
	return em.get_entity_by_id(party_entity_id)


## Get the PartyComponent from the party entity (requires EntityManager)
func get_party_component(em: EntityManager) -> PartyComponent:
	var party_entity := get_party_entity(em)
	if party_entity == null:
		return null
	return party_entity.get_component(&"PartyComponent") as PartyComponent


## Check if available (in party and not away)
func is_available() -> bool:
	return is_in_party() and not is_away

#endregion

## —————————————————————————————————————————————
#region Membership Management
## —————————————————————————————————————————————

## Join a party
func join_party(new_party_id: String, slot: int = -1, role: StringName = &"") -> void:
	party_entity_id = new_party_id
	if slot >= 0:
		party_slot = slot
	if role != &"":
		party_role = role
	joined_at = Time.get_ticks_msec()
	is_away = false
	away_reason = &""


## Leave the current party
func leave_party(reason: StringName = &"left") -> void:
	if party_entity_id.is_empty():
		return

	var old_party := party_entity_id
	party_entity_id = ""
	party_slot = 0
	party_role = &""
	marching_position = 0
	is_away = false
	away_reason = &""

	if _lifecycle_initialized:
		left_party.emit(parent_entity_id, old_party, reason)


## Mark member as temporarily away
func set_away(reason: StringName = &"separated") -> void:
	is_away = true
	away_reason = reason


## Mark member as returned/available
func set_returned() -> void:
	is_away = false
	away_reason = &""


## Set role within party
func set_role(role: StringName) -> void:
	party_role = role

#endregion

## —————————————————————————————————————————————
#region Convenience Methods (require EntityManager)
## —————————————————————————————————————————————

## Get all other party members' IDs (excluding self)
func get_other_member_ids(em: EntityManager) -> Array[String]:
	var party_comp := get_party_component(em)
	if party_comp == null:
		return []

	var result: Array[String] = []
	for member_id in party_comp.member_ids:
		if member_id != parent_entity_id:
			result.append(member_id)
	return result


## Get party leader's ID
func get_leader_id(em: EntityManager) -> String:
	var party_comp := get_party_component(em)
	if party_comp == null:
		return ""
	return party_comp.leader_id


## Get party size
func get_party_size(em: EntityManager) -> int:
	var party_comp := get_party_component(em)
	if party_comp == null:
		return 0
	return party_comp.get_member_count()


## Check if party is in combat
func is_party_in_combat(em: EntityManager) -> bool:
	var party_comp := get_party_component(em)
	if party_comp == null:
		return false
	return party_comp.in_combat

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_change(field: StringName, old_value: Variant, new_value: Variant) -> void:
	if _lifecycle_initialized:
		party_role_changed.emit(parent_entity_id, field, old_value, new_value)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	return {
		"key": get_class_name(),
		"enabled": enabled,
		"party_entity_id": party_entity_id,
		"party_slot": party_slot,
		"party_role": String(party_role),
		"marching_position": marching_position,
		"joined_at": joined_at,
		"is_away": is_away,
		"away_reason": String(away_reason),
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	party_entity_id = data.get("party_entity_id", "")
	party_slot = int(data.get("party_slot", 0))
	party_role = StringName(data.get("party_role", ""))
	marching_position = int(data.get("marching_position", 0))
	joined_at = int(data.get("joined_at", 0))
	is_away = bool(data.get("is_away", false))
	away_reason = StringName(data.get("away_reason", ""))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	if party_entity_id.is_empty():
		return "PartyMembershipComponent[%s](no party)" % parent_entity_id

	var status_parts: Array[String] = []
	if is_away:
		status_parts.append("AWAY: %s" % away_reason)
	if party_role != &"":
		status_parts.append(String(party_role))

	var status_str := ", ".join(status_parts) if not status_parts.is_empty() else "active"
	return "PartyMembershipComponent[%s](party=%s, slot=%d, %s)" % [
	parent_entity_id, party_entity_id, party_slot, status_str
	]


func print_debug() -> void:
	print("=== PartyMembershipComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  --- Membership ---")
	print("    Party Entity: %s" % (party_entity_id if not party_entity_id.is_empty() else "(none)"))
	print("    Party Slot: %d" % party_slot)
	print("    Party Role: %s" % (String(party_role) if party_role != &"" else "(none)"))
	print("    Marching Position: %d" % marching_position)
	print("  --- Status ---")
	print("    In Party: %s" % is_in_party())
	print("    Is Away: %s" % is_away)
	if is_away:
		print("    Away Reason: %s" % away_reason)
	print("    Joined At: %d" % joined_at)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"party_entity_id": party_entity_id,
		"is_in_party": is_in_party(),
		"party_slot": party_slot,
		"party_role": String(party_role),
		"marching_position": marching_position,
		"is_away": is_away,
		"away_reason": String(away_reason),
		"is_available": is_available(),
		"joined_at": joined_at,
	}

#endregion