# reimagined-from: src/fx/water/waterfall.js@573def3e9b4e153aab3c58e5e931241cb0915f67
# Waterfall: A river pours from a notch in a rock outcrop: a white curl, a deep sheet that splits into strands, churning foam, spray, drifting mist and rings on a dark pool.
# loop, 2.00 s, 144x136 canvas, origin [72.0, 118.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The outcrop is the original's pixels (port/props.py). The water is a canvas shader (fx/water/_falls.gdshader) on the
# original's own noise: the dark pool with caustics, a lit far shore and the falls' broken reflection; the river
# sliding out of the notch, the white curl, the sheet of lanes (see-through ones on the soft layer, lit ones with
# white dashes sliding and stretching down them) splitting into strands, and the churning foot. Three rings spread
# over the pool (fx/water/_ring.gdshader). Strands peel off the edges, billows roll out of the churn, beads are
# thrown clear and plink into the pool, fine spray drifts up, mist rolls sideways (emitters); glints wink.
extends "res://build/fx/water/_water.gd"

const D := 2.0
const SY := 0.2
const G := 760.0


func make() -> void:
	var H: float = meta.options.height
	var W: float = meta.options.width
	var S: int = meta.options.seed
	ground(2.0)
	var base := {"pal": C, "H": H, "W": W, "seed": float(S)}

	# behind: the pool, the far halves of the rings, mist
	var pool := base.duplicate()
	pool.merge({"mode": 0.0, "translucent": true})
	loop_t(shape("Pool", water_shader("falls"), Vector2(116, 26), pool, {"at": Vector2(0, 2), "back": true}))
	loop_t(shape("Caustics", water_shader("falls_light"), Vector2(116, 26), {"pal": C}, {"at": Vector2(0, 2), "back": true}))
	var shore := base.duplicate()
	shore.mode = 1.0
	loop_t(shape("Shore", water_shader("falls"), Vector2(116, 26), shore, {"at": Vector2(0, 2), "back": true}))
	for i in 3:
		var rg := water_ring("Ring%d" % i, W + 46.0, {"sy": SY, "n": 1.0, "seed": float(i + 1)}, {"at": Vector2(0, 1)})
		sample_shader(rg, func(t: float) -> Dictionary:
			var f := fposmod(t / D + i / 3.0, 1.0)
			return {"r": W + 6.0 + f * 38.0, "k": 0.95 * pow(1.0 - f, 1.5), "glint": (1.0 - f * 2.5) if f < 0.4 else 0.0})
	var mist := gradient([Color(C[6], 0.0), Color(C[6], 0.3), Color(C[6], 0.18), Color(C[6], 0.0)], [0.0, 0.12, 0.5, 1.0], true)
	for side in [[-1.0, "MistL"], [1.0, "MistR"]]:
		particles(side[1], {"layer": "light", "at": Vector2(side[0] * 8.0, -5), "amount": 6, "lifetime": 2.3,
			"randomness": 0.2, "texture": "glow32", "emit": {"box": Vector2(5, 3)}, "dir": 90.0 - side[0] * 80.0,
			"spread": 8, "speed": [24, 40], "damping": [10, 16], "scale": [0.35, 0.5], "scale_curve": [[0, 0.7], [1, 1.5]], "ramp": mist})

	# the river, the outcrop, the sheet and its curl
	var river := base.duplicate()
	river.mode = 3.0
	var lanes := base.duplicate()
	lanes.merge({"mode": 2.0, "translucent": true})
	var size := Vector2(W * 2.0 + 24.0, H + 12.0)
	var at := Vector2(0, -H / 2.0 - 4.0)
	prop({"back": false})
	loop_t(shape("Lanes", water_shader("falls"), size, lanes, {"at": at}))
	loop_t(shape("Sheet", water_shader("falls"), size, river, {"at": at}))
	glow("CurlLight", 34, {"radius": 34, "color": C[5], "alpha": 0.2}, {"at": Vector2(0, -H)})
	line("CurlLine", PackedVector2Array([Vector2(-W, -H + 0.5), Vector2(W, -H + 0.5)]), {"layer": "light", "width": 12, "color": Color(C[6], 0.18)})

	# strands peel off the edges and fall free
	for side in [[-1.0, "StrandsL"], [1.0, "StrandsR"]]:
		particles(side[1], {"at": Vector2(side[0] * (W + 3.0), -H + 14.0 + H * 0.28), "amount": 3, "lifetime": 0.4,
			"texture": "streak6", "align": true, "emit": {"box": Vector2(1.5, H * 0.28)}, "dir": 90.0 - side[0] * 8.0,
			"speed": [50, 70], "gravity": Vector2(0, 520), "ramp": gradient([C[4], C[6], Color(C[4], 0.5)], [0.0, 0.3, 0.8])})

	# the churning foot, billows rolling out of it
	var foot := base.duplicate()
	foot.mode = 4.0
	loop_t(shape("Foam", water_shader("falls"), Vector2(2.0 * (W + 11.0), 18), foot, {"at": Vector2(0, -5)}))
	var bill := {"at": Vector2(0, -4), "amount": 11, "lifetime": 0.7, "texture": "disc5", "emit": {"box": Vector2(W * 0.9, 1.5)},
		"dir": -90, "spread": 75, "speed": [6, 14], "damping": [10, 20], "scale": [0.6, 1.1],
		"scale_curve": [[0, 0.3], [0.3, 1.0], [0.7, 1.0], [1, 0.3]], "color": C[4]}
	var shadow := particles("Billows", bill)
	var body := bill.duplicate()
	body.merge({"color": C[6], "scale": [0.5, 0.92], "at": Vector2(0, -4.6)}, true)
	twin("BillowBody", shadow, body, {})
	var cap := bill.duplicate()
	cap.merge({"texture": "disc3", "color": C[7], "scale": [0.5, 0.9], "at": Vector2(-0.6, -5.4)}, true)
	twin("BillowCap", shadow, cap, {})

	# beads thrown clear of the churn, landing in the pool with a ring
	var spray := {"at": Vector2(0, -5), "amount": 9, "lifetime": 1.0, "texture": "dot1", "emit": {"box": Vector2(W + 2.0, 1)},
		"dir": -90, "spread": 26, "speed": [75, 160], "gravity": Vector2(0, G), "initial": gradient([C[6], C[5], C[6], C[7]]),
		"collide": {"hide": true, "size": 1}}
	var sp := particles("Spray", spray)
	twin("SprayTails", sp, spray, {"texture": "streak3", "align": true, "initial": null, "color": C[3]})
	particles("Plinks", {"at": Vector2(0, 2), "amount": 5, "lifetime": 0.35, "texture": "ripple5x1",
		"emit": {"box": Vector2(W + 24.0, 2)}, "scale_curve": [[0, 0.6], [1, 1.5]],
		"ramp": ramp("palette", {"from": 0.57, "to": 0.86, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})})
	# fine spray hangs in the air off the foot, drifting up and out
	particles("Fine", {"at": Vector2(0, -6), "amount": 21, "lifetime": 1.25, "randomness": 0.3, "texture": "dot1",
		"emit": {"box": Vector2(W + 3.0, 3)}, "dir": -90, "spread": 40, "speed": [10, 30], "damping": [4, 8],
		"initial": gradient([C[6], C[7], C[6], C[6]]), "alpha_curve": [[0, 1], [0.7, 1], [1, 0]],
		"turbulence": {"strength": 1.0, "scale": 2.0, "influence": [0.01, 0.02]}})

	# glints wink on the falling water and in the spray
	var rng := RandomNumberGenerator.new()
	rng.seed = S + 50
	for g in 12:
		var born := rng.randf() * D
		var life := rng.randf_range(0.2, 0.4)
		var low := rng.randf() < 0.45
		var d := (H - rng.randf_range(4, 16)) if low else rng.randf_range(12, H - 16)
		var x := rng.randf_range(-W - 10, W + 10) if low else rng.randf_range(-0.8, 0.8) * (W + 3.2 * pow(d / H, 1.6))
		glint("Glint%d" % g, func(t: float) -> Array:
			var age := fposmod(t - born, D)
			if age >= life:
				return [x, 0.0, 0.0]
			return [x, -H + d - (age / life) * (6.0 if low else -10.0), sin(PI * age / life)], 0.55, 5.0, 0.35)

	# light: down the sheet, a pool of it where the water lands, on the water around
	line("SheetLight", PackedVector2Array([Vector2(0, -H + 6.0), Vector2(0, -8)]), {"layer": "light", "width": 52, "color": Color(C[4], 0.12)})
	var landing := glow("FootLight", 40, {"radius": 40, "color": C[5], "alpha": 0.32}, {"at": Vector2(0, -5)})
	sample(landing, "material:shader_parameter/alpha", func(t: float) -> float: return 0.32 + 0.05 * sin(t / D * TAU * 2.0))
	glow("PoolLight", 50, {"radius": 50, "color": C[3], "alpha": 0.14}, {"at": Vector2(0, 4)})
