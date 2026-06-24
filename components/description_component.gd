## Stores descriptive text and physical characteristics for an entity.
## Examples: Character bios, item descriptions, monster lore, appearance details
class_name DescriptionComponent
extends EntityComponent

const IS_SLOT_ROOT: bool = true

## Emitted when any description field changes
signal description_changed(entity_id: String, field: StringName, old_value: Variant, new_value: Variant)

## Primary description text (e.g., "A weathered adventurer with a haunted look")
@export_multiline var description: String = "":
	set(value):
		if description != value:
			var old := description
			description = value
			_emit_change(&"description", old, value)

## Short one-line description for tooltips/lists (e.g., "Veteran warrior")
@export var short_description: String = "":
	set(value):
		if short_description != value:
			var old := short_description
			short_description = value
			_emit_change(&"short_description", old, value)

## Detailed lore/backstory (e.g., "Born in the village of...")
@export_multiline var lore: String = "":
	set(value):
		if lore != value:
			var old := lore
			lore = value
			_emit_change(&"lore", old, value)

## Physical appearance details
@export_group("Appearance")

@export var gender: Gender.Enum = Gender.Enum.NEUTRAL:
	set(value):
		if gender != value:
			var old := gender
			gender = value
			_emit_change(&"gender", old, value)

@export var age: int = 0:
	set(value):
		if age != value:
			var old := age
			age = value
			_emit_change(&"age", old, value)

@export var height_cm: int = 0:  # Height in centimeters
	set(value):
		if height_cm != value:
			var old := height_cm
			height_cm = value
			_emit_change(&"height_cm", old, value)

@export var weight_kg: int = 0:  # Weight in kilograms
	set(value):
		if weight_kg != value:
			var old := weight_kg
			weight_kg = value
			_emit_change(&"weight_kg", old, value)

## Visual identifiers
@export_group("Visuals")

@export var portrait_id: StringName = &"":  # Reference to portrait texture
	set(value):
		if portrait_id != value:
			var old := portrait_id
			portrait_id = value
			_emit_change(&"portrait_id", old, value)

@export var sprite_id: StringName = &"":  # Reference to sprite/animation
	set(value):
		if sprite_id != value:
			var old := sprite_id
			sprite_id = value
			_emit_change(&"sprite_id", old, value)

@export var color_primary: Color = Color.WHITE:  # Primary color (clothing, skin, etc.)
	set(value):
		if color_primary != value:
			var old := color_primary
			color_primary = value
			_emit_change(&"color_primary", old, value)

@export var color_secondary: Color = Color.WHITE:  # Secondary color
	set(value):
		if color_secondary != value:
			var old := color_secondary
			color_secondary = value
			_emit_change(&"color_secondary", old, value)

## Freeform tags for filtering/searching (e.g., ["human", "warrior", "scarred"])
@export var tags: Array[StringName] = []


## —————————————————————————————————————————————
#region Initialization
## —————————————————————————————————————————————

func _init(p_description: String = "", p_short_description: String = "") -> void:
	super()
	description = p_description
	short_description = p_short_description
	_register_broadcasters()


func _register_broadcasters() -> void:
	Switchboard_auto.add_resource_broadcaster(
		self,
		"description_changed",
		Switchboard_auto.SubscriptionStrategy.UNLIMITED
	)


func _unregister_broadcasters() -> void:
	Switchboard_auto.remove_resource_broadcaster(self, "description_changed")

#endregion

## —————————————————————————————————————————————
#region Lifecycle
## —————————————————————————————————————————————

func on_added(entity: Entity, em: EntityManager) -> void:
	super.on_added(entity, em)


func on_removed(entity: Entity, em: EntityManager) -> void:
	super.on_removed(entity, em)


func _unregister_from_switchboard() -> void:
	_unregister_broadcasters()
	super._unregister_from_switchboard()

#endregion

## —————————————————————————————————————————————
#region Description Access
## —————————————————————————————————————————————

## Returns the best available description (short if main is empty)
func get_description() -> String:
	if not description.is_empty():
		return description
	if not short_description.is_empty():
		return short_description
	return ""


