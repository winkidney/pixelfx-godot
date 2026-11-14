@tool
extends Node2D
## A plasma filament (lightning/plasma-ball, after the original's drawTendril): a wavy line from the electrode out to
## where it touches the glass, swaying by w1 / w2, jittered a little every frame, fanning into three short fingers
## at its foot. A front one is bright (a pale body, white-hot near its ends, a dark line under it) and flares where
## it touches the glass; a back one is a dim line. A child "Light" (light layer) gets the light along it.
## The animation keys end, angle, w1, w2, front, rim; the jitter re-rolls `rate` times a second off the effect clock.

const STEP := 2.2

@export var centre := Vector2(0, -55)
## Where it meets the glass, and the direction it leaves the electrode in (radians).
@export var end := Vector2(0, -31):
	set(v):
		end = v
		_redraw()
@export var angle := 0.0:
	set(v):
		angle = v
		_redraw()
@export var w1 := 0.0:
	set(v):
		w1 = v
		_redraw()
@export var w2 := 0.0:
	set(v):
		w2 = v
		_redraw()
@export var index := 0
@export var front := true:
	set(v):
		front = v
		_redraw()
## Its foot lies on the rim: the glass's edge lights up beside it.
@export var rim := false:
	set(v):
		rim = v
		_redraw()
@export var radius := 24.0
@export var rate := 30.0
@export var tseed := 1
## The effect's eight colours, dark to bright.
@export var colors := PackedColorArray()

var _clock_step := 0
var _light: CanvasItem


func _ready() -> void:
	_light = get_node_or_null("Light")
	if _light and not _light.draw.is_connected(_draw_light):
		_light.draw.connect(_draw_light)


func _process(_delta: float) -> void:
	var n := get_parent()
	while n and not n.has_method("play"):
		n = n.get_parent()
	var t: float = n.t if n else 0.0
	var s := int(floor(t * rate + 1e-3))
	if s != _clock_step:
		_clock_step = s
		_redraw()


func _redraw() -> void:
	queue_redraw()
	if _light:
		_light.queue_redraw()


func _shape() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(tseed, index, _clock_step))
	var s := centre + Vector2(cos(angle), sin(angle)) * 4.5
	var d := end - s
	var L := maxf(0.001, d.length())
	var nrm := Vector2(-d.y, d.x) / L
	var m := maxi(4, roundi(L / STEP))
	var pts := PackedVector2Array()
	for j in m + 1:
		var u := j / float(m)
		var w := 3.2 * w1 * sin(PI * u) + 1.6 * w2 * sin(TAU * u + index)
		var jit := rng.randf_range(-0.7, 0.7) if (j > 0 and j < m) else 0.0
		pts.append(s + d * u + nrm * (w + jit))
	var fingers := []
	for k in 3:
		var b := pts[m - 2]
		var a := angle + (k - 1) * rng.randf_range(0.25, 0.45)
		var l := rng.randf_range(2.5, 5.0)
		fingers.append(PackedVector2Array([b, b + Vector2(cos(a), sin(a)) * l * 0.5 + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6)), b + Vector2(cos(a), sin(a)) * l]))
	return {"pts": pts, "fingers": fingers, "hot": rng.randf() < 0.2}


func _c(i: int) -> Color:
	return colors[i] if colors.size() >= 8 else Color.WHITE


func _line(a: Vector2, b: Vector2, c: Color) -> void:
	var p := Vector2i(floori(a.x), floori(a.y))
	var e := Vector2i(floori(b.x), floori(b.y))
	var dx := absi(e.x - p.x)
	var dy := -absi(e.y - p.y)
	var sx := 1 if p.x < e.x else -1
	var sy := 1 if p.y < e.y else -1
	var err := dx + dy
	while true:
		draw_rect(Rect2(Vector2(p), Vector2.ONE), c)
		if p == e:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


func _draw() -> void:
	var sh := _shape()
	var pts: PackedVector2Array = sh.pts
	var n := pts.size()
	for j in n - 1:
		if front:
			_line(pts[j] + Vector2.ONE, pts[j + 1] + Vector2.ONE, _c(3))
	for j in n - 1:
		var u := j / float(n - 1)
		var c := _c(3)
		if front:
			c = _c(6) if (sh.hot or u > 0.75 or u < 0.2) else _c(5)
		_line(pts[j], pts[j + 1], c)
	for f in sh.fingers:
		for j in 2:
			_line(f[j], f[j + 1], _c(6) if front else _c(2))
	if front:
		var r2 := 1.6 * 1.6
		for py in range(floori(end.y - 2), ceili(end.y + 2) + 1):
			for px in range(floori(end.x - 2), ceili(end.x + 2) + 1):
				if Vector2(px + 0.5, py + 0.5).distance_squared_to(end) <= r2:
					draw_rect(Rect2(px, py, 1, 1), _c(6))
		draw_rect(Rect2(floorf(end.x), floorf(end.y), 1, 1), Color.WHITE)
		if rim:
			for s in [-1.0, 1.0]:
				var q := centre + Vector2(cos(angle + s * 0.09), sin(angle + s * 0.09)) * (radius - 0.5)
				draw_rect(Rect2(floorf(q.x), floorf(q.y), 1, 1), _c(6))


func _draw_light() -> void:
	var sh := _shape()
	var pts: PackedVector2Array = sh.pts
	var tex: Texture2D = preload("res://addons/pixelfx_particles/fx/lightning/_volt.gd").glow_texture()
	var lc := _c(4)
	var j := 0
	while j < pts.size() - 1:
		var r := 6.0 if front else 4.0
		var a: float = (0.4 if sh.hot else 0.24) if front else 0.12
		_light.draw_texture_rect(tex, Rect2(pts[j] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(lc, a))
		j += 3
	if front:
		_light.draw_texture_rect(tex, Rect2(end - Vector2(9, 9), Vector2(18, 18)), false, Color(_c(5), 0.55))
	else:
		_light.draw_texture_rect(tex, Rect2(end - Vector2(6, 6), Vector2(12, 12)), false, Color(lc, 0.25))
