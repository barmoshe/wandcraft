class_name Glossary
extends RefCounted
## Design v2: the words the game uses, one line each. Every player-facing text sticks to
## these (test_copy bans the old ones: rotation, cycle, payload, carrier...). Shown from the
## editor's "?" and the pause menu's HOW IT WORKS.

## [shape (Screen.Fam, or -1 for a plain word), word, one line]
const TERMS := [
	[-1, "Cast", "One shot of the wand. It reads slots left to right until a spell fires."],
	[-1, "Recharge", "After its last slot the wand pauses, then starts again from slot 1."],
	[-1, "Mana", "Each wand has its own. Every cast spends some; it refills over time."],
	[0, "Spell", "Fires something: bolts, beams, blasts, summons."],
	[1, "Boost", "Powers up every spell on its right until the wand recharges."],
	[2, "Trigger", "Goes between two spells: the one on its left releases the one on its right."],
	[3, "Passive", "Works from any slot."],
	[-1, "Pierce / Blast / Shock", "Break shields / tear off armor / strip wards."],
	[-1, "Burn, Chill, Charged", "Fire hurts over time. 3 chills freeze. A charged enemy passes its next hit on."],
	[-1, "Level", "Two copies of a spell merge into the next level (up to 3)."],
]
