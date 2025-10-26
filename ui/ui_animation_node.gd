class_name UiAnimationNode extends Node


## signal that the entrance animation has finished
signal entrance_animation_finished

@export_group("Options")

## flag indicating the animations should play when the node enters the scene
@export var is_entrance_animation: bool = false

## flag indicating the UiAnimationNode controls its transform from the center
@export var from_center: bool

## flag indicating whether the different animations should run simultaneously or sequentially
@export var run_parallel_animations: bool

## the list of properties that should be captured in the default valuesS
@export var properties: Array[String] = [
	"scale",
	"position",
	"rotation",
	"size",
	"self_modulate",
	"shader_param"
]

## The dictionary where default property values will be stored
var default_values: Dictionary

## close the property group
@export_group("")

@export_group("Entrance Animation Settings")

## the length in seconds a entrance animation should be delayed before playing
@export var entrance_delay: float = 0.0

## the length in seconds a entrance animation should last
@export var entrance_duration: float = 0.1

## the adjustments applied to the target's colour when entering
@export var entrance_modulate: Color = Color.WHITE

## the adjustments applied to the target's position when entering the UiAnimationNode target
@export var entrance_position: Vector2

## the rotation applied when entering the UiAnimationNode target
@export var entrance_rotation: float

## the scale factor applied when entering the UiAnimationNode target
@export var entrance_scale: Vector2 = Vector2(1, 1)

## the adjustment made to the target's size when entering
@export var entrance_size: Vector2 = Vector2(0, 0)

## the way the timing of the entrance animation is handled
@export var entrance_transition_type: Tween.TransitionType

## controls the way the entrance animation transition is applied to the interpolation (in the beginning, the end, or both)
@export var entrance_easing: Tween.EaseType

## the name of the shader parameter being adjusted
@export var entrance_shader_parameter: String

## close the property group
@export_group("")

@export_group("Entrance Shader Parameter Settings")

## the type of shader parameter being adjusted
@export var entrance_shader_parameter_type: Variant.Type

## the adjustment as a floating-point variable made to the target's shader parameter when entering
@export var entrance_shader_parameter_float_setting: float

## close the property group
@export_group("")

## the UiAnimationNode that plays immediately before this
@export var wait_for: UiAnimationNode

## The dictionary where entrance animation property values will be stored
var entrance_values: Dictionary

## close the property group
@export_group("")

@export_group("Hover Settings")

## the length in seconds a hover animation should be delayed before playing
@export var hover_delay: float = 0.0

## the length in seconds a hover animation should last
@export var hover_duration: float = 0.1

## the adjustments applied to the target's colour when hovering
@export var hover_modulate: Color = Color.WHITE

## the adjustments applied to the target's position when hovering the UiAnimationNode target
@export var hover_position: Vector2

## the rotation applied when hovering the UiAnimationNode target
@export var hover_rotation: float

## the scale factor applied when hovering the UiAnimationNode target
@export var hover_scale: Vector2 = Vector2(1, 1)

## the adjustment made to the target's size when hovering
@export var hover_size: Vector2 = Vector2(0, 0)

## the way the timing of the hover animation is handled
@export var hover_transition_type: Tween.TransitionType

## controls the way the hover animation transition is applied to the interpolation (in the beginning, the end, or both)
@export var hover_easing: Tween.EaseType

## The dictionary where hover animation property values will be stored
var hover_values: Dictionary

## close the property group
@export_group("")

## the Node that will get animated
var target: Control

## for entrance animations, we don't want any strange interpolations taking place, so use linear at all times
const IMMEDIATE_TRANSITION: int = Tween.TRANS_LINEAR


func _ready() -> void:
	target = get_parent()
	call_deferred("setup")


## Adds a tween animation.
func add_tween(values: Dictionary, is_parallel: bool, seconds: float, delay: float, transition: int, easing: int, is_entrance: bool = false) -> void:
	# make sure the scene tree is still active for this element. If a button that was being hovered makes a call to change the scene,
	# the UiAnimationNode will try to add a tween when the button is no longer being hovered, but at that point it has no scene tree
	if get_tree() != null:
		var tween: Tween = get_tree().create_tween()
		tween.set_parallel(is_parallel)
		tween.pause()

		for property: String in properties:
			if property == "shader_param":
				if values.has(property) and len(values[property]) > 0:
					tween.tween_property(
						target,
						"material:shader_parameter/{}".format([values[property]], "{}"),
						values["shader_param_value"],
						seconds
					).set_trans(transition).set_ease(easing)
			else:
				# tell the tween what it's animating, what property it's animating, what's the value, and how long does the animation take
				tween.tween_property(target, property, values[property], seconds).set_trans(transition).set_ease(easing)

		await get_tree().create_timer(delay).timeout
		tween.play()

		if is_entrance:
			await tween.finished
			entrance_animation_finished.emit()


## Runs the initial setup to capture default and hover animation property values.
func setup() -> void:
	if from_center:
		target.pivot_offset = target.size * 0.5

	default_values = {
		"scale": target.scale,
		"position": target.position,
		"rotation": target.rotation,
		"size": target.size,
		"self_modulate": target.modulate
	}

	entrance_values = {
		"scale": entrance_scale,
		"position": target.position + entrance_position,
		"rotation": target.rotation + deg_to_rad(entrance_rotation),
		"size": target.size + entrance_size,
		"self_modulate": entrance_modulate,
	}
	if len(entrance_shader_parameter) > 0:
		match entrance_shader_parameter_type:
			Variant.Type.TYPE_FLOAT:
				entrance_values["shader_param"] = entrance_shader_parameter
				entrance_values["shader_param_value"] = entrance_shader_parameter_float_setting

				default_values["shader_param"] = entrance_shader_parameter
				default_values["shader_param_value"] = target.material.get("shader_parameter/{}".format([entrance_shader_parameter], "{}"))

	hover_values = {
		"scale": hover_scale,
		"position": target.position + hover_position,
		"rotation": target.rotation + deg_to_rad(hover_rotation),
		"size": target.size + hover_size,
		"self_modulate": hover_modulate
	}
	target.mouse_entered.connect(add_tween.bind(
		hover_values,
		run_parallel_animations,
		hover_duration,
		hover_delay,
		hover_transition_type,
		hover_easing,
	))
	target.mouse_exited.connect(add_tween.bind(
		default_values,
		run_parallel_animations,
		hover_duration,
		hover_delay,
		hover_transition_type,
		hover_easing,
	))
	if wait_for:
		wait_for.entrance_animation_finished.connect(add_tween.bind(
			default_values,
			run_parallel_animations,
			entrance_duration,
			entrance_delay,
			entrance_transition_type,
			entrance_easing,
			true
		))

	if is_entrance_animation:
		on_entrance()
	else:
		entrance_animation_finished.emit()


func on_entrance() -> void:
	# on entrance, immediately apply the entrance values, and then TWEEN back to the default values
	# (the default values represent the UI elements as they would normally appear)
	add_tween(
		entrance_values,
		true,
		0.0,
		0.0,
		IMMEDIATE_TRANSITION,
		entrance_easing,
		true
	)

	if wait_for:
		pass
	else:
		add_tween(
			default_values,
			run_parallel_animations,
			entrance_duration,
			entrance_delay,
			entrance_transition_type,
			entrance_easing,
			true
		)
