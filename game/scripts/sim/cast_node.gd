class_name CastNode
extends RefCounted
## One shooting spell as compiled from a wand: its level, the boosts it carries and an
## optional payload (the spell a trigger or carrier releases).

var spell: SpellDef
var level := 1
var mods: Mods
var slot := -1
var trig: StringName = &""   # then | callback | loop | fork | finally | sleep | seed | wheel | ping | daemon
var trig_level := 1
var payload: CastNode
var pay_mana := 0.0          # what the payload costs each time it fires (callback/loop pay at fire time)
var dup := false             # cast twice (Mirror boost)
var cost := 0.0
## IF / ELSE (D2): `cond` marks the "enemy near" branch; `alt` (maybe null) fires instead
## when no enemy is close.
var cond := false
var alt: CastNode
## Pipeline (D2): seconds after the cast that this node goes out.
var delay := 0.0
var free_copy := false       # HEAD: a free copy of the first shooting spell
## Per-bullet values worked out once per compiled node (SpellRunner._prep), not per bullet.
var prepped := false
var p_r := 2.0
var p_burn := 0
var p_chill := 0
var p_chain := 0
var p_life := 1.0
var p_pierce := 0
var p_home := 0.0
var p_pull := 0.0
var p_static := false
var p_rot := 0
var p_mark := 0.0
var p_kw := 0
var p_spr: Array = []


func describe() -> String:
	var s := "%s%s" % [spell.title, "+".repeat(level - 1)]
	if mods.multi > 0:
		s += " x%d" % (mods.multi + 1)
	if payload:
		s += " [%s] -> %s" % [trig, payload.describe()]
	if cond:
		s = "IF near: %s ELSE: %s" % [s, alt.describe() if alt else "-"]
	return s