## Returns short description, falling back to truncated main description
func get_short_description(max_length: int = 50) -> String:
	if not short_description.is_empty():
		return short_description
	if not description.is_empty():
		if description.length() <= max_length:
			return description
		return description.substr(0, max_length - 3) + "..."
	return ""


## Returns lore text, or empty string if none
func get_lore() -> String:
	return lore


## Check if entity has any description
func has_description() -> bool:
	return not description.is_empty() or not short_description.is_empty()


## Check if entity has lore/backstory
func has_lore() -> bool:
	return not lore.is_empty()

#endregion

## —————————————————————————————————————————————
#region Appearance Access
## —————————————————————————————————————————————

## Returns gender pronoun (he/she/they/it)
func get_pronoun() -> String:
	return Gender.pronoun(gender)


## Returns possessive pronoun (his/her/their/its)
func get_possessive() -> String:
	return Gender.possessive(gender)


## Returns objective pronoun (him/her/them/it)
func get_objective() -> String:
	return Gender.objective(gender)


## Returns reflexive pronoun (himself/herself/themselves/itself)
func get_reflexive() -> String:
	return Gender.reflexive(gender)


## Returns appropriate verb form of "to be" (is/are)
func get_verb_be() -> String:
	return Gender.verb_be(gender)


## Returns appropriate verb form of "to have" (has/have)
func get_verb_have() -> String:
	return Gender.verb_have(gender)


## Process gender tokens in text using this entity's gender
## Example: "[gender-pronoun] [gender-verb-be] here" -> "she is here"
func replace_gender_tokens(text: String) -> String:
	return Gender.replace_tokens(gender, text)


## Returns height as formatted string
func get_height_string(use_imperial: bool = false) -> String:
	if height_cm <= 0:
		return ""
	if use_imperial:
		var total_inches := int(float(height_cm) / 2.54)
		var feet := total_inches / 12
		var inches := total_inches % 12
		return "%d'%d\"" % [feet, inches]
	return "%d cm" % height_cm


## Returns weight as formatted string
func get_weight_string(use_imperial: bool = false) -> String:
	if weight_kg <= 0:
		return ""
	if use_imperial:
		var pounds := int(float(weight_kg) * 2.205)
		return "%d lbs" % pounds
	return "%d kg" % weight_kg


## Returns age category string
func get_age_category() -> String:
	if age <= 0:
		return "Unknown"
	elif age < 13:
		return "Child"
	elif age < 20:
		return "Young"
	elif age < 40:
		return "Adult"
	elif age < 60:
		return "Middle-aged"
	elif age < 80:
		return "Old"
	else:
		return "Ancient"


## Check if appearance data is set
func has_appearance() -> bool:
	return age > 0 or height_cm > 0 or weight_kg > 0

#endregion

## —————————————————————————————————————————————
#region Tags
## —————————————————————————————————————————————

## Add a tag if not already present
func add_tag(tag: StringName) -> void:
	if not tags.has(tag):
		tags.append(tag)
		_emit_change(&"tags", tags, tags)  # Same array, signals change


## Remove a tag if present
func remove_tag(tag: StringName) -> bool:
	var index := tags.find(tag)
	if index >= 0:
		tags.remove_at(index)
		_emit_change(&"tags", tags, tags)
		return true
	return false


## Check if entity has a specific tag
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Check if entity has ALL specified tags
func has_all_tags(required_tags: Array[StringName]) -> bool:
	for tag in required_tags:
		if not tags.has(tag):
			return false
	return true


## Check if entity has ANY of the specified tags
func has_any_tag(check_tags: Array[StringName]) -> bool:
	for tag in check_tags:
		if tags.has(tag):
			return true
	return false


## Get all tags
func get_tags() -> Array[StringName]:
	return tags.duplicate()


## Clear all tags
func clear_tags() -> void:
	if not tags.is_empty():
		tags.clear()
		_emit_change(&"tags", tags, tags)

#endregion

## —————————————————————————————————————————————
#region Convenience Setters
## —————————————————————————————————————————————

## Set basic description fields
func set_descriptions(p_description: String, p_short_description: String = "", p_lore: String = "") -> void:
	description = p_description
	short_description = p_short_description
	lore = p_lore


