# reimagined-from: src/fx/weather/god-rays.js@5902f1d614ec621a4516cf3bccfa5d1a8ecb3c5a
# God rays: Shafts of light slant down from high on the left, breathing and swaying, pooling on the floor, as drifting dust motes light up whenever they cross a beam.
# loop, 10.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp palette: #1a1208 #3a2810 #7a5a24 #c89a44 #f2d27a #fff2c4 #ffffff
# The air and the six breathing shafts are a canvas shader over the canvas (fx/weather/_god_rays_sky.gdshader, the
# soft layer; its light twin carries the beams' light and the sun's glare); the dust motes are GPU particles placed
# from the clock on the original's whole-cycle drifts (_god_rays.gdshader), shown only while a beam lights them,
# each with a light twin.
extends "res://build/fx/weather/_weather.gd"


func make() -> void:
	var C := fitc("palette", 7)
	keep_colour(Color.WHITE)
	var Lc := PackedColorArray()
	for c in C:
		Lc.append(mixc(C[0], c, 0.75))
	var pr := {"C": C, "L": Lc, "seed": 3}
	sky("Air", "god_rays_sky", pr, {"layer": "soft"})
	sky("AirLight", "god_rays_sky_light", pr, {"layer": "light"})
	for front in [false, true]:
		var p := bodies("Motes" + ("Front" if front else "Back"), 50 if front else 110, "god_rays", "mote", 4,
			{"seed": 3, "first": 0 if front else 50, "front": front, "tone": [C[4], C[5], Color.WHITE], "side": C[4]})
		body_light(p, "mote_light", 16, {"glow_color": C[4]})
