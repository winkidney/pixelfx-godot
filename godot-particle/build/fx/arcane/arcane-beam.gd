# reimagined-from: src/fx/arcane/arcane-beam.js@7ac65ffe9f01a05aba85be08dc31c2c836f0cd33
# Arcane beam: A beam fires right from the hand: a white core, strands twisting round it, pulses running down it, a flaring source and an end that sprays sparks.
# loop, 1.20 s, 264x100 canvas, origin [26.0, 84.0], backdrop ground, stand-in 2
# The beam's body is a canvas shader (fx/arcane/_beam.gdshader: the original's bands, wobble, pulses and strands off
# the loop's clock) under a run of light along it (_glowline); the source and the end are discs (ring shader) whose
# radius flickers on the original's sines, with rays (lines) re-keyed every frame and three shock rings at the end;
# sparks spray off the end and fall to a floor, sparkles and violet vapour hang over it, energy is drawn into the
# hand and motes are shed along the beam.
extends "res://build/fx/arcane/_arcane.gd"

const D := 1.2
const HX := 15.0
const HY := -24.0
const L := 168.0
const W := 6.0
const EX := HX + L


func make() -> void:
	ground()
	var white := Color.WHITE
	# the floor beneath catches the light
	glow("FloorEnd", 31, {"radius": 30, "color": C[5], "alpha": 0.25}, {"at": Vector2(EX, -1)})
	glow("FloorMid", 61, {"radius": 60, "color": C[4], "alpha": 0.12}, {"at": Vector2(HX + L / 2, -1)})

	# the body and its light
	var body := shape("Beam", arcane_shader("beam"), Vector2(L + 4, 24), {"x0": HX, "len": L, "y0": HY, "width": W,
		"c0": white, "c1": C[6], "c2": C[5], "c3": C[4], "c4": C[3], "c5": C[2]}, {"at": Vector2(HX + L / 2, HY)})
	loop_t(body)
	glow_line("BeamLight", Vector2(HX, HY), Vector2(EX, HY), W * 2.2 + 4, C[5], 0.2, 4.0)

	# motes shed along the beam, above and below it, drifting on and away
	for s in [-1, 1]:
		particles("Motes%s" % ("Up" if s < 0 else "Down"), {"at": Vector2(HX + L / 2, HY + s * (W + 1)), "amount": 4,
			"lifetime": 0.6, "texture": "dot1", "emit": {"box": Vector2(L / 2 - 10, 0.5)}, "dir": rad_to_deg(atan2(s * 10.0, 40.0)),
			"spread": 8, "speed": [38, 48], "initial": gradient([C[6], C[5]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})

	# the source: a flickering flare with four spinning rays, energy drawn into the hand
	source()
	var into := particles("Into", {"at": Vector2(HX, HY), "amount": 3, "lifetime": 0.18, "texture": "dot1",
		"emit": {"ring": [19.0, 17.0]}, "ramp": gradient([C[6], white], [0.0, 0.6])})
	radial_speed(into, -90, -85)

	# the end: rays, shock rings, a hot flare, light
	end_flare()
	var sp_ramp := gradient([white, C[6], C[5]], [0.0, 0.4, 0.7])
	# a spark is a short line, its head in the colour of its age and its tail darker (fx/arcane/_spark6.png)
	var sparks := particles("Sparks", {"at": Vector2(EX, HY), "amount": 96, "lifetime": 0.5, "texture": load(ARC + "_spark6.png"), "align": true,
		"dir": -126, "spread": 62, "speed": [70, 260], "gravity": Vector2(0, 480), "damping": [140, 260], "ramp": sp_ramp,
		"collide": {"hide": true, "size": 1}})
	life_rand(sparks, 0.64)
	particles("Sparkles", {"at": Vector2(EX - 4, HY), "amount": 2, "lifetime": 0.3, "texture": "spark7",
		"emit": {"box": Vector2(8, 12)}, "color": C[6], "scale_curve": [[0, 0.3], [0.5, 1.0], [1, 0.3]]})
	var vapour := gradient([Color(C[4], 0.1), Color(C[4], 0.3), Color(C[4], 0.3), Color(C[4], 0.1)], [0.0, 0.2, 0.75, 0.95])
	var vap := particles("Vapour", {"layer": "soft", "at": Vector2(EX - 2, HY - 4), "amount": 7, "lifetime": 1.2, "texture": "glow16",
		"emit": {"box": Vector2(6, 1)}, "dir": -110, "spread": 10, "speed": [14, 22], "scale": [0.85, 1.2],
		"scale_curve": [[0, 0.7], [1, 1.5]], "ramp": vapour})
	life_rand(vap, 0.33)


func source() -> void:
	var flare := group("Source", {"at": Vector2(HX, HY)})
	for i in 4:
		var ray := line("Ray%d" % i, PackedVector2Array([Vector2.ZERO, Vector2(8, 0)]), {"parent": flare,
			"gradient": gradient([Color.WHITE, C[6], Color(C[6], 0.75)], [0.0, 0.5, 0.8])})
		var ii := i
		keyf(ray, "points", func(t: float): return rays_at(t / D * TAU * 2.5 + ii * TAU / 4, 7 + 3 * sin(t / D * TAU * 6 + ii)), 0.0, -1.0, 30.0, "nearest")
	var rims := [[1.5, C[4]], [0.0, C[6]], [-1.0, Color.WHITE]]
	for k in rims.size():
		var r: Array = rims[k]
		var disc := ring("Flare%d" % k, 8, {"radius": 4.2, "color": r[1]}, {"parent": flare})
		var add: float = r[0]
		keyf(disc, "material:shader_parameter/radius", func(t: float):
			var fr := 4.2 + sin(t / D * TAU * 10) * 0.6
			return fr * 0.6 if add < 0.0 else fr + add)
	glow("SourceLight", 33, {"radius": 32, "color": C[5], "alpha": 0.8}, {"at": Vector2(HX, HY)})


## A ray from the centre: a point every px (Line2D colours its gradient per point).
func rays_at(a: float, l: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(2, int(ceilf(l)) + 1)
	for i in n:
		out.append(Vector2(cos(a), sin(a)) * l * i / float(n - 1))
	return out


func end_flare() -> void:
	var end := group("End", {"at": Vector2(EX, HY)})
	var rng := RandomNumberGenerator.new()
	rng.seed = 107
	for i in 7:
		var a := PI + (i - 3) * 0.36
		var ray := line("Ray%d" % i, PackedVector2Array([Vector2.ZERO, Vector2(8, 0)]), {"parent": end,
			"gradient": gradient([Color.WHITE, C[5] if i % 2 else C[6], Color(C[5] if i % 2 else C[6], 0.7)], [0.0, 0.4, 0.8])})
		# a smooth loop of lengths 8..16 (the original's loopNoise)
		var ph0 := rng.randf() * TAU
		var ph1 := rng.randf() * TAU
		keyf(ray, "points", func(t: float):
			var ph := t / D * TAU
			var n := absf(0.6 * sin(ph * 2 + ph0) + 0.4 * sin(ph * 3 + ph1))
			return rays_at(a, 8 + 8 * n), 0.0, -1.0, 30.0, "nearest")
	for k in 3:
		var shock := ring("Shock%d" % k, 20, {"radius": 3, "thickness": 2, "color": Color.WHITE}, {"parent": end})
		var kk := k
		var q := func(t: float): return fposmod(t / D * 3 + kk / 3.0, 1.0)
		keyf(shock, "material:shader_parameter/radius", func(t: float): return 3 + 15 * out_cubic(q.call(t)), 0.0, -1.0, 30.0, "nearest")
		keyf(shock, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 2 * (1 - q.call(t))), 0.0, -1.0, 30.0, "nearest")
		keyf(shock, "material:shader_parameter/alpha", func(t: float): return minf(1.0, 1.1 - q.call(t)), 0.0, -1.0, 30.0, "nearest")
		keyf(shock, "material:shader_parameter/color", func(t: float): return Color.WHITE if q.call(t) < 0.25 else C[5], 0.0, -1.0, 30.0, "nearest")
	var rims := [[1.5, C[4]], [0.0, C[6]], [-1.0, Color.WHITE]]
	for k in rims.size():
		var r: Array = rims[k]
		var disc := ring("Flare%d" % k, 9, {"radius": 5, "color": r[1]}, {"parent": end})
		var add: float = r[0]
		keyf(disc, "material:shader_parameter/radius", func(t: float):
			var ir := 5 + sin(t / D * TAU * 12) * 0.8
			return ir * 0.55 if add < 0.0 else ir + add)
	glow("EndLight", 41, {"radius": 40, "color": C[5], "alpha": 0.9}, {"at": Vector2(EX, HY)})
	glow("EndHot", 13, {"radius": 12, "color": Color.WHITE, "alpha": 0.6}, {"at": Vector2(EX, HY)})
