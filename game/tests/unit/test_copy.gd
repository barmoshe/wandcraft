extends "res://tests/unit/test_helpers.gd"
## Player-facing text: every description shows one level's numbers, and fits the smallest
## reward card (three cards on a 480x270 view) without being cut.

## Three cards on a 480-wide view: (468 - 2 * 10) / 3 wide, minus 14 of padding.
const BODY_W := 135.0
## What the smallest card leaves for text with the icon shrunk (reward_screen.gd _card).
const MAX_LINES := 8


func _lines(s: String) -> int:
	var sc := Screen.new()
	var n := sc._wrap(Game.font("small"), s, BODY_W, 8).size()
	sc.free()
	return n


func test_level_tokens_resolve_per_level() -> void:
	var d := Catalog.spell(&"then")
	ok(d.text_at(1).contains("+30%"), "THEN level 1 reads 30%")
	ok(d.text_at(3).contains("+120%"), "THEN level 3 reads 120%")
	ok(not d.text_at(2).contains("/"), "no slashes left at level 2")
	ok(Catalog.spell(&"mote").text_at(3).ends_with("passes through one enemy."), "level 3 adds its sentence")
	ok(not Catalog.spell(&"mote").text_at(2).contains("passes"), "only at level 3")


func test_no_raw_level_notation_reaches_the_player() -> void:
	var slash := RegEx.create_from_string("\\d/\\d")
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		for lv in [1, 2, 3]:
			var t := d.text_at(lv)
			ok(not t.contains("{") and not t.contains("}"), "%s L%d: no braces" % [id, lv])
			ok(slash.search(t) == null, "%s L%d: no a/b/c numbers (%s)" % [id, lv, t])
	for id in Relics.DEFS:
		ok(slash.search(String(Relics.DEFS[id]["desc"])) == null, "%s: no a/b/c numbers" % id)


func test_every_text_fits_the_smallest_card() -> void:
	for id in Catalog.spells():
		for lv in [1, 2, 3]:
			var t := Catalog.spell(id).text_at(lv)
			ok(_lines(t) <= MAX_LINES, "%s L%d fits (%d lines): %s" % [id, lv, _lines(t), t])
	for id in Relics.DEFS:
		var t := Rewards.item_desc({"t": &"relic", "id": id})
		ok(_lines(t) <= MAX_LINES, "%s fits (%d lines)" % [id, _lines(t)])
	for id in Catalog.wands():
		var t := Rewards.wand_desc(Catalog.wand(id))
		ok(_lines(t) <= MAX_LINES, "%s fits (%d lines)" % [id, _lines(t)])
	for id in Rewards.LOADOUT_TEXT:
		ok(_lines(Rewards.LOADOUT_TEXT[id]) <= MAX_LINES, "%s start fits" % id)


func test_a_copy_you_hold_shows_the_merged_level() -> void:
	var r := RunState.create(1)
	eq(Rewards.level_after(r, &"empower"), 1, "no copy: level 1")
	r.bag.append({"id": &"empower", "lv": 1})
	eq(Rewards.level_after(r, &"empower"), 2, "one copy at level 1: merges to 2")
	r.bag[0]["lv"] = 2
	eq(Rewards.level_after(r, &"empower"), 1, "a level-2 copy alone does not merge with a level-1 pick")


## Design v2: one vocabulary. Old words stay out of anything a player reads.
const BANNED := ["rotation", "payload", "carrier", "debugger", "merge commit", "familiar", " mp ", "l3", "left spell", "right one"]


func _player_texts() -> Array:
	var out: Array = []
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		out.append(d.title)
		for lv in [1, 2, 3]:
			out.append(d.text_at(lv))
	for id in Relics.DEFS:
		out.append(Relics.DEFS[id]["title"])
		out.append(Rewards.item_desc({"t": &"relic", "id": id}))
	for id in Catalog.wands():
		out.append(Rewards.wand_desc(Catalog.wand(id)))
	for t in Glossary.TERMS:
		out.append(t[2])
	for k in Tutorial.COACH:
		out.append(Tutorial.COACH[k])
	for k in Hints.TIPS:
		out.append_array(Hints.TIPS[k])
	return out


func test_no_old_words_in_player_text() -> void:
	for t in _player_texts():
		var low := " " + String(t).to_lower() + " "
		for w in BANNED:
			ok(not low.contains(w), "'%s' in: %s" % [w.strip_edges(), t])


func test_no_two_things_share_a_name() -> void:
	var seen := {}
	for id in Catalog.spells():
		var t := Catalog.spell(id).title.to_lower()
		ok(not seen.has(t), "spell name used twice: %s" % t)
		seen[t] = true
	for id in Relics.DEFS:
		var t := String(Relics.DEFS[id]["title"]).to_lower()
		ok(not seen.has(t), "relic name used twice: %s" % t)
		seen[t] = true
	for id in Catalog.wands():
		var t := Catalog.wand(id).title.to_lower()
		ok(not seen.has(t), "wand name used twice: %s" % t)
		seen[t] = true
