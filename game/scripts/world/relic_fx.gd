class_name RelicFx
extends RefCounted
## 0.21 relics that act in the world (the numbers and counters live in Relics, sim-side).
## SpellRunner owns one and calls it from a few one-line hooks, so the shared files stay small:
##   on_cast        Clean Streak and Wand Variety counts (Relics.note_cast); Summon Volley
##   blast_radius   Crowd Blast grows blasts with the enemies up
##   after_blast    Blast Share, Scorch Zone and Aftershock, once a blast has hit
##   summon_ended   Summon Refund
##   update         scorched ground and queued aftershocks
## Shock (Shock Charge, Charged Strike) and Frost (Frost Spread, Quick Freeze) hook World.

const SCORCH_T := 1.5        # Scorch Zone: how long the ground burns
const SCORCH_TICK := 0.5     # and how often it sets what stands on it on fire
const SCORCH_R := 0.8        # its radius, as a share of the blast's
const ECHO_DELAY := 0.25     # Aftershock: the second blast comes this long after
const ECHO_R := 0.7
const ECHO_DMG := 0.5
const REFUND := 0.5          # Summon Refund: share of the summon's mana given back
const VOLLEY_CD := 1.0       # Summon Volley: at most once a second

var world: World
var zones: Array = []        # {"pos", "r", "t", "tick", "dmg"}
var echoes: Array = []       # {"pos", "r", "dmg", "t", "kw", "color"}
var volley_at := -9.0


func _init(w: World) -> void:
	world = w


## A cast from a wand of the player's, before its damage is worked out.
func on_cast(w: WandState, plan: WandProgram.Plan) -> void:
	var run := world.run
	if run == null:
		return
	if run.has_relic(&"clean_build") or run.has_relic(&"code_coverage"):
		var ids: Array = []
		for i in plan.used:
			if i >= 0 and i < w.slots.size() and w.slots[i] != null:
				ids.append(w.slots[i]["id"])
		Relics.note_cast(run, w, ids)
	if run.has_relic(&"hive_mind") and world.time - volley_at >= VOLLEY_CD:
		var any := false
		for s in world.spells.summons:
			if s.kind != &"duck":
				s.cd = 0.0
				any = true
		if any:
			volley_at = world.time
			world.fx.ring(world.player.position + Vector2(0, -8), 2.0, 16.0, 0.25, Style.c("amber:3"))


## Crowd Blast: a blast's radius with the enemies up right now.
func blast_radius(r: float) -> float:
	var run := world.run
	if run == null or not run.has_relic(&"load_spike"):
		return r
	var alive := 0
	for e in world.enemies:
		if not e.dead and e.spawn_t <= 0.0:
			alive += 1
	return r * Relics.blast_mul(run, alive)


## After a blast at `pos` (radius r, damage dmg) hit the enemies in `caught`.
func after_blast(pos: Vector2, r: float, dmg: float, caught: Array, kw: int, color: Color) -> void:
	var run := world.run
	if run == null:
		return
	if run.has_relic(&"side_effects") and caught.size() >= 2:
		share_statuses(caught)
	if run.has_relic(&"burn_in"):
		zones.append({"pos": pos, "r": r * SCORCH_R, "t": SCORCH_T, "tick": 0.0, "dmg": dmg})
		world.fx.ring(pos, 2.0, r * SCORCH_R, 0.4, Style.c("ember:2"))
	if run.has_relic(&"chain_reaction"):
		echoes.append({"pos": pos, "r": r * ECHO_R, "dmg": dmg * ECHO_DMG, "t": ECHO_DELAY, "kw": kw, "color": color})


