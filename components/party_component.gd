# res://ecs/components/PartyComponent.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
## Structural data for a player-controlled party:
## identity, ordered roster, optional formation, and light world state.
## Pure data; no logic, no signals.
## Resources (gold, supplies) belong in PartyWalletComponent/Inventory.
class_name PartyComponent
extends EntityComponent

## —————————————————————————————————————————————
#region Identity
## —————————————————————————————————————————————
@export var party_id: StringName = &"party_1"
@export var name: String = "Adventuring Company"
@export var party_tags: int = 0  # Optional FlagSet (see PartyTags.gd if you add one)

#endregion

## —————————————————————————————————————————————
#region Roster (source of truth: order defines marching order)
## —————————————————————————————————————————————
@export var members_roster_ids: Array[StringName] = []  # e.g., [&"pc_01", &"pc_02", ...]
@export var leader_roster_id: StringName = &""          # convenience pointer (should exist in members)
@export var max_members: int = 6

#endregion

## —————————————————————————————————————————————
#region Formation (optional)
## —————————————————————————————————————————————
@export var formation_grid: Vector2i = Vector2i(3, 2)   # columns x rows (example)
# Map roster_id -> grid cell (col,row). Only used if your tactics layer needs it.
@export var formation_pos_by_roster: Dictionary = {}    # { &"pc_01": Vector2i(0,0), ... }

#endregion

## —————————————————————————————————————————————
#region World / Map (lightweight)
## —————————————————————————————————————————————
@export var world_scene: String = ""                    # overworld scene/map id
@export var world_pos: Vector2 = Vector2.ZERO           # overworld position

#endregion

## Optional dungeon hooks (uncomment if needed)
# @export var dungeon_scene: String = ""
# @export var dungeon_cell: Vector2i = Vector2i.ZERO

## —————————————————————————————————————————————
#region Meta
## —————————————————————————————————————————————
@export var creation_timestamp: float = 0.0
@export var last_used_timestamp: float = 0.0

#endregion
