class_name SpatialHash
extends RefCounted
## Uniform grid of enemy indices, rebuilt every physics tick. Queries return indices into
## the world's enemy array.

const CELL := 32.0

var cols := 1
var rows := 1
var cells: Array = []   # Array[PackedInt32Array]
## 1 where the cell or one of its 8 neighbours holds an enemy. Small queries (radius under
## one cell) can skip everything when their own cell reads 0.
var near := PackedByteArray()


func resize(width_px: float, height_px: float) -> void:
	cols = maxi(1, ceili(width_px / CELL))
	rows = maxi(1, ceili(height_px / CELL))
	cells.resize(cols * rows)
	near.resize(cols * rows)


func rebuild(enemies: Array) -> void:
	near.fill(0)
	for i in cells.size():
		cells[i] = PackedInt32Array()
	for idx in enemies.size():
		var e: Enemy = enemies[idx]
		if e.dead:
			continue
		var cx := clampi(int(e.position.x / CELL), 0, cols - 1)
		var cy := clampi(int(e.position.y / CELL), 0, rows - 1)
		var c: PackedInt32Array = cells[cy * cols + cx]
		c.append(idx)
		cells[cy * cols + cx] = c
		for ny in range(maxi(0, cy - 1), mini(rows, cy + 2)):
			for nx in range(maxi(0, cx - 1), mini(cols, cx + 2)):
				near[ny * cols + nx] = 1


func query(p: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0 := clampi(int((p.x - r) / CELL), 0, cols - 1)
	var x1 := clampi(int((p.x + r) / CELL), 0, cols - 1)
	var y0 := clampi(int((p.y - r) / CELL), 0, rows - 1)
	var y1 := clampi(int((p.y + r) / CELL), 0, rows - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out.append_array(cells[y * cols + x])
	return out


## Cell range covering a circle, as [x0, y0, x1, y1]; iterate `cells` directly with it
## in hot loops to avoid allocating a result array per query.
func span(p: Vector2, r: float) -> Vector4i:
	return Vector4i(
		clampi(int((p.x - r) / CELL), 0, cols - 1), clampi(int((p.y - r) / CELL), 0, rows - 1),
		clampi(int((p.x + r) / CELL), 0, cols - 1), clampi(int((p.y + r) / CELL), 0, rows - 1))
