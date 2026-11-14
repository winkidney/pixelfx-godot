# reimagined-from: src/fx/melee/scythe-reap.js@9757b43fda2cdacda8d527867172f0a4b7d5899e
# Scythe reap: A slow, huge dark crescent reaps round the front with a pale ghostly edge; it hangs, then tears away from the tail into curling wisps and cold vapour.
# one-shot, 2.10 s, 184x116 canvas, origin [84.0, 98.0], backdrop ground, stand-in 2
# The crescent is fx/melee/_scythe.gdshader on the original's swing (far half behind the stand-in, a step deeper in
# the ramp; near half in front), its head on the original's ease and its ragged tear keyed; light rides it
# (fx/melee/_swing_light). Vapour gathering on the blade, shed by the edge and rising off the tear, the wisps that
# peel away (short curling threads) and their twinkles are the original's streams replayed on GPU particles
# (fx/melee/_kinds.gdshader), behind or in front by where they start; the point glints as it sets off and stops.
extends "res://build/fx/melee/_melee.gd"

const WIND := 0.08
const SWEEP := 0.34
const HANG := 0.14
const TEAR := 0.55
const T0 := WIND
const T1 := WIND + SWEEP
const T2 := T1 + HANG
const T3 := T2 + TEAR


static func head(t: float) -> float:
	return in_out_sine((t - T0) / SWEEP)


func make() -> void:
	var A := swing({"cx": 8.0, "cy": -33.0, "R": 52.0, "sy": 0.6, "k": 0.1, "rot": 0.08, "a0": -0.5, "dir": 1.0, "span": 3.5})
	var W := 21.0
	var st := func(t: float) -> Dictionary:
		var U: float = A.span * head(t)
		var k := smooth(T2, T3, t)
		var on := U >= 0.02 and k < 1.0
		return {"U": U if on else 0.0, "tear": k, "u0": maxf(0.0, k * 1.2 * A.span - 0.3), "u1": U if on else -1.0, "lb": maxf(U, 0.01), "k0": 0.3 if on else 0.0}
	for half in [-1.0, 1.0]:
		var hs := "Back" if half < 0.0 else "Front"
		var ramp := Array(C) if half > 0.0 else [C[0], C[0], C[1], C[2], C[3], C[4], C[5], C[6]]
		var b := swing_shape("Blade" + hs, "scythe", A, {"W": W, "span": A.span, "ramp": ramp}, W, 1.0, half)
		keyd(b, ["U", "tear"], st, 0.0, T3 + 0.02)
		key(b, "material:shader_parameter/late", [[0.0, 0.0], [T1 + 0.004, 1.0]], "nearest")
		var l := swing_shape("BladeLight" + hs, "swing_light", A, {"gr": A.R - 2.0, "gstep": 0.25, "rad": 14.0, "color": C[5], "lin": 1.0, "la": 0.0}, W, 15.0, half)
		keyd(l, ["u0", "u1", "lb", "k0"], st, 0.0, T3 + 0.02)

	# the blade's point glints cold as it sets off and where it stops
	sparkle("Start", on_swing(A, A.R - 3.0, 0.0), C[6], C[5], func(t: float) -> Array:
		return [6.0 * minf(1.0, t / 0.04) * (1.0 - smooth(WIND - 0.02, WIND + 0.05, t)), 0.45], 0.0, WIND + 0.05)
	sparkle("Stop", on_swing(A, A.R - 3.0, A.span), C[6], C[5], func(t: float) -> Array:
		var g := t - T1 + 0.06
		return [9.0 * out_back(minf(1.0, g / 0.06)) * (1.0 - g / 0.3), 0.55], T1 - 0.06, T1 + 0.24)

	# the original's streams, stepped at 120 Hz, each spawn waiting for its moment
	var vap := []
	var wisps := {true: [], false: []}
	var stars := {true: [], false: []}
	var t := 0.0
	var t0 := 1.0 / 120.0
	var last := 0.0
	while t < T3 + 0.02:
		t += 1.0 / 120.0
		var d := t - t0
		if t < WIND and R.chance(0.5):
			var p := on_swing(A, A.R - 4.0, 0.0)
			vap.append(sp(p.x + R.rf(-14, 14), p.y + R.rf(-8, 8), R.rf(-10, 10), R.rf(-6, 6), R.rf(0.3, 0.5), C[5], R.rf(1.5, 2.5), d))
		if t > T0 and t < T1 and R.chance(0.5):
			var tr := travel(A, A.span * head(t) * R.rf(0.75, 1))
			vap.append(sp(tr.p.x, tr.p.y, tr.d.x * 20.0, -R.rf(4, 14), R.rf(0.5, 0.9), C[6], R.rf(2, 3.5), d))
		var k := smooth(T2, T3, t)
		var u := last
		while u < k * 1.15:
			var s := A.duplicate()
			s.R = A.R - R.rf(0, 8)
			var tr := travel(s, minf(1.0, u) * A.span)
			var far := sin(float(tr.a)) < 0.0
			wisps[far].append(sp(tr.p.x, tr.p.y, R.rf(-12, 12), -R.rf(8, 26), R.rf(0.5, 0.9), C[6], 1.0, d))
			if R.chance(0.5):
				vap.append(sp(tr.p.x, tr.p.y, R.rf(-10, 10), -R.rf(6, 18), R.rf(0.55, 0.85), C[5] if R.chance(0.5) else C[4], R.rf(2.5, 4.5), d))
			if R.chance(0.2):
				stars[far].append(sp(tr.p.x + R.rf(-3, 3), tr.p.y + R.rf(-3, 3), 0, -6, R.rf(0.25, 0.5), C[6] if R.chance(0.5) else Color.WHITE, R.rf(0.6, 1.6), d))
			u += 0.022
		last = maxf(last, k * 1.15)
	var thread := [C[6], C[5], C[5], C[3]]
	burst("Vapour", VAPOUR, t0, vap, {"back": true, "haze": C[5]})
	burst("StarsBack", STAR, t0, stars[true], {"back": true})
	burst("WispsBack", WISP, t0, wisps[true], {"back": true, "sparks": thread, "floor": false})
	burst("Stars", STAR, t0, stars[false])
	burst("Wisps", WISP, t0, wisps[false], {"sparks": thread, "floor": false})
