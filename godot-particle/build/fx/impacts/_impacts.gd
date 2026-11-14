# Shared by the impacts build scripts (not an effect). The originals (src/fx/impacts/*.js) roll everything once from a
# seeded generator, so this replays their draws bit for bit (JsRng: mulberry32, math.js) and hands them to Godot:
#   - particles: spawn() / add_bit() collect the original's Particles.spawn and Bits.add calls; flush() turns each kind
#     into a GPUParticles2D moved by the original's own physics (fx/impacts/_sim.gdshader: drag proportional to speed,
#     floors that sparks skip off and grit ticks on, rocks that bounce and rest) and drawn as the original draws the
#     kind (_bits.gdshader, with a light twin, _bits_light.gdshader, for the glow round sparks, motes and glints).
#   - shapes: the hit star (_star.gdshader), a ring breaking into arcs (_bring.gdshader), light along a segment
#     (_glowline.gdshader), keyed on the original's frames (keyf samples its formulas, 60 a second by default).
#   - lights: the original's Lights.add (a glow that shrinks a little and dies) and p.glow keyed from its formula.
extends "res://addons/pixelfx_particles/core/build.gd"

const DIR := "res://addons/pixelfx_particles/fx/impacts/"
const SPARK := 0
const MOTE := 1
const FLAKE := 3
const DUST := 5
const STAR := 6
const SMOKE := 8
const GRIT := 11
const CHUNK := 20
const SHARD := 21
const PUFF := 30
const BIG := 2
const SOOT := Color8(0x0d, 0x0a, 0x12)
const OUTLINE := Color8(0x1a, 0x14, 0x22)
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const DT := 1.0 / 120.0

var C: PackedColorArray
var R: JsRng
## spawns by group key ("kind/big/back") -> Array of dictionaries
var _spawns := {}
var _bits := []
var _flushed := 0


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.palette


func sh(name: String) -> Shader:
	return load(DIR + "_" + name + ".gdshader")


# ------------------------------------------------------------------ the original's randomness and colours

## The original's seeded generator (mulberry32, src/core/math.js Rng), bit for bit.
class JsRng:
	var s := 1

	func _init(seed_: int = 1) -> void:
		s = seed_ & 0xffffffff
		if s == 0:
			s = 1

	static func _mul(a: int, b: int) -> int:
		a &= 0xffffffff
		b &= 0xffffffff
		return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = _mul(t ^ (t >> 15), t | 1)
		t = t ^ ((t + _mul(t ^ (t >> 7), t | 61)) & 0xffffffff)
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	func int_(a: int, b: int) -> int:
		return int(floor(self.range(a, b + 1)))

	func chance(p: float) -> bool:
		return next() < p

	func sign() -> float:
		return -1.0 if next() < 0.5 else 1.0

	func pick(list: Array) -> Variant:
		return list[int(floor(next() * list.size()))]


