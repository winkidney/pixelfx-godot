# Shared by shadow/grasping-hands, shadow/shadow-tendrils and shadow/soul-drain (not an effect): the original's own
# randomness (core/math.js hash, rand and the mulberry32 Rng) so a script can replay its choices, and the dark pool
# the hands and tendrils rise from (the lib's floorPool(): fx/shadow/_pool.gdshader, its ripples replayed from the
# original's events), the pool's light, and its breath: soot puffs, motes, vapour, drops splashing out where an arm
# breaks the surface.
extends "res://build/fx/shadow/_shadow.gd"

const M32 := 0xffffffff
const MAX_RIPPLES := 48


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


## core/math.js Rng (mulberry32).
class Rng:
	var s := 1

	func _init(seed_: int = 1) -> void:
		s = seed_ & 0xffffffff
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

	func chance(p: float) -> bool:
		return next() < p

	func sign() -> float:
		return -1.0 if next() < 0.5 else 1.0

	func pick(list: Array) -> Variant:
		return list[floori(next() * list.size())]


## core/particles.js rng(...ns): a generator seeded from a hash.
static func jrng(ns: Array) -> Rng:
	return Rng.new(jhash(ns))


static func out_back_s(x: float, s: float) -> float:
	return out_back(x, s)


static func in_out_cubic(x: float) -> float:
	var u := clampf(x, 0.0, 1.0)
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0


# ------------------------------------------------------------------ the pool

const POOL_HZ := 60.0


