# reimagined-from: src/fx/fire/spirit-flame.js
# Spirit flame: a cold blue-teal ghost fire floating in the air: a bright rim round a hollow dark heart, a wave
# climbing its wispy tail, curls breaking off, cold sparks rising.
# The body is the original's inverted layers as emitters drawn in order (a pale rim, a teal band, the dark hollow, a
# pale heart and a white core low down): discs rising slowly at the wave's own speed and tapering into a teardrop.
# Each particle leaves at the slant the climbing wave has where it will be, so the wave climbs the flame with them;
# a keyed sideways pull leans it. Two thin side wisps flicker in and out the same way; bright strands run up the
# hollow in dashes; teal curls break off the tip and thin out (soft); cold sparks twinkle up; a cold slow glow.
extends "res://build/fx/fire/_fire.gd"

const S := 7
## inverted layers: the rim burns brightest, a teal band inside it, a dark hollow heart, a pale core low down
const GHOST := [[1.0, 1.0, 1], [0.8, 0.92, 3], [0.6, 0.78, 6], [0.3, 0.42, 2], [0.14, 0.22, 0]]
## how fast the wave climbs (px/s): the body's particles rise with it
const C := 18.0
## how far up its layer a particle meets the centre line exactly (the tail sways most, so match it high)
const RSTAR := 0.95


func ph(t: float) -> float:
	return t / root.duration


func bob(t: float) -> float:
	return sin(ph(t) * TAU) * 1.5


func lean(t: float) -> float:
	return N(t, 0.67, S + 2) * 3.0


func h0(t: float) -> float:
	return 44.0 * (0.92 + 0.08 * N(t, 1.3, S + 3))


## the wave on the centre line at height r (v = r / h), without the lean
func wave(v: float, r: float, t: float, k := 0.0) -> float:
	var p := ph(t)
	return (sin(r * 0.24 - p * TAU * 2.0 + k) * 2.2 + sin(r * 0.11 - p * TAU + k * 0.5) * 3.2) * v * v


