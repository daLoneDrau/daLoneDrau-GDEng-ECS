## Stores player-specific metadata and state.
## Distinguishes player entities from NPCs, monsters, and items.
## Examples: Player index, control scheme, save slot, UI preferences
class_name PlayerComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when player state changes
signal player_state_changed(entity_id: String, field: StringName, old_value: Variant, new_value: Variant)

## Emitted when player input is enabled/disabled
signal input_enabled_changed(entity_id: String, is_enabled: bool)

## Emitted when player dies
signal player_died(entity_id: String, death_count: int)

## Emitted when player is revived/respawned
signal player_respawned(entity_id: String)

## —————————————————————————————————————————————
## Player Identity
## —————————————————————————————————————————————

## Player index for multiplayer (0 = player 1, 1 = player 2, etc.)
@export var player_index: int = 0:
	set(value):
		if player_index != value:
			var old := player_index
			player_index = value
			_emit_change(&"player_index", old, value)

## Control scheme identifier (e.g., "keyboard_wasd", "gamepad_0", "touch")
@export var control_scheme: StringName = &"keyboard":
	set(value):
		if control_scheme != value:
			var old := control_scheme
			control_scheme = value
			_emit_change(&"control_scheme", old, value)

## Whether this player can receive input
@export var input_enabled: bool = true:
	set(value):
		if input_enabled != value:
			input_enabled = value
			if _lifecycle_initialized:
				input_enabled_changed.emit(parent_entity_id, value)
			_emit_change(&"input_enabled", not value, value)

## Save/load slot associated with this player
@export var save_slot: int = -1:
	set(value):
		if save_slot != value:
			var old := save_slot
			save_slot = value
			_emit_change(&"save_slot", old, value)

## —————————————————————————————————————————————
## Session State
## —————————————————————————————————————————————

@export_group("Session")

## Is the player currently alive?
@export var is_alive: bool = true:
	set(value):
		if is_alive != value:
			var old := is_alive
			is_alive = value
			_emit_change(&"is_alive", old, value)
			if not value:
				_death_count += 1
				if _lifecycle_initialized:
					player_died.emit(parent_entity_id, _death_count)

## Is the player in a menu/dialogue (blocks gameplay input)?
@export var in_menu: bool = false:
	set(value):
		if in_menu != value:
			var old := in_menu
			in_menu = value
			_emit_change(&"in_menu", old, value)

## Is the player in a cutscene (blocks all input)?
@export var in_cutscene: bool = false:
	set(value):
		if in_cutscene != value:
			var old := in_cutscene
			in_cutscene = value
			_emit_change(&"in_cutscene", old, value)

## —————————————————————————————————————————————
## Session Tracking
## —————————————————————————————————————————————

@export_group("Tracking")

## Total play time in seconds
@export var play_time_seconds: float = 0.0

## Number of times player has died this session
var _death_count: int = 0

## Timestamp when session started (for play time tracking)
var _session_start_time: int = 0

## —————————————————————————————————————————————
## Gamebook-Specific (Fighting Fantasy)
## —————————————————————————————————————————————

@export_group("Gamebook")

## Current paragraph/section number
@export var current_paragraph: int = 1:
	set(value):
		if current_paragraph != value:
			var old := current_paragraph
			_visited_paragraphs[old] = true
			current_paragraph = value
			_emit_change(&"current_paragraph", old, value)

## Set of visited paragraph numbers
var _visited_paragraphs: Dictionary = {}  # int -> bool

## Story flags/decisions (e.g., "met_wizard", "has_key_123")
var _story_flags: Dictionary = {}  # StringName -> Variant

## Number of provisions (food/healing items) remaining
@export var provisions: int = 10:
	set(value):
		if provisions != value:
			var old := provisions
			provisions = maxi(0, value)
			_emit_change(&"provisions", old, provisions)

## Gold pieces
@export var gold: int = 0:
	set(value):
		if gold != value:
			var old := gold
			gold = maxi(0, value)
			_emit_change(&"gold", old, gold)


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init(p_player_index: int = 0) -> void:
	super()
	player_index = p_player_index
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"player_state_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"input_enabled_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"player_died",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)
	Switchboard_auto.add_resource_broadcaster(
		self,
		"player_respawned",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "player_state_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "input_enabled_changed")
	Switchboard_auto.remove_resource_broadcaster(self, "player_died")
	Switchboard_auto.remove_resource_broadcaster(self, "player_respawned")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)
	_session_start_time = Time.get_ticks_msec()


func on_removed(entity: Entity, em: EntityManager) -> void:
	_update_play_time()
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()

#endregion

## —————————————————————————————————————————————
#region State Queries
## —————————————————————————————————————————————

