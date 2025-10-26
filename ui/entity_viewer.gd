## Container class handling signals for viewing Entities.
class_name EntityViewer extends CanvasItem


## the entity reference id. only events that happen to this entity should be listened to
var entity_id: String:
	get:
		return entity_id
	set(value):
		entity_id = value
		update_entity(entity_id)


## reference ids for the multiple entities being viewed. only events that happen to one of these entities should be listened to
var set_of_entity_ids: Array[String]


func _enter_tree() -> void:
	# connect to the entity_data_update signal
	Switchboard_auto.connect_subscriber(
		self,
		"entity_data_update",
		update_entity
	)
	# connect to the entity_viewer_change signal. this signal indicates the single entity being viewed has changed
	Switchboard_auto.connect_subscriber(
		self,
		"entity_viewed_change",
		change_entity
	)
	# connect to the entity_viewer_change signal. this signal indicates the set of entities being viewed has changed
	Switchboard_auto.connect_subscriber(
		self,
		"entities_viewed_change",
		change_entities
	)


func _exit_tree() -> void:
	Switchboard_auto.remove_from_waitlist("entity_data_update", update_entity)
	Switchboard_auto.remove_from_waitlist("entity_viewed_change", change_entity)
	Switchboard_auto.remove_from_waitlist("entities_viewed_change", change_entities)


## Handles changes to the entity being viewed.
func change_entity(id: String) -> void:
	entity_id = id
	# print(self.name, " received change_entity(", id)


## Handles changes to the set of entities being viewed.
func change_entities(_source: String, _ids: Array[String]) -> void:
	push_error(self.get_name() + ".change_entities() not defined " + self.name)
	assert(false, self.get_name() + ".change_entities() was left undefined!")


func display_entity(_entity_id: String) -> void:
	push_error(self.get_name() + ".display_entity() not defined " + self.name)
	assert(false, self.get_name() + ".display_entity() was left undefined!")


## Displays the entities being viewed.
func display_entities() -> void:
	push_error(self.get_name() + ".display_entities() not defined " + self.name)
	assert(false, self.get_name() + ".display_entities() was left undefined!")

## Handles the signal that an [Entity] has been updated.
func update_entity(_entity_id: String) -> void:
	push_error(self.get_name() + ".update_entity() signal received but not handled " + self.name)
	assert(false, self.get_name() + ".update_entity() was left undefined!")


## Formats a number.
func number_format(val: Variant, _decimals = 0, _dec_point = ".", _thousands_sep = ",") -> String:
	var number: float = float(val)

	if !_dec_point or !_thousands_sep:
		_dec_point = '.';
		_thousands_sep = ','


	var roundedNumber: String  = str(round( abs( number ) * float('1e' + str(_decimals)) ))
	var numbersString: String  = roundedNumber
	var decimalsString: String = ""
	if _decimals > 0:
		numbersString = roundedNumber.left(roundedNumber.length() - _decimals)
		decimalsString = roundedNumber.right(roundedNumber.length() - _decimals)

	var formattedNumber: String = ""

	while numbersString.length() > 3:
		formattedNumber += _thousands_sep + numbersString.right(3)
		numbersString = numbersString.substr(0, numbersString.length() - 3);

	var ret: String = ""
	if number < 0:
		ret += "-"
	ret += numbersString + formattedNumber
	if decimalsString != "":
		ret += (_dec_point + decimalsString)

	return ret
