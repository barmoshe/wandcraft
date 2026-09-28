class_name ArtSheets
extends RefCounted
## What each art sheet shows (tests/art/artsheet.gd). Add new art here as it is drawn.


## D1 readability check: each actor on a real floor patch, then the same in grayscale (the
## value test: does it still separate from the ground?) and as a silhouette.
static func check(s: Node) -> void:
	var grid := PackedByteArray()
	grid.resize(8 * 6)
	grid.fill(0)
	var room := RoomPainter.paint(grid, 8, 6, 5)
	var o := RoomPainter.MARGIN * RoomPainter.TS
	var patch := room.get_region(Rect2i(o + Vector2i(16, 16), Vector2i(64, 48)))
	var actors: Array = []
	for h in Hero.LOOKS:
		actors.append([String(h), Hero.frames(h)[0]])
	for k in Bestiary.ART:
		actors.append([k, Bestiary.frames(k)[0]])
	actors.append(["loop head", Bestiary.loop_head(false)])
	_check_on(s, patch, actors, "actors on the floor | grayscale value test | silhouette")
	# 0.20: the Kernel's actors and hazards on its own floors (the Archive, then Ring Zero)
	var kernel: Array = []
	for k in ["leak", "null_ptr", "interrupt"]:
		kernel.append([k, Bestiary.frames(k)[0]])
	kernel.append(["thread A", KernelArt.thread(0, 0)])
	kernel.append(["thread B", KernelArt.thread(1, 0)])
	for p2 in 3:
		kernel.append(["glitch %d" % p2, KernelArt.glitch(p2, 0)])
	for id in [&"grep", &"hotfix", &"cache"]:
		kernel.append([String(id), KernelArt.resident(id, 0)])
	kernel.append(["puddle", KernelArt.puddle(10, 0)])
	kernel.append(["revert", KernelArt.revert_glyph(0)])
	kernel.append(["page", KernelArt.page(0)])
	for b in [4, 5]:
		var kroom := RoomPainter.paint(grid, 8, 6, 5, b)
		var kpatch := kroom.get_region(Rect2i(o + Vector2i(16, 16), Vector2i(64, 56)))
		_check_on(s, kpatch, kernel, "kernel on theme %d | value | silhouette" % b)


static func _check_on(s: Node, patch: Image, actors: Array, title: String) -> void:
	s.section(title)
	for a in actors:
		var spr: Image = (a[1] as Texture2D).get_image()
		var on := patch.duplicate() as Image
		var at := Vector2i((on.get_width() - spr.get_width()) / 2, on.get_height() - spr.get_height() - 6)
		on.blend_rect(spr, Rect2i(Vector2i.ZERO, spr.get_size()), at)
		s.add("%s" % a[0], ImageTexture.create_from_image(on))
		var gray := on.duplicate() as Image
		for j in gray.get_height():
			for i in gray.get_width():
				var c := gray.get_pixel(i, j)
				var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				gray.set_pixel(i, j, Color(l, l, l))
		s.add("value", ImageTexture.create_from_image(gray))
		var sil := spr.duplicate() as Image
		for j in sil.get_height():
			for i in sil.get_width():
				if sil.get_pixel(i, j).a > 0.0:
					sil.set_pixel(i, j, Color(0.9, 0.9, 0.95))
		s.add("shape", ImageTexture.create_from_image(sil))


## D6: every rig clip as a strip (frames left to right), the wand's 16 angles.
static func anim(s: Node) -> void:
	for back in [false, true]:
		var c := Hero.clips(back)
		for k in c:
			s.section("hero %s: %s" % ["back" if back else "front", k])
			var fr: Array = c[k]
			for i in fr.size():
				s.add("%d" % i, fr[i])
	for k in Bestiary.ART:
		var c := Bestiary.clips(k)
		s.section("%s: move | tele | attack" % k)
		for clip in ["move", "tele", "attack"]:
			var fr: Array = c[clip]
			for i in fr.size():
				s.add("%s %d" % [clip, i], fr[i])
	var lc := Bestiary.clips_of(Bestiary.loop_rig())
	for clip in lc:
		s.section("loop head: %s" % clip)
		for i in (lc[clip] as Array).size():
			s.add("%d" % i, lc[clip][i])
	s.section("loop head, 16 headings (chomp 0)")
	for i in 16:
		s.add("%d" % i, Bestiary.loop_head_view("chomp", 0, i))
	var cc := Bestiary.clone_clips()
	s.section("copy-paste: run | cast | hurt")
	for clip in ["run", "cast", "hurt"]:
		for i in (cc[clip] as Array).size():
			s.add("%s %d" % [clip, i], cc[clip][i])
	s.section("death poof")
	var pf := FxLayer.poof_frames()
	for i in pf.size():
		s.add("%d" % i, pf[i])
	s.section("wand, 16 angles")
	var wa := Hero.wand_angles()
	for i in wa.size():
		s.add("%d" % i, wa[i])