## math.js hash / rand(...ns) in [0, 1)
static func rand(ns: Array) -> float:
	var h := 0x9e3779b9
	for n in ns:
		h = JsRng._mul(h ^ (int(n) & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = JsRng._mul(h, 0xc2b2ae35)
		h ^= h >> 16
	return (h & 0xffffffff) / 4294967296.0


static func _b(v: float) -> int:
	return int(v) & 255


## color.js mix(): truncated like the original's rgb()
static func mixc(a: Color, b: Color, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var ar := a.r8
	var ag := a.g8
	var ab := a.b8
	return Color8(_b(ar + (b.r8 - ar) * t), _b(ag + (b.g8 - ag) * t), _b(ab + (b.b8 - ab) * t))


## color.js scale()
static func scalec(c: Color, k: float) -> Color:
	return Color8(_b(minf(255, c.r8 * k)), _b(minf(255, c.g8 * k)), _b(minf(255, c.b8 * k)))


## _lib.js stone(): light, body, shade, dust, lip
static func stone(c: Color) -> Dictionary:
	return {"light": mixc(scalec(c, 1.35), Color.WHITE, 0.08), "body": c, "shade": scalec(c, 0.64),
		"dust": mixc(scalec(c, 1.2), Color8(150, 140, 150), 0.3), "lip": mixc(scalec(c, 1.55), Color.WHITE, 0.12)}


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_quad(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.0)


static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := seg(x, a, b)
	return u * u * (3.0 - 2.0 * u)


## _lib.js spikes(): n spikes round the circle, longer towards aim. Each: Vector4(a, len, w, 0).
func spikes(n: int, aim: float, o: Dictionary = {}) -> Array:
	var ln: Array = o.get("len", [7.0, 10.0])
	var w: Array = o.get("w", [1.5, 2.1])
	var fwd: float = o.get("fwd", 1.8)
	var back: float = o.get("back", 0.6)
	var jag: float = o.get("jag", 1.0)
	var jit: float = o.get("jit", 0.18)
	var out := []
	for i in n:
		var a := aim + (i / float(n)) * TAU + R.range(-jit, jit)
		var cb := cos(a - aim)
		var L := R.range(ln[0], ln[1]) * (1.0 + fwd * pow(maxf(0.0, cb), 3.0) + back * pow(maxf(0.0, -cb), 3.0)) * (jag if i % 2 else 1.0)
		var ww := R.range(w[0], w[1]) * (sqrt(jag) if i % 2 else 1.0)
		out.append(Vector4(a, L, ww, 0.0))
	return out


# ------------------------------------------------------------------ time

## Steps ("nearest" keys) are the original's beats, `if (t < 0.058)`: what matters is which of its frames (30 a second)
## show which look. A stepped key is moved to the middle of the frame interval before the first frame that shows it,
## so the step never rides on a frame's own time (where a few ms of clock decide it) and every frame shows what the
## original's does.
func key(node: Node, prop: String, keys: Array, interp := "linear") -> void:
	if interp == "nearest":
		var snapped := []
		for k in keys:
			var t := float(k[0])
			if t > 0.0:
				t = (ceilf(t * 30.0 - 1e-4) - 0.5) / 30.0 + 0.001
			if snapped.size() and absf(snapped[-1][0] - t) < 1e-6:
				snapped[-1] = [t, k[1]]
			else:
				snapped.append([t, k[1]])
		keys = snapped
	super(node, prop, keys, interp)


## Key node.prop from f(t) sampled `hz` times a second over [t0, t1] (t1 < 0: the whole effect).
func keyf(node: Node, prop: String, f: Callable, t0 := 0.0, t1 := -1.0, hz := 60.0, interp := "linear") -> void:
	var end: float = root.duration if t1 < 0.0 else t1
	var keys := []
	var n := int(ceilf((end - t0) * hz - 1e-6))
	for i in n + 1:
		var t := minf(t0 + i / hz, end)
		keys.append([t, f.call(t)])
	key(node, prop, keys, interp)


## Steps: node.prop takes each [t, v] from t on (the original's "if t < ..." beats).
func steps(node: Node, prop: String, keys: Array) -> void:
	key(node, prop, keys, "nearest")


# ------------------------------------------------------------------ light

## The original's p.glow(x, y, r, c, k(t)) keyed from k(t) (and r(t) if given): a soft additive disc.
func glow_fn(name: String, at: Vector2, r: float, c: Color, kf: Callable, t0 := 0.0, t1 := -1.0, rf: Variant = null, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at}
	oo.merge(o, true)
	var g := glow(name, r + 1, {"radius": r, "color": c, "alpha": 0.0}, oo)
	keyf(g, "material:shader_parameter/alpha", kf, t0, t1)
	if rf != null:
		keyf(g, "material:shader_parameter/radius", rf, t0, t1)
	return g


## The original's Lights.add(x, y, r, c, k, life) from t0: a glow shrinking to 55% and dying as (life left)^2.
func light_add(name: String, at: Vector2, r: float, c: Color, k: float, life: float, t0 := 0.0) -> ColorRect:
	return glow_fn(name, at, r, c, func(t: float) -> float: return 0.0 if t < t0 or t >= t0 + life else k * pow(1.0 - (t - t0) / life, 2.0),
		0.0, minf(root.duration, t0 + life + 0.02), func(t: float) -> float: return r * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))))


