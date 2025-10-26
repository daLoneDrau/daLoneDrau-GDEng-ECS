class_name GameAction


## the action's name
var name: String

## the action's type
var type: String

## any arguments supplied
var args: Variant


func _init(n: String, t: String, a: Variant = null) -> void:
	self.name = n
	self.type = t
	self.args = a


func _to_string():
	return "{} {}".format([name, type], "{}")
