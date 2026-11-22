# Shared by the water build scripts (not an effect: files starting with _ are helpers, as in the original's
# src/fx/water/_lib.js): the water ramp, the original's easing, keys sampled from a function of time, and the ripple
# ring (fx/water/_ring.gdshader) keyed from the original's ring() arguments.
extends "res://addons/pixelfx_particles/core/build.gd"

const FX := "res://addons/pixelfx_particles/fx/water/"

## The water ramp, deep to white (the original's fit(o.palette, 8)).
var C: PackedColorArray
## shader nodes keyed together: a ring's light twin takes its ring's keys
var _twins := {}


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.palette


func water_shader(name: String) -> Shader:
	return load(FX + "_" + name + ".gdshader")


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_quad(x: float) -> float:
	return x * x


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Keys on node.prop sampled from fn(t) every 1/hz s over [t0, t1] (t1 < 0: the whole effect).
func sample(node: Node, prop: String, fn: Callable, t0 := 0.0, t1 := -1.0, hz := 30.0, interp := "linear") -> void:
	if t1 < 0.0:
		t1 = root.duration
	var keys := []
	var n := int(roundf((t1 - t0) * hz))
	for i in n + 1:
		var t := t0 + i / hz
		keys.append([t, fn.call(t)])
	key(node, prop, keys, interp)


## Several shader uniforms of one node from one function: fn(t) -> {uniform: value}. Values that are bools key as
## 0/1 steps.
func sample_shader(node: Node, fn: Callable, t0 := 0.0, t1 := -1.0, hz := 30.0) -> void:
	if t1 < 0.0:
		t1 = root.duration
	var tracks := {}
	var n := int(roundf((t1 - t0) * hz))
	for i in n + 1:
		var t := t0 + i / hz
		var d: Dictionary = fn.call(t)
		for k in d:
			if not tracks.has(k):
				tracks[k] = []
			tracks[k].append([t, (1.0 if d[k] else 0.0) if d[k] is bool else d[k]])
	for k in tracks:
		var steps: bool = k in ["hot", "seed", "side", "n"]
		key(node, "material:shader_parameter/" + k, tracks[k], "nearest" if steps else "linear")
		if _twins.has(node):
			key(_twins[node], "material:shader_parameter/" + k, tracks[k], "nearest" if steps else "linear")


## A ripple ring (the original's ring()) centred on `at`, big enough for `reach` px of radius. params: r, k, sy, n,
## gap, side, hot, glint, seed, wob. The light its outer crest catches is a twin on the light layer (o.light: how
## much, 0 for none) that sample_shader() keys along with it.
func water_ring(name: String, reach: float, params: Dictionary = {}, o: Dictionary = {}) -> ColorRect:
	var sy: float = params.get("sy", 0.26)
	var pr := {"pal": C, "sy": sy, "r": 0.0, "k": 0.0}
	pr.merge(params, true)
	var size := Vector2(ceilf(reach + 4.0) * 2.0, ceilf(reach * sy + 4.0) * 2.0)
	var col := shape(name, water_shader("ring"), size, pr, o)
	var amount: float = o.get("light", 0.3)
	if amount > 0.0:
		var lp := pr.duplicate()
		lp.amount = amount
		_twins[col] = shape(name + "Light", water_shader("ring_light"), size, lp, o)
	return col


## A ripple from the original's Ripples.add(x, z, r0, r1, life, o) born at t0: its far half behind, its near half in
## front. o: n, gap, k, hot, glint, seed, at (its middle), sy.
func ripple(name: String, t0: float, r0: float, r1: float, life: float, o: Dictionary) -> void:
	var n: float = o.get("n", 2.0)
	var gap: float = o.get("gap", 3.0)
	var k0: float = o.get("k", 1.0)
	var hot: float = o.get("hot", 0.1)
	var glint: float = o.get("glint", 0.0)
	var sy: float = o.get("sy", 0.22)
	var reach := r1 + 2.0
	for side in [-1.0, 1.0]:
		var rg := water_ring(name + ("Far" if side < 0.0 else "Near"), reach, {"sy": sy, "n": n, "side": side,
			"seed": float(o.get("seed", 1))}, {"back": side < 0.0, "at": o.get("at", Vector2.ZERO)})
		sample_shader(rg, func(t: float) -> Dictionary:
			var a := t - t0
			if a < 0.0 or a >= life:
				return {"r": r0, "k": 0.0, "hot": false, "glint": 0.0, "gap": gap}
			var q := a / life
			var k := k0 * pow(1.0 - q, 1.7)
			return {"r": r0 + (r1 - r0) * (1.0 - pow(1.0 - q, 2.6)), "k": k, "gap": gap * (0.55 + 0.6 * q),
				"hot": a < hot, "glint": glint * k})


