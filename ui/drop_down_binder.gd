# res://ecs/ui/DropdownBinder.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Bind an OptionButton to one of your ECS enum classes
## using EnumUtils for all enum operations (values, labels, keys).
##
## Requirements on enum_class:
##   - enum_values()
##   - display_name(value)
##   - to_string(value)   (optional but recommended)
##
## Usage:
##   DropdownBinder.bind(option_button, Race, initial_value, player_component, "race", "Select race…")
##   var value := DropdownBinder.get_value(option_button)                # -> int
##   DropdownBinder.set_value(option_button, Race.Enum.ELF)              # updates UI (+ bound property)
##   DropdownBinder.refresh_labels(option_button)                        # re-localize after language swap
##   DropdownBinder.sync_from_target(option_button)                      # pull from bound property
##
## Notes:
## - Stores mapping & bindings in OptionButton metadata ("enum_binder").
## - If target & prop are provided, selection writes to the property automatically.
## - Safe to call bind() repeatedly; it will re-populate and re-select.
class_name DropdownBinder


const META_KEY := "enum_binder"

## —————————————————————————————————————————————
#region Public API
## —————————————————————————————————————————————


static func bind(
	ob: OptionButton,
	enum_class: Object,
	initial_value: int = -1,
	target: Object = null,
	prop: String = "",
	placeholder: String = ""
) -> void:
	if enum_class == null:
		push_warning("DropdownBinder.bind(): enum_class is null.")
		return

	# Pull values & labels via EnumUtils
	var values: Array[int] = EnumUtils.get_values(enum_class)
	var has_values := values.size() > 0

	ob.clear()
	var map_index_to_value: Dictionary = {}
	var has_placeholder := placeholder.strip_edges() != ""

	if has_placeholder:
		ob.add_item(placeholder)
		map_index_to_value[0] = -1

	var start_index := 1 if has_placeholder else 0
	for i in range(values.size()):
		var v: int = int(values[i])
		var label: String = EnumUtils.display_name_safe(enum_class, v)
		ob.add_item(label)
		map_index_to_value[start_index + i] = v

	# Save binding metadata
	var meta := {
					"enum_class": enum_class,
					"map": map_index_to_value,
					"target": target,
					"prop": prop,
				}
	ob.set_meta(META_KEY, meta)

	# Ensure signal connection (avoid duplicates)
	_connect_once(ob)

	# Decide selection
	var selected_idx := _find_index_for_value(ob, initial_value)
	if selected_idx == -1 and is_instance_valid(target) and prop != "" and target.has_method("get"):
		selected_idx = _find_index_for_value(ob, int(target.get(prop)))

	if selected_idx == -1:
		selected_idx = 0 if has_placeholder else (start_index if has_values else -1)

	if selected_idx >= 0:
		ob.select(selected_idx)
		_write_to_target(ob, _value_from_index(ob, selected_idx))

static func get_value(ob: OptionButton) -> int:
	var idx := ob.get_selected_id() if _has_custom_ids(ob) else ob.get_selected()
	return _value_from_index(ob, idx)

static func set_value(ob: OptionButton, enum_value: int) -> void:
	var idx := _find_index_for_value(ob, enum_value)
	if idx >= 0:
		ob.select(idx)
		_write_to_target(ob, enum_value)

static func refresh_labels(ob: OptionButton) -> void:
	# Re-pull labels via EnumUtils (useful after locale change)
	var meta := _get_meta(ob)
	if meta.is_empty(): return
	var enum_class: Object = meta["enum_class"]
	if enum_class == null: return
	var map: Dictionary = meta["map"]

	for idx in map.keys():
		var v: int = map[idx]
		if v == -1:
			# Placeholder: keep its current text
			continue
		ob.set_item_text(idx, EnumUtils.display_name_safe(enum_class, v))

static func sync_from_target(ob: OptionButton) -> void:
	var meta := _get_meta(ob)
	if meta.is_empty(): return
	var target: Object = meta["target"]
	var prop: String = meta["prop"]
	if not is_instance_valid(target) or prop == "": return
	var val := int(target.get(prop))
	set_value(ob, val)
	
#endregion

## —————————————————————————————————————————————
#region Internal handlers
## —————————————————————————————————————————————


static func _on_item_selected(_unused_index: int, ob: OptionButton) -> void:
	var value := get_value(ob)
	_write_to_target(ob, value)

#endregion

## —————————————————————————————————————————————
#region Helpers
## —————————————————————————————————————————————


static func _get_meta(ob: OptionButton) -> Dictionary:
	if ob.has_meta(META_KEY):
		var meta = ob.get_meta(META_KEY)
		return meta if typeof(meta) == TYPE_DICTIONARY else {}
	return {}


static func _connect_once(ob: OptionButton) -> void:
	# Avoid duplicate connections in case bind() is called multiple times
	for c in ob.get_signal_connection_list("item_selected"):
		if c.callable.get_object() == DropdownBinder and c.callable.get_method() == "_on_item_selected":
			return
	ob.connect("item_selected", Callable(DropdownBinder, "_on_item_selected").bind(ob))


static func _value_from_index(ob: OptionButton, idx: int) -> int:
	var meta := _get_meta(ob)
	if meta.is_empty(): return -1
	var map: Dictionary = meta["map"]
	return int(map.get(idx, -1))


static func _find_index_for_value(ob: OptionButton, enum_value: int) -> int:
	if enum_value == null: return -1
	var meta := _get_meta(ob)
	if meta.is_empty(): return -1
	var map: Dictionary = meta["map"]
	for idx in map.keys():
		if int(map[idx]) == int(enum_value):
			return int(idx)
	return -1


static func _write_to_target(ob: OptionButton, value: int) -> void:
	var meta := _get_meta(ob)
	if meta.is_empty(): return
	var target: Object = meta["target"]
	var prop: String = meta["prop"]
	if is_instance_valid(target) and prop != "" and target.has_method("set"):
		target.set(prop, value)


static func _has_custom_ids(ob: OptionButton) -> bool:
	for i in range(ob.item_count):
		if ob.get_item_id(i) != i:
			return true
	return false

#endregion
