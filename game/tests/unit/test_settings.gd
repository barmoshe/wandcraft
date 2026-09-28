extends "res://tests/unit/test_helpers.gd"
## 0.22 feel and accessibility: the shake and flash cycles, reduce motion, large text, Assist
## (which replaced Gentle), saves from before 0.22, and the small-tap audit.

var tree: SceneTree
var _saved: Dictionary


func setup(t: SceneTree) -> void:
	tree = t
	SaveGame.in_memory = true
	_saved = Game.settings()


func teardown() -> void:
	Game.apply_settings(_saved)
	SaveGame.in_memory = false


func test_shake_and_flash_cycle_100_50_off() -> void:
	eq(Game.next_step(Game.SCALES, 1.0), 0.5, "100% then 50%")
	eq(Game.next_step(Game.SCALES, 0.5), 0.0, "50% then OFF")
	eq(Game.next_step(Game.SCALES, 0.0), 1.0, "OFF then 100%")
	Game.apply_settings({"shake": 1.0, "flash": 1.0, "reduce_motion": false})
	var s := PauseScreen.new()
	s.hub = true
	tree.root.add_child(s)
	var seen := []
	for i in 3:
		s.press("shake")
		seen.append(Game.shake_scale)
	eq(seen, [0.5, 0.0, 1.0], "SHAKE taps: 50%, OFF, 100%")
	s.press("flash")
	s.press("flash")
	eq(Game.flash_scale, 0.0, "FLASH OFF")
	ok(not Game.flash_fx, "and no flash at all")
	eq(SaveGame.load_settings().get("flash"), 0.0, "saved as a number")
	s.press("flash")
	ok(Game.flash_fx and Game.flash_scale == 1.0, "back to 100%")
	eq(PauseScreen._pct(0.5), "50%", "the label shows 50%")
	eq(PauseScreen._pct(0.0), "OFF", "and OFF")
	s.free()


func test_saves_from_before_0_22_still_load() -> void:
	Game.apply_settings({"shake": true, "flash": true, "gentle": false})
	eq(Game.shake_level, 1.0, "shake on is 100%")
	eq(Game.flash_scale, 1.0, "flash on is 100%")
	eq(Game.assist, 0.0, "gentle off is assist off")
	Game.apply_settings({"shake": false, "flash": false})
	eq(Game.shake_scale, 0.0, "shake off is OFF")
	ok(not Game.flash_fx, "flash off is OFF")
	Game.apply_settings({"gentle": true})
	eq(Game.assist, 0.25, "gentle on reads as Assist 25%")
	Game.apply_settings({"gentle": true, "assist": 0.5})
	eq(Game.assist, 0.5, "a saved assist wins over the old key")
	Game.apply_settings({"shake": 0.4, "assist": 0.3})
	ok(Game.shake_level == 0.5 and Game.assist == 0.25, "odd numbers snap to a step")
	ok(not Game.settings().has("gentle"), "the old key is not written again")


func test_assist_cuts_damage_slows_shots_and_widens_aim() -> void:
	eq(Game.next_step(Game.ASSISTS, 0.0), 0.25, "OFF then 25%")
	eq(Game.next_step(Game.ASSISTS, 0.25), 0.5, "25% then 50%")
	eq(Game.next_step(Game.ASSISTS, 0.5), 0.0, "50% then OFF")
	var world := World.new()
	world.auto_step = false
	tree.root.add_child(world)
	world.setup(5)
	world.start_run(RunState.create(5))
	var p := world.player
	var taken := []
	for a in [0.0, 0.25, 0.5]:
		Game.assist = a
		p.hp = 100.0
		p.inv = 0.0
		p.shield = 0.0
		p.hurt(20.0, p.position + Vector2(10, 0), "test")
		taken.append(100.0 - p.hp)
	ok(is_equal_approx(taken[1], taken[0] * 0.75) and is_equal_approx(taken[2], taken[0] * 0.5),
		"25%% and 50%% less damage (%s)" % [taken])
	Game.assist = 0.25
	world.enemy_shoot(Vector2(40, 40), 0.0, 100.0, 5.0)
	var b: Variant = world.ebullets.active.back()
	ok(absf(b.vel.length() - 80.0) < 0.01, "enemy shots at 0.8x (%.1f)" % b.vel.length())
	eq(Game.assist_cone_mul(), Game.ASSIST_CONE, "a wider auto-aim cone")
	for i in 12:   # the hurt's hit-stop holds the first few steps
		world.step(1.0 / 60.0)
	ok(bool(world.run.stats.get("assist", false)), "the run is marked as an assist run")
	Game.assist = 0.0
	eq(Game.assist_shot_mul(), 1.0, "off: shots at full speed")
	eq(Game.assist_cone_mul(), 1.0, "off: the usual cone")
	world.free()


func test_a_daily_played_with_assist_is_marked() -> void:
	var r := RunState.create(9)
	r.daily = "2026-09-28"
	r.stats["assist"] = true
	SaveGame.record_run(r)
	ok(bool(SaveGame.load_meta().get("daily", {}).get("assist", false)), "the daily best says ASSIST")


func test_reduce_motion_drops_the_lead_and_halves_shake() -> void:
	Game.apply_settings({"shake": 1.0, "reduce_motion": false})
	eq(Game.cam_lead(16.0), 16.0, "the camera leads normally")
	eq(Game.shake_scale, 1.0, "full shake")
	Game.apply_settings({"reduce_motion": true})
	eq(Game.cam_lead(16.0), 0.0, "no lead with reduce motion")
	eq(Game.shake_scale, 0.5, "half shake")
	eq(Game.shake_level, 1.0, "the Shake setting itself is unchanged")


func test_large_text_draws_small_text_at_10() -> void:
	Game.apply_settings({"text_big": false})
	eq(Game.text_px(8), 8, "normal: 8")
	Game.apply_settings({"text_big": true})
	eq(Game.text_px(8), 10, "large: small text at 10")
	eq(Game.text_px(8, "bold"), 8, "bold labels keep their size")
	eq(Game.text_px(16, "body"), 16, "titles keep theirs")
	eq(Game.text_px(8, "small", "A LONG LINE OF TEXT", 60.0), 8, "stays 8 where 10 no longer fits")


func test_small_taps_are_reported() -> void:
	var bad := UiAudit.small_taps("Test", [[Rect2(0, 0, 20, 20), "relic0"], [Rect2(0, 0, 32, 32), "ok"]])
	eq(bad.size(), 1, "one small tap")
	ok(bad[0].contains("small tap") and bad[0].contains("relic0"), bad[0] if bad.size() > 0 else "")
	var hud := Hud.new()
	hud.buttons = {"menu": Rect2(0, 0, 32, 32), "tiny": Rect2(0, 0, 20, 32)}
	var taps := UiAudit.taps_of(hud)
	eq(taps.size(), 2, "the HUD's buttons are read")
	eq(UiAudit.small_taps("Hud", taps).size(), 1, "and the narrow one reported")
	hud.free()
