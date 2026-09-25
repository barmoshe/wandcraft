extends "res://tests/unit/test_helpers.gd"
## Menu logic, driven through the same press() the touch input uses (no rendering).

var tree: SceneTree


func setup(t: SceneTree) -> void:
	tree = t
	SaveGame.enabled = false


func teardown() -> void:
	SaveGame.enabled = true


func _open(s: Screen, r: RunState) -> Screen:
	s.run = r
	tree.root.add_child(s)
	# during the runner's _initialize the tree is not running yet, so _ready is deferred
	if not s.is_node_ready():
		s._opened()
	return s


func test_reward_needs_a_pick_before_take() -> void:
	var r := RunState.create(1)
	var s := RewardScreen.new()
	s.kind = &"spell"
	s.offer = Rewards.offer(r, &"spell")
	_open(s, r)
	var got := []
	s.finished.connect(func(res: Dictionary) -> void: got.append(res))
	s.press("take")
	eq(got.size(), 0, "TAKE does nothing until a card is picked")
	s.press("card1")
	eq(s.sel, 1, "tapping a card only selects it")
	s.press("take")
	eq(got.size(), 1, "then TAKE confirms")
	eq(got[0]["taken"], s.offer[1], "the picked card")
	s.free()


func test_reward_skip_pays_gold() -> void:
	var r := RunState.create(1)
	var s := RewardScreen.new()
	s.kind = &"relic"
	s.offer = Rewards.offer(r, &"relic")
	_open(s, r)
	s.press("skip")
	eq(r.gold, Rewards.SKIP_GOLD, "skip pays")
	eq(r.relics.size(), 0, "and takes nothing")
	s.free()


func test_shop_buys_only_what_you_can_afford() -> void:
	var r := RunState.create(2)
	r.shop = Rewards.shop_stock(r)
	var s := ShopScreen.new()
	_open(s, r)
	s.press("item0")
	s.press("buy")
	ok(not r.shop[0]["sold"], "no gold, no sale")
	r.gold = 500
	s.press("buy")
	ok(r.shop[0]["sold"], "sold")
	eq(r.gold, 500 - int(r.shop[0]["price"]), "paid")
	s.free()


func test_forge_upgrades_a_spell() -> void:
	var r := RunState.create(2)
	r.gold = 100
	var s := ShopScreen.new()
	s.mode = "forge"
	_open(s, r)
	s.press("item1")   # item0 is the +1 slot
	s.press("buy")
	eq(int(r.wand().slots[0]["lv"]), 2, "the mote is level 2")
	eq(r.gold, 100 - Rewards.forge_price(1), "paid the forge")
	var n := r.wand().slots.size()
	r.gold = 100
	s.press("item0")
	s.press("buy")
	eq(r.wand().slots.size(), n + 1, "+1 slot bought")
	eq(r.gold, 100 - Rewards.SLOT_PRICE, "for its price")
	s.free()


func test_editor_tap_to_move_and_revert() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([&"mote", &"fan", null, null])
	var s := EditorScreen.new()
	_open(s, r)
	s.press("slot:0:1")
	eq(s.sel, {"w": 0, "i": 1}, "tap picks the fan")
	s.press("slot:0:3")
	ok(r.wand().slots[1] == null and r.wand().slots[3]["id"] == &"fan", "tap on a slot moves it there")
	s.press("slot:0:0")
	s.press("slot:-1:0")
	eq(r.bag.size(), 1, "into the bag")
	s.press("revert")
	eq(r.wand().slots[0]["id"], &"mote", "revert brings the mote back")
	eq(r.wand().slots[1]["id"], &"fan", "and the fan")
	eq(r.bag.size(), 0, "and empties the bag again")
	s.free()


func test_editor_selects_the_wand_in_hand() -> void:
	var r := RunState.create(3)
	r.add_wand(&"oak")
	r.cur = 0
	var s := EditorScreen.new()
	_open(s, r)
	s.press("wand1")
	eq(r.cur, 1, "tapping a wand's name puts it in hand")
	s.free()


func test_pause_abandon_needs_two_taps() -> void:
	var r := RunState.create(3)
	var s := PauseScreen.new()
	_open(s, r)
	var got := []
	s.finished.connect(func(res: Dictionary) -> void: got.append(res))
	s.press("abandon")
	eq(got.size(), 0, "one tap only arms it")
	s.press("abandon")
	eq(got, [{"abandon": true}], "the second tap abandons")
	s.free()
