extends "res://tests/unit/test_helpers.gd"
## Balance guardrail for World 1 (tools/balance.sh). The bot plays WITHOUT god mode over a
## set of seeds and we record survival, HP lost per room, run length and boss kill times.
## The bot aims perfectly but dodges poorly (it sidesteps the nearest bullet only), which
## makes it a fair stand-in for a new human player. Targets (research/balance-w1.md):
##   survival 40-85% (hard enough to matter, easy enough that a new player gets there in
##   2-4 tries), mini-boss 20-90 s, boss 30-150 s.
## D2 runs two bots: one that edits its wand (WandPlanner: picks rewards by what they add,
## equips from the bag, buys a slot at the forge) and one that never edits (takes the first
## offer, leaves the bag alone). The design wants editing to matter: the D4 targets are
## 60-80% for the editor and 15-30% for the non-editor; until D4's enemy counters land, only
## the editor is held to the band and the non-editor is reported.
## World 2 (0.17): a run is two worlds. The band holds for clearing World 1 (the Loop); the
## full-run win rate and Deadlock's time are reported beside it.
## 0.18 (research/difficulty.md): humans found 60% easy, and the bot never dashes, so the band
## moved down: the editor clears World 1 25-45% and wins the full run 5-15%; mini-bosses
## 20-75 s, the Loop 50-100 s, Deadlock 60-110 s; a room averages under a minute.
## 0.20 (research/world3-0.20.md): a run is three worlds; the Glitch's time and World 2's clear
## rate are reported. test_kernel_balance starts in the Kernel with a mid-game kit, so Data
## Race and the Glitch are measured even though few full runs get that far.

const DT := 1.0 / 60.0
const SEEDS := [11, 22, 33, 44, 55, 66, 77, 88, 99, 110]
const ONLY := []   # debugging: set to e.g. [99] to bench one seed
const LIMIT := 3600.0


func _play(seed_value: int, edits := true, start: RunState = null, dash := true) -> Dictionary:
	var world := World.new()
	world.auto_step = false
	runner.root.add_child(world)
	world.setup(seed_value)
	world.bot = true
	world.bot_dash = dash
	var res := {"won": false, "w1": false, "step": 0, "time": 0.0, "hp_lost": 0.0, "rooms": 0, "mini": -1.0, "boss": -1.0, "boss2": -1.0, "boss3": -1.0, "race": -1.0, "path": []}
	var state := {"victory": false, "defeat": false}
	world.ui_request.connect(_answer.bind(world, state, edits))
	var by: Dictionary = {}
	res["by"] = by
	var on_hurt := func(a: float) -> void:
		if not is_instance_valid(world):
			return
		res["hp_lost"] += a
		var k: String = world.player.last_hurt_by
		by[k] = float(by.get(k, 0.0)) + a
	Events.player_hurt.connect(on_hurt)
	world.start_run(start if start else RunState.create(seed_value))
	var t := 0.0
	var boss_t0 := -1.0
	var last_kind: StringName = &""
	var dashes := 0
	while t < LIMIT and not state["victory"] and not state["defeat"]:
		var was := world.player.dash_t
		world.step(DT)
		t += DT
		if was <= 0.0 and world.player.dash_t > 0.0:
			dashes += 1   # 0.22: the bot dashes
		if world.room_kind != last_kind:
			last_kind = world.room_kind
		if world.boss and not world.boss.dead and boss_t0 < 0.0:
			boss_t0 = t
		if world.boss and world.boss.dead and boss_t0 >= 0.0:
			var key: String = "mini" if world.room_kind == &"mini" else ["boss", "boss2", "boss3"][mini(world.run.world, 2)]
			if world.room_kind == &"mini" and world.run.world >= 2:
				key = "race"
			if res[key] < 0.0:
				res[key] = t - boss_t0
			boss_t0 = -1.0
	Events.player_hurt.disconnect(on_hurt)
	res["won"] = state["victory"]
	res["dashes"] = dashes
	res["w1"] = world.run.world >= 1 or state["victory"]
	res["w2"] = world.run.world >= 2 or state["victory"]
	res["world"] = world.run.world + 1
	res["step"] = world.run.step
	res["time"] = t
	res["rooms"] = int(world.run.stats["rooms"])
	res["path"] = world.run.path
	if t >= LIMIT:
		res["alive"] = world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).map(func(e: Enemy) -> String:
			return "%s hp%.0f sh%d ward%d arm%.0f @%s" % [e.kind, e.hp, e.shield_hp, e.ward_n, e.armor, e.position.round()])
		res["room"] = world.run.room
		res["wand"] = world.run.wand().slots.map(func(x: Variant) -> String: return "-" if x == null else String(x["id"]))
		print("    STALL seed %d: room %s, wand %s, alive %s" % [world.run.seed_value, res["room"], res["wand"], res["alive"]])
	var w_ref := world
	world = null
	w_ref.free()
	return res


