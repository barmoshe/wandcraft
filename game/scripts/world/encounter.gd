class_name Encounter
extends RefCounted
## The encounter director (D4, research/design-plan.md §3): what a fight room throws at you
## and when. Split out of World so the room code and the fight grammar can grow apart.
##   wave grammar   each wave is one anchor (ranged, area denial, tank or summoner) plus
##                  pressure (fodder, swarm, charger); a Lantern Wisp may join an anchor
##   pacing         no two anchors in one wave before the fourth room; the next wave comes
##                  when 70% of the current one is down
##   puzzle rooms   the fight right before the mini-boss and the boss tests one counter:
##                  Sentry Wall (pierce), Nursery (area), Golem Pair (blast)
##   spawn rules    a rune and a sound first; never within 96 px of the player or in the
##                  cone they are aiming down
## Pure choices over World's rng; World owns the enemies.

const ANCHORS_EARLY: Array[StringName] = [&"weaver", &"puffcap"]
const ANCHORS: Array[StringName] = [&"weaver", &"puffcap", &"sentry", &"golem", &"stump"]
const PRESSURE_EARLY: Array[StringName] = [&"slime", &"bugling"]
const PRESSURE: Array[StringName] = [&"slime", &"bugling", &"ram", &"tick"]
const NEXT_AT := 0.7
## Design v3: the Grove's variants of the Cellar's enemies (Enemy.DEFS, Bestiary.VARIANTS).
const GROVE_SWAP := {&"weaver": &"rot_weaver", &"tick": &"blink_tick", &"ram": &"thorn_ram"}          # share of a wave that must be down before the next one
const SAFE_R := 96.0
const CONE := 0.45            # radians either side of the aim where nothing spawns
const PUZZLES := {
	&"sentry_wall": {"title": "SENTRY WALL", "waves": [[[&"sentry", false], [&"sentry", false], [&"sentry", false], [&"slime", false], [&"slime", false]],
		[[&"bugling", false], [&"bugling", false], [&"bugling", false], [&"sentry", false]]]},
	&"nursery": {"title": "NURSERY", "waves": [[[&"stump", false], [&"stump", false], [&"slime", false]],
		[[&"bugling", false], [&"bugling", false], [&"bugling", false], [&"bugling", false], [&"tick", false]]]},
	&"golem_pair": {"title": "GOLEM PAIR", "waves": [[[&"golem", false], [&"golem", false]],
		[[&"slime", false], [&"slime", false], [&"tick", false], [&"tick", false]]]},
}


## Which puzzle the room at this step is, if any (the plain fight right before a boss).
static func puzzle_for(run: RunState, kind: StringName, rng: RandomNumberGenerator) -> StringName:
	if kind != &"fight" or run == null:
		return &""
	var nxt := run.step + 1
	if nxt >= Chapter.PLAN.size() or not (Chapter.PLAN[nxt] == &"mini" or Chapter.PLAN[nxt] == &"boss"):
		return &""
	if Chapter.PLAN[nxt] == &"mini":
		return [&"sentry_wall", &"nursery"][rng.randi() % 2]
	return [&"golem_pair", &"nursery"][rng.randi() % 2]