## The original's p.glowLine(a, b, r, c, k(t)): light round a segment.
func glow_line(name: String, a: Vector2, b: Vector2, r: float, c: Color, kf: Callable, t0 := 0.0, t1 := -1.0, o: Dictionary = {}) -> ColorRect:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r + 1, r + 1)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r + 1, r + 1)
	lo = lo.floor()
	hi = hi.ceil()
	var oo := {"at": (lo + hi) / 2.0}
	oo.merge(o, true)
	var g := shape(name, sh("glowline"), hi - lo, {"a": a, "b": b, "radius": r, "color": c, "k": 0.0}, oo)
	keyf(g, "material:shader_parameter/k", kf, t0, t1)
	return g


## A glowline over a fixed box (lo..hi, radius r) whose ends the caller keys ("material:shader_parameter/a", "/b", "/k").
func glow_path(name: String, lo: Vector2, hi: Vector2, r: float, c: Color, o: Dictionary = {}) -> ColorRect:
	var a := (Vector2(minf(lo.x, hi.x), minf(lo.y, hi.y)) - Vector2(r + 1, r + 1)).floor()
	var b := (Vector2(maxf(lo.x, hi.x), maxf(lo.y, hi.y)) + Vector2(r + 1, r + 1)).ceil()
	var oo := {"at": (a + b) / 2.0}
	oo.merge(o, true)
	return shape(name, sh("glowline"), b - a, {"a": lo, "b": hi, "radius": r, "color": c, "k": 0.0}, oo)


## The original's p.glowRing(x, y, R(t), r, c, k(t)): light hugging a circle.
func glow_ring(name: String, at: Vector2, reach: float, r: float, c: Color, rad: Callable, kf: Callable, t0 := 0.0, t1 := -1.0) -> ColorRect:
	var g := glow(name, reach + r + 1, {"radius": 1.0, "thickness": r, "color": c, "alpha": 0.0}, {"at": at})
	keyf(g, "material:shader_parameter/radius", rad, t0, t1)
	keyf(g, "material:shader_parameter/alpha", kf, t0, t1)
	return g


# ------------------------------------------------------------------ shapes

## The hit star (_lib.js star()) at `at` with these spikes. frames: [[from t, sc, th, alpha, [rim, body, inner, core]],
## ..., [end t]]: it shows each look from its t to the next, then is gone.
func hit_star(name: String, at: Vector2, sp: Array, heart: float, frames: Array, o: Dictionary = {}) -> ColorRect:
	var reach := 4.0
	var top := 0.0
	for f in frames:
		if f.size() > 1:
			top = maxf(top, float(f[1]))
	for s in sp:
		reach = maxf(reach, s.y * top + s.z + 2.0)
	var e := ceilf(reach + 2.0) * 2.0
	var arr := []
	for i in 16:
		arr.append(sp[i] if i < sp.size() else Vector4.ZERO)
	var f0: Array = frames[0]
	var oo := {"at": at}
	oo.merge(o, true)
	var n := shape(name, sh("star"), Vector2(e, e), {"spikes": PackedVector4Array(arr), "count": float(sp.size()), "heart": heart,
		"sc": f0[1], "th": f0[2], "alpha": f0[3], "rim": f0[4][0], "body": f0[4][1], "inner": f0[4][2], "core": f0[4][3]}, oo)
	for f in frames:
		if f.size() > 1:
			for c in f[4]:
				keep_colour(c)
	var u := "material:shader_parameter/"
	for p in [["sc", 1], ["th", 2], ["alpha", 3]]:
		var ks := []
		for f in frames:
			if f.size() > 1:
				ks.append([f[0], f[p[1]]])
		steps(n, u + p[0], ks)
	var names := ["rim", "body", "inner", "core"]
	for j in 4:
		var ks := []
		for f in frames:
			if f.size() > 1:
				ks.append([f[0], f[4][j]])
		steps(n, u + names[j], ks)
	show(n, frames[0][0], frames[-1][0])
	return n


