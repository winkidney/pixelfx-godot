# reimagined-from: src/fx/shadow/eclipse.js@c2470b8ce9331480f33a35afbda4dbc409ded984
# Eclipse: A black moon over the sun: a breathing pearl corona with long streamers, a thin white rim, and one diamond bead blazing on its edge.
# loop, 4.00 s, 160x144 canvas, origin [80.0, 72.0], backdrop sky
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# ramp pearl: #5a4f8a #a99be0 #e6defa #fffaf2
# The corona, streamers, moon and bead are one canvas shader (fx/shadow/_eclipse.gdshader) run off the loop's clock
# with the original's streamer table, in two passes: the corona and streamers under the light, the moon over it (the
# original unlights it); a light shader (_eclipse_light) gives each streamer its glow line. Stars twinkle as
# particles on the original's star spots; the pearly bloom, the bead's blaze and the halo round the moon are glows.
extends "res://build/fx/shadow/_shadow.gd"

const J := preload("res://build/fx/shadow/_jsrand.gd")
const R := 19.0
const D := 4.0
const BEAD := -0.72


static func breathe(t: float, k: float, ph: float) -> float:
	return sin(TAU * k * t / D + ph)


func make() -> void:
	var Q: PackedColorArray = root.ramps.pearl
	var S := 3
	var white := Color.WHITE
	keep_colour(white)

	# the original's 30 streamers: angle, length, curl, phase
	var streams := PackedVector4Array()
	for i in 30:
		var side := 0.0 if i % 2 else PI
		var spread := (J.rand([i, 1]) - 0.5) * (1.3 if J.rand([i, 2]) < 0.7 else 3.1)
		var a := side + spread
		var eq := absf(cos(a))
		var len := (10.0 + J.rand([i, 3]) * 28.0) * (0.45 + 0.75 * eq)
		streams.append(Vector4(a, len, (J.rand([i, 4]) - 0.5) * 0.00018, J.rand([i, 5]) * TAU))

	# stars twinkling in the sky round it, on the original's spots (each blinks once a loop)
	var pts := PackedVector2Array()
	var life_sum := 0.0
	for i in 26:
		var g := J.rng([S, i, 911])
		g.next()
		var L := g.range(1.2, 2.6)
		var r := J.rng([S, i])
		var p := Vector2(r.range(-78, 78), r.range(-70, 70))
		if p.length() < R + 22:
			continue
		pts.append(p.floor() + Vector2(0.5, 0.5))
		life_sum += L
	var alpha := []
	for k in 11:
		var u := k / 10.0
		alpha.append([u, minf(1.0, sin(PI * u) * 1.2)])
	var stars := particles("Stars", {"amount": maxi(1, int(round(life_sum / D))), "lifetime": 1.9, "texture": "dot1",
		"emit": {"points": pts}, "ramp": gradient([Q[1], white, Q[1]], [0.0, 0.247, 0.753]), "alpha_curve": alpha, "back": true})
	life_rand(stars, 0.35)

	# the outer corona's light: a wide pearly bloom, breathing
	var bloom := glow("Bloom", 80, {"radius": 72, "color": C[4], "alpha": 0.38})
	keyf(bloom, "material:shader_parameter/radius", func(t: float): return 72.0 * (1.0 + 0.08 * breathe(t, 1, 0)))
	var bloom2 := glow("Bloom2", 52, {"radius": 46, "color": Q[1], "alpha": 0.34})
	keyf(bloom2, "material:shader_parameter/radius", func(t: float): return 46.0 * (1.0 + 0.08 * breathe(t, 1, 0)))

	# streamers, corona and bead (colour), their glow lines (light), the moon over the light
	var sz := Vector2(160, 144)
	var params := {"streams": streams, "c0": C[0], "c1": C[1], "c4": C[4], "c5": C[5], "q1": Q[1], "q2": Q[2], "q3": Q[3], "white": white}
	var corona := shape("Corona", shadow_shader("eclipse"), sz, params)
	loop_t(corona)
	var lit := shape("CoronaLight", shadow_shader("eclipse_light"), sz, {"streams": streams, "c4": C[4], "c5": C[5], "q1": Q[1], "q2": Q[2]})
	loop_t(lit)

	# the bead's blaze and the halo hugging the moon
	var bp := Vector2(cos(BEAD), sin(BEAD)) * (R + 0.4)
	var blaze := glow("Blaze", 60, {"radius": 46, "color": Q[2], "alpha": 0.8}, {"at": bp})
	keyf(blaze, "material:shader_parameter/radius", func(t: float): return 46.0 * (0.75 + 0.25 * breathe(t, 2, 1)))
	keyf(blaze, "material:shader_parameter/alpha", func(t: float): return 0.8 * (0.75 + 0.25 * breathe(t, 2, 1)))
	glow("BeadLight", 15, {"radius": 14, "color": white, "alpha": 0.8}, {"at": bp})
	var hl := halo("Halo", Vector2.ZERO, R + 17, R - 0.5, R + 16, Q[2], 0.35)
	keyf(hl, "material:shader_parameter/k", func(t: float): return 0.35 * (1.0 + 0.08 * breathe(t, 1, 0)))

	var mp := params.duplicate()
	mp.mode = 1.0
	var moon := shape("Moon", shadow_shader("eclipse"), Vector2(44, 44), mp)
	loop_t(moon)
	over_light(moon)
