## Tracks experience, level, and skill point progression for an entity.
## Examples: Player leveling, companion advancement, monster challenge ratings
class_name ProgressionComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when XP changes
signal xp_changed(entity_id: String, old_xp: int, new_xp: int, delta: int)

## Emitted when level changes
signal level_changed(entity_id: String, old_level: int, new_level: int)

## Emitted when skill points change
signal skill_points_changed(entity_id: String, old_points: int, new_points: int)

## Emitted when ready to level up (XP threshold reached)
signal level_up_available(entity_id: String, current_level: int, xp: int)

## Current experience points
@export var experience: int = 0:
	set(value):
		if experience != value:
			var old := experience
			experience = maxi(0, value)
			_emit_xp_change(old, experience, experience - old)

## Current level
@export var level: int = 1:
	set(value):
		if level != value:
			var old := level
			level = clampi(value, min_level, max_level)
			_emit_level_change(old, level)

## Unspent skill/attribute points
@export var skill_points: int = 0:
	set(value):
		if skill_points != value:
			var old := skill_points
			skill_points = maxi(0, value)
			_emit_skill_points_change(old, skill_points)

## —————————————————————————————————————————————
## Configuration
## —————————————————————————————————————————————

@export_group("Limits")

## Minimum level (usually 1)
@export var min_level: int = 1

## Maximum level cap (-1 = unlimited)
@export var max_level: int = -1

## —————————————————————————————————————————————
## XP Tracking
## —————————————————————————————————————————————

@export_group("XP Tracking")

## Total XP ever earned (doesn't decrease on level-up for "spend XP" systems)
@export var lifetime_xp: int = 0

## XP required for next level (set by leveling system, cached for UI)
@export var xp_for_next_level: int = 100

## XP required for current level (for progress bar calculation)
@export var xp_for_current_level: int = 0

## —————————————————————————————————————————————
## Skill Point Tracking
## —————————————————————————————————————————————

@export_group("Skill Points")

## Total skill points ever earned
@export var lifetime_skill_points: int = 0

## Skill points awarded per level (informational, system handles actual awards)
@export var skill_points_per_level: int = 1


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init(p_level: int = 1, p_experience: int = 0) -> void:
	super()
	level = p_level
	experience = p_experience
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"xp_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"level_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"skill_points_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"level_up_available",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "xp_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "level_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "skill_points_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "level_up_available")

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
#region XP Management
## —————————————————————————————————————————————

## Add experience points
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	lifetime_xp += amount
	experience += amount
	_check_level_up_available()


## Remove experience points (for "spend XP" systems)
func spend_xp(amount: int) -> bool:
	if amount > experience:
		return false
	experience -= amount
	return true


## Set XP directly (for save/load or GM override)
func set_xp(amount: int) -> void:
	experience = amount


## Get progress toward next level as percentage (0.0 to 1.0)
func get_level_progress() -> float:
	var xp_into_level := experience - xp_for_current_level
	var xp_needed := xp_for_next_level - xp_for_current_level

	if xp_needed <= 0:
		return 1.0

	return clampf(float(xp_into_level) / float(xp_needed), 0.0, 1.0)


## Get XP remaining until next level
func get_xp_to_next_level() -> int:
	return maxi(0, xp_for_next_level - experience)


## Check if enough XP to level up
func can_level_up() -> bool:
	if max_level > 0 and level >= max_level:
		return false
	return experience >= xp_for_next_level


## Check and emit level_up_available signal
func _check_level_up_available() -> void:
	if can_level_up() and _lifecycle_initialized:
		level_up_available.emit(parent_entity_id, level, experience)

#endregion

## —————————————————————————————————————————————
#region Level Management
## —————————————————————————————————————————————

## Increase level by amount (system should call this after validating XP)
func add_levels(amount: int = 1) -> void:
	if amount <= 0:
		return
	level += amount


## Set level directly (for save/load or GM override)
func set_level(new_level: int) -> void:
	level = new_level


## Check if at max level
func is_max_level() -> bool:
	return max_level > 0 and level >= max_level


## Get levels until cap (-1 if unlimited)
func get_levels_to_cap() -> int:
	if max_level <= 0:
		return -1
	return maxi(0, max_level - level)

#endregion

## —————————————————————————————————————————————
#region Skill Points Management
## —————————————————————————————————————————————

