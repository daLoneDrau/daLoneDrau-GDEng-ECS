class_name ExecutionNode
extends BehaviourTreeNode


enum Category {
	ACTION, CONDITION
}

var category: int

## flag indicating whether debugging is turned on
var debugging_on: bool = false


func _init(my_category: int) -> void:
	category = my_category


## Executes the execution node.
func execute(_e: Entity) -> int:
	var response: int = ControlFlowNode.Response.FAILURE
	push_error(self.get_name() + ".execute() was left undefined")
	assert(false, self.get_name() + ".execute() was left undefined!")

	return response
