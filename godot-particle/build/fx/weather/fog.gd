# reimagined-from: src/fx/weather/fog.js@68785cbc590bd950fd124ba18be6f85f62a4cf3c
# Fog: Slow banks of moonlit fog at three depths drift past each other, crests catching the light, while thin streaks of mist slide by in front.
# loop, 12.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp palette: #14121e #24213a #363250 #4f4a6c #6d688b #918cab #bdb8d4 #ece8f6
# Three banks of fog and the streaks of mist in front, each a canvas shader over the canvas (fx/weather/_fog.gdshader,
# the soft layer, with a light twin for the moonlit crests): the original's baked tiling noise, warped, scrolled a
# whole tile a loop, cut into three tones with Bayer edges and a lit crest.
extends "res://build/fx/weather/_weather.gd"

const TONE := [[2, 3, 4], [2, 3, 4], [2, 3, 5]]
const CREST := [5, 5, 6]


func make() -> void:
	var C := fitc("palette", 8)
	var S := 5
	var G := field_tex(S * 7 + 11, 256, 128, [4, 8, 16])
	for n in 3:
		var tc: Array = TONE[n]
		var pr := {"C": C, "F": field_tex(S * 7 + n), "G": G, "pass_": n, "tones": [C[tc[0]], C[tc[1]], C[tc[2]]],
			"crest": mixc(C[CREST[n]], Color.WHITE, 0.12 + 0.08 * n)}
		sky("Bank%d" % n, "fog", pr, {"layer": "soft"})
		sky("Bank%dLight" % n, "fog_light", pr, {"layer": "light"})
	var sp := {"C": C, "F": field_tex(S * 7 + 21), "G": G, "pass_": 3, "tones": [C[2], C[3], C[4]], "crest": C[5]}
	sky("Streaks", "fog", sp, {"layer": "soft"})
	sky("StreaksLight", "fog_light", sp, {"layer": "light"})
