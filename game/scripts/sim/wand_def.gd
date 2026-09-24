class_name WandDef
extends Resource
## A wand body. Original names and numbers (decisions/0002).

@export var id: StringName
@export var title: String
@export var rarity := 0
@export var slots := 5
@export var max_mana := 80.0
@export var regen := 18.0
@export var cast_delay := 0.15
@export var recharge := 0.5
@export var scatter := 5.0        # degrees
@export var simultaneous := 1
@export var reverse := false
@export var color := Color("#c79a5a")
