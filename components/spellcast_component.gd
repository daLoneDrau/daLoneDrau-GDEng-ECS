class_name SpellcastComponent
extends EntityComponent


## the type of spell that was cast.
@export var spell_type: int

## the spell's level.
@export var level: int

## any spell flags
var flags: FlagSet = FlagSet.new()

## the spell's target
@export var target: String

## the spell's duration.
@export var duration: int
