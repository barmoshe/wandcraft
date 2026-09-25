extends "res://tests/unit/test_helpers.gd"
## Design v2 R2: the firing range measures what the game does.

var tree: SceneTree


func setup(t: SceneTree) -> void:
	tree = t
	SaveGame.enabled = false


func teardown() -> void:
	SaveGame.enabled = true


func test_the_range_measures_boosts_and_stays_quiet() -> void:
	var lab := WandLab.probe(tree)
	var r := RunState.create(3)
	var twig := Catalog.wand(&"twig")
	var base := lab.measure_now(r, twig, [null, null, {"id": &"mote", "lv": 1}])
	var boosted := lab.measure_now(r, twig, [null, {"id": &"empower", "lv": 1}, {"id": &"mote", "lv": 1}])
	ok(base > 5.0, "a Mote deals damage on the range (%.1f/s)" % base)
	ok(boosted > base * 1.15, "Empower on its left raises it (%.1f -> %.1f)" % [base, boosted])
	var wrong := lab.measure_now(r, twig, [null, {"id": &"mote", "lv": 1}, {"id": &"empower", "lv": 1}])
	ok(absf(wrong - base) < base * 0.1, "Empower on its right does nothing (%.1f vs %.1f)" % [wrong, base])
	eq(Game.quiet, 0, "the quiet gate is released")


func test_probe_results_are_cached_by_layout() -> void:
	var lab := WandLab.probe(tree)
	var r := RunState.create(3)
	var twig := Catalog.wand(&"twig")
	var slots := [null, null, {"id": &"needle", "lv": 1}]
	var a := lab.measure_now(r, twig, slots)
	eq(lab.dps(r, twig, slots), a, "dps() returns the measured number at once")
