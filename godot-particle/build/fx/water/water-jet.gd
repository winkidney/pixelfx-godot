# reimagined-from: src/fx/water/water-jet.js@8bb38c280df5adefa7909eb8570d03407af4b1b2
# Water jet: A pressurised stream blasts right: a tight glassy rod with surges running down it that swells, roughens, bends under its weight and breaks into chunks, spray and mist.
# loop, 1.00 s, 188x80 canvas, origin [14.0, 32.0], backdrop dark
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The rod is a canvas shader (fx/water/_jet.gdshader): white core banded out to blue edges, streaks and surges
# racing along it, roughening and tearing into chunks toward its end, light down its core. The nozzle flare is
# three ring shaders pulsing and a ring of dots spinning round them. Beads pinch off the end and race on, spray is
# shed off the stream and its end and arcs down, mist blooms off the end (all emitters); light runs down the core.
extends "res://build/fx/water/_water.gd"

const D := 1.0
const G := 520.0
const SPEED := 260.0


func drop(x: float, L: float) -> float:
	return pow(x / L, 2.0) * 9.0


func thick(x: float, L: float) -> float:
	return 2.6 + 5.4 * pow(x / L, 1.1)


func make() -> void:
	var L: float = meta.options.length
	var at := Vector2(62, 4)
	var rod := {"pal": C, "L": L, "speed": SPEED, "seed": float(meta.options.seed), "offset": -at}
	var stream := shape("Stream", water_shader("jet"), Vector2(128, 48), rod, {"at": at})
	loop_t(stream)
	var core := shape("StreamLight", water_shader("jet_light"), Vector2(128, 48), rod, {"at": at})
	loop_t(core)

	# light: down the core, brightest near the nozzle
	var x := 0.0
	while x < L:
		var r := 14.0 + x * 0.1
		glow("Core%d" % int(x), r, {"radius": r, "color": C[4], "alpha": 0.26 * (1.0 - (x / L) * 0.5)}, {"at": Vector2(x, drop(x, L))})
		x += 10.0
	glow("EndLight", 26, {"radius": 26, "color": C[5], "alpha": 0.22}, {"at": Vector2(L * 0.9, drop(L * 0.9, L))})

	# the nozzle flare: a white burst where it leaves, pulsing, ringed with spinning dots, and its light
	var fl := func(t: float) -> float: return 0.85 + 0.15 * sin(t / D * TAU * 6.0)
	var discs := [[4.4, C[5]], [3.4, C[6]], [2.2, C[7]]]
	for i in discs.size():
		var d: Array = discs[i]
		var rr: float = d[0]
		var disc := ring("Flare%d" % i, 6, {"radius": rr, "color": d[1]})
		sample(disc, "material:shader_parameter/radius", func(t: float) -> float: return rr * fl.call(t))
	particles("FlareDots", {"amount": 18, "lifetime": 1.0, "texture": "dot1", "emit": {"ring": [5.2, 5.0]},
		"orbit": [2.0, 2.0], "color": Color(C[5], 0.6)})
	var flare := glow("FlareLight", 24, {"radius": 24, "color": C[5], "alpha": 0.6})
	sample(flare, "material:shader_parameter/alpha", func(t: float) -> float: return 0.6 * fl.call(t))
	var hot := glow("FlareHot", 8, {"radius": 8, "color": C[7], "alpha": 0.4})
	sample(hot, "material:shader_parameter/alpha", func(t: float) -> float: return 0.4 * fl.call(t))

	# where it pinches apart: beads strung out along its end, racing on (a bead and its tail, one seed)
	var beads := {"at": Vector2(L * 0.82, drop(L * 0.82, L)), "amount": 4, "lifetime": 0.21, "emit": {"box": Vector2(1, 1.5)},
		"dir": 3, "spread": 2, "speed": [SPEED, SPEED], "gravity": Vector2(0, 60)}
	var tail := beads.duplicate()
	tail.merge({"texture": "streak4", "align": true, "color": C[3]}, true)
	tail.at = beads.at + Vector2(-2, 0)
	var t_p := particles("BeadTails", tail)
	var head := beads.duplicate()
	head.merge({"texture": "dot2", "initial": gradient([C[6], C[5], C[6], C[4]])}, true)
	var h_p := particles("Beads", head)
	h_p.seed = t_p.seed

	# spray: drops shed off the stream and torn off its end, arcing down
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 64:
		var f := sqrt(rng.randf())
		var x0 := L * (0.3 + 0.7 * f)
		pts.append(Vector2(x0, drop(x0, L) + rng.randf_range(-1.0, 1.0) * thick(x0, L)))
	var spray := gradient([C[7], C[6], C[5], Color(C[5], 0.0)], [0.0, 0.45, 0.75, 0.95])
	particles("Spray", {"amount": 22, "lifetime": 0.31, "randomness": 0.35, "texture": "dot1", "emit": {"points": pts},
		"dir": 4, "spread": 24, "speed": [90, 260], "gravity": Vector2(0, G), "ramp": spray})
	particles("SprayBeads", {"amount": 12, "lifetime": 0.31, "randomness": 0.35, "texture": "streak3", "align": true,
		"emit": {"points": pts}, "dir": 6, "spread": 22, "speed": [110, 240], "gravity": Vector2(0, G),
		"ramp": gradient([C[5], C[4], C[3], Color(C[3], 0.0)], [0.0, 0.4, 0.75, 0.95])})

	# mist blooming off the end
	# (a faint halo: on the light layer, as the soft layer's eight steps would block it out)
	var mist := gradient([Color(C[6], 0.0), Color(C[6], 0.14), Color(C[6], 0.08), Color(C[6], 0.0)], [0.0, 0.15, 0.6, 1.0], true)
	particles("Mist", {"layer": "light", "at": Vector2(L * 0.85, drop(L * 0.85, L)), "amount": 10, "lifetime": 0.85,
		"randomness": 0.3, "texture": "glow32", "emit": {"box": Vector2(L * 0.15, 5)}, "dir": 15, "spread": 15,
		"speed": [20, 45], "scale_curve": [[0, 0.5], [1, 1.4]], "ramp": mist})
