extends "res://tests/unit/world_fixture.gd"
## The 0.21 arsenal (research/arsenal-0.21.md): 12 spells for the thin builds (Burn, Frost, Rot,
## Shock, summons) and the rule-breaking runes, and 6 wands with a rule. One behaviour test per
## card, in the world where it acts there, else in the compiler.

const SPELLS := [&"flame_graph", &"crunch_time", &"breakpoint", &"code_freeze", &"cruft", &"worm",
	&"daisy_chain", &"pair_prog", &"squash", &"pointer", &"symlink", &"on_load"]
const WANDS := [&"channel_rod", &"unsafe_staff", &"singleton", &"decorator_rod", &"hot_reload", &"monorepo"]


## An empty room with dummies at the given spots.
func _room(spots: Array) -> Array[Enemy]:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)
	var out: Array[Enemy] = []
	for p in spots:
		out.append(_dummy(p))
	world.hash.rebuild(world.enemies)
	return out


func _live(id: StringName) -> Array[Bullet]:
	var out: Array[Bullet] = []
	for b in world.bullets.active:
		if b.alive and b.cast and b.cast.spell.id == id:
			out.append(b)
	return out


## Casts a wand already in hand once more (clears its cooldown first).
func _again(w: WandState, ang := -PI / 2.0) -> bool:
	w.cd = 0.0
	world.player.aim = ang
	world.hash.rebuild(world.enemies)
	return world.spells.wand_fire(w, world.player.tip(), ang)


## Puts a wand in hand without casting it.
func _hold(ids: Array, wand_id := &"apprentice") -> WandState:
	var w := wand(ids, wand_id)
	world.run.wands[0] = w
	world.run.cur = 0
	return w


func _ids(plans: Array) -> Array:
	var out: Array = []
	for plan: WandProgram.Plan in plans:
		for g in plan.groups:
			out.append(g.spell.id)
	return out


## Steps until `cond` holds (at most `seconds`). True when it did.
func _until(cond: Callable, seconds := 1.5) -> bool:
	for k in int(seconds / DT):
		world.step(DT)
		if cond.call():
			return true
	return false


## The aim from the wand tip at an enemy.
func _at(e: Enemy) -> float:
	return (e.position + Vector2(0, -4) - world.player.tip()).angle()


## The damage one cast of `ids` does to the range's dummies.
func _one_cast(ids: Array, wand_id := &"apprentice") -> float:
	_range_setup()
	_fire(ids, wand_id)
	_steps(0.8)
	return world.damage_done


# ---- Burn ----

func test_flame_graph_spreads_fire_when_a_burning_enemy_dies() -> void:
	var d := _room([Vector2(207, 170), Vector2(236, 162)])
	_fire([&"flame_graph"])
	ok(_until(func() -> bool: return d[0].burn_t > 0.0), "the bolt sets the first enemy burning")
	ok(d[0].burn_share, "with fire that spreads")
	eq(d[1].burn_t, 0.0, "its neighbour is not burning yet")
	d[0].hp = 1.0
	world.hurt_enemy(d[0], 5.0, d[0].position, 0.0, 0.0)
	ok(d[0].dead, "the burning enemy dies")
	ok(d[1].burn_t > 0.0, "and its neighbour catches fire")
	ok(d[1].burn_share, "fire that spreads on from it")
	# a plain Ember Bolt's fire stays put
	var e := _room([Vector2(207, 170), Vector2(236, 162)])
	_fire([&"ember"])
	ok(_until(func() -> bool: return e[0].burn_t > 0.0), "an Ember Bolt sets it burning")
	ok(not e[0].burn_share, "with plain fire")
	e[0].hp = 1.0
	world.hurt_enemy(e[0], 5.0, e[0].position, 0.0, 0.0)
	eq(e[1].burn_t, 0.0, "which does not spread")


