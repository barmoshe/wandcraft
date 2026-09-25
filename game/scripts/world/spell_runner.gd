class_name SpellRunner
extends RefCounted
## Turns compiled casts into things in the world and runs them: bolts, beams, bursts,
## the Starwheel, and every trigger/carrier event. Ported from the prototype's rules.
##   seed / then / fork   fire their payload once, when the left spell ends
##   callback             fires on every hit (pays mana each time, with a cooldown)
##   loop                 fires repeatedly while the left spell flies (at least once)
##   wheel                sprays its payload 16 times while it spins
##   finally              fires when the left spell kills (up to 1/2/3 times)
##   sleep                fires after a set time, from wherever the left spell is (D2)
##   ping                 delivers its payload onto the nearest (or marked) enemy (D2)
##   daemon               a familiar that casts its payload every few seconds (D2)
## Behaviors: bolt, bomb, beam, burst, wheel, boomerang, mine, cone, orb, and (D2) wall,
## cloud, ping and the familiars (daemon, turret, duck).

const MAX_DEPTH := 3
const THEN_ADD := [0.3, 0.6, 1.2]
const FORK_MUL := [0.35, 0.45, 0.6]
const CALLBACK_CD := [0.3, 0.2, 0.1]
const LOOP_EVERY := 0.22
const WHEEL_SHOTS := 16
const SLEEP_T := [0.4, 0.3, 0.2]
const IF_RANGE := 60.0
const ORBIT_R := 28.0
const REVERSE_MUL := 1.6
const BG_EVERY := 3.0          # Daemon Rod: the background slot fires this often
const CAPS := {&"daemon": 1, &"turret": 2, &"duck": 1}

## Per-emission options, passed down from the wand or the trigger that fired.
class Opt:
	extends RefCounted
	var gm := 1.0          # global damage multiplier (relics later)
	var mul := 1.0         # trigger damage multiplier (fork, wheel)
	var add := 0.0         # flat damage added (THEN)
	var src: WandState     # who pays for callback/loop payloads
	var depth := 0
	var ignore := -1       # enemy uid this emission must not hit first
	var sc := 0.0          # base scatter in degrees

var world: World
var bullets: BulletPool
var cast_seq := 0
var casts_fired := 0
var summons: Array[Summon] = []
var max_depth := MAX_DEPTH         # Stack Overflow raises it (set per cast)
var knock_mul := 1.0               # Force Push
var legacy_slot := -1              # Legacy Code: the wand's last slot hits harder (-1: not owned)
var blockers: Array[Bullet] = []   # player bullets that stop enemy shots this tick
var _later: Array = []             # Pipeline: casts waiting for their turn


## A familiar on the field (Daemon, Watchdog Turret, Rubber Duck).
class Summon:
	extends RefCounted
	var kind: StringName
	var pos := Vector2.ZERO
	var life := 1.0
	var max_life := 1.0
	var every := 1.0
	var cd := 0.3
	var a := 0.0
	var dmg := 1.0
	var crit := 0.0
	var soak := 0
	var hit_cd := 0.0
	var color := Color.WHITE
	var payload: CastNode
	var pay_mana := 0.0
	var src: WandState
	var gm := 1.0


## Damage multiplier from the relics that look at this one cast (D3): Cold Start, Low
## Battery, Cornered, Loop Counter and Empty Set. Also shown by the HUD's counter pips.
func cast_bonus(w: WandState, low: bool, tenth: bool) -> float:
	var run := world.run
	var k := 1.0
	if w.fresh and run.has_relic(&"cold_start"):
		k *= 1.5
	if low and run.has_relic(&"low_battery"):
		k *= 1.4
	if run.has_relic(&"cornered") and world.cornered():
		k *= 1.25
	if tenth:
		k *= 2.0
		world.fx.ring(world.player.position + Vector2(0, -8), 2.0, 14.0, 0.25, Style.c("gold:4"))
	if run.has_relic(&"empty_set"):
		k *= 1.0 + 0.08 * w.slots.count(null)
	return k


func _init(w: World) -> void:
	world = w
	bullets = w.bullets


