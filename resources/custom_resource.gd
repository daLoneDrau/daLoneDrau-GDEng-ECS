@abstract class_name CustomResource
extends Resource


var _cached_class_name: String = ""


## Check if a script class is marked as a slot root.
static func _script_is_slot_root(script: Script) -> bool:
	if script == null:
		return false
	var constants: Dictionary = script.get_script_constant_map()
	return constants.get("IS_SLOT_ROOT", false) == true


func _compute_class_name() -> String:
	var script_instance: Script = get_script()
	if not script_instance:
		return get_class()

	# Walk up the inheritance chain looking for a slot root
	var current_script: Script = script_instance
	var slot_root_name: String = ""

	while current_script:
		var current_name: String = current_script.get_global_name()

		# Stop if we've reached EntityComponent (don't go higher)
		if current_name == "EntityComponent":
			break

		# Check if this level is a slot root
		if _script_is_slot_root(current_script):
			slot_root_name = current_name
			break  # Found the slot root

		current_script = current_script.get_base_script()

	# Return slot root if found, otherwise this class's name
	if slot_root_name != "":
		return slot_root_name

	return script_instance.get_global_name()


## Returns the actual class name of this instance (ignoring slot roots).
func get_actual_class_name() -> String:
	var script_instance: Script = get_script()
	if script_instance:
		return script_instance.get_global_name()
	return get_class()


## Gets the component slot name for this resource.
## For slot roots and their descendants, returns the slot root's class name.
## Otherwise returns this class's global name.
func get_class_name() -> String:
	if _cached_class_name.is_empty():
		_cached_class_name = _compute_class_name()
	return _cached_class_name


## Returns the full inheritance chain as an array of class names.
## Index 0 is this class, last index is the highest ancestor before Resource.
func get_inheritance_chain() -> Array[String]:
	var chain: Array[String] = []
	var current_script: Script = get_script()

	while current_script:
		var current_name: String = current_script.get_global_name()
		if current_name.is_empty():
			current_name = "(anonymous)"
		chain.append(current_name)
		current_script = current_script.get_base_script()

	return chain


## Returns inheritance info as a dictionary for debugging.
## Includes: actual_class, slot_name, chain, slot_root_index
func get_inheritance_info() -> Dictionary:
	var chain: Array[String] = get_inheritance_chain()
	var slot_name: String = get_class_name()
	var actual_name: String = get_actual_class_name()

	# Find which index in chain is the slot root
	var slot_root_index: int = -1
	var current_script: Script = get_script()
	var index: int = 0

	while current_script:
		if _script_is_slot_root(current_script):
			slot_root_index = index
			break
		if current_script.get_global_name() == "EntityComponent":
			break
		current_script = current_script.get_base_script()
		index += 1

	return {
		"actual_class": actual_name,
		"slot_name": slot_name,
		"inheritance_chain": chain,
		"slot_root_index": slot_root_index,
		"is_slot_root": slot_root_index == 0,
	}


## Prints a formatted debug view of the inheritance chain.
## Marks slot roots with [SLOT ROOT] indicator.
func print_inheritance_debug() -> void:
	var info: Dictionary = get_inheritance_info()
	var chain: Array[String] = info["inheritance_chain"]

	print("=== Inheritance Debug: %s ===" % info["actual_class"])
	print("  Slot name: %s" % info["slot_name"])
	print("  Chain:")

	var current_script: Script = get_script()
	for i in range(chain.size()):
		var indent: String = "    " + "  ".repeat(i)
		var marker: String = ""

		if current_script and _script_is_slot_root(current_script):
			marker = " [SLOT ROOT]"

		print("%s%s%s" % [indent, chain[i], marker])

		if current_script:
			current_script = current_script.get_base_script()

	print("")


## Validates the slot root configuration and returns any issues found.
## Useful for unit tests or editor validation.
func validate_slot_config() -> Array[String]:
	var issues: Array[String] = []
	var current_script: Script = get_script()
	var slot_roots_found: Array[String] = []

	# Check for multiple slot roots in chain (probably a mistake)
	while current_script:
		var current_name: String = current_script.get_global_name()

		if current_name == "EntityComponent":
			break

		if _script_is_slot_root(current_script):
			slot_roots_found.append(current_name)

		current_script = current_script.get_base_script()

	if slot_roots_found.size() > 1:
		issues.append(
			"Multiple slot roots found in chain: %s. Only the lowest will be used: %s" % [slot_roots_found, slot_roots_found[0]]
		)

	if slot_roots_found.is_empty() and self is EntityComponent:
		issues.append(
			"Class '%s' looks like a component but has no slot root in its hierarchy. Consider adding 'const IS_SLOT_ROOT: bool = true' to the base component class." % get_actual_class_name()
		)

	return issues


## Static helper to validate a component class before instantiation.
## Pass the script/class directly: CustomResource.validate_component_class(WeaponItemComponent)
static func validate_component_class(script: Script) -> Array[String]:
	if script == null:
		return ["Script is null"]

	var temp_instance: Resource = script.new()
	if temp_instance is CustomResource:
		var issues: Array[String] = (temp_instance as CustomResource).validate_slot_config()
		return issues

	return ["Script does not extend CustomResource"]