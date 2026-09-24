class_name Hints
extends RefCounted
## First-run tips, each shown once and remembered in user://meta.json. They appear when the
## thing they explain first happens (progressive disclosure), never as a wall of text.
## "Show tips again" in the pause menu resets them.

const TIPS := {
	"move": ["Drag on the left side to move", "WASD or arrows to move"],
	"aim": ["Your wand fires by itself. Drag on the right side to aim", "Your wand fires by itself. Hold the mouse to aim"],
	"orb": ["Touch the glowing orb to choose a reward", "Walk into the glowing orb to choose a reward"],
	"doors": ["Each door shows what is behind it. Pick your path", "Each door shows what is behind it. Pick your path"],
	"editor": ["Tap the bag button to arrange the spells in your wand", "Press Tab (or the bag button) to arrange your spells"],
	"boss": ["Red lines and circles show where the boss will strike", "Red lines and circles show where the boss will strike"],
}

static var _seen: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for id in SaveGame.load_meta().get("hints", []):
		_seen[String(id)] = true


## Shows a tip the first time it is asked for. Returns true if it was shown.
static func show(id: String) -> bool:
	_load()
	if _seen.has(id) or not TIPS.has(id):
		return false
	_seen[id] = true
	var m := SaveGame.load_meta()
	m["hints"] = _seen.keys()
	SaveGame.save_meta(m)
	Events.hint.emit(TIPS[id][0 if Game.is_touch() else 1])
	return true


static func reset() -> void:
	_seen.clear()
	_loaded = true
	var m := SaveGame.load_meta()
	m["hints"] = []
	SaveGame.save_meta(m)
