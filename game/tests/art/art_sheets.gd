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
	var actors: Array = [["hero", Hero.frames()[0]]]
	for k in Bestiary.ART:
		actors.append([k, Bestiary.frames(k)[0]])
	actors.append(["loop head", Bestiary.loop_head(false)])
	s.section("actors on the floor | grayscale value test | silhouette")
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


static func chars(s: Node) -> void:
	s.section("hero (0.4)")
	var hf: Array = Hero.frames()
	for i in hf.size():
		s.add("hero %d" % i, hf[i])
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
	s.section("enemies (old)")
	for k in Sprites.ENEMY_ART:
		var fr: Array = Sprites.enemy_frames(k)
		for i in fr.size():
			s.add("%s %d" % [k, i], fr[i])
	s.section("bosses")
	for k in Sprites.BOSS_ART:
		s.add(String(k), Sprites.boss_texture(k))


## Icon art straight from the IconSpells / IconRelics data, including items whose gameplay
## is not in the catalog yet ("kind" in the entry: proj, boost, trig, passive).
static func icons(s: Node) -> void:
	const KINDS := {"proj": SpellDef.Kind.PROJ, "boost": SpellDef.Kind.BOOST, "trig": SpellDef.Kind.TRIG, "passive": SpellDef.Kind.PASSIVE}
	s.section("spells")
	var all_spells: Dictionary = IconSpells.ART.duplicate()
	all_spells.merge(IconSpellsB.ART)
	all_spells.merge(IconSpellsC.ART)
	for id in all_spells:
		var e: Dictionary = all_spells[id]
		var kind: int = KINDS.get(e.get("kind", ""), Catalog.spell(id).kind if Catalog.spells().has(id) else SpellDef.Kind.PROJ)
		s.add(String(id), PixelArt.tex(Icons.framed(kind, e)))
	s.section("relics")
	for id in IconRelics.ART:
		s.add(String(id), PixelArt.tex(Icons.framed(-1, IconRelics.ART[id])))
	s.section("not drawn yet")
	for id in Catalog.spells():
		if IconArt.spell(id).is_empty():
			s.add(String(id), Icons.spell(Catalog.spell(id)))
	for id in Relics.DEFS:
		if not IconRelics.ART.has(id):
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


static func fx(s: Node) -> void:
	s.section("projectiles")
	s.add("atlas", Projectiles.atlas())


static func ui(_s: Node) -> void:
	pass


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
		s.add("old " + k, Sprites.enemy_frames(k)[0])
	s.section("spell and relic icons: new / old")
	for id in ["mote", "ember", "frost", "empower", "then"]:
		s.add("new " + id, Icons.spell(Catalog.spell(StringName(id))))
	for id in ["hot_patch", "wildfire"]:
		s.add("new " + id, Icons.relic(StringName(id)))
	s.add("old mote", PixelArt.cached("old_mote", func() -> Image: return Icons._build(Catalog.spell(&"mote"))))
	s.add("old ember", PixelArt.cached("old_ember", func() -> Image: return Icons._build(Catalog.spell(&"ember"))))
