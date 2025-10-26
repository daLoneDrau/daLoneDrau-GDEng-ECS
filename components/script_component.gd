# res://ecs/components/script_component.gd
## —————————————————————————————————————————————
## Purpose
## —————————————————————————————————————————————
##
## Pure-data component declaring which logic scripts an entity uses.
## The ScriptSystem instantiates them, links context, and dispatches events.
@abstract class_name ScriptComponent
extends EntityComponent

var main_script: EntityScript        # must extend EntityScript
var master_script: EntityScript      # optional overlay
@export var master_first: bool = true
@export var role_hint: String = ""

## Runtime caches (populated by ScriptSystem)
var _instances: Array = []           # [EntityScript]
var _subscriptions: Array[int] = []  # merged event IDs

func get_script_chain() -> Array[Script]:
	var chain: Array[Script] = []
	if master_first:
		if master_script: chain.append(master_script)
		if main_script: chain.append(main_script)
	else:
		if main_script: chain.append(main_script)
		if master_script: chain.append(master_script)
	return chain

func has_any_scripts() -> bool:
	return main_script != null or master_script != null
