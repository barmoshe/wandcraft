class_name SpellRunner
extends RefCounted
## Turns compiled casts into things in the world and runs them: bolts, beams, bursts,
## the Starwheel, and every trigger/carrier event. Ported from the prototype's rules.
##   seed / then / fork   fire their payload once, when the left spell ends
##   callback             fires on every hit (pays mana each time, with a cooldown)
##   loop                 fires repeatedly while the left spell flies (at least once)
##   wheel                sprays its payload 16 times while it spins

const MAX_DEPTH := 3
const THEN_ADD := [0.3, 0.6, 1.2]
const FORK_MUL := [0.35, 0.45, 0.6]
const CALLBACK_CD := [0.3, 0.2, 0.1]
const LOOP_EVERY := 0.22
const WHEEL_SHOTS := 16

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
	if w.mana < cost:
		w.cd = 0.06
		return false
	w.mana -= cost
	w.ptr = plan.ptr
	w.acc = plan.acc
	w.casts += 1
	w.flash = plan.used[plan.used.size() - 1] if not plan.used.is_empty() else -1
	var run := world.run
	var oc := 0.85 if run and run.has_relic(&"overclock") else 1.0
	var dl := maxf(0.03, (w.def.cast_delay + plan.delay_add) * oc)
	var rc := maxf(0.03, (w.recharge_time() + plan.recharge_add) * oc)
	w.cd = dl + (rc if plan.wrapped else 0.0)
	if plan.wrapped:
		w.rech = rc
		w.rech_max = rc
	var opt := Opt.new()
	opt.src = w
	opt.sc = w.def.scatter
	opt.gm = Relics.dmg_mul(run, world.room_time) if run else 1.0
	cast_seq += 1
	casts_fired += 1
	for g in plan.groups:
		emit_cast(g, origin, ang, opt)
	# Echo Crystal: sometimes the whole cast happens again, for free
	if run and run.has_relic(&"echo") and world.rng.randf() < 0.15:
		cast_seq += 1
		var a2 := ang + world.rng.randf_range(-0.25, 0.25)
		for g in plan.groups:
			emit_cast(g, origin, a2, opt)
	world.fx.ring(origin, 1.0, 6.0, 0.12, plan.groups[0].spell.color)
	Audio.cast(plan.groups[0].spell.id)
	Events.wand_cast.emit(w.flash)
	return true


## One compiled cast: copies (Twin Cast), fans (count/spread) and scatter.
func emit_cast(c: CastNode, pos: Vector2, ang: float, opt: Opt) -> void:
	var d := c.spell
	var m := c.mods
	var lv := c.level
	var run := world.run
	var dmg := (d.damage_at(lv) * m.dmg * opt.gm + opt.add) * opt.mul
	if opt.depth > 0 and run and run.has_relic(&"recursion"):
		dmg *= 1.3
	var crit := d.crit + m.crit + (0.1 if run and run.has_relic(&"lucky_bit") else 0.0)
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
	var spd := float(d.param("speed", c.level, 200.0)) * maxf(0.3, 1.0 + c.mods.spd)
	if world.run and world.run.has_relic(&"keen_scope"):
		spd *= 1.15
	var b := _spawn(c, pos, ang, spd, dmg, crit, opt)
	if b == null:
		return
	if d.behavior == &"wheel":
		b.beh = &"wheel"
		b.size = 1.6
	if d.id == &"fan":
		b.color = Color.from_hsv(float(idx) / 7.0, 0.55, 1.0)


func _fill(b: Bullet, c: CastNode, pos: Vector2, ang: float, spd: float, dmg: float, crit: float, opt: Opt) -> void:
	var d := c.spell
	var m := c.mods
	var lv := c.level
	b.cast = c
	b.pos = pos
	b.prev = pos
	b.a = ang
	b.vel = Vector2.from_angle(ang) * spd
	b.dmg = dmg
	b.crit = crit
	b.r = float(d.param("radius", lv, 2.0)) * minf(2.5, sqrt(m.area))
	b.area = m.area
	b.burn = maxi(int(d.param("burn", lv, 0)), m.burn)
	b.chill = maxi(int(d.param("chill", lv, 0)), m.chill)
	b.chain = int(d.param("chain", lv, 0))
	b.life = float(d.param("life", lv, 1.0)) + m.dur_add
	b.max_life = b.life
	b.pierce = int(d.param("pierce", lv, 0)) + m.pierce
	b.bounce = m.bounce + (1 if world.run and world.run.has_relic(&"bounce_core") else 0)
	b.home = float(d.param("homing", lv, 0.0)) + m.home
	b.shatter = m.shatter
	b.color = d.color
	b.trig = c.trig
	b.payload = c.payload
	b.pay_mana = c.pay_mana
	b.trig_lv = c.trig_level
	b.depth = opt.depth
	b.src = opt.src
	b.gm = opt.gm
	b.ignore = opt.ignore
	b.group = cast_seq


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
		world.hurt_enemy(e, ps.dmg, pos, crit, 0.5)
		world.apply_status(e, ps.burn, ps.chill, ps.dmg)
		_on_hit(ps, e)
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
	var r := float(c.spell.param("area", c.level, 30.0)) * c.mods.area * world.area_mul()
	var ps := _pseudo(c, pos, ang, dmg, crit, opt)
	world.fx.ring(pos, 2.0, r, 0.25, c.spell.color)
	world.fx.sparks(pos, 14, c.spell.color, 140.0)
	for k in world.hash.query(pos, r + 16.0):
		var e: Enemy = world.enemies[k]
		if e.dead or e.spawn_t > 0.0 or e.uid == opt.ignore:
			continue
		if e.position.distance_squared_to(pos) < (r + e.r) * (r + e.r):
			world.hurt_enemy(e, dmg, pos, crit, 1.3)
			world.apply_status(e, ps.burn, ps.chill, dmg)
			_on_hit(ps, e)
	world.shake(0.1)
	world.break_crates_in(pos, r)
	Audio.sfx("boom", 0.1, -3.0)
	end_bullet(ps, null)


