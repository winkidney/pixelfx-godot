# reimagined-from: src/fx/ice/blizzard-vortex.js@bd397bfc79222dfb4c2ecc5268e8a019e175544f
# Blizzard vortex: a swirling snow tornado: wind bands spin up a leaning funnel, flakes and ice crystals orbit in front
# and behind, snow boils at its foot and cold light fills its throat.
# The funnel's body is a translucent shader (its rims and swirl bands, and their light) swaying once a loop. Everything
# carried round it is GPU particles run by a process shader (fx/ice/_helix.gdshader) that places each one on the
# original's helix from its index and the loop's time: wind streaks are dotted arcs, orbiters a head and a tail, the
# far half drawn dim behind, the near half bright in front; soft puffs boil at its foot and a thin cloud spreads off
# its mouth. A snow drift on the floor, cold light in its throat.
extends "res://build/fx/ice/_ice.gd"

const H := 80.0
const TILT := 0.24


func axis(h: float, ph: float) -> float:
	return (5.0 * sin(TAU * ph + h * 0.05) + 1.5 * sin(TAU * ph * 2.0 - h * 0.11)) * (h / H) - 2.0 * (h / H)


func make() -> void:
	var D: float = root.duration
	# a snow drift on the floor, swept round
	var base := {}
	var over := {}
	for x in range(-30, 31):
		var d := absf(x) / 30.0
		var hgt := int(roundf((1.0 - d * d) * (1.5 + jrand([x, 3]) * 1.5)))
		for j in hgt:
			base[Vector2i(x, -j)] = Color.WHITE if j == hgt - 1 else C[5]
		over[Vector2i(x, 0)] = Color(C[6], 1.0 - d * 0.5)
		over[Vector2i(x, 1)] = Color(C[4], 0.8 - d * 0.6)
	bitmap("Drift", base, {"back": true})
	bitmap("DriftEdge", over, {"back": true})
	glow("FloorLight", 42, {"radius": 40, "color": C[4], "alpha": 0.22}, {"at": Vector2(0, -2)})

	var common := {"period": D, "H": H, "tilt": TILT}
	# behind: the far half of the foot's puffs, streaks and orbiters
	helix("FootBack", 2, 12, 1, -1, {"c0": C[5], "disc": 16.0}, {"texture": tex("puff16"), "layer": "soft", "back": true}, common)
	helix("StreaksBack", 0, 58, 16, -1, {"c0": C[5], "c1": C[4], "c2": C[3], "cut": Vector2(0.3, 0.6)}, {"back": true}, common)
	helix("OrbitersBack", 1, 76, 5, -1, {"c0": C[5], "c1": C[4], "c2": C[3]}, {"back": true}, common, 9)

	# the body and the cold light in its throat
	var body := shape("Funnel", load(ICE + "_funnel.gdshader"), Vector2(96, 2 * (H + 8)), {"H": H, "c4": C[4], "c5": C[5], "c6": C[6],
		"translucent": true}, {"at": Vector2(0, 0)})
	loop_t(body)
	var body_light := shape("FunnelLight", load(ICE + "_funnel_light.gdshader"), Vector2(96, 2 * (H + 8)), {"H": H, "c5": C[5]}, {"at": Vector2(0, 0)})
	loop_t(body_light)
	var throat := glow("Throat", 42, {"radius": 40, "color": C[4], "alpha": 0.3}, {"at": Vector2(0, -H * 0.45)})
	var heart := glow("Heart", 20, {"radius": 18, "color": C[5], "alpha": 0.4}, {"at": Vector2(0, -H * 0.15)})
	var foot := glow("FootLight", 12, {"radius": 10, "color": Color.WHITE, "alpha": 0.3}, {"at": Vector2(0, -3)})
	key(throat, "position", sample(func(t): return Vector2(roundf(axis(H * 0.45, t / D)), -H * 0.45)))
	key(heart, "position", sample(func(t): return Vector2(roundf(axis(H * 0.15, t / D)), -H * 0.15)))
	key(foot, "position", sample(func(t): return Vector2(roundf(axis(H * 0.05, t / D)), -3)))
	key(heart, "material:shader_parameter/alpha", sample(func(t): return 0.4 + 0.1 * sin(TAU * t / D * 4.0)))

	# in front: the near half, brighter
	helix("StreaksFront", 0, 58, 16, 1, {"c0": Color.WHITE, "c1": C[6], "c2": C[5], "cut": Vector2(0.15, 0.5)}, {}, common)
	helix("OrbitersFront", 1, 76, 5, 1, {"c0": Color.WHITE, "c1": C[6], "c2": C[4]}, {}, common, 9)
	# the big ones: a plus of pale ice round a white heart, glowing
	helix("BigFront", 1, 76, 1, 1, {"c0": C[6], "c1": C[6], "only_big": true}, {"texture": "plus3"}, common, 9)
	helix("BigHeart", 1, 76, 1, 1, {"c0": Color.WHITE, "c1": Color.WHITE, "only_big": true}, {}, common, 9)
	helix("BigLight", 1, 76, 1, 1, {"c0": Color(C[5], 0.35), "c1": Color(C[5], 0.35), "only_big": true}, {"texture": "glow8", "layer": "light"}, common, 9)
	helix("FootFront", 2, 12, 1, 1, {"c0": C[6], "disc": 16.0}, {"texture": tex("puff16"), "layer": "soft"}, common)
	helix("FootCap", 2, 12, 1, 1, {"c0": Color(Color.WHITE, 0.5), "disc": 16.0, "radius_k": 0.5}, {"texture": tex("puff16"), "layer": "soft"}, common)
	# snow thrown off the mouth, spreading into a thin cloud
	helix("Cloud", 3, 10, 1, 0, {"c0": C[6], "disc": 16.0, "radius_k": 0.8}, {"texture": tex("puff16"), "layer": "soft"}, common)
	helix("CloudLight", 3, 10, 1, 0, {"c0": Color(C[4], 0.33), "disc": 32.0, "radius_k": 1.5}, {"texture": "glow32", "layer": "light"}, common)


## One of the helix emitters: mode (0 streaks, 1 orbiters, 2 foot, 3 cloud), n of them (the original's count over a
## loop, all of them: the shader shows the live ones), segs particles each, side (1 near, -1 far, 0 both).
func helix(name: String, mode: int, n: int, segs: int, side: int, params: Dictionary, o: Dictionary, common: Dictionary, seed_ := -1) -> GPUParticles2D:
	var pr := {"mode": mode, "count": n, "segs": segs, "side": float(side), "seed": float(seed_ if seed_ >= 0 else mode * 3 + 1)}
	pr.merge(common, true)
	pr.merge(params, true)
	for k in ["c0", "c1", "c2"]:
		if pr.has(k):
			keep_colour(pr[k])
	var oo := {"amount": n * segs}
	oo.merge(o, true)
	return formula(name, "helix", pr, oo)