static func chars(s: Node) -> void:
	# 0.19: every hero's look, front frames then the back view
	for h in Hero.LOOKS:
		s.section("hero: %s" % h)
		var hf: Array = Hero.frames(h)
		for i in hf.size():
			s.add("%d" % i, hf[i])
		s.add("back", Hero.clips(true, h)["idle"][0])
	s.section("wizard (old)")
	var wf: Array = Sprites.wizard_frames()
	for i in wf.size():
		s.add("wiz %d" % i, wf[i])
	s.section("bestiary (0.4)")
	for k in Bestiary.ART:
		var bf: Array = Bestiary.frames(k)
		for i in bf.size():
			s.add("%s %d" % [k, i], bf[i])
	s.add("loop head", Bestiary.loop_head(false))
	s.add("loop head open", Bestiary.loop_head(true))
	var cf: Array = Bestiary.clone_frames()
	for i in [0, 2, 6]:
		s.add("clone %d" % i, cf[i])
	for h in [&"pyromancer", &"tinkerer"]:
		s.add("clone %s" % h, Bestiary.clone_frames(h)[0])
	s.section("enemies (old)")
	for k in Sprites.ENEMY_ART:
		var fr: Array = Sprites.enemy_frames(k)
		for i in fr.size():
			s.add("%s %d" % [k, i], fr[i])
	s.section("bosses")
	for k in Sprites.BOSS_ART:
		s.add(String(k), Sprites.boss_texture(k))
	kernel_chars(s)


## 0.20, World 3 the Kernel: the twins, the Glitch by phase and the residents.
static func kernel_chars(s: Node) -> void:
	s.section("kernel: data race twins (run 0-3, wind-up 4)")
	for w in 2:
		for i in 5:
			s.add("thread %s %d" % ["AB"[w], i], KernelArt.thread(w, i))
	for p in 3:
		s.section("kernel: the glitch, phase %d (idle 0-3, telegraph 4)" % p)
		for i in 5:
			s.add("glitch %d.%d" % [p, i], KernelArt.glitch(p, i))
	s.section("kernel: residents (idle 0-3)")
	for id in [&"grep", &"hotfix", &"cache"]:
		for i in 4:
			s.add("%s %d" % [id, i], KernelArt.resident(id, i))


## Icon art straight from the IconSpells / IconRelics data, including items whose gameplay
## is not in the catalog yet ("kind" in the entry: proj, boost, trig, passive).
static func icons(s: Node) -> void:
	const KINDS := {"proj": SpellDef.Kind.PROJ, "boost": SpellDef.Kind.BOOST, "trig": SpellDef.Kind.TRIG, "passive": SpellDef.Kind.PASSIVE}
	s.section("spells")
	var all_spells: Dictionary = IconSpells.ART.duplicate()
	all_spells.merge(IconSpellsB.ART)
	all_spells.merge(IconSpellsC.ART)
	all_spells.merge(IconSpellsD.ART)
	for id in all_spells:
		var e: Dictionary = all_spells[id]
		var kind: int = KINDS.get(e.get("kind", ""), Catalog.spell(id).kind if Catalog.spells().has(id) else SpellDef.Kind.PROJ)
		s.add(String(id), PixelArt.tex(Icons.framed(kind, e)))
	s.section("relics")
	for id in IconRelics.ART:
		s.add(String(id), PixelArt.tex(Icons.framed(-1, IconRelics.ART[id])))
	for id in IconSpellsD.RELICS:
		s.add(String(id), PixelArt.tex(Icons.framed(-1, IconSpellsD.RELICS[id])))
	s.section("not drawn yet")
	for id in Catalog.spells():
		if IconArt.spell(id).is_empty():
			s.add(String(id), Icons.spell(Catalog.spell(id)))
	for id in Relics.DEFS:
		if IconArt.relic(id).is_empty():
			s.add(String(id), Icons.relic(id))


static func tiles(s: Node) -> void:
	s.section("props")
	for k in ["spell", "relic", "boss", "shop"]:
		var c := Color(Chapter.INFO.get(k, {"color": "#ffffff"})["color"])
		s.add("door %s" % k, Props.door(c, true))
	s.add("door closed", Props.door(Color.WHITE, false))
	s.add("altar", Props.altar(Color("#ffe066")))
	s.add("fountain", Props.fountain(true))
	s.add("fountain dry", Props.fountain(false))
	s.add("merchant 0", Props.merchant(0))
	s.add("merchant 1", Props.merchant(1))
	s.add("anvil", Props.anvil())
	for i in 3:
		s.add("flame %d" % i, Props.flame(i))
	s.add("sconce", Props.sconce())
	for b in RoomPainter.THEMES.size():
		s.add("bramble %d" % b, Props.bramble(b))
	rooms(s)


