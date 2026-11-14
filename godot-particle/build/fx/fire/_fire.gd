# The fire category's shared recipe (the original's src/fx/fire/_lib.js, reimagined with particles): flame tongues
# as layered emitters (a red rim round orange round yellow round a white heart, each layer a stream of shrinking
# discs rising off the root, bent by a keyed sideways pull and leaping with keyed speed), flame puffs and licks off
# the tips, smoke, embers, sparks and the fire's light. Fire build scripts extend this instead of core/build.gd.
extends "res://addons/pixelfx_particles/core/build.gd"

## Tongue layers [width share, height share, step of the hot-first ramp]: red rim, orange, yellow, white heart.
const LAYERS := [[1.0, 1.0, 6], [0.76, 0.86, 4], [0.54, 0.68, 2], [0.3, 0.42, 0]]
## Big tongues: more orange and a smaller white heart.
const BIG_LAYERS := [[1.0, 1.0, 6], [0.8, 0.9, 5], [0.62, 0.78, 4], [0.44, 0.6, 3], [0.26, 0.4, 1], [0.12, 0.22, 0]]
## A step cooler, for flames further back.
const BACK_LAYERS := [[1.0, 1.0, 7], [0.76, 0.86, 5], [0.54, 0.68, 3], [0.3, 0.42, 2]]
const SMOKE1 := Color("#5b5566")
## A tongue's width along its life: a rounded root, then (1 - u)^0.85 to the tip.
const TAPER := [[0.0, 0.55], [0.08, 1.0], [0.3, 0.74], [0.55, 0.5], [0.8, 0.25], [1.0, 0.06]]

## The hot-first ramp: H[0] white .. H[8] smouldering (the palette reversed).
var H := PackedColorArray()
var FPS := 30.0


func fire_begin(ramp_name := "palette") -> void:
	var cols: PackedColorArray = root.ramps[ramp_name]
	H = PackedColorArray()
	for i in cols.size():
		H.append(cols[cols.size() - 1 - i])


# ------------------------------------------------------------------ noise (loops repeat exactly)

static func _hash(i: int, s: int) -> float:
	var x: int = (i * 374761393 + s * 668265263 + 1013904223) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	x = x ^ (x >> 16)
	return float(x & 0xffff) / 65536.0


