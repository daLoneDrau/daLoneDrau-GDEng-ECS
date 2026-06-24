class_name ControlFlowNode
extends BehaviourTreeNode


enum Category {
	SEQUENCE, FALLBACK, PARALLEL, DECORATOR
}

enum Response {
	SUCCESS, FAILURE, RUNNING
}

## the [ControlFlowNode]'s category
var category: int

## the [ControlFlowNode]'s children
var children: Array[BehaviourTreeNode] = []

## flag indicating whether debugging is turned on
var debugging_on: bool = false

## the last response obtained when processing
var last_response: int = Response.SUCCESS

## the last node that was run
var last_child_index: int = -1


func _init(my_category: int, flow_name: String = "") -> void:
	category = my_category
	var category_string: String = ""
	match category:
		Category.SEQUENCE:
			category_string = "SEQUENCE"
		Category.FALLBACK:
			category_string = "FALLBACK"
		Category.PARALLEL:
			category_string = "PARALLEL"
		Category.DECORATOR:
			category_string = "DECORATOR"
	self.resource_name = "{} {} {}".format([get_class_name(), flow_name, category_string], "{}")


## Adds a child node.
func add_child(node: BehaviourTreeNode) -> void:
	children.append(node)


## Process the node from the first child node.
func process_all_nodes(e: Entity) -> int:
	var response: int = Response.FAILURE
	# find the last node and run from there
	for i in range(len(children)):
		var child: BehaviourTreeNode = children[i]
		var child_response: int
		if is_instance_of(child, ControlFlowNode):
			var control_flow_node: ControlFlowNode = child as ControlFlowNode
			child_response = control_flow_node.process(e)
		elif is_instance_of(child, ExecutionNode):
			var execution_node: ExecutionNode = child as ExecutionNode
			child_response = execution_node.execute(e)
		if debugging_on:
			var response_string: String = "SUCCESS"
			if child_response == Response.FAILURE:
				response_string = "FAILURE"
			if child_response == Response.RUNNING:
				response_string = "RUNNING"
			print("\t\tchild response ", response_string)

		response = child_response

		# if the node is still running, stop there
		if child_response == Response.RUNNING:
			last_child_index = i
			break

		if category == Category.SEQUENCE and child_response == Response.FAILURE:
			# Sequence nodes stop at the first failure
			if debugging_on:
				print("\t", self.resource_name, " stopped at first FAILURE")
			break
		if category == Category.FALLBACK and child_response == Response.SUCCESS:
			# Fallback nodes stop at the first success
			if debugging_on:
				print("\t", self.resource_name, " stopped at first SUCCESS")
			break

	return response


## Process the node from the last child node that was still running
func process_from_last_run(e: Entity) -> int:
	var response: int = Response.FAILURE
	# find the last node and run from there
	for i in range(last_child_index, len(children)):
		var child: BehaviourTreeNode = children[i]
		var child_response: int
		if is_instance_of(child, ControlFlowNode):
			var control_flow_node: ControlFlowNode = child as ControlFlowNode
			child_response = control_flow_node.process(e)
		elif is_instance_of(child, ExecutionNode):
			var execution_node: ExecutionNode = child as ExecutionNode
			child_response = execution_node.execute(e)
		if debugging_on:
			var response_string: String = "SUCCESS"
			if child_response == Response.FAILURE:
				response_string = "FAILURE"
			if child_response == Response.RUNNING:
				response_string = "RUNNING"
			print("\t\tchild response ", response_string)

		response = child_response

		# if the node is still running, stop there
		if child_response == Response.RUNNING:
			last_child_index = i
			break

		if category == Category.SEQUENCE and child_response == Response.FAILURE:
			# Sequence nodes stop at the first failure
			if debugging_on:
				print("\t", self.resource_name, " stopped at first FAILURE")
			break
		if category == Category.FALLBACK and child_response == Response.SUCCESS:
			# Fallback nodes stop at the first success
			if debugging_on:
				print("\t", self.resource_name, " stopped at first SUCCESS")
			break

	return response


## Processes the control node.
func process(e: Entity) -> int:
	if debugging_on:
		print("process ", self.resource_name)

	var response: int = Response.FAILURE

	if last_response == Response.RUNNING:
		response = process_from_last_run(e)
	else:
		response = process_all_nodes(e)

	# store the last response
	last_response = response
	return response