func test_world_one_balance() -> void:
	if OS.get_environment("BENCH") == "kernel":
		return   # BENCH=kernel tools/balance.sh: only the World 3 bench
	# 0.23: the band is for a new player, whom the bot stands in for without dashing (it was
	# set that way in 0.18, when humans found the 60% it then cleared easy). With its dodge on
	# (0.22) it plays like a skilled player, reported and held to clearing World 1 more often.
	var rate := _bench(true, false)
	ok(rate >= 0.25 and rate <= 0.45, "editing bot: World 1 cleared %.0f%%, inside 25-45%%" % (rate * 100.0))
	var lazy := _bench(false, false)
	print("    editing %.0f%% vs never editing %.0f%%" % [rate * 100.0, lazy * 100.0])
	ok(lazy < rate, "editing the wand matters (%.0f%% vs %.0f%%)" % [rate * 100.0, lazy * 100.0])
	var skilled := _bench(true, true)
	ok(skilled >= 0.6 and skilled >= rate, "a player who dodges clears World 1 most runs (%.0f%%)" % (skilled * 100.0))


func _bench(edits: bool, dash: bool) -> float:
	Meta.core_only = true   # design v2: measure the pool a new player gets
	Game.god_mode = false
	Game.auto_fire = true
	SaveGame.enabled = false
	var wins := 0
	var full := 0
	var stalls := 0
	var bosses2: Array = []
	var bosses3: Array = []
	var w2 := 0
	var minis: Array = []
	var bosses: Array = []
	var room_t := 0.0
	var rooms := 0
	print("\n    %s bot%s" % ["EDITING" if edits else "NEVER-EDITING", ", DODGING" if dash else ""])
	print("    seed  result   w-step  time   hp_lost  rooms  dash  mini   boss  boss2")
	for s in (ONLY if not ONLY.is_empty() else SEEDS):
		var r := _play(s, edits, null, dash)
		if r["w1"]:
			wins += 1
		if r["won"]:
			full += 1
		if r["time"] >= LIMIT - 1.0:
			stalls += 1
		if r["boss2"] >= 0.0:
			bosses2.append(r["boss2"])
		if r["boss3"] >= 0.0:
			bosses3.append(r["boss3"])
		if r["w2"]:
			w2 += 1
		if r["mini"] >= 0.0:
			minis.append(r["mini"])
		if r["boss"] >= 0.0:
			bosses.append(r["boss"])
		room_t += r["time"]
		rooms += maxi(1, r["rooms"])
		print("    %4d  %-7s  %d-%-4d  %4.0fs  %7.0f  %5d  %4d  %5.0f  %5.0f  %5.0f   %s" % [s, "WIN" if r["won"] else ("W1" if r["w1"] else "died"), r["world"], r["step"], r["time"], r["hp_lost"], r["rooms"], r["dashes"], r["mini"], r["boss"], r["boss2"], _top_sources(r["by"])])
	var rate := float(wins) / SEEDS.size()
	print("    World 1 cleared %.0f%%, World 2 %.0f%%, full run won %.0f%%, mini-boss avg %.0fs, Loop avg %.0fs, Deadlock avg %.0fs, the Glitch avg %.0fs, %.0fs a room" % [rate * 100.0, 100.0 * w2 / SEEDS.size(), 100.0 * full / SEEDS.size(), _avg(minis), _avg(bosses), _avg(bosses2), _avg(bosses3), room_t / maxi(1, rooms)])
	SaveGame.enabled = true
	eq(stalls, 0, "every run ends (a stall means a bot or game bug, not balance)")
	if not edits or dash:
		return rate   # the fight lengths are held for the new-player bot
	if not minis.is_empty():
		ok(_avg(minis) >= 20.0 and _avg(minis) <= 75.0, "mini-boss takes 20-75 s (%.0f)" % _avg(minis))
	if not bosses.is_empty():
		ok(_avg(bosses) >= 50.0 and _avg(bosses) <= 100.0, "the Loop takes 50-100 s (%.0f)" % _avg(bosses))
	if not bosses2.is_empty():
		ok(_avg(bosses2) >= 60.0 and _avg(bosses2) <= 110.0, "Deadlock takes 60-110 s (%.0f)" % _avg(bosses2))
	ok(room_t / maxi(1, rooms) <= 60.0, "a room averages under a minute (%.0f s)" % (room_t / maxi(1, rooms)))
	return rate


