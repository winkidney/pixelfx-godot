# Shared by the melee build scripts (not an effect): the original's swings (src/fx/melee/_lib.js: a circle on a tilted
# plane, swept), its slash crescents with their light and dotted trace (fx/melee/_slash.gdshader, _swing_light), its
# simulated particles replayed on GPU particles (fx/melee/_kinds.gdshader: SPARK, MOTE, STAR, SMOKE, GRIT, rocks...),
# its lights that flare and die, its sparkle glints, and the easings it leans on. Every curve is the original's
# formula sampled into keys; shaders never read TIME.
extends "res://addons/pixelfx_particles/core/build.gd"

const MEL := "res://addons/pixelfx_particles/fx/melee/"
const HZ := 60.0
const HOT := ["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"]
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const OUTLINE := "#1a1422"

## The original's particle kinds (core/sim.js P) and debris (Bits B), as _kinds.gdshader numbers them.
const SPARK := 0
const MOTE := 1
const STREAK := 2
const VAPOUR := 4
const DUST := 5
const STAR := 6
const EMBER := 7
const SMOKE := 8
const SMOKE_BIG := 9
const GRIT := 11
const CHIP := 20
const CHUNK := 21
const DRIP := 22
const WISP := 30

var C: PackedColorArray
var R: Rng
var _bursts := 0


## A seeded random source with the original's Rng calls (its numbers differ; its distributions don't).
class Rng:
	var g := RandomNumberGenerator.new()

	func _init(s: int) -> void:
		g.seed = s

	func next() -> float:
		return g.randf()

	func rf(a: float, b: float) -> float:
		return a + (b - a) * g.randf()

	func chance(p: float) -> bool:
		return g.randf() < p

	func ri(a: int, b: int) -> int:
		return a + int(floor(g.randf() * (b - a + 1)))

	func pick(arr: Array) -> Variant:
		return arr[mini(arr.size() - 1, int(floor(g.randf() * arr.size())))]

	func sgn() -> float:
		return -1.0 if g.randf() < 0.5 else 1.0


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.palette
	R = Rng.new(int(meta.options.get("seed", 1)) * 7919 + 17)


func mel_shader(name: String) -> Shader:
	return load(MEL + "_" + name + ".gdshader")


# ------------------------------------------------------------------ easing (core/math.js)

static func clamp01(x: float) -> float:
	return clampf(x, 0.0, 1.0)


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clamp01(x), 3.0)


static func in_quad(x: float) -> float:
	return pow(clamp01(x), 2.0)


static func out_back(x: float, s := 1.70158) -> float:
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


static func in_out_sine(x: float) -> float:
	return -(cos(PI * clamp01(x)) - 1.0) / 2.0


static func seg(t: float, a: float, b: float) -> float:
	return clamp01((t - a) / (b - a))


static func smooth(a: float, b: float, x: float) -> float:
	var u := seg(x, a, b)
	return u * u * (3.0 - 2.0 * u)


## The original's rand(...): a repeatable hash of integers to 0..1.
static func hrand(a: float, b := 0.0, c := 0.0) -> float:
	var h := sin(a * 127.1 + b * 311.7 + c * 74.7) * 43758.5453
	return h - floor(h)


static func scaled(c: Color, k: float) -> Color:
	return Color(minf(1.0, c.r * k), minf(1.0, c.g * k), minf(1.0, c.b * k), c.a)


# ------------------------------------------------------------------ keys

## Key node.prop from f(t) sampled `hz` times a second over [t0, t1] (t1 < 0: the whole effect). "nearest" keys sit a
## hair before each sample so a capture at exactly that time gets that value.
func keyf(node: Node, prop: String, f: Callable, t0 := 0.0, t1 := -1.0, hz := HZ, interp := "linear") -> void:
	var end: float = root.duration if t1 < 0.0 else t1
	var keys := []
	var n := int(ceilf((end - t0) * hz - 1e-6))
	for i in n + 1:
		var t := minf(t0 + i / hz, end)
		var at := t
		if interp == "nearest" and t > 0.0:
			at = maxf(0.0, t - 0.002)
		keys.append([at, f.call(t)])
	key(node, prop, keys, interp)


