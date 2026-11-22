@tool
extends Node2D
## A lightning bolt inked the way the lightning originals ink one (src/fx/lightning/_lib.js): a jagged trunk by
## midpoint displacement whose forks split off and thin (zigzag), or bowed off the straight line (bowed), drawn
##   style 0, a stroke: a deep halo, a pale body and a white core on the trunk; forks drop out below k 0.5, the trunk
##            thins below 0.6, the core goes below 0.3; `hero` (a white frame) turns the body white;
##   style 1, a crackle: a 1 px core, a 2 px pale body, a dithered halo while k is high (short arcs);
##   style 2, a trace: the trunk as a 1 px line in `trace_color` (cooling channels, afterimages).
## A child named "Light" (on the light layer) gets the light along it, every third point.
## The shape re-rolls `rate` times a second off the effect's clock (PfxEffect.t), or, with rate 0, whenever the
## animation keys `step`; it is seeded, so the same time always draws the same bolt. Key from, to, bow, k, hero,
## up_to, alpha, visible. The lightning effects' own stand-in for core/bolt.gd, which draws one flat Line2D.

const CROSS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

@export var from := Vector2.ZERO:
	set(v):
		from = v
		_dirty()
@export var to := Vector2(0, 40):
	set(v):
		to = v
		_dirty()
## px off the straight line at the middle (bowed arcs; negative bows up for a left-to-right arc). 0: a plain bolt.
@export var bow := 0.0:
	set(v):
		bow = v
		_dirty()
## How far the first midpoint may swing, as a share of the length, and how readily it forks.
@export var jag := 0.3:
	set(v):
		jag = v
		_dirty()
@export var forks := 0.35:
	set(v):
		forks = v
		_dirty()
@export var bolt_seed := 1:
	set(v):
		bolt_seed = v
		_dirty()
## Re-rolls a second off the effect's clock; 0: the keyed `step` picks the shape.
@export var rate := 15.0
@export var step := 0:
	set(v):
		if v != step:
			step = v
			if rate <= 0.0:
				_dirty()
## Brightness, the original's k: thickness, forks, core and light all follow it. <= 0.02 draws nothing.
@export var k := 1.0:
	set(v):
		k = v
		_redraw()
## Thickness scale (the original's s).
@export var thick := 1.0:
	set(v):
		thick = v
		_redraw()
@export var hero := false:
	set(v):
		hero = v
		_redraw()
## Draw the trunk only to this share of its length (a leader racing out); below 1 the forks wait.
@export var up_to := 1.0:
	set(v):
		up_to = v
		_redraw()
## 0 stroke, 1 crackle, 2 trace.
@export var style := 0:
	set(v):
		style = v
		_redraw()
@export var alpha := 1.0:
	set(v):
		alpha = v
		_redraw()
## Radius of a thicker white core (0: one pixel).
@export var core := 0.0
## While the trunk is drawn only part way (up_to < 1): a white head of this radius at its tip, with light
## (head_light strength, head_reach radius, in light_color's place C[5]).
@export var head := 0.0
@export var head_light := 0.6
@export var head_reach := 14.0
## Light strength along it (the original's o.light / glowK) and how wide it spreads (x the original's radius).
@export var light := 0.5:
	set(v):
		light = v
		_redraw()
@export var light_reach := 1.0
## The effect's eight colours, dark to bright (the original's C).
@export var colors := PackedColorArray()
@export var trace_color := Color.WHITE:
	set(v):
		trace_color = v
		_redraw()
## Light colour (C[4] by default).
@export var light_color := Color(0, 0, 0, 0)

@export_group("Strike")
## Shape: keep only the trunk; bend it sideways by `drift` px at the middle of its height (drift_top: the top's y);
## trim forks that leave |x| < keep_w - 5, the floor (y > -3) or the top (y < drift_top + 6) (0: no trimming).
@export var trunk_only := false
@export var drift := 0.0
@export var drift_top := -224.0
@export var keep_w := 0.0
## style 2: draw the trunk from this share of its length (a dart running down it).
@export var start_at := 0.0:
	set(v):
		start_at = v
		_redraw()
## style 3, a stepped leader: every path as a 1 px line down to y_reach, the stretch below y_prev young (bright while
## `fresh` > 0.4), above it old and dim; a white tip where it stops.
@export var y_reach := 0.0:
	set(v):
		y_reach = v
		_redraw()
