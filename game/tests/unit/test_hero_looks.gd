extends "res://tests/unit/test_helpers.gd"
## 0.19: each hero has its own look (Hero.LOOKS), on the apprentice's rig and frame budget.

var world: World


func setup(tree: SceneTree) -> void:
	SaveGame.enabled = false
	Game.god_mode = true
	Game.auto_fire = false
	world = World.new()
	world.auto_step = false
	tree.root.add_child(world)
	world.setup(19)
	world.start_run(RunState.create(19))


func teardown() -> void:
	SaveGame.enabled = true
	Game.god_mode = false
	Game.auto_fire = true
	world.free()


func test_every_loadout_has_a_look() -> void:
	for h in RunState.LOADOUTS:
		ok(Hero.LOOKS.has(h), "%s has a look" % h)


func test_every_hero_matches_the_apprentices_frames() -> void:
	for back in [false, true]:
		var base := Hero.clips(back)
		for h in Hero.LOOKS:
			var c := Hero.clips(back, h)
			var face := "back" if back else "front"
			ok(c.keys() == base.keys(), "%s %s has the apprentice's clips" % [h, face])
			for k in base:
				ok((c[k] as Array).size() == (base[k] as Array).size(), "%s %s %s has %d frames" % [h, face, k, (base[k] as Array).size()])
				for i in (c[k] as Array).size():
					ok((c[k][i] as Texture2D).get_size() == (base[k][0] as Texture2D).get_size(), "%s %s %s %d is the apprentice's size" % [h, face, k, i])
			ok(Hero.rig(back, h).frame_count() == Hero.rig(back).frame_count(), "%s %s: the same frame budget" % [h, face])
		ok(Hero.frames(&"pyromancer").size() == Hero.frames().size(), "frames() lists the same poses for every hero")


func test_the_heroes_look_different() -> void:
	var ids: Array = Hero.LOOKS.keys()
	for back in [false, true]:
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				var ia := (Hero.clips(back, ids[a])["idle"][0] as Texture2D).get_image()
				var ib := (Hero.clips(back, ids[b])["idle"][0] as Texture2D).get_image()
				ok(ia.get_data() != ib.get_data(), "%s and %s differ (%s)" % [ids[a], ids[b], "back" if back else "front"])


func test_rig_ids_and_the_fallback() -> void:
	eq(Hero.rig(false).id, "hero_front", "the apprentice's front rig id is unchanged")
	eq(Hero.rig(true).id, "hero_back", "the apprentice's back rig id is unchanged")
	eq(Hero.rig(false, &"apprentice").id, "hero_front", "naming the apprentice is the same rig")
	eq(Hero.rig(false, &"pyromancer").id, "hero_pyromancer_front", "the pyromancer's rig id")
	eq(Hero.rig(true, &"tinkerer").id, "hero_tinkerer_back", "the tinkerer's back rig id")
	ok(Hero.rig(false, &"nobody") == Hero.rig(false), "an unknown hero falls back to the apprentice")
	ok(Hero.frames(&"nobody")[0] == Hero.frames()[0], "an unknown hero draws the apprentice")
	eq(Hero.palette(), Hero.PAL, "the apprentice's palette is PAL")


func test_the_clone_copies_the_hero_you_play() -> void:
	var a := (Bestiary.clone_frames()[0] as Texture2D).get_image()
	var p := (Bestiary.clone_frames(&"pyromancer")[0] as Texture2D).get_image()
	ok(a.get_data() != p.get_data(), "Copy-Paste glitches the pyromancer, not the apprentice")
	ok(Bestiary.clone_clips(&"tinkerer")["run"].size() == Bestiary.clone_clips()["run"].size(), "the clone's clips keep the budget")
	ok(Bestiary.clone_clips(&"tinkerer") != Bestiary.clone_clips(), "each hero has its own clone clips")


func test_the_player_wears_the_runs_hero() -> void:
	var p := world.player
	ok(p.frames[0] == Hero.frames()[0], "a new run's apprentice looks like the apprentice")
	p.set_look(&"pyromancer")
	ok(p.frames[0] == Hero.frames(&"pyromancer")[0], "set_look swaps the frames")
	ok(p.clips_front["idle"][0] == Hero.clips(false, &"pyromancer")["idle"][0], "set_look swaps the front clips")
	ok(p.clips_back["idle"][0] == Hero.clips(true, &"pyromancer")["idle"][0], "set_look swaps the back clips")
	p.aim = 0.0
	p._animate()
	ok(Hero.clips(false, &"pyromancer")["idle"].has(p.sprite.texture), "the sprite draws the pyromancer (%s)" % p.clip)
	world.start_run(RunState.create(19, &"tinkerer"))
	ok(p.frames[0] == Hero.frames(&"tinkerer")[0], "starting a run as the tinkerer dresses the player")


func test_a_start_pick_changes_the_look() -> void:
	# the start orb grants a loadout (Rewards.grant -> set_loadout), then main calls reward_taken
	var p := world.player
	world.run.set_loadout(&"pyromancer")
	world.reward_taken()
	ok(p.frames[0] == Hero.frames(&"pyromancer")[0], "picking the pyromancer at the start changes the look")
