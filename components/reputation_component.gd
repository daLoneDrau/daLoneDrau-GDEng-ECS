## Tracks reputation/standing with multiple factions for an entity.
## Examples: Guild standings, NPC relationships, faction allegiances
class_name ReputationComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when reputation with any faction changes
signal reputation_changed(entity_id: String, faction_id: StringName, old_value: int, new_value: int, delta: int)

## Emitted when a reputation threshold is crossed
signal reputation_threshold_crossed(entity_id: String, faction_id: StringName, old_tier: StringName, new_tier: StringName)

## Emitted when a new faction is added
signal faction_added(entity_id: String, faction_id: StringName, initial_value: int)

## Emitted when a faction is removed
signal faction_removed(entity_id: String, faction_id: StringName)

## Default faction ID for single-reputation games
const DEFAULT_FACTION: StringName = &"general"

## —————————————————————————————————————————————
## Configuration
## —————————————————————————————————————————————

@export_group("Limits")

## Minimum reputation value
@export var min_reputation: int = -100

## Maximum reputation value
@export var max_reputation: int = 100

## Default starting reputation for new factions
@export var default_reputation: int = 0

## —————————————————————————————————————————————
## Reputation Tiers (for threshold system)
## —————————————————————————————————————————————

## Tier thresholds: { tier_name: minimum_value }
## Must be sorted by value ascending
## Example: { &"hated": -100, &"hostile": -50, &"unfriendly": -25, &"neutral": 0, &"friendly": 25, &"honored": 50, &"exalted": 75 }
@export var tier_thresholds: Dictionary = {
	&"hated": -100,
	&"hostile": -50,
	&"unfriendly": -25,
	&"neutral": 0,
	&"friendly": 25,
	&"honored": 50,
	&"exalted": 75,
}

## —————————————————————————————————————————————
## Internal Data
## —————————————————————————————————————————————

## Reputation values per faction: { faction_id: int }
var _reputations: Dictionary = {}  # StringName -> int

## Cached tiers per faction: { faction_id: tier_name }
var _cached_tiers: Dictionary = {}  # StringName -> StringName


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init() -> void:
	super()
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"reputation_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"reputation_threshold_crossed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"faction_added",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"faction_removed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "reputation_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "reputation_threshold_crossed")
	Switchboard_auto.remove_resource_broadcaster(self, "faction_added")
	Switchboard_auto.remove_resource_broadcaster(self, "faction_removed")

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
#region Single-Faction Convenience API
## —————————————————————————————————————————————

## Get general reputation (single-faction games)
func get_reputation() -> int:
	return get_faction_reputation(DEFAULT_FACTION)


## Set general reputation (single-faction games)
func set_reputation(value: int) -> void:
	set_faction_reputation(DEFAULT_FACTION, value)


## Add to general reputation (single-faction games)
func add_reputation(amount: int) -> void:
	add_faction_reputation(DEFAULT_FACTION, amount)


## Get general reputation tier (single-faction games)
func get_tier() -> StringName:
	return get_faction_tier(DEFAULT_FACTION)

#endregion

## —————————————————————————————————————————————
#region Multi-Faction API
## —————————————————————————————————————————————

## Get reputation with a specific faction
func get_faction_reputation(faction_id: StringName) -> int:
	if not _reputations.has(faction_id):
		return default_reputation
	return _reputations[faction_id]


## Set reputation with a specific faction
func set_faction_reputation(faction_id: StringName, value: int) -> void:
	var is_new := not _reputations.has(faction_id)
	var old_value := get_faction_reputation(faction_id)
	var clamped_value := clampi(value, min_reputation, max_reputation)

	if old_value == clamped_value and not is_new:
		return

	var old_tier := _get_tier_for_value(old_value)
	_reputations[faction_id] = clamped_value
	var new_tier := _get_tier_for_value(clamped_value)
	_cached_tiers[faction_id] = new_tier

	if is_new and _lifecycle_initialized:
		faction_added.emit(parent_entity_id, faction_id, clamped_value)

	_emit_reputation_change(faction_id, old_value, clamped_value, clamped_value - old_value)

	if old_tier != new_tier and _lifecycle_initialized:
		reputation_threshold_crossed.emit(parent_entity_id, faction_id, old_tier, new_tier)


## Add to reputation with a specific faction
func add_faction_reputation(faction_id: StringName, amount: int) -> void:
	var current := get_faction_reputation(faction_id)
	set_faction_reputation(faction_id, current + amount)


## Remove a faction entirely
func remove_faction(faction_id: StringName) -> bool:
	if not _reputations.has(faction_id):
		return false

	_reputations.erase(faction_id)
	_cached_tiers.erase(faction_id)

	if _lifecycle_initialized:
		faction_removed.emit(parent_entity_id, faction_id)

	emit_update_signal()
	return true


## Check if faction exists
func has_faction(faction_id: StringName) -> bool:
	return _reputations.has(faction_id)