## Ember Bolt and friends: an explosion where the bolt ends. Payload triggers still fire.
func _blast(b: Bullet, hit_e: Enemy) -> void:
	var r := float(b.cast.spell.param("area", b.cast.level, 18.0)) * b.area * world.area_mul()
	world.fx.ring(b.pos, 2.0, r, 0.25, b.color)
	world.fx.sparks(b.pos, 12, b.color, 120.0)
	for k in world.hash.query(b.pos, r + 16.0):
		var e: Enemy = world.enemies[k]
		if e.dead or e.spawn_t > 0.0 or e == hit_e:
			continue
		if e.position.distance_squared_to(b.pos) < (r + e.r) * (r + e.r):
			world.hurt_enemy(e, b.dmg * 0.7, b.pos, b.crit, 1.2)
			world.apply_status(e, b.burn, b.chill, b.dmg)
	world.shake(0.08)
	world.break_crates_in(b.pos, r)
	Audio.sfx("boom", 0.12, -5.0)


func update(dt: float) -> void:
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
		if b.trig == &"loop":
			b.loop_t -= dt
			if b.loop_t <= 0.0:
				b.loop_t = LOOP_EVERY
				fire_carry(b, &"fly", null)
		if b.beh == &"wheel":
			b.spin += dt * 7.0
			b.vel *= pow(0.6, dt)
			b.wheel_t -= dt
			if b.trig == &"wheel" and b.wheel_t <= 0.0 and b.wheel_n < WHEEL_SHOTS:
				b.wheel_t = b.max_life / (WHEEL_SHOTS + 1)
				b.wheel_n += 1
				fire_carry(b, &"nova", null, b.spin + b.wheel_n * 2.4)
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
		if tile == 4:
			world.break_crate(tx, ty)
			world.fx.sparks(b.pos, 3, b.color, 50.0)
			end_bullet(b, null)
			continue
		if tile == 1 or tile == 3:
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
		_hit_scan(b)
	bullets.compact()


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
	world.hurt_enemy(e, b.dmg, b.pos - b.vel * 0.02, b.crit, 1.0)
	world.apply_status(e, b.burn, b.chill, b.dmg)
	_on_hit(b, e)
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


func _on_hit(b: Bullet, e: Enemy) -> void:
	if b.trig != &"":
		fire_carry(b, &"hit", e)


func end_bullet(b: Bullet, hit_e: Enemy) -> void:
	if not b.alive:
		return
	b.alive = false
	if b.cast and b.cast.spell.behavior == &"bomb" and b.depth <= MAX_DEPTH:
		_blast(b, hit_e)
	if b.shatter > 0 and b.depth < MAX_DEPTH:
		var n := mini(12, b.shatter)
		var base := b.vel.angle() if b.vel.length_squared() > 0.01 else b.a
		for k in n:
			var s := bullets.spawn()
			if s == null:
				break
			s.pos = b.pos
			s.prev = b.pos
			s.vel = Vector2.from_angle(base + TAU * k / n + world.rng.randf_range(-0.2, 0.2)) * 210.0
			s.dmg = b.dmg * 0.33
			s.crit = b.crit
			s.r = 1.5
			s.life = 0.45
			s.max_life = 0.45
			s.color = b.color
			s.depth = MAX_DEPTH
			s.ignore = hit_e.uid if hit_e else -1
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
	if pl == null or b.depth >= MAX_DEPTH:
		return
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
		_:
			return
	var a0: float = dir if not is_nan(dir) else (b.vel.angle() if b.vel.length_squared() > 0.01 else b.a)
	if not radial and is_nan(dir):
		var tgt := world.nearest_enemy(b.pos, 170.0, hit_e.uid if hit_e else -1)
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