## The waves for a fight room: each wave an Array of [kind, elite].
static func compose(run: RunState, kind: StringName, rng: RandomNumberGenerator, puzzle := &"") -> Array:
	if puzzle != &"":
		return (PUZZLES[puzzle]["waves"] as Array).duplicate(true)
	var step := run.step if run else 1
	var mult := 1.3 if kind == &"challenge" else (1.15 if kind == &"glitch" else 1.0)
	var budget := (6.0 + step * 2.0) * mult
	var anchors: Array[StringName] = ANCHORS_EARLY if step <= 2 else ANCHORS
	var pressure: Array[StringName] = PRESSURE_EARLY if step <= 2 else PRESSURE
	var out: Array = []
	var n := 2
	for w in n:
		var b := budget / n * (1.2 if w == n - 1 else 0.9)
		var list: Array = []
		# the very first wave of the run is pressure only: learn to move and shoot first
		var n_anchor := 0 if step <= 1 and w == 0 else (1 if step < 3 else 1 + int(rng.randf() < 0.4))
		for k in n_anchor:
			var a: StringName = anchors[rng.randi() % anchors.size()]
			if float(Enemy.DEFS[a]["cost"]) > b + 1.0:
				break
			list.append([a, false])
			b -= float(Enemy.DEFS[a]["cost"])
		if n_anchor > 0 and step >= 3 and rng.randf() < 0.35 and b >= 3.0:
			list.append([&"wisp", false])
			b -= 3.0
		var guard := 0
		while b > 0.0 and list.size() < 14 and guard < 40:
			guard += 1
			var opts := pressure.filter(func(k: StringName) -> bool: return float(Enemy.DEFS[k]["cost"]) <= b + 1.0)
			if opts.is_empty():
				break
			var p: StringName = opts[rng.randi() % opts.size()]
			# buglings come in packs of three
			var pack := 3 if p == &"bugling" else 1
			for k in pack:
				list.append([p, false])
			b -= float(Enemy.DEFS[p]["cost"]) * pack
		out.append(list)
	# Bug Reports 1+: every fight's last wave carries an elite
	if run and run.heat >= 1 and not out[n - 1].any(func(e: Array) -> bool: return e[1]):
		var cands: Array = []
		for i in out[n - 1].size():
			if out[n - 1][i][0] != &"bugling":
				cands.append(i)
		if not cands.is_empty():
			out[n - 1][cands[rng.randi() % cands.size()]][1] = true
	# design v3: the Corrupted Grove swaps in its own enemies for most of the familiar ones
	if run and run.step >= Chapter.AREAS[1]["from"]:
		for w in out:
			for en in w:
				var alt: StringName = GROVE_SWAP.get(en[0], &"")
				if alt != &"" and rng.randf() < 0.65:
					en[0] = alt
	# design v2: the threat the door promised is in the room
	var threat := Chapter.threat_of(run.room) if run else &""
	match threat:
		&"shield":
			out[n - 1].append([&"sentry", false])
			if step >= 4:
				out[0].append([&"sentry", false])
		&"armor":
			out[n - 1].append([&"golem", false])
		&"ward":
			var k := 0
			for w in n:
				for en in out[w]:
					if en[0] != &"bugling" and en.size() < 3 and k < 3:
						en.append(&"warded")
						k += 1
			if k == 0:
				out[n - 1].append([&"slime", false, &"warded"])
		&"swarm":
			# packs, not a summoner: a Brood Stump in a big room's far corner never ends
			for w in n:
				for i in 3:
					out[w].append([&"bugling", false])
			out[n - 1].append([&"tick", false])
			out[n - 1].append([&"tick", false])
	if kind == &"challenge" or kind == &"glitch":
		var picks := anchors.duplicate()
		picks.append_array(pressure.filter(func(k: StringName) -> bool: return k != &"bugling"))
		out[n - 1].append([picks[rng.randi() % picks.size()], true])
	return out


## Spawn points for a wave: sockets clear of the player and out of their aim cone.
static func spawn_points(world: World) -> Array:
	var pl := world.player
	var ok_ := world.sockets.filter(func(p: Vector2) -> bool:
		var to := p - pl.position
		if to.length() < SAFE_R:
			return false
		return not (to.length() < 220.0 and absf(angle_difference(pl.aim, to.angle())) < CONE))
	if ok_.is_empty():
		ok_ = world.sockets.filter(func(p: Vector2) -> bool: return p.distance_to(pl.position) > 60.0)
	if ok_.is_empty():
		ok_ = world.sockets.duplicate()
	return ok_


## True when enough of the current wave is down for the next one to come in.
static func wave_done(current: Array) -> bool:
	if current.is_empty():
		return true
	# untyped on purpose: a wave enemy may already be freed, and a typed `e: Enemy` parameter
	# cannot take a freed object (the call errors and the enemy never counts as down)
	var down := 0
	for e: Variant in current:
		if not is_instance_valid(e) or (e as Enemy).dead:
			down += 1
	return float(down) / current.size() >= NEXT_AT
