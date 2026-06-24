class_name Switchboard extends Node


enum SubscriptionStrategy {PARENT_ONLY, UNLIMITED}

var parent_only_node_broadcasters: Dictionary = {}

var unlimited_node_broadcasters: Dictionary = {}

var parent_only_resource_broadcasters: Dictionary = {}

var unlimited_resource_broadcasters: Dictionary = {}

var waitlisted_subscribers: Dictionary = {}

# Track which object registered which callables for cleanup
var subscriber_callables: Dictionary = {}  # Object -> Array[{signal_name, callable}]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


func _disconnect_callable_from_broadcasters(signal_name: String, callable: Callable) -> void:
	if unlimited_node_broadcasters.has(signal_name):
		for emitter: Node in unlimited_node_broadcasters[signal_name]:
			if emitter.is_connected(signal_name, callable):
				emitter.disconnect(signal_name, callable)

	if unlimited_resource_broadcasters.has(signal_name):
		for emitter: Resource in unlimited_resource_broadcasters[signal_name]:
			if emitter.is_connected(signal_name, callable):
				emitter.disconnect(signal_name, callable)

	if parent_only_node_broadcasters.has(signal_name):
		for emitter: Node in parent_only_node_broadcasters[signal_name]:
			if emitter.is_connected(signal_name, callable):
				emitter.disconnect(signal_name, callable)

	if parent_only_resource_broadcasters.has(signal_name):
		for emitter: Resource in parent_only_resource_broadcasters[signal_name]:
			if emitter.is_connected(signal_name, callable):
				emitter.disconnect(signal_name, callable)


func _is_callable_valid(callable: Callable) -> bool:
	if not callable.is_valid():
		return false
	var obj: Object = callable.get_object()
	if obj == null:
		return false
	if obj is Node:
		var node: Node = obj as Node
		if not is_instance_valid(node) or not node.is_inside_tree():
			return false
	if obj is RefCounted:
		if not is_instance_valid(obj):
			return false
	return true


## Adds a broadcaster that wants to allow connections to its signals.
func add_node_broadcaster(broadcaster: Node, signal_name: StringName, subscription_strategy: SubscriptionStrategy = SubscriptionStrategy.UNLIMITED) -> void:
	match subscription_strategy:
		SubscriptionStrategy.PARENT_ONLY:
			if !parent_only_node_broadcasters.has(signal_name):
				parent_only_node_broadcasters[signal_name] = []
			parent_only_node_broadcasters[signal_name].append(broadcaster)
		SubscriptionStrategy.UNLIMITED:
			if !unlimited_node_broadcasters.has(signal_name):
				unlimited_node_broadcasters[signal_name] = []
			unlimited_node_broadcasters[signal_name].append(broadcaster)
			for saved_signal: String in waitlisted_subscribers:
				if saved_signal == signal_name:
					# print("\tsubscribers waiting for this signal")
					# a subscriber already asked to receive this signal
					for emitter_node: Node in unlimited_node_broadcasters[signal_name]:
						for callable in waitlisted_subscribers[signal_name]:
							if !emitter_node.is_connected(signal_name, callable):
								emitter_node.connect(signal_name, callable)
								# print("connecting ", emitter_node, " to waitlisted subscriber ", callable, " for signal ", signal_name)


## Adds a broadcaster that wants to allow connections to its signals.
func add_resource_broadcaster(broadcaster: Resource, signal_name: StringName, subscription_strategy: SubscriptionStrategy = SubscriptionStrategy.UNLIMITED) -> void:
	# print("adding resource ", broadcaster, " for signal ", signal_name)
	match subscription_strategy:
		SubscriptionStrategy.PARENT_ONLY:
			if !parent_only_resource_broadcasters.has(signal_name):
				parent_only_resource_broadcasters[signal_name] = []
			parent_only_resource_broadcasters[signal_name].append(broadcaster)
		SubscriptionStrategy.UNLIMITED:
			if !unlimited_resource_broadcasters.has(signal_name):
				unlimited_resource_broadcasters[signal_name] = []
			unlimited_resource_broadcasters[signal_name].append(broadcaster)

			# Connect waitlisted subscribers
			if waitlisted_subscribers.has(signal_name):
				var valid_callables: Array = []
				for callable in waitlisted_subscribers[signal_name]:
					# Validate callable before connecting
					if _is_callable_valid(callable):
						if not broadcaster.is_connected(signal_name, callable):
							broadcaster.connect(signal_name, callable)
						valid_callables.append(callable)
				# Prune invalid callables
				waitlisted_subscribers[signal_name] = valid_callables


## Connects a subscriber to any broadcasters that are giving off the signal they want to subscribe to.
func connect_subscriber(object: Object, signal_name: String, callable: Callable) -> void:
	var _subscription_filled: bool = false
	if object is Node:
		var node: Node = object as Node
		if parent_only_node_broadcasters.has(signal_name):
			for emitter_node: Node in parent_only_node_broadcasters[signal_name]:
				if node.is_ancestor_of(emitter_node):
					emitter_node.connect(signal_name, callable)
					_subscription_filled = true

	if unlimited_node_broadcasters.has(signal_name):
		for emitter_node: Node in unlimited_node_broadcasters[signal_name]:
			if not emitter_node.is_connected(signal_name, callable):
				emitter_node.connect(signal_name, callable)
				_subscription_filled = true
	elif unlimited_resource_broadcasters.has(signal_name):
		for emitter_node: Resource in unlimited_resource_broadcasters[signal_name]:
			if not emitter_node.is_connected(signal_name, callable):
				emitter_node.connect(signal_name, callable)
				_subscription_filled = true
	# if !subscription_filled:
	# no broadcaster was registered for this signal. store the subscriber in unlimited_resource_subscribers.
	# when a broadcaster registers with an unlimited subscription strategy, then if the signal names match,
	# the subscriber will be added to the broadcasts
	if !waitlisted_subscribers.has(signal_name):
		waitlisted_subscribers[signal_name] = []
	waitlisted_subscribers[signal_name].append(callable)
	# print("adding ", callable, " to waitlist as a subscriber for ", signal_name)

	# Track for cleanup
	if not subscriber_callables.has(object):
		subscriber_callables[object] = []
	subscriber_callables[object].append({
		"signal_name": signal_name,
		"callable": callable
	})


# Debug helper for development
func print_active_subscriptions() -> void:
	print("=== Switchboard Debug ===")
	print("Unlimited Node Broadcasters: ", unlimited_node_broadcasters.keys())
	print("Unlimited Resource Broadcasters: ", unlimited_resource_broadcasters.keys())
	print("Waitlisted Signals: ", waitlisted_subscribers.keys())


## Removed a node from the list of broadcasters.
func remove_node_broadcaster(broadcaster: Node, signal_name: StringName, subscription_strategy: SubscriptionStrategy = SubscriptionStrategy.UNLIMITED) -> void:
	match subscription_strategy:
		SubscriptionStrategy.PARENT_ONLY:
			if parent_only_node_broadcasters.has(signal_name):
				parent_only_node_broadcasters[signal_name].erase(broadcaster)
		SubscriptionStrategy.UNLIMITED:
			if unlimited_node_broadcasters.has(signal_name):
				unlimited_node_broadcasters[signal_name].erase(broadcaster)


## Remove a resource broadcaster and disconnect its signals
func remove_resource_broadcaster(broadcaster: Resource, signal_name: StringName) -> void:
	if parent_only_resource_broadcasters.has(signal_name):
		parent_only_resource_broadcasters[signal_name].erase(broadcaster)
	if unlimited_resource_broadcasters.has(signal_name):
		unlimited_resource_broadcasters[signal_name].erase(broadcaster)
	# Optionally disconnect all existing connections
	for callable in broadcaster.get_signal_connection_list(signal_name):
		broadcaster.disconnect(signal_name, callable["callable"])


## Removes a subscriber from the waitlist.
func remove_from_waitlist(signal_name: String, callable: Callable) -> void:
	if waitlisted_subscribers.has(signal_name):
		waitlisted_subscribers[signal_name].erase(callable)


## Removes all waitlisted subscriptions for an object
func remove_subscriber(object: Object) -> void:
	if not subscriber_callables.has(object):
		return

	var registrations: Array = subscriber_callables[object]
	for reg in registrations:
		var signal_name: String = reg["signal_name"]
		var callable: Callable = reg["callable"]

		# Remove from waitlist
		if waitlisted_subscribers.has(signal_name):
			waitlisted_subscribers[signal_name].erase(callable)

		# Disconnect from any active broadcasters
		_disconnect_callable_from_broadcasters(signal_name, callable)

	subscriber_callables.erase(object)
