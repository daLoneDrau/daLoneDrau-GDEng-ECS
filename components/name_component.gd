## Stores name and identity information for an entity.
## Examples: Player name, monster names, item names, NPC names with titles
class_name NameComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when any name field changes
signal name_changed(entity_id: String, field: StringName, old_value: String, new_value: String)

## The primary display name (e.g., "Dorian", "Goblin", "Sword of Fire")
@export var display_name: String = "":
	set(value):
		if display_name != value:
			var old := display_name
			display_name = value
			_emit_change(&"display_name", old, value)

## Optional title prefix (e.g., "Sir", "Lord", "The")
@export var title: String = "":
	set(value):
		if title != value:
			var old := title
			title = value
			_emit_change(&"title", old, value)

## Optional suffix/epithet (e.g., "the Brave", "of Firetop Mountain", "III")
@export var suffix: String = "":
	set(value):
		if suffix != value:
			var old := suffix
			suffix = value
			_emit_change(&"suffix", old, value)

## Short name for UI elements with limited space (e.g., "Dorian", "Gob.")
@export var short_name: String = "":
	set(value):
		if short_name != value:
			var old := short_name
			short_name = value
			_emit_change(&"short_name", old, value)

## Internal/technical identifier (e.g., "player_1", "goblin_warrior_03")
@export var internal_id: StringName = &""

## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————


func _init(p_display_name: String = "", p_title: String = "", p_suffix: String = "") -> void:
	super()
	# Use backing fields to avoid signal emission during init
	display_name = p_display_name
	title = p_title
	suffix = p_suffix
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"name_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "name_changed")

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
#region Name Access
## —————————————————————————————————————————————

## Returns the full formatted name with title and suffix.
## Example: "Sir Dorian the Brave"
func get_full_name() -> String:
	var parts: Array[String] = []

	if not title.is_empty():
		parts.append(title)

	if not display_name.is_empty():
		parts.append(display_name)

	if not suffix.is_empty():
		parts.append(suffix)

	return " ".join(parts)


## Returns the display name, or short name if display is empty.
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not short_name.is_empty():
		return short_name
	return "[Unnamed]"


## Returns the short name, falling back to display name if not set.
func get_short_name() -> String:
	if not short_name.is_empty():
		return short_name
	if not display_name.is_empty():
		return display_name
	return "[?]"


## Returns name with title but no suffix.
## Example: "Sir Dorian"
func get_titled_name() -> String:
	if title.is_empty():
		return get_display_name()
	return "%s %s" % [title, get_display_name()]


## Check if entity has a proper name set
func has_name() -> bool:
	return not display_name.is_empty()


## Check if entity has a title
func has_title() -> bool:
	return not title.is_empty()


## Check if entity has a suffix/epithet
func has_suffix() -> bool:
	return not suffix.is_empty()

#endregion

## —————————————————————————————————————————————
#region Convenience Setters
## —————————————————————————————————————————————

## Set all name fields at once
func set_full_name(p_display_name: String, p_title: String = "", p_suffix: String = "") -> void:
	title = p_title
	display_name = p_display_name
	suffix = p_suffix


## Set display and short name together (short defaults to display if empty)
func set_names(p_display_name: String, p_short_name: String = "") -> void:
	display_name = p_display_name
	short_name = p_short_name


## Clear all name fields
func clear() -> void:
	title = ""
	display_name = ""
	suffix = ""
	short_name = ""
	internal_id = &""

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_change(field: StringName, old_value: String, new_value: String) -> void:
	if _lifecycle_initialized:
		name_changed.emit(parent_entity_id, field, old_value, new_value)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	return {
		"key": get_class_name(),
		"enabled": enabled,
		"display_name": display_name,
		"title": title,
		"suffix": suffix,
		"short_name": short_name,
		"internal_id": String(internal_id),
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	display_name = data.get("display_name", "")
	title = data.get("title", "")
	suffix = data.get("suffix", "")
	short_name = data.get("short_name", "")
	internal_id = StringName(data.get("internal_id", ""))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var name_str := get_full_name()
	if name_str.is_empty():
		name_str = "[Unnamed]"
	return "NameComponent[%s](%s)" % [parent_entity_id, name_str]


func print_debug() -> void:
	print("=== NameComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Display Name: '%s'" % display_name)
	print("  Title: '%s'" % title)
	print("  Suffix: '%s'" % suffix)
	print("  Short Name: '%s'" % short_name)
	print("  Internal ID: '%s'" % internal_id)
	print("  Full Name: '%s'" % get_full_name())


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"display_name": display_name,
		"title": title,
		"suffix": suffix,
		"short_name": short_name,
		"internal_id": String(internal_id),
		"full_name": get_full_name(),
	}

#endregion