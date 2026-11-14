# reimagined-from: src/fx/ice/frost-breath.js@0afac88eb09d5e236e07158bedae7b180c9cb55e
# Frost breath: a cone of icy wind blowing right: frost puffs billow out, swell and sink, wind streaks race through,
# ice crystals tumble and glint off a white-hot mouth.
# The gust's body is a shader (noise scrolled one tile a loop through a cone, in four translucent steps, and its
# light); billows behind and brighter puffs in front are soft emitters that swell and sink as they slow, each with a
# lit cap while young and a haze of light; snow, wind streaks (a fading tail and a white head, two emitters on one
# seed) and tumbling crystals stream through; the mouth is two ellipses, three flickering jets and its glow.
extends "res://build/fx/ice/_ice.gd"

const SP := 0.21
const SINK := 9.0


func make() -> void:
	var D: float = root.duration
	var sp := tan(SP) * 1.08
	# the gust's body, and its light
	var gp := {"noise": texture("noise128"), "reach": 170.0, "spread": sp, "sag": 7.0, "contrast": 1.5,
		"c4": C[4], "c5": C[5], "c6": C[6], "c7": C[7], "translucent": true}
	var gust := shape("Gust", load(ICE + "_gust.gdshader"), Vector2(344, 96), gp, {"at": Vector2(0, 0), "back": true})
	loop_t(gust)
	var gl := gp.duplicate()
	gl.erase("translucent")
	var gust_light := shape("GustLight", load(ICE + "_gust_light.gdshader"), Vector2(344, 96), gl, {"at": Vector2(0, 0)})
	loop_t(gust_light)

	# the big slow billows behind: a body, a lit cap while young, a haze of light
	billows("Billow", true, 11, 1.12, SP, [170, 230], 178.0, [0.25, 1.75], 0.75, C[4], C[6])
	# light down the cone
	glow_line("ConeLight", Vector2(4, 0), Vector2(120, 6), 24, C[4], 0.26)
	glow_line("CoreLight", Vector2(2, 0), Vector2(50, 1), 9, C[6], 0.3)
	glow("FarLight", 46, {"radius": 44, "color": C[3], "alpha": 0.16}, {"at": Vector2(60, 4)})
	# brighter puffs in front, smaller and quicker
	billows("Puff", false, 7, 0.82, SP * 0.8, [190, 260], 245.0, [0.19, 1.2], 0.85, C[5], C[7])

	# snow carried along, swaying
	particles("Snow", {"at": Vector2(4, 0), "amount": 14, "lifetime": 0.95, "randomness": 0.3, "texture": "dot1",
		"dir": 0, "spread": rad_to_deg(SP * 1.1), "speed": [120, 190], "damping": [140, 165], "gravity": Vector2(0, SINK * 1.4),
		"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.85, 1], [0.86, 0], [0.9, 1], [0.94, 0], [0.97, 1], [1, 0]],
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})

	# wind streaks: a cool fading tail and a white head on the same particles
	var streak_o := {"at": Vector2(6, 0), "amount": 7, "lifetime": 0.29, "randomness": 0.3, "align": true,
		"emit": {"box": Vector2(0.5, 2)}, "dir": 0, "spread": rad_to_deg(SP * 0.9), "speed": [280, 380], "damping": [260, 300],
		"texture": tex("fade16"), "ramp": gradient([Color(C[6], 1), Color(C[5], 1), Color(C[4], 0.8), Color(C[4], 0.3)], [0.0, 0.3, 0.6, 0.85])}
	var tails := particles("Streaks", streak_o)
	var heads: GPUParticles2D = tails.duplicate()
	heads.name = "StreakHeads"
	root.add_child(heads)
	heads.texture = tex("tip16")
	var hm: ParticleProcessMaterial = tails.process_material.duplicate()
	hm.color_ramp = gradient([Color.WHITE, Color.WHITE, Color(C[6], 0.6)], [0.0, 0.6, 0.85])
	heads.process_material = hm
	heads.seed = tails.seed
	lit_copy(tails, "StreakLight", "glow8", Color(C[5], 0.3), [[0, 1], [1, 0]])

	# ice crystals tumbling through, glinting as they turn
	var crystals := particles("Crystals", {"at": Vector2(5, 0), "amount": 6, "lifetime": 0.78, "randomness": 0.3, "texture": "streak4",
		"dir": 0, "spread": rad_to_deg(SP), "speed": [150, 230], "damping": [150, 190], "gravity": Vector2(0, SINK),
		"angle": [0, 360], "spin": [-860, 860], "color": C[5],
		"alpha_curve": [[0, 1], [0.85, 1], [0.86, 0], [0.9, 1], [0.94, 0], [0.97, 1], [1, 0]]})
	lit_copy(crystals, "CrystalLight", "glow8", Color(C[5], 0.25))

	# the mouth: a white-hot core, a flickering jet of cold
	var jets := []
	for i in 3:
		var dy := (i - 1) * 1.4
		var j := line("Jet%d" % i, PackedVector2Array([Vector2(2.5, dy * 0.5 + 0.5), Vector2(12, dy + 0.5)]), {"width": 1.0,
			"gradient": gradient([Color.WHITE, Color.WHITE, C[6], Color(C[6], 0.5)], [0.0, 0.5, 0.6, 0.8])})
		jets.append(j)
		var pk := []
		for f in int(roundf(D * FPS)) + 1:
			var t := f / FPS
			var ph := t / D
			var n := 0.6 * sin(TAU * ph + i * 2.1) + 0.4 * sin(TAU * ph * 2.0 + i * 1.3 + 0.7)
			var L := 9.0 + 6.0 * n
			pk.append([t, PackedVector2Array([Vector2(2.5, roundf(dy * 0.5) + 0.5), Vector2(2.5 + L, roundf(dy) + 0.5)])])
		key(j, "points", pk, "nearest")
	ring("MouthOuter", 6, {"radius": 4.6, "squash": 3.0 / 4.6, "color": C[6]}, {"at": Vector2(2.5, 0)})
	ring("MouthCore", 4, {"radius": 3.0, "squash": 0.6, "color": Color.WHITE}, {"at": Vector2(2, 0)})
	var g1 := glow("MouthGlow", 26, {"radius": 24, "color": C[5], "alpha": 0.7}, {"at": Vector2(2, 0)})
	var g2 := glow("MouthHot", 10, {"radius": 9, "color": Color.WHITE, "alpha": 0.5}, {"at": Vector2(2, 0)})
	key(g1, "material:shader_parameter/alpha", sample(func(t): return 0.7 * (0.85 + 0.15 * sin(t / D * TAU * 3.0))))
	key(g2, "material:shader_parameter/alpha", sample(func(t): return 0.5 * (0.85 + 0.15 * sin(t / D * TAU * 3.0))))


