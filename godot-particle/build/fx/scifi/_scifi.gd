# Shared by the scifi build scripts (not an effect). The originals (src/fx/scifi/*.js) roll their choices from seeded
# generators and move their particles by the toolkit's physics, so this replays both:
#   - the original's randomness bit for bit (JsRng: mulberry32; rand(): math.js hash), its colour maths (mix, scale)
#     and easings, to key shapes and shaders on the original's own beats (keyf samples a formula every frame);
#   - its particles: ghost() collects each of the original's Ghosts.add (loops) or Particles.spawn (one-shots) and
#     ghosts() turns each kind into a GPUParticles2D placed from the keyed clock by the original's own physics
#     (fx/scifi/_ghost.gdshader), drawn as the original draws the kind (_bits.gdshader) with a light twin
#     (_bits_light.gdshader) for the glow round sparks, motes, streaks, stars, embers and fire;
#   - light: the original's p.glow / Lights.add / glowLine keyed from their formulas.
extends "res://addons/pixelfx_particles/core/build.gd"

const DIR := "res://addons/pixelfx_particles/fx/scifi/"
const SPARK := 0
const MOTE := 1
const STREAK := 2
const FLAKE := 3
const VAPOUR := 4
const DUST := 5
const STAR := 6
const EMBER := 7
const SMOKE := 8
const FIRE := 9
const GRIT := 11
const PIXEL := 12
const DEAD := 13
const BIT := 14
const PF_SMOKES := 1
const PF_BIG := 2
const PF_BACK := 4
const GRAVITY := 950.0
const FIRE_RAMP := ["#ffffff", "#fff3a6", "#ffe26b", "#ffc23d", "#ff8a2a", "#f2561d", "#c9281f", "#8a1f17", "#4a1712"]
const SMOKE_RAMP := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const HOT := ["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"]
const SOFT_KINDS := [VAPOUR, DUST, SMOKE]

var C: PackedColorArray
var W := Color.WHITE
var _gh := []
var _gh_n := 0
var _gh_period := 0.0
var _gh_flushed := 0


func begin(effect_id: String) -> void:
	super(effect_id)
	C = root.ramps.get("palette", PackedColorArray())
	keep_colour(Color.WHITE)


func sh(name: String) -> Shader:
	return load(DIR + "_" + name + ".gdshader")


## color.js fit(): the ramp resampled to n steps, its ends kept.
static func fit(r: PackedColorArray, n: int) -> PackedColorArray:
	if r.size() == n:
		return r
	var out := PackedColorArray()
	for i in n:
		out.append(r[int(roundf(i * (r.size() - 1) / float(maxi(1, n - 1))))])
	return out


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