## Check if player can receive gameplay input
func can_receive_input() -> bool:
	return input_enabled and is_alive and not in_menu and not in_cutscene


## Check if player is in any blocking state
func is_blocked() -> bool:
	return in_menu or in_cutscene or not is_alive


## Check if this is the primary/first player
func is_primary_player() -> bool:
	return player_index == 0


## Get death count for this session
func get_death_count() -> int:
	return _death_count

#endregion

## —————————————————————————————————————————————
#region State Management
## —————————————————————————————————————————————

## Kill the player
func die() -> void:
	is_alive = false


## Revive/respawn the player
func respawn() -> void:
	is_alive = true
	if _lifecycle_initialized:
		player_respawned.emit(parent_entity_id)


## Enter menu state (pauses gameplay input)
func enter_menu() -> void:
	in_menu = true


## Exit menu state
func exit_menu() -> void:
	in_menu = false


## Enter cutscene state (blocks all input)
func enter_cutscene() -> void:
	in_cutscene = true


## Exit cutscene state
func exit_cutscene() -> void:
	in_cutscene = false


## Reset session state (for new game)
func reset_session() -> void:
	is_alive = true
	in_menu = false
	in_cutscene = false
	_death_count = 0
	_session_start_time = Time.get_ticks_msec()

#endregion

## —————————————————————————————————————————————
#region Play Time Tracking
## —————————————————————————————————————————————

## Update play time from session timer
func _update_play_time() -> void:
	if _session_start_time > 0:
		var elapsed := (Time.get_ticks_msec() - _session_start_time) / 1000.0
		play_time_seconds += elapsed
		_session_start_time = Time.get_ticks_msec()


## Get total play time as formatted string
func get_play_time_string() -> String:
	_update_play_time()
	var total_seconds := int(play_time_seconds)
	var hours := int(float(total_seconds) / 3600)
	var minutes := int(float(total_seconds % 3600) / 60)
	var seconds := total_seconds % 60

	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%d:%02d" % [minutes, seconds]


## Get play time components
func get_play_time() -> Dictionary:
	_update_play_time()
	var total_seconds := int(play_time_seconds)
	return {
		"total_seconds": total_seconds,
		"hours": int(float(total_seconds) / 3600),
		"minutes": int(float(total_seconds % 3600) / 60),
		"seconds": total_seconds % 60,
	}

#endregion

## —————————————————————————————————————————————
#region Gamebook: Paragraph Navigation
## —————————————————————————————————————————————

## Go to a specific paragraph
func goto_paragraph(paragraph: int) -> void:
	current_paragraph = paragraph


## Check if a paragraph has been visited
func has_visited(paragraph: int) -> bool:
	return _visited_paragraphs.has(paragraph)


## Get all visited paragraphs
func get_visited_paragraphs() -> Array[int]:
	var result: Array[int] = []
	for p in _visited_paragraphs.keys():
		result.append(int(p))
	return result


## Get count of visited paragraphs
func get_visited_count() -> int:
	return _visited_paragraphs.size()


## Mark a paragraph as visited without navigating to it
func mark_visited(paragraph: int) -> void:
	_visited_paragraphs[paragraph] = true


## Clear visited paragraphs (for new game)
func clear_visited() -> void:
	_visited_paragraphs.clear()

#endregion

## —————————————————————————————————————————————
#region Gamebook: Story Flags
## —————————————————————————————————————————————

## Set a story flag
func set_flag(flag: StringName, value: Variant = true) -> void:
	var old_value: Variant = _story_flags.get(flag)
	_story_flags[flag] = value
	_emit_change(&"story_flag:" + String(flag), old_value, value)


## Get a story flag value
func get_flag(flag: StringName, default: Variant = null) -> Variant:
	return _story_flags.get(flag, default)


## Check if a flag is set (and optionally equals a value)
func has_flag(flag: StringName, expected_value: Variant = null) -> bool:
	if not _story_flags.has(flag):
		return false
	if expected_value != null:
		return _story_flags[flag] == expected_value
	return true


## Remove a story flag
func clear_flag(flag: StringName) -> bool:
	return _story_flags.erase(flag)


## Get all flag names
func get_all_flags() -> Array[StringName]:
	var result: Array[StringName] = []
	for key in _story_flags.keys():
		result.append(key)
	return result


## Clear all story flags (for new game)
func clear_all_flags() -> void:
	_story_flags.clear()

#endregion

## —————————————————————————————————————————————
#region Gamebook: Provisions & Gold
## —————————————————————————————————————————————

## Use a provision to heal (returns true if successful)
## Note: in_combat check requires EntityManager lookup now
func use_provision() -> bool:
	if provisions <= 0:
		return false

	provisions -= 1
	# Note: Actual healing should be handled by the system using StatsComponent
	# Combat check should be done by the system, not here
	return true


