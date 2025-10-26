class_name ScriptingComponent
extends EntityComponent


var script_name: String

var variables: ScriptVariableSet = ScriptVariableSet.new()


func _init() -> void:
	# connect to the entity_data_update signal
	Switchboard_auto.connect_subscriber(
		self,
		"scripted_event",
		handle_script_event
	)

#region variable set wrappers


## Adds a new variable to the set.
func add_variable(name: String, obj,  overridePrevious: bool = false) -> void:
	variables.add_variable(name, obj, overridePrevious)


## clears the set
func clear_variables() -> void: variables.clear()


## Determines if a variable by a specific name was set.
func has_variable(name: String) -> bool: return variables.has(name)


## Removes a variable
func remove_variable(key: String) -> void: variables.remove(key)


## Sets a script variable's value.
func set_variable(name: String, obj: Variant) -> void: variables.set_variable(name, obj)


## Gets the variable's value.
func get_variable_value(name: String) -> Variant: return variables.value(name)

#endregion variable set wrappers

#region SCRIPT_HANDLING


## Handles a script event.
func handle_script_event(script_message: Dictionary) -> void:
	match script_message.audience:
		GlobalUtils.ScriptMessageAudience.SINGLE_ENTITY:
			if parent_entity_id == script_message.recipient:
				process_script_message(script_message)
		GlobalUtils.ScriptMessageAudience.ALL_ENTITIES:
			process_script_message(script_message)
		GlobalUtils.ScriptMessageAudience.ENTITY_GROUP:
			var parent: Entity = entity_manager_instance.get_entity_by_id(parent_entity_id)
			if script_message.recipient in parent.groups:
				process_script_message(script_message)


## Processes a script meant for this Entity.
func process_script_message(script_message: Dictionary) -> void:
	match script_message.message_id:
		GlobalUtils.SM_INIT:
			on_init(script_message)
		GlobalUtils.SM_INVENTORYIN:
			on_inventory_in(script_message)
		GlobalUtils.SM_DIE:
			on_die(script_message)
		GlobalUtils.SM_SPELLCAST:
			on_spellcast(script_message)
		GlobalUtils.SM_SPELLEND:
			on_spellend(script_message)
		GlobalUtils.SM_TURN_START:
			on_turn_start(script_message)
		_:
			process_unhandled_script_event(script_message)


## Handles the initialize script event.
func process_unhandled_script_event(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".process_unhandled_script_event undefined")
	assert(false, self.get_name() + ".process_unhandled_script_event() was left undefined!")

#region SCRIPT_MESSAGE_HANDLERS


## Handles the die script event.
func on_die(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".on_die undefined")
	assert(false, self.get_name() + ".on_die() was left undefined!")


## Handles the initialize script event.
func on_init(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".on_init undefined")
	assert(false, self.get_name() + ".on_init() was left undefined!")


## Handles the script event when an item is placed in an entity's inventory.
func on_inventory_in(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".on_inventory_in undefined")
	assert(false, self.get_name() + ".on_inventory_in() was left undefined!")


## Handles the spell cast script event.
func on_spellcast(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".on_spellcast undefined")
	assert(false, self.get_name() + ".on_spellcast() was left undefined!")


## Handles the spell end script event.
func on_spellend(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".on_spellend undefined")
	assert(false, self.get_name() + ".on_spellend() was left undefined!")


## Handles the turn start event.
func on_turn_start(_script_message: Dictionary) -> void:
	push_error(self.get_name() + ".on_turn_start undefined")
	assert(false, self.get_name() + ".on_turn_start() was left undefined!")

#endregion SCRIPT_MESSAGE_HANDLERS
#endregion SCRIPT_HANDLING