## Set appearance data
func set_appearance(p_gender: Gender.Enum, p_age: int = 0, p_height_cm: int = 0, p_weight_kg: int = 0) -> void:
	gender = p_gender
	age = p_age
	height_cm = p_height_cm
	weight_kg = p_weight_kg


## Set visual identifiers
func set_visuals(p_portrait_id: StringName, p_sprite_id: StringName = &"") -> void:
	portrait_id = p_portrait_id
	sprite_id = p_sprite_id


## Set color scheme
func set_colors(p_primary: Color, p_secondary: Color = Color.WHITE) -> void:
	color_primary = p_primary
	color_secondary = p_secondary


## Clear all fields
func clear() -> void:
	description = ""
	short_description = ""
	lore = ""
	gender = Gender.Enum.NEUTRAL
	age = 0
	height_cm = 0
	weight_kg = 0
	portrait_id = &""
	sprite_id = &""
	color_primary = Color.WHITE
	color_secondary = Color.WHITE
	tags.clear()

#endregion

## —————————————————————————————————————————————
#region Signal Helpers
## —————————————————————————————————————————————

func _emit_change(field: StringName, old_value: Variant, new_value: Variant) -> void:
	if _lifecycle_initialized:
		description_changed.emit(parent_entity_id, field, old_value, new_value)
		emit_update_signal()

#endregion

## —————————————————————————————————————————————
#region Serialization
## —————————————————————————————————————————————

func to_dict() -> Dictionary:
	var tags_array: Array[String] = []
	for tag in tags:
		tags_array.append(String(tag))

	return {
		"key": get_class_name(),
		"enabled": enabled,
		"description": description,
		"short_description": short_description,
		"lore": lore,
		"gender": gender,
		"age": age,
		"height_cm": height_cm,
		"weight_kg": weight_kg,
		"portrait_id": String(portrait_id),
		"sprite_id": String(sprite_id),
		"color_primary": color_primary.to_html(),
		"color_secondary": color_secondary.to_html(),
		"tags": tags_array,
	}


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	description = data.get("description", "")
	short_description = data.get("short_description", "")
	lore = data.get("lore", "")
	gender = int(data.get("gender", Gender.Enum.NEUTRAL))
	age = int(data.get("age", 0))
	height_cm = int(data.get("height_cm", 0))
	weight_kg = int(data.get("weight_kg", 0))
	portrait_id = StringName(data.get("portrait_id", ""))
	sprite_id = StringName(data.get("sprite_id", ""))
	color_primary = Color.html(data.get("color_primary", "ffffff"))
	color_secondary = Color.html(data.get("color_secondary", "ffffff"))

	tags.clear()
	for tag_str in data.get("tags", []):
		tags.append(StringName(tag_str))

#endregion

## —————————————————————————————————————————————
#region Debug
## —————————————————————————————————————————————

func _to_string() -> String:
	var desc_preview := get_short_description(30)
	if desc_preview.is_empty():
		desc_preview = "[No description]"
	return "DescriptionComponent[%s](%s)" % [parent_entity_id, desc_preview]


func print_debug() -> void:
	print("=== DescriptionComponent Debug ===")
	print("  Entity: %s" % parent_entity_id)
	print("  Description: '%s'" % get_short_description(60))
	print("  Has Lore: %s" % has_lore())
	print("  Gender: %s (%s)" % [Gender.title(gender), get_pronoun()])
	print("  Age: %s (%s)" % [age if age > 0 else "?", get_age_category()])
	print("  Height: %s" % get_height_string())
	print("  Weight: %s" % get_weight_string())
	print("  Portrait: %s" % portrait_id)
	print("  Sprite: %s" % sprite_id)
	print("  Tags: %s" % tags)


func get_summary() -> Dictionary:
	return {
		"entity_id": parent_entity_id,
		"description": description,
		"short_description": short_description,
		"has_lore": has_lore(),
		"gender": Gender.title(gender),
		"pronoun": get_pronoun(),
		"age": age,
		"age_category": get_age_category(),
		"height_cm": height_cm,
		"height_string": get_height_string(),
		"weight_kg": weight_kg,
		"weight_string": get_weight_string(),
		"portrait_id": String(portrait_id),
		"sprite_id": String(sprite_id),
		"tags": get_tags(),
	}

#endregion