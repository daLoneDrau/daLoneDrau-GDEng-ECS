## Defines a set of ability scores.
@abstract class_name AbilitiesComponent
extends EntityComponent


## the set of attributes defined by the abilities
var ability_set: Dictionary[int, AbilityScore] = {}

## —————————————————————————————————————————————
#region Lifecycle wiring: keep parent pointers correct
## —————————————————————————————————————————————
func on_added(_entity: Entity, _em: EntityManager) -> void:
	for a in ability_set.keys():
		if ability_set[a] != null:
			ability_set[a]._parent = self


func on_removed(_entity: Entity, _em: EntityManager) -> void:
	for a in ability_set.keys():
		if ability_set[a] != null:
			ability_set[a]._parent = null
			
#endregion

## —————————————————————————————————————————————
#region API
## —————————————————————————————————————————————


## Adds an ability score.
func add(ability: int, initial_score: int = 0) -> void:
	var score := AbilityScore.new(self)
	score.base = initial_score
	ability_set[ability] = score
	emit_update_signal()


## Adds an [AbilityScore] modifier with a specific source.
func add_source(ability: int, src: StringName, amount: int) -> void:
	var s: AbilityScore = ability_set.get(ability, null)
	if s != null:
		s.add_source(src, amount)


## Gets the base value score for a specific [AbilityScore].
func base_value(ability: int) -> int:
	var s: AbilityScore = ability_set.get(ability, null)
	return 0 if s == null else s.base


## Clears all [AbilityScore] modifiers.
func clear_all_sources() -> void:
	for s in ability_set.values():
		if s != null:
			s.clear_sources()


## Clears all modifiers for a specific [AbilityScore]..
func clear_sources(ability: int) -> void:
	var s: AbilityScore = ability_set.get(ability, null)
	if s != null:
		s.clear_sources()


func from_dict(data: Dictionary) -> void:
	if not data.has("abilities"):
		return
	var ab: Dictionary[int, Dictionary] = data["abilities"]
	for a in ab.keys():
		var slot: = ab[a]
		var s: AbilityScore = ability_set.get(a, null)
		if s == null:
			add(a, int(slot.get("base", 0)))
			s = ability_set[a]
		else:
			s.base = int(slot.get("base", 0))
		# restore sources (recalculates modifier + emits update)
		s.clear_sources()
		var sources: Dictionary = slot.get("sources", {})
		for k in sources.keys():
			s.add_source(k, int(sources[k]))


## Gets the full score for a specific [AbilityScore].
func full(ability: int) -> int:
	var s: AbilityScore = ability_set.get(ability, null)
	return 0 if s == null else s.full


## Determines if the [SetOfAbilities] contains a specific ability.
func has_ability_score(ability: int) -> bool:
	return ability_set.has(ability)


## Gets the modifier value score for a specific [AbilityScore].
func modifier_value(ability: int) -> int:
	var s: AbilityScore = ability_set.get(ability, null)
	return 0 if s == null else s.modifier


## Removes an [AbilityScore] modifier from a specific source.
func remove_source(ability: int, src: StringName) -> void:
	var s: AbilityScore = ability_set.get(ability, null)
	if s != null:
		s.remove_source(src)


## Sets the base score for a specific ability.
func set_ability_score(ability: int, base_score: int) -> void:
	var s: AbilityScore = ability_set.get(ability, null)
	if s == null:
		add(ability, base_score)
	else:
		s.base = base_score
		# AbilityScore will call parent.emit_update_signal() for us


func to_dict() -> Dictionary:
	var out: Dictionary[int, Dictionary] = {}
	for a in ability_set.keys():
		var s: AbilityScore = ability_set[a]
		if s == null:
			continue
		out[a] = {
			"base": s.base,
			"modifier": s.modifier,
			"sources": s.get_sources()
		}
	return {
		"key": get_class_name(),
		"abilities": out
	}


## Gets an ability's score.
func value(ability: int) -> AbilityScore:
	return ability_set.get(ability, null)
