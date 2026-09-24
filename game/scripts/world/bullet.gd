class_name Bullet
extends RefCounted
## A pooled projectile (player or enemy). Plain data: SpellRunner and World update it,
## BulletPool draws it. Instant spells (beams, bursts) use a throwaway "pseudo" bullet so
## triggers work the same way for them.

var alive := false
var pos := Vector2.ZERO
var prev := Vector2.ZERO
var vel := Vector2.ZERO
var a := 0.0
var life := 1.0
var max_life := 1.0
var t := 0.0
var dmg := 1.0
var r := 2.0
var crit := 0.0
var pierce := 0
var bounce := 0
var home := 0.0
var accel := 0.0
var burn := 0
var chill := 0
var chain := 0
var area := 1.0
var color := Color.WHITE
var size := 1.0
var beh: StringName = &"bolt"   # bolt | wheel | pseudo
var instant := false
var cast: CastNode
var src: WandState
var depth := 0
var gm := 1.0
var group := 0
var hits := PackedInt32Array()
var shatter := 0
var ignore := -1
var tgt: Enemy
var by := ""        # enemy bullets: who fired it (damage attribution)
# trigger state
var trig: StringName = &""
var payload: CastNode
var pay_mana := 0.0
var trig_lv := 1
var fired := false
var cb_t := -9.0
var loop_t := 0.12
var wheel_n := 0
var wheel_t := 0.0
var spin := 0.0


func reset() -> void:
	alive = true
	t = 0.0
	hits.clear()
	fired = false
	cb_t = -9.0
	loop_t = 0.12
	wheel_n = 0
	wheel_t = 0.0
	spin = 0.0
	ignore = -1
	tgt = null
	trig = &""
	payload = null
	pay_mana = 0.0
	cast = null
	src = null
	shatter = 0
	pierce = 0
	bounce = 0
	home = 0.0
	accel = 0.0
	burn = 0
	chill = 0
	chain = 0
	area = 1.0
	crit = 0.0
	depth = 0
	gm = 1.0
	size = 1.0
	instant = false
	beh = &"bolt"
