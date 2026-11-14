# reimagined-from: src/fx/water/bubbles.js@6ba609c5b2ee85100e075a515c75264678ec1911
# Bubbles: Bubbles stream up from a vent of pebbles, wobbling and swelling as they rise, flare as they cross shafts of light from the surface, then dome up and pop there.
# loop, 4.00 s, 104x112 canvas, origin [52.0, 104.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The vent's pebbles are the original's pixels (port/props.py). The water is a canvas shader
# (fx/water/_underwater.gdshader): deeper toward the floor on the soft layer, a wavy lit surface with glints running
# along it on the colour layer, light shafts drifting down through it and caustics on the floor on the light layer.
# The bubbles rise from the vent's three mouths (emitters, the bigger ones faster): pixels, shaded 2 x 2s and
# lit-rim bubbles with a see-through body and a highlight (twin emitters on one seed), wobbling as they go; they die
# at the surface (a collision ceiling) where pops ring out; specks drift and twinkle in the water.
extends "res://build/fx/water/_water.gd"

const D := 4.0
const TOP := -92.0
const HALF := 48.0


func make() -> void:
	prop()
	ground(TOP - 64.0)
	var size := Vector2(HALF * 2.0, -TOP + 8.0)
	var at := Vector2(0, TOP / 2.0 - 2.0)
	var params := {"pal": C, "top": TOP, "half_w": HALF}
	var water := params.duplicate()
	water.merge({"mode": 0.0, "translucent": true})
	loop_t(shape("Water", water_shader("underwater"), size, water, {"at": at, "back": true}))
	var line := params.duplicate()
	line.mode = 1.0
	loop_t(shape("Surface", water_shader("underwater"), size, line, {"at": at}))
	loop_t(shape("Light", water_shader("underwater_light"), size + Vector2(16, 16), params, {"at": at}))

	# specks drifting in the water, twinkling
	particles("Specks", {"at": Vector2(0, TOP + 49), "amount": 26, "lifetime": D, "texture": "dot1",
		"emit": {"box": Vector2(HALF - 6.0, 43)}, "dir": -90, "spread": 20, "speed": [3, 5],
		"initial": gradient([C[4], C[5], C[4], C[7]]),
		"alpha_curve": [[0, 0], [0.08, 1], [0.3, 1], [0.38, 0], [0.5, 0], [0.58, 1], [0.92, 1], [1, 0]],
		"turbulence": {"strength": 1.0, "scale": 4.0, "influence": [0.005, 0.01]}})

	# the bubbles, from the vent's three mouths, wobbling as they rise; they end at the surface
	var mouths := PackedVector2Array([Vector2(-5, -2), Vector2(1, -2), Vector2(6, -2)])
	var wobble := {"strength": 1.5, "scale": 3.0, "influence": [0.01, 0.02]}
	var tiny := {"local": true, "amount": 9, "lifetime": 2.6, "texture": "dot1", "emit": {"points": mouths}, "dir": -90,
		"spread": 3, "speed": [34, 44], "initial": gradient([C[5], C[6], C[5]]), "turbulence": wobble,
		"collide": {"hide": true, "size": 1}}
	particles("Tiny", tiny)
	var small := tiny.duplicate()
	small.merge({"amount": 11, "texture": "dot2", "speed": [36, 46], "initial": null}, true)
	small.erase("initial")
	small.color = C[5]
	var sm := particles("Small", small)
	twin("SmallShine", sm, small, {"texture": "dot1", "color": C[7], "at": Vector2(-0.5, -0.5)})
	for b in [["Big", "ring5", "disc3", 4, [44, 54]], ["Bigger", "ring7", "disc5", 3, [48, 58]]]:
		var big := tiny.duplicate()
		big.merge({"amount": b[3], "lifetime": 2.1, "texture": b[1], "speed": b[4], "color": C[4],
			"collide": {"hide": true, "size": 4}}, true)
		big.erase("initial")
		var rim := particles(b[0], big)
		twin(b[0] + "Body", rim, big, {"layer": "soft", "texture": b[2], "color": Color(C[5], 0.15)})
		twin(b[0] + "Lit", rim, big, {"texture": "dot1", "color": C[6], "at": Vector2(-1, -1)})
		twin(b[0] + "Shine", rim, big, {"texture": "dot1", "color": C[7], "at": Vector2(-1, -2)})

	# where they reach the surface they pop: a ring flattening out, flecks thrown up
	var pop := ramp("palette", {"from": 0.71, "to": 1.0, "reverse": true, "alpha": [[0, 1], [0.6, 1], [1, 0.2]]})
	particles("Pops", {"at": Vector2(0, TOP + 0.5), "amount": 3, "lifetime": 0.3, "texture": "ripple7x3",
		"emit": {"box": Vector2(10, 0.5)}, "scale_curve": [[0, 0.5], [1, 1.5]], "ramp": pop})
	particles("PopFlecks", {"at": Vector2(0, TOP - 1), "amount": 4, "lifetime": 0.25, "texture": "dot1",
		"emit": {"box": Vector2(10, 0.5)}, "dir": -90, "spread": 30, "speed": [12, 22], "color": C[6]})