## Casts once from the wand. False when it cannot (empty, cooling down, out of mana).
func wand_fire(w: WandState, origin: Vector2, ang: float) -> bool:
	if w.cd > 0.0:
		return false
	var plan := WandProgram.compile(w)
	if plan.groups.is_empty():
		w.cd = 0.3
		return false
	var cost := 0.0 if Game.inf_mana else plan.mana
	var run := world.run
	# Watchdog: a wand left alone for a second casts its next cast for free
	var free := w.idle >= 1.0 and w.passive_level(&"watchdog") > 0
	# Loop Counter: every 10th cast is free (and hits twice as hard, below)
	var tenth := run != null and run.has_relic(&"loop_counter") and (casts_fired + 1) % 10 == 0
	if free or tenth:
		cost = 0.0
	if w.mana < cost:
		w.cd = 0.06
		return false
	var low := w.mana < w.max_mana() * 0.25
	w.mana -= cost
	w.idle = 0.0
	if free:
		world.fx.ring(origin, 2.0, 10.0, 0.2, Style.c("leaf:4"))
	w.ptr = plan.ptr
	w.acc = plan.acc
	w.casts += 1
	w.flash = plan.used[plan.used.size() - 1] if not plan.used.is_empty() else -1
	var sp := Relics.stat(run, "cast")
	var dl := maxf(0.03, (w.def.cast_delay + plan.delay_add) * sp)
	var rc := maxf(0.03, (w.recharge_time() + plan.recharge_add) * sp)
	w.cd = dl + (rc if plan.wrapped else 0.0)
	if plan.wrapped:
		w.rech = rc
		w.rech_max = rc
	max_depth = int(Relics.stat(run, "depth"))
	knock_mul = Relics.stat(run, "knock")
	legacy_slot = w.slots.size() - 1 if run != null and run.has_relic(&"legacy_code") else -1
	var opt := Opt.new()
	opt.src = w
	opt.sc = w.def.scatter
	opt.gm = Relics.dmg_mul(run, world.room_time) if run else 1.0
	if run:
		opt.gm *= cast_bonus(w, low, tenth)
	if run and run.has_relic(&"busy_wait") and world.player.still_t >= 0.6:
		opt.gm *= 1.6
		world.fx.ring(origin, 2.0, 12.0, 0.2, Color("#ffe066"))
	w.fresh = plan.wrapped
	world.player.still_t = 0.0
	cast_seq += 1
	casts_fired += 1
	# Race Condition: one cast in five fizzles (paid for, nothing comes out)
	if run and run.has_relic(&"race_condition") and world.rng.randf() < 0.2:
		world.fx.sparks(origin, 6, Style.c("glitch:3"), 60.0)
		world.fx.text(origin + Vector2(0, -10), "FIZZLE", Style.c("glitch:4"))
		return true
	for g in plan.groups:
		emit_cast(g, origin, ang, opt)
	# Stack Trace: every 7th cast also goes out backward
	if run and run.has_relic(&"stack_trace") and casts_fired % 7 == 0:
		cast_seq += 1
		for g in plan.groups:
			emit_cast(g, origin, ang + PI, opt)
	# Tail Call: the last cast before a recharge goes out twice
	if run and run.has_relic(&"tail_call") and plan.wrapped:
		cast_seq += 1
		for g in plan.groups:
			emit_cast(g, origin, ang + 0.18, opt)
	world.fx.ring(origin, 1.0, 6.0, 0.12, plan.groups[0].spell.color)
	Audio.cast(plan.groups[0].spell.id)
	Events.wand_cast.emit(w.flash)
	return true


## One compiled cast: copies (Twin Cast), fans (count/spread) and scatter.
## `now` skips a Pipeline delay (the scheduler calls back with it).
func emit_cast(c: CastNode, pos: Vector2, ang: float, opt: Opt, now := false) -> void:
	if c.delay > 0.0 and not now:
		_later.append({"t": c.delay, "c": c, "pos": pos, "ang": ang, "opt": opt, "hand": opt.depth == 0})
		return
	if c.cond and world.nearest_enemy(pos, IF_RANGE) == null:
		# IF / ELSE: no enemy close, so the ELSE branch goes instead
		if c.alt:
			emit_cast(c.alt, pos, ang, opt, true)
		return
	var d := c.spell
	var m := c.mods
	var lv := c.level
	var run := world.run
	var dmg := (d.damage_at(lv) * m.dmg * opt.gm + opt.add) * opt.mul
	if opt.depth > 0 and run and run.has_relic(&"recursion"):
		dmg *= 1.3
	if m.reverse:
		ang += PI
		dmg *= REVERSE_MUL
	if legacy_slot >= 0:
		dmg *= 2.5 if c.slot == legacy_slot else 0.8
	var crit := d.crit + m.crit + float(d.param("crit_add", lv, 0.0))
	var base := int(d.param("count", lv, 1))
	if base > 1 and run and run.has_relic(&"aperture"):
		base += 1
	var copies := mini(16, 1 + m.multi)
	var sc := deg_to_rad(maxf(0.0, opt.sc + m.scatter))
	var fan := deg_to_rad(float(d.param("spread", lv, 0.0))) if base > 1 else 0.0
	for k in copies:
		var ca := ang + (world.rng.randf() - 0.5) * sc * (0.3 if copies > 1 else 1.0)
		if copies > 1:
			ca += (k - (copies - 1) / 2.0) * maxf(0.12, sc / copies)
		for i in base:
			var aa := ca
			if base > 1:
				aa += (float(i) / (base - 1) - 0.5) * fan
			_emit_one(c, pos, aa, dmg, crit, opt, i)


func _emit_one(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt, idx: int) -> void:
	var d := c.spell
	match d.behavior:
		&"beam":
			_beam(c, pos, ang, dmg, crit, opt)
			return
		&"burst":
			_burst(c, pos + Vector2.from_angle(ang) * 8.0, ang, dmg, crit, opt)
			return
		&"cone":
			_cone(c, pos, ang, dmg, crit, opt)
			return
		&"wall":
			_wall(c, pos, ang, dmg, crit, opt)
			return
		&"ping":
			_ping(c, pos, ang, dmg, crit, opt)
			return
		&"daemon", &"turret", &"duck":
			_summon(c, pos, ang, dmg, crit, opt)
			return
	var spd := float(d.param("speed", c.level, 200.0)) * maxf(0.3, 1.0 + c.mods.spd)
	var b := _spawn(c, pos, ang, spd, dmg, crit, opt)
	if b == null:
		return
	match d.behavior:
		&"wheel":
			b.beh = &"wheel"
			b.size = 1.6
		&"boomerang":
			b.beh = &"boomerang"
			b.size = 1.4
		&"mine":
			b.beh = &"mine"
			b.size = 1.3
		&"orb":
			b.beh = &"orb"
			b.size = 2.0
		&"cloud":
			b.beh = &"cloud"
			b.size = 2.0
	if c.mods.orbit and opt.depth == 0 and b.beh != &"mine":
		# Orbit Rune: the spell circles the caster and eats enemy shots
		b.orbit = true
		b.orb_a = ang
		b.orb_r = 4.0
		b.home = 0.0
		b.life = maxf(b.life * 2.5, 2.0)
		b.max_life = b.life
		b.blocks = true
		b.ext = true
	if d.id == &"fan":
		b.color = Color.from_hsv(float(idx) / 7.0, 0.55, 1.0)


