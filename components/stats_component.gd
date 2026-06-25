## Container component for multiple stats on an entity.
## Examples: Player stats (Skill, Stamina, Luck), NPC attributes, item properties
class_name StatsComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when any stat's value changes
## Parameters: entity_id, stat_id, old_value, new_value
signal stat_value_changed(entity_id: String, stat_id: StringName, old_value: int, new_value: int)

## Emitted when any stat's base changes
## Parameters: entity_id, stat_id, old_base, new_base
signal stat_base_changed(entity_id: String, stat_id: StringName, old_base: int, new_base: int)

## Emitted when modifiers change on any stat
## Parameters: entity_id, stat_id
signal stat_modifiers_changed(entity_id: String, stat_id: StringName)

## Emitted when a stat is added or removed
## Parameters: entity_id
signal stat_list_changed(entity_id: String)

## All stats keyed by identifier
@export var stats: Dictionary[StringName, Stat] = {}


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————


func _init() -> void:
	super()
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"stat_value_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"stat_base_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"stat_modifiers_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"stat_list_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "stat_value_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "stat_base_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "stat_modifiers_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "stat_list_changed")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)
	_connect_all_stat_signals()


func on_removed(entity: Entity, em: EntityManager) -> void:
	_disconnect_all_stat_signals()
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()


func _connect_all_stat_signals() -> void:
	for stat_id in stats:
		_connect_stat_signals(stat_id, stats[stat_id])


func _disconnect_all_stat_signals() -> void:
	for stat_id in stats:
		_disconnect_stat_signals(stat_id, stats[stat_id])


func _connect_stat_signals(stat_id: StringName, stat: Stat) -> void:
	if stat == null:
		return

	if not stat.value_changed.is_connected(_on_stat_value_changed):
		stat.value_changed.connect(_on_stat_value_changed.bind(stat_id))
	if not stat.base_changed.is_connected(_on_stat_base_changed):
		stat.base_changed.connect(_on_stat_base_changed.bind(stat_id))
	if not stat.modifiers_changed.is_connected(_on_stat_modifiers_changed):
		stat.modifiers_changed.connect(_on_stat_modifiers_changed.bind(stat_id))


func _disconnect_stat_signals(_stat_id: StringName, stat: Stat) -> void:
	if stat == null:
		return

	if stat.value_changed.is_connected(_on_stat_value_changed):
		stat.value_changed.disconnect(_on_stat_value_changed)
	if stat.base_changed.is_connected(_on_stat_base_changed):
		stat.base_changed.disconnect(_on_stat_base_changed)
	if stat.modifiers_changed.is_connected(_on_stat_modifiers_changed):
		stat.modifiers_changed.disconnect(_on_stat_modifiers_changed)


func _on_stat_value_changed(old_value: int, new_value: int, stat_id: StringName) -> void:
	stat_value_changed.emit(parent_entity_id, stat_id, old_value, new_value)
	emit_update_signal()


func _on_stat_base_changed(old_base: int, new_base: int, stat_id: StringName) -> void:
	stat_base_changed.emit(parent_entity_id, stat_id, old_base, new_base)
	emit_update_signal()


func _on_stat_modifiers_changed(stat_id: StringName) -> void:
	stat_modifiers_changed.emit(parent_entity_id, stat_id)
	emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Stat Management
## —————————————————————————————————————————————

## Add a new stat with initial base value. Returns the created Stat.
func add_stat(stat_id: StringName, initial_base: int = 0, min_val: int = 0, max_val: int = -1) -> Stat:
	if stats.has(stat_id):
		push_warning("StatsComponent: Stat '%s' already exists, updating base value" % stat_id)
		stats[stat_id].base_value = initial_base
		return stats[stat_id]

	var stat := Stat.new(initial_base)
	stat.min_value = min_val
	stat.max_value = max_val

	stats[stat_id] = stat

	if _lifecycle_initialized:
		_connect_stat_signals(stat_id, stat)

	stat_list_changed.emit(parent_entity_id)
	emit_update_signal()
	return stat


## Remove a stat entirely. Returns true if found and removed.
func remove_stat(stat_id: StringName) -> bool:
	if not stats.has(stat_id):
		return false

	var stat: Stat = stats[stat_id]
	_disconnect_stat_signals(stat_id, stat)
	stats.erase(stat_id)

	stat_list_changed.emit(parent_entity_id)
	emit_update_signal()
	return true


## Check if a stat exists
func has_stat(stat_id: StringName) -> bool:
	return stats.has(stat_id)


## Get a stat by ID. Returns null if not found.
func get_stat(stat_id: StringName) -> Stat:
	return stats.get(stat_id)


## Get all stat IDs
func get_stat_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(stats.keys())
	return ids

#endregion

## —————————————————————————————————————————————
#region Value Access (Convenience Methods)
## —————————————————————————————————————————————

## Get the total (computed) value of a stat. Returns default_value if stat doesn't exist.
func get_value(stat_id: StringName, default_value: int = 0) -> int:
	var stat := get_stat(stat_id)
	return stat.total if stat else default_value