## Get all known faction IDs
func get_faction_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _reputations.keys():
		result.append(key)
	return result


## Get count of known factions
func get_faction_count() -> int:
	return _reputations.size()

#endregion

## —————————————————————————————————————————————
#region Tier System
## —————————————————————————————————————————————

## Get tier name for a faction
func get_faction_tier(faction_id: StringName) -> StringName:
	if _cached_tiers.has(faction_id):
		return _cached_tiers[faction_id]

	var value := get_faction_reputation(faction_id)
	var tier := _get_tier_for_value(value)
	_cached_tiers[faction_id] = tier
	return tier


## Get tier for a specific value
func _get_tier_for_value(value: int) -> StringName:
	var result_tier: StringName = &"neutral"
	var result_threshold: int = -999999

	for tier_name in tier_thresholds:
		var threshold: int = tier_thresholds[tier_name]
		if value >= threshold and threshold > result_threshold:
			result_tier = tier_name
			result_threshold = threshold

	return result_tier


## Get progress within current tier (0.0 to 1.0)
func get_tier_progress(faction_id: StringName) -> float:
	var value := get_faction_reputation(faction_id)
	var current_tier := get_faction_tier(faction_id)
	var current_threshold: int = tier_thresholds.get(current_tier, 0)

	# Find next tier threshold
	var next_threshold: int = max_reputation
	var sorted_thresholds: Array = tier_thresholds.values()
	sorted_thresholds.sort()

	for threshold in sorted_thresholds:
		if threshold > current_threshold:
			next_threshold = threshold
			break

	var range_size := next_threshold - current_threshold
	if range_size <= 0:
		return 1.0

	return clampf(float(value - current_threshold) / float(range_size), 0.0, 1.0)


## Get value needed to reach next tier
func get_value_to_next_tier(faction_id: StringName) -> int:
	var value := get_faction_reputation(faction_id)
	var current_tier := get_faction_tier(faction_id)
	var current_threshold: int = tier_thresholds.get(current_tier, 0)

	# Find next tier threshold
	var sorted_thresholds: Array = tier_thresholds.values()
	sorted_thresholds.sort()

	for threshold in sorted_thresholds:
		if threshold > current_threshold:
			return maxi(0, threshold - value)

	return 0  # Already at max tier


## Check if faction is at or above a specific tier
func is_tier_or_higher(faction_id: StringName, tier_name: StringName) -> bool:
	var value := get_faction_reputation(faction_id)
	var tier_threshold: int = tier_thresholds.get(tier_name, 0)
	return value >= tier_threshold


## Check if faction is at or below a specific tier
func is_tier_or_lower(faction_id: StringName, tier_name: StringName) -> bool:
	var value := get_faction_reputation(faction_id)
	var tier_threshold: int = tier_thresholds.get(tier_name, 0)

	# Find the next tier above this one
	var sorted_thresholds: Array = tier_thresholds.values()
	sorted_thresholds.sort()

	var next_threshold: int = max_reputation + 1
	for threshold in sorted_thresholds:
		if threshold > tier_threshold:
			next_threshold = threshold
			break

	return value < next_threshold

#endregion

## —————————————————————————————————————————————
#region Queries
## —————————————————————————————————————————————