## A ring that breaks into arcs (_lib.js brokenRing()) at `at`; segs: Vector4(a, gap, dr, w). Key its uniforms:
## radius, th, brk, color, color2, alpha (squash, max_y fixed).
func broken_ring(name: String, at: Vector2, segs: Array, reach: float, params: Dictionary = {}) -> ColorRect:
	var arr := []
	for i in 8:
		arr.append(segs[i] if i < segs.size() else Vector4.ZERO)
	var sq: float = params.get("squash", 1.0)
	var pr := {"segs": PackedVector4Array(arr), "seg_count": float(segs.size())}
	pr.merge(params, true)
	return shape(name, sh("bring"), Vector2(ceilf(reach + 3) * 2, ceilf(reach * sq + 3) * 2), pr, {"at": at})


## A thin ring of dots on the side where cos(angle - dir) > open (fx/impacts/_dotring.gdshader). Key radius, color,
## alpha.
func dot_ring(name: String, at: Vector2, reach: float, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var sq: float = params.get("squash", 1.0)
	var oo := {"at": at}
	oo.merge(o, true)
	return shape(name, sh("dotring"), Vector2(ceilf(reach + 2) * 2, ceilf(reach * sq + 2) * 2), params, oo)


## painter.js line(): the cells a 1 px line from a to b steps through (Bresenham on whole cells).
static func line_cells(a: Vector2, b: Vector2) -> Array:
	var sx := int(floor(a.x))
	var sy := int(floor(a.y))
	var ex := int(floor(b.x))
	var ey := int(floor(b.y))
	var dx := absi(ex - sx)
	var dy := -absi(ey - sy)
	var stx := 1 if sx < ex else -1
	var sty := 1 if sy < ey else -1
	var err := dx + dy
	var out := []
	while true:
		out.append(Vector2i(sx, sy))
		if sx == ex and sy == ey:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			sx += stx
		if e2 <= dx:
			err += dx
			sy += sty
	return out


## Whole cells (Vector2i, the effect's coordinates) in one colour: a Sprite2D of white pixels tinted by its modulate
## (key "modulate" for its colour and fade; colours keyed must be kept with keep_colour). o: layer, back.
func cells(name: String, list: Array, col: Color, o: Dictionary = {}) -> Sprite2D:
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-100000, -100000)
	for c in list:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var img := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	for c in list:
		img.set_pixel(c.x - lo.x, c.y - lo.y, Color.WHITE)
	var oo := {"centered": false, "at": Vector2(lo), "modulate": col}
	oo.merge(o, true)
	keep_colour(col)
	return sprite(name, asset("_" + name.to_snake_case(), img), oo)


## The originals' p.dot(x, y, c, a) calls baked into a sprite (colour layer): dots [[Vector2, Color, alpha], ...] in the
## effect's coordinates land on whole cells, the last on a cell wins; the colour layer dithers their alpha as the
## original's dot() does.
func dots(name: String, list: Array, o: Dictionary = {}) -> Sprite2D:
	var cellmap := {}
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-100000, -100000)
	for d in list:
		var c := Vector2i(floori(d[0].x), floori(d[0].y))
		if float(d[2]) <= 0.0:
			continue
		cellmap[c] = Color(d[1], clampf(d[2], 0.0, 1.0))
		keep_colour(d[1])
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	if cellmap.is_empty():
		lo = Vector2i.ZERO
		hi = Vector2i.ZERO
	var img := Image.create(hi.x - lo.x + 1, hi.y - lo.y + 1, false, Image.FORMAT_RGBA8)
	for c in cellmap:
		img.set_pixel(c.x - lo.x, c.y - lo.y, cellmap[c])
	var oo := {"centered": false, "at": Vector2(lo)}
	oo.merge(o, true)
	return sprite(name, asset("_" + name.to_snake_case(), img), oo)


# _lib.js walk(): a jagged walk from (x, y) heading a for L px; points Vector3(x, y, distance along)
func _walk(x: float, y: float, a: float, L: float, jit := 0.55, st0 := 2.0, st1 := 4.0, max_y := 1e9, d0 := 0.0) -> Array:
	var pts := [Vector3(x, y, d0)]
	var d := 0.0
	var cur := a
	while d < L - 0.01:
		var s := minf(L - d, R.range(st0, st1))
		cur += R.range(-jit, jit) + (a - cur) * 0.45
		x += cos(cur) * s
		y = clampf(y + sin(cur) * s, 0.5, max_y)
		d += s
		pts.append(Vector3(x, y, d0 + d))
	return pts


