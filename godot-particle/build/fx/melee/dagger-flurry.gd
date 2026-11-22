# reimagined-from: src/fx/melee/dagger-flurry.js@03a5906d812a90c92533f98713497158a3deb008
# Dagger flurry: A flurry of small quick crescents at every angle in front of the fighter, each with a flick of sparks, finished by one big cut that glints and bursts.
# one-shot, 0.95 s, 148x104 canvas, origin [36.0, 86.0], backdrop ground, stand-in 2
# Six small slashes and the flat finisher are the slash shader (fx/melee/_slash.gdshader) on the original's swings,
# keyed from their sweep / hold / trail, with their light and dotted traces; each cut's end glints, flares light and
# throws sparks and shavings (the original's spawns replayed on GPU particles, fx/melee/_kinds.gdshader); the
# finisher bursts into twinkles and throws slivers off its end (fx/melee/_slivers.gdshader).
extends "res://build/fx/melee/_melee.gd"

const EVERY := 0.055
const CUTS := [[21, -27, -0.5, 1], [33, -16, 0.9, -1], [26, -38, 2.4, 1], [37, -30, -1.8, -1], [19, -17, 0.2, 1], [30, -24, 1.4, -1]]


func make() -> void:
	var all := []
	for i in CUTS.size():
		var c: Array = CUTS[i]
		all.append(swing({"cx": float(c[0]), "cy": float(c[1]), "R": R.rf(12, 15), "sy": R.rf(0.55, 0.75), "rot": c[2], "a0": R.rf(-2.8, -2.2),
			"dir": float(c[3]), "span": R.rf(2.3, 2.8), "W": R.rf(5.2, 6.4), "t0": i * EVERY, "sweep": 0.035, "hold": 0.03, "trail": 0.13}))
	var big := swing({"cx": 24.0, "cy": -26.0, "R": 30.0, "sy": 0.36, "k": 0.24, "rot": 0.12, "a0": 3.0, "dir": -1.0, "span": 2.85,
		"W": 11.0, "t0": CUTS.size() * EVERY + 0.04, "sweep": 0.055, "hold": 0.06, "trail": 0.24})
	all.append(big)
	var sl := []
	for a in [-2.6, -1.5, -0.4, 0.7]:
		sl.append([a + R.rf(-0.2, 0.2), R.rf(4, 7), R.rf(70, 110), R.rf(0.4, 0.7)])

	for i in all.size():
		var s: Dictionary = all[i]
		slash("Cut%d" % i, s)
	for i in all.size():
		var s: Dictionary = all[i]
		var last: bool = i == all.size() - 1
		var e := slash_end(s)
		var ep: Vector2 = e.p
		var ed: Vector2 = e.d
		var t_end: float = s.t0 + s.sweep
		# the glint at the end of each cut
		var life := 0.24 if last else 0.12
		var g0: float = s.t0 + s.sweep * 0.6
		var arm := 10.0 if last else 4.0
		sparkle("Glint%d" % i, ep, C[5], C[3], func(t: float) -> Array:
			var g := t - g0
			return [arm * out_back(minf(1.0, g / 0.04)) * (1.0 - g / life), 0.6 if last else 0.35], g0, g0 + life)
		# light rides each edge while it's moving
		var ride_t: float = s.sweep + 0.1
		glow_path("Ride%d" % i, 41 if last else 23, C[3], func(t: float) -> Array:
			var u: float = t - s.t0
			var h := s.duplicate()
			h.span = s.span * out_expo(clamp01(u / s.sweep))
			return [slash_end(h).p, 40.0 if last else 22.0, (0.5 if last else 0.35) * (1.0 - u / ride_t) if u > 0.0 else 0.0], s.t0, s.t0 + ride_t)
		# as each edge stops: a light, sparks along its way, shavings off its arc
		light_burst("Flash%d" % i, t_end, ep, 56.0 if last else 26.0, C[3], 0.6 if last else 0.4, 0.4 if last else 0.14)
		if last:
			light_burst("White%d" % i, t_end, ep, 16.0, Color.WHITE, 0.7, 0.08)
		var sparks := []
		for k in (12 if last else 3):
			var a := ed.angle() + R.rf(-0.5, 0.5)
			var v := R.rf(100, 340 if last else 220)
			sparks.append(sp(ep.x, ep.y, cos(a) * v, sin(a) * v, R.rf(0.1, 0.35 if last else 0.22)))
		burst("Sparks%d" % i, SPARK, t_end, sparks)
		burst("Shavings%d" % i, MOTE, t_end, shavings(s, 14 if last else 4, [C[4], C[5]]))
		if last:
			var stars := []
			for k in 5:
				stars.append(sp(s.cx + R.rf(-22, 22), s.cy + R.rf(-14, 14), 0, -4, R.rf(0.2, 0.45), C[5] if R.chance(0.5) else Color.WHITE, R.rf(1, 2.2), R.rf(0.05, 0.25)))
			burst("Stars", STAR, t_end, stars)
			# the finisher throws slivers off its end
			var turned := []
			for q in sl:
				turned.append([q[0] + ed.angle(), q[1], q[2], q[3]])
			slivers("Slivers", ep, turned, t_end + 0.02, 0.12, C[6], C[5], C[4])
