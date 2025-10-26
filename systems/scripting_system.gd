## System intended to standardize the emission of scripting signals
@abstract class_name ScriptingSystem
extends GameSystem


signal scripted_event(script_message: Dictionary)

var global_variables: ScriptVariableSet = ScriptVariableSet.new()


func _init() -> void:
	# register as a broadcaster for scripted events
	Switchboard_auto.add_node_broadcaster(
		self,
		"scripted_event",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


## Broadcasts a scripted event.
func send_script_event(sender: String, recipient: String, message_id: int, audience: int=GlobalUtils.ScriptMessageAudience.SINGLE_ENTITY, params: Dictionary={}):
	# put all data into a dictionary
	scripted_event.emit({
		"sender": sender,
		"recipient": recipient,
		"message_id": message_id,
		"audience": audience,
		"params": params,
	})