## Every room theme on a small sample room (walls, a pillar, a pit, spikes, a bramble), with
## the margin's surroundings, raw and under the world's ambient tint.
static func rooms(s: Node, themes: Array = []) -> void:
	var gw := 14
	var gh := 9
	var grid := PackedByteArray()
	grid.resize(gw * gh)
	grid.fill(0)
	for x in gw:
		grid[x] = 1
		grid[(gh - 1) * gw + x] = 1
	for y in gh:
		grid[y * gw] = 1
		grid[y * gw + gw - 1] = 1
	grid[3 * gw + 4] = 1
	grid[4 * gw + 4] = 1
	grid[5 * gw + 9] = 5
	grid[6 * gw + 9] = 5
	grid[2 * gw + 10] = 2
	grid[6 * gw + 3] = 7
	var ts := RoomPainter.TS
	var cut := Rect2i((RoomPainter.MARGIN - Vector2i(5, 4)) * ts, Vector2i(gw + 10, gh + 8) * ts)
	var list := themes if not themes.is_empty() else range(RoomPainter.THEMES.size())
	for b in list:
		s.section("room theme %d" % b)
		var img := RoomPainter.paint(grid, gw, gh, 11 + b, b).get_region(cut)
		s.add("theme %d" % b, ImageTexture.create_from_image(img))


static func fx(s: Node) -> void:
	s.section("projectiles")
	s.add("atlas", Projectiles.atlas())
	kernel_fx(s)


## 0.20: the residents' speech-box faces (next to the Duck's and LINT's) and the Kernel's
## props, glyphs and hazards.
static func kernel_fx(s: Node) -> void:
	s.section("speech faces: duck, lint | resident x mood (neutral happy worried stern), talk, blink")
	s.add("duck", Hud.duck_face())
	s.add("lint", Hud.lint_face())
	for id in [&"grep", &"hotfix", &"cache"]:
		for m in 4:
			s.add("%s %d" % [id, m], KernelArt.portrait(id, m, false, false))
		s.add("talk", KernelArt.portrait(id, 0, true, false))
		s.add("blink", KernelArt.portrait(id, 0, false, true))
		s.add("happy talk", KernelArt.portrait(id, 1, true, false))
	s.section("kernel props")
	s.add("cage", KernelArt.cage(false))
	s.add("cage open", KernelArt.cage(true))
	s.add("clock w1", KernelArt.clock("16:59:57"))
	s.add("clock w3", KernelArt.clock("16:59:59"))
	s.add("clock 16:58", KernelArt.clock("16:58"))
	for i in 4:
		s.add("revert %d" % i, KernelArt.revert_glyph(i))
	for i in 4:
		s.add("page %d" % i, KernelArt.page(i))
	for r in [4, 8, 12, 16]:
		for i in 2:
			s.add("puddle r%d.%d" % [r, i], KernelArt.puddle(r, i))
	s.add("diff -", KernelArt.diff_row(64, false))
	s.add("diff +", KernelArt.diff_row(64, true))


## D6: the HUD's own icons and the wand badge in every gem colour.
static func ui(s: Node) -> void:
	s.section("hud icons")
	s.add("coin", HudIcons.coin())
	s.add("pause", HudIcons.pause())
	s.add("bag", HudIcons.bag())
	s.add("heart", HudIcons.heart())
	s.add("drop", HudIcons.drop())
	s.section("wand badge by gem")
	for g in Hero.GEMS:
		s.add(g, Hero.wand_angles(g)[14])


## The 0.4 style frames sent to Bar: new art next to the old.
static func style(s: Node) -> void:
	s.section("hero: new / old")
	var hf: Array = Hero.frames()
	s.add("new idle", hf[0])
	s.add("new walk", hf[2])
	s.add("new cast", hf[6])
	s.add("old", Sprites.wizard_frames()[0])
	s.section("enemies: new / old")
	for k in Bestiary.ART:
		s.add("new " + k, Bestiary.frames(k)[0])
		if Sprites.ENEMY_ART.has(k):
			s.add("old " + k, Sprites.enemy_frames(k)[0])
	s.section("spell and relic icons: new / old")
	for id in ["mote", "ember", "frost", "empower", "then"]:
		s.add("new " + id, Icons.spell(Catalog.spell(StringName(id))))
	for id in ["hot_patch", "wildfire"]:
		s.add("new " + id, Icons.relic(StringName(id)))
	s.add("old mote", PixelArt.cached("old_mote", func() -> Image: return Icons._build(Catalog.spell(&"mote"))))
	s.add("old ember", PixelArt.cached("old_ember", func() -> Image: return Icons._build(Catalog.spell(&"ember"))))