## Key node.prop to f(t) inside the window (t0, t1) and to `off` outside it, stepping sharply at both ends (the
## original draws a thing only while t0 < t < t1).
func keyf_window(node: Node, prop: String, f: Callable, t0: float, t1: float, off: Variant = 0.0, hz := HZ) -> void:
	# the render's clock runs a few ms ahead of the frame times: a window opening just after a frame's time must not
	# show on that frame, so it opens 13 ms after it
	var on := t0
	var fr := floorf(t0 * 30.0 + 1e-6) / 30.0
	if t0 > 0.0 and t0 - fr < 0.013:
		on = fr + 0.013
	var keys := [[0.0, off]] if t0 > 0.0 else []
	if on > 0.002:
		keys.append([on - 0.001, off])
	# the last sample sits just inside the window, so the step out at t1 stays a step
	var end := minf(t1 - 0.0005, root.duration)
	var n := int(ceilf((end - t0) * hz - 1e-6))
	for i in n + 1:
		var t := minf(t0 + i / hz, end)
		var tt := t if t0 <= 0.0 else maxf(t, on + 0.0005)
		if i > 0 and tt <= on + 0.0005:
			continue
		keys.append([tt, f.call(tt)])
	if t1 < root.duration:
		keys.append([t1, off])
	key(node, prop, keys)


# ------------------------------------------------------------------ swings (_lib.js)

## A swing: centre (cx, cy), radius R, squash sy, turn rot, start angle a0, direction dir, cone k; plus whatever a
## slash needs (span, W, t0, sweep, hold, trail, ramp, lens, hot).
func swing(o: Dictionary) -> Dictionary:
	var s := {"cx": 0.0, "cy": 0.0, "R": 30.0, "sy": 1.0, "rot": 0.0, "a0": 0.0, "dir": 1.0, "k": 0.0, "span": PI,
		"W": 8.0, "t0": 0.0, "sweep": 0.06, "hold": 0.06, "trail": 0.24, "lens": false, "ramp": C}
	s.merge(o, true)
	return s


## A swing on radius r whose arc passes through (x, y) heading along th, that point `at` of the way along span.
func through(x: float, y: float, th: float, d: float, r: float, span: float, at := 0.55, extra := {}) -> Dictionary:
	var a := th - d * PI / 2.0
	var o := {"cx": x - cos(a) * r, "cy": y - sin(a) * r, "R": r, "sy": 1.0, "rot": 0.0, "a0": a - d * span * at, "dir": d, "span": span}
	o.merge(extra, true)
	return swing(o)


static func on_swing(s: Dictionary, r: float, u: float) -> Vector2:
	var a: float = s.a0 + s.dir * u
	var lx := cos(a) * r
	var ly: float = sin(a) * r * s.sy - s.k * (s.R - r)
	var c := cos(float(s.rot))
	var n := sin(float(s.rot))
	return Vector2(s.cx + lx * c - ly * n, s.cy + lx * n + ly * c)


## Where the swing is at u and which way it's travelling: {p, d (unit), a (in-plane angle)}.
static func travel(s: Dictionary, u: float) -> Dictionary:
	var p0 := on_swing(s, s.R, u)
	var p1 := on_swing(s, s.R, u + 0.01)
	var d := p1 - p0
	return {"p": p0, "d": d.normalized() if d.length() > 0.0 else Vector2.RIGHT, "a": s.a0 + s.dir * u}


static func slash_end(s: Dictionary) -> Dictionary:
	var e := s.duplicate()
	e.R = s.R - s.W * 0.3
	return travel(e, s.span)


## Geometry uniforms for a swing's shaders, and the rect that holds it (pad px beyond the rim, w px band).
func _swing_params(s: Dictionary, half: float) -> Dictionary:
	var ramp_in: PackedColorArray = s.ramp
	var ramp := []
	for i in 8:
		ramp.append(ramp_in[mini(i, ramp_in.size() - 1)])
	return {"sc": Vector2(s.cx, s.cy), "R": s.R, "sy": s.sy, "rot": s.rot, "a0": s.a0, "dir": s.dir, "kc": s.k,
		"side": half, "ramp": ramp, "n": float(ramp_in.size())}


func _swing_box(s: Dictionary, w: float, extra: float) -> Dictionary:
	var A: float = s.R + 3.0 + extra
	var Bn: float = A * s.sy + absf(s.k) * (w + 2.0) + extra
	var c := cos(float(s.rot))
	var n := sin(float(s.rot))
	var hx := Vector2(A * c, Bn * n).length() + 2.0
	var hy := Vector2(A * n, Bn * c).length() + 2.0 + absf(s.k) * (w + 2.0)
	var at := Vector2(floorf(s.cx), floorf(s.cy))
	return {"at": at, "size": Vector2(2.0 * ceilf(hx + 1.0), 2.0 * ceilf(hy + 1.0))}


