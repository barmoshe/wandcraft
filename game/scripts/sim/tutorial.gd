class_name Tutorial
extends RefCounted
## D9: the first run is a curriculum (design-plan §6): each of the three rooms before the
## mini-boss teaches one thing the wand editor is for, and ends by handing over exactly the
## spell that lesson needs. The editor opens with a coach line and rings on what to move and
## where. Everything after the mini-boss is a normal run.
##   room 1  buglings only; the prize is Empower (a boost) -> the first wand edit
##   room 2  a Hex Weaver among fodder; the prize is Needle or Prism Lance (both shooting
##           pierce spells; 0.20: Phase, a boost, left the wand one spell short), because...
##   room 3  ...Rune Sentries are shielded and show BLOCKED to anything but pierce; the prize
##           is a second shooting spell (Frost Shard or Chain Spark) -> a wand that takes turns,
##           and its mana bar
##           (0.20: triggers left the first run. They were coached before the wand had two
##           spells to join, and now come in the Triggers pack at the Merchant.)
##   mini    Copy-Paste turns your own wand against you
## Armour (Blast) and wards (Shock) are taught by a tip the first time they block you, in
## any run (Hints), not by a forced room.
##
## Tested (tests/unit/test_onboarding_d9.gd): a new player's first edit by 120 s of play, and a
## wand with two shooting spells before the mini-boss.

const STEPS := {
	1: {
		"title": "First Steps",
		"waves": [[[&"bugling", false], [&"bugling", false], [&"bugling", false]], [[&"bugling", false], [&"bugling", false]]],
		"offer": [&"empower"],
		"coach": "equip",
	},
	2: {
		"title": "Aim and Dodge",
		"waves": [[[&"slime", false], [&"bugling", false], [&"bugling", false]], [[&"weaver", false], [&"bugling", false]]],
		"offer": [&"needle", &"lance"],
		"coach": "pierce",
	},
	3: {
		"title": "Shields",
		"waves": [[[&"sentry", false], [&"bugling", false], [&"bugling", false]], [[&"sentry", false], [&"slime", false]]],
		"offer": [&"frost", &"spark"],
		"coach": "second",
	},
}

## Why each lesson's spell goes where it goes. The coach adds what to do now (_step_text).
const COACH := {
	"equip": "A boost powers up every spell on its right, so it goes left of your Mote.",
	"pierce": "Some enemies carry a shield that blocks hits from the front. A pierce spell breaks it, and your boost powers it up.",
	"second": "A wand fires its spells left to right, one per shot, and every spell costs mana. The bar under the range shows if it keeps up.",
}


## True while the run is in one of the lesson rooms.
static func active(run: RunState) -> bool:
	return run != null and run.tutorial and STEPS.has(run.step)


## The map node for a lesson step: one fight, promising a spell.
static func map_node(step: int) -> Dictionary:
	return {"kind": &"fight", "reward": &"spell", "lesson": step}


## The fixed prize of a lesson room.
static func offer(run: RunState) -> Array:
	return (STEPS[run.step]["offer"] as Array).map(func(id: StringName) -> Dictionary: return {"t": &"spell", "id": id, "v": 1})


static func waves(run: RunState) -> Array:
	return STEPS[run.step]["waves"]


static func title(run: RunState) -> String:
	return STEPS[run.step]["title"]


## A lesson prize: lesson 3's also grows the wand by one slot, so the second shooting spell
## has room beside the first.
static func on_prize(run: RunState, lesson_step: int) -> void:
	if run == null or not run.tutorial or not STEPS.has(lesson_step):
		return
	if lesson_step == 3:
		Rewards.grant(run, {"t": &"slot", "id": &"slot"})
	# the layout to coach toward is fixed now: moves on the way must not change the goal
	run.lesson_target = layout(run, lesson_step)