@export var y_prev := 0.0
@export var fresh := 1.0
## style 4, a spent channel crumbling from the top down: `crumble` s after its last stroke, each segment cooling
## and gone at its own moment (sooner higher up), as the original's lightning-strike does.
@export var crumble := 0.0:
	set(v):
		crumble = v
		_redraw()

static var _glow_tex: ImageTexture

var _paths: Array = []
var _built := false
var _clock_step := -1
var _light: CanvasItem


func _ready() -> void:
	_light = get_node_or_null("Light")
	if _light and not _light.draw.is_connected(_draw_light):
		_light.draw.connect(_draw_light)
	_rebuild()


func _process(_delta: float) -> void:
	if rate <= 0.0:
		return
	var fx := _effect()
	var t: float = fx.t if fx else 0.0
	var s := int(floor(t * rate + 1e-3))
	if s != _clock_step:
		_clock_step = s
		_rebuild()


func _effect() -> Node:
	var n := get_parent()
	while n and not n.has_method("play"):
		n = n.get_parent()
	return n


func _dirty() -> void:
	if is_inside_tree():
		_rebuild()


func _redraw() -> void:
	queue_redraw()
	if _light:
		_light.queue_redraw()


func _rebuild() -> void:
	var rng := RandomNumberGenerator.new()
	var s := _clock_step if rate > 0.0 else step
	rng.seed = hash(Vector3i(bolt_seed, s, 7919))
	_paths = []
	if absf(bow) > 0.001:
		_bowed(rng, from, to, bow, jag, forks)
	else:
		_zigzag(rng, from, to, jag, forks, 1.0, 0, _paths)
	if keep_w > 0.0:
		var kept := []
		for q in _paths:
			var pts := PackedVector2Array()
			for pt in q.pts:
				if absf(pt.x) > keep_w - 5.0 or pt.y > -3.0 or pt.y < drift_top + 6.0:
					break
				pts.append(pt)
			if q.w >= 1.0 or pts.size() > 3:
				kept.append({"pts": q.pts if q.w >= 1.0 else pts, "w": q.w})
		_paths = kept
	if trunk_only:
		_paths = _paths.slice(0, 1)
	if absf(drift) > 0.0:
		for q in _paths:
			var pts: PackedVector2Array = q.pts
			for i in pts.size():
				pts[i] = Vector2(pts[i].x + drift * sin(PI * pts[i].y / drift_top), pts[i].y)
			q.pts = pts
	_built = true
	_redraw()


# ------------------------------------------------------------------ shape (the original's zigzag and bowed)

static func _zigzag(rng: RandomNumberGenerator, a: Vector2, b: Vector2, j: float, fk: float, w: float, depth: int, out: Array) -> void:
	var L := a.distance_to(b)
	var pts := PackedVector2Array([a, b])
	var off := L * j
	while pts.size() < 2.0 + L / 3.0:
		var nxt := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			var A := pts[i]
			var B := pts[i + 1]
			var l := A.distance_to(B)
			if l == 0.0:
				l = 1.0
			var o := rng.randf_range(-off, off)
			nxt.append((A + B) * 0.5 + Vector2(-(B.y - A.y) / l, (B.x - A.x) / l) * o)
			nxt.append(B)
		pts = nxt
		off *= 0.52
	out.append({"pts": pts, "w": w})
	if depth < 2:
		var n := pts.size()
		for i in range(2, n - 3):
			if rng.randf() < fk / (1.0 + depth) / maxf(4.0, n / 6.0):
				var A := pts[i]
				var B := pts[mini(n - 1, i + 3)]
				var sg := 1.0 if rng.randf() < 0.5 else -1.0
				var an := (B - A).angle() + sg * rng.randf_range(0.35, 0.9)
				var l := (L - (i / float(n)) * L) * rng.randf_range(0.25, 0.55)
				_zigzag(rng, A, A + Vector2(cos(an), sin(an)) * l, j * 1.1, fk, w * 0.55, depth + 1, out)


