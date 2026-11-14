# Shared by the projectile build scripts (not an effect; the original's src/fx/projectiles/_lib.js): the original's
# own randomness (hash, rand, mulberry32 Rng) so a script can replay its choices (a flash's lobes, a casing's throw),
# keys sampled from its formulas, its easings, wake() (motion in a projectile's frame), the casing's bounces, the
# muzzle-flash lobes (flash_shape() + flash(): fx/projectiles/_flash.gdshader), smoke puffs lit like its cloud()
# (lobes(): _lobe.gdshader), light along a segment (glow_line(): _glowline.gdshader), its sparkle() and flare().
extends "res://addons/pixelfx_particles/core/build.gd"

const PROJ := "res://addons/pixelfx_particles/fx/projectiles/"
const M32 := 0xffffffff
const FPS := 30.0


func pshader(name: String) -> Shader:
	return load(PROJ + "_" + name + ".gdshader")


func pal(name: String) -> PackedColorArray:
	return root.ramps[name]


# ------------------------------------------------------------------ the original's randomness

static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & M32


## core/math.js hash(...ns): a 32-bit hash of integers.
static func jhash(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		var v: int = int(n) & M32
		h = imul(h ^ v, 0x85ebca6b)
		h ^= h >> 13
		h = imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & M32


## core/math.js rand(...ns) in [0, 1).
static func jrand(ns: Array) -> float:
	return jhash(ns) / 4294967296.0


## core/math.js noise(x, seed): smooth value noise in [-1, 1].
static func jnoise(x: float, s: int) -> float:
	var i := floori(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	return lerpf(jrand([i, s]), jrand([i + 1, s]), u) * 2.0 - 1.0


## core/math.js Rng (mulberry32).
class Rng:
	var s := 1

	func _init(seed: int = 1) -> void:
		s = seed & 0xffffffff
		if s == 0:
			s = 1

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xffffffff
		var t := s
		t = _imul(t ^ (t >> 15), t | 1)
		t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xffffffff
		return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	static func _imul(a: int, b: int) -> int:
		a &= 0xffffffff
		b &= 0xffffffff
		return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff

	func range(a: float, b: float) -> float:
		return a + (b - a) * next()

	func int_(a: int, b: int) -> int:
		return floori(self.range(a, b + 1))

	func chance(p: float) -> bool:
		return next() < p

	func sign() -> float:
		return -1.0 if next() < 0.5 else 1.0

	func pick(list: Array) -> Variant:
		return list[floori(next() * list.size())]


## core/math.js rng(...ns): a generator for one particle.
static func rng(ns: Array) -> Rng:
	return Rng.new(jhash(ns))


## projectiles/_lib.js beat(): particle i of n born at i * period / n, each with its own life (life(rng(seed, i, 911)))
## and rng(seed, i). fn(age, life, r, i) for every copy alive at t.
static func beat(t: float, period: float, n: int, seed: int, life: Callable, fn: Callable) -> void:
	for i in n:
		var L: float = life.call(rng([seed, i, 911]))
		var age := fposmod(t - i * period / n + 1e-7, period)
		while age < L:
			fn.call(age, L, rng([seed, i]), i)
			age += period


# ------------------------------------------------------------------ easing, motion

static func seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := seg(x, a, b)
	return u * u * (3.0 - 2.0 * u)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func in_out_sine(x: float) -> float:
	return -(cos(PI * clampf(x, 0.0, 1.0)) - 1.0) / 2.0


static func out_back(x: float, s := 1.70158) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


## _lib.js wake(): where something is `age` s after it was launched from (x, y) at (vx, vy) relative to the still air,
## in the frame of a projectile flying right at V px/s (drag k 1/s toward the air, gravity g). [x, y, vx, vy].
static func wake(x: float, y: float, vx: float, vy: float, age: float, V: float, k: float, g := 0.0) -> Array:
	var e := exp(-k * age)
	var f := (1.0 - e) / k
	var vt := g / k
	return [x + vx * f - V * age, y + vt * age + (vy - vt) * f, vx * e - V, vt + (vy - vt) * e]


## Key node.prop from f(t) sampled `hz` times a second over [t0, t1] (t1 < 0: the whole effect). "nearest" keys sit a
## hair before each frame so a capture at exactly that frame's time gets that frame's value.
func keyf(node: Node, prop: String, f: Callable, t0 := 0.0, t1 := -1.0, hz := 30.0, interp := "linear") -> void:
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


## A GradientTexture1D of raw values (a particle's state for a shader, not colours: no palette entries made).
func raw(values: Array, offsets: Array, smooth_ := false) -> GradientTexture1D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR if smooth_ else Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(values)
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return tex


static func mixc(a: Color, b: Color, k: float) -> Color:
	var c := a.lerp(b, k)
	c.a = 1.0
	return c


# ------------------------------------------------------------------ light

## The original's p.glow(x, y, r, c, k) at `at`: glow() with its alpha (key "material:shader_parameter/alpha").
func light_at(name: String, at: Vector2, r: float, c: Color, k: float, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at}
	oo.merge(o, true)
	return glow(name, r, {"radius": r, "color": c, "alpha": k}, oo)


## The original's p.glowLine(a, b, r, c, k): light round a segment, (1 - d / r)^2 * k (fx/projectiles/_glowline).
## The rect covers lo..hi (px from the origin, the segment's reach by default); key "a", "b", "alpha" to move it.
func glow_line(name: String, a: Vector2, b: Vector2, r: float, c: Color, k: float, o: Dictionary = {}) -> ColorRect:
	var lo: Vector2 = o.get("lo", Vector2(minf(a.x, b.x), minf(a.y, b.y)))
	var hi: Vector2 = o.get("hi", Vector2(maxf(a.x, b.x), maxf(a.y, b.y)))
	lo -= Vector2(r + 2, r + 2)
	hi += Vector2(r + 2, r + 2)
	var sz := (hi - lo).ceil()
	sz = Vector2(sz.x + int(sz.x) % 2, sz.y + int(sz.y) % 2)
	var oo := {"at": ((lo + hi) / 2.0).round()}
	for kk in ["back", "parent"]:
		if o.has(kk):
			oo[kk] = o[kk]
	return shape(name, pshader("glowline"), sz, {"a": a, "b": b, "radius": r, "color": c, "k": k}, oo)


## The original's sparkle(x, y, arm, c, tip): a star glint (arms on the axes, diagonals from 3 px, a white heart) on
## the colour layer; key "material:shader_parameter/arm". Its glow (4 + arm * 2 px) is up to the caller.
func sparkle(name: String, at: Vector2, arm: float, c: Color, tip: Color, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at.floor() + Vector2(0.5, 0.5)}
	oo.merge(o, true)
	return shape(name, pshader("sparkle"), Vector2(23, 23), {"arm": arm, "c": c, "tip": tip, "heart": Color.WHITE}, oo)


## The original's flare(x, y, L, k, ramp): an 8-ray star, white at the heart, then ramp[n - 2], then ramp[n - 3];
## key "material:shader_parameter/len" and "k".
func flare8(name: String, at: Vector2, length: float, k: float, ramp_: PackedColorArray, o: Dictionary = {}) -> ColorRect:
	var oo := {"at": at.floor() + Vector2(0.5, 0.5)}
	oo.merge(o, true)
	var n := ramp_.size()
	return shape(name, pshader("flare"), Vector2(61, 61), {"len": length, "k": k, "white": Color.WHITE, "c_hi": ramp_[n - 2], "c_lo": ramp_[n - 3]}, oo)


# ------------------------------------------------------------------ smoke

## Smoke puffs lit as the original's cloud() lights its merged puffs: a lit crown, shade beneath, tone and density in
## clean steps (fx/projectiles/_lobe.gdshader), on the soft layer. The particle colour carries the puff's state, not a
## colour: alpha its density, red its brightness b (0..1: how far up the smoke ramp), green the fire's light on it
## (0..1: toward the warm ramp). state: [[u, b, warm, a], ...] over its life (raw, linear). R: the smoke ramp dark to
## bright; WR the same lit by fire (as long as R). o as particles(); "radius": [min, max] px at full size.
func lobes(name: String, o: Dictionary, state: Array, R: PackedColorArray, WR: PackedColorArray, lit := 1.0) -> GPUParticles2D:
	var vals := []
	var offs := []
	for s in state:
		offs.append(float(s[0]))
		vals.append(Color(float(s[1]), float(s[2]), 0.0, float(s[3])))
	var r: Array = o.get("radius", [4.0, 6.0])
	var oo := {"layer": "soft", "texture": "glow16", "scale": [float(r[0]) * 2.0 / 16.0, float(r[1]) * 2.0 / 16.0], "ramp": raw(vals, offs, true)}
	oo.merge(o, true)
	oo.erase("radius")
	var p := particles(name, oo)
	var m := ShaderMaterial.new()
	m.shader = pshader("lobe")
	m.set_shader_parameter("translucent", true)
	m.set_shader_parameter("n", R.size())
	m.set_shader_parameter("lit", lit)
	var ra := PackedVector4Array()
	var wa := PackedVector4Array()
	for i in R.size():
		ra.append(Vector4(R[i].r, R[i].g, R[i].b, 1.0))
		wa.append(Vector4(WR[i].r, WR[i].g, WR[i].b, 1.0))
		keep_colour(R[i])
		keep_colour(WR[i])
	m.set_shader_parameter("ramp_cols", ra)
	m.set_shader_parameter("warm_cols", wa)
	p.material = m
	return p


# ------------------------------------------------------------------ muzzle flashes

## _lib.js flashShape(r, f, opts): a muzzle flash's lobes [{off, a, len, wid, core}] from rng r (frame f 2 cooler).
static func flash_shape(r: Rng, f: int, o: Dictionary = {}) -> Array:
	var k := 1.0 if f == 1 else 0.6
	var w := 1.0 if f == 1 else 0.72
	var S: float = o.get("size", 1.0)
	var spike: Array = o.get("spike", [12, 20])
	var diag: Array = o.get("diag", [5, 10])
	var cross: Array = o.get("cross", [3, 6])
	var back: Array = o.get("back", [2, 4.5])
	var core: float = o.get("core", 0.7)
	var L := []
	var a0 := r.range(-0.08, 0.08)
	var l0 := r.range(5.5, 8) * S * k
	var w0 := r.range(2.1, 2.6) * S * w
	L.append({"off": 0.5, "a": a0, "len": l0, "wid": w0, "core": 0.5 * core})
	var a1 := r.range(-0.07, 0.07)
	var l1 := r.range(spike[0], spike[1]) * S * k
	var w1 := r.range(1, 1.3) * S * w
	L.append({"off": 2.0, "a": a1, "len": l1, "wid": w1, "core": 0.35 * core})
	for s: float in [-1.0, 1.0]:
		# each ray's numbers in the original's order: angle, length, width, then the chance it's there
		var a := s * r.range(0.3, 0.8)
		var ln := r.range(diag[0], diag[1])
		var wd := r.range(1.1, 1.5)
		var on := r.chance(0.85)
		var off := r.range(0.5, 2) if on else 0.0
		if on:
			L.append({"off": off, "a": a, "len": ln * S * k, "wid": wd * S * w, "core": 0.25 * core})
		a = s * r.range(1.15, 1.7)
		ln = r.range(cross[0], cross[1])
		wd = r.range(1, 1.3)
		on = r.chance(0.6)
		if on:
			off = r.range(0.5, 2)
			L.append({"off": off, "a": a, "len": ln * S * k, "wid": wd * S * w, "core": 0.25 * core})
		a = s * r.range(2, 2.7)
		ln = r.range(back[0], back[1])
		on = r.chance(0.7) and f == 1
		if on:
			off = r.range(0.5, 2)
			L.append({"off": off, "a": a, "len": ln * S * k, "wid": 1.0 * S * w, "core": 0.25 * core})
	return L


## _lib.js flash(): lobes L at `at` pointing along angle `ang`, coloured C [core, inner, body, rim] by depth, with a
## ragged rim (fx/projectiles/_flash.gdshader, colour layer). Show it for its frame.
func flash(name: String, at: Vector2, ang: float, L: Array, C: Array, seed: int, o: Dictionary = {}) -> ColorRect:
	var ext := 2.0
	var lob := PackedVector4Array()
	var cores := PackedFloat32Array()
	for l in L:
		ext = maxf(ext, float(l.off) + float(l.len) + 2.0)
		lob.append(Vector4(l.off, l.a, l.len, l.wid))
		cores.append(l.core)
	while lob.size() < 24:
		lob.append(Vector4(0, 0, -100, 0))
		cores.append(0.0)
	var e := ceilf(ext + 3.0) * 2.0
	var oo := {"at": at}
	oo.merge(o, true)
	var params := {"lobes": lob, "cores": cores, "count": L.size(), "ang": ang, "ext": ext, "grain": float(seed),
		"c0": C[0], "c1": C[1], "c2": C[2], "c3": C[3]}
	return shape(name, pshader("flash"), Vector2(e, e), params, oo)


# ------------------------------------------------------------------ casings

## _lib.js casing(): a casing thrown from (x, y) at (vx, vy) spinning va, falling under g onto the floor at `fl`,
## bouncing until too slow, then sliding to rest. {x, y, a, rest, hit (s since the last bounce, or -1)}.
static func casing(x: float, y: float, vx: float, vy: float, va: float, age: float, g: float, fl: float, bounce := 0.42, a0 := 0.0) -> Dictionary:
	var t0 := 0.0
	var a := a0
	var hit := -1.0
	for n in 6:
		var d := fl - y
		var T := (-vy + sqrt(maxf(0.0, vy * vy + 2.0 * g * d))) / g
		if age - t0 < T:
			var u := age - t0
			return {"x": x + vx * u, "y": y + vy * u + 0.5 * g * u * u, "a": a + va * u, "rest": false, "hit": hit}
		x += vx * T
		a += va * T
		t0 += T
		hit = age - t0
		var vin := vy + g * T
		y = fl
		if vin * bounce < 45.0:
			var u2 := age - t0
			var kk := 7.0
			var s := (1.0 - exp(-kk * u2)) / kk
			return {"x": x + vx * 0.6 * s, "y": fl, "a": roundf(a / PI) * PI, "rest": true, "hit": hit}
		vy = -vin * bounce
		vx *= 0.55
		va *= 0.6
	return {"x": x, "y": fl, "a": roundf(a / PI) * PI, "rest": true, "hit": hit}
