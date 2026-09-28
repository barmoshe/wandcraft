class_name Glossary
extends RefCounted
## Design v2: the words the game uses, one line each. Every player-facing text sticks to
## these (test_copy bans the old ones: rotation, cycle, payload, carrier...). Shown from the
## editor's "?" and the pause menu's HOW IT WORKS.

## [shape (Screen.Fam, or -1 for a plain word), word, one line]
## 0.22: what a tag chip means, one line each (tap a chip on a card to read it).
const KEYWORDS := {
	"Burn": "Burn hurts over time. Fire spreads with the right cards.",
	"Frost": "Chills slow. Three chills freeze.",
	"Shock": "Shock strips wards and charges foes: their next hit arcs on.",
	"Rot": "Bitrot stacks up. Five stacks crash an enemy.",
	"Area": "Hits everything in a circle: blasts and bursts.",
	"Multi": "Fires more than one shot.",
	"Crit": "Critical hits: bigger numbers, sometimes.",
	"Trigger": "Goes between two spells: the left one releases the right one.",
	"Summon": "Calls a helper that fights beside you for a while.",
	"Rune": "Changes how the wand reads its slots.",
	"Survival": "Keeps you alive: heals, shields, second chances.",
	"Economy": "Gold, Bits and mana: more of them.",
	"Glitch": "Risky code: strong, with a catch.",
	"Debug": "Changes how the wand reads its slots.",
}

const TERMS := [
	[-1, "Cast", "One shot of the wand. It reads slots left to right until a spell fires."],
	[-1, "Recharge", "After its last slot the wand pauses, then starts again from slot 1."],
	[-1, "Mana", "Each wand has its own. Every cast spends some; it refills over time."],
	[0, "Spell", "Fires something: bolts, beams, blasts, summons."],
	[1, "Boost", "Powers up every spell on its right until the wand recharges."],
	[2, "Trigger", "Goes between two spells: the one on its left releases the one on its right."],
	[3, "Passive", "Works from any slot."],
	[-1, "Keywords", "Pierce breaks shields. Blast tears off armor. Shock strips wards."],
	[-1, "Status", "Burn hurts over time. 3 chills freeze. A charged enemy passes its next hit on."],
	[-1, "Level", "Two copies of a spell merge into the next level (up to 3)."],
]
