@abstract class_name GameEngine
extends Node


signal scene_will_change(from_key: String, to_key: String)
signal scene_changed(to_key: String, to_node: Node)
signal key_action_routed(action_name: String, phase: String)  # "START"/"END"

# scene stacking signals
signal scene_pushed(key: String, node: Node)
signal scene_popped(key: String)

## The current scene.
var assets: AssetsLibrary

## The [EntityManager]
var entity_manager: EntityManager = null

## The current scene.
var current_scene: String

## flag indicating whether debugging is turned on
var debugging_on: bool = true

## the number of game frames that have been processed. does not include time paused or within menus
var frames_processed: int

## the last keycode captured
var last_keycode: int

## the last scene that was playing.
var last_scene: String

## flag indicating whether the engine is running.
var running: bool

## The dictionary of scenes.
var scenes: Dictionary[String, Dictionary] = {}

## Scene stack for overlays/pauses (top is last). Each entry:
## { key: String, node: Node, path: String, paused_prev: bool, pause_tree: bool, blocker: Node? }
var scene_stack: Array[Dictionary] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("GameEngine._ready()")

	# set it so game engine keeps processing while scene tree is paused
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	running = true


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if running:
		# Tick current scene if it exposes update(delta)
		var node: Scene = get_tree().current_scene as Scene
		if node and node.has_method("update"):
			node.update(delta)

		# Tick ECS
		if entity_manager and entity_manager.has_method("update"):
			entity_manager.update()

		frames_processed += 1


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var event_key: InputEventKey = event as InputEventKey
		if event_key.echo:
			return  # drop auto-repeat unless you want it

		var key_name: String = OS.get_keycode_string(event_key.keycode)
		var phase: String = "START" if event_key.pressed else "END"
		var scene: Scene = get_tree().current_scene as Scene
		
		# Prefer explicit action for the key; fallback to "any_key"
		if scene and scene.has_method("has_action") and scene.has_method("do_action"):
			if scene.has_action(key_name):
				if scene.has_method("get_action"):
					var action_def: String = scene.get_action(key_name)
					scene.do_action(GameAction.new(action_def, phase))
					key_action_routed.emit(key_name, phase)
					if event_key.pressed:
						last_keycode = event_key.keycode
					return
			if scene.has_action("any_key"):
				if scene.has_method("get_registered_action"):
					var any_def: String = scene.get_registered_action("any_key")
					scene.do_action(GameAction.new(any_def, phase))
					key_action_routed.emit("any_key", phase)
					if event_key.pressed:
						last_keycode = event_key.keycode
					return
			# If your scenes don’t implement that API, nothing happens (safe no-op)

func _ensure_registered(scene_name: String, scene_path: String) -> bool:
	if scene_path.length() > 0 and not scenes.has(scene_name):
		register_scene(scene_name, scene_path)
	return scenes.has(scene_name)

## Register (or update) a scene key -> path
func register_scene(scene_name: String, scene_path: String) -> void:
	scenes[scene_name] = {"path": scene_path}
	

## Changes the current scene
func change_scene(scene_name:String, scene_path: String="") -> void:
	# check to see if current scene isn't the one we're supposed to be changing to
	# if scenes[scene]["name"] != get_tree().current_scene.name:

	if scene_path.length() > 0 and not scenes.has(scene_name):
		# this scene is new to us
		register_scene(scene_name, scene_path)
		
	if not scenes.has(scene_name):
		push_error("Scene '%s' not registered and no path provided." % scene_name)
		return

	# Derive last_scene key by comparing current scene name with registry (best effort)
	last_scene = ""
	var current_node: Scene = get_tree().current_scene as Scene

	if current_node:
		for key in scenes.keys():
			var entry: Dictionary = scenes.get(key, null)
			if entry == null:
				continue

			# Use node.name or better a custom scene key your scenes expose
			if current_node.name == scene_name or current_node.scene_file_path == entry.get("path", ""):
				last_scene = key
				break

	if last_scene == scene_name:
		# already on it
		return

	scene_will_change.emit(last_scene, scene_name)
	var ok := get_tree().change_scene_to_file(scenes[scene_name]["path"])
	if ok != OK:
		push_error("Failed to change scene to %s" % scenes[scene_name]["path"])
		return

	current_scene = scene_name
	print("GameEngine.change_scene() -\n\tchange scene to ", scenes[current_scene]["path"])

	# Inject engine reference if scene supports it
	var node := get_tree().current_scene
	if node and node.has_method("set_engine"):
		node.set_engine(self)

	scene_changed.emit(current_scene, node)