## Get the base value of a stat. Returns default_value if stat doesn't exist.
func get_base(stat_id: StringName, default_value: int = 0) -> int:
	var stat := get_stat(stat_id)
	return stat.base_value if stat else default_value


## Set the base value of a stat. Creates the stat if it doesn't exist.
func set_base(stat_id: StringName, value: int) -> void:
	var stat := get_stat(stat_id)
	if stat:
		stat.base_value = value
	else:
		add_stat(stat_id, value)


## Adjust base value by delta (can be negative)
func adjust_base(stat_id: StringName, delta: int) -> void:
	var stat := get_stat(stat_id)
	if stat:
		stat.base_value += delta

#endregion

## —————————————————————————————————————————————
#region Modifier Management
## —————————————————————————————————————————————

## Add a modifier to a specific stat
func add_modifier(
	stat_id: StringName,
	source_id: StringName,
	amount: int,
	is_percentage: bool = false,
	stack_group: StringName = &""
) -> bool:
	var stat := get_stat(stat_id)
	if stat == null:
		push_warning("StatsComponent: Cannot add modifier, stat '%s' not found" % stat_id)
		return false

	stat.add_modifier(source_id, amount, is_percentage, stack_group)
	return true


## Add a modifier entry to a specific stat
func add_modifier_entry(stat_id: StringName, entry: StatModifierEntry) -> bool:
	var stat := get_stat(stat_id)
	if stat == null:
		push_warning("StatsComponent: Cannot add modifier entry, stat '%s' not found" % stat_id)
		return false

	stat.add_modifier_entry(entry)
	return true


## Remove a modifier from a specific stat
func remove_modifier(stat_id: StringName, source_id: StringName) -> bool:
	var stat := get_stat(stat_id)
	if stat == null:
		return false
	return stat.remove_modifier(source_id)


## Remove all modifiers from a source across ALL stats
func remove_modifiers_from_source(source_id: StringName) -> int:
	var removed := 0
	for stat in stats.values():
		if stat.remove_modifier(source_id):
			removed += 1
	return removed


## Clear all modifiers from a specific stat
func clear_modifiers(stat_id: StringName) -> void:
	var stat := get_stat(stat_id)
	if stat:
		stat.clear_modifiers()


## Clear all modifiers from ALL stats
func clear_all_modifiers() -> void:
	for stat in stats.values():
		stat.clear_modifiers()

#endregion

## —————————————————————————————————————————————
#region Bulk Operations
## —————————————————————————————————————————————

## Apply multiple modifiers at once (e.g., from an equipped item)
## modifiers: Array of { stat_id, amount, is_percentage?, stack_group? }
func apply_modifier_bundle(source_id: StringName, modifiers: Array) -> void:
	for mod in modifiers:
		var stat_id: StringName = mod.get("stat_id", &"")
		if stat_id == &"":
			continue

		add_modifier(
			stat_id,
			source_id,
			int(mod.get("amount", 0)),
			bool(mod.get("is_percentage", false)),
			StringName(mod.get("stack_group", ""))
		)


## Check if any stat has a modifier from this source
func has_modifier_from_source(source_id: StringName) -> bool:
	for stat in stats.values():
		if stat.has_modifier(source_id):
			return true
	return false


## Get all modifiers from a specific source across all stats
func get_modifiers_from_source(source_id: StringName) -> Dictionary[StringName, StatModifierEntry]:
	var result: Dictionary[StringName, StatModifierEntry] = {}
	for stat_id in stats:
		var stat: Stat = stats[stat_id]
		if stat.has_modifier(source_id):
			result[stat_id] = stat.get_modifier(source_id)
	return result

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	var stats_data: Dictionary = {}
	for stat_id in stats:
		stats_data[String(stat_id)] = stats[stat_id].to_dict()

	return {
		"key": get_class_name(),
		"enabled": enabled,
		"stats": stats_data
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	_disconnect_all_stat_signals()

	var stats_data: Dictionary = data.get("stats", {})
	stats.clear()

	for stat_id_str in stats_data:
		var stat_id := StringName(stat_id_str)
		var stat := Stat.new()
		stat.from_dict(stats_data[stat_id_str])
		stats[stat_id] = stat

	if _lifecycle_initialized:
		_connect_all_stat_signals()

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var parts: Array[String] = []
	for stat_id in stats:
		parts.append("%s: %d" % [stat_id, stats[stat_id].total])
	return "StatsComponent[%s](%s)" % [parent_entity_id, ", ".join(parts)]


func print_debug() -> void:
	print("=== StatsComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Broadcasters registered: stat_value_changed, stat_base_changed, stat_modifiers_changed, stat_list_changed")
	print("  Stats (%d):" % stats.size())
	for stat_id in stats:
		var stat: Stat = stats[stat_id]
		print("    %s: %s" % [stat_id, stat])
		var modifiers := stat.get_modifiers()
		if not modifiers.is_empty():
			for source_id in modifiers:
				print("      - %s" % modifiers[source_id])


func get_summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stat_id in stats:
		var stat: Stat = stats[stat_id]
		result.append({
			"entity_id": parent_entity_id,
			"id": stat_id,
			"base": stat.base_value,
			"total": stat.total,
			"breakdown": stat.get_breakdown()
		})
	return result

#endregion