## Add provisions
func add_provisions(amount: int) -> void:
	provisions += amount


## Check if player has provisions
func has_provisions() -> bool:
	return provisions > 0


## Add gold
func add_gold(amount: int) -> void:
	gold += amount


## Spend gold (returns true if successful)
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


## Check if player can afford something
func can_afford(amount: int) -> bool:
	return gold >= amount

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_change(field: StringName, old_value: Variant, new_value: Variant) -> void:
	if _lifecycle_initialized:
		player_state_changed.emit(parent_entity_id, field, old_value, new_value)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	_update_play_time()

	var visited_array: Array[int] = []
	for p in _visited_paragraphs.keys():
		visited_array.append(int(p))

	var flags_dict: Dictionary = {}
	for key in _story_flags.keys():
		flags_dict[String(key)] = _story_flags[key]

	return {
		"key": get_class_name(),
		"enabled": enabled,
		"player_index": player_index,
		"control_scheme": String(control_scheme),
		"input_enabled": input_enabled,
		"save_slot": save_slot,
		"is_alive": is_alive,
		"in_menu": in_menu,
		"in_cutscene": in_cutscene,
		"play_time_seconds": play_time_seconds,
		"death_count": _death_count,
		"current_paragraph": current_paragraph,
		"visited_paragraphs": visited_array,
		"story_flags": flags_dict,
		"provisions": provisions,
		"gold": gold,
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)

	player_index = int(data.get("player_index", 0))
	control_scheme = StringName(data.get("control_scheme", "keyboard"))
	input_enabled = bool(data.get("input_enabled", true))
	save_slot = int(data.get("save_slot", -1))
	is_alive = bool(data.get("is_alive", true))
	in_menu = bool(data.get("in_menu", false))
	in_cutscene = bool(data.get("in_cutscene", false))
	play_time_seconds = float(data.get("play_time_seconds", 0.0))
	_death_count = int(data.get("death_count", 0))
	current_paragraph = int(data.get("current_paragraph", 1))
	provisions = int(data.get("provisions", 10))
	gold = int(data.get("gold", 0))

	_visited_paragraphs.clear()
	for p in data.get("visited_paragraphs", []):
		_visited_paragraphs[int(p)] = true

	_story_flags.clear()
	var flags_data: Dictionary = data.get("story_flags", {})
	for key in flags_data.keys():
		_story_flags[StringName(key)] = flags_data[key]

	_session_start_time = Time.get_ticks_msec()

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var state_parts: Array[String] = []
	if not is_alive:
		state_parts.append("DEAD")
	if in_menu:
		state_parts.append("menu")
	if in_cutscene:
		state_parts.append("cutscene")

	var state_str := ", ".join(state_parts) if not state_parts.is_empty() else "active"
	return "PlayerComponent[%s](P%d, %s, §%d)" % [parent_entity_id, player_index + 1, state_str, current_paragraph]


func print_debug() -> void:
	print("=== PlayerComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Player Index: %d (P%d)" % [player_index, player_index + 1])
	print("  Control Scheme: %s" % control_scheme)
	print("  Input Enabled: %s" % input_enabled)
	print("  Can Receive Input: %s" % can_receive_input())
	print("  Save Slot: %s" % (str(save_slot) if save_slot >= 0 else "None"))
	print("  --- State ---")
	print("    Alive: %s" % is_alive)
	print("    In Menu: %s" % in_menu)
	print("    In Cutscene: %s" % in_cutscene)
	print("  --- Progression ---")
	print("    Play Time: %s" % get_play_time_string())
	print("    Deaths: %d" % _death_count)
	print("  --- Gamebook ---")
	print("    Current Paragraph: %d" % current_paragraph)
	print("    Visited Paragraphs: %d" % get_visited_count())
	print("    Story Flags: %d" % _story_flags.size())
	print("    Provisions: %d" % provisions)
	print("    Gold: %d" % gold)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"player_index": player_index,
		"player_number": player_index + 1,
		"control_scheme": String(control_scheme),
		"input_enabled": input_enabled,
		"can_receive_input": can_receive_input(),
		"save_slot": save_slot,
		"is_alive": is_alive,
		"in_menu": in_menu,
		"in_cutscene": in_cutscene,
		"is_blocked": is_blocked(),
		"play_time": get_play_time(),
		"play_time_string": get_play_time_string(),
		"death_count": _death_count,
		"current_paragraph": current_paragraph,
		"visited_count": get_visited_count(),
		"flag_count": _story_flags.size(),
		"provisions": provisions,
		"gold": gold,
	}

#endregion