## _lib.js makeCracks(): n jagged cracks in the floor face below (0, 0). Each {pts, len, t0, kids}.
func make_cracks(n: int, o: Dictionary = {}) -> Array:
	var ln: Array = o.get("len", [14.0, 40.0])
	var dive: float = o.get("dive", 0.85)
	var max_y: float = o.get("maxY", 22.0)
	var forks: float = o.get("forks", 0.5)
	var x0: Array = o.get("x0", [1.0, 5.0])
	var out := []
	for i in n:
		var side := 1.0 if i % 2 else -1.0
		var dip := 0.06 + pow(R.next(), 1.7) * dive
		var L := R.range(ln[0], ln[1]) * (1.0 - (0.5 * dip) / (dive + 0.06))
		var a := dip if side > 0 else PI - dip
		var sx := side * R.range(x0[0], x0[1])
		var sy := R.range(0.5, 1.5)
		var pts := _walk(sx, sy, a, L, 0.55, 2.0, 4.0, max_y)
		var c := {"pts": pts, "len": L, "t0": R.range(0, 0.035), "kids": []}
		for j in range(2, pts.size() - 1):
			if R.chance(forks * 0.4):
				var f: Vector3 = pts[j]
				var ka := a + R.sign() * R.range(0.45, 1)
				var kl := R.range(3, 9) * (1.0 - (0.5 * j) / pts.size())
				c.kids.append(_walk(f.x, f.y, ka, kl, 0.7, 1.5, 3.0, max_y, f.z))
		out.append(c)
	return out


## The cracks as a node (fx/impacts/_cracks.gdshader over a map baked from the original's lines): key its t (the
## effect's time), heat and fade. params: grow, hot0..hot3, dark, lip. Returns [node, segments] (segments: Vector4(x,
## y, d0, 0) at each stretch's middle, for the light along the hot parts).
func cracks_node(name: String, cracks: Array, params: Dictionary, o: Dictionary = {}) -> Array:
	var cellmap := {}
	var segs := []
	var info := []
	var ci := 0
	for c in cracks:
		info.append(Vector4(c.t0, c.len, 0, 0))
		for path in [c.pts] + c.kids:
			for i in range(1, path.size()):
				var a: Vector3 = path[i - 1]
				var b: Vector3 = path[i]
				segs.append(Vector4((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, a.z, 0.0))
				var lc := line_cells(Vector2(a.x, a.y + 1), Vector2(b.x, b.y + 1))
				for j in lc.size():
					var u := j / float(maxi(1, lc.size() - 1))
					if rand([floori(a.x + (b.x - a.x) * u + 0.5), floori(a.y + (b.y - a.y) * u + 0.5), 5]) < 0.3:
						cellmap[lc[j]] = Color(a.z + (b.z - a.z) * u, ci, 2.0, 1.0)
				var mc := line_cells(Vector2(a.x, a.y), Vector2(b.x, b.y))
				for j in mc.size():
					var u := j / float(maxi(1, mc.size() - 1))
					cellmap[mc[j]] = Color(a.z + (b.z - a.z) * u, ci, 1.0, 1.0)
		ci += 1
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-100000, -100000)
	for c in cellmap:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var sz := hi - lo + Vector2i.ONE
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBAF)
	for c in cellmap:
		img.set_pixel(c.x - lo.x, c.y - lo.y, cellmap[c])
	while info.size() < 16:
		info.append(Vector4.ZERO)
	var pr := {"map": asset("_" + name.to_snake_case(), img), "crack": PackedVector4Array(info), "t": 0.0, "heat": 0.0, "fade": 1.0}
	pr.merge(params, true)
	var oo := {"at": Vector2(lo) + Vector2(sz) / 2.0}
	oo.merge(o, true)
	var n := shape(name, sh("cracks"), Vector2(sz), pr, oo)
	return [n, segs]