func make() -> void:
	fire_begin()
	var COLD := H[3].lerp(Color.WHITE, 0.15)
	var br := func(t: float) -> float: return 0.9 + 0.1 * N(t, 2.0, S + 4)

	# the glow it casts, cold and slow
	var g1 := glow("Glow", 62, {"radius": 60, "color": COLD, "alpha": 0.36}, {"at": Vector2(0, -16)})
	key(g1, "material:shader_parameter/alpha", sampled(func(t): return 0.36 * br.call(t)))
	key(g1, "position", sampled(func(t): return Vector2(0, bob(t) - 16)))
	var g2 := glow("Glow2", 28, {"radius": 26, "color": H[2], "alpha": 0.2}, {"at": Vector2(0, -20)})
	key(g2, "material:shader_parameter/alpha", sampled(func(t): return 0.2 * br.call(t)))
	key(g2, "position", sampled(func(t): return Vector2(wave(0.5, 20, t) * 0.5, bob(t) - 20)))

	# curls breaking off the tip and drifting up, thinning out
	var curl := gradient([Color(H[4], 0.0), Color(H[4], 0.38), Color(H[4], 0.3), Color(H[5], 0.14), Color(H[5], 0.0)], [0.0, 0.1, 0.4, 0.75, 0.97])
	var curls := particles("Curls", {"layer": "soft", "at": Vector2(0, -33), "amount": 19, "lifetime": 1.45, "randomness": 0.35,
		"texture": "disc9", "emit": {"box": Vector2(4, 9)}, "dir": -90, "spread": 22, "speed": [10, 22], "damping": [4, 8],
		"gravity": Vector2(0, -6), "scale": [0.45, 0.8], "scale_curve": [[0, 0.6], [0.5, 1.0], [1, 1.4]], "ramp": curl,
		"turbulence": {"strength": 2.0, "scale": 2.5, "influence": [0.01, 0.02]}})
	key(curls, "position", sampled(func(t): return Vector2(wave(0.9, 26, t) * 0.5, bob(t) - 33)))
	particles("CurlHearts", {"layer": "soft", "at": Vector2(0, -34), "amount": 10, "lifetime": 1.2, "randomness": 0.35,
		"texture": "disc3", "emit": {"box": Vector2(4, 8)}, "dir": -90, "spread": 22, "speed": [10, 22], "damping": [4, 8],
		"gravity": Vector2(0, -6), "ramp": gradient([Color(H[2], 0.0), Color(H[2], 0.42), Color(H[3], 0.2), Color(H[3], 0.0)], [0.0, 0.1, 0.5, 0.9]),
		"turbulence": {"strength": 2.0, "scale": 2.5, "influence": [0.01, 0.02]}})

	# two thin wisps off the sides, flickering out and curling, then the body
	for side in [[-1.0, -4.0, 2.1, S + 6], [1.0, 4.2, -1.8, S + 7]]:
		var sd: float = side[0]
		var k: float = side[2]
		var sn: int = side[3]
		var len := func(t: float) -> float: return maxf(0.0, 0.25 + 0.55 * N(t, 1.7, sn))
		ghost("Wisp%s" % ("L" if sd < 0 else "R"), Vector2(side[1], -4), 2.4, 0.4,
			func(t: float) -> float: return h0(t) * maxf(0.3, len.call(t)),
			func(v: float, r: float, t: float) -> float: return wave(v, r, t, k) + sd * 6.0 * v * v - sd * 3.0 * sin(v * 5.0 - ph(t) * TAU * 2.0 + (1.0 if sd > 0 else 0.0)) * v,
			func(t: float) -> float: return 1.0 if len.call(t) > 0.12 else 0.0)
	ghost("Body", Vector2.ZERO, 8.6, 0.0, h0, wave, func(_t): return 1.0)

	# bright strands drifting up through the hollow heart, in dashes
	for k in 2:
		var kk := float(k)
		var life := 0.72 * 44.0 / 42.0
		var strand := particles("Strand%d" % k, {"at": Vector2(0, -4), "amount": 34, "lifetime": life, "texture": "dot1",
			"dir": -90, "speed": [42, 42], "color": H[2] if k else H[1]})
		key(strand, "position", sampled(func(t): return Vector2(sin(-ph(t) * TAU * 3.0 + kk * PI) * 2.2, bob(t) - 4.0)))
		var on := []
		for i in int(root.duration * 60.0) + 1:
			var t := i / 60.0
			on.append([t, sin(4.0 * 0.2 - ph(t) * TAU * 4.0 + kk * 2.0) > 0.2])
		key(strand, "emitting", on, "nearest")
		key(strand, "process_material:direction", sampled(func(t):
			var r := 0.4 * 44.0
			var x := wave(0.4, r, t + r / 42.0)
			return Vector3(x / (r / 42.0), -42.0, 0.0).normalized()))

	# light along the body and the pale heart breathing low in it
	for v in [0.2, 0.45, 0.7]:
		var gl := glow("BodyLight%d" % int(v * 100), 14, {"radius": 12, "color": H[2], "alpha": 0.16}, {"at": Vector2(0, -44.0 * v)})
		key(gl, "material:shader_parameter/alpha", sampled(func(t): return 0.16 * br.call(t)))
		key(gl, "position", sampled(func(t): return Vector2(wave(v, 44.0 * v, t), bob(t) - 44.0 * v)))
	var heart := glow("Heart", 11, {"radius": 9, "color": H[1], "alpha": 0.22}, {"at": Vector2(0, -4)})
	key(heart, "material:shader_parameter/alpha", sampled(func(t): return 0.22 + 0.06 * N(t, 3.0, S + 5)))
	key(heart, "position", sampled(func(t): return Vector2(0, bob(t) - 4.0)))

	# cold sparks rising off it, twinkling
	particles("Sparks", {"at": Vector2(0, -16), "amount": 16, "lifetime": 1.35, "randomness": 0.35, "texture": "dot1",
		"emit": {"box": Vector2(7, 12)}, "dir": -90, "spread": 30, "speed": [14, 30], "damping": [6, 12], "gravity": Vector2(0, -8),
		"ramp": gradient([H[0], H[1], H[0], H[1], H[3], Color(H[3], 0.0)], [0.0, 0.15, 0.3, 0.5, 0.75, 0.95]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})
	particles("SparkStars", {"at": Vector2(0, -16), "amount": 3, "lifetime": 0.6, "randomness": 0.3, "texture": "plus3",
		"emit": {"box": Vector2(7, 12)}, "dir": -90, "spread": 30, "speed": [14, 30], "gravity": Vector2(0, -8),
		"ramp": gradient([H[1], H[3], Color(H[3], 0.0)], [0.0, 0.6, 0.95])})
	particles("SparkLights", {"layer": "light", "at": Vector2(0, -16), "amount": 8, "lifetime": 1.35, "randomness": 0.35, "texture": "glow8",
		"emit": {"box": Vector2(7, 12)}, "dir": -90, "spread": 30, "speed": [14, 30], "damping": [6, 12], "gravity": Vector2(0, -8),
		"color": Color(H[2], 0.3), "alpha_curve": [[0, 1], [1, 0]]})


## A ghost tongue rooted at `at` (and bobbing): per layer an emitter of discs rising at the wave's speed C, as wide as
## the layer, tapering to a thin tail. Each particle leaves at the slant the centre line centre(v, r, t) will have
## where it gets to, so the wave climbs with the particles; jit roughens the edges; on(t) switches it.
func ghost(name: String, at: Vector2, w: float, jit: float, hf: Callable, centre: Callable, on: Callable) -> void:
	var k := 0
	for L in GHOST:
		var lw: float = L[0]
		var lh: float = L[1]
		var half := w * lw
		var width := 2.0 * half + 1.0
		var tex := "disc13" if width > 9.0 else "disc9" if width > 5.0 else "disc5" if width > 3.0 else "disc3"
		var ts := float(tex.substr(4).to_int())
		var s := width / ts
		# a stack of discs bulges below its root by about a disc's radius: start each layer that much higher
		var lift := maxf(0.0, half * 0.65 - 0.8)
		var life := maxf(0.2, 44.0 * lh - lift) / C
		var m := 1.1 / width
		var taper := []
		for u in [0.0, 0.05, 0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 0.9, 1.0]:
			var r: float = u * 44.0 * lh
			taper.append([u, maxf(m, pow(1.0 - u, 0.75) * minf(1.0, (r + 1.5) / 4.0))])
		var p := particles("%s%d" % [name, k], {"at": at - Vector2(0, lift), "amount": int(ceil(44.0 * lh * 1.4)) + 4, "lifetime": life,
			"texture": tex, "emit": {"box": Vector2(maxf(0.2, jit), 0.4)}, "dir": -90, "speed": [C, C],
			"scale": [s, s], "scale_curve": taper, "color": H[L[2]]})
		var lh_ := lh
		# the slant: where the centre line will be when the particle is RSTAR up its layer (it rises at C scaled by
		# the flame's height, so it gets there in tau whatever the height)
		var vel := func(t: float) -> Vector2:
			var hh: float = hf.call(t)
			var tau := RSTAR * 44.0 * lh_ / C
			var x: float = centre.call(RSTAR * lh_, RSTAR * lh_ * hh, t + tau)
			return Vector2(x / tau, -C * hh / 44.0)
		key(p, "process_material:direction", sampled(func(t):
			var v: Vector2 = vel.call(t)
			return Vector3(v.x, v.y, 0.0).normalized()))
		key(p, "process_material:initial_velocity_min", sampled(func(t): return vel.call(t).length()))
		key(p, "process_material:initial_velocity_max", sampled(func(t): return vel.call(t).length()))
		# the slow lean: a sideways pull bending the whole flame
		key(p, "process_material:gravity", sampled(func(t): return Vector3(2.0 * lean(t) * C * C / (44.0 * 44.0), 0, 0)))
		key(p, "position", sampled(func(t): return at + Vector2(0, bob(t) - lift)))
		key(p, "emitting", sampled(func(t): return on.call(t) > 0.5), "nearest")
		k += 1


# ------------------------------------------------------------------ the original's own noise (src/core/math.js hash,
# fire/_lib.js noiseFor), so the flame leaps, sways and flickers on the reference's beats

static func _mul32(a: int, b: int) -> int:
	return ((a * (b & 0xffff)) + (((a * (b >> 16)) & 0xffff) << 16)) & 0xffffffff


static func _jhash(a: int, b: int) -> int:
	var h := 0x9e3779b9
	for n in [a, b]:
		h = _mul32(h ^ (n & 0xffffffff), 0x85ebca6b)
		h ^= h >> 13
		h = _mul32(h, 0xc2b2ae35)
		h ^= h >> 16
	return h


func N(t: float, rate: float, s: int, off := 0.0) -> float:
	var D: float = root.duration
	var P := maxi(1, roundi(rate * D))
	var x := t / D * P + off
	var i := floori(x)
	var f := x - i
	var u := f * f * (3.0 - 2.0 * f)
	var a := _jhash(posmod(i, P), s) / 4294967296.0
	var b := _jhash(posmod(i + 1, P), s) / 4294967296.0
	return (a + (b - a) * u) * 2.0 - 1.0
