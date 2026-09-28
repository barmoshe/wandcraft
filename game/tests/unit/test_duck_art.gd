extends "res://tests/unit/test_helpers.gd"
## 0.24, the Debug Duck (DuckArt, ADR 0036): one design everywhere, drawn from Style ramps,
## with moods, a blink and a talking bill that really change the picture.


func _png(t: Texture2D) -> PackedByteArray:
	return t.get_image().save_png_to_buffer()


func test_the_face_keeps_the_speech_box_size() -> void:
	eq(DuckArt.face().get_size(), Vector2(14, 13), "14x13, the size resident portraits match")
	eq(Hud.duck_face(), DuckArt.face(), "the old entry point draws the new Duck")


func test_moods_blink_and_talk_change_the_face() -> void:
	var plain := _png(DuckArt.face())
	ok(_png(DuckArt.face(DuckArt.SMUG)) != plain, "smug differs")
	ok(_png(DuckArt.face(DuckArt.PLEASED)) != plain, "pleased differs")
	ok(_png(DuckArt.face(DuckArt.PLAIN, true)) != plain, "the bill opens")
	ok(_png(DuckArt.face(DuckArt.PLAIN, false, true)) != plain, "it blinks")


func test_the_companion_waddles_talks_and_blinks() -> void:
	var a := _png(DuckArt.body(0))
	ok(_png(DuckArt.body(1)) != a, "the feet step")
	ok(_png(DuckArt.body(0, true)) != a, "the bill opens")
	ok(_png(DuckArt.body(0, false, true)) != a, "it blinks")
	eq(CompanionArt.duck(0, false), DuckArt.body(0), "the old entry point draws the new Duck")
	ok(DuckArt.sit().get_height() < DuckArt.body(0).get_height(), "sitting, it has no feet")


func test_the_spell_and_the_story_use_the_same_duck() -> void:
	eq(Props.familiar(&"duck", 0), DuckArt.familiar(0), "the Rubber Duck spell's familiar")
	eq(IconArt.spell(&"duck")["rows"], DuckArt.ICON, "its icon")
	eq(DuckArt.ICON.size(), 12, "12 rows")
	for r in DuckArt.ICON:
		eq(String(r).length(), 12, "12 wide")
	ok(_png(DuckArt.bust(false, false, 0)) != _png(DuckArt.bust(false, false, 1)), "the bath water ripples")
	ok(_png(DuckArt.bust(true)) != _png(DuckArt.bust()), "the bust talks")


func test_every_color_is_a_style_ramp() -> void:
	for k in DuckArt.PAL:
		var v := String(DuckArt.PAL[k])
		ok(not v.begins_with("#") and Style.RAMPS.has(v.split(":")[0]), "%s is a ramp step (%s)" % [k, v])


func test_a_line_sets_the_mood() -> void:
	eq(DuckArt.mood_of("hub_win.2"), DuckArt.PLEASED, "a win pleases it")
	eq(DuckArt.mood_of("hub_death.0"), DuckArt.SMUG, "a death lets it be right")
	eq(DuckArt.mood_of("intro.3"), DuckArt.PLAIN, "the rest is plain")
