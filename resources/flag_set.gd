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
	flags = 0


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
	assert(_is_power_of_two(flag), "has() expects a single flag, use has_all() for masks")
	return (flags & flag) == flag


## Returns true if ANY of the specified flags are set
func has_any(mask: int) -> bool:
	return (flags & mask) != 0


## Returns true if ALL of the specified flags are set
func has_all(mask: int) -> bool:
	return (flags & mask) == mask


func is_empty() -> bool:
	return flags == 0


## Determines if the bit is a power of two.
func _is_power_of_two(n: int) -> bool:
	return n > 0 and (n & (n - 1)) == 0


## Returns a new FlagSet with only flags present in both
func intersection(other: FlagSet) -> FlagSet:
	var result := FlagSet.new()
	result.flags = flags & other.flags
	return result


## Removes a flag from the set.
func remove(flag: int) -> void:
	flags &= ~flag


## Replaces the bitmask directly.
func set_mask(mask: int) -> void:
	flags = mask


## Toggles a flag on/off.
func toggle(flag: int) -> void:
	flags ^= flag


## Returns a new FlagSet with flags from both sets
func union(other: FlagSet) -> FlagSet:
	var result := FlagSet.new()
	result.flags = flags | other.flags
	return result
	
#endregion


func _to_string() -> String:
	return "FlagSet(0b%s)" % String.num_int64(flags, 2)