## 0.20: World 3 on its own. Each seed starts in the Kernel with the kit a run tends to have by
## then (two wands, a few upgrades, the world-clear HP), the editing bot, no god mode.
func test_kernel_balance() -> void:
	if OS.get_environment("BENCH") == "w1":
		return   # BENCH=w1 tools/balance.sh: only the World 1 bench
	Meta.core_only = true
	Game.god_mode = false
	Game.auto_fire = true
	SaveGame.enabled = false
	var clears := 0
	var races: Array = []
	var glitches: Array = []
	print("\n    WORLD 3 (from the Kernel's start, mid-game kit)")
	print("    seed  result   w-step  time   hp_lost  dash  race  glitch   top damage")
	for s in (ONLY if not ONLY.is_empty() else SEEDS):
		var r := RunState.create(s)
		r.tutorial = false
		r.picked = true   # keep this kit: the start room's hero orb would swap it for a loadout
		r.world = 2
		r.step = 0
		r.max_hp = 140.0   # the start HP, two world-clear bonuses and a few hearts
		r.hp = r.max_hp
		r.gold = 120
		r.wand().set_slots([&"empower", &"twin", &"spark", &"ember"])
		r.add_wand(&"oak")
		r.wands[1].set_slots([&"keen", &"fan", &"then", &"burst", &"frost"])
		r.map = Chapter.make_map(r)
		var res := _play(s, true, r)
		if res["won"]:
			clears += 1
		if res["race"] >= 0.0:
			races.append(res["race"])
		if res["boss3"] >= 0.0:
			glitches.append(res["boss3"])
		print("    %4d  %-7s  %d-%-4d  %4.0fs  %7.0f  %4d  %5.0f  %5.0f   %s" % [s, "CLEAR" if res["won"] else "died", res["world"], res["step"], res["time"], res["hp_lost"], res["dashes"], res["race"], res["boss3"], _top_sources(res["by"])])
	print("    World 3 cleared %.0f%%, Data Race avg %.0fs, the Glitch avg %.0fs" % [100.0 * clears / SEEDS.size(), _avg(races), _avg(glitches)])
	SaveGame.enabled = true
	if not glitches.is_empty():
		ok(_avg(glitches) >= 60.0 and _avg(glitches) <= 150.0, "the Glitch takes 60-150 s (%.0f)" % _avg(glitches))
	if not races.is_empty():
		ok(_avg(races) >= 20.0 and _avg(races) <= 90.0, "Data Race takes 20-90 s (%.0f)" % _avg(races))


func _avg(a: Array) -> float:
	if a.is_empty():
		return -1.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()


func _answer(kind: StringName, data: Dictionary, world: World, state: Dictionary, edits: bool) -> void:
	if kind == &"reward":
		if edits:
			WandPlanner.bot_answer(world.run, kind, data["offer"])
		elif not data["offer"].is_empty():
			Rewards.grant(world.run, data["offer"][0])
		world.reward_taken()
	elif kind == &"shop" or kind == &"forge":
		if edits:
			WandPlanner.bot_answer(world.run, kind)
		world.ui_done()
	elif kind == &"world":
		world.enter_next_world()
	elif kind == &"victory":
		state["victory"] = true
	elif kind == &"defeat":
		state["defeat"] = true


func _top_sources(by: Dictionary) -> String:
	var keys := by.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return by[a] > by[b])
	return ", ".join(keys.slice(0, 4).map(func(k: String) -> String: return "%s %d" % [k, roundi(by[k])]))
