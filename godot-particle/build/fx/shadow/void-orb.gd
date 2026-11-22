# reimagined-from: src/fx/shadow/void-orb.js@63f0c0f52086f7a1d86b3a36c3e14ee68692ec6a
# Void orb: A black orb hangs in the air, a pale rim crawling round it; a dark vortex winds into it, motes and streaks are pulled in, and light bends round its edge.
# loop, 3.20 s, 168x160 canvas, origin [84.0, 150.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The vortex (veil of dark dust, filaments, lit arm edges), the lensing (Einstein ring, specks smeared into arcs) and
# the orb with its crawling rim are a canvas shader (fx/shadow/_void-orb.gdshader) off the loop's clock, with a light
# pass; the orb's black inside sits above the light layer (the original unlights it). Dust drawn up off the floor,
# motes spiralling in and streaks shot in are GPU particles pulled to the orb; the gulp rings are ring shaders keyed
# from the original's curve; the halos swell with each gulp.
extends "res://build/fx/shadow/_shadow.gd"

const Y := -62.0
const R := 12.0
const VR := 48.0
const D := 3.2
const GULPS := [0.2, 0.68]


static func gulp(t: float) -> float:
	var s := 0.0
	for g in GULPS:
		var w: float = (fposmod(t / D - g + 0.5, 1.0) - 0.5) * D / 0.07
		s += exp(-w * w)
	return s


func make() -> void:
	var white := Color.WHITE
	var pal := [C[0], C[1], C[2], C[3], C[4], C[5], C[6], C[7], white]
	var at := Vector2(0, Y)
	var back := glow("FloorGlow", 54, {"radius": 52, "color": C[4], "alpha": 0.22}, {"at": Vector2(0, -1)})
	keyf(back, "material:shader_parameter/alpha", func(t: float): return 0.22 + 0.1 * gulp(t), 0.0, -1.0, 60.0)

	var sz := Vector2(VR * 2, VR * 2)
	var veil := shape("Veil", shadow_shader("void-orb"), sz, {"pal": pal, "mode": 1.0, "translucent": true}, {"at": at})
	loop_t(veil)
	var fil := shape("Filaments", shadow_shader("void-orb"), sz, {"pal": pal, "mode": 0.0}, {"at": at})
	loop_t(fil)
	var lens := shape("Lensing", shadow_shader("void-orb"), sz, {"pal": pal, "mode": 2.0}, {"at": at})
	loop_t(lens)
	var vl := shape("VortexLight", shadow_shader("void-orb_light"), sz, {"pal": pal}, {"at": at})
	loop_t(vl)

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# dust drawn up off the floor, curving into the orb
	particles("DustPuff", {"layer": "soft", "at": Vector2(0, -1.5), "amount": 3, "lifetime": 0.5, "texture": "disc9",
		"emit": {"box": Vector2(44, 0.2)}, "scale_curve": [[0, 0.4], [1, 1.1]], "color": C[3], "alpha_curve": [[0, 0.4], [1, 0]]})
	var dust := particles("Dust", {"at": at, "amount": 9, "lifetime": 2.0, "texture": "dot1", "life_random": 0.2,
		"emit": {"box": Vector2(44, 0.2)}, "radial": [-34, -28],
		"ramp": gradient([C[5], C[6], C[7]], [0.0, 0.4, 0.75]), "alpha_curve": [[0, 0], [0.12, 1], [1, 1]]})
	dust.process_material.emission_shape_offset = Vector3(0, -1 - Y, 0)
	var dl := twin(dust, {"texture": "glow8", "modulate": Color(C[5], 0.3)})

	# motes swirl in along the arms, faster as they fall
	var mpts := PackedVector2Array()
	for i in 240:
		var th := rng.randf() * TAU
		if sin(th) > 0.75:
			th = -th
		mpts.append(Vector2.from_angle(th) * rng.randf_range(30, 64))
	var motes := particles("Motes", {"at": at, "amount": 14, "lifetime": 1.5, "life_random": 0.25, "texture": "streak4", "align": true,
		"emit": {"points": mpts}, "orbit": [-0.4, -0.22], "radial": [-42, -30],
		"initial": gradient([white, C[7], C[6], C[6], C[5]]), "alpha_curve": [[0, 0], [0.15, 1], [1, 1]]})
	twin(motes, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})

	# streaks shot in from further out
	var spts := PackedVector2Array()
	for i in 200:
		var th := rng.randf() * TAU
		if sin(th) > 0.45:
			th = -th
		spts.append(Vector2.from_angle(th) * rng.randf_range(56, 74))
	var streaks := particles("Streaks", {"at": at, "amount": 2, "lifetime": 0.42, "texture": "streak8", "align": true,
		"emit": {"points": spts}, "radial": [-640, -520], "scale_curve": [[0, 0.3], [1, 1.4]],
		"ramp": gradient([C[6], white], [0.0, 0.5])})
	radial_speed(streaks, -12, -8)
	twin(streaks, {"texture": "glow8", "modulate": Color(C[6], 0.4)})

	# a gulp draws a faint ring in after it
	for i in 2:
		var g0: float = GULPS[i] * D
		var gr := ring("GulpRing%d" % i, VR + 4, {"radius": VR, "thickness": 1.0, "color": C[4], "alpha": 0.0}, {"at": at})
		var gl := ring_light("GulpLight%d" % i, at, VR + 6, VR, 4, C[5], 0.0)
		var uu := func(t: float) -> float: return fposmod(t - g0, D) / 0.4
		keyf(gr, "material:shader_parameter/radius", func(t: float): return R + 2 + (VR - R) * (1 - in_quad(uu.call(t))), 0.0, -1.0, 60.0)
		keyf(gr, "material:shader_parameter/alpha", func(t: float): return 0.35 * (1 - uu.call(t)) if uu.call(t) < 1 else 0.0, 0.0, -1.0, 60.0)
		keyf(gl, "material:shader_parameter/radius", func(t: float): return R + 2 + (VR - R) * (1 - in_quad(uu.call(t))), 0.0, -1.0, 60.0)
		keyf(gl, "material:shader_parameter/alpha", func(t: float): return 0.3 * (1 - uu.call(t)) if uu.call(t) < 1 else 0.0, 0.0, -1.0, 60.0)

	# the orb: the pale rim crawling round, halos, the black inside above the light
	var osz := Vector2(28, 28)
	var rim := shape("Rim", shadow_shader("void-orb"), osz, {"pal": pal, "mode": 3.0}, {"at": at})
	loop_t(rim)
	var h1 := halo("Halo", at, R + 8, R - 0.5, R + 7, C[6], 0.6)
	keyf(h1, "material:shader_parameter/k", func(t: float): return 0.6 + 0.3 * gulp(t), 0.0, -1.0, 60.0)
	var h2 := halo("HaloWide", at, R + 47, R - 0.5, R + 46, C[4], 0.38)
	keyf(h2, "material:shader_parameter/k", func(t: float): return 0.38 + 0.15 * gulp(t), 0.0, -1.0, 60.0)
	var inside := shape("Orb", shadow_shader("void-orb"), osz, {"pal": pal, "mode": 4.0}, {"at": at})
	loop_t(inside)
	over_light(inside)