## The original's slash(p, s, t, half): the crescent (head out over sweep, hold, tail after it over trail, thinning and
## cooling), its light riding it and its dotted trace (colour s.ramp[trace]). half -1 draws only the far half (behind
## the stand-in), 1 the near half. hot(t) flashes it white. Returns [colour node, light node].
func slash(name: String, s: Dictionary, half := 0.0, o := {}) -> Array:
	var ramp: PackedColorArray = s.ramp
	var nn := ramp.size()
	var params := _swing_params(s, half)
	params.merge({"wmax": s.W, "lens": 1.0 if s.lens else 0.0, "span": s.span, "tr_r": s.R - 0.5,
		"tr_col": ramp[o.get("trace", 2)], "T": 0.0, "U": 0.0, "W": s.W, "tr_k": 0.0, "tr_u1": 0.0})
	var box := _swing_box(s, s.W, 1.0)
	var back := half < 0.0
	var col := shape(name, mel_shader("slash"), box.size, params, {"at": box.at, "back": back})
	var lp := _swing_params(s, half)
	lp.erase("ramp")
	lp.erase("n")
	lp.merge({"gr": s.R, "gstep": 0.3, "rad": 5.0 + s.W, "color": ramp[nn - 3], "k0": 0.0, "lin": 1.0})
	var lbox := _swing_box(s, s.W, 5.0 + s.W)
	# the original adds all its light over everything, the far half's too
	var lit := shape(name + "Light", mel_shader("swing_light"), lbox.size, lp, {"at": lbox.at})
	var hot: Callable = o.get("hot", func(_t: float) -> float: return 0.0)
	var life: float = s.sweep + s.hold + s.trail
	var t_end: float = minf(root.duration, s.t0 + life + 0.25)
	var st := func(t: float) -> Dictionary:
		var u: float = t - s.t0
		var d := {"T": 0.0, "U": 0.0, "W": s.W, "age": 0.0, "hot": hot.call(t), "tr_u1": 0.0, "tr_k": 0.0, "k0": 0.0}
		if u < 0.0:
			return d
		var head := out_expo(clamp01(u / s.sweep))
		var tail := smooth(s.sweep + s.hold, life, u)
		var age := clamp01(u / life)
		d.W = s.W * (1.0 - tail * 0.55)
		d.age = age
		if tail < 1.0 and s.span * (head - tail) > 0.01:
			d.T = s.span * tail
			d.U = s.span * head
			d.k0 = (0.22 + d.hot * 0.3) * (1.0 - age)
		var th: float = 0.7 * (1.0 - clamp01((u - s.sweep - s.hold) / (s.trail + 0.2)))
		if tail > 0.02 and th > 0.0:
			d.tr_u1 = s.span * tail
			d.tr_k = th
		return d
	var cache := {}
	var at := func(t: float) -> Dictionary:
		var kk := snappedf(t, 0.0001)
		if not cache.has(kk):
			cache[kk] = st.call(t)
		return cache[kk]
	for k in ["T", "U", "W", "age", "hot", "tr_u1", "tr_k"]:
		var kname: String = k
		keyf(col, "material:shader_parameter/" + k, func(t: float) -> float: return at.call(t)[kname], 0.0, t_end)
	keyf(lit, "material:shader_parameter/u0", func(t: float) -> float: return at.call(t).T, 0.0, t_end)
	keyf(lit, "material:shader_parameter/u1", func(t: float) -> float: return at.call(t).U, 0.0, t_end)
	keyf(lit, "material:shader_parameter/la", func(t: float) -> float: return at.call(t).T, 0.0, t_end)
	keyf(lit, "material:shader_parameter/lb", func(t: float) -> float: return at.call(t).U, 0.0, t_end)
	keyf(lit, "material:shader_parameter/k0", func(t: float) -> float: return at.call(t).k0, 0.0, t_end)
	keyf(lit, "material:shader_parameter/gr", func(t: float) -> float: return s.R - at.call(t).W * 0.4, 0.0, t_end)
	keyf(lit, "material:shader_parameter/rad", func(t: float) -> float: return 5.0 + at.call(t).W, 0.0, t_end)
	show(col, maxf(0.0, s.t0 - 0.02), t_end)
	show(lit, maxf(0.0, s.t0 - 0.02), t_end)
	return [col, lit]


# ------------------------------------------------------------------ particles (core/sim.js, replayed)

## One spawn of the original's ps.spawn(kind, x, y, vx, vy, life, col, size, delay): a row for burst().
static func sp(x: float, y: float, vx: float, vy: float, life: float, col: Variant = Color.WHITE, size := 1.0, delay := 0.0) -> Dictionary:
	return {"p": Vector2(x, y), "v": Vector2(vx, vy), "life": life, "col": col if col is Color else Color(col), "size": size, "delay": delay}


