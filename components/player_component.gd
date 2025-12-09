# res://ecs/components/PlayerComponent.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Identifies an entity as a controllable player character (PC)
## with identity/profile, party membership, lightweight state,
## and meta tags. Pure data; no logic, no signals.
## Related enums (int-backed) expected at:
##   - Gender.gd (Gender.Enum)
##   - Race.gd (Race.Enum)
##   - Region.gd (Region.Enum)
##   - Faith.gd (Faith.Enum)
##   - Profession.gd (Profession.Enum)
##   - Alignment.gd (Alignment.Enum)
##   - Order.gd (Order.Enum)
##   - PlayerTags.gd (PlayerTags.Tag bitmask)
class_name PlayerComponent
extends EntityComponent

## —————————————————————————————————————————————
## Identity / Profile
## —————————————————————————————————————————————
@export var name: String = "Unnamed"
@export var gender: int = Gender.Enum.NEUTRAL                # Gender.Enum
@export var race: int = 0                                    # Race.Enum
@export var origin_region: int = 0                           # Region.Enum
@export var faith: int = 0                                   # Faith.Enum
@export var profession: int = 0                              # Profession.Enum
@export var alignment: int = 0                               # Alignment.Enum
@export var order_affiliation: int = 0                       # Order.Enum
@export var portrait_id: int = -1                            # UI portrait key or resource path
@export var player_tags: int = 0                             # FlagSet of PlayerTags.Tag

## —————————————————————————————————————————————
## Progression (compact)
## —————————————————————————————————————————————
@export var level: int = 1
@export var experience: float = 0.0
@export var reputation: float = 0.0

## —————————————————————————————————————————————
## Party / Roster (multi-PC)
## —————————————————————————————————————————————
@export var roster_id: StringName = &""                      # Stable unique ID across saves
@export var party_id: StringName = &""                       # Empty ⇒ not in an active party
@export var party_slot: int = -1                             # 0..N-1 when in party; -1 otherwise
@export var is_party_leader: bool = false
@export var is_selected: bool = false                        # UI selection flag
@export var is_controllable: bool = true                     # Accepts player commands

## —————————————————————————————————————————————
## World / State (lightweight)
## —————————————————————————————————————————————
@export var current_scene: String = ""                       # Last known map/scene id
@export var is_in_combat: bool = false
@export var is_dead: bool = false

## —————————————————————————————————————————————
## Meta / Persistence
## —————————————————————————————————————————————
@export var creation_timestamp: float = 0.0                  # Unix seconds; set by save/load layer
