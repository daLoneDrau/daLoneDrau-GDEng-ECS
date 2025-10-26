@abstract class_name CombatSystem
extends GameSystem


signal attack_resolved(attacker_id: String, defender_id: String, hit: Dictionary)

func attack(attacker_id: String, defender_id: String, args: Dictionary) -> Dictionary:
	# args: {weapon_id?, ability_id?, advantage?, cover?, distance?}
	var hit: Dictionary = _roll_to_hit(attacker_id, defender_id, args)
	if hit.hit:
		# successful hit. apply damage
		var packet: Dictionary = _build_damage_packet(attacker_id, defender_id, hit, args)
		var parent_scene: Scene = get_parent() as Scene
		var damage_system: DamageSystem = parent_scene.get_damage_system()
		var result: Dictionary = damage_system.apply_damage(defender_id, packet)
		hit.damage_result = result
	
	# emit signal
	attack_resolved.emit(attacker_id, defender_id, hit)
	return hit

@abstract func _roll_to_hit(attacker_id, defender_id, args) -> Dictionary
@abstract func _build_damage_packet(attacker_id, defender_id, hit, args) -> Dictionary