## The pool on the floor (fx/shadow/_pool.gdshader), its radius keyed from rx(t), its ripples [[x, t0, life, w], ...]
## and its light: glows = [[y, radius or -1 (r * 1.7 + 12) or -2 (r * 1.15), colour, k], ...] scaled by how open it is.
func pool(big: float, rx: Callable, ripples: Array, glows: Array) -> ColorRect:
	var rip := PackedVector4Array()
	for r in ripples.slice(0, MAX_RIPPLES):
		rip.append(Vector4(r[0], r[1], r[2], r[3]))
	var n := rip.size()
	rip.resize(MAX_RIPPLES)
	var sz := Vector2(ceilf(big * 1.18 + 4) * 2, ceilf((big * 0.17 + 0.6) * 1.18 + 3) * 2)
	var pl := shape("Pool", shadow_shader("pool"), sz, {"pal": [C[0], C[1], C[2], C[3], C[4], C[5], C[6], C[7]], "rx": 0.0, "rip": rip, "rip_n": n},
		{"at": Vector2(0, 0), "back": true})
	keyf(pl, "material:shader_parameter/rx", rx, 0.0, -1.0, POOL_HZ)
	key(pl, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	var i := 0
	for g in glows:
		var mode: float = g[1]
		var top: float = big * 1.7 + 12 if mode == -1.0 else big * 1.15 if mode == -2.0 else mode
		var gl := glow("PoolGlow%d" % i, top + 1, {"radius": top, "color": g[2], "alpha": 0.0}, {"at": Vector2(0, g[0])})
		if mode < 0.0:
			keyf(gl, "material:shader_parameter/radius", func(t: float): return maxf(1.0, rx.call(t) * 1.7 + 12 if mode == -1.0 else rx.call(t) * 1.15), 0.0, -1.0, POOL_HZ)
		var k: float = g[3]
		keyf(gl, "material:shader_parameter/alpha", func(t: float): return k * rx.call(t) / big, 0.0, -1.0, POOL_HZ)
		i += 1
	return pl


## What the pool breathes out while it's open (t0..t1): soot wisps lit from below, motes, vapour, the odd ember.
func pool_breath(big: float, t0: float, t1: float, soot_rate: float, mote_rate: float, vapour_rate: float, ember_rate: float) -> void:
	var s0 := C[3].lerp(C[2], 0.55)
	var s1 := C[2].lerp(C[1], 0.5)
	var soot := gradient([Color(s0.lerp(C[5], 0.4), 0.0), Color(s0.lerp(C[5], 0.4), 0.6), Color(s0, 0.55), Color(s1, 0.35), Color(s1, 0.0)], [0.0, 0.12, 0.4, 0.75, 1.0], true)
	var puffs := particles("Wisps", {"layer": "soft", "back": true, "at": Vector2(0, -2.5), "amount": maxi(2, int(round(soot_rate * 0.8))), "lifetime": 0.8, "life_random": 0.25,
		"texture": "disc9", "emit": {"box": Vector2(big * 0.8, 1.5)}, "dir": -90, "spread": 20, "speed": [14, 30], "gravity": Vector2(0, -18), "drag": 1.4,
		"scale": [0.7, 1.3], "scale_curve": [[0, 0.65], [0.4, 1.1], [1, 1.5]], "ramp": soot, "emitting": false})
	emit(puffs, t0, t1)
	if vapour_rate > 0.0:
		var vap := particles("Vapour", {"layer": "soft", "back": true, "at": Vector2(0, -5), "amount": maxi(2, int(round(vapour_rate * 0.8))), "lifetime": 0.8, "life_random": 0.3,
			"texture": "disc9", "emit": {"box": Vector2(big * 0.7, 3)}, "dir": -90, "spread": 20, "speed": [10, 22], "drag": 4.0,
			"scale": [0.7, 1.3], "scale_curve": [[0, 0.7], [1, 1.4]], "initial": gradient([C[3], C[4]]), "alpha_curve": [[0, 0], [0.2, 0.3], [1, 0]], "emitting": false})
		emit(vap, t0, t1)
	var motes := particles("PoolMotes", {"back": true, "at": Vector2(0, -2), "amount": maxi(2, int(round(mote_rate * 0.75))), "lifetime": 0.9, "life_random": 0.45,
		"texture": "streak3", "align": true, "emit": {"box": Vector2(big * 0.8, 0.5)}, "dir": -90, "spread": 8, "speed": [30, 80], "drag": 0.6,
		"initial": gradient([C[7], C[6], C[6], C[5]]), "alpha_curve": [[0, 1], [0.65, 1], [1, 0]], "emitting": false})
	emit(motes, t0, t1)
	twin(motes, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	if ember_rate > 0.0:
		var emb := particles("PoolEmbers", {"back": true, "at": Vector2(0, -3), "amount": maxi(2, int(round(ember_rate * 0.8))), "lifetime": 1.0, "life_random": 0.4,
			"texture": "dot1", "emit": {"box": Vector2(big * 0.8, 0.5)}, "dir": -90, "spread": 15, "speed": [20, 45], "gravity": Vector2(0, -30), "drag": 1.6,
			"color": C[6], "alpha_curve": [[0, 1], [0.75, 1], [1, 0]], "emitting": false})
		emit(emb, t0, t1)
		twin(emb, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})


## Where a limb breaks the surface: ink drops thrown up (they vanish into the floor), a light.
func splash(name: String, at: Vector2, t0: float, n: int, power: float) -> void:
	var drops := particles(name, {"at": at + Vector2(0, -1), "amount": n, "lifetime": 0.75 if power >= 1.0 else 0.55, "one_shot": true, "explosiveness": 1.0, "texture": "dot1",
		"emit": {"box": Vector2(2, 0.2)}, "dir": -90, "spread": 20, "speed": [90 * power, 230 * power], "gravity": Vector2(0, 760), "drag": 0.4,
		"scale": [1, 1.8], "initial": gradient([C[1], C[1], C[5]]), "collide": {"hide": true}, "emitting": false})
	emit(drops, t0)
	var l := glow(name + "Light", 31, {"radius": 30, "color": C[5], "alpha": 0.0}, {"at": at + Vector2(0, -7)})
	keyf(l, "material:shader_parameter/radius", func(t: float): return 30 * (0.6 + 0.4 * (1 - seg(t, t0, t0 + 0.25))), t0, t0 + 0.25, POOL_HZ)
	keyf(l, "material:shader_parameter/alpha", func(t: float): return 0.6 * power * pow(1 - seg(t, t0, t0 + 0.25), 2) if t >= t0 else 0.0, t0 - 1 / POOL_HZ, t0 + 0.27, POOL_HZ)


## A tentacle (mode 0) or an arm with its hand (mode 1) on fx/shadow/_pool_limb.gdshader, with its light pass:
## `fixed` are its constant uniforms (x0, surf, len, wid, lam, om, ph, curl, curve, t0), `keyed` maps a uniform to
## f(t), sampled over [on, off]. cols: the 8 colours it's drawn in (the dimmed ramp for the back row).
func limb(name: String, mode: int, fixed: Dictionary, keyed: Dictionary, on: float, off: float, cols: Array, back: bool) -> ColorRect:
	var reach: float = fixed.len + 14.0
	var sz := Vector2(reach * 2 + 8, reach + 12)
	var at := Vector2(round(fixed.x0), round(fixed.surf - reach / 2.0 + 2))
	var pr := fixed.duplicate()
	pr.mode = mode
	for i in 8:
		pr["c%d" % i] = cols[i]
	pr.white = Color.WHITE
	var n := shape(name, shadow_shader("pool_limb"), sz, pr, {"at": at, "back": back})
	var ln := shape(name + "Light", shadow_shader("pool_limb_light"), sz, pr, {"at": at})
	for node in [n, ln]:
		for k in keyed:
			keyf(node, "material:shader_parameter/" + k, keyed[k], on, off, POOL_HZ)
		key(node, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
		show(node, on, off)
	return n
