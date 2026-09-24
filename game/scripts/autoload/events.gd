extends Node
## Global signal bus. Systems announce things here instead of holding references to each other.

signal room_cleared
signal room_entered(def: Dictionary)
signal player_hurt(amount: float)
signal player_died
signal enemy_killed(kind: StringName, pos: Vector2)
signal wand_cast(slot: int)
signal toast(text: String)