## Particles of one kind spawned at t0 (the list of sp()s, all at once), replayed by fx/melee/_kinds.gdshader from a
## table: one GPUParticles2D per piece the kind draws (a streak's tail and head, its glow...). o: back, sparks (the
## SPARK / EMBER / chip ramp, head first), floor (false: no floor), haze (vapour's glow colour), stone (rock shades).
func burst(name: String, kind: int, t0: float, list: Array, o := {}) -> Array:
	if list.is_empty():
		return []
	var n := list.size()
	var img := Image.create(n, 4, false, Image.FORMAT_RGBAF)
	var top := 0.0
	for i in n:
		var q: Dictionary = list[i]
		img.set_pixel(i, 0, Color(q.p.x, q.p.y, q.v.x, q.v.y))
		img.set_pixel(i, 1, Color(q.life, q.get("delay", 0.0), q.get("size", 1.0), R.rf(0.0, 100.0)))
		var c: Color = q.col
		img.set_pixel(i, 2, c)
		img.set_pixel(i, 3, Color(q.get("g", 1.0), q.get("drag", 0.0), q.get("bounce", 0.0), q.get("spin", 0.0)) if kind >= CHIP else Color(o.get("haze", Color.BLACK)))
		top = maxf(top, q.life + q.get("delay", 0.0))
		if c.a > 0.0:
			keep_colour(c)
			if kind == MOTE:
				keep_colour(scaled(c, 0.55))
			elif kind == STAR:
				keep_colour(scaled(c, 0.75))
			elif kind == STREAK:
				keep_colour(scaled(c, 0.6))
	_bursts += 1
	var tex := asset("%s_%d" % [name.to_snake_case(), _bursts], img)
	var spk: Array = o.get("sparks", meta.options.get("sparks", HOT))
	var sc := []
	for i in 4:
		var c: Color = spk[mini(i, spk.size() - 1)] if spk[0] is Color else Color(spk[mini(i, spk.size() - 1)])
		sc.append(c)
		if kind in [SPARK, EMBER, CHIP, WISP]:
			keep_colour(c)
	var smoke := PackedVector4Array()
	for h in SMOKE_RAMP:
		var c := Color(h)
		smoke.append(Vector4(c.r, c.g, c.b, 1.0))
		if kind == SMOKE or kind == SMOKE_BIG:
			keep_colour(c)
	var parts: Array = {SPARK: [0, 1, 2], MOTE: [0, 1, 2], STREAK: [0, 1, 3, 2], VAPOUR: [0, 2] if o.has("haze") else [0], DUST: [0],
		STAR: [0, 2], EMBER: [0, 1, 2], SMOKE: [0, 1, 3], SMOKE_BIG: [0, 1, 3], GRIT: [0], CHIP: [0, 1, 2], CHUNK: [0],
		DRIP: [0, 1], WISP: [0, 1, 3, 2]}[kind]
	# the original spawns on its first 120 Hz step at or past t0 and moves them one step before the frame is drawn; the
	# emitter starts on the first 30 fps frame at or past that and has run two 60 Hz steps by the time it's drawn
	var ts := ceilf(t0 * 120.0 - 1e-4) / 120.0
	var tf := ceilf(ts * 30.0 - 1e-4) / 30.0
	var lag := maxf(0.0, 2.0 / 60.0 - (tf - ts + 1.0 / 120.0))
	var life := minf(top + lag + 0.02, root.duration - tf + 0.04)
	var out := []
	for part in parts:
		var soft_kind: bool = kind in [VAPOUR, DUST, SMOKE, SMOKE_BIG]
		var layer := "light" if part == 2 else ("soft" if soft_kind else "color")
		var p := particles("%s%d" % [name, part], {"amount": n, "lifetime": life, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "local": true, "texture": "dot1", "layer": layer, "back": o.get("back", false),
			"process_shader": MEL + "_kinds.gdshader", "process_params": {"table": tex, "kind_": float(kind), "part_": float(part),
				"t0": ts, "lag": lag, "has_floor": 0.0 if o.get("floor", true) == false else 1.0, "floor_y": o.get("floor_y", 0.0),
				"s0": sc[0], "s1": sc[1], "s2": sc[2], "s3": sc[3], "smoke": smoke}})
		p.interpolate = false
		if part == 2:
			var m := ShaderMaterial.new()
			m.shader = mel_shader("plight")
			p.material = m
		elif kind == STAR and part == 0:
			var m := ShaderMaterial.new()
			m.shader = mel_shader("psparkle")
			p.material = m
		elif kind == CHUNK:
			var m := ShaderMaterial.new()
			m.shader = mel_shader("prock")
			var st: Dictionary = o.stone
			for k in ["light", "body", "shade", "dark"]:
				m.set_shader_parameter(k, st[k])
				keep_colour(st[k])
			m.set_shader_parameter("outline", Color(OUTLINE))
			keep_colour(Color(OUTLINE))
			p.material = m
		elif soft_kind:
			var m := ShaderMaterial.new()
			m.shader = mel_shader("pdisc")
			m.set_shader_parameter("translucent", true)
			p.material = m
		emit(p, maxf(0.0, tf - 0.004))
		out.append(p)
	return out