## Add skill points
func add_skill_points(amount: int) -> void:
	if amount <= 0:
		return
	lifetime_skill_points += amount
	skill_points += amount


## Spend skill points (returns true if successful)
func spend_skill_points(amount: int) -> bool:
	if amount > skill_points:
		return false
	skill_points -= amount
	return true


## Check if player has enough skill points
func has_skill_points(amount: int) -> bool:
	return skill_points >= amount


## Set skill points directly
func set_skill_points(amount: int) -> void:
	skill_points = amount

#endregion

## —————————————————————————————————————————————
#region XP Threshold Helpers (for LevelingSystem)
## —————————————————————————————————————————————

## Update XP thresholds (called by leveling system after level change)
func update_thresholds(current_level_xp: int, next_level_xp: int) -> void:
	xp_for_current_level = current_level_xp
	xp_for_next_level = next_level_xp


## Reset XP after leveling (for systems that reset XP each level)
func reset_xp_for_level() -> void:
	experience = 0
	xp_for_current_level = 0

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_xp_change(old_xp: int, new_xp: int, delta: int) -> void:
	if _lifecycle_initialized:
		xp_changed.emit(parent_entity_id, old_xp, new_xp, delta)
		emit_update_signal()


func _emit_level_change(old_level: int, new_level: int) -> void:
	if _lifecycle_initialized:
		level_changed.emit(parent_entity_id, old_level, new_level)
		emit_update_signal()


func _emit_skill_points_change(old_points: int, new_points: int) -> void:
	if _lifecycle_initialized:
		skill_points_changed.emit(parent_entity_id, old_points, new_points)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	return {
		"key": get_class_name(),
		"enabled": enabled,
		"experience": experience,
		"level": level,
		"skill_points": skill_points,
		"min_level": min_level,
		"max_level": max_level,
		"lifetime_xp": lifetime_xp,
		"lifetime_skill_points": lifetime_skill_points,
		"xp_for_current_level": xp_for_current_level,
		"xp_for_next_level": xp_for_next_level,
		"skill_points_per_level": skill_points_per_level,
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	min_level = int(data.get("min_level", 1))
	max_level = int(data.get("max_level", -1))
	level = int(data.get("level", 1))
	experience = int(data.get("experience", 0))
	skill_points = int(data.get("skill_points", 0))
	lifetime_xp = int(data.get("lifetime_xp", 0))
	lifetime_skill_points = int(data.get("lifetime_skill_points", 0))
	xp_for_current_level = int(data.get("xp_for_current_level", 0))
	xp_for_next_level = int(data.get("xp_for_next_level", 100))
	skill_points_per_level = int(data.get("skill_points_per_level", 1))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var cap_str := "/%d" % max_level if max_level > 0 else ""
	var progress := get_level_progress() * 100
	return "ProgressionComponent[%s](Lv%d%s, %d XP [%.0f%%], %d SP)" % [
	parent_entity_id, level, cap_str, experience, progress, skill_points
	]


func print_debug() -> void:
	print("=== ProgressionComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  --- Level ---")
	print("    Current: %d" % level)
	print("    Range: %d - %s" % [min_level, str(max_level) if max_level > 0 else "∞"])
	print("    At Max: %s" % is_max_level())
	print("  --- Experience ---")
	print("    Current: %d" % experience)
	print("    Lifetime: %d" % lifetime_xp)
	print("    Progress: %.1f%%" % (get_level_progress() * 100))
	print("    To Next Level: %d" % get_xp_to_next_level())
	print("    Threshold: %d / %d" % [xp_for_current_level, xp_for_next_level])
	print("    Can Level Up: %s" % can_level_up())
	print("  --- Skill Points ---")
	print("    Available: %d" % skill_points)
	print("    Lifetime: %d" % lifetime_skill_points)
	print("    Per Level: %d" % skill_points_per_level)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"level": level,
		"min_level": min_level,
		"max_level": max_level,
		"is_max_level": is_max_level(),
		"experience": experience,
		"lifetime_xp": lifetime_xp,
		"level_progress": get_level_progress(),
		"level_progress_percent": get_level_progress() * 100,
		"xp_to_next_level": get_xp_to_next_level(),
		"xp_for_current_level": xp_for_current_level,
		"xp_for_next_level": xp_for_next_level,
		"can_level_up": can_level_up(),
		"skill_points": skill_points,
		"lifetime_skill_points": lifetime_skill_points,
	}

#endregion