## Works out a node's per-bullet values once (a fan or a twin cast spawns many bullets).
func _prep(c: CastNode) -> void:
	var d := c.spell
	var m := c.mods
	var lv := c.level
	c.p_r = float(d.param("radius", lv, 2.0)) * minf(2.5, sqrt(m.area))
	c.p_burn = maxi(int(d.param("burn", lv, 0)), m.burn)
	c.p_chill = maxi(int(d.param("chill", lv, 0)), m.chill)
	c.p_chain = int(d.param("chain", lv, 0))
	c.p_life = float(d.param("life", lv, 1.0)) + m.dur_add
	c.p_pierce = int(d.param("pierce", lv, 0)) + m.pierce
	c.p_home = float(d.param("homing", lv, 0.0)) + m.home
	c.p_pull = maxf(float(d.param("pull", lv, 0.0)), m.pull)
	c.p_static = m.static_on or int(d.param("static", lv, 0)) > 0
	c.p_rot = maxi(m.rot, int(d.param("rot", lv, 0)))
	c.p_mark = float(d.param("mark", lv, 0.0))
	c.p_kw = keywords(d, m)
	c.p_spr = Projectiles.for_spell(d.id)
	c.p_blast = int(d.param("implode", lv, 0)) > 0
	c.p_split = maxi(m.split, int(d.param("split", lv, 0)))
	c.prepped = true


func _fill(b: Bullet, c: CastNode, pos: Vector2, ang: float, spd: float, dmg: float, crit: float, opt: Opt) -> void:
	if not c.prepped:
		_prep(c)
	var m := c.mods
	b.cast = c
	b.pos = pos
	b.prev = pos
	b.a = ang
	b.vel = Vector2.from_angle(ang) * spd
	b.dmg = dmg
	b.crit = crit
	b.r = c.p_r
	b.area = m.area
	b.burn = c.p_burn
	b.chill = c.p_chill
	b.chain = c.p_chain
	b.life = c.p_life
	b.max_life = b.life
	b.pierce = c.p_pierce
	b.bounce = m.bounce
	b.home = c.p_home
	b.split = c.p_split
	b.knock = m.knock * knock_mul
	b.slam = m.slam
	b.static_on = c.p_static
	b.rot = c.p_rot
	b.mark = c.p_mark
	b.siphon = m.siphon
	b.cost = c.cost
	b.kw = c.p_kw
	b.cell = c.p_spr[0]
	b.frames = c.p_spr[1]
	b.dir_sprite = c.p_spr[2]
	b.pull = c.p_pull
	b.color = c.spell.color
	b.trig = c.trig
	b.ext = c.trig == &"sleep"
	b.payload = c.payload
	b.pay_mana = c.pay_mana
	b.trig_lv = c.trig_level
	b.depth = opt.depth
	b.src = opt.src
	b.gm = opt.gm
	b.ignore = opt.ignore
	b.group = cast_seq


## Resist keywords a spell carries (bit 1 pierce, 2 blast, 4 shock): the answers to enemy
## shields, armor and wards (D4).
static func keywords(d: SpellDef, m: Mods) -> int:
	var k := 0
	if d.keywords.has("pierce") or m.kw_pierce:
		k |= 1
	if d.keywords.has("blast"):
		k |= 2
	if d.keywords.has("shock") or m.kw_shock:
		k |= 4
	return k


func _spawn(c: CastNode, pos: Vector2, ang: float, spd: float, dmg: float, crit: float, opt: Opt) -> Bullet:
	var b := bullets.spawn()
	if b == null:
		return null
	_fill(b, c, pos, ang, spd, dmg, crit, opt)
	return b


