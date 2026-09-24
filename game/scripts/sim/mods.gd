class_name Mods
extends RefCounted
## The boost accumulator: everything a boost changes about the shooting spells to its right.

var dmg := 1.0
var spd := 0.0
var area := 1.0
var dur_add := 0.0
var home := 0.0
var pierce := 0
var bounce := 0
var crit := 0.0
var multi := 0
var mp_mul := 1.0
var cnt_mp := 1.0
var shatter := 0
var scatter := 0.0
var burn := 0        # status level applied on hit (Ember Coat)
var chill := 0       # status level applied on hit (Frost Coat)
var split := 0       # bolts a spell splits into on its first hit (Split Rune)
var pull := 0.0      # px/s the spell drags nearby enemies (Gravity Rune)


func copy() -> Mods:
	var m := Mods.new()
	m.dmg = dmg; m.spd = spd; m.area = area; m.dur_add = dur_add; m.home = home
	m.pierce = pierce; m.bounce = bounce; m.crit = crit; m.multi = multi
	m.mp_mul = mp_mul; m.cnt_mp = cnt_mp; m.shatter = shatter; m.scatter = scatter
	m.burn = burn; m.chill = chill; m.split = split; m.pull = pull
	return m


## Payloads start a fresh count scope: copies and shatter stop at a trigger or carrier.
func payload_scope() -> Mods:
	var m := copy()
	m.multi = 0
	m.cnt_mp = 1.0
	m.shatter = 0
	return m