func test_crunch_time_burns_faster_below_half_hp() -> void:
	var c := WandProgram.compile(wand(["crunch_time", "mote"]), 0, Mods.new())
	eq(c.groups[0].mods.burn, 1, "spells on its right set fire")
	ok(is_equal_approx(c.groups[0].mods.rush, 1.5), "1.5x as fast at level 1")
	var d := _room([Vector2(207, 170)])
	_fire([&"crunch_time", &"mote"])
	ok(_until(func() -> bool: return d[0].burn_t > 0.0), "the Mote sets it on fire")
	eq(d[0].burn_rate, 1.0, "at full HP the fire burns as usual")
	var slow := d[0].max_hp - d[0].hp
	_steps(1.0)
	slow = d[0].max_hp - d[0].hp - slow
	var e := _room([Vector2(207, 170)])
	world.player.hp = world.player.max_hp * 0.4
	_fire([&"crunch_time", &"mote"])
	ok(_until(func() -> bool: return e[0].burn_t > 0.0), "and again below half HP")
	ok(is_equal_approx(e[0].burn_rate, 1.5), "now its fire ticks 1.5x as fast")
	var fast := e[0].max_hp - e[0].hp
	_steps(1.0)
	fast = e[0].max_hp - e[0].hp - fast
	ok(fast > slow * 1.3, "and burns more in a second (%.1f vs %.1f)" % [fast, slow])
	world.player.hp = world.player.max_hp


# ---- Frost ----

func test_breakpoint_shatters_a_frozen_enemy() -> void:
	var d := _room([Vector2(207, 170), Vector2(226, 166)])
	d[0].frozen_t = 3.0
	_fire([&"breakpoint"])
	ok(_until(func() -> bool: return d[0].hp < d[0].max_hp), "the shard lands")
	eq(d[0].frozen_t, 0.0, "the ice shatters")
	ok(d[1].hp < d[1].max_hp, "and the blast hurts the enemy next to it")
	eq(d[1].chill_n, 2, "and chills it twice")
	var hit := d[0].max_hp - d[0].hp
	ok(hit >= 5.0 * 2.4, "the frozen one takes the shard plus 1.5x (%.1f)" % hit)
	var e := _room([Vector2(207, 170), Vector2(226, 166)])
	_fire([&"breakpoint"])
	ok(_until(func() -> bool: return e[0].hp < e[0].max_hp), "a shard on an enemy that is not frozen")
	eq(e[0].chill_n, 1, "only chills it")
	eq(e[1].hp, e[1].max_hp, "and nothing shatters")


func test_code_freeze_chills_longer_and_freezes_at_two() -> void:
	var d := _room([Vector2(207, 170)])
	var w := _hold([&"frost_coat", &"mote"])
	_again(w, _at(d[0]))
	ok(_until(func() -> bool: return d[0].chill_t > 0.0), "a plain wand chills")
	var plain := d[0].chill_t
	_steps(0.3)
	_again(w, _at(d[0]))
	ok(_until(func() -> bool: return d[0].chill_n >= 2), "twice")
	eq(d[0].frozen_t, 0.0, "2 chills do not freeze")
	var e := _room([Vector2(207, 170)])
	var cf := _hold([&"code_freeze", &"frost_coat", &"mote"])
	_again(cf, _at(e[0]))
	ok(_until(func() -> bool: return e[0].chill_t > 0.0), "with Code Freeze")
	ok(e[0].chill_t > plain * 1.3, "the chill lasts 40%% longer (%.2f vs %.2f)" % [e[0].chill_t, plain])
	_steps(0.3)
	_again(cf, _at(e[0]))
	ok(_until(func() -> bool: return e[0].frozen_t > 0.0), "and 2 chills freeze")


# ---- Rot ----

func test_cruft_grows_with_rooms_cleared() -> void:
	world.run.stats["rooms"] = 0
	var fresh := _one_cast([&"cruft"])
	world.run.stats["rooms"] = 10
	var old := _one_cast([&"cruft"])
	ok(fresh > 0.0, "a Cruft bolt lands (%.1f)" % fresh)
	ok(absf(old - fresh * 1.4) < 0.6, "+4%% per room: 1.4x after ten rooms (%.1f vs %.1f)" % [old, fresh])
	var d := _room([Vector2(207, 170)])
	_fire([&"cruft"])
	ok(_until(func() -> bool: return d[0].rot_n > 0), "it adds Bitrot")


func test_worm_spreads_bitrot_on_a_kill() -> void:
	var d := _room([Vector2(207, 170), Vector2(230, 160), Vector2(150, 100)])
	d[0].hp = 1.0
	_fire([&"worm", &"mote"])
	ok(_until(func() -> bool: return d[0].dead), "the Mote kills")
	eq(d[1].rot_n, 2, "the enemy nearby gets 2 Bitrot")
	eq(d[2].rot_n, 0, "one far off gets none")
	var e := _room([Vector2(207, 170), Vector2(230, 160)])
	e[0].hp = 1.0
	_fire([&"mote"])
	ok(_until(func() -> bool: return e[0].dead), "a plain kill")
	eq(e[1].rot_n, 0, "spreads nothing")


