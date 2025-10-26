# res://ecs/components/HealthComponent.gd

## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Pure data container for health state. No logic, no signals.
## Systems are responsible for:
## - Damage/heal resolution & clamping
## - Death checks & signaling
## - Regeneration timing/application
## - Applying modifiers (equipment, effects, scripts)
## Suggested signal emitters (in systems):
## - resources_changed(entity_id)
## - death_state_changed(entity_id, is_dead)
class_name HealthComponent
extends EntityComponent


## —————————————————————————————————————————————
#region Core Pools
## —————————————————————————————————————————————
@export_group("Core Pools")
## Current hit points.
@export var current_hp: float = 10.0

## Maximum hit points after all modifiers (systems maintain this).
@export var max_hp: float = 10.0

## Temporary hit points that are consumed before 'current'.
## Set/maintained by systems (e.g., shield spells, buffs).
@export var temp_hp: float = 0.0

## Optional cap for temp HP (0 => uncapped; systems decide policy).
@export var temp_hp_max: float = 0.0

#endregion


## —————————————————————————————————————————————
#region Regeneration & Constraints
## —————————————————————————————————————————————

@export_group("Regeneration & Constraints")
## Passive regeneration per tick/turn (systems decide cadence).
@export var regen_rate: float = 0.0

## Allow healing above 'max' up to 'overheal_cap'.
@export var allow_overheal: bool = false

## If overheal is allowed, this is the hard cap for 'current'.
## Example: max=100, overheal_cap=120 allows +20 overheal.
@export var overheal_cap: float = 0.0

## Minimum viable value; usually 0. Systems decide if <= min_value means dead.
@export var min_value: float = 0.0

#endregion


## —————————————————————————————————————————————
#region Status Flags (system-maintained)
## —————————————————————————————————————————————
@export_group("Status Flags (system-maintained)")
## Set by systems when death threshold is crossed / reversed.
@export var is_dead: bool = false

## When true, damage should be ignored by systems (e.g., invulnerability frames).
@export var invulnerable: bool = false

#endregion


## —————————————————————————————————————————————
#region Telemetry (optional; useful for combat logs/UX)
## —————————————————————————————————————————————

## Last damage magnitude applied to this entity (for floaty text, logs).
var last_damage: float = 0.0

## Optional damage type key (e.g., "physical", "fire", "poison").
var last_damage_type: StringName = &""

## Entity ID that last applied damage (for aggro/kill credit).
var last_source_entity_id: String = ""

## Unix time (ms) when health last changed; systems update this.
var last_changed_ms: int = 0

#endregion
