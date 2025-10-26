## Handles all numerical health logic for any entity.
@abstract class_name DamageSystem
extends GameSystem


## —————————————————————————————————————————————
#region Signals
## —————————————————————————————————————————————

signal damage_applied(entity_id: String, result: Dictionary)
signal heal_applied(entity_id: String, result: Dictionary)
signal death_state_changed(entity_id: String, is_dead: bool)

#endregion

## Canonical entry to apply damage; return a result if you like (crit, mitigations, tags).
func apply_damage(entity_id: String, packet: Dictionary) -> Dictionary:
	# packet: {amount, type, tags:[], armor_pen:=0.0}
	var result := _resolve_damage_pipeline(entity_id, packet)
	_alter_hp(entity_id, -result.get("amount", 0.0))
	damage_applied.emit(entity_id, result)
	
	if _is_dead(entity_id):
		death_state_changed.emit(entity_id, true)
	return result


func apply_heal(entity_id: String, heal: Dictionary) -> Dictionary:
	var result: Dictionary = _resolve_heal_pipeline(entity_id, heal)
	_alter_hp(entity_id, result.get("amount", 0.0))
	heal_applied.emit(entity_id, result)
	return result

@abstract func _resolve_damage_pipeline(_entity_id: String, dmg: Dictionary) -> Dictionary
@abstract func _resolve_heal_pipeline(_entity_id: String, heal: Dictionary) -> Dictionary
@abstract func _alter_hp(_entity_id: String, delta: float) -> void
@abstract func _peek_hp(id: String) -> float
@abstract func _is_dead(id: String) -> bool


