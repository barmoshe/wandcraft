class_name CastNode
extends RefCounted
## One shooting spell as compiled from a wand: its level, the boosts it carries and an
## optional payload (the spell a trigger or carrier releases).

var spell: SpellDef
var level := 1
var mods: Mods
var slot := -1
var trig: StringName = &""   # then | callback | loop | fork | seed | wheel
var trig_level := 1
var payload: CastNode
var pay_mana := 0.0          # what the payload costs each time it fires (callback/loop pay at fire time)
var dup := false             # cast twice (Mirror boost)
var cost := 0.0


func describe() -> String:
	var s := "%s%s" % [spell.title, "+".repeat(level - 1)]
	if mods.multi > 0:
		s += " x%d" % (mods.multi + 1)
	if payload:
		s += " [%s] -> %s" % [trig, payload.describe()]
	return s
