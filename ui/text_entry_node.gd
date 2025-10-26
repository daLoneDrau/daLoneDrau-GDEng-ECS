class_name TextEntryNode extends CanvasItem


## the entry label
@export var entry_label: Label

## the maximum length allowed
@export var max_length: int


## Adds a character based on the key code.
func add_key(key_code: String, lower_case_allowed: bool = true) -> void:
	# print("add_key *", key_code, "*")
	if lower_case_allowed:
		key_code = key_code.to_lower()
	if entry_label.text.length() == max_length:
		entry_label.text = entry_label.text.substr(0, max_length - 1)
	if Input.is_key_pressed(KEY_SHIFT):
		key_code = key_code.to_upper()
	entry_label.text += key_code


## Backspaces the last character.
func backspace() -> void:
	if entry_label.text.length() > 0:
		entry_label.text = entry_label.text.substr(0, entry_label.text.length() - 1)