func _pseudo(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> Bullet:
	var b := Bullet.new()
	b.reset()
	_fill(b, c, pos, ang, 0.0, dmg, crit, opt)
	b.beh = &"pseudo"
	b.instant = true
	return b


## Prism Lance: instant line that stops at walls and at the first enemy it cannot pierce.
func _beam(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> void:
	var m := c.mods
	var length := float(c.spell.param("len", c.level, 150.0)) * (1.0 + m.spd * 0.5) + m.dur_add * 40.0
	var dir := Vector2.from_angle(ang)
	var reach := length
	var s := 4.0
	while s < length:
		var q := pos + dir * s
		if world.solid_at(q):
			reach = s
			world.break_crate(floori(q.x / World.TS), floori(q.y / World.TS))
			break
		s += 4.0
	var ps := _pseudo(c, pos, ang, dmg, crit, opt)
	var pierce := m.pierce
	var hits: Array = []
	for e in world.enemies:
		if e.dead or e.spawn_t > 0.0 or e.uid == opt.ignore:
			continue
		var along := clampf((e.position - pos).dot(dir), 0.0, reach)
		if (pos + dir * along).distance_squared_to(e.position) < (e.r + 2.5) * (e.r + 2.5):
			hits.append([along, e])
	hits.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var end_t := reach
	var last: Enemy = null
	for h in hits:
		var e: Enemy = h[1]
		ps.pos = e.position
		_strike(ps, e, pos, ps.dmg, 0.5)
		last = e
		if pierce > 0:
			pierce -= 1
			continue
		end_t = h[0]
		break
	var ep := pos + dir * end_t
	world.fx.beam(pos, ep, c.spell.color, 2.0)
	ps.pos = ep
	ps.vel = dir * 300.0
	end_bullet(ps, last)


## Rune Burst: an instant blast. Payloads delivered by carriers make it shine.
func _burst(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> void:
	var r := float(c.spell.param("area", c.level, 30.0)) * c.mods.area
	var ps := _pseudo(c, pos, ang, dmg, crit, opt)
	world.fx.explosion(pos, r, c.spell.color)
	world.fx.ring(pos, 2.0, r, 0.25, c.spell.color)
	world.fx.sparks(pos, 8, c.spell.color, 140.0)
	for k in world.hash.query(pos, r + 16.0):
		var e: Enemy = world.enemies[k]
		if e.dead or e.spawn_t > 0.0 or e.uid == opt.ignore:
			continue
		if e.position.distance_squared_to(pos) < (r + e.r) * (r + e.r):
			_strike(ps, e, pos, dmg, 1.3)
	world.shake(0.1)
	world.break_crates_in(pos, r, ps.burn > 0)
	Audio.sfx("boom", 0.1, -3.0)
	end_bullet(ps, null)


## Static Cone: instant lightning in a wedge in front of the caster.
func _cone(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> void:
	var reach := float(c.spell.param("len", c.level, 70.0)) * sqrt(c.mods.area)
	var half := deg_to_rad(float(c.spell.param("arc", c.level, 70.0))) * 0.5
	var ps := _pseudo(c, pos, ang, dmg, crit, opt)
	for k in 6:
		var a := ang + world.rng.randf_range(-half, half)
		var p0 := pos
		var n := 4
		for s in n:
			var p1 := pos + Vector2.from_angle(a + world.rng.randf_range(-0.2, 0.2)) * reach * (s + 1) / n
			world.fx.beam(p0, p1, c.spell.color, 1.0)
			p0 = p1
	for k in world.hash.query(pos, reach + 16.0):
		var e: Enemy = world.enemies[k]
		if e.dead or e.spawn_t > 0.0 or e.uid == opt.ignore:
			continue
		var to := e.position - pos
		var dist := to.length()
		if dist > reach + e.r:
			continue
		var slack := atan2(e.r, maxf(dist, 1.0))
		if absf(angle_difference(ang, to.angle())) > half + slack:
			continue
		ps.pos = e.position
		_strike(ps, e, pos, dmg, 0.8)
	ps.pos = pos + Vector2.from_angle(ang) * reach
	end_bullet(ps, null)


## Firewall: a short line of flames across the aim. Each flame is a still bullet that burns
## what walks through it and stops enemy shots. Only the middle flame carries a payload.
func _wall(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> void:
	var d := c.spell
	var ctr := pos + Vector2.from_angle(ang) * float(d.param("dist", c.level, 34.0))
	var half := float(d.param("len", c.level, 40.0)) * 0.5 * sqrt(c.mods.area)
	var side := Vector2.from_angle(ang + PI * 0.5)
	var n := 5
	for k in n:
		var p := ctr + side * lerpf(-half, half, float(k) / (n - 1))
		if world.solid_at(p):
			continue
		var b := _spawn(c, p, ang, 0.0, dmg, crit, opt)
		if b == null:
			break
		b.beh = &"wall"
		b.vel = Vector2.ZERO
		b.r = 5.0
		b.pierce = 99
		b.bounce = 0
		b.home = 0.0
		b.size = 1.2
		b.blocks = true
		b.ext = true
		b.spin = float(k) * 1.7
		if k != n / 2:
			b.trig = &""
			b.payload = null
	world.fx.ring(ctr, 2.0, half, 0.2, d.color)


## Ping: reaches the nearest (or the marked) enemy anywhere in the room at once and releases
## its payload right in front of it. With nobody to reach, the payload goes out at the wand.
func _ping(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> void:
	var tgt := target_near(pos, 400.0, opt.ignore)
	var ps := _pseudo(c, pos, ang, dmg, crit, opt)
	if tgt == null:
		ps.pos = pos + Vector2.from_angle(ang) * 10.0
		ps.vel = Vector2.from_angle(ang) * 200.0
		ps.alive = false
		fire_carry(ps, &"end", null, ang)
		return
	var dir := (tgt.position - pos).normalized()
	world.fx.beam(pos, tgt.position + Vector2(0, -4), c.spell.color, 1.0)
	world.fx.ring(tgt.position + Vector2(0, -4), 1.0, 9.0, 0.18, c.spell.color)
	ps.pos = tgt.position - dir * (tgt.r + 6.0)
	ps.vel = dir * 200.0
	world.hurt_enemy(tgt, dmg, pos, crit, 0.3, false, ps.kw)
	_apply(ps, tgt)
	ps.alive = false
	fire_carry(ps, &"end", null, dir.angle())


## Familiars: the Daemon orbits you and casts its payload; the Watchdog Turret shoots the
## nearest enemy; the Rubber Duck draws enemies and their shots. Each has a cap: a new one
## past the cap replaces the oldest.
func _summon(c: CastNode, pos: Vector2, ang: float, dmg: float, crit: float, opt: Opt) -> void:
	var d := c.spell
	var kind := d.behavior
	var same := summons.filter(func(s: Summon) -> bool: return s.kind == kind)
	if same.size() >= int(CAPS.get(kind, 1)):
		summons.erase(same[0])
	var s := Summon.new()
	s.kind = kind
	s.life = float(d.param("life", c.level, 8.0)) + c.mods.dur_add
	s.max_life = s.life
	s.every = float(d.param("every", c.level, 1.0))
	s.dmg = dmg
	s.crit = crit
	s.color = d.color
	s.src = opt.src
	s.gm = opt.gm
	s.a = ang
	s.payload = c.payload
	s.pay_mana = c.pay_mana
	s.soak = int(d.param("soak", c.level, 0))
	var drop := pos + Vector2.from_angle(ang) * (14.0 if kind == &"daemon" else 22.0)
	s.pos = drop if not world.solid_at(drop) else pos
	summons.append(s)
	world.fx.ring(s.pos, 2.0, 12.0, 0.3, s.color)
	world.fx.sparks(s.pos, 8, s.color, 70.0)


## The Rubber Duck, if one is out (enemies go for it instead of the player).
func decoy() -> Summon:
	for s in summons:
		if s.kind == &"duck":
			return s
	return null


## An enemy shot at p that the duck takes instead of the player. True when it did.
func decoy_takes(p: Vector2, r: float) -> bool:
	var dk := decoy()
	if dk == null or p.distance_squared_to(dk.pos + Vector2(0, -3)) > pow(r + 5.0, 2):
		return false
	_soak(dk)
	return true


func _soak(dk: Summon) -> void:
	dk.soak -= 1
	world.fx.sparks(dk.pos + Vector2(0, -4), 5, dk.color, 60.0)
	Audio.sfx("hit", 0.2, -6.0)
	if dk.soak <= 0:
		dk.life = 0.0


## True when a player bullet that stops enemy shots (Firewall, orbiting spells) covers p.
func blocked(p: Vector2, r: float) -> bool:
	for b in blockers:
		if b.alive and b.pos.distance_squared_to(p) < pow(b.r + r + 1.0, 2):
			return true
	return false


## The marked enemy (Hex Cursor) when there is one, else the nearest within max_d.
func target_near(p: Vector2, max_d: float, exclude := -1) -> Enemy:
	var mk := world.marked
	if mk and not mk.dead and mk.mark_t > 0.0 and mk.uid != exclude:
		return mk
	return world.nearest_enemy(p, max_d, exclude)


func _update_summons(dt: float) -> void:
	var pl := world.player
	var i := 0
	while i < summons.size():
		var s: Summon = summons[i]
		s.life -= dt
		if s.life <= 0.0:
			world.fx.sparks(s.pos, 8, s.color, 60.0)
			world.fx.ring(s.pos, 2.0, 10.0, 0.25, s.color)
			summons.remove_at(i)
			continue
		i += 1
		match s.kind:
			&"daemon":
				s.a += dt * 2.6
				var want := pl.position + Player.HAND + Vector2.from_angle(s.a) * 18.0
				s.pos = s.pos.lerp(want, 1.0 - pow(0.001, dt))
				s.cd -= dt
				if s.cd <= 0.0:
					var tgt := target_near(s.pos, 170.0)
					if tgt and world.los(s.pos, tgt.position):
						s.cd = s.every
						_familiar_cast(s, (tgt.position - s.pos).angle())
					else:
						s.cd = 0.2
			&"turret":
				s.cd -= dt
				if s.cd <= 0.0:
					var tgt := target_near(s.pos, 130.0)
					if tgt and world.los(s.pos, tgt.position):
						s.cd = s.every
						_familiar_bolt(s, s.pos + Vector2(0, -8), (tgt.position - s.pos).angle(), s.dmg)
					else:
						s.cd = 0.15
			&"duck":
				s.hit_cd -= dt
				if s.hit_cd <= 0.0:
					for k in world.hash.query(s.pos, 20.0):
						var e: Enemy = world.enemies[k]
						if not e.dead and e.spawn_t <= 0.0 and e.dmg > 0.0 and e.position.distance_to(s.pos) < e.r + 5.0:
							s.hit_cd = 0.5
							_soak(s)
							break


## A Daemon's shot: its payload (paid from the wand each time), or a small bolt of its own.
func _familiar_cast(s: Summon, ang: float) -> void:
	if s.payload == null:
		_familiar_bolt(s, s.pos, ang, 4.0 * s.gm)
		return
	if not _pay(s.src, s.pay_mana):
		return
	var opt := Opt.new()
	opt.gm = s.gm
	opt.src = s.src
	opt.depth = 1
	cast_seq += 1
	world.fx.ring(s.pos, 1.0, 6.0, 0.12, s.color)
	emit_cast(s.payload, s.pos, ang, opt, true)


func _familiar_bolt(s: Summon, p: Vector2, ang: float, dmg: float) -> void:
	var b := bullets.spawn()
	if b == null:
		return
	b.pos = p
	b.prev = p
	b.a = ang
	b.vel = Vector2.from_angle(ang) * 240.0
	b.dmg = dmg
	b.crit = s.crit
	b.r = 2.0
	b.life = 0.8
	b.max_life = 0.8
	b.color = s.color
	b.depth = MAX_DEPTH
	b.src = s.src
	world.fx.muzzle(p, ang, s.color)


## Draws familiars: the ground ones (turret, duck) under the actors, the daemon on top.
func draw_summons(ci: CanvasItem, top: bool) -> void:
	for s in summons:
		if (s.kind == &"daemon") != top:
			continue
		if s.life < 1.5 and fmod(s.life, 0.2) < 0.08:
			continue   # blinks out at the end
		var fr := int(world.time * 6.0) % 2
		var tex := Props.familiar(s.kind, fr)
		var p := s.pos
		if s.kind == &"daemon":
			p.y += roundf(sin(world.time * 5.0 + s.a) * 1.0)
		else:
			ci.draw_set_transform(s.pos + Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
			ci.draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.4))
			ci.draw_set_transform(Vector2.ZERO)
		ci.draw_texture(tex, (p - Vector2(tex.get_width() / 2.0, tex.get_height() - (tex.get_height() / 2.0 if s.kind == &"daemon" else 1.0))).round())


## Daemon Rod: the last slot fires on its own every few seconds at the nearest enemy.
func _background(dt: float) -> void:
	var pl := world.player
	if pl == null or pl.dead or world.run == null:
		return
	var w := pl.wand()
	var s: Variant = w.background()
	if s == null:
		return
	var d := Catalog.spell(s["id"])
	if not Catalog.is_caster(d):
		return
	w.bg_t -= dt
	if w.bg_t > 0.0:
		return
	var from := pl.position + Player.HAND
	var tgt := target_near(from, 200.0)
	if tgt == null:
		w.bg_t = 0.3
		return
	var c := CastNode.new()
	c.spell = d
	c.level = int(s["lv"])
	c.mods = Mods.new()
	c.cost = d.mana_at(c.level)
	if not _pay(w, c.cost):
		w.bg_t = 0.5
		return
	w.bg_t = BG_EVERY
	var opt := Opt.new()
	opt.src = w
	opt.gm = Relics.dmg_mul(world.run, world.room_time)
	cast_seq += 1
	world.fx.ring(from, 1.0, 8.0, 0.15, w.def.color)
	emit_cast(c, from, (tgt.position - from).angle(), opt)


## Ember Bolt and friends: an explosion where the bolt ends. Payload triggers still fire.
func _blast(b: Bullet, hit_e: Enemy) -> void:
	var r := float(b.cast.spell.param("area", b.cast.level, 18.0)) * b.area
	world.fx.explosion(b.pos, r, b.color)
	world.fx.ring(b.pos, 2.0, r, 0.25, b.color)
	world.fx.sparks(b.pos, 8, b.color, 120.0)
	for k in world.hash.query(b.pos, r + 16.0):
		var e: Enemy = world.enemies[k]
		if e.dead or e.spawn_t > 0.0 or e == hit_e:
			continue
		if e.position.distance_squared_to(b.pos) < (r + e.r) * (r + e.r):
			world.hurt_enemy(e, b.dmg * (1.0 if b.beh == &"mine" else 0.7), b.pos, b.crit, 1.2 * b.knock, false, b.kw | 2)
			_apply(b, e)
	world.shake(0.08)
	world.break_crates_in(b.pos, r, b.burn > 0)
	Audio.sfx("boom", 0.12, -5.0)


func update(dt: float) -> void:
	_run_later(dt)
	_update_summons(dt)
	_background(dt)
	blockers.clear()
	# hot loop: tile and hash lookups are inlined (this runs for ~1000 bullets a tick)
	var grid := world.grid
	var gw := world.gw
	var gh := world.gh
	var arr := bullets.active
	var i := 0
	while i < arr.size():
		var b: Bullet = arr[i]
		i += 1
		if not b.alive:
			continue
		b.prev = b.pos
		b.t += dt
		b.life -= dt
		if b.ext:
			if b.blocks:
				blockers.append(b)
			if b.trig == &"sleep" and not b.fired and b.t >= SLEEP_T[clampi(b.trig_lv, 1, 3) - 1]:
				fire_carry(b, &"fly", null)
			if b.orbit:
				var ctr := world.player.position + Player.HAND
				b.orb_a += dt * 6.0
				b.orb_r = minf(ORBIT_R, b.orb_r + dt * 110.0)
				var op := ctr + Vector2.from_angle(b.orb_a) * b.orb_r
				b.vel = (op - b.pos) / maxf(dt, 0.001)
				b.pos = op
				if b.life <= 0.0:
					end_bullet(b, null)
					continue
				_hit_scan(b)
				continue
		if b.trig == &"loop":
			b.loop_t -= dt
			if b.loop_t <= 0.0:
				b.loop_t = LOOP_EVERY
				fire_carry(b, &"fly", null)
		# plain bolts (most of a storm) skip the behaviour table
		if b.beh != &"bolt":
			match b.beh:
				&"wheel":
					b.spin += dt * 7.0
					b.vel *= pow(0.6, dt)
					b.wheel_t -= dt
					if b.trig == &"wheel" and b.wheel_t <= 0.0 and b.wheel_n < WHEEL_SHOTS:
						b.wheel_t = b.max_life / (WHEEL_SHOTS + 1)
						b.wheel_n += 1
						fire_carry(b, &"nova", null, b.spin + b.wheel_n * 2.4)
				&"boomerang":
					b.spin += dt * 18.0
					if not b.ret and b.t >= b.max_life * 0.45:
						b.ret = true
						b.hits.clear()
						b.life = maxf(b.life, 1.5)
					if b.ret:
						var home := world.player.position + Player.HAND
						b.vel = (home - b.pos).normalized() * maxf(230.0, b.vel.length())
						if b.pos.distance_squared_to(home) < 100.0:
							end_bullet(b, null)
							continue
				&"mine":
					b.vel *= pow(0.004, dt)
					b.spin += dt * 3.0
					if b.t > 0.35 and world.nearest_enemy(b.pos, 16.0) != null:
						end_bullet(b, null)
						continue
				&"orb", &"cloud", &"wall":
					b.spin += dt * 4.0
					if b.t - b.cb_t >= 0.25:
						b.cb_t = b.t
						b.hits.clear()
		if b.pull > 0.0 and fmod(b.t, 0.05) < dt:
			_pull(b, 0.05)
		if b.home > 0.0:
			# re-pick the target a few times a second, not every tick
			if b.tgt == null or b.tgt.dead or fmod(b.t, 0.15) < dt:
				b.tgt = world.nearest_enemy(b.pos, 150.0, b.ignore)
			if b.tgt:
				_steer(b, b.tgt.position, b.home, dt)
		var np := b.pos + b.vel * dt
		var tx := int(np.x) >> 4
		var ty := int(np.y) >> 4
		var tile := 1 if np.x < 0.0 or np.y < 0.0 or tx >= gw or ty >= gh else grid[ty * gw + tx]
		if b.ret:
			b.pos = np   # a returning disc flies over walls back to the hand
			if b.life <= 0.0:
				end_bullet(b, null)
				continue
			_hit_scan(b)
			continue
		if b.beh == &"mine" and tile != 0 and tile != 2:
			b.vel = Vector2.ZERO
			tile = 0
			np = b.pos
		if tile >= 6:
			world.tile_hit(tx, ty, b.burn > 0)
		if tile == 4:
			world.break_crate(tx, ty)
			world.fx.sparks(b.pos, 3, b.color, 50.0)
			end_bullet(b, null)
			continue
		if tile == 1 or tile == 3 or tile >= 6:
			if b.bounce > 0:
				var hx := world.solid_at(Vector2(np.x, b.pos.y))
				var hy := world.solid_at(Vector2(b.pos.x, np.y))
				if hx or not hy:
					b.vel.x = -b.vel.x
				if hy or not hx:
					b.vel.y = -b.vel.y
				b.bounce -= 1
				b.life += 0.35
				world.fx.sparks(b.pos, 2, b.color, 40.0)
			else:
				world.fx.sparks(b.pos, 4, b.color, 50.0)
				end_bullet(b, null)
				continue
		else:
			b.pos = np
		if b.life <= 0.0:
			end_bullet(b, null)
			continue
		if b.beh != &"mine":
			_hit_scan(b)
	bullets.compact()


## Pipeline: casts held back a few hundredths of a second go out from the hand, down the aim.
func _run_later(dt: float) -> void:
	if _later.is_empty():
		return
	var due := []
	for e in _later:
		e["t"] -= dt
		if e["t"] <= 0.0:
			due.append(e)
	for e in due:
		_later.erase(e)
		var pos: Vector2 = e["pos"]
		var ang: float = e["ang"]
		if e["hand"] and world.player and not world.player.dead:
			pos = world.player.tip()
			ang = world.player.aim
		emit_cast(e["c"], pos, ang, e["opt"], true)


## Drops everything in flight that belongs to the room (familiars, queued casts).
func clear_room() -> void:
	summons.clear()
	_later.clear()
	blockers.clear()


## Gravity: drags enemies near the spell toward it (bosses and their parts are too heavy).
func _pull(b: Bullet, dt: float) -> void:
	for k in world.hash.query(b.pos, 44.0):
		var e: Enemy = world.enemies[k]
		if e.dead or e.heavy or e.spawn_t > 0.0:
			continue
		var to := b.pos - e.position
		var d := to.length()
		if d < 3.0 or d > 44.0 + e.r:
			continue
		e.position = world.move_body(e.position, e.r, to / d * minf(b.pull * dt, d - 2.0), true)
		world.fall_check(e)


func _steer(b: Bullet, target: Vector2, rate: float, dt: float) -> void:
	var cur := b.vel.angle()
	var want := (target - b.pos).angle()
	var na := cur + clampf(angle_difference(cur, want), -rate * dt, rate * dt)
	b.vel = Vector2.from_angle(na) * b.vel.length()


func _hit_scan(b: Bullet) -> void:
	var h := world.hash
	var cols := h.cols
	var rows := h.rows
	var ccx := clampi(int(b.pos.x / SpatialHash.CELL), 0, cols - 1)
	var ccy := clampi(int(b.pos.y / SpatialHash.CELL), 0, rows - 1)
	if h.near[ccy * cols + ccx] == 0:
		return
	var rr := b.r + 10.0
	var x0 := clampi(int((b.pos.x - rr) / SpatialHash.CELL), 0, cols - 1)
	var x1 := clampi(int((b.pos.x + rr) / SpatialHash.CELL), 0, cols - 1)
	var y0 := clampi(int((b.pos.y - rr) / SpatialHash.CELL), 0, rows - 1)
	var y1 := clampi(int((b.pos.y + rr) / SpatialHash.CELL), 0, rows - 1)
	var enemies := world.enemies
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var cell: PackedInt32Array = h.cells[cy * cols + cx]
			for k in cell:
				if _hit_one(b, enemies[k]):
					return


## Tests one enemy against a bullet. True when the bullet is finished.
func _hit_one(b: Bullet, e: Enemy) -> bool:
	if e.dead or e.spawn_t > 0.0 or e.uid == b.ignore:
		return false
	var rr := e.r + b.r + 1.0
	if e.position.distance_squared_to(b.pos) > rr * rr or b.hits.has(e.uid):
		return false
	b.hits.append(e.uid)
	world.fx.sparks(b.pos, 3, b.color, 60.0)
	_strike(b, e, b.pos - b.vel * 0.02, b.dmg, 0.25 if b.beh == &"wall" or b.beh == &"cloud" else 1.0)
	if b.split > 0 and b.depth < MAX_DEPTH:
		_split(b, e)
	if not b.alive:
		return true
	if b.chain > 0:
		var nx := _next_unhit(b, e.position, 110.0)
		if nx:
			b.chain -= 1
			b.vel = (nx.position - b.pos).normalized() * maxf(200.0, b.vel.length())
			b.life = maxf(b.life, 0.5)
			b.home = 0.0
			world.fx.beam(e.position, b.pos, b.color, 1.0)
			return false
	if b.pierce > 0:
		b.pierce -= 1
		return false
	end_bullet(b, e)
	return true


func _next_unhit(b: Bullet, p: Vector2, max_d: float) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in world.enemies:
		if e.dead or e.spawn_t > 0.0 or b.hits.has(e.uid):
			continue
		var d := e.position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	return best


## One hit of a player spell on an enemy: damage, knockback, statuses, the Heavy Rune's
## wall slam, then the trigger events. Hot path (hundreds of hits a tick in a storm): the
## cheap checks come before any call.
func _strike(b: Bullet, e: Enemy, from: Vector2, dmg: float, kb: float) -> void:
	# the hit sounds like the spell's element (D8)
	world.hit_sound = Audio.hit_for(b.cast.spell.id) if b.cast else "hit"
	world.hurt_enemy(e, dmg, from, b.crit, kb * b.knock, false, b.kw)
	world.hit_sound = "hit"
	if b.burn > 0 or b.chill > 0 or b.static_on or b.rot > 0 or b.mark > 0.0:
		_apply(b, e)
	if b.slam and not e.dead and not e.heavy:
		var kd := (e.position - from).normalized()
		if world.solid_at(e.position + kd * (e.r + 8.0)):
			world.fx.text(e.position + Vector2(0, -14), "SLAM", Style.c("sand:4"))
			world.hurt_enemy(e, dmg * 0.5, e.position - kd, 0.0, 0.0)
			world.shake(0.08)
	if b.trig != &"":
		fire_carry(b, &"hit", e)
	if e.dead:
		_on_kill_check(b, e)


## Statuses and marks a spell leaves on what it hits.
func _apply(b: Bullet, e: Enemy) -> void:
	if b.burn > 0 or b.chill > 0:
		world.apply_status(e, b.burn, b.chill, b.dmg)
	if b.static_on:
		world.charge(e)
	if b.rot > 0:
		world.add_rot(e, b.rot)
	if b.mark > 0.0:
		world.mark(e, b.mark)


func _on_hit(b: Bullet, e: Enemy) -> void:
	if b.trig != &"":
		fire_carry(b, &"hit", e)


func _on_kill_check(b: Bullet, e: Enemy) -> void:
	if not e.dead:
		return
	if b.siphon > 0.0 and b.src and b.cost > 0.0:
		b.src.mana = minf(b.src.max_mana(), b.src.mana + b.cost * b.siphon)
		world.fx.sparks(e.position + Vector2(0, -4), 4, Style.c("leaf:4"), 50.0)
	if b.trig == &"finally":
		fire_carry(b, &"kill", e)


## Split Rune: on the first hit the bolt throws out `split` smaller bolts in a fan.
func _split(b: Bullet, e: Enemy) -> void:
	var n := b.split
	b.split = 0
	var base := b.vel.angle() if b.vel.length_squared() > 0.01 else b.a
	var spd := maxf(180.0, b.vel.length())
	for k in n:
		var s := bullets.spawn()
		if s == null:
			break
		var a := base + deg_to_rad(lerpf(-25.0, 25.0, float(k) / maxf(1.0, n - 1)))
		s.pos = e.position
		s.prev = e.position
		s.a = a
		s.vel = Vector2.from_angle(a) * spd
		s.dmg = b.dmg * 0.4
		s.crit = b.crit
		s.r = 1.5
		s.life = 0.5
		s.max_life = 0.5
		s.color = b.color
		s.burn = b.burn
		s.chill = b.chill
		s.rot = b.rot
		s.static_on = b.static_on
		s.kw = b.kw
		s.depth = MAX_DEPTH
		s.ignore = e.uid


func end_bullet(b: Bullet, hit_e: Enemy) -> void:
	if not b.alive:
		return
	b.alive = false
	if b.cast and (b.cast.spell.behavior == &"bomb" or b.beh == &"mine" or b.cast.p_blast) and b.depth <= max_depth:
		_blast(b, hit_e)
	if b.trig != &"":
		fire_carry(b, &"end", hit_e)


func _pay(w: WandState, mp: float) -> bool:
	if w == null or Game.inf_mana:
		return true
	if w.mana >= mp:
		w.mana -= mp
		return true
	return false


## Releases a bullet's payload. `ev` is hit | end | fly | nova.
func fire_carry(b: Bullet, ev: StringName, hit_e: Enemy, dir := NAN) -> void:
	var pl := b.payload
	if pl == null or b.depth >= max_depth:
		return
	if world.run and float(world.run.stats.get("first_trigger", -1.0)) < 0.0:
		world.run.stats["first_trigger"] = world.run.stats["time"]
	var n := 1
	var radial := false
	var mul := 1.0
	var add := 0.0
	var i := clampi(b.trig_lv, 1, 3) - 1
	match b.trig:
		&"seed":
			if ev != &"end" or b.fired:
				return
			b.fired = true
		&"then":
			if ev != &"end" or b.fired:
				return
			b.fired = true
			add = b.dmg * THEN_ADD[i]
		&"fork":
			if ev != &"end" or b.fired:
				return
			b.fired = true
			n = 4
			radial = true
			mul = FORK_MUL[i]
		&"callback":
			if ev != &"hit" or world.time - b.cb_t < CALLBACK_CD[i]:
				return
			if not _pay(b.src, b.pay_mana):
				return
			b.cb_t = world.time
		&"loop":
			# the loop body always runs at least once: a spell that ends (or an instant one)
			# before its first tick runs it where it ends
			var once := ev == &"end" and not b.fired
			if ev != &"fly" and not once:
				return
			if not _pay(b.src, b.pay_mana):
				return
			b.fired = true
		&"wheel":
			if ev != &"nova":
				return
			mul = 0.5
		&"finally":
			if ev != &"kill" or b.fin >= i + 1:
				return
			b.fin += 1
		&"sleep":
			# fires once its time is up, or where the left spell ends if that comes first
			if b.fired or (ev != &"fly" and ev != &"end"):
				return
			b.fired = true
		&"ping":
			if ev != &"end" or b.fired:
				return
			b.fired = true
		_:
			return
	var a0: float = dir if not is_nan(dir) else (b.vel.angle() if b.vel.length_squared() > 0.01 else b.a)
	if not radial and is_nan(dir):
		var tgt := target_near(b.pos, 170.0, hit_e.uid if hit_e else -1)
		if tgt:
			a0 = (tgt.position - b.pos).angle()
	if ev != &"nova":
		world.fx.ring(b.pos, 1.0, 9.0, 0.18, Color("#ffe066"))
		Audio.sfx("trigger", 0.1, -4.0)
	var opt := Opt.new()
	opt.gm = b.gm
	opt.mul = mul
	opt.add = add
	opt.src = b.src
	opt.depth = b.depth + 1
	opt.ignore = hit_e.uid if hit_e else -1
	cast_seq += 1
	for k in n:
		emit_cast(pl, b.pos, a0 + TAU * k / n + 0.4 if radial else a0, opt)
	# Event Loop: the payload goes out a second time, weaker
	if ev != &"fly" and ev != &"nova" and world.run and world.run.has_relic(&"event_loop"):
		var o2 := Opt.new()
		o2.gm = opt.gm
		o2.mul = opt.mul * 0.6
		o2.add = opt.add * 0.6
		o2.src = opt.src
		o2.depth = opt.depth
		o2.ignore = opt.ignore
		cast_seq += 1
		for k in n:
			emit_cast(pl, b.pos, (a0 + TAU * k / n + 0.4 if radial else a0) + 0.35, o2)