# ---- Shock ----

func test_daisy_chain_hits_harder_each_jump() -> void:
	var d := _room([Vector2(207, 170), Vector2(232, 150), Vector2(207, 128), Vector2(232, 108)])
	_fire([&"daisy_chain"])
	_steps(1.0)
	var losses: Array = []
	for e in d:
		if e.hp < e.max_hp:
			losses.append(e.max_hp - e.hp)
	losses.sort()
	ok(losses.size() >= 3, "it jumps through at least 3 enemies (%d)" % losses.size())
	if losses.size() >= 3:
		ok(is_equal_approx(losses[1], losses[0] * 1.25), "the next hit +25%% (%.2f, %.2f)" % [losses[0], losses[1]])
		ok(is_equal_approx(losses[2], losses[1] * 1.25), "and +25%% again (%.2f)" % losses[2])
	eq(SpellRunner.keywords(Catalog.spell(&"daisy_chain"), Mods.new()) & 4, 4, "it carries Shock")


# ---- summons ----

func test_pair_programmer_copies_the_spell_on_its_right() -> void:
	_range_setup()
	var w := _hold([&"pair_prog", &"mote"])
	_again(w)
	var pairs := world.spells.summons.filter(func(s: SpellRunner.Summon) -> bool: return s.kind == &"pair")
	eq(pairs.size(), 1, "a partner is out")
	if pairs.is_empty():
		return
	eq(pairs[0].echo_slot, 1, "watching the Mote's slot")
	var m0 := w.mana
	_again(w)
	var motes := _live(&"mote")
	eq(motes.size(), 2, "casting the Mote casts a copy too")
	eq(m0 - w.mana, 3.0, "the copy is free")
	var dmgs := motes.map(func(b: Bullet) -> float: return b.dmg)
	dmgs.sort()
	ok(is_equal_approx(dmgs[0], dmgs[1] * 0.5), "at 50%% damage (%.1f, %.1f)" % [dmgs[0], dmgs[1]])
	_steps(1.0)
	ok(world.damage_done > 0.0, "and they hit")
	_again(w)
	eq(world.spells.summons.filter(func(s: SpellRunner.Summon) -> bool: return s.kind == &"pair").size(), 1, "one at a time")


func test_squash_merges_two_summons() -> void:
	var c := WandProgram.compile(wand(["squash", "turret", "turret"]), 0, Mods.new())
	eq(c.groups.size(), 1, "one summon")
	var t := c.groups[0]
	eq(t.spell.id, &"turret", "the first one")
	ok(is_equal_approx(t.mods.dmg, 1.5), "1.5x as strong")
	ok(is_equal_approx(t.mods.dur_add, 8.0), "stays out as long as both")
	eq(c.mana, 4.0 + 9.0 + 9.0, "both are paid for")
	ok(c.wrapped, "and both slots are used")
	var lone := WandProgram.compile(wand(["squash", "mote"]), 0, Mods.new())
	ok(is_equal_approx(lone.groups[0].mods.dmg, 1.0), "with no summon on its right it does nothing")
	_range_setup()
	_fire([&"squash", &"turret", &"turret"])
	eq(world.spells.summons.size(), 1, "one turret on the field")
	if not world.spells.summons.is_empty():
		var s: SpellRunner.Summon = world.spells.summons[0]
		ok(is_equal_approx(s.life, 16.0), "for 16 s")
		ok(is_equal_approx(s.dmg, 7.5), "at 1.5x damage")
	_range_setup()
	_fire([&"squash", &"duck", &"turret"])
	eq(world.spells.summons[0].kind, &"duck", "a duck and a turret become a duck")
	eq(world.spells.summons[0].soak, 5, "that soaks 1.5x the hits (rounded)")


# ---- runes ----

func test_pointer_copies_the_next_spell_and_leaves_it() -> void:
	var plans := WandProgram.preview_cycle(wand(["pointer", "mote", "needle"]))
	eq(_ids(plans), [&"mote", &"mote", &"needle"], "a copy, then the Mote in its turn")
	ok(is_equal_approx(plans[0].groups[0].mods.dmg, 0.6), "the copy at 60%")
	eq(plans[0].mana, 2.0 + 3.0, "the rune plus the copy's mana")
	eq(plans[1].groups[0].slot, 1, "the Mote still casts from its slot")
	var boosted := WandProgram.preview_cycle(wand(["pointer", "empower", "mote"]))
	ok(is_equal_approx(boosted[0].groups[0].mods.dmg, 0.6), "boosts not read yet stay out of the copy")
	ok(is_equal_approx(boosted[1].groups[0].mods.dmg, 1.25), "the Mote keeps its boost")
	_range_setup()
	var w := _hold([&"pointer", &"mote"])
	_again(w)
	eq(_live(&"mote").size(), 1, "the copy flies")


