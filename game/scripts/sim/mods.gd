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
var scatter := 0.0
var burn := 0        # status level applied on hit (Ember Coat)
var chill := 0       # status level applied on hit (Frost Coat)
var split := 0       # bolts a spell branches into on its first hit (Branch Rune)
var pull := 0.0      # px/s the spell drags nearby enemies (Gravity Rune)
# D2
var knock := 1.0     # knockback multiplier (Heavy)
var slam := false    # enemies knocked into a wall take the hit again at half (Heavy)
var static_on := false   # hits charge enemies (Static Coat)
var rot := 0         # Bitrot stacks per hit (Rot Coat)
var orbit := false   # spells circle the caster (Orbit Rune)
var reverse := false # spells fire backward at +60% (Reverse Rune; a second one cancels)
var siphon := 0.0    # share of the spell's mana refunded on a kill (Siphon Rune)
var kw_pierce := false   # hits break shields (Phase Through)
var kw_shock := false    # hits strip wards (Static Coat)
var goto_used := false   # GOTO fires once per cycle


func copy() -> Mods:
	var m := Mods.new()
	m.dmg = dmg; m.spd = spd; m.area = area; m.dur_add = dur_add; m.home = home
	m.pierce = pierce; m.bounce = bounce; m.crit = crit; m.multi = multi
	m.mp_mul = mp_mul; m.cnt_mp = cnt_mp; m.scatter = scatter
	m.burn = burn; m.chill = chill; m.split = split; m.pull = pull
	m.knock = knock; m.slam = slam; m.static_on = static_on; m.rot = rot; m.orbit = orbit
	m.reverse = reverse; m.siphon = siphon; m.kw_pierce = kw_pierce; m.kw_shock = kw_shock
	m.goto_used = goto_used
	return m


## Payloads start a fresh count scope: copies stop at a trigger or carrier.
func payload_scope() -> Mods:
	var m := copy()
	m.multi = 0
	m.cnt_mp = 1.0
	return m