## math.js hash(...ns) (a uint)
static func hash_(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		h = JsRng._mul(h ^ (_i32(n) & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = JsRng._mul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & 0xffffffff


## JS `n | 0`: truncate toward zero, wrapped to 32 bits
static func _i32(n: Variant) -> int:
	var f := float(n)
	var i := int(f) if absf(f) < 9.0e18 else 0
	return i & 0xffffffff


## math.js rand(...ns) in [0, 1)
static func rand(ns: Array) -> float:
	return hash_(ns) / 4294967296.0


## math.js rng(...ns): a generator seeded from a hash
static func rng(ns: Array) -> JsRng:
	return JsRng.new(hash_(ns))


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


static func luma(c: Color) -> float:
	return (0.299 * c.r8 + 0.587 * c.g8 + 0.114 * c.b8) / 255.0


# ------------------------------------------------------------------ easings (math.js ease)

static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := seg(x, a, b)
	return u * u * (3.0 - 2.0 * u)


static func bump(t: float, a: float, b: float) -> float:
	return 0.0 if (t <= a or t >= b) else sin(PI * seg(t, a, b))


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_cubic(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 3.0)


static func in_quad(x: float) -> float:
	return pow(clampf(x, 0.0, 1.0), 2.0)


static func out_quad(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - u) * (1.0 - u)


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


static func out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)


static func in_out_sine(x: float) -> float:
	return -(cos(PI * clampf(x, 0.0, 1.0)) - 1.0) / 2.0


## _lib.js since(): the smallest positive age of an event at t0 in a loop of period D, seen at t
static func since(t: float, t0: float, d: float) -> float:
	return fposmod(t - t0, d)


# ------------------------------------------------------------------ time

## The time the reference draws frame i at: it adds 1 / 30 a frame, so its clock drifts a hair off i / 30 (0.39999...
## at frame 12), which decides the original's `if (t < ...)` beats that fall on a frame.
static func frame_t(i: int) -> float:
	var t := 0.0
	for j in i:
		t += 1.0 / 30.0
	return t


## Key node.prop from f(t) sampled `hz` times a second over [t0, t1] (t1 < 0: to the end). "nearest" keys land on
## the frames (n / 30) the original draws, so each frame shows what the original's does; a sample on a frame reads
## the formula at the reference's own clock for that frame (frame_t).
func keyf(node: Node, prop: String, f: Callable, t0 := 0.0, t1 := -1.0, hz := 30.0, interp := "linear") -> void:
	var end: float = root.duration if t1 < 0.0 else t1
	var keys := []
	var n := int(ceilf((end - t0) * hz - 1e-6))
	for i in n + 1:
		var t := minf(t0 + i / hz, end)
		var fi := roundf(t * 30.0)
		var at := frame_t(int(fi)) if absf(t * 30.0 - fi) < 1e-6 else t
		keys.append([t, f.call(at)])
	key(node, prop, keys, interp)


## Key a shader's `t` uniform to the effect's own seconds (0 .. duration).
func clock(node: CanvasItem, prop := "material:shader_parameter/t") -> void:
	key(node, prop, [[0.0, 0.0], [root.duration, root.duration]])


## A per-frame stepped key: f(frame index, t) at every frame of the effect.
func frames_key(node: Node, prop: String, f: Callable) -> void:
	keyf(node, prop, f, 0.0, -1.0, 30.0, "nearest")


# ------------------------------------------------------------------ light

## The original's p.glow(x, y, r, c, k(t)) keyed from k(t) (and r(t) if given): a soft additive disc.
func glow_fn(name: String, at: Vector2, r: float, c: Color, kf: Callable, rf: Variant = null, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at}
	oo.merge(o, true)
	var reach: float = o.get("reach", r)
	var g := glow(name, reach + 1, {"radius": r, "color": c, "alpha": 0.0}, oo)
	keyf(g, "material:shader_parameter/alpha", kf, o.get("t0", 0.0), o.get("t1", -1.0), o.get("hz", 30.0))
	if rf != null:
		keyf(g, "material:shader_parameter/radius", rf, o.get("t0", 0.0), o.get("t1", -1.0), o.get("hz", 30.0))
	return g


## The original's Lights.add(x, y, r, c, k, life) at t0: a glow shrinking to 55% and dying as (life left)^2.
func light_add(name: String, at: Vector2, r: float, c: Color, k: float, life: float, t0 := 0.0) -> ColorRect:
	var g := glow(name, r + 1, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	var t1 := minf(root.duration, t0 + life + 0.04)
	keyf(g, "material:shader_parameter/alpha", func(t: float) -> float: return 0.0 if t < t0 or t >= t0 + life else k * pow(1.0 - (t - t0) / life, 2.0), maxf(0.0, t0 - 0.04), t1)
	keyf(g, "material:shader_parameter/radius", func(t: float) -> float: return r * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), maxf(0.0, t0 - 0.04), t1)
	return g


## A glowline over a fixed box (lo..hi, radius r): key "material:shader_parameter/a", "/b", "/k".
func glow_path(name: String, lo: Vector2, hi: Vector2, r: float, c: Color, o: Dictionary = {}) -> ColorRect:
	var a := (Vector2(minf(lo.x, hi.x), minf(lo.y, hi.y)) - Vector2(r + 1, r + 1)).floor()
	var b := (Vector2(maxf(lo.x, hi.x), maxf(lo.y, hi.y)) + Vector2(r + 1, r + 1)).ceil()
	var oo := {"at": (a + b) / 2.0}
	oo.merge(o, true)
	return shape(name, sh("glowline"), b - a, {"a": lo, "b": hi, "radius": r, "color": c, "k": o.get("k", 0.0)}, oo)


# ------------------------------------------------------------------ particles

## Start collecting particles: period > 0 for the original's Ghosts (a loop), 0 for its Particles (a one-shot).
func ghosts_begin(period: float) -> void:
	_gh = []
	_gh_n = 0
	_gh_period = period


## The original's Ghosts.add(born, k, x, y, vx, vy, life, col, size, flag) (period > 0), seeded as it seeds them, or
## Particles.spawn at time `born` with its seed (period 0: pass seed from the original's R.next() * 100). col null:
## the kind's own ramp (SMOKE, FIRE). o: layer ("back" / "front": which of the original's draw passes),
## age0 (the sin() terms' clock offset).
func ghost(born: float, k: int, x: float, y: float, vx: float, vy: float, life: float, col: Variant = Color.WHITE, size := 1.0, flag := 0, o: Dictionary = {}) -> void:
	var n := _gh_n
	_gh_n += 1
	var sd: float = o.get("seed", rand([n, 41]) * 100.0)
	if _gh_period > 0.0 and k == STAR:
		var m := ceilf((8.0 * _gh_period) / TAU)
		var f := (TAU * m) / _gh_period - 8.0
		if f < 5.0:
			sd = f + 5.0 * floorf(rand([n, 43]) * 19.0)
	var b := fposmod(born, _gh_period) if _gh_period > 0.0 else born
	var layer: String = o.get("layer", "back" if (k in SOFT_KINDS or flag & PF_BACK) else "front")
	var spec := {"born": b, "k": k, "x": x, "y": y, "vx": vx, "vy": vy, "life": life, "col": col, "size": size, "flag": flag,
		"seed": sd, "age0": o.get("age0", 0.0), "layer": layer, "frames": o.get("frames", 0.0)}
	_gh.append(spec)
	if k == FIRE and flag & PF_SMOKES:
		_fire_smoke(spec)


## A FIRE puff with SMOKES turns into smoke when it dies (_lib.js Ghosts.state): run its flight here, at the
## original's steps, and add the smoke it leaves as a particle of its own from then on.
func _fire_smoke(s: Dictionary) -> void:
	var q := {"x": s.x, "y": s.y, "vx": s.vx, "vy": s.vy}
	var step := 1.0 / 240.0 if _gh_period > 0.0 else 1.0 / 120.0
	var life: float = s.life
	var a := 0.0
	while life > 0.0:
		var dt := step
		var ck: float = a if _gh_period > 0.0 else s.born + a
		q.vy -= 95.0 * dt
		q.vx += sin(ck * 17.0 + s.seed) * 30.0 * dt
		q.vx -= q.vx * 5.0 * dt
		q.vy -= q.vy * 3.2 * dt
		q.x += q.vx * dt
		q.y += q.vy * dt
		a += dt
		life -= dt
	var big: bool = s.flag & PF_BIG
	var r1 := rand([int(s.seed * 7.0), 1])
	var L := 1.3 + r1 if big else 0.8 + r1 * 0.6
	var spec := {"born": fposmod(s.born + a, _gh_period) if _gh_period > 0.0 else s.born + a, "k": SMOKE, "x": q.x, "y": q.y,
		"vx": q.vx * 0.6, "vy": q.vy * 0.6 - 6.0, "life": L, "col": null, "size": s.size * (0.85 if big else 0.7),
		"flag": PF_BIG if big else 0, "seed": s.seed, "age0": a, "layer": "back", "frames": 0.0}
	_gh.append(spec)


## Every particle collected so far becomes emitters, one per kind (and size class, draw pass), each with a light twin
## where the original lights the kind. o: sparks (4 colours, head .. tail), haze (vapour's glow colour), floor (the
## ground's y; none if absent), box ([x0, y0, x1, y1]: dropped outside), prefix, only (a draw pass: "back" or
## "front"), back (override: z behind the stand-in), step (substep, s).
func ghosts(o: Dictionary = {}) -> Array:
	var groups := {}
	var order := []
	var left := []
	for s in _gh:
		if o.has("only") and s.layer != o.only:
			left.append(s)
			continue
		var plain: bool = s.col == null
		var g := "%02d/%d/%s/%d" % [s.k, 1 if (s.k == SMOKE and s.flag & PF_BIG) else 0, s.layer, 1 if plain else 0]
		if not groups.has(g):
			groups[g] = []
			order.append(g)
		groups[g].append(s)
	_gh = left
	# Ghosts.at() looks back a period for a particle that outlives the loop: a copy a period back for each
	if _gh_period > 0.0:
		for g in order:
			var more := []
			for s in groups[g]:
				for w in range(1, int(ceilf(s.life / _gh_period))):
					var c: Dictionary = s.duplicate()
					c.wrap = w
					more.append(c)
			groups[g] += more
	order.sort()
	var out := []
	for g in order:
		var parts: PackedStringArray = g.split("/")
		out.append(_ghost_emitter(int(parts[0]), groups[g], o, parts[1] == "1", parts[2], parts[3] == "1"))
	return out


func _quad(n: int) -> Texture2D:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return asset("_quad%d" % n, img)


func _ghost_emitter(k: int, list: Array, o: Dictionary, big: bool, layer: String, plain: bool) -> GPUParticles2D:
	var names := {SPARK: "Sparks", MOTE: "Motes", STREAK: "Streaks", FLAKE: "Flakes", VAPOUR: "Vapour", DUST: "Dust", STAR: "Stars",
		EMBER: "Embers", SMOKE: "Smoke", FIRE: "Fire", GRIT: "Grit", PIXEL: "Pixels", DEAD: "DeadPixels", BIT: "Bits"}
	_gh_flushed += 1
	var name: String = o.get("prefix", "") + names.get(k, "P%d" % k) + ("Big" if big else "") + ("Back" if layer == "back" else "") + ("Plain" if plain else "")
	if root.has_node(name):
		name += str(_gh_flushed)
	var n := list.size()
	var img := Image.create(n, 4, false, Image.FORMAT_RGBAF)
	var reach := 3.0
	var sp: Array = o.get("sparks", HOT)
	var spc := []
	for c in sp:
		spc.append(c if c is Color else Color(c))
	for i in n:
		var q: Dictionary = list[i]
		img.set_pixel(i, 0, Color(q.x, q.y, q.vx, q.vy))
		img.set_pixel(i, 1, Color(q.life, q.born, q.size, q.seed))
		var c: Color = Color.WHITE if q.col == null else (q.col if q.col is Color else Color(q.col))
		img.set_pixel(i, 2, Color(c.r, c.g, c.b, 1.0))
		img.set_pixel(i, 3, Color(float(int(q.seed * 1000.0)), q.age0, float(q.get("wrap", 0)), q.frames))
		var sz: float = q.size
		match k:
			SPARK:
				reach = 13.0
			MOTE:
				reach = maxf(reach, 16.0 * sz + 4.0 + sz)
				keep_colour(c)
				keep_colour(Color(c.r * 0.55, c.g * 0.55, c.b * 0.55))
			STREAK:
				reach = maxf(reach, 10.0)
				keep_colour(c)
				keep_colour(Color(c.r * 0.6, c.g * 0.6, c.b * 0.6))
			GRIT:
				keep_colour(c)
				keep_colour(Color(c.r * 0.8, c.g * 0.8, c.b * 0.8))
				keep_colour(Color(c.r * 0.7, c.g * 0.7, c.b * 0.7))
			FLAKE:
				keep_colour(c)
				keep_colour(Color(c.r * 0.8, c.g * 0.8, c.b * 0.8))
			STAR:
				reach = maxf(reach, 4.0 + 2.0 * ceilf(sz) + 3.0)
				keep_colour(c)
				keep_colour(Color(c.r * 0.75, c.g * 0.75, c.b * 0.75))
			EMBER:
				reach = maxf(reach, 4.0 + sz + 1.0)
			VAPOUR:
				reach = maxf(reach, sz * 1.5 * 1.8 + 2.0)
				keep_colour(c)
			DUST:
				reach = maxf(reach, sz * 1.5 + 2.0)
				keep_colour(c)
			SMOKE:
				reach = maxf(reach, sz * (1.1 + (0.5 if big else 0.4)) + 3.0)
				keep_colour(c)
			FIRE:
				reach = maxf(reach, sz * 2.4 + 4.0)
			PIXEL:
				reach = 2.0
				keep_colour(c)
			DEAD:
				reach = 4.0
				keep_colour(c)
			BIT:
				reach = 11.0
	var qn := int(ceilf(reach)) * 2
	var data := asset("_" + name.to_snake_case(), img)
	var tex := _quad(qn)
	var soft_ := k in SOFT_KINDS
	var loop_ := _gh_period > 0.0
	var b := Vector4(-1e9, -1e9, 1e9, 1e9)
	if o.has("box"):
		b = Vector4(o.box[0], o.box[1], o.box[2], o.box[3])
	var pp := {"data": data, "kind": float(k), "floor_y": float(o.get("floor", 1e9)), "big": 1.0 if big else 0.0,
		"period": _gh_period, "box": b, "step_s": float(o.get("step", 1.0 / 240.0 if loop_ else 1.0 / 120.0)), "own_clock": loop_}
	var back: bool = o.get("back", layer == "back" and bool(o.get("back_pass_behind", true)))
	var po := {"amount": n, "lifetime": root.duration, "one_shot": not loop_, "explosiveness": 1.0, "local": true, "texture": tex,
		"layer": "soft" if soft_ else "color", "back": back, "process_shader": sh("ghost"), "process_params": pp, "preprocess": 0.0}
	var p := particles(name, po)
	p.interpolate = false
	# placed from the keyed clock: nothing to warm up (a frame's worth keeps the loop check content)
	p.preprocess = 1.0 / 60.0 if loop_ else 0.0
	var pm: ShaderMaterial = p.process_material
	pm.set_shader_parameter("own_clock", loop_)
	key(p, "process_material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	var m := ShaderMaterial.new()
	m.shader = sh("bits")
	var params := {"kind": float(k), "quad": Vector2(qn, qn), "big": 1.0 if big else 0.0, "translucent": soft_, "plain": plain}
	if k == SPARK or k == EMBER:
		for j in 4:
			params["s%d" % j] = spc[mini(j, spc.size() - 1)]
			keep_colour(spc[mini(j, spc.size() - 1)])
	elif k == DEAD:
		params["s0"] = o.get("cool", Color.WHITE)
		keep_colour(params["s0"])
	elif k == BIT:
		var bc: Array = o.get("bit_colours", [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		for j in 4:
			params["s%d" % j] = bc[j]
			keep_colour(bc[j])
	elif k == SMOKE:
		for j in 4:
			params["s%d" % j] = Color(SMOKE_RAMP[j])
			keep_colour(Color(SMOKE_RAMP[j]))
		params["smoke4"] = Color(SMOKE_RAMP[4])
		keep_colour(Color(SMOKE_RAMP[4]))
	elif k == FIRE:
		var fr := PackedColorArray()
		for h in FIRE_RAMP:
			fr.append(Color(h))
			keep_colour(Color(h))
		params["fire"] = fr
	params["data"] = data
	for key_ in params:
		m.set_shader_parameter(key_, params[key_])
	m.resource_name = name
	p.material = m
	if k in [SPARK, MOTE, STREAK, STAR, EMBER, FIRE] or (k == VAPOUR and o.has("haze")):
		var lp := particles(name + "Light", {"amount": n, "lifetime": root.duration, "one_shot": not loop_, "explosiveness": 1.0, "local": true,
			"texture": tex, "layer": "light", "back": back, "preprocess": 0.0})
		lp.interpolate = false
		lp.preprocess = p.preprocess
		lp.seed = p.seed
		lp.process_material = pm
		var lm := ShaderMaterial.new()
		lm.shader = sh("bits_light")
		var lpar := {"data": data, "kind": float(k), "quad": Vector2(qn, qn)}
		if k == SPARK or k == EMBER:
			for j in 3:
				lpar["s%d" % j] = spc[mini(j, spc.size() - 1)]
		elif k == FIRE:
			lpar["fire"] = params["fire"]
		elif k == VAPOUR:
			lpar["haze"] = o.haze if o.haze is Color else Color(o.haze)
		for key_ in lpar:
			lm.set_shader_parameter(key_, lpar[key_])
		lp.material = lm
	return p


# ------------------------------------------------------------------ shapes (src/core/shapes.js)

## shapes.js bolt(): a jagged path from a to b by midpoint displacement, drawing from r as the original does.
static func bolt_path(r: JsRng, x0: float, y0: float, x1: float, y1: float, jag := 0.22, depth := 5) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y1)])
	for d in depth:
		var nx := PackedVector2Array([pts[0]])
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var dx := b.x - a.x
			var dy := b.y - a.y
			var L := sqrt(dx * dx + dy * dy)
			var off := (r.next() * 2.0 - 1.0) * jag * L
			var l1 := L if L != 0.0 else 1.0
			nx.append(Vector2((a.x + b.x) / 2.0 + (-dy / l1) * off, (a.y + b.y) / 2.0 + (dx / l1) * off))
			nx.append(b)
		pts = nx
	return pts


## shapes.js forks(): count branches off a bolt path, each up to len px.
static func fork_paths(r: JsRng, path: PackedVector2Array, count := 3, length := 20.0, jag := 0.3, spread := 0.9) -> Array:
	var out := []
	for k in count:
		var i := 1 + int(floor(r.next() * (path.size() - 2)))
		var p := path[i]
		var q := path[i - 1]
		var a := atan2(p.y - q.y, p.x - q.x) + (-1.0 if r.next() < 0.5 else 1.0) * spread * (0.4 + 0.6 * r.next())
		var l := length * (0.4 + 0.6 * r.next())
		out.append(bolt_path(r, p.x, p.y, p.x + cos(a) * l, p.y + sin(a) * l, jag, 3))
	return out


## The original's p.dot(x, y, c, a) calls worked out at build time and laid on a sprite (colour layer: the dither
## material fades their alpha as the original's dot() does). dots: [[Vector2, Color, alpha], ...] in the effect's
## coordinates; the last on a cell wins. o: back, layer.
func dots_sprite(name: String, list: Array, o: Dictionary = {}) -> Sprite2D:
	var cellmap := {}
	var lo := Vector2i(100000, 100000)
	var hi := Vector2i(-100000, -100000)
	for d in list:
		if float(d[2]) <= 0.0:
			continue
		var c := Vector2i(floori(d[0].x), floori(d[0].y))
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


## sim.js band(): a ring lying on the floor, th px thick, its rim in the ramp's brightest step fading inward, as
## dots (for dots_sprite). keep(angle) picks the half.
static func band_dots(cx: float, cy: float, r: float, sy: float, th: float, k: float, ramp: Array, keep: Callable, hot := false) -> Array:
	var out := []
	var n := ramp.size()
	var m := int(ceil(r * TAU * 1.2))
	for j in m:
		var ang := (j / float(m)) * TAU
		if not keep.call(ang):
			continue
		var o := th
		while o >= 0.0:
			var u := o / th
			var c: Color = (Color.WHITE if hot else ramp[n - 1]) if u < 0.15 else ramp[n - 2] if u < 0.4 else ramp[n - 3] if u < 0.7 else ramp[n - 4]
			out.append([Vector2(cx + cos(ang) * (r - o), cy + sin(ang) * (r - o) * sy), c, k * (1.2 if u < 0.4 else 1.15 - u)])
			o -= 0.5
	return out