## Many small glows (fx/impacts/_points_light.gdshader) over the box lo..hi: pts Vector4 (at most 200).
func points_light(name: String, pts: Array, lo: Vector2, hi: Vector2, params: Dictionary) -> ColorRect:
	var arr := []
	for i in 200:
		arr.append(pts[i] if i < pts.size() else Vector4.ZERO)
	var pr := {"pts": PackedVector4Array(arr), "count": float(mini(200, pts.size()))}
	pr.merge(params, true)
	return shape(name, sh("points_light"), (hi - lo).ceil(), pr, {"at": (lo + hi) / 2.0})


## Key a shader's `t` uniform to the effect's own time over [t0, t1].
func clock(node: CanvasItem, t0 := 0.0, t1 := -1.0) -> void:
	var e: float = root.duration if t1 < 0.0 else t1
	key(node, "material:shader_parameter/t", [[t0, t0], [e, e]])


# ------------------------------------------------------------------ particles

## The original's Particles.spawn(k, x, y, vx, vy, life, col, size, delay, flag): consumes R for the particle's seed
## as the original does. `at`: when the original spawned it (it appears then, after its delay).
func spawn(k: int, x: float, y: float, vx: float, vy: float, life: float, col: Color = Color.WHITE, size := 1.0, delay := 0.0, flag := 0, at := 0.0, layer := "") -> void:
	var sd := R.next() * 100.0
	var back := layer if layer != "" else ("back" if k in [DUST, SMOKE] else "front")
	var g := "%d/%d/%s" % [k, 1 if (k == SMOKE and flag & BIG) else 0, back]
	if not _spawns.has(g):
		_spawns[g] = []
	_spawns[g].append({"x": x, "y": y, "vx": vx, "vy": vy, "life": life, "col": col, "size": size, "delay": delay + at, "seed": sd})


## An effect's own soft puff (blunt-hit's dust): radius r, slowed by drag, lifted by lift px/s/s, appearing at t0, a
## disc thinning to its rim with a lit cap; tinted toward `warm` early on (flush's "warm": {k, t0, len}). No R draws.
func puff(x: float, y: float, vx: float, vy: float, r: float, life: float, t0: float, drag: float, lift: float, col: Color, warm: Color, layer := "back") -> void:
	var g := "%d/0/%s" % [PUFF, layer]
	if not _spawns.has(g):
		_spawns[g] = []
	_spawns[g].append({"x": x, "y": y, "vx": vx, "vy": vy, "life": life, "col": col, "size": r, "delay": t0, "a": drag, "va": lift, "warm": warm})


## The original's Bits.add({kind, x, y, vx, vy, a, va, s, c, life, pts}).
func add_bit(b: Dictionary) -> void:
	_bits.append(b)


## Replays the original's Bits (no randomness in their motion) at its 120 Hz: calls on_land(bit, t, pvy) whenever a
## bit hits the floor falling faster than `fast` (the originals kick dust there). g, drag, bounce from each bit.
func replay_bits(on_land: Callable, fast := 60.0, floor_y := 0.0) -> void:
	var st := []
	for b in _bits:
		st.append({"x": b.x, "y": b.y, "vx": b.vx, "vy": b.vy, "life": b.life, "rest": false, "b": b})
	var t := 0.0
	while t < root.duration:
		t += DT
		for s in st:
			var b: Dictionary = s.b
			var pvy: float = s.vy
			s.life -= DT
			if s.life <= 0.0 or s.rest:
				continue
			s.vy += 950.0 * b.get("g", 1.0) * DT
			s.vx -= s.vx * b.get("drag", 0.0) * DT
			s.vy -= s.vy * b.get("drag", 0.0) * DT
			s.x += s.vx * DT
			s.y += s.vy * DT
			var sp: float = s.vy
			if s.y < floor_y or sp <= 0.0:
				continue
			s.y = floor_y - 0.01
			if b.get("bounce", 0.0) > 0.0 and sp > 70.0:
				s.vy = -sp * b.bounce
				s.vx *= 0.7
			else:
				s.rest = true
				s.vx = 0.0
				s.vy = 0.0
			if pvy > fast and s.vy <= 0.0:
				on_land.call(s, t, pvy)