## The original's stone(c): rock, grit and dust shades from one body colour.
func stone(hexc: String) -> Dictionary:
	var c := Color(hexc)
	var lt := scaled(c, 1.35).lerp(Color.WHITE, 0.08)
	var st := {"light": lt, "body": c, "shade": scaled(c, 0.64), "dust": scaled(c, 1.2).lerp(Color8(150, 140, 150), 0.3), "dark": scaled(c, 0.42)}
	for k in st:
		keep_colour(st[k])
	return st


# ------------------------------------------------------------------ light and glints

## The original's Lights.add(x, y, r, c, k, life) at t0: a glow that shrinks a little and dies, k * (life left)^2.
func light_burst(name: String, t0: float, at: Vector2, r0: float, c: Color, k: float, life: float, o := {}) -> ColorRect:
	var lg := glow(name, r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": at, "back": o.get("back", false)})
	keyf(lg, "material:shader_parameter/radius", func(t: float) -> float: return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0, minf(root.duration, t0 + life))
	keyf_window(lg, "material:shader_parameter/alpha", func(t: float) -> float: return k * pow(1.0 - seg(t, t0, t0 + life), 2.0), t0, t0 + life)
	return lg


## A glow (the original's p.glow) whose place, radius and strength follow f(t) -> [Vector2 at, radius, k] over [t0, t1].
func glow_path(name: String, reach: float, c: Color, f: Callable, t0: float, t1: float, o := {}) -> ColorRect:
	var g := glow(name, reach, {"radius": reach, "color": c, "alpha": 0.0}, {"back": o.get("back", false)})
	keyf(g, "position", func(t: float) -> Vector2: return f.call(t)[0], t0, t1)
	keyf(g, "material:shader_parameter/radius", func(t: float) -> float: return f.call(t)[1], t0, t1)
	keyf_window(g, "material:shader_parameter/alpha", func(t: float) -> float: return f.call(t)[2], t0, t1)
	return g


## The original's sparkle(p, x, y, arm(t), c, tip, k) at a fixed point from t0 to t1: the glint (arms rounded) and its
## glow (radius 4 + 2 n, strength k(t)). f(t) -> [arm, k].
func sparkle(name: String, at: Vector2, c: Color, tip: Color, f: Callable, t0: float, t1: float, o := {}) -> Array:
	var cell := at.floor()
	var s := shape(name, mel_shader("sparkle"), Vector2(25, 25), {"arm": 0.0, "c": c, "tip": tip, "heart": Color.WHITE},
		{"at": cell + Vector2(0.5, 0.5), "back": o.get("back", false)})
	keyf_window(s, "material:shader_parameter/arm", func(t: float) -> float: return f.call(t)[0], t0, t1)
	var g := glow(name + "Light", 26, {"radius": 4.0, "color": c, "alpha": 0.0}, {"at": at, "back": o.get("back", false)})
	keyf(g, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * roundf(f.call(t)[0]), t0, minf(root.duration, t1))
	keyf_window(g, "material:shader_parameter/alpha", func(t: float) -> float: return f.call(t)[1] if roundf(f.call(t)[0]) >= 1.0 else 0.0, t0, t1)
	return [s, g]


## The original's slivers flying out of `at` from t0 for dur s: list of [angle, radius, speed, arc] (fx/melee/_slivers),
## colours c0 (k < 0.4), c1 (k < 0.7), c2.
func slivers(name: String, at: Vector2, list: Array, t0: float, dur: float, c0: Color, c1: Color, c2: Color, o := {}) -> ColorRect:
	var reach := 0.0
	var sl := PackedVector4Array()
	for s in list:
		sl.append(Vector4(s[0], s[1], s[2], s[3]))
		reach = maxf(reach, s[1] + s[2] * dur + 3.0)
	var sz := Vector2(2.0 * ceilf(reach + 2.0) + 1.0, 2.0 * ceilf(reach + 2.0) + 1.0)
	var n := shape(name, mel_shader("slivers"), sz, {"sl": sl, "count": float(list.size()), "q": -1.0, "dur": dur,
		"c0": c0, "c1": c1, "c2": c2, "frac_": at - at.floor()}, {"at": at.floor() + Vector2(0.5, 0.5), "back": o.get("back", false)})
	key(n, "material:shader_parameter/q", [[0.0, -1.0], [maxf(0.0, t0 - 0.001), -1.0], [t0, 0.0], [t0 + dur, dur], [t0 + dur + 0.001, dur + 1.0]])
	return n


## The original's shavings(): n motes flung off a slash's edge, outward from its circle.
func shavings(s: Dictionary, n: int, cols: Array, from := 0.3) -> Array:
	var out := []
	for i in n:
		var p := on_swing(s, s.R, s.span * R.rf(from, 1.0))
		var o := p - Vector2(s.cx, s.cy)
		var l := o.length() if o.length() > 0.0 else 1.0
		var v := R.rf(30, 100)
		out.append(sp(p.x, p.y, o.x / l * v, minf(25.0, o.y / l * v) - 10.0, R.rf(0.25, 0.55), R.pick(cols), 0.6))
	return out


## The original's flare(p, x, y, L(t), k(t), ramp) at a fixed point from t0 to t1 (fx/melee/_flare): f(t) -> [L, k].
func flare(name: String, at: Vector2, reach: float, f: Callable, t0: float, t1: float, o := {}) -> ColorRect:
	var sz := Vector2(2.0 * ceilf(reach + 2.0) + 1.0, 2.0 * ceilf(reach + 2.0) + 1.0)
	var n := C.size()
	var fl := shape(name, mel_shader("flare"), sz, {"frac_": at - at.floor(), "L": 0.0, "k": 1.0, "white": Color.WHITE,
		"hi": C[n - 2], "lo": C[n - 3]}, {"at": at.floor() + Vector2(0.5, 0.5), "back": o.get("back", false)})
	keyf_window(fl, "material:shader_parameter/L", func(t: float) -> float: return f.call(t)[0], t0, t1)
	keyf(fl, "material:shader_parameter/k", func(t: float) -> float: return f.call(t)[1], t0, minf(t1, root.duration))
	return fl


## The original's impact star(p, x, y, spikes, sc, th, core, body, inner, rim) at a fixed point from t0 to t1
## (fx/melee/_star): spikes [[angle, length, width], ...]; f(t) -> [sc, th, turn, core, body, inner, rim].
func impact_star(name: String, at: Vector2, spikes: Array, reach: float, f: Callable, t0: float, t1: float, o := {}) -> ColorRect:
	var sz := Vector2(2.0 * ceilf(reach + 3.0) + 1.0, 2.0 * ceilf(reach + 3.0) + 1.0)
	var spv := PackedVector4Array()
	for s in spikes:
		spv.append(Vector4(s[0], s[1], s[2], 0.0))
	var first: Array = f.call(t0 + 0.0005)
	var st := shape(name, mel_shader("star"), sz, {"frac_": at - at.floor(), "sp": spv, "count": float(spikes.size()), "sc": 0.0,
		"th": 1.0, "turn": 0.0, "core": first[3], "body": first[4], "inner": first[5], "rim": first[6]},
		{"at": at.floor() + Vector2(0.5, 0.5), "back": o.get("back", false)})
	keyf_window(st, "material:shader_parameter/sc", func(t: float) -> float: return f.call(t)[0], t0, t1)
	keyf(st, "material:shader_parameter/th", func(t: float) -> float: return f.call(t)[1], t0, minf(t1, root.duration))
	keyf(st, "material:shader_parameter/turn", func(t: float) -> float: return f.call(t)[2], t0, minf(t1, root.duration))
	var names := ["core", "body", "inner", "rim"]
	for j in 4:
		var jj := j
		var keys := []
		var last: Variant = null
		var n := int(ceilf((minf(t1, root.duration) - t0) * HZ))
		for i in n + 1:
			var t := t0 + 0.0005 + i / HZ
			var c: Color = f.call(t)[3 + jj]
			keep_colour(c)
			if last == null or c != last:
				keys.append([maxf(0.0, t - 0.002), c])
				last = c
		key(st, "material:shader_parameter/" + names[jj], keys, "nearest")
	return st


## Dotted speed lines (fx/melee/_lines): lines [[x0, y0, vx, vy, born, life, length, shrink], ...] (up to 16), white
## for 3 px, c1 to f1 of the length, then c2; a rect from lo to hi (px from the origin) holds them.
func speed_lines(name: String, lines: Array, lo: Vector2, hi: Vector2, f1: float, c1: Color, c2: Color, o := {}) -> ColorRect:
	var la := PackedVector4Array()
	var lb := PackedVector4Array()
	for l in lines:
		la.append(Vector4(l[0], l[1], l[2], l[3]))
		lb.append(Vector4(l[4], l[5], l[6], l[7]))
	var a := lo.floor()
	var b := hi.ceil()
	var sz := b - a
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	var n := shape(name, mel_shader("lines"), sz, {"la": la, "lb": lb, "count": float(lines.size()), "q": 0.0, "f1": f1,
		"white": Color.WHITE, "c1": c1, "c2": c2}, {"at": a + sz / 2.0, "back": o.get("back", false)})
	key(n, "material:shader_parameter/q", [[0.0, 0.0], [root.duration, root.duration]])
	return n


## A straight 1 px line (the original's p.line, cell to cell) whose ends, colour and alpha follow f(t) -> [a, b, colour,
## alpha] while t0 < t < t1: a Line2D on the colour layer, keyed every frame.
func seg_line(name: String, f: Callable, t0: float, t1: float, o := {}) -> Line2D:
	var l := line(name, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"width": 1.0, "back": o.get("back", false)})
	var pts := [[0.0, PackedVector2Array()]]
	var cols := [[0.0, Color(1, 1, 1, 0)]]
	var n := int(ceilf((minf(t1, root.duration) - t0) * HZ))
	for i in n + 1:
		var t := t0 + 0.0005 + i / HZ
		if t >= t1:
			break
		var r: Array = f.call(t)
		var pa: Vector2 = Vector2(r[0]).floor() + Vector2(0.5, 0.5)
		var pb: Vector2 = Vector2(r[1]).floor() + Vector2(0.5, 0.5)
		var d := pb - pa
		var e := d.normalized() if d.length() > 0.01 else Vector2.RIGHT
		pts.append([maxf(0.0, t - 0.002), PackedVector2Array([pa - e * 0.5, pb + e * 0.5])])
		var c: Color = r[2]
		keep_colour(c)
		cols.append([maxf(0.0, t - 0.002), Color(c.r, c.g, c.b, r[3])])
	pts.append([t1, PackedVector2Array()])
	cols.append([t1, Color(1, 1, 1, 0)])
	key(l, "points", pts, "nearest")
	key(l, "default_color", cols, "nearest")
	return l


