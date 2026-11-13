@tool
extends Line2D
## A lightning bolt (or an arc, a crackle, a tendril): a jagged line from `from` to `to` that re-rolls its zigzag
## `rate` times a second, seeded, so the same effect time always draws the same bolt. Branches fork off it. It reads
## the effect's clock (PfxEffect.t), so it freezes with a hit-stop and renders the same every time.
## Key `from`, `to`, `jag`, `visible` and the Line2D's width and colour to animate it.

@export var from := Vector2.ZERO
@export var to := Vector2(0, 40)
## How far a joint strays from the straight line, in px, and how many segments.
@export var jag := 4.0
@export var segments := 8
## Re-rolls a second (0: never).
@export var rate := 15.0
@export var bolt_seed := 1
## Branches forking off the main line: how many, how long (share of the bolt), and their own Line2D width.
@export var branches := 0
@export var branch_length := 0.35
@export var branch_width := 1.0

var _step := -1
var _built := []
var _branches: Array[Line2D] = []


func _ready() -> void:
	_rebuild(0)


func _process(_delta: float) -> void:
	var fx := _effect()
	var t: float = fx.t if fx else 0.0
	var step := int(floor(t * rate)) if rate > 0.0 else 0
	# re-roll on the next step, and redraw at once when the ends or the jag are keyed somewhere new
	if step != _step or _built != [from, to, jag]:
		_rebuild(step)


func _effect() -> Node:
	var n := get_parent()
	while n and not n.has_method("play"):
		n = n.get_parent()
	return n


func _rebuild(step: int) -> void:
	_step = step
	_built = [from, to, jag]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(bolt_seed, step, segments))
	points = _zigzag(from, to, segments, jag, rng)
	for b in _branches:
		b.queue_free()
	_branches.clear()
	for i in branches:
		var at := rng.randi_range(1, maxi(1, points.size() - 2))
		var p0 := points[at]
		var dir := (to - from).normalized().rotated(rng.randf_range(-0.9, 0.9))
		var p1 := p0 + dir * (to - from).length() * branch_length * rng.randf_range(0.5, 1.0)
		var b := Line2D.new()
		b.width = branch_width
		b.default_color = default_color
		b.gradient = gradient
		b.antialiased = false
		b.use_parent_material = true
		b.points = _zigzag(p0, p1, maxi(2, int(segments / 3.0)), jag * 0.6, rng)
		add_child(b)
		b.owner = null
		_branches.append(b)


static func _zigzag(a: Vector2, b: Vector2, n: int, j: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	var side := (b - a).orthogonal().normalized()
	for k in range(1, n):
		var u := k / float(n)
		out.append((a.lerp(b, u) + side * rng.randf_range(-j, j)).round())
	out.append(b)
	return out
