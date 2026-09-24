class_name ArtSheets
extends RefCounted
## What each art sheet shows (tests/art/artsheet.gd). Add new art here as it is drawn.


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
	for id in IconSpells.ART:
		var e: Dictionary = IconSpells.ART[id]
		var kind: int = KINDS.get(e.get("kind", ""), Catalog.spell(id).kind if Catalog.spells().has(id) else SpellDef.Kind.PROJ)
		s.add(String(id), PixelArt.tex(Icons.framed(kind, e)))
	s.section("relics")
	for id in IconRelics.ART:
		s.add(String(id), PixelArt.tex(Icons.framed(-1, IconRelics.ART[id])))
	s.section("not drawn yet")
	for id in Catalog.spells():
		if not IconSpells.ART.has(id):
			s.add(String(id), Icons.spell(Catalog.spell(id)))
	for id in Relics.DEFS:
		if not IconRelics.ART.has(id):
			s.add(String(id), Icons.relic(id))


static func tiles(s: Node) -> void:
	s.section("room")


static func fx(s: Node) -> void:
	s.section("bullets")
	s.add("bullet", PixelArt.bullet_texture())


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
	for id in ["hot_patch", "overclock"]:
		s.add("new " + id, Icons.relic(StringName(id)))
	s.add("old mote", PixelArt.cached("old_mote", func() -> Image: return Icons._build(Catalog.spell(&"mote"))))
	s.add("old ember", PixelArt.cached("old_ember", func() -> Image: return Icons._build(Catalog.spell(&"ember"))))
