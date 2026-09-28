class_name WandDef
extends Resource
## A wand body. Original names and numbers (decisions/0002).

@export var id: StringName
@export var title: String
@export var rarity := 0
@export var slots := 5
@export var max_mana := 80.0
@export var regen := 18.0
@export var cast_delay := 0.15
@export var recharge := 0.5
@export var scatter := 5.0        # degrees
@export var simultaneous := 1
@export var reverse := false
@export var color := Color("#c79a5a")
## Quirks (D2): the last slot fires on its own every few seconds (Daemon Rod), and
## Debugger runes cost double on this wand (Debug Build).
@export var background_slot := false
@export var rune_tax := 1.0
## 0.20 wand rules (research/arsenal-0.20/6-spells-wands.md): shuffle (Shuffle Play, a new order
## each recharge), pinned (Pinned Tab, slot 1 joins every cast), palindrome (Palindrome Staff,
## there and back), pages (Double Buffer, two halves in turn), recycle (Recycle Bin, kills refill).
## 0.21 (research/arsenal-0.21.md): channel (Channel Rod, still casts stack damage), blood (Unsafe
## Staff, HP pays), singleton (repeats sit out; variety adds damage), decorator (a boost powers only
## the next spell, twice), hot_reload (switching to it ends its recharge), monorepo (recharge grows
## with each spell on it).
@export var rule: StringName = &""
@export var desc := ""