## Every spawn and bit collected so far becomes emitters (one a kind, plus a light twin for sparks, motes and glints).
## o: sparks [head .. tail] (the Particles' spark colours), stone (stone() for rocks), prefix, z (a dictionary of
## "back"/"front" -> override), quad.
func flush(o: Dictionary = {}) -> Array:
	var out := []
	var pre: String = o.get("prefix", "")
	var names := {SPARK: "Sparks", MOTE: "Motes", FLAKE: "Flakes", DUST: "Dust", STAR: "Glints", SMOKE: "Smoke", GRIT: "Grit", PUFF: "Puffs"}
	var keys := _spawns.keys()
	keys.sort()
	var only: Array = o.get("only", [])
	var left := {}
	for g in keys:
		var parts: PackedStringArray = g.split("/")
		var k := int(parts[0])
		if only.size() and not k in only:
			left[g] = _spawns[g]
			continue
		var nm: String = pre + names.get(k, "P%d" % k) + ("Big" if parts[1] == "1" else "") + ("Back" if parts[2] == "back" and not k in [DUST, SMOKE, PUFF] else "") + ("Front" if parts[2] == "front" and k in [DUST, SMOKE, PUFF] else "")
		out.append(_emitter(nm, k, _spawns[g], o, parts[1] == "1", parts[2] == "back"))
	if _bits.size() and (only.is_empty() or CHUNK in only or SHARD in only):
		var kinds := {}
		for b in _bits:
			var kk: int = b.get("kind", CHUNK)
			if not kinds.has(kk):
				kinds[kk] = []
			kinds[kk].append(b)
		for kk in kinds:
			out.append(_emitter(pre + ("Rocks" if kk == CHUNK else "Shards"), kk, kinds[kk], o, false, bool(o.get("bits_back", false))))
		_bits.clear()
	_spawns = left
	return out


func _quad(n: int) -> Texture2D:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return asset("_quad%d" % n, img)