## What the editor should coach now: {"text", "from": ref, "to": ref, "ids"}, or {} once the
## wand matches the lesson's layout (or the run is not a lesson). Recomputed every frame, so a
## lesson that needs two moves walks the player through both.
static func coach(run: RunState, lesson_step: int) -> Dictionary:
	if run == null or not run.tutorial or not STEPS.has(lesson_step):
		return {}
	var ids: Array = STEPS[lesson_step]["offer"]
	var w := run.wand()
	var target := run.lesson_target
	if target.is_empty() or target.size() != w.slots.size():
		return {}
	# 0.20 (Bar's "fix all lessons"): moves into EMPTY slots first, so nothing is ever bumped
	# into the bag only to be dragged back; the spells already on the wand make room, then
	# the prize goes in. Only when no empty slot is waiting does a move land on a spell.
	var todo: Array = []
	for i in target.size():
		var have: Variant = w.slots[i]["id"] if w.slots[i] != null else null
		if have != target[i] and target[i] != null:
			todo.append(i)
	if todo.is_empty():
		return {}
	var pick: int = todo[0]
	for i in todo:
		if w.slots[i] == null:
			pick = i
			break
	var from := _find(run, target[pick], pick)
	if from.is_empty():
		return {}
	var prize_in_bag := run.bag.any(func(sp: Variant) -> bool: return sp != null and ids.has(sp["id"]))
	return {"text": _step_text(lesson_step, target[pick], ids.has(target[pick]), prize_in_bag),
		"from": from, "to": {"w": run.cur, "i": pick}, "ids": [target[pick]]}


## The coach's words for one move: the lesson's reason while the prize still waits in the bag
## (then "first, make room" or "drag it in"), and a plain "now" once it's on the wand.
static func _step_text(lesson_step: int, id: StringName, is_prize: bool, prize_in_bag: bool) -> String:
	var why: String = COACH[STEPS[lesson_step]["coach"]]
	var nm := Catalog.spell(id).title.to_upper()
	if is_prize:
		return "%s Drag %s onto the lit slot." % [why, nm]
	if prize_in_bag:
		return "%s First, make room: drag %s onto the lit slot." % [why, nm]
	return "Now drag %s onto the lit slot." % nm


## The wand in hand as it should look after the lesson (spell ids, null for empty), built
## from what it holds now plus the lesson spell the player took:
##   a boost goes just left of the first shooting spell (boosts power up what is on their right)
##   a shooting spell goes just left of the last one, so every boost powers it up too (0.20:
##   it went left of everything, where the boosts never reached it)
##   a trigger goes right after the first shooting spell, so another one follows it
## The layout is right-aligned: spells sit at the right end, empty slots stay on the left.
## Returns [] when the lesson spell is not in the run at all.
static func layout(run: RunState, lesson_step: int) -> Array:
	var ids: Array = STEPS[lesson_step]["offer"]
	var w := run.wand()
	var prize: Variant = null
	var held: Array = []
	for sp in w.slots:
		if sp != null:
			if ids.has(sp["id"]) and prize == null:
				prize = sp["id"]
			else:
				held.append(sp["id"])
	if prize == null:
		for sp in run.bag:
			if sp != null and ids.has(sp["id"]):
				prize = sp["id"]
				break
	if prize == null:
		return []
	var casters := held.filter(func(id: StringName) -> bool: return Catalog.is_caster(Catalog.spell(id)))
	var first_caster := held.find(casters[0]) if not casters.is_empty() else held.size()
	var order := held.duplicate()
	match Catalog.spell(prize).kind:
		SpellDef.Kind.BOOST, SpellDef.Kind.PASSIVE:
			order.insert(first_caster, prize)
		SpellDef.Kind.TRIG:
			order.insert(mini(first_caster + 1, order.size()), prize)
			# the trigger needs a shooting spell on its right: bring one from the bag if the
			# wand has only the one on its left
			var after := order.find(prize) + 1
			if after >= order.size() or not Catalog.is_caster(Catalog.spell(order[after])):
				for sp in run.bag:
					if sp != null and Catalog.is_caster(Catalog.spell(sp["id"])):
						order.insert(after, sp["id"])
						break
		_:
			# just left of the last shooting spell (the Mote, in its last slot): every boost
			# on the wand sits left of it, so they all power the new spell up too
			var last_caster := held.rfind(casters[-1]) if not casters.is_empty() else held.size()
			order.insert(last_caster, prize)
	# what does not fit goes to the bag; the empty slots stay on the left
	var out: Array = []
	var pad := w.slots.size() - order.size()
	for i in w.slots.size():
		out.append(order[i - pad] if i >= pad else null)
	return out


## Where a spell is: the bag first, then a wand slot other than `not_slot`.
static func _find(run: RunState, id: StringName, not_slot: int) -> Dictionary:
	for i in run.bag.size():
		if run.bag[i] != null and run.bag[i]["id"] == id:
			return {"w": -1, "i": i}
	var w := run.wand()
	for i in w.slots.size():
		if i != not_slot and w.slots[i] != null and w.slots[i]["id"] == id:
			return {"w": run.cur, "i": i}
	return {}
