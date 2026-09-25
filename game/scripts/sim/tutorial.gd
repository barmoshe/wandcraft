class_name Tutorial
extends RefCounted
## D9: the first run is a curriculum (design-plan §6): each of the three rooms before the
## mini-boss teaches one thing the wand editor is for, and ends by handing over exactly the
## spell that lesson needs. The editor opens with a coach line and rings on what to move and
## where. Everything after the mini-boss is a normal run.
##   room 1  buglings only; the prize is Empower (a boost) -> the first wand edit
##   room 2  a Hex Weaver among fodder; the prize is Needle or Phase (pierce), because...
##   room 3  ...Rune Sentries are shielded and show BLOCKED to anything but pierce; the prize
##           is a trigger (Then or Callback) -> the first trigger
##   mini    Copy-Paste turns your own wand against you
## Armour (Blast) and wards (Shock) are taught by a tip the first time they block you, in
## any run (Hints), not by a forced room.
##
## Tested (tests/unit/test_onboarding_d9.gd): a new player's first edit by 120 s and first
## trigger by 180 s of play.

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
		"offer": [&"needle", &"phase"],
		"coach": "pierce",
	},
	3: {
		"title": "Shields",
		"waves": [[[&"sentry", false], [&"bugling", false], [&"bugling", false]], [[&"sentry", false], [&"slime", false]]],
		"offer": [&"then", &"callback"],
		"coach": "trigger",
	},
}

const COACH := {
	"equip": "A boost powers up every spell on its right, so it goes left of your Mote. Drag EMPOWER onto the lit slot.",
	"pierce": "Some enemies carry a shield that blocks hits from the front. A PIERCE spell breaks it. Drag it onto the lit slot.",
	"trigger": "A trigger goes between two spells: when the one on its left ends, it casts the one on its right. Drag THEN onto the lit slot.",
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


## A lesson prize: lesson 3's also grows the wand by one slot, so the trigger has room to sit
## between two spells.
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
	# the lesson spell's own move first: it carries the explanation, the rest just make room
	var order: Array = range(target.size())
	order.sort_custom(func(a: int, b: int) -> bool: return ids.has(target[a]) and not ids.has(target[b]))
	for i in order:
		var have: Variant = w.slots[i]["id"] if w.slots[i] != null else null
		if have == target[i] or target[i] == null:
			continue
		var from := _find(run, target[i], i)
		if from.is_empty():
			return {}
		var first: bool = ids.has(target[i]) and int(from["w"]) < 0
		var text: String = COACH[STEPS[lesson_step]["coach"]] if first else \
			"Now drag %s onto the lit slot." % Catalog.spell(target[i]).title.to_upper()
		return {"text": text, "from": from, "to": {"w": run.cur, "i": i}, "ids": [target[i]]}
	return {}


## The wand in hand as it should look after the lesson (spell ids, null for empty), built
## from what it holds now plus the lesson spell the player took:
##   a boost goes just left of the first shooting spell (boosts power up what is on their right)
##   a shooting spell goes left of everything, into the empty room
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
			order.push_front(prize)
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