func test_symlink_reads_as_the_leftmost_slot() -> void:
	var b := WandProgram.preview_cycle(wand(["empower", "mote", "symlink", "needle"]))
	eq(_ids(b), [&"mote", &"needle"], "a boost in slot 1: the Symlink is that boost")
	ok(is_equal_approx(b[1].groups[0].mods.dmg, 1.5625), "Empower counts again (%.4f)" % b[1].groups[0].mods.dmg)
	eq(b[1].mana, 2.0 + 5.0 + 2.0, "paid as the boost, plus its own mana")
	var s := WandProgram.preview_cycle(wand(["mote", "symlink", "needle"]))
	eq(_ids(s), [&"mote", &"mote", &"needle"], "a spell in slot 1: the Symlink casts it again")
	eq(s[1].groups[0].slot, 1, "from its own slot")
	eq(_ids(WandProgram.preview_cycle(wand([null, "symlink", "mote"]))), [&"mote"], "an empty slot 1: nothing")
	var h := WandProgram.preview_cycle(wand(["head", "mote", "symlink"]))
	eq(_ids(h), [&"mote", &"mote", &"mote"], "a rune in slot 1 works through it: HEAD's copy, twice")
	ok(h[2].groups[0].free_copy, "the Symlink's copy is HEAD's free one")


func test_on_load_fires_at_each_recharge() -> void:
	var w := wand(["on_load", "needle", "mote"])
	eq(_ids(WandProgram.preview_cycle(w)), [&"mote"], "the Needle is out of the wand's order")
	eq(w.read_pos(1), -1, "and shows no number")
	_range_setup()
	var h := _hold([&"on_load", &"needle", &"mote"])
	var m0 := h.mana
	_again(h, PI / 2.0)   # the Mote goes away from the dummies
	eq(_live(&"needle").size(), 1, "the recharge set off the Needle")
	eq(m0 - h.mana, 3.0 + 2.0, "which paid its full mana at level 1")
	var n: Bullet = _live(&"needle")[0]
	ok(n.vel.y < 0.0, "at the nearest enemy, not down the aim")
	_steps(0.6)
	ok(world.damage_done > 0.0, "and hits it")
	_range_setup()
	var h3 := _hold([{"id": &"on_load", "lv": 3}, &"needle", &"mote"])
	var m3 := h3.mana
	_again(h3, PI / 2.0)
	eq(m3 - h3.mana, 3.0 + 1.0, "half at level 3")


# ---- wands ----

func test_channel_rod_builds_while_still_and_resets_on_move() -> void:
	var fresh := _one_cast([&"mote"], &"channel_rod")
	_range_setup()
	var w := _hold([&"mote"], &"channel_rod")
	for k in 3:
		_again(w, PI / 2.0)
	eq(w.channel, 3, "three casts standing still")
	w.channel = WandState.CHANNEL_MAX
	world.damage_done = 0.0
	_again(w)
	_steps(0.8)
	ok(absf(world.damage_done - fresh * 1.8) < 0.6, "+80%% at the most (%.1f vs %.1f)" % [world.damage_done, fresh])
	eq(w.channel, WandState.CHANNEL_MAX, "and it stops growing")
	world.player.vel = Vector2(90, 0)
	world.step(DT)
	eq(w.channel, 0, "moving resets it")


func test_unsafe_staff_pays_hp_and_never_the_last() -> void:
	var plain := _one_cast([&"mote"])
	var blood := _one_cast([&"mote"], &"unsafe_staff")
	ok(absf(blood - plain * WandState.BLOOD_DMG) < 0.6, "+40%% damage (%.1f vs %.1f)" % [blood, plain])
	_range_setup()
	var w := _hold([&"burst"], &"unsafe_staff")
	var p := world.player
	p.hp = 50.0
	var m0 := w.mana
	ok(_again(w), "it casts")
	ok(is_equal_approx(p.hp, 50.0 - 8.0 * WandState.BLOOD_HP), "for HP (%.2f)" % p.hp)
	eq(w.mana, m0, "not mana")
	p.hp = 1.2
	ok(not _again(w), "it will not spend the last HP")
	ok(is_equal_approx(p.hp, 1.2), "and takes none")
	p.hp = p.max_hp
	ok(not Rewards.wand_desc(Catalog.wand(&"unsafe_staff")).contains("mana."), "its card shows no mana pool")