func _instantiate_scene(path: String) -> Scene:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("GameEngine: failed to load scene at %s" % path)
		return null
	print("Instantiated")
	var node: Scene = packed.instantiate() as Scene
	if node and node.has_method("set_engine"):
		node.set_engine(self)
	return node


## Convenience getter for your the [Scene] class
func get_current_scene() -> Scene:
	return get_tree().current_scene as Scene


func quit() -> void:
	get_tree().quit()


func update() -> void:
	# reserved if you want a non-delta loop; Run() is your main loop
	pass


func user_input() -> void:
	# polling-style input if you prefer continuous states; left blank intentionally
	pass


## Loads game resources
@abstract func load_resources() -> void


## Performs the action defined in the arguments
func perform_action(args: Array) -> void:
	var callable: Callable = Callable(self, args[0])
	if len(args) == 1:
		callable.call()
	else:
		args.remove_at(0)
		callable.callv(args)


## Puts an item entity into the world in front of the targeted entity.
@abstract func put_item_in_world_in_front_of_entity(_item_entity: Entity, _target_entity: Entity, _apply_physics: bool)



## —————————————————————————————————————————————
#region Scene stacking
## —————————————————————————————————————————————
## Push an overlay scene (e.g., pause menu) on top of the current scene.
## If pause_tree is true, SceneTree.paused is set while overlay is up.
## If process_when_paused is true, overlay's process_mode is WHEN_PAUSED so it keeps updating.
func push_scene(scene_name: String, scene_path: String = "", pause_tree: bool = true, process_when_paused: bool = true) -> Node:
	if not _ensure_registered(scene_name, scene_path):
		push_error("push_scene: scene '%s' not registered and no path provided" % scene_name)
		return null

	# prevent pushing same key twice in a row
	if not scene_stack.is_empty() and scene_stack.back().get("key", "") == scene_name:
		return scene_stack.back()["node"]

	var path: String = scenes[scene_name]["path"]
	var node := _instantiate_scene(path)
	if node == null:
		return null

	# If we’re pausing the game, remember previous pause state.
	var prev_paused := get_tree().paused
	if pause_tree:
		get_tree().paused = true

	# Ensure overlay continues processing if desired.
	if process_when_paused:
		# Godot 4: PROCESS_MODE_WHEN_PAUSED keeps it alive during pause.
		node.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Add overlay to the engine (top-level UI usually) so it renders above.
	add_child(node)
	move_child(node, get_child_count() - 1)

	# Track on the stack.
	scene_stack.append({
		"key": scene_name,
		"node": node,
		"path": path,
		"paused_prev": prev_paused,
		"pause_tree": pause_tree
	})

	scene_pushed.emit(scene_name, node)
	return node