func _emitter(name: String, k: int, list: Array, o: Dictionary, big: bool, back: bool) -> GPUParticles2D:
	var n := list.size()
	var rows := 6
	var img := Image.create(n, rows, false, Image.FORMAT_RGBAF)
	var top := 0.0
	var reach := 4.0
	for i in n:
		var q: Dictionary = list[i]
		var life: float = q.life
		img.set_pixel(i, 0, Color(q.x, q.y, q.vx, q.vy))
		img.set_pixel(i, 1, Color(life, q.get("delay", 0.0), q.get("size", 1.0), q.get("seed", 0.0)))
		var c: Color = q.get("col", q.get("c", Color.WHITE))
		img.set_pixel(i, 2, Color(c.r, c.g, c.b, 1.0))
		var pts: Array = q.get("pts", [])
		img.set_pixel(i, 3, Color(q.get("a", 0.0), q.get("va", 0.0), q.get("s", 1.0), float(pts.size())))
		var pp := []
		for j in 8:
			pp.append(pts[j] if j < pts.size() else 0.0)
		if q.has("warm"):
			img.set_pixel(i, 4, q.warm)
		else:
			img.set_pixel(i, 4, Color(pp[0], pp[1], pp[2], pp[3]))
		img.set_pixel(i, 5, Color(pp[4], pp[5], pp[6], pp[7]))
		top = maxf(top, q.get("delay", 0.0) + life)
		var sz: float = q.get("size", 1.0)
		match k:
			SPARK:
				reach = 13.0
			MOTE:
				reach = maxf(reach, 16.0 * sz + 4.0 + sz)
				keep_colour(c)
				keep_colour(Color(c.r * 0.55, c.g * 0.55, c.b * 0.55))
			GRIT:
				reach = 3.0
				keep_colour(c)
				keep_colour(Color(c.r * 0.8, c.g * 0.8, c.b * 0.8))
				keep_colour(Color(c.r * 0.7, c.g * 0.7, c.b * 0.7))
			FLAKE:
				reach = 3.0
				keep_colour(c)
				keep_colour(Color(c.r * 0.8, c.g * 0.8, c.b * 0.8))
			STAR:
				reach = maxf(reach, 4.0 + 2.0 * ceilf(sz) + 2.0)
				keep_colour(c)
				keep_colour(Color(c.r * 0.75, c.g * 0.75, c.b * 0.75))
			DUST:
				reach = maxf(reach, sz * 1.5 + 2.0)
				keep_colour(c)
			SMOKE:
				reach = maxf(reach, sz * (1.1 + (0.5 if big else 0.4)) + 3.0)
				keep_colour(c)
			PUFF:
				reach = maxf(reach, sz * 1.55 + 2.0)
				var wk: Dictionary = o.get("warm", {"k": 0.0})
				for j in 6:
					var mc := c.lerp(q.warm, wk.k * j / 5.0)
					keep_colour(mc)
					keep_colour(mc.lerp(Color.WHITE, 0.55))
			CHUNK:
				reach = maxf(reach, (0.75 + float(q.get("s", 1.0)) * 0.8) * 1.15 + 2.0)
			SHARD:
				reach = maxf(reach, float(q.get("s", 1.0)) / 2.0 + 2.0)
				keep_colour(c)
	var qn := int(ceilf(reach)) * 2
	var data := asset("_" + name.to_snake_case(), img)
	var tex := _quad(qn)
	var soft := k in [DUST, SMOKE, PUFF]
	var pp := {"data": data, "kind": float(k), "floor_y": float(o.get("floor", 0.0)), "big": 1.0 if big else 0.0}
	if k == PUFF:
		var wk: Dictionary = o.get("warm", {"k": 0.0})
		pp.merge({"warm_k": float(wk.get("k", 0.0)), "warm_t0": float(wk.get("t0", 0.03)), "warm_len": float(wk.get("len", 0.25))}, true)
	if k >= CHUNK:
		var b0: Dictionary = list[0]
		pp.merge({"grav": float(b0.get("g", 1.0)), "drag": float(b0.get("drag", 0.0)), "bounce": float(b0.get("bounce", 0.0))}, true)
	var po := {"amount": n, "lifetime": minf(top + 0.05, root.duration), "one_shot": true, "explosiveness": 1.0, "local": true, "texture": tex,
		"layer": "soft" if soft else "color", "back": back or bool(o.get("all_back", false)), "process_shader": sh("sim"), "process_params": pp}
	var p := particles(name, po)
	p.interpolate = false
	p.preprocess = float(o.get("preprocess", 0.0))
	var m := ShaderMaterial.new()
	m.shader = sh("bits")
	var sp: Array = o.get("sparks", [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	var params := {"data": data, "kind": float(k), "quad": Vector2(qn, qn), "big": 1.0 if big else 0.0, "translucent": soft}
	if k == SPARK:
		for j in 4:
			params["s%d" % j] = sp[j]
			keep_colour(sp[j])
	elif k == SMOKE:
		for j in 4:
			params["s%d" % j] = Color(SMOKE_RAMP[j])
			keep_colour(Color(SMOKE_RAMP[j]))
		params["smoke4"] = Color(SMOKE_RAMP[4])
		keep_colour(Color(SMOKE_RAMP[4]))
	elif k == CHUNK:
		var st: Dictionary = o.stone
		params.merge({"outline_c": OUTLINE, "light_c": st.light, "body_c": st.body, "shade_c": st.shade}, true)
		for c in [OUTLINE, st.light, st.body, st.shade]:
			keep_colour(c)
	for key_ in params:
		m.set_shader_parameter(key_, params[key_])
	m.resource_name = name
	p.material = m
	if k in [SPARK, MOTE, STAR]:
		var lo := po.duplicate()
		lo.layer = "light"
		var lp := particles(name + "Light", lo)
		lp.interpolate = false
		lp.preprocess = p.preprocess
		lp.seed = p.seed
		var lm := ShaderMaterial.new()
		lm.shader = sh("bits_light")
		var lpar := {"data": data, "kind": float(k), "quad": Vector2(qn, qn)}
		if k == SPARK:
			for j in 3:
				lpar["s%d" % j] = sp[j]
		for key_ in lpar:
			lm.set_shader_parameter(key_, lpar[key_])
		lp.material = lm
	return p
