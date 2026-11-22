# reimagined-from: src/fx/melee/spear-sweep.js@61979356918fe7ac57e415d82b82736b23b4457d
# Spear sweep: A wide low sweep at shin height: a long flat crescent swings from behind the legs round the front, and the wind of it kicks a wake of dust and grit along the floor.
# one-shot, 1.50 s, 216x84 canvas, origin [104.0, 70.0], backdrop ground, stand-in 2
# The crescent is the slash shader (fx/melee/_slash.gdshader) on the original's flat, coned swing, drawn twice: its
# far half behind the stand-in, its near half in front, keyed from its sweep / hold / trail, with light and a dotted
# trace. The wake is the original's own stream of spawns, replayed on GPU particles (fx/melee/_kinds.gdshader): soft
# dust puffs rolling the way the blade goes, grit thrown up, motes off the edge; the tip glints, sparks and piles its
# wake up as it stops.
extends "res://build/fx/melee/_melee.gd"


func make() -> void:
	var st := stone(meta.options.stone)
	var A := swing({"cx": 2.0, "cy": -12.0, "R": 50.0, "sy": 0.2, "k": 0.19, "rot": -0.04, "a0": PI + 0.55, "dir": -1.0,
		"span": PI + 0.35, "W": 19.0, "t0": 0.0, "sweep": 0.13, "hold": 0.05, "trail": 0.3})
	var end := slash_end(A)
	var ep: Vector2 = end.p
	var ed: Vector2 = end.d

	slash("SmearBack", A, -1.0)
	slash("SmearFront", A, 1.0)
	sparkle("Glint", ep, C[5], C[3], func(t: float) -> Array:
		var g: float = t - A.sweep * 0.6
		return [9.0 * out_back(minf(1.0, g / 0.05)) * (1.0 - g / 0.24), 0.55], A.sweep * 0.6, A.sweep * 0.6 + 0.24)
	glow_path("Ride", 37, C[3], func(t: float) -> Array:
		return [on_swing(A, A.R - 5.0, A.span * out_expo(clamp01(t / A.sweep))), 36.0, 0.45 * (1.0 - t / (A.sweep + 0.12))], 0.0, A.sweep + 0.12)

	# the wind under the blade kicks dust up off the floor as it passes, rolling the way it goes: the original's
	# stream, stepped at 120 Hz, each spawn waiting for its moment
	var smoke := []
	var grit := []
	var motes_near := []
	var motes_far := []
	var last_u := 0.0
	var t := 0.0
	var t0 := 1.0 / 120.0
	while t < A.sweep + 0.01:
		t += 1.0 / 120.0
		var U: float = A.span * out_expo(clamp01(t / A.sweep))
		var u := last_u
		while u < U:
			var tr := travel(A, u)
			var p: Vector2 = tr.p
			var d: Vector2 = tr.d
			var near := sin(float(tr.a)) >= 0.0
			var fy := -1.0 if near else -3.0
			var v := R.rf(30, 90)
			var q := sp(p.x, fy - R.rf(0, 2), d.x * v, -R.rf(4, 16), R.rf(0.7, 1.15), st.dust, R.rf(3, 5.5), t - t0 + R.rf(0, 0.05))
			smoke.append(q)
			if R.chance(0.6):
				grit.append(sp(p.x, fy, d.x * R.rf(40, 120) + R.rf(-20, 20), -R.rf(40, 130), R.rf(0.6, 1.0), R.pick([st.light, st.body, st.shade]), 2.0 if R.chance(0.3) else 1.0, t - t0))
			if R.chance(0.35):
				var m := sp(p.x, p.y, d.x * R.rf(40, 100), d.y * 40.0 - R.rf(5, 20), R.rf(0.2, 0.4), C[4] if R.chance(0.5) else C[5], 0.6, t - t0)
				(motes_near if near else motes_far).append(m)
			u += 0.09
		last_u = U
	burst("Wake", SMOKE, t0, smoke, {"back": true})
	burst("MotesFar", MOTE, t0, motes_far, {"back": true})
	burst("Grit", GRIT, t0, grit)
	burst("Motes", MOTE, t0, motes_near)

	# the edge stops: light, sparks off the tip, the wake piles up and rolls on past it
	light_burst("Flash", A.sweep, ep + Vector2(0, -4), 50, C[3], 0.5, 0.35)
	var sparks := []
	for i in 8:
		var a := ed.angle() + R.rf(-0.5, 0.3)
		var v := R.rf(120, 260)
		sparks.append(sp(ep.x, ep.y, cos(a) * v, sin(a) * v - 40.0, R.rf(0.12, 0.3)))
	burst("Sparks", SPARK, A.sweep, sparks)
	var pile := []
	for i in 6:
		pile.append(sp(ep.x + R.rf(-6, 4), -R.rf(1, 4), R.rf(30, 90), -R.rf(4, 14), R.rf(0.9, 1.25), st.dust, R.rf(4.5, 7), R.rf(0, 0.08)))
	burst("Pile", SMOKE_BIG, A.sweep, pile, {"back": true})