## A ring of dots (fx/melee/_dotring) at a fixed point while t0 < t < t1: f(t) -> [r, th, colour, alpha, offset].
## o: rx_k, ry_k (ellipse), astep (angle between dots; 0: 0.6 / r).
func dot_ring(name: String, at: Vector2, reach: float, f: Callable, t0: float, t1: float, o := {}) -> ColorRect:
	var sz := Vector2(2.0 * ceilf(reach + 3.0) + 1.0, 2.0 * ceilf(reach + 3.0) + 1.0)
	var first: Array = f.call(t0 + 0.0005)
	var rg := shape(name, mel_shader("dotring"), sz, {"frac_": at - at.floor(), "r": first[0], "th": first[1], "color": first[2],
		"alpha": 0.0, "rx_k": o.get("rx_k", 1.0), "ry_k": o.get("ry_k", 1.0), "astep": o.get("astep", 0.0)},
		{"at": at.floor() + Vector2(0.5, 0.5), "back": o.get("back", false)})
	keyf_window(rg, "material:shader_parameter/alpha", func(t: float) -> float: return f.call(t)[3], t0, t1)
	keyf(rg, "material:shader_parameter/r", func(t: float) -> float: return f.call(t)[0], t0, minf(t1, root.duration))
	keyf(rg, "material:shader_parameter/th", func(t: float) -> float: return f.call(t)[1], t0, minf(t1, root.duration))
	if first.size() > 4:
		keyf(rg, "material:shader_parameter/off", func(t: float) -> Vector2: return f.call(t)[4], t0, minf(t1, root.duration))
	var keys := []
	var last: Variant = null
	var n := int(ceilf((minf(t1, root.duration) - t0) * HZ))
	for i in n + 1:
		var t := t0 + 0.0005 + i / HZ
		var c: Color = f.call(t)[2]
		keep_colour(c)
		if last == null or c != last:
			keys.append([maxf(0.0, t - 0.002), c])
			last = c
	key(rg, "material:shader_parameter/color", keys, "nearest")
	return rg


