# reimagined-from: src/fx/nature/poison-cloud.js@f045358ea239e5ba376008fd018b8aa7a4f4eb1f
# Poison cloud: A miasma hugging the floor: ragged sheets of gas lit yellow-green from within, fading to violet, creep
# out in tongues that curl over at their tips; plumes twist up as ribbons.
# The three sheets are one shader each (fx/nature/_miasma.gdshader: the original's height field, tongues creeping out
# and rolling over in curls, streaks, a pale torn top), two behind and one in front, translucent; the plumes are a
# shader too (_miasma_plume.gdshader: twisting ribbons that rise and thin on the original's cycle); specks drifting
# out through the gas are particles (a light-layer twin with the same seed glows on each); the light inside it is a
# row of dim glows along the floor, pockets wandering inside, a broad wash.
extends "res://addons/pixelfx_particles/core/build.gd"

const SHEETS := [
	{"h": 36.0, "e": 0.84, "a": 0.46, "dim": 2.0, "flow": 4.0, "n": 2.0, "back": true},
	{"h": 26.0, "e": 0.96, "a": 0.5, "dim": 1.0, "flow": 8.0, "n": 2.0, "back": true},
	{"h": 16.0, "e": 1.04, "a": 0.56, "dim": 0.0, "flow": 8.0, "n": 3.0, "back": false},
]


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var D: float = meta.duration
	var E: float = 96.0 * float(meta.options.spread)
	var seed_: float = float(meta.options.seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31

	# the light inside it, low down: a row of glows along the floor (pulsing), pockets wandering inside it
	var x := -E
	var i := 0
	while x <= E:
		var g := glow("FloorLight%d" % i, 32, {"radius": 30, "color": C[5]}, {"at": Vector2(roundf(x), -3)})
		var keys := []
		for j in 17:
			var t := j / 16.0 * D
			var pulse := 0.85 + 0.15 * sin(TAU * t * 2.0 / D)
			keys.append([t, 0.14 * pulse * (1.0 - absf(x) / (E * 1.3))])
		key(g, "material:shader_parameter/alpha", keys)
		x += 22.0
		i += 1
	for k in 6:
		var ph := rng.randf() * TAU
		var amp := rng.randf_range(0.2, 0.7) * E
		var off := rng.randf_range(-0.3, 0.3) * E
		var y := -rng.randf_range(4, 10)
		var r := rng.randf_range(14, 22)
		var g := glow("Pocket%d" % k, r + 2, {"radius": r, "color": C[6]})
		var pos := []
		var al := []
		for j in 41:
			var t := j / 40.0 * D
			pos.append([t, Vector2(roundf(sin(TAU * t / D + ph) * amp + off), y)])
			al.append([t, 0.2 * (0.6 + 0.4 * sin(TAU * t * 3.0 / D + k))])
		key(g, "position", pos)
		key(g, "material:shader_parameter/alpha", al)

	var pal := ramp("palette", {"stops": 8})
	var sheets := []
	for si in SHEETS.size():
		var sh: Dictionary = SHEETS[si]
		var params := sh.duplicate()
		params.erase("back")
		params.merge({"si": float(si), "reach": E, "seed": seed_, "ramp": pal, "translucent": true})
		var node := shape("Sheet%d" % si, load("res://addons/pixelfx_particles/fx/nature/_miasma.gdshader"), Vector2(256, 66), params,
			{"at": Vector2(0, -31), "back": sh.back})
		loop_t(node)
		sheets.append(node)

	# plumes lifting off the sheets and twisting up as ribbons (in front of the back sheets, behind the front one)
	var pa := PackedVector4Array()
	var pb := PackedVector4Array()
	for k in 5:
		pa.append(Vector4(rng.randf() * D, rng.randf_range(2.4, 3.2), rng.randf_range(-0.55, 0.55) * E, rng.randf_range(13, 19)))
		pb.append(Vector4(rng.randf_range(34, 48), rng.randf() * TAU, rng.randf_range(3, 5), 0))
	for k in range(5, 8):
		pa.append(Vector4.ZERO)
		pb.append(Vector4.ZERO)
	var plumes := shape("Plumes", load("res://addons/pixelfx_particles/fx/nature/_miasma_plume.gdshader"), Vector2(170, 80),
		{"period": D, "count": 5.0, "pa": pa, "pb": pb, "ramp": pal, "translucent": true}, {"at": Vector2(0, -46)})
	loop_t(plumes)
	# draw the plumes under the front sheet
	root.move_child(plumes, sheets[2].get_index())

	# specks drifting out through the gas with its flow, twinkling, each with a little light
	for side in [-1, 1]:
		var o := {"at": Vector2(side * 0.375 * E, -11), "amount": 9, "lifetime": 2.0, "randomness": 0.3, "texture": "dot1",
			"emit": {"box": Vector2(0.325 * E, 9)}, "dir": 90 - side * 90, "spread": 10, "speed": [6, 14],
			"ramp": gradient([C[6], C[7], C[6], C[7], C[6]]), "alpha_curve": [[0, 0], [0.2, 1], [0.7, 1], [1, 0]],
			"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}}
		var sp := particles("Specks%s" % ("L" if side < 0 else "R"), o)
		var lo := o.duplicate()
		lo.layer = "light"
		lo.texture = "glow8"
		lo.ramp = gradient([Color(C[6], 0.3), Color(C[6], 0.3)])
		var sl := particles("SpeckLight%s" % ("L" if side < 0 else "R"), lo)
		sl.seed = sp.seed
	glow("Wash", 88, {"radius": E * 0.9, "color": C[5], "alpha": 0.1}, {"at": Vector2(0, -6)})
