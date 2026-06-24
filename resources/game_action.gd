class_name GameAction
extends Resource


const PHASE_START: String = "START"

const PHASE_END: String = "END"

## the action's name
var name: String

## the action's type
var phase: String

## any arguments supplied
var args: Variant


func _init(n: String, p: String, a: Variant = null) -> void:
	self.name = n
	self.phase = p
	self.args = a


func is_pressed() -> bool:
	return phase == PHASE_START


func is_released() -> bool:
	return phase == PHASE_END


func _to_string():
	return "{} {}".format([name, phase], "{}")
