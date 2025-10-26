class_name ScriptVariable
extends CustomResource


## Type enum from GlobalUtils.ScriptVariableType
@export var type: int

@export var text_val: String = ""
@export var text_arr_val: Array[String] = []
@export var float_val: float = 0.0
@export var float_arr_val: Array[float] = []
@export var int_val: int = 0
@export var int_arr_val: Array[int] = []
@export var bool_val: bool = false
@export var bool_arr_val: Array[bool] = []
@export var dictionary_val: Dictionary = {}

## Unified accessor
var value:
	get:
		match type:
			GlobalUtils.ScriptVariableType.TEXT:       return text_val
			GlobalUtils.ScriptVariableType.TEXT_ARR:   return text_arr_val
			GlobalUtils.ScriptVariableType.FLOAT:      return float_val
			GlobalUtils.ScriptVariableType.FLOAT_ARR:  return float_arr_val
			GlobalUtils.ScriptVariableType.INT:        return int_val
			GlobalUtils.ScriptVariableType.INT_ARR:    return int_arr_val
			GlobalUtils.ScriptVariableType.BOOL:       return bool_val
			GlobalUtils.ScriptVariableType.BOOL_ARR:   return bool_arr_val
			GlobalUtils.ScriptVariableType.DICTIONARY: return dictionary_val
			_: return null
	set(v):
		set_variable(v)


## Clears up member fields, releasing their memory.
func clear() -> void:
	type = -1
	text_val = ""
	text_arr_val.clear()
	float_val = 0.0
	float_arr_val.clear()
	int_val = 0
	int_arr_val.clear()
	bool_val = false
	bool_arr_val.clear()
	dictionary_val.clear()


## Sets the variable's value.
func set_variable(o) -> void:
	if o == null:
		push_error("ScriptVariable.set_variable() - parameter is null.")
		return

	if o is float:
		type = GlobalUtils.ScriptVariableType.FLOAT
		float_val = o
	elif o is Array and o.is_typed() and o.get_typed_class_name() == "" and o.get_typed_builtin() == TYPE_FLOAT:
		type = GlobalUtils.ScriptVariableType.FLOAT_ARR
		float_arr_val = o
	elif o is int:
		type = GlobalUtils.ScriptVariableType.INT
		int_val = o
	elif o is Array and o.is_typed() and o.get_typed_class_name() == "" and o.get_typed_builtin() == TYPE_INT:
		type = GlobalUtils.ScriptVariableType.INT_ARR
		int_arr_val = o
	elif o is String:
		type = GlobalUtils.ScriptVariableType.TEXT
		text_val = o
	elif o is Array and o.is_typed() and o.get_typed_class_name() == "" and o.get_typed_builtin() == TYPE_STRING:
		type = GlobalUtils.ScriptVariableType.TEXT_ARR
		text_arr_val = o
	elif o is bool:
		type = GlobalUtils.ScriptVariableType.BOOL
		bool_val = o
	elif o is Array and o.is_typed() and o.get_typed_class_name() == "" and o.get_typed_builtin() == TYPE_BOOL:
		type = GlobalUtils.ScriptVariableType.BOOL_ARR
		bool_arr_val = o
	elif o is Dictionary:
		type = GlobalUtils.ScriptVariableType.DICTIONARY
		dictionary_val = o
	else:
		push_error("ScriptVariable.set_variable() - unrecognized type: %s" % typeof(o))

## Optional: persistence helpers
func to_dict() -> Dictionary:
	return {
		"type": type,
		"text_val": text_val,
		"text_arr_val": text_arr_val,
		"float_val": float_val,
		"float_arr_val": float_arr_val,
		"int_val": int_val,
		"int_arr_val": int_arr_val,
		"bool_val": bool_val,
		"bool_arr_val": bool_arr_val,
		"dictionary_val": dictionary_val,
	}

func from_dict(d: Dictionary) -> void:
	type = int(d.get("type", type))
	text_val = d.get("text_val", text_val)
	text_arr_val = d.get("text_arr_val", text_arr_val)
	float_val = float(d.get("float_val", float_val))
	float_arr_val = d.get("float_arr_val", float_arr_val)
	int_val = int(d.get("int_val", int_val))
	int_arr_val = d.get("int_arr_val", int_arr_val)
	bool_val = bool(d.get("bool_val", bool_val))
	bool_arr_val = d.get("bool_arr_val", bool_arr_val)
	dictionary_val = d.get("dictionary_val", dictionary_val)
