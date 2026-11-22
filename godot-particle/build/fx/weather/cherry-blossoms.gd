# reimagined-from: src/fx/weather/cherry-blossoms.js@768097439f72fb08a6a6f969e65761321d9bc763
# Cherry blossoms: Pink petals flutter down on a spring breeze, tumbling in little spirals and flashing as they catch the light, with a few whole blossoms spinning among them.
# loop, 10.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp palette: #4a1832 #8e3460 #d26a94 #f2a2c0 #ffd2e2 #fff4f8
# A plum dusk haze (the soft layer), then GPU particles placed from the clock by the original's own trips
# (fx/weather/_cherry.gdshader): the petals already lying on the floor, petals behind and in front, each tumbling in a
# little spiral down a whole number of times a loop on the periodic breeze, flipping and flashing (light twins), and
# whole blossoms spinning as they sink; every petal shaded as the original shades it (_petal.gdshader).
extends "res://build/fx/weather/_weather.gd"


func make() -> void:
	var C := fitc("palette", 6)
	var W := Color.WHITE
	keep_colour(W)
	var top := Color("#0e0a14")
	var low := mixc(Color("#1a0e1a"), C[0], 0.4)
	keep_mix(top, low, 12)
	sky("Haze", "haze", {"mode": 1, "top": top, "low": low, "pw": 2.0, "a0": 0.3, "a1": 0.12, "e0": -170.0, "e1": 10.0,
		"y0": -170.0, "y1": 9.0}, {"layer": "soft"})
	var pr := {"seed": 12, "C": C, "white": W, "heart": Color("#ffe08a")}
	bodies("Fallen", 46, "cherry", "petal", 16, pr.merged({"layer": 2}))
	for near in [0, 1]:
		var p := bodies("Petals" + ("Near" if near else "Far"), 54 if near else 90, "cherry", "petal", 16, pr.merged({"layer": near}))
		body_light(p, "petal_light", 16, {"glow_color": C[4], "radius": 7.0 if near else 5.0})
	var b := bodies("Blossoms", 7, "cherry", "petal", 20, pr.merged({"layer": 3}))
	body_light(b, "petal_light", 20, {"glow_color": C[4]})