## Get all factions at or above a tier
func get_factions_at_tier_or_higher(tier_name: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for faction_id in _reputations.keys():
		if is_tier_or_higher(faction_id, tier_name):
			result.append(faction_id)
	return result


## Get all factions at or below a tier
func get_factions_at_tier_or_lower(tier_name: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for faction_id in _reputations.keys():
		if is_tier_or_lower(faction_id, tier_name):
			result.append(faction_id)
	return result


## Get all factions at a specific tier
func get_factions_at_tier(tier_name: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for faction_id in _reputations.keys():
		if get_faction_tier(faction_id) == tier_name:
			result.append(faction_id)
	return result


## Get highest reputation faction
func get_highest_reputation_faction() -> StringName:
	var best_faction: StringName = &""
	var best_value: int = -999999

	for faction_id in _reputations.keys():
		var value: int = _reputations[faction_id]
		if value > best_value:
			best_value = value
			best_faction = faction_id

	return best_faction


## Get lowest reputation faction
func get_lowest_reputation_faction() -> StringName:
	var worst_faction: StringName = &""
	var worst_value: int = 999999

	for faction_id in _reputations.keys():
		var value: int = _reputations[faction_id]
		if value < worst_value:
			worst_value = value
			worst_faction = faction_id

	return worst_faction


## Check if any faction is hostile (below a threshold)
func has_hostile_faction(hostile_tier: StringName = &"hostile") -> bool:
	return get_factions_at_tier_or_lower(hostile_tier).size() > 0


## Check if any faction is friendly (at or above a threshold)
func has_friendly_faction(friendly_tier: StringName = &"friendly") -> bool:
	return get_factions_at_tier_or_higher(friendly_tier).size() > 0

#endregion

## —————————————————————————————————————————————
#region Bulk Operations
## —————————————————————————————————————————————

## Set multiple faction reputations at once
func set_factions(faction_values: Dictionary) -> void:
	for faction_id in faction_values:
		set_faction_reputation(StringName(faction_id), int(faction_values[faction_id]))


## Add to multiple faction reputations at once
func add_to_factions(faction_deltas: Dictionary) -> void:
	for faction_id in faction_deltas:
		add_faction_reputation(StringName(faction_id), int(faction_deltas[faction_id]))


## Clear all faction reputations
func clear_all_factions() -> void:
	var faction_ids := get_faction_ids()
	for faction_id in faction_ids:
		remove_faction(faction_id)


## Reset all factions to default reputation
func reset_all_factions() -> void:
	for faction_id in _reputations.keys():
		set_faction_reputation(faction_id, default_reputation)

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_reputation_change(faction_id: StringName, old_value: int, new_value: int, delta: int) -> void:
	if _lifecycle_initialized:
		reputation_changed.emit(parent_entity_id, faction_id, old_value, new_value, delta)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	var reputations_data: Dictionary = {}
	for faction_id in _reputations.keys():
		reputations_data[String(faction_id)] = _reputations[faction_id]

	var tiers_data: Dictionary = {}
	for tier_name in tier_thresholds.keys():
		tiers_data[String(tier_name)] = tier_thresholds[tier_name]

	return {
		"key": get_class_name(),
		"enabled": enabled,
		"min_reputation": min_reputation,
		"max_reputation": max_reputation,
		"default_reputation": default_reputation,
		"tier_thresholds": tiers_data,
		"reputations": reputations_data,
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	min_reputation = int(data.get("min_reputation", -100))
	max_reputation = int(data.get("max_reputation", 100))
	default_reputation = int(data.get("default_reputation", 0))

	tier_thresholds.clear()
	var tiers_data: Dictionary = data.get("tier_thresholds", {})
	for tier_name in tiers_data.keys():
		tier_thresholds[StringName(tier_name)] = int(tiers_data[tier_name])

	# Restore default tiers if none provided
	if tier_thresholds.is_empty():
		tier_thresholds = {
			&"hated": -100,
			&"hostile": -50,
			&"unfriendly": -25,
			&"neutral": 0,
			&"friendly": 25,
			&"honored": 50,
			&"exalted": 75,
		}

	_reputations.clear()
	_cached_tiers.clear()
	var reputations_data: Dictionary = data.get("reputations", {})
	for faction_id in reputations_data.keys():
		var value := int(reputations_data[faction_id])
		_reputations[StringName(faction_id)] = value
		_cached_tiers[StringName(faction_id)] = _get_tier_for_value(value)

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	if _reputations.is_empty():
		return "ReputationComponent[%s](no factions)" % parent_entity_id

	var faction_strs: Array[String] = []
	for faction_id in _reputations.keys():
		var value: int = _reputations[faction_id]
		var tier := get_faction_tier(faction_id)
		faction_strs.append("%s: %d (%s)" % [faction_id, value, tier])

	return "ReputationComponent[%s](%s)" % [parent_entity_id, ", ".join(faction_strs)]


func print_debug() -> void:
	print("=== ReputationComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Range: %d to %d (default: %d)" % [min_reputation, max_reputation, default_reputation])
	print("  --- Tier Thresholds ---")

	var sorted_tiers: Array = []
	for tier_name in tier_thresholds.keys():
		sorted_tiers.append({"name": tier_name, "value": tier_thresholds[tier_name]})
	sorted_tiers.sort_custom(func(a, b): return a["value"] < b["value"])

	for tier in sorted_tiers:
		print("    %s: %d+" % [tier["name"], tier["value"]])

	print("  --- Factions (%d) ---" % _reputations.size())
	for faction_id in _reputations.keys():
		var value: int = _reputations[faction_id]
		var tier := get_faction_tier(faction_id)
		var progress := get_tier_progress(faction_id) * 100
		var to_next := get_value_to_next_tier(faction_id)
		print("    %s: %d (%s, %.0f%% to next, %d needed)" % [faction_id, value, tier, progress, to_next])


func get_summary() -> Dictionary:
	var factions_summary: Array[Dictionary] = []
	for faction_id in _reputations.keys():
		factions_summary.append({
			"faction_id": String(faction_id),
			"value": _reputations[faction_id],
			"tier": String(get_faction_tier(faction_id)),
			"tier_progress": get_tier_progress(faction_id),
			"to_next_tier": get_value_to_next_tier(faction_id),
		})

	return {
		"entity_id": parent_entity_id,
		"min_reputation": min_reputation,
		"max_reputation": max_reputation,
		"default_reputation": default_reputation,
		"faction_count": _reputations.size(),
		"factions": factions_summary,
		"highest_faction": String(get_highest_reputation_faction()),
		"lowest_faction": String(get_lowest_reputation_faction()),
		"has_hostile": has_hostile_faction(),
		"has_friendly": has_friendly_faction(),
	}

#endregion