func ARX_DAMAGES_IgnitIO(_entity: Entity, _dmg: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_IgnitIO() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_IgnitIO() was left undefined!")


func ARX_DAMAGES_SCREEN_SPLATS_Init() -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_SCREEN_SPLATS_Init() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_SCREEN_SPLATS_Init() was left undefined!")


func ARX_DAMAGES_SCREEN_SPLATS_Add(_pos: Vector3, _dmgs: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_SCREEN_SPLATS_Add() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_SCREEN_SPLATS_Add() was left undefined!")


func ARX_DAMAGE_Reset_Blood_Info() -> void:
	push_error(self.get_name() + ".ARX_DAMAGE_Reset_Blood_Info() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGE_Reset_Blood_Info() was left undefined!")


func ARX_DAMAGE_Show_Hit_Blood() -> void:
	push_error(self.get_name() + ".ARX_DAMAGE_Show_Hit_Blood() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGE_Show_Hit_Blood() was left undefined!")


func damage_player(_dmg: float, _type: int, _source: int, _pos: Vector3) -> float:
	push_error(self.get_name() + ".damage_player() was left undefined!")
	assert(false, self.get_name() + ".damage_player() was left undefined!")
	return 0


func heal_player(_dmg: float) -> void:
	push_error(self.get_name() + ".heal_player() was left undefined!")
	assert(false, self.get_name() + ".heal_player() was left undefined!")


## Heals an [Entity] that is not a player. Replaces ARX_DAMAGES_HealInter.
func heal_entity(_entity: Entity, _dmg: float) -> void:
	push_error(self.get_name() + ".heal_entity() was left undefined!")
	assert(false, self.get_name() + ".heal_entity() was left undefined!")


func ARX_DAMAGES_HealManaPlayer(_dmg: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_HealManaPlayer() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_HealManaPlayer() was left undefined!")


func ARX_DAMAGES_HealManaInter(_entity: Entity, _dmg: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_HealManaInter() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_HealManaInter() was left undefined!")


func ARX_DAMAGES_DrainMana(_entity: Entity, _dmg: float) -> float:
	push_error(self.get_name() + ".ARX_DAMAGES_DrainMana() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DrainMana() was left undefined!")
	return 0


func ARX_DAMAGES_DamageFIX(_entity: Entity, _dmg: float, _source: int, _flags: int, _pos: Vector3) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_DamageFIX() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DamageFIX() was left undefined!")


func ARX_DAMAGES_ForceDeath(_entity_dead: Entity, _entity_killer: Entity) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_ForceDeath() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_ForceDeath() was left undefined!")


func ARX_DAMAGES_PushIO(_entity_target: Entity, _source: int, _power: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_PushIO() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_PushIO() was left undefined!")


func ARX_DAMAGES_DealDamages(_target: int, _dmg: float, _source: int, _flags: int, _pos: Vector3) -> float:
	push_error(self.get_name() + ".ARX_DAMAGES_DealDamages() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DealDamages() was left undefined!")
	return 0


func ARX_DAMAGES_DamageNPC(_entity: Entity, _dmg: float, _source: int, _flags: int, _pos: Vector3) -> float:
	push_error(self.get_name() + ".ARX_DAMAGES_DamageNPC() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DamageNPC() was left undefined!")
	return 0


func ARX_DAMAGES_Reset() -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_Reset() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_Reset() was left undefined!")


func ARX_DAMAGES_GetFree() -> int:
	push_error(self.get_name() + ".ARX_DAMAGES_GetFree() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_GetFree() was left undefined!")
	return 0


func InExceptList(_dmg: int, _num: int) -> int:
	push_error(self.get_name() + ".InExceptList() was left undefined!")
	assert(false, self.get_name() + ".InExceptList() was left undefined!")
	return 0


func ARX_DAMAGES_AddVisual(_damage_info: DamageInfo, _pos: Vector3, _dmg: float, _entity: Entity) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_AddVisual() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_AddVisual() was left undefined!")


func ARX_DAMAGES_UpdateDamage(_j: int, _tim: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_UpdateDamage() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_UpdateDamage() was left undefined!")


func ARX_DAMAGES_UpdateAll() -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_UpdateAll() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_UpdateAll() was left undefined!")


func SphereInIO(_entity: Entity, _pos: Vector3, _radius: float) -> bool:
	push_error(self.get_name() + ".SphereInIO() was left undefined!")
	assert(false, self.get_name() + ".SphereInIO() was left undefined!")
	return false


func ARX_DAMAGES_TryToDoDamage(_pos: Vector3, _dmg: float, _radius: float, _source: int) -> bool:
	push_error(self.get_name() + ".ARX_DAMAGES_TryToDoDamage() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_TryToDoDamage() was left undefined!")
	return false


func CheckForIgnition(_pos: Vector3, _radius: float, _mode: int, _flag: int) -> void:
	push_error(self.get_name() + ".CheckForIgnition() was left undefined!")
	assert(false, self.get_name() + ".CheckForIgnition() was left undefined!")


func PushPlayer(_pos: Vector3, _intensity: float) -> void:
	push_error(self.get_name() + ".PushPlayer() was left undefined!")
	assert(false, self.get_name() + ".PushPlayer() was left undefined!")


func DoSphericDamage(_pos: Vector3, _dmg: float, _radius: float, _flags: int, _typ: int, _numsource: int) -> bool:
	push_error(self.get_name() + ".DoSphericDamage() was left undefined!")
	assert(false, self.get_name() + ".DoSphericDamage() was left undefined!")
	return false


func ARX_DAMAGES_DurabilityRestore(_entity: Entity, _percent: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_DurabilityRestore() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DurabilityRestore() was left undefined!")


func ARX_DAMAGES_DurabilityCheck(_entity: Entity, _ratio: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_DurabilityCheck() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DurabilityCheck() was left undefined!")


func ARX_DAMAGES_DurabilityLoss(_entity: Entity, _loss: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_DurabilityLoss() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DurabilityLoss() was left undefined!")


func ARX_DAMAGES_DamagePlayerEquipment(_damages: float) -> void:
	push_error(self.get_name() + ".ARX_DAMAGES_DamagePlayerEquipment() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_DamagePlayerEquipment() was left undefined!")


func ARX_DAMAGES_ComputeRepairPrice(_torepair: Entity, _blacksmith: Entity) -> float:
	push_error(self.get_name() + ".ARX_DAMAGES_ComputeRepairPrice() was left undefined!")
	assert(false, self.get_name() + ".ARX_DAMAGES_ComputeRepairPrice() was left undefined!")
	return 0

# Inside a class file.

# An inner class in this class file.
class DamageInfo:
	var exist: bool
	var active: bool
	var pos: Vector3
	var damages: float
	var radius: float
	var start_time: int
	var except: Array[bool]
	var duration: int
	var source_id: String
	var area: int
	var flags: int
	var type: int
	var special: int
	var special_id: String
	var lastupd: int