## A shader of this category's (fx/melee/_<shader>.gdshader) drawn over swing s: its geometry uniforms set, a rect big
## enough for a band w px wide plus `extra` px round it. half -1 puts it behind the stand-in (the far half).
func swing_shape(name: String, shader: String, s: Dictionary, params: Dictionary, w: float, extra := 1.0, half := 0.0) -> ColorRect:
	var pr := _swing_params(s, half)
	if shader.ends_with("light"):
		pr.erase("ramp")
		pr.erase("n")
	pr.merge(params, true)
	var box := _swing_box(s, w, extra)
	return shape(name, mel_shader(shader), box.size, pr, {"at": box.at, "back": half < 0.0 and not shader.ends_with("light")})


## Key several uniforms of node from one function of time f(t) -> {uniform: value} over [t0, t1].
func keyd(node: Node, names: Array, f: Callable, t0: float, t1: float) -> void:
	var cache := {}
	var at := func(t: float) -> Dictionary:
		var kk := snappedf(t, 0.0001)
		if not cache.has(kk):
			cache[kk] = f.call(t)
		return cache[kk]
	for k in names:
		var kname: String = k
		keyf(node, "material:shader_parameter/" + kname, func(t: float) -> Variant: return at.call(t)[kname], t0, minf(t1, root.duration))


