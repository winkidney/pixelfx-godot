# reimagined-from: src/fx/arcane/portal.js@ddd71b9bd069b29ec4fb839fb5c2e200815794bb
# Portal: An upright rift: fibrous spiral arms wind down into the dark, a lit rim wobbles, motes and streaks are pulled in, the floor glows.
# loop, 2.40 s, 152x116 canvas, origin [76.0, 106.0], backdrop ground, stand-in 0
# The rift is a canvas shader (fx/arcane/_portal.gdshader: the original's rim, arms, knots and tunnel rings in dithered
# ramp steps, off the loop's clock) with a light pass for its rim; specks sink round the well and motes ride round the
# rim (emitters in a group squashed to the oval, orbiting); motes and streaks are pulled in from round about, grit
# skates in along the floor (particles); light pools round the rim, two hot spots chase round it, the floor is lit.
extends "res://build/fx/arcane/_arcane.gd"

const D := 2.4
const RX := 17.0
const RY := 29.0
const CY := -34.0


func pulse(t: float) -> float:
	return 0.85 + 0.15 * sin(t / D * TAU * 2)


func make() -> void:
	# the floor: a lit line under it, brightest in the middle
	for row in 2:
		var cols := []
		var offs := []
		var pts := PackedVector2Array()
		for x in range(-36, 37):
			var u := absf(x + 0.5) / 36.0
			pts.append(Vector2(x, row + 0.5))
			offs.append((x + 36) / 72.0)
			if row == 0:
				cols.append(Color(Color.WHITE if u < 0.2 else C[6] if u < 0.5 else C[5], 1.0 if u < 0.55 else 1.0 - (u - 0.55) / 0.45))
			else:
				cols.append(Color(C[5] if u < 0.15 else C[4], (1.0 if u < 0.15 else 0.5) if u < 0.3 else 0.0))
		pts.append(Vector2(37, row + 0.5))
		offs.append(1.0)
		cols.append(cols[-1])
		var fl := line("Floor%d" % row, pts, {"gradient": gradient(cols, offs), "back": true})
		if row == 0:
			keyf(fl, "modulate:a", func(t: float): return 0.8 + 0.2 * pulse(t))

	# light: a big soft pool, a halo hugging the rim, the hot spots, the floor
	var pool := glow("Pool", RY * 5 + 1, {"radius": RY * 5, "color": C[4], "alpha": 0.17}, {"at": Vector2(0, CY)})
	keyf(pool, "material:shader_parameter/alpha", func(t: float): return 0.17 * pulse(t))
	var pool2 := glow("Pool2", RY * 2.6 + 1, {"radius": RY * 2.6, "color": C[4], "alpha": 0.1}, {"at": Vector2(0, CY)})
	keyf(pool2, "material:shader_parameter/alpha", func(t: float): return 0.1 * pulse(t))
	var halo := group("Halo")
	for i in 16:
		var th := i / 16.0 * TAU
		var h := glow("Halo%d" % i, 16, {"radius": 15, "color": C[4], "alpha": 0.15}, {"parent": halo, "at": Vector2(cos(th) * 1.08 * RX, CY + sin(th) * 1.08 * RY)})
		keyf(h, "material:shader_parameter/alpha", func(t: float): return 0.15 * pulse(t))
	for k in 2:
		var spot := glow("Spot%d" % k, 17, {"radius": 16, "color": C[6], "alpha": 0.42}, {"at": Vector2(0, CY)})
		var off := k * PI - 0.6
		keyf(spot, "position", func(t: float):
			var th := t / D * TAU * 2 + off
			return Vector2(cos(th) * RX, CY + sin(th) * RY))
	var floor_light := glow_line("FloorLight", Vector2(-21, -1), Vector2(21, -1), 16, C[5], 0.12, 7.0)
	keyf(floor_light, "material:shader_parameter/alpha", func(t: float): return pulse(t))

	# the rift
	var sz := Vector2(RX * 2 + 14, RY * 2 + 14)
	var params := {"rx": RX, "ry": RY, "cy": CY}
	for i in 8:
		params["c%d" % i] = C[i]
	var rift := shape("Rift", arcane_shader("portal"), sz, params, {"at": Vector2(0, CY)})
	loop_t(rift)
	var rift_light := shape("RiftLight", arcane_shader("portal_light"), sz, {"rx": RX, "ry": RY, "cy": CY, "c6": C[6]}, {"at": Vector2(0, CY)})
	loop_t(rift_light)

	# in the oval's own plane (a group squashed to it): specks sinking round the well, motes riding round the rim
	var oval := group("Oval", {"at": Vector2(0, CY)})
	oval.scale = Vector2(1, RY / RX)
	var specks := particles("Specks", {"parent": oval, "local": true, "amount": 11, "lifetime": 1.8, "texture": "dot1",
		"emit": {"ring": [RX * 0.92, RX * 0.8]}, "orbit": [0.25, 0.3], "radial": [-14, -9],
		"ramp": gradient([C[6], C[6], C[5], C[5]], [0.0, 0.3, 0.6, 1.0]), "alpha_curve": [[0, 0], [0.15, 1], [0.75, 1], [1, 0]]})
	life_rand(specks, 0.38)
	var riders := particles("Riders", {"parent": oval, "local": true, "amount": 7, "lifetime": 1.2, "texture": "streak4", "align": true,
		"emit": {"ring": [RX * 1.55, RX * 1.2]}, "orbit": [1.1, 1.2], "radial": [-6, -4],
		"initial": gradient([Color.WHITE, C[6], C[6]]), "alpha_curve": [[0, 0], [0.2, 1], [0.8, 1], [1, 0]]})
	riders.amount = 7

	# motes pulled in from round about, faster as they fall, and streaks
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	for i in 200:
		var th := rng.randf() * TAU
		var d0 := rng.randf_range(1.8, 3.0)
		var out := d0 - 1.0
		pts.append(Vector2(cos(th) * (RX + out * 21), minf(-1.0 - CY, sin(th) * (RY + out * 16))))
	var infall := particles("Infall", {"at": Vector2(0, CY), "amount": 10, "lifetime": 0.5, "texture": load(ARC + "_spark6.png"), "align": true,
		"emit": {"points": pts}, "tangential": [10, 40], "radial": [-260, -160],
		"initial": gradient([Color.WHITE, C[6], C[5], C[4]], [0.0, 0.25, 0.55, 0.8]), "alpha_curve": [[0, 0], [0.2, 1], [0.85, 1], [1, 0]]})
	radial_speed(infall, -40, -25)
	life_rand(infall, 0.4)
	var streaks := particles("Streaks", {"at": Vector2(0, CY), "amount": 3, "lifetime": 0.5, "texture": "streak6", "align": true,
		"emit": {"points": pts}, "radial": [-320, -240], "ramp": gradient([C[6], Color.WHITE], [0.0, 0.85]),
		"alpha_curve": [[0, 0], [0.2, 1], [1, 1]]})
	life_rand(streaks, 0.28)
	var sl := particles("StreakLight", {"layer": "light", "at": Vector2(0, CY), "amount": 3, "lifetime": 0.5, "texture": "glow8",
		"emit": {"points": pts}, "radial": [-320, -240], "color": Color(C[6], 0.35)})
	life_rand(sl, 0.28)
	sl.seed = streaks.seed

	# grit and sparks skating in along the floor from both sides
	for s in [-1, 1]:
		var sk := particles("Skate%s" % ("L" if s < 0 else "R"), {"at": Vector2(s * 36, -1.5), "amount": 3, "lifetime": 1.1,
			"texture": "streak3", "align": true, "emit": {"box": Vector2(13, 0.6)}, "dir": 0 if s < 0 else 180, "speed": [0, 4],
			"gravity": Vector2(-s * 70, -4), "initial": gradient([C[6], C[5], C[5]]), "alpha_curve": [[0, 0], [0.25, 1], [0.85, 1], [1, 0]]})
		life_rand(sk, 0.36)