func test_singleton_skips_repeats_and_rewards_variety() -> void:
	var w := wand(["mote", "mote", "needle", "mote"], &"singleton")
	eq(_ids(WandProgram.preview_cycle(w)), [&"mote", &"needle"], "repeats sit out")
	eq(w.read_pos(1), -1, "and show no number")
	ok(is_equal_approx(w.singleton_mul(), 1.10), "two different spells: +10%")
	var plain := _one_cast([&"mote"])
	var one := _one_cast([&"mote"], &"singleton")
	ok(absf(one - plain * 1.08) < 0.3, "one spell: +8%% (%.2f vs %.2f)" % [one, plain])


func test_decorator_rod_powers_only_the_next_spell_twice() -> void:
	var a := WandProgram.preview_cycle(wand(["empower", "mote", "needle"]))
	ok(is_equal_approx(a[1].groups[0].mods.dmg, 1.25), "on a plain wand the boost reaches the Needle too")
	var d := WandProgram.preview_cycle(wand(["empower", "mote", "needle"], &"decorator_rod"))
	ok(is_equal_approx(d[0].groups[0].mods.dmg, 1.5625), "the Mote gets Empower twice")
	ok(is_equal_approx(d[1].groups[0].mods.dmg, 1.0), "the Needle gets nothing")
	eq(d[0].mana, 5.0 + 3.0, "the boost is paid once")


func test_hot_reload_ends_its_recharge_when_switched_to() -> void:
	_range_setup()
	var other := wand([&"mote"])
	var hot := wand([&"mote"], &"hot_reload")
	world.run.wands.clear()
	world.run.wands.append(other)
	world.run.wands.append(hot)
	world.run.cur = 1
	_again(hot)
	ok(hot.rech > 1.0 and hot.cd > 1.0, "it is recharging (%.2f s)" % hot.rech)
	world.run.cur = 0
	# 0.22: a flick back and forth does nothing; it must rest on the belt first
	world.step(DT)
	world.player.controls.select_wand = 1
	world.step(DT)
	ok(hot.rech > 0.5, "straight back from the belt: still recharging")
	world.run.cur = 0
	hot.rech = 3.0
	hot.bench = WandState.HOT_BENCH
	world.player.controls.select_wand = 1
	world.step(DT)
	eq(world.run.cur, 1, "switched to it")
	eq(hot.rech, 0.0, "the recharge is over")
	eq(hot.cd, 0.0, "it can cast at once")
	_again(other)
	var left := other.cd
	world.player.controls.select_wand = 0
	world.step(DT)
	ok(other.cd > left - 0.05, "a plain wand keeps its recharge")


func test_monorepo_recharge_grows_with_its_spells() -> void:
	var w := wand(["mote", "needle", "lance"], &"monorepo")
	eq(w.slots.size(), 12, "12 slots")
	ok(is_equal_approx(w.recharge_time(), 0.5), "0.2 s plus 0.1 s for each of 3 spells")
	var full := wand(["mote", "mote", "mote", "mote", "mote", "mote", "mote", "mote", "mote", "mote", "mote", "mote"], &"monorepo")
	ok(is_equal_approx(full.recharge_time(), 1.4), "1.4 s when full")


# ---- content ----

func test_new_cards_exist_and_are_not_core() -> void:
	for id in SPELLS:
		var d := Catalog.spell(id)
		ok(d != null, "%s is in the catalog" % id)
		if d == null:
			continue
		ok(not Catalog.tags(id).is_empty(), "%s has tags" % id)
		ok(not Meta.CORE_SPELLS.has(id), "%s is not core" % id)
		ok(not IconArt.spell(id).is_empty(), "%s has an icon" % id)
		ok(Icons.spell(d) != null, "%s icon renders" % id)
		if d.kind == SpellDef.Kind.PROJ or d.kind == SpellDef.Kind.FAMILIAR:
			ok(Audio.CAST.has(id), "%s has a cast sound" % id)
	for id in WANDS:
		ok(Catalog.wand(id) != null and Catalog.wand(id).rule != &"", "%s is a wand with a rule" % id)
		ok(not Meta.CORE_WANDS.has(id), "%s is not core" % id)
	ok(Props.familiar(&"pair", 0) != null, "the partner has a sprite")
