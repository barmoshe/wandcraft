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
var beh: StringName = &"bolt"   # bolt | wheel | pseudo | boomerang | mine | orb | wall | cloud
var split := 0
var pull := 0.0
var cell := 0          # Projectiles atlas cell (0: the tinted core)
var frames := 1
var dir_sprite := false
var ret := false    # Boomerang Disc: on its way back
var fin := 0        # Finally: payloads released so far
var instant := false
var cast: CastNode
var src: WandState
var depth := 0
var gm := 1.0
var group := 0
var hits := PackedInt32Array()
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
# D2
var knock := 1.0       # knockback multiplier (Heavy Rune)
var slam := false      # a knockback into a wall hits again (Heavy Rune)
var static_on := false # hits charge the enemy (Static Coat, Static Cone)
var rot := 0           # Bitrot stacks per hit
var mark := 0.0        # Hex Cursor: seconds the hit enemy stays marked
var siphon := 0.0      # share of `cost` refunded on a kill (Siphon Rune)
var cost := 0.0        # what this spell cost to cast (Siphon Rune)
var kw := 0            # resist keywords: 1 pierce, 2 blast, 4 shock (enemy counters, D4)
var orbit := false     # circles the caster (Orbit Rune)
var orb_a := 0.0
var orb_r := 0.0
var blocks := false    # destroys enemy shots it touches (Firewall, orbiting spells)
var ext := false       # has per-tick extras (blocks, orbit, Sleep): keeps the hot loop lean


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
	knock = 1.0
	slam = false
	static_on = false
	rot = 0
	mark = 0.0
	siphon = 0.0
	cost = 0.0
	kw = 0
	orbit = false
	orb_a = 0.0
	orb_r = 0.0
	blocks = false
	ext = false
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
	split = 0
	pull = 0.0
	cell = 0
	frames = 1
	dir_sprite = false
	ret = false
	fin = 0