## Puffs of frost flung out of the mouth that swell as they slow and sink: a body, a lit cap while young (same seed,
## smaller, brighter), and a haze of light. scale: puff16 scale at birth and death; a: the puff's strength (its body
## draws at 0.75 of it: the original's body and denser core together, its cap at 0.7).
func billows(name: String, back: bool, n: int, life: float, sp: float, speed: Array, damp: float, scale: Array, a: float, body: Color, cap: Color) -> void:
	var sc := []
	for i in 9:
		var k := i / 8.0
		sc.append([k, lerpf(scale[0], scale[1], pow(k, 0.75))])
	var al := []
	for i in 9:
		var k := i / 8.0
		al.append(a * pow(1.0 - k, 1.2) * minf(1.0, k * life / 0.08) * (1.0 if k < 0.8 else 0.0))
	var o := {"layer": "soft", "back": back, "at": Vector2(3, 0), "amount": n, "lifetime": life, "randomness": 0.25,
		"texture": tex("puff16"), "emit": {"box": Vector2(0.5, 1)}, "dir": 0, "spread": rad_to_deg(sp), "speed": speed,
		"damping": [damp * 0.9, damp * 1.1], "gravity": Vector2(0, SINK), "scale_curve": sc,
		"ramp": gradient(al.map(func(v): return Color(body, v * 0.75)), range(9).map(func(i): return i / 8.0), true)}
	var p := particles(name + "s", o)
	var caps: GPUParticles2D = p.duplicate()
	caps.name = name + "Caps"
	p.get_parent().add_child(caps)
	caps.seed = p.seed
	var m: ParticleProcessMaterial = p.process_material.duplicate()
	var cs := []
	for i in 9:
		var k := i / 8.0
		cs.append([k, lerpf(scale[0], scale[1], pow(k, 0.75)) * 0.5])
	m.scale_curve = curve(cs, 8.0)
	var ca := []
	for i in 9:
		var k := i / 8.0
		ca.append(Color(cap, 0.7 * al[i] * maxf(0.0, 1.0 - k / 0.55)))
	m.color_ramp = gradient(ca, range(9).map(func(i): return i / 8.0), true)
	caps.process_material = m
	lit_copy(p, name + "Haze", "glow32", Color(C[4], 0.1), [[0, 1], [1, 0]])