func _bowed(rng: RandomNumberGenerator, a: Vector2, b: Vector2, bw: float, j: float, fk: float) -> void:
	var L := maxf(1.0, a.distance_to(b))
	var nrm := Vector2(-(b.y - a.y) / L, (b.x - a.x) / L)
	var m := (a + b) * 0.5 + nrm * bw + Vector2(rng.randf_range(-2.0, 2.0), 0.0)
	var pa: Array = []
	var pb: Array = []
	_zigzag(rng, a, m, j, fk, 1.0, 0, pa)
	_zigzag(rng, m, b, j, fk, 1.0, 0, pb)
	var trunk: PackedVector2Array = pa[0].pts.duplicate()
	var second: PackedVector2Array = pb[0].pts
	for i in range(1, second.size()):
		trunk.append(second[i])
	_paths.append({"pts": trunk, "w": 1.0})
	_paths.append_array(pa.slice(1))
	_paths.append_array(pb.slice(1))


# ------------------------------------------------------------------ ink

var _grid := {}


func _mark(x: float, y: float, lvl: int) -> void:
	var p := Vector2i(floori(x), floori(y))
	if _grid.get(p, 0) < lvl:
		_grid[p] = lvl


func _stamp(x: float, y: float, r: float, lvl: int) -> void:
	if r <= 0.5:
		_mark(roundf(x), roundf(y), lvl)
		return
	var r2 := r * r
	for py in range(floori(y - r), ceili(y + r) + 1):
		var dy := py + 0.5 - y
		for px in range(floori(x - r), ceili(x + r) + 1):
			var dx := px + 0.5 - x
			if dx * dx + dy * dy <= r2:
				_mark(px, py, lvl)


func _walk(pts: PackedVector2Array, fn: Callable) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var l := maxf(1.0, a.distance_to(b))
		var d := 0.0
		while d <= l:
			var p := a + (b - a) * (d / l)
			fn.call(p.x, p.y)
			d += 0.5


func _trunk_pts(q: Dictionary) -> PackedVector2Array:
	var pts: PackedVector2Array = q.pts
	if up_to < 1.0 and q.w >= 1.0:
		return pts.slice(0, maxi(2, ceili(pts.size() * up_to)))
	return pts


func _c(i: int) -> Color:
	if colors.size() < 8:
		return Color.WHITE
	return colors[i]


func _draw() -> void:
	if not _built or k <= 0.02 or alpha <= 0.0:
		return
	_grid.clear()
	var cols: Array
	var alphas: Array = [alpha, alpha, alpha, alpha, alpha, alpha]
	if style == 2:
		var pts: PackedVector2Array = _trunk_pts(_paths[0])
		var n := pts.size()
		pts = pts.slice(clampi(floori(start_at * n), 0, n - 1))
		for i in pts.size() - 1:
			_line(pts[i], pts[i + 1], 1)
		cols = [trace_color, trace_color, trace_color, trace_color]
	elif style == 3:
		cols = [_c(2), _c(3), _c(4), _c(5), _c(6), Color.WHITE]
		for q in _paths:
			var tk: bool = q.w >= 1.0
			var pts: PackedVector2Array = q.pts
			for i in pts.size() - 1:
				var a := pts[i]
				var b := pts[i + 1]
				if b.y > y_reach:
					if a.y <= y_reach and i > 0:
						_grid[Vector2i(floori(a.x), floori(a.y))] = 6
					break
				var young := b.y > y_prev
				_line(a, b, ((5 if tk else 4) if fresh > 0.4 else 3) if young else (2 if tk else 1))
	elif style == 4:
		cols = [_c(2), _c(3), _c(4), _c(5)]
		var pts: PackedVector2Array = _paths[0].pts
		for i in pts.size() - 1:
			var gone := _gone(i, pts[i].y)
			if crumble >= gone:
				continue
			var h := 1.0 - clampf((crumble - 0.23) / (gone - 0.23), 0.0, 1.0)
			_line(pts[i], pts[i + 1], 4 if h > 0.7 else (3 if h > 0.4 else (2 if h > 0.15 else 1)))
	elif style == 1:
		for q in _paths:
			if up_to < 1.0 and q.w < 1.0:
				continue
			var thick_q: bool = q.w >= 1.0
			var thin_body: bool = thick_q or q.w > 0.4
			var kk := k
			_walk(_trunk_pts(q), func(x, y):
				if kk > 0.45 and thick_q:
					for d in CROSS:
						_mark(x + d.x * 1.5, y + d.y * 1.5, 1)
				if kk > 0.25 and thin_body:
					_mark(x + 1, y, 2)
					_mark(x, y + 1, 2)
				_mark(x, y, 4 if (thick_q and kk > 0.3) else 3))
		cols = [_c(3), _c(5), _c(5), _c(7)]
		alphas[0] = minf(1.0, (k - 0.45) * 1.6) * alpha
	else:
		for q in _paths:
			var trunk: bool = q.w >= 1.0
			if not trunk and (k < 0.5 or up_to < 1.0):
				continue
			var rh := (((2.1 if k > 0.6 else 1.6) if trunk else 1.1)) * thick
			var rb := (((1.3 if k > 0.6 else 0.8) if trunk else 0.5)) * thick
			var lv := 3 if trunk else 2
			var kk := k
			var cr := core
			_walk(_trunk_pts(q), func(x, y):
				_stamp(x, y, rh, 1)
				_stamp(x, y, rb, lv)
				if trunk and kk > 0.3:
					if cr > 0.0:
						_stamp(x, y, cr, 4)
					else:
						_mark(x, y, 4))
		cols = [_c(3), _c(6), _c(7), _c(7)] if hero else [_c(2), _c(4), _c(5), _c(7)]
	if head > 0.0 and up_to < 1.0 and _paths.size():
		var tip := _tip()
		var r2 := head * head
		for py in range(floori(tip.y - head), ceili(tip.y + head) + 1):
			for px in range(floori(tip.x - head), ceili(tip.x + head) + 1):
				if Vector2(px + 0.5, py + 0.5).distance_squared_to(tip) <= r2:
					_grid[Vector2i(px, py)] = 5
		cols.append(Color.WHITE)
		alphas.append(alpha)
	for p in _grid:
		var v: int = _grid[p]
		var a: float = alphas[v - 1]
		if a <= 0.0:
			continue
		var c: Color = cols[v - 1]
		draw_rect(Rect2(Vector2(p), Vector2.ONE), Color(c.r, c.g, c.b, minf(1.0, a)))
	_grid.clear()


