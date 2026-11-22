# reimagined-from: src/fx/melee/uppercut.js@70c719906577a24a1aeb37278a85cc818d1057af
# Uppercut: A crescent rises from the floor past the face, and at the top a comic impact star bursts: bold outline, hot core, burst lines, twinkles and sparks.
# one-shot, 0.85 s, 132x128 canvas, origin [48.0, 110.0], backdrop ground, stand-in 2
# The crescent is the slash shader (fx/melee/_slash.gdshader) on the original's swing, keyed from its sweep / hold /
# trail, with its light and dotted trace; speed lines rise beside it (fx/melee/_lines); the comic star is
# fx/melee/_star.gdshader drawn twice (the ink outline, then the colours), popping, turning and shrinking on the
# original's curves; a ring bursts round it (ring shader), burst lines fly out (Line2Ds keyed per frame); dust off
# the floor, sparks and twinkles are the original's spawns on GPU particles (fx/melee/_kinds.gdshader).
extends "res://build/fx/melee/_melee.gd"


func make() -> void:
	var INK := Color(meta.options.outline)
	var A := swing({"cx": 8.0, "cy": -25.0, "R": 27.0, "sy": 1.0, "rot": 0.0, "a0": 1.08, "dir": -1.0, "span": 2.5, "W": 13.0,
		"t0": 0.02, "sweep": 0.07, "hold": 0.05, "trail": 0.22})
	var top: Vector2 = slash_end(A).p
	var S := top + Vector2(3, -5)
	var HIT: float = A.t0 + A.sweep * 0.8
	var spikes := []
	for i in 10:
		spikes.append([i / 10.0 * TAU + R.rf(-0.12, 0.12) - PI / 2.0, (7.0 if i % 2 else 13.0) + R.rf(0, 4), 2.2 if i % 2 else 3.0])
	var bursts := []
	for i in 8:
		bursts.append([i / 8.0 * TAU + 0.2 + R.rf(-0.15, 0.15), R.rf(15, 18), R.rf(5, 9)])

	# the fist comes up off the floor
	var dust := []
	for i in 4:
		dust.append(sp(18 + R.rf(-4, 4), -1, R.rf(-30, 30), -R.rf(5, 20), R.rf(0.3, 0.55), Color("#6a6080"), R.rf(1.5, 2.6)))
	burst("Dust", DUST, 1.0 / 120.0, dust)

	slash("Smear", A)
	# speed lines rising beside the crescent while it goes up
	var lines := []
	for l in [[A.cx + A.R + 7, -16.0, 18.0], [A.cx + A.R + 11, -30.0, 12.0], [A.cx - 4, -40.0, 10.0]]:
		# the white head runs up 30 px over 0.16 s; the line trails down below it
		lines.append([l[0], l[1], 0.0, -30.0 / 0.16, A.t0, 0.16, l[2], 0.0])
	speed_lines("SpeedLines", lines, Vector2(A.cx - 8, -80), Vector2(A.cx + A.R + 14, 4), 0.5, C[5], C[3])
	glow_path("Ride", 35, C[3], func(t: float) -> Array:
		var u: float = t - A.t0
		return [on_swing(A, A.R - 5.0, A.span * out_expo(clamp01(u / A.sweep))), 34.0, 0.45 * (1.0 - u / (A.sweep + 0.06)) if u > 0.0 else 0.0], A.t0, A.t0 + A.sweep + 0.06)

	# the comic star: pops past full size, holds, then shrinks away turning
	var pop := func(t: float) -> float:
		var q := t - HIT
		var out := 1.0 - smooth(0.16, 0.36, q)
		var sc := out_back(clamp01(q / 0.05), 2.6) * (0.35 + 0.65 * out)
		return sc if sc > 0.08 else 0.0
	impact_star("StarInk", S, spikes, 22, func(t: float) -> Array:
		return [pop.call(t) * 1.12, 1.0, (t - HIT) * 1.2, INK, INK, INK, INK], HIT, HIT + 0.36)
	impact_star("Star", S, spikes, 22, func(t: float) -> Array:
		var q := t - HIT
		return [pop.call(t), 1.0, q * 1.2, Color.WHITE if q < 0.05 else C[6], C[4], C[3], C[2]], HIT, HIT + 0.36)
	glow_path("StarLight", 31, C[4], func(t: float) -> Array: return [S, 30.0, 0.45 * (1.0 - smooth(0.16, 0.36, t - HIT))], HIT, HIT + 0.36)
	# a ring bursts out round the star, white to orange, breaking into dots
	var r0 := HIT + 0.02
	dot_ring("Ring", S, 26, func(t: float) -> Array:
		var k := (t - r0) / 0.22
		var col: Color = Color.WHITE if k < 0.25 else C[5] if k < 0.5 else C[4] if k < 0.75 else C[3]
		return [7.0 + 17.0 * out_cubic(k), maxf(1.0, 2.2 * (1.0 - k)), col, 1.15 - k], r0, r0 + 0.22)
	# burst lines fly out round it
	for i in bursts.size():
		var b: Array = bursts[i]
		var e := Vector2(cos(b[0]), sin(b[0]))
		seg_line("Burst%d" % i, func(t: float) -> Array:
			var k := (t - HIT - 0.02) / 0.18
			var rr: float = b[1] + 10.0 * out_cubic(k)
			return [S + e * rr, S + e * (rr + b[2] * (1.0 - k)), Color.WHITE if k < 0.4 else C[5], 1.1 - k], HIT + 0.02, HIT + 0.2)

	# the hit: light, sparks fanned upward, twinkles round it
	light_burst("Flash", HIT, S, 56, C[4], 0.6, 0.4)
	light_burst("White", HIT, S, 18, Color.WHITE, 0.7, 0.08)
	var sparks := []
	for i in 16:
		var a := -PI / 2.0 + R.rf(-1.6, 1.6)
		var v := R.rf(120, 320)
		sparks.append(sp(S.x, S.y, cos(a) * v, sin(a) * v, R.rf(0.15, 0.45)))
	burst("Sparks", SPARK, HIT, sparks)
	var stars := []
	for i in 6:
		var a := R.rf(0, TAU)
		var d := R.rf(14, 24)
		stars.append(sp(S.x + cos(a) * d, S.y + sin(a) * d, cos(a) * 20, sin(a) * 20 - 10, R.rf(0.25, 0.5), C[5] if R.chance(0.5) else Color.WHITE, R.rf(1.4, 2.6), R.rf(0.04, 0.18)))
	burst("Stars", STAR, HIT, stars)