## Push an overlay that behaves modally: pauses the game, blocks background input,
## keeps the overlay processing while paused, and grabs focus.
func push_modal_scene(
	scene_name: String,
	scene_path: String = "",
	with_scrim: bool = true,
	scrim_color: Color = Color(0, 0, 0, 0.5)
) -> Node:
	# Ensure registry entry exists
	if not _ensure_registered(scene_name, scene_path):
		push_error("push_modal_scene: scene '%s' not registered and no path provided" % scene_name)
		return null

	# Instantiate the modal overlay
	var path: String = scenes[scene_name]["path"]
	var overlay: Scene = _instantiate_scene(path)
	print("instantiating\n", path,"\n",overlay)
	if overlay == null:
		return null

	# Pause tree while modal is active
	var prev_paused := get_tree().paused
	get_tree().paused = true
	print("pausing")

	# tell last scene in stack to ignore mouse events
	get_tree().current_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ensure the overlay runs while paused
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# Make a blocking, full-rect scrim behind the overlay (captures clicks)
	print("make blocker")
	var blocker := _make_modal_blocker(with_scrim, scrim_color)
	if get_tree().current_scene.has_node("Overlays"):
		var overlay_node = get_tree().current_scene.get_node_or_null("Overlays")
		overlay_node.add_child(blocker)
		overlay_node.add_child(overlay)
	else:
		add_child(blocker)
		add_child(overlay)
	
		# Keep Z order: blocker just below overlay
		move_child(blocker, get_child_count() - 2)
		move_child(overlay, get_child_count() - 1)

	# If it's a Control, ensure it captures input & focus
	if is_instance_of(overlay, Control):
		#TODO - fix this casting
		# var c: Control = overlay as Control
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.focus_mode = Control.FOCUS_ALL
		
		# Optional: center or full-rect if your modal scene isn't already laid out
		# c.set_anchors_preset(Control.PRESET_CENTER) # or PRESET_FULL_RECT as needed
	elif overlay.has_method("grab_focus"):
		overlay.call("grab_focus")

	# Record on the stack (note: include blocker so pop can free it)
	var entry := {
		"key": scene_name,
		"node": overlay,
		"path": path,
		"paused_prev": prev_paused,
		"pause_tree": true,
		"blocker": blocker
	}
	scene_stack.append(entry)

	scene_pushed.emit(scene_name, overlay)
	return overlay


## Pop the top overlay; restores previous pause state if it paused the tree.
func pop_scene() -> void:
	if scene_stack.is_empty():
		return

	var top: Dictionary   = scene_stack.pop_back()
	var node: Node        = top["node"]
	var pause_tree: bool  = top["pause_tree"]
	var prev_paused: bool = top["paused_prev"]
	var key: String       = top["key"]
	var blocker: Node     = top.get("blocker", null)

	if is_instance_valid(node):
		node.queue_free()
	if is_instance_valid(blocker):
		blocker.queue_free()

	if pause_tree:
		get_tree().paused = prev_paused

	# tell last scene in stack it can handle mouse events again
	get_tree().current_scene.mouse_filter = Control.MOUSE_FILTER_STOP

	scene_popped.emit(key)


## Returns the top overlay node (if any), else null.
func peek_scene() -> Node:
	if scene_stack.is_empty():
		return null
	return scene_stack[scene_stack.size() - 1]["node"]


func _make_modal_blocker(with_scrim: bool, scrim_color: Color) -> Node:
	var blocker: Control
	if with_scrim:
		var cr := ColorRect.new()
		cr.color = scrim_color
		blocker = cr
	else:
		blocker = Control.new()

	blocker.name = "ModalBlocker"
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.focus_mode = Control.FOCUS_NONE
	blocker.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	return blocker


func is_modal_open() -> bool:
	if scene_stack.is_empty(): return false
	var top: Dictionary = scene_stack.back()
	return top.get("blocker", null) != null


func close_overlay(key: String) -> void:
	for i in range(scene_stack.size() - 1, -1, -1):
		if scene_stack[i].get("key", "") == key:
			var top: Dictionary = scene_stack.pop_at(i)
			var node: Node = top["node"]
			var blocker: Node = top.get("blocker", null)
			if is_instance_valid(node):
				node.queue_free()
			if is_instance_valid(blocker):
				blocker.queue_free()
			if top.get("pause_tree", false):
				# restore to the most recent remaining paused_prev or false
				var paused := false
				if not scene_stack.is_empty():
					paused = scene_stack.back().get("paused_prev", false)
				get_tree().paused = paused
			scene_popped.emit(key)
			return

func close_all_overlays() -> void:
	while not scene_stack.is_empty():
		pop_scene()
	
#endregion
