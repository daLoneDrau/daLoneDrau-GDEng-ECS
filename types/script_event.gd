# res://ecs/types/ScriptEvent.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Central registry of all scriptable event types used by the ECS.
## Each event type is a unique integer ID — no bitmasks — allowing
## hundreds or thousands of script events.
## Scripts now return a list of int IDs in `subscribed_events()`.
## Example:
##   return [ScriptEvent.DIED, ScriptEvent.ITEM_USED]
## The ScriptSystem dispatches by integer match, not bitmask.
class_name ScriptEvent


## —————————————————————————————————————————————
#region Core event categories (1–99)
## —————————————————————————————————————————————
const NONE:              int = 0
const DIED:              int = 1
const ITEM_USED:         int = 2
const ENTITY_COMBINED:   int = 3
const INITIALIZED:       int = 4   # formerly SPAWNED
const INTERACTED:        int = 5
const DAMAGED:           int = 6
const HEALED:            int = 7
const MOVED:             int = 8
const TURN_STARTED:      int = 9
const TURN_ENDED:        int = 10
#endregion

## —————————————————————————————————————————————
#region Economy (100–199)
## —————————————————————————————————————————————
const GOLD_CHANGED:      int = 100
const ITEM_SOLD:         int = 101
const ITEM_BOUGHT:       int = 102
const ITEM_APPRAISED:    int = 103
#endregion

## —————————————————————————————————————————————
#region Inventory & Equipment (200–299)
## —————————————————————————————————————————————
const ITEM_ADDED:        int = 200
const ITEM_REMOVED:      int = 201
const INVENTORY_FULL:    int = 202
const INVENTORY_OPENED:  int = 203
const INVENTORY_CLOSED:  int = 204

## Equipment-specific events
const ITEM_EQUIPPED:     int = 210
const ITEM_UNEQUIPPED:   int = 211
#endregion

## —————————————————————————————————————————————
#region Combat (300–399)
## —————————————————————————————————————————————
const ATTACK_STARTED:    int = 300
const ATTACK_HIT:        int = 301
const ATTACK_MISSED:     int = 302
const CRITICAL_HIT:      int = 303
const BLOCKED:           int = 304
const DODGED:            int = 305
#endregion

## —————————————————————————————————————————————
#region Dialogue & Interaction (400–499)
## —————————————————————————————————————————————
const DIALOGUE_STARTED:  int = 400
const DIALOGUE_CHOICE:   int = 401
const DIALOGUE_ENDED:    int = 402
const QUEST_ACCEPTED:    int = 403
const QUEST_COMPLETED:   int = 404
const QUEST_FAILED:      int = 405
#endregion

## —————————————————————————————————————————————
#region Magic / Effects (500–599)
## —————————————————————————————————————————————
const SPELL_CAST:        int = 500
const SPELL_HIT:         int = 501
const SPELL_MISCAST:     int = 502
const EFFECT_APPLIED:    int = 503
const EFFECT_EXPIRED:    int = 504
#endregion

## —————————————————————————————————————————————
#region Custom / Content Expansion (1000+)
## —————————————————————————————————————————————
## Reserve these for game-specific content packs.
const CUSTOM_A:          int = 1000
const CUSTOM_B:          int = 1001
const CUSTOM_C:          int = 1002
#endregion

## —————————————————————————————————————————————
## Registry utilities
## —————————————————————————————————————————————

static func all() -> Dictionary:
	return {
		"NONE": NONE,
		"DIED": DIED,
		"ITEM_USED": ITEM_USED,
		"ENTITY_COMBINED": ENTITY_COMBINED,
		"INITIALIZED": INITIALIZED,
		"INTERACTED": INTERACTED,
		"DAMAGED": DAMAGED,
		"HEALED": HEALED,
		"MOVED": MOVED,
		"TURN_STARTED": TURN_STARTED,
		"TURN_ENDED": TURN_ENDED,
		"GOLD_CHANGED": GOLD_CHANGED,
		"ITEM_SOLD": ITEM_SOLD,
		"ITEM_BOUGHT": ITEM_BOUGHT,
		"ITEM_APPRAISED": ITEM_APPRAISED,
		"ITEM_ADDED": ITEM_ADDED,
		"ITEM_REMOVED": ITEM_REMOVED,
		"INVENTORY_FULL": INVENTORY_FULL,
		"INVENTORY_OPENED": INVENTORY_OPENED,
		"INVENTORY_CLOSED": INVENTORY_CLOSED,
		"ITEM_EQUIPPED": ITEM_EQUIPPED,
		"ITEM_UNEQUIPPED": ITEM_UNEQUIPPED,
		"ATTACK_STARTED": ATTACK_STARTED,
		"ATTACK_HIT": ATTACK_HIT,
		"ATTACK_MISSED": ATTACK_MISSED,
		"CRITICAL_HIT": CRITICAL_HIT,
		"BLOCKED": BLOCKED,
		"DODGED": DODGED,
		"DIALOGUE_STARTED": DIALOGUE_STARTED,
		"DIALOGUE_CHOICE": DIALOGUE_CHOICE,
		"DIALOGUE_ENDED": DIALOGUE_ENDED,
		"QUEST_ACCEPTED": QUEST_ACCEPTED,
		"QUEST_COMPLETED": QUEST_COMPLETED,
		"QUEST_FAILED": QUEST_FAILED,
		"SPELL_CAST": SPELL_CAST,
		"SPELL_HIT": SPELL_HIT,
		"SPELL_MISCAST": SPELL_MISCAST,
		"EFFECT_APPLIED": EFFECT_APPLIED,
		"EFFECT_EXPIRED": EFFECT_EXPIRED,
		"CUSTOM_A": CUSTOM_A,
		"CUSTOM_B": CUSTOM_B,
		"CUSTOM_C": CUSTOM_C,
	}

static func name_from_id(event_id: int) -> String:
	for key in all().keys():
		if all()[key] == event_id:
			return key
	return "UNKNOWN(%d)" % event_id