## When segment i of a crumbling channel goes (s after the last stroke): sooner higher up, each at its own moment.
func _gone(i: int, y: float) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector2i(bolt_seed, i))
	return 0.25 + 0.75 * (0.55 * r.randf() + 0.45 * (1.0 - y / drift_top))


## A 1 px line in whole pixels, as the original's p.line, at level lvl (later lines win).
func _line(a: Vector2, b: Vector2, lvl: int) -> void:
	var p := Vector2i(floori(a.x), floori(a.y))
	var e := Vector2i(floori(b.x), floori(b.y))
	var dx := absi(e.x - p.x)
	var dy := -absi(e.y - p.y)
	var sx := 1 if p.x < e.x else -1
	var sy := 1 if p.y < e.y else -1
	var err := dx + dy
	while true:
		_grid[p] = lvl
		if p == e:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy


func _tip() -> Vector2:
	var tp: PackedVector2Array = _paths[0].pts
	return tp[mini(tp.size() - 1, floori(up_to * (tp.size() - 1)))]


func _draw_light() -> void:
	if not _built or alpha <= 0.0 or style == 2:
		return
	if head > 0.0 and up_to < 1.0 and _paths.size() and head_light > 0.0:
		var hr := head_reach
		_light.draw_texture_rect(glow_texture(), Rect2(_tip() - Vector2(hr, hr), Vector2(hr, hr) * 2.0), false, Color(_c(5), head_light * alpha))
	if k <= 0.02 or light <= 0.0 or style >= 3:
		return
	var lc := light_color if light_color.a > 0.0 else _c(4)
	for q in _paths:
		var trunk: bool = q.w >= 1.0
		if up_to < 1.0 and not trunk:
			continue
		if style == 0 and not trunk and k < 0.5:
			continue
		var pts := _trunk_pts(q)
		var r: float
		if style == 1:
			r = (9.0 if trunk else 5.0) * (0.5 + k * 0.5)
		else:
			r = (14.0 if trunk else 7.0) * thick
		r *= light_reach
		var a: float = light * k * q.w * alpha
		var i := 0
		while i < pts.size() - 1:
			_light.draw_texture_rect(glow_texture(), Rect2(pts[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(lc.r, lc.g, lc.b, a))
			i += 3


## A soft round light, (1 - d)^2 from the middle out, as the original's glow falls off.
static func glow_texture() -> ImageTexture:
	if _glow_tex == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				var f := maxf(0.0, 1.0 - d)
				img.set_pixel(x, y, Color(1, 1, 1, f * f))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex
