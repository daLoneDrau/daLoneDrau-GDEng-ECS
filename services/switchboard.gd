class_name Switchboard
extends Node


enum SubscriptionStrategy {PARENT_ONLY, UNLIMITED}

var parent_only_node_broadcasters: Dictionary = {}

var unlimited_node_broadcasters: Dictionary = {}

var parent_only_resource_broadcasters: Dictionary = {}

var unlimited_resource_broadcasters: Dictionary = {}

var waitlisted_subscribers: Dictionary = {}


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


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
			# check to see if any subscribers have been waiting around for this signal
			for saved_signal: String in waitlisted_subscribers:
				if saved_signal == signal_name:
					# print("\tsubscribers waiting for this signal")
					# a subscriber already asked to receive this signal
					for emitter_node: Resource in unlimited_resource_broadcasters[signal_name]:
						for callable in waitlisted_subscribers[signal_name]:
							if !emitter_node.is_connected(signal_name, callable):
								emitter_node.connect(signal_name, callable)
								# print("connecting ", emitter_node, " to waitlisted subscriber ", callable, " for signal ", signal_name)


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
			emitter_node.connect(signal_name, callable)
			_subscription_filled = true
	elif unlimited_resource_broadcasters.has(signal_name):
		for emitter_node: Resource in unlimited_resource_broadcasters[signal_name]:
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


## Removed a node from the list of broadcasters.
func remove_node_broadcaster(broadcaster: Node, signal_name: StringName, subscription_strategy: SubscriptionStrategy = SubscriptionStrategy.UNLIMITED) -> void:
	match subscription_strategy:
		SubscriptionStrategy.PARENT_ONLY:
			if parent_only_node_broadcasters.has(signal_name):
				parent_only_node_broadcasters[signal_name].erase(broadcaster)
		SubscriptionStrategy.UNLIMITED:
			if unlimited_node_broadcasters.has(signal_name):
				unlimited_node_broadcasters[signal_name].erase(broadcaster)


## Removes a subscriber from the waitlist.
func remove_from_waitlist(signal_name: String, callable: Callable) -> void:
	if waitlisted_subscribers.has(signal_name):
		waitlisted_subscribers[signal_name].erase(callable)