## The original's cracks(): jagged cracks splitting the floor from x0, each running out along the floor's edge and
## zig-zagging down into its face, with short forks. Returns [{pts: [Vector2], at, fork}].
func cracks(x0: float, n: int, reach: float, depth := 7.0, bias := 0.3) -> Array:
	var out := []
	for i in n:
		var sd := 1.0 if R.chance(0.5 + bias * 0.5) else -1.0
		var L := reach * R.rf(0.45, 1) * (1.0 if i < 2 else 0.7)
		var pts := [Vector2(x0 + sd * R.rf(0, 1.5), 0)]
		var x: float = pts[0].x
		var y := 0.0
		while absf(x - x0) < L and y < depth:
			x += sd * R.rf(1.5, 3.5)
			y = minf(depth, maxf(0.0, y + R.rf(-0.6, 1.6) * (1.0 if absf(x - x0) > 3.0 else 0.3)))
			pts.append(Vector2(roundf(x), roundf(y)))
			if R.chance(0.18) and pts.size() > 3 and y < depth - 2.0:
				var f := [Vector2(roundf(x), roundf(y))]
				var fx_ := x
				var fy := y
				for j in R.ri(1, 3):
					fx_ += sd * R.rf(1, 3)
					fy += R.rf(0.8, 2)
					f.append(Vector2(roundf(fx_), roundf(minf(depth + 1.0, fy))))
				out.append({"pts": f, "at": absf(x - x0) / reach, "fork": true})
		out.append({"pts": pts, "at": 0.0, "fork": false})
	return out


## The cracks as fx/melee/_cracks.gdshader over a rect lo..hi (px from the origin); params: mode, reach, ramp_t, at_k,
## the colours. Key q (s since the blow), heat and fade.
func cracks_shape(name: String, lines: Array, lo: Vector2, hi: Vector2, params: Dictionary) -> ColorRect:
	var segs := []
	for c in lines:
		var d := 0.0
		for i in range(1, c.pts.size()):
			var a: Vector2 = c.pts[i - 1]
			var b: Vector2 = c.pts[i]
			segs.append([a, b, d, c.at, 1.0 if c.fork else 0.0])
			d += a.distance_to(b)
	var img := Image.create(maxi(1, segs.size()), 2, false, Image.FORMAT_RGBAF)
	for i in segs.size():
		var s: Array = segs[i]
		img.set_pixel(i, 0, Color(s[0].x, s[0].y, s[1].x, s[1].y))
		img.set_pixel(i, 1, Color(s[2], s[3], s[4], 0.0))
	var pr := {"segs": asset(name.to_snake_case(), img), "count": float(segs.size()), "q": -1.0}
	pr.merge(params, true)
	var sz := (hi - lo).ceil()
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	return shape(name, mel_shader("cracks"), sz, pr, {"at": lo.floor() + sz / 2.0})


## The original's band() rolling out across the floor from t0 for dur s (fx/melee/_band): the far half behind the
## stand-in, the near half in front. f(k) -> [r, th, alpha] for k = 0..1; cols: rim first.
func floor_band(name: String, at: Vector2, reach: float, t0: float, dur: float, f: Callable, cols: Array) -> void:
	var sz := Vector2(2.0 * ceilf(reach + 4.0), 2.0 * ceilf(reach * 0.16 + 4.0))
	var c := at.floor()
	for half in [[1.0, true, "Back"], [-1.0, false, "Front"]]:
		var b := shape(name + half[2], mel_shader("band"), sz, {"frac_": at - c, "sy": 0.16, "side": half[0], "k": 0.0, "c0": cols[0], "c1": cols[1],
			"c2": cols[2], "c3": cols[3]}, {"at": c, "back": half[1]})
		keyf_window(b, "material:shader_parameter/k", func(t: float) -> float: return f.call((t - t0) / dur)[2], t0, t0 + dur)
		keyf(b, "material:shader_parameter/r", func(t: float) -> float: return f.call((t - t0) / dur)[0], t0, t0 + dur)
		keyf(b, "material:shader_parameter/th", func(t: float) -> float: return f.call((t - t0) / dur)[1], t0, t0 + dur)
