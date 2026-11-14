# reimagined-from: src/fx/status/confused.js@127974548645b8685f14f2b8c980cf2f88316fe6
# Confused: Head in a spin: a glowing spiral whirls over the head, question marks pop up round it and bob, the eyes dart left and right.
# loop, 2.40 s, 60x78 canvas, origin [30.0, 70.0], backdrop ground, stand-in 2
# ramp marks: #2a1608 #b0701a #ffd84a #fff4b8
# ramp palette: #1e0f2e #4b2070 #8a3ab0 #c66ae0 #f0a8ff #ffffff
# The spiral is a shader (fx/status/_confused_spiral*.gdshader) keyed with the original's spin and breathing, a
# sparkle riding its tip; the three question marks are the original's shaded icons at three sizes (a strip), popped,
# bobbed and shrunk by its formula, each with a one-shot burst of rays and a flash; glitter flicks off the spiral
# (an emitter); the eyes are a still mark.
extends "res://build/fx/status/_status.gd"

const QS := [
	[".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
	[".####.", "##..##", "....##", "...##.", "..##..", "..##..", "......", "..##..", "..##.."],
	[".#####.", "##...##", "##...##", ".....##", "....##.", "...##..", "...##..", ".......", "...##..", "...##.."],
]
const MARKS := [[-12, -5, 0.0, 2], [12, -8, 0.8, 1], [1, -17, 1.6, 2]]


func make() -> void:
	var D: float = root.duration
	var C := fit("palette", 6)
	var M := fit("marks", 4)
	var cy := AY - 7.0

	# the eyes: dark with a white catchlight
	var ey := {}
	for e in eyes():
		for q in e.px:
			ey[Vector2i(AX + q.x, AY + q.y)] = Color("#17121f")
		ey[Vector2i(AX + e.x0, AY + e.y0)] = WHITE
	pixels("Eyes", ey, {"layer": "prop"})

	glow("HeadGlow", 18, {"radius": 16, "color": C[3], "alpha": 0.22}, {"at": Vector2(0, cy)})
	glow("SpiralGlow", 15, {"radius": 13, "color": C[3], "alpha": 0.28}, {"at": Vector2(0, cy)})
	var sp := shape("Spiral", load(STATUS + "_confused_spiral.gdshader"), Vector2(24, 24),
		{"c1": C[1], "c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5]}, {"at": Vector2(0, cy)})
	var spl := shape("SpiralLight", load(STATUS + "_confused_spiral_light.gdshader"), Vector2(24, 24), {"color": C[3]}, {"at": Vector2(0, cy)})
	var tip := sparkle("Tip", {"color": C[4], "tip": C[3]})
	var rot := []
	var br := []
	var tk := []
	for t in frame_times():
		var b: float = 1.0 + 0.08 * sin(t / D * TAU * 4.0)
		rot.append([t, t / D * TAU * 2.0])
		br.append([t, b])
		var th: float = 1.8 * TAU - t / D * TAU * 2.0
		tk.append([t, Vector2(cos(th) * 7.4 * b, cy + sin(th) * 7.4 * b * 0.9), 2, 0.5])
	for n in [sp, spl]:
		key(n, "material:shader_parameter/rot", rot, "nearest")
		key(n, "material:shader_parameter/breathe", br, "nearest")
	sparkle_keys(tip, tk)

	# glitter flicking off the spiral
	var gl := particles("Glitter", {"at": Vector2(0, cy), "amount": 3, "lifetime": 0.55, "life_random": 0.35, "texture": "dot1",
		"emit": {"ring": [6, 6]}, "radial_speed": [12, 22], "ramp": gradient([C[5], C[4]], [0.0, 0.5]),
		"alpha_curve": [[0, 1], [0.6, 1], [1, 0.2]]})
	gl.scale = Vector2(1, 0.8)
	twin(gl, {"modulate": Color(C[3], 0.35), "texture": "glow8"})

	# the question marks
	var imgs := []
	for q in QS:
		imgs.append(icon_image(bitmap(q), 7, [M[0], M[1], M[2], M[3]]))
	var i := 0
	for m in MARKS:
		var ic := icon_strip("Mark%d" % i, imgs, {"file": "_mark%d" % i})
		var g := glow("MarkGlow%d" % i, 18, {"radius": 12, "color": M[2], "alpha": 0.0})
		var fl := glow("MarkFlash%d" % i, 18, {"radius": 16, "color": M[2], "alpha": 0.0})
		var K := {"v": [], "p": [], "f": [], "gp": [], "gr": [], "ga": [], "fa": []}
		for t in frame_times():
			var age := fposmod(t - m[2], D)
			var u := age / 1.9
			var pop := out_back(clamp01(age / 0.16), 3.0)
			var out := clamp01((u - 0.82) / 0.18)
			var size := maxi(0, int(jround(m[3] * pop * (1.0 - out) + (1.0 if pop > 1.1 else 0.0))))
			var x: float = m[0] + sin(age * 3.3 + m[2]) * 0.8
			var y: float = AY + m[1] + sin(age * 5.0 + m[2] * 3.0) * 1.6 - age * 2.0
			var vis := age <= 1.9 and not (pop < 0.3 or (out > 0.6 and size == 0))
			K.v.append([t, vis])
			K.p.append([t, Vector2(jround(x), jround(y))])
			K.f.append([t, mini(2, size)])
			K.gp.append([t, Vector2(x, y)])
			K.gr.append([t, 10.0 + size * 2.0])
			K.ga.append([t, 0.28 * (1.0 - out) if vis else 0.0])
			K.fa.append([t, 0.45 * (1.0 - age / 0.2) if age < 0.2 and vis else 0.0])
		key(ic, "visible", K.v, "nearest")
		key(ic, "position", K.p, "nearest")
		key(ic, "frame", K.f, "nearest")
		key(g, "position", K.gp, "nearest")
		key(g, "material:shader_parameter/radius", K.gr, "nearest")
		key(g, "material:shader_parameter/alpha", K.ga, "nearest")
		key(fl, "position", K.gp, "nearest")
		key(fl, "material:shader_parameter/alpha", K.fa, "nearest")
		# it pops in with a burst of short rays
		var rays := particles("Rays%d" % i, {"at": Vector2(m[0], AY + m[1]), "amount": 8, "lifetime": 0.2, "one_shot": true,
			"explosiveness": 1.0, "texture": "streak3", "align": true, "emit": {"ring": [4.5, 4.5]}, "radial_speed": [34, 36],
			"initial": gradient([M[2], M[3]]), "alpha_curve": [[0, 1], [1, 0.1]], "preprocess": 0.0})
		emit(rays, m[2] + 0.02)
		i += 1