## A one-pixel (o.size: w x h) dot in colour c with its top-left at `at`: flecks, beads, glints keyed by position and
## visibility (a Sprite2D, so its position keys as it is).
func dot(name: String, c: Color, at: Vector2, o: Dictionary = {}) -> Sprite2D:
	var oo := {"centered": false, "modulate": c, "at": at, "scale": o.get("size", Vector2.ONE)}
	oo.merge(o, true)
	oo.erase("size")
	keep_colour(c)
	return sprite(name, "dot1", oo)


## A glint winking on water: a white pixel, plus-shaped arms in the lightest blue while it's bright, light round it
## (the original's p.px + four C[6] arms + p.glow(x, y, 5, C[5], 0.4 k)). fn(t) -> [x, y, k] (k <= 0: hidden; arms
## from `arms`), sampled every frame.
func glint(name: String, fn: Callable, arms := 0.5, reach := 5.0, bright := 0.4) -> void:
	var g := group(name)
	var plus := sprite("Arms", "plus3", {"parent": g, "modulate": C[6]})
	dot("Core", C[7], Vector2(-0.5, -0.5), {"parent": g})
	var shine := glow(name + "Light", reach, {"radius": reach, "color": C[5], "alpha": 0.0})
	var vis := []
	var av := []
	var pos := []
	var sa := []
	for f in int(roundf(root.duration * 30.0)) + 1:
		var t := f / 30.0
		var v: Array = fn.call(t)
		var k: float = v[2]
		var at := Vector2(floorf(v[0]) + 0.5, floorf(v[1]) + 0.5)
		vis.append([t, k > 0.0])
		av.append([t, k > arms])
		pos.append([t, at])
		sa.append([t, bright * k if k > 0.0 else 0.0])
	key(g, "visible", vis, "nearest")
	key(plus, "visible", av, "nearest")
	key(g, "position", pos, "nearest")
	key(shine, "position", pos, "nearest")
	key(shine, "material:shader_parameter/alpha", sa, "nearest")


## An emitter that moves exactly as `of` does (same seed, amount, timing and motion), drawn differently: a bubble's
## highlight, a bead's tail. `changes` replace keys of `o` (the options `of` was made with): texture, colour, layer,
## at (an offset; local coordinates keep the motion identical).
func twin(name: String, of: GPUParticles2D, o: Dictionary, changes: Dictionary) -> GPUParticles2D:
	var oo := o.duplicate()
	oo.merge(changes, true)
	var p := particles(name, oo)
	p.seed = of.seed
	return p


static func _imul(a: int, b: int) -> int:
	return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


## The original's rand(...ns): a deterministic number in [0, 1) from integers, so choices made once (which way an
## arc of a fountain throws) match the original's.
static func jsrand(ns: Array) -> float:
	var h := 0x9e3779b9
	for n in ns:
		h = _imul(h ^ (int(n) & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = _imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h / 4294967296.0


## The original's seeded generator (mulberry32), so choices it makes once (a crown's phase, its fingers' lengths)
## match: JsRng.new(seed).range(a, b).
class JsRng:
	var s := 1

	func _init(seed: int) -> void:
		s = seed & 0xffffffff
		if s == 0:
			s = 1

	static func _mul(a: int, b: int) -> int:
		return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = _mul(t ^ (t >> 15), t | 1)
		t = t ^ ((t + _mul(t ^ (t >> 7), t | 61)) & 0xffffffff)
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()
