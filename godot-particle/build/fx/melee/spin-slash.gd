# reimagined-from: src/fx/melee/spin-slash.js@59ccca78edd514d81c9f87bbc024d55e660b4a34
# Spin slash: The blade whirls once round the waist on a tilted plane, behind the body and back in front; the closed ring flares white, dissolves into a dotted trace and throws sparks.
# one-shot, 0.80 s, 208x104 canvas, origin [104.0, 84.0], backdrop ground, stand-in 2
# The smear, its echo, the closed ring's flare and the dotted trace are fx/melee/_spin.gdshader on the original's
# tilted, coned swing, each drawn twice: the far half behind the stand-in (deeper in the ramp), the near half in
# front; the edge's turn, each pixel's age and the flare are the original's curves, keyed. Light rides the edge and
# the ring (fx/melee/_swing_light). Shavings peel off the edge as it goes, sparks and twinkles fly as the ring closes:
# the original's spawns replayed on GPU particles (fx/melee/_kinds.gdshader), behind or in front by where they start.
extends "res://build/fx/melee/_melee.gd"

const SW := 0.17
const FLARE := 0.3


static func turn(t: float) -> float:
	return 1.0 - pow(1.0 - clamp01(t / SW), 1.6)


func make() -> void:
	var R0: float = meta.options.radius
	var A := swing({"cx": 0.0, "cy": -17.0, "R": R0, "sy": 0.27, "rot": -0.1, "a0": 0.5, "dir": -1.0, "k": 0.15})
	var E := A.duplicate()
	E.R = R0 * 0.8
	E.k = 0.1
	var W := 16.0
	var WE := 5.0
	var DIM := PackedColorArray([C[0], C[0], C[1], C[2], C[3], C[4], C[5]])
	var t_end := SW + FLARE + 0.06 + 0.4

	for half in [-1.0, 1.0]:
		var hs := "Back" if half < 0.0 else "Front"
		var rp: PackedColorArray = DIM if half < 0.0 else C
		var ramp := []
		for i in 8:
			ramp.append(rp[mini(i, 6)])
		# the swept smear and its echo
		for b in [[E, WE, 0.025, 0.0, "Echo"], [A, W, 0.0, 1.0, "Body"]]:
			var s: Dictionary = b[0]
			var lag: float = b[2]
			var node := swing_shape(b[4] + hs, "spin", s, {"mode": 0.0, "w0": b[1], "rim": b[3], "SW": SW, "ramp": ramp, "n": 7.0}, b[1], 1.0, half)
			keyd(node, ["U", "tt"], func(t: float) -> Dictionary:
				var tt := t - lag
				var on := tt <= SW + 0.02 and TAU * turn(tt) >= 0.02
				return {"U": TAU * turn(tt) if on else 0.0, "tt": tt}, 0.0, SW + 0.06)
		var bl := swing_shape("BodyLight" + hs, "swing_light", A, {"gr": A.R - 5.0, "gstep": 0.35, "rad": 14.0, "color": C[3],
			"lin": 0.0, "age_mode": 1.0, "ap0": SW, "aspan": TAU, "atau": 0.08}, W, 15.0, half)
		keyd(bl, ["u1", "k0", "at"], func(t: float) -> Dictionary:
			return {"u1": TAU * turn(t), "k0": (0.2 if half < 0.0 else 0.3) if t < SW + 0.04 else 0.0, "at": t}, 0.0, SW + 0.06)
		# closed: the ring flares white, swells a little, thins, cools and breaks into dots
		var fl := swing_shape("Flare" + hs, "spin", A, {"mode": 1.0, "SW": SW, "ramp": ramp, "n": 7.0, "th": 0.0, "f": 1.0}, 9.0, 8.0, half)
		var fst := func(t: float) -> Dictionary:
			var f := (t - SW) / FLARE
			var on := t >= SW and f < 1.0
			return {"R": A.R + 6.0 * out_cubic(f) if on else A.R, "th": (9.0 if f < 0.13 else maxf(1.0, 6.0 * pow(1.0 - f, 1.5) + 0.5)) if on else 0.0,
				"f": f if on else 1.0, "fstep": 6.0 if f < 0.13 else 5.0 if f < 0.3 else 4.0 if f < 0.55 else 3.0,
				"k0": 0.32 * (1.0 - f) * (1.0 - f) if on else 0.0, "gr": A.R + 6.0 * out_cubic(f) - 2.0}
		keyd(fl, ["R", "th", "f"], fst, 0.0, SW + FLARE + 0.02)
		key(fl, "material:shader_parameter/fstep", [[0.0, 6.0], [SW + FLARE * 0.13, 5.0], [SW + FLARE * 0.3, 4.0], [SW + FLARE * 0.55, 3.0]], "nearest")
		var fll := swing_shape("FlareLight" + hs, "swing_light", A, {"gstep": 0.35, "u0": 0.0, "u1": TAU, "rad": 14.0, "color": C[4], "lin": 0.0}, 9.0, 22.0, half)
		keyd(fll, ["R", "k0", "gr"], fst, 0.0, SW + FLARE + 0.02)
		# a dotted trace of the blade's path lingers where the ring was, fading
		var tr := swing_shape("Trace" + hs, "spin", A, {"mode": 1.0, "th": 0.0, "f": 1.0, "tr_r": A.R - 0.5, "tr_col": rp[4], "ramp": ramp, "n": 7.0}, 2.0, 2.0, half)
		keyf(tr, "material:shader_parameter/tr_k", func(t: float) -> float: return 1.0 - clamp01((t - SW - 0.06) / 0.4) if t >= SW else 0.0, 0.0, t_end)

	# the blade catches the light as it sets off, and glints again where the ring closes
	var start := on_swing(A, A.R - 3.0, 0.0)
	sparkle("Start", start, C[5], C[3], func(t: float) -> Array: return [7.0 * (1.0 - t / 0.06), 0.5], 0.0, 0.06)
	var tip := on_swing(A, A.R - 3.0, TAU)
	sparkle("Glint", tip, C[5], C[3], func(t: float) -> Array:
		var g := t - SW * 0.85
		return [10.0 * out_back(minf(1.0, g / 0.05)) * (1.0 - g / 0.24), 0.6], SW * 0.85, SW * 0.85 + 0.24)
	# light rides the edge, dimmer and smaller round the far side
	glow_path("Ride", 39, C[3], func(t: float) -> Array:
		var U := TAU * turn(t)
		var far: bool = sin(A.a0 + A.dir * U) < 0.0
		return [on_swing(A, A.R - 5.0, U), 26.0 if far else 38.0, (0.3 if far else 0.5) * (1.0 - smooth(SW - 0.04, SW + 0.05, t))], 0.0, SW + 0.05)

	# shavings peel off the edge as it goes round, flung along its path: the original's stream at 120 Hz
	var near := []
	var far := []
	var last_u := 0.0
	var t := 0.0
	var t0 := 1.0 / 120.0
	while t < SW - 1e-6:
		t += 1.0 / 120.0
		if t >= SW:
			break
		var U := TAU * turn(t)
		var u := last_u
		while u < U:
			var trv := travel(A, u)
			var p: Vector2 = trv.p
			var d: Vector2 = trv.d
			var o := (p - Vector2(A.cx, A.cy)).normalized()
			var v := R.rf(40, 120)
			var q := sp(p.x, p.y, d.x * v + o.x * v * 0.35, d.y * v * 0.6 - R.rf(5, 30), R.rf(0.22, 0.45), C[4 + R.ri(0, 1)], 0.55, t - t0)
			(far if sin(float(trv.a)) < 0.0 else near).append(q)
			u += 0.3
		last_u = U
	burst("ShavingsBack", MOTE, t0, far, {"back": true})
	burst("Shavings", MOTE, t0, near)

	# the ring closes: light, sparks off the edge where it closes and all round its turn, twinkles left hanging
	light_burst("Flash", SW, Vector2(A.cx, A.cy + 4.0), 90, C[3], 0.4, 0.4)
	var end := travel(A, TAU)
	var ep: Vector2 = end.p
	var ed: Vector2 = end.d
	var sparks := []
	for i in 9:
		var a := ed.angle() + R.rf(-0.45, 0.35)
		var v := R.rf(160, 360)
		sparks.append(sp(ep.x, ep.y, cos(a) * v, sin(a) * v - R.rf(20, 70), R.rf(0.14, 0.36)))
	var ring_near := []
	var ring_far := []
	for i in 16:
		var trv := travel(A, R.rf(0, TAU))
		var p: Vector2 = trv.p
		var d: Vector2 = trv.d
		var v := R.rf(110, 260)
		var q := sp(p.x, p.y, d.x * v, d.y * v - R.rf(20, 80), R.rf(0.12, 0.32))
		(ring_far if sin(float(trv.a)) < 0.0 else ring_near).append(q)
	var stars_near := []
	var stars_far := []
	for i in 6:
		var u := R.rf(0, TAU)
		var p := on_swing(A, A.R + R.rf(-1, 3), u)
		var q := sp(p.x, p.y, 0, -R.rf(2, 8), R.rf(0.25, 0.5), C[5] if R.chance(0.5) else Color.WHITE, R.rf(1.2, 2.6), R.rf(0.04, 0.16))
		(stars_far if sin(A.a0 + A.dir * u) < 0.0 else stars_near).append(q)
	burst("SparksBack", SPARK, SW, ring_far, {"back": true})
	burst("StarsBack", STAR, SW, stars_far, {"back": true})
	burst("Sparks", SPARK, SW, sparks + ring_near)
	burst("Stars", STAR, SW, stars_near)
