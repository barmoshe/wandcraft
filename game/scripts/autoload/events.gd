extends Node
## Global signal bus. Systems announce things here instead of holding references to each other.

signal room_cleared
signal room_entered(def: Dictionary)
signal player_hurt(amount: float)
signal player_died
signal enemy_killed(kind: StringName, pos: Vector2)
signal wand_cast(slot: int)
signal toast(text: String)
signal boss_started(title: String, subtitle: String)
signal boss_defeated
signal boss_phase(n: int, line: String)   # design v3: the HUD's phase banner
signal hint(text: String)
signal screen_flash(color: Color, amount: float)
signal shockwave(world_pos: Vector2)   # boss phase changes (D7): main draws a screen ripple