## Smooth value noise in [-1, 1] repeating every `period` cells.
static func pnoise(x: float, period: int, s: int) -> float:
	var i := floori(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	var a := _hash(posmod(i, period), s)
	var b := _hash(posmod(i + 1, period), s)
	return (a + (b - a) * u) * 2.0 - 1.0


## Noise wobbling about `rate` times a second; on a loop it repeats every duration.
func N(t: float, rate: float, s: int, off := 0.0) -> float:
	if root.loop:
		var P := maxi(1, roundi(rate * root.duration))
		return pnoise(t / root.duration * P + off, P, s)
	return pnoise(t * rate + off, 1 << 20, s)


## The fire's flicker, 0.74 to 1.
func flick(t: float, s: int) -> float:
	return 0.74 + 0.16 * N(t, 7.3, s + 1) + 0.1 * N(t, 19.0, s + 2)


## Keys of f(t) sampled at 30 fps from t0 to t1 (whole effect by default).
func sampled(f: Callable, t0 := 0.0, t1 := -1.0) -> Array:
	var end: float = root.duration if t1 < 0.0 else t1
	var n := maxi(1, int(ceil((end - t0) * FPS)))
	var out := []
	for i in n + 1:
		var t := minf(end, t0 + i / FPS)
		out.append([t, f.call(t)])
	return out


# ------------------------------------------------------------------ flames

## A flame tongue rooted at `at`, h px tall, w px half-width at the root. o: layers, life (s per particle), seed,
## height (Callable t -> height multiplier, keyed as speed), sweep (Callable t -> px the tip is swept sideways),
## back, density (particles per px of height), dir (degrees, default -90: up), parent, emitting.
func tongue(name: String, at: Vector2, h: float, w: float, o: Dictionary = {}) -> Array:
	var layers: Array = o.get("layers", BIG_LAYERS if w > 2.2 else LAYERS)
	var life: float = o.get("life", 0.42)
	var dens: float = o.get("density", 0.9)
	var out := []
	var k := 0
	var d: float = o.get("dir", -90.0)
	var up := Vector2(cos(deg_to_rad(d)), sin(deg_to_rad(d)))
	var side := Vector2(-up.y, up.x)
	for L in layers:
		var lw: float = L[0]
		var lh: float = L[1]
		var c: Color = H[L[2]]
		var len := h * lh
		var half := maxf(0.5, w * lw)
		var tex := "disc9" if half > 2.6 else "disc5" if half > 1.2 else "disc3"
		var tsize := 9.0 if tex == "disc9" else 5.0 if tex == "disc5" else 3.0
		var s := (2.0 * half + 1.0) / tsize
		var v := len / life
		var oo := {"at": at, "amount": maxi(6, int(ceil(len * dens)) + 3), "lifetime": life, "randomness": 0.15,
			"texture": tex, "emit": {"box": Vector2(maxf(0.3, half * 0.3), 0.5)}, "dir": d, "spread": o.get("spread", 4.0),
			"speed": [v * 0.8, v * 1.05], "scale": [s * 0.9, s * 1.1], "scale_curve": o.get("taper", TAPER), "color": c}
		for kk in ["back", "parent", "emitting", "preprocess", "one_shot", "layer"]:
			if o.has(kk):
				oo[kk] = o[kk]
		var p := particles("%s_%d" % [name, k], oo)
		if o.has("height"):
			var hf: Callable = o.height
			key(p, "process_material:initial_velocity_min", sampled(func(t): return v * 0.8 * hf.call(t)))
			key(p, "process_material:initial_velocity_max", sampled(func(t): return v * 1.05 * hf.call(t)))
		if o.has("sweep"):
			var sf: Callable = o.sweep
			var hf2: Callable = o.get("height", func(_t): return 1.0)
			key(p, "process_material:gravity", sampled(func(t):
				var g: Vector2 = side * (2.0 * sf.call(t) * lh / (life * life))
				return Vector3(g.x, g.y, 0.0)))
		out.append(p)
		k += 1
	return out


## The original's burn(): tongues T ([dx, dy, height share, half-width, back?]) from base, HC tall. o: seed, lean,
## life, back, prefix (node names), parent. Returns the tongues ({dx, y, h, w, back, n}) for tip_bits().
func flames(base: Vector2, T: Array, HC: float, o: Dictionary = {}) -> Array:
	var S: int = o.get("seed", 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = S * 77 + 5
	var TT := []
	for i in T.size():
		var tg: Array = T[i]
		TT.append({"dx": tg[0] + rng.randf_range(-0.3, 0.3), "y": tg[1], "h": 2.0 + HC * tg[2] * rng.randf_range(0.92, 1.08),
			"w": tg[3] * rng.randf_range(0.92, 1.08), "back": tg.size() > 4 and tg[4], "n": (S * 7 + i) * 13})
	var lean_k: float = o.get("lean", 0.1)
	var order := []
	for i in TT.size():
		if TT[i].back:
			order.append(i)
	for i in TT.size():
		if not TT[i].back:
			order.append(i)
	for i in order:
		var q: Dictionary = TT[i]
		var n: int = q.n
		var hh: float = q.h
		var dx: float = q.dx
		var height := func(t: float) -> float:
			var leap := maxf(0.0, N(t, 2.6, n + 70) - 0.55) * 1.4
			return (1.0 + 0.25 * N(t, 3.3, n) + leap) * (0.9 + 0.1 * flick(t, S))
		var sweep := func(t: float) -> float:
			return N(t, 2.2, n + 40) * (1.0 + hh * 0.08) + N(t, 0.67, S + 90) * lean_k * hh * 0.9 - clampf(dx * 0.3, -2.5, 2.5)
		var oo := {"height": height, "sweep": sweep, "life": o.get("life", 0.42)}
		if q.back:
			oo.layers = BACK_LAYERS
		for kk in ["back", "parent"]:
			if o.has(kk):
				oo[kk] = o[kk]
		tongue("%sTongue%d" % [o.get("prefix", ""), i], base + Vector2(dx, q.y), hh, q.w, oo)
	return TT


## A light that flickers with the fire: glow() keyed by flick(t) * k.
func fire_glow(name: String, at: Vector2, r: float, c: Color, k: float, S: int, squash := 1.0) -> ColorRect:
	var g := glow(name, r, {"radius": r, "color": c, "alpha": k, "squash": squash}, {"at": at})
	key(g, "material:shader_parameter/alpha", sampled(func(t): return k * flick(t, S)))
	return g


## The fire's light from burn(): a broad warm wash, a light on the flames, a hot heart at the base.
func fire_light(base: Vector2, HC: float, R1: float, G: float, S: int) -> void:
	var GLOW := H[3].lerp(H[4], 0.5).lerp(Color.WHITE, 0.25)
	fire_glow("Wash", base + Vector2(0, -HC * 0.35), R1 * 1.5, GLOW, 0.22 * G, S)
	fire_glow("Light", base + Vector2(0, -HC * 0.75), R1, GLOW, 0.34 * G, S)
	fire_glow("Heart", base + Vector2(0, -HC * 0.2), R1 * 0.32, H[2], 0.2 * G, S)
	fire_glow("Root", base + Vector2(0, -2), 8, H[0], 0.14 * G, S)


func glow_colour() -> Color:
	return H[3].lerp(H[4], 0.5).lerp(Color.WHITE, 0.25)


## Smoke as the original's smokePuff: soft, swelling, thinning. col tints it.
func smoke_ramp(col: Color, a := 0.36) -> GradientTexture1D:
	var c0 := col
	return gradient([Color(c0, 0.0), Color(c0, a), Color(c0.lerp(SMOKE1, 0.5), a * 0.85), Color(SMOKE1.darkened(0.15), a * 0.55), Color(SMOKE1.darkened(0.25), 0.0)],
		[0.0, 0.08, 0.4, 0.75, 0.97])


## Embers' four colours [hot, warm, cool, rim] -> a colour over life (k from 1 to 0) with a flicker-out tail.
func ember_ramp() -> GradientTexture1D:
	return gradient([H[1], H[2], H[4], Color(H[4], 0.5), Color(H[6], 0.0)], [0.0, 0.4, 0.7, 0.85, 0.97])


## Where the tongues' tips are (relative to their base), for what's torn off them.
func tip_points(TT: Array, lift := 3.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in TT:
		pts.append(Vector2(q.dx, q.y - q.h * 0.88 + lift))
	return pts


## Flame puffs and licks torn off the tongues' tips (puffs cool into wisps of smoke). o: puffs, licks (a second per
## tongue), size, back, smoke (false: no wisps), prefix (node names), parent.
func tip_bits(base: Vector2, TT: Array, o: Dictionary = {}) -> void:
	var pre: String = o.get("prefix", "")
	var pts := tip_points(TT)
	var n := TT.size()
	var sz: float = o.get("size", 1.0)
	var oo := {"at": base, "emit": {"points": pts}, "dir": -90}
	for kk in ["back", "parent"]:
		if o.has(kk):
			oo[kk] = o[kk]
	var puffs := {"amount": maxi(3, int(n * float(o.get("puffs", 8)) * 0.24)), "lifetime": 0.24, "randomness": 0.4,
		"texture": "disc3", "spread": 14, "speed": [15, 30], "gravity": Vector2(0, -95), "damping": [10, 20],
		"scale": [0.8 * sz, 1.15 * sz], "scale_curve": [[0, 0.7], [0.15, 1.0], [1, 0.55]],
		"ramp": gradient([H[1], H[2], H[3], H[4], H[5], H[6]], [0.0, 0.12, 0.3, 0.5, 0.7, 0.88])}
	puffs.merge(oo)
	particles(pre + "Puffs", puffs)
	var licks := {"amount": maxi(2, int(n * float(o.get("licks", 4)) * 0.26)), "lifetime": 0.26, "texture": "disc3",
		"spread": 12, "speed": [12, 22], "scale": [1.0 * sz, 1.5 * sz], "scale_curve": [[0, 1.0], [1, 0.55]],
		"ramp": gradient([H[2], H[4], H[5], H[6]], [0.0, 0.3, 0.5, 0.75])}
	licks.merge(oo)
	licks.at = base + Vector2(0, -2)
	particles(pre + "Licks", licks)
	if o.get("smoke", true):
		var wisp := gradient([Color(SMOKE1, 0.0), Color(SMOKE1, 0.28), Color(SMOKE1.darkened(0.2), 0.16), Color(SMOKE1.darkened(0.2), 0.0)], [0.0, 0.15, 0.6, 0.95])
		var sm := {"layer": "soft", "amount": maxi(3, int(n * float(o.get("puffs", 8)) * 0.45 * 0.5)), "lifetime": 1.1,
			"randomness": 0.3, "texture": "disc3", "spread": 18, "speed": [8, 16], "gravity": Vector2(3, -10), "damping": [2, 4],
			"scale": [0.8 * sz, 1.2 * sz], "scale_curve": [[0, 0.8], [1, 1.5]], "ramp": wisp}
		sm.merge(oo)
		sm.at = base + Vector2(0, -6)
		particles(pre + "Wisps", sm)
