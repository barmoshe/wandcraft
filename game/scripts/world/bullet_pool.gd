class_name BulletPool
extends MultiMeshInstance2D
## Fixed-capacity bullet storage drawn in one call through a MultiMesh (additive glow).
## Bullets are plain objects recycled from `_free`; `active` holds the live ones in spawn
## order. Positions are interpolated between physics ticks for smooth 120 Hz output.

var active: Array[Bullet] = []
var _free: Array[Bullet] = []
var capacity := 0
var base_size := 8.0


func setup(cap: int, tex: Texture2D, additive := true) -> void:
	capacity = cap
	for i in cap:
		_free.append(Bullet.new())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	base_size = float(tex.get_width())
	q.size = Vector2(base_size, base_size)
	mm.mesh = q
	mm.instance_count = cap
	mm.visible_instance_count = 0
	multimesh = mm
	texture = tex
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	# bullets are interpolated by hand in sync(); the node itself never moves
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Returns a reset bullet, or null when the pool is full (the cast simply fizzles).
func spawn() -> Bullet:
	if _free.is_empty():
		return null
	var b: Bullet = _free.pop_back()
	b.reset()
	active.append(b)
	return b


func live_count() -> int:
	return active.size()


## Moves dead bullets back to the free list, keeping spawn order.
func compact() -> void:
	var w := 0
	for i in active.size():
		var b := active[i]
		if b.alive:
			active[w] = b
			w += 1
		else:
			_free.append(b)
	active.resize(w)


func clear_all() -> void:
	for b in active:
		b.alive = false
	compact()


func sync(frac: float) -> void:
	var mm := multimesh
	var n := mini(active.size(), capacity)
	for i in n:
		var b := active[i]
		var p := b.prev.lerp(b.pos, frac) if b.alive else b.pos
		var s := b.size * (b.r * 2.0 + 3.0) / base_size
		var fade := clampf(b.life * 8.0, 0.0, 1.0)
		mm.set_instance_transform_2d(i, Transform2D(b.spin, Vector2(s, s), 0.0, p.round()))
		var c := b.color
		mm.set_instance_color(i, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, fade if b.alive else 0.0))
	mm.visible_instance_count = n
