class_name ScriptVariableSet
extends EntityComponent


## the set of variables.
@export var variable_set: Dictionary = {}


## Adds a new variable to the set.
func add_variable(name: String, obj,  overridePrevious: bool = false) -> void:
	if variable_set.has(name):
		if overridePrevious:
			variable_set[name].set_variable(obj)
		else:
			push_error("ScriptVariableSet.add_variable() - variable already exists and is not overriden. Use set_variable()")
	else:
		var variable: ScriptVariable = ScriptVariable.new()
		variable.set_variable(obj)
		variable_set[name] = variable


## clears the set
func clear() -> void:
	variable_set.clear()


func get_variable(name: String) -> ScriptVariable:
	return variable_set.get(name, null)


## Determines if a variable by a specific name was set.
func has(name: String) -> bool: return name in variable_set


## Removes a variable
func remove(key: String) -> void: variable_set.erase(key)


## Sets a script variable's value.
func set_variable(name: String, obj: Variant) -> void:
	if variable_set.has(name):
		variable_set[name].set_variable(obj)
	else:
		var variable: ScriptVariable = ScriptVariable.new()
		variable.set_variable(obj)
		variable_set[name] = variable


## Gets the variable's value.
func value(name: String, default: Variant = null) -> Variant:
	if not variable_set.has(name):
		return default
	return variable_set[name].value


## Serializes the set to a dictionary.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for k in variable_set.keys():
		var sv: ScriptVariable = variable_set[k]
		if sv != null and sv.has_method("to_dict"):
			out[k] = sv.to_dict()
	return out


## Restores the set from a dictionary.
func from_dict(data: Dictionary) -> void:
	variable_set.clear()
	for k in data.keys():
		var sv := ScriptVariable.new()
		if typeof(data[k]) == TYPE_DICTIONARY and sv.has_method("from_dict"):
			sv.from_dict(data[k])
		else:
			# Fallback: store raw value if a plain value was provided
			sv.set_variable(data[k])
		variable_set[k] = sv


## Overlays values from a dictionary without clearing the set.
## - If `override` is false, existing entries are preserved.
## - Each value can be either:
##     • a Dictionary produced by ScriptVariable.to_dict()
##     • a raw Variant value (we'll call set_variable on it)
func merge_from_dict(data: Dictionary, override: bool = true) -> void:
	for k in data.keys():
		var exists := variable_set.has(k)
		if not exists:
			var sv := ScriptVariable.new()
			if typeof(data[k]) == TYPE_DICTIONARY and sv.has_method("from_dict"):
				sv.from_dict(data[k])
			else:
				sv.set_variable(data[k])
			variable_set[k] = sv
		else:
			if not override:
				continue
			var sv: ScriptVariable = variable_set[k]
			if typeof(data[k]) == TYPE_DICTIONARY and sv.has_method("from_dict"):
				sv.from_dict(data[k])
			else:
				sv.set_variable(data[k])

