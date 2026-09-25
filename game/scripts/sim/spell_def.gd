class_name SpellDef
extends Resource
## One spell card. Content is original (see decisions/0002); values are per level [L1, L2, L3].

## RUNE: Debugger runes that edit the program itself (D2). FAMILIAR: a summon, cast like a
## shooting spell but it stays out (one of each kind at a time, see the spell text).
enum Kind { PROJ, BOOST, TRIG, PASSIVE, RUNE, FAMILIAR }

@export var id: StringName
@export var title: String
@export var desc: String
@export var kind: Kind = Kind.PROJ
@export var rarity := 0
@export var mana := PackedFloat32Array([0.0])
@export var damage := PackedFloat32Array([0.0])
@export var crit := 0.0
@export var cast_delay := 0.0
@export var recharge := 0.0
@export var color := Color.WHITE
## PROJ behaviour: bolt | beam | burst | wheel
@export var behavior: StringName = &"bolt"
## Carriers hold the next shooting spell as a payload: seed | wheel
@export var carrier: StringName = &""
## TRIG sits between two spells: then | callback | loop | fork
@export var trig: StringName = &""
## speed, radius, life, count, spread (deg), homing, pierce, area, ...
@export var params: Dictionary = {}
@export var icon_rows: PackedStringArray
## What changes at level 3 beyond the numbers (shown on the card as "L3: ...").
@export var l3 := ""
## Keywords this spell carries into hits: pierce (breaks shields), blast (breaks armor),
## shock (strips wards). Boosts and statuses can add more (D2/D4).
@export var keywords: PackedStringArray


static func at(arr: PackedFloat32Array, level: int) -> float:
	if arr.is_empty():
		return 0.0
	return arr[clampi(level, 1, arr.size()) - 1]


func mana_at(level: int) -> float:
	return at(mana, level)


func damage_at(level: int) -> float:
	return at(damage, level)


func param(key: String, level := 1, fallback: Variant = 0.0) -> Variant:
	var v: Variant = params.get(key, fallback)
	if v is Array or v is PackedFloat32Array:
		var a: Array = Array(v)
		return a[clampi(level, 1, a.size()) - 1]
	return v
