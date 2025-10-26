class_name FlagSet
extends CustomResource


@export var flags: int = 0

## —————————————————————————————————————————————
#region Core bit operations
## —————————————————————————————————————————————


## Adds (sets) a flag in the set.
func add(flag: int) -> void:
	flags |= flag


## Clears all flags.
func clear() -> void:
	flags = 0;


## Returns true if all flags match another FlagSet or int mask.
func equals(obj) -> bool:
	var ret_val: bool = false
	if obj is FlagSet:
		ret_val = flags == obj.flags
	elif obj is int:
		ret_val = flags == obj
	return ret_val


## Returns the current bitmask.
func get_mask() -> int:
	return flags


## Determines if a specific flag was added to the set.
func has(flag: int) -> bool:
	return (flags & flag) == flag


## Removes a flag from the set.
func remove(flag: int) -> void:
	flags &= ~flag


## Replaces the bitmask directly.
func set_mask(mask: int) -> void:
	flags = mask


## Toggles a flag on/off.
func toggle(flag: int) -> void:
	flags ^= flag
	
#endregion
