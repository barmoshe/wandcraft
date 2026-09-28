class_name Bubbles
extends RefCounted
## 0.21 speech bubbles (Bar: "above their head should be a speech bubble"). Whoever speaks a
## line (Dialogue.line_started) gets a bubble over their own head in the world: the Duck and
## LINT companions in a run, the Workshop's Duck, LINT and residents at their spots, a caged
## resident in its cage. A speaker with no body on screen gets the bubble pinned at the edge
## with an arrow toward them; one with no body at all falls back to the HUD's speech box.
## The HUD draws the bubble (so it keeps clear of the HUD and the overlap audit sees it);
## these are its pure parts, testable without rendering. Research: research/speak-up-0.21.md
## (Stardew's above-head lines, Rainswept's edge arrows, subtitle reading speeds).

const WIDTH := 150.0          # the widest a bubble's text runs
const WIDE := 200.0           # ... unless the line would need more lines than allowed
const CPS := 30.0             # the typewriter's floor, characters a second
const TAIL := 4.0             # the tail under the bubble
const PAD := Vector2(5, 4)
const LINE_H := 10.0


## Where a speaker's head is, in world coordinates; Vector2.INF when they have no body here.
static func anchor(world: World, who: String) -> Vector2:
	if world == null or world.run == null:
		return Vector2.INF
	var res := Residents.id_of(who)
	if world.hub:
		var key := String(res) if res != &"" else ("duck" if who == Story.DUCK else ("lint" if who == Story.LINT else ""))
		if key == "" or not world.hub.anchors.has(key):
			return Vector2.INF
		var p: Vector2 = world.hub.anchors[key][0]
		if res != &"":
			return p + Vector2(0, 8 - KernelArt.resident(res, 0).get_height() - 2)
		return p + (Vector2(0, -10) if key == "duck" else Vector2(0, -12))
	for c in world.companions:
		if c.who() == who and c.visible:
			return c.head()
	if res != &"" and not world.cage.is_empty() and StringName(world.cage.get("who", &"")) == res:
		return (world.cage["pos"] as Vector2) + Vector2(0, 8 - KernelArt.resident(res, 0).get_height() - 2)
	return Vector2.INF


## The speaker's colour: the Duck gold, LINT cyan, a resident their own.
static func color_of(who: String) -> Color:
	var res := Residents.id_of(who)
	if res != &"":
		return Color(Residents.DEFS[res]["color"])
	return Style.c("cyan:4") if who == Story.LINT else Style.UI_GOLD


## Word wrap at the pixel font's size 8.
static func wrap_text(f: Font, s: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var t := word if line == "" else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


## The lines a bubble shows: at most `max_lines` (2 in a fight, 3 in the Workshop), wider
## when it must; a line too long even then ends in "...".
static func lines_for(f: Font, s: String, max_lines: int) -> PackedStringArray:
	var ls := wrap_text(f, s, WIDTH)
	if ls.size() > max_lines:
		ls = wrap_text(f, s, WIDE)
	if ls.size() > max_lines:
		var keep: PackedStringArray = ls.slice(0, max_lines)
		var last: String = keep[max_lines - 1] + "..."
		while f.get_string_size(last, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > WIDE and last.length() > 4:
			last = last.substr(0, last.length() - 4) + "..."
		keep[max_lines - 1] = last
		ls = keep
	return ls


## How many characters show at `t` seconds into a line of `n` characters lasting `dur`:
## the typewriter runs at CPS or faster, so the whole line is out by 60% of its time.
static func shown_chars(t: float, n: int, dur: float) -> int:
	var cps := maxf(CPS, n / maxf(0.1, dur * 0.6))
	return clampi(int(t * cps), 0, n)


## The bubble's fade: pops in over 0.12 s, fades out over the last 0.2 s.
static func alpha(t: float, dur: float) -> float:
	return clampf(t / 0.12, 0.0, 1.0) * clampf((dur - t) / 0.2, 0.0, 1.0)


## Where the bubble goes, in screen pixels. `a` is the speaker's head on screen, `size` the
## bubble's, `sr` the safe screen, `taken` what the HUD covers, `hero` the hero on screen.
## Above the head, leaning away from the hero; flipped under the speaker when the top or the
## HUD is in the way; pinned at the edge (with an arrow) when the speaker is off screen.
## Returns {rect, tail_x, tail_up, pinned, arrow}.
static func layout(a: Vector2, size: Vector2, sr: Rect2, taken: Array, hero := Vector2.INF) -> Dictionary:
	var inner := sr.grow(-2.0)
	var pinned := not inner.has_point(a)
	var r := Rect2(Vector2(a.x - size.x / 2.0, a.y - TAIL - size.y), size)
	if hero != Vector2.INF and absf(hero.x - a.x) < size.x / 2.0 and hero.y > a.y - 8.0:
		# lean away from the hero, so the bubble never sits over them
		r.position.x += signf(a.x - hero.x if a.x != hero.x else 1.0) * size.x * 0.3
	var up := false
	if not pinned:
		if r.position.y < inner.position.y or _hits(r, taken):
			var below := Rect2(Vector2(r.position.x, a.y + 26.0 + TAIL), size)
			if below.end.y <= inner.end.y and not _hits(below, taken):
				r = below
				up = true
	r.position.x = clampf(r.position.x, inner.position.x, inner.end.x - size.x)
	r.position.y = clampf(r.position.y, inner.position.y, inner.end.y - size.y)
	# still on something the HUD covers: the nearest clear spot, searched outward (up and
	# down first, then sideways), so it never lands on a panel, a label or the hero
	if _hits(r, taken):
		var best := r
		var best_d := INF
		for dy in range(-160, 161, 4):
			for dx in [0.0, -0.5, 0.5, -1.0, 1.0]:
				var c := Rect2(r.position + Vector2(dx * size.x, dy), size)
				c.position.x = clampf(c.position.x, inner.position.x, inner.end.x - size.x)
				c.position.y = clampf(c.position.y, inner.position.y, inner.end.y - size.y)
				var dist := absf(dy) + absf(dx) * size.x * 0.8
				if dist < best_d and not _hits(c, taken):
					best = c
					best_d = dist
		up = up or best.position.y > a.y
		r = best
	r = Rect2(r.position.round(), r.size)
	var arrow := Vector2.ZERO
	if pinned:
		arrow = (a - r.get_center()).normalized()
	var tail_x := clampf(roundf(a.x), r.position.x + 6.0, r.end.x - 6.0)
	return {"rect": r, "tail_x": tail_x, "tail_up": up, "pinned": pinned, "arrow": arrow}


static func _hits(r: Rect2, taken: Array) -> bool:
	return _hit_rect(r, taken) != Rect2()


static func _hit_rect(r: Rect2, taken: Array) -> Rect2:
	for t in taken:
		if (t as Rect2).intersects(r.grow(1.0)):
			return t
	return Rect2()