## Blast Share: every enemy caught gets each status any of them had (the strongest of each).
func share_statuses(caught: Array) -> void:
	var burn_t := 0.0
	var burn_dps := 0.0
	var chill_t := 0.0
	var chill_slow := 1.0
	var static_t := 0.0
	var rot_n := 0
	var rot_t := 0.0
	for e: Enemy in caught:
		if e.dead:
			continue
		if e.burn_t > burn_t:
			burn_t = e.burn_t
		burn_dps = maxf(burn_dps, e.burn_dps if e.burn_t > 0.0 else 0.0)
		if e.chill_t > 0.0 or e.frozen_t > 0.0:
			chill_t = maxf(chill_t, maxf(e.chill_t, 1.2))
			chill_slow = minf(chill_slow, e.chill_slow)
		static_t = maxf(static_t, e.static_t)
		if e.rot_n > rot_n:
			rot_n = e.rot_n
			rot_t = maxf(rot_t, e.rot_t)
	for e: Enemy in caught:
		var t: Enemy = e.forward if e.forward else e
		if t.dead:
			continue
		if burn_t > 0.0:
			t.burn_t = maxf(t.burn_t, burn_t)
			t.burn_dps = maxf(t.burn_dps, burn_dps)
		if chill_t > 0.0 and not (t is Boss):
			t.chill_t = maxf(t.chill_t, chill_t)
			t.chill_slow = minf(t.chill_slow, chill_slow)
		if static_t > 0.0:
			t.static_t = maxf(t.static_t, static_t)
		if rot_n > 0:
			t.rot_n = maxi(t.rot_n, rot_n)
			t.rot_t = maxf(t.rot_t, rot_t)


## Summon Refund: a summon that ran out gives its wand back part of what it cost.
func summon_ended(s: SpellRunner.Summon) -> void:
	var run := world.run
	if run == null or not run.has_relic(&"graceful_exit") or s.src == null or s.cost <= 0.0:
		return
	s.src.mana = minf(s.src.max_mana(), s.src.mana + s.cost * REFUND)
	world.fx.sparks(s.pos + Vector2(0, -4), 5, Style.c("leaf:4"), 50.0)


func update(dt: float) -> void:
	if not zones.is_empty():
		_zones(dt)
	if not echoes.is_empty():
		_echoes(dt)


## Scorch Zone: the ground keeps setting enemies on fire (so Frost meets it as Thermal Shock).
func _zones(dt: float) -> void:
	var i := 0
	while i < zones.size():
		var z: Dictionary = zones[i]
		z["t"] -= dt
		if z["t"] <= 0.0:
			zones.remove_at(i)
			continue
		i += 1
		z["tick"] -= dt
		if z["tick"] > 0.0:
			continue
		z["tick"] = SCORCH_TICK
		var p: Vector2 = z["pos"]
		var r: float = z["r"]
		world.fx.sparks(p, 3, Style.c("ember:3"), 25.0)
		for k in world.hash.query(p, r + 16.0):
			var e: Enemy = world.enemies[k]
			if not e.dead and e.spawn_t <= 0.0 and e.position.distance_squared_to(p) < (r + e.r) * (r + e.r):
				world.apply_status(e, 1, 0, z["dmg"])


## Aftershock: the queued second blasts. They never set off another.
func _echoes(dt: float) -> void:
	var due: Array = []
	for x in echoes:
		x["t"] -= dt
		if x["t"] <= 0.0:
			due.append(x)
	for x in due:
		echoes.erase(x)
		var p: Vector2 = x["pos"]
		var r: float = x["r"]
		world.fx.explosion(p, r, x["color"])
		world.fx.ring(p, 2.0, r, 0.25, x["color"])
		for k in world.hash.query(p, r + 16.0):
			var e: Enemy = world.enemies[k]
			if not e.dead and e.spawn_t <= 0.0 and e.position.distance_squared_to(p) < (r + e.r) * (r + e.r):
				world.hurt_enemy(e, x["dmg"], p, 0.0, 0.6, false, int(x["kw"]) | 2)
		world.shake(0.05)
		Audio.sfx("boom", p)


func clear_room() -> void:
	zones.clear()
	echoes.clear()
	volley_at = -9.0
	Relics.new_room(world.run)
