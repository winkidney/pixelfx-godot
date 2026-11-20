# reimagined-from: src/fx/weather/rain.js@20fe94ba69d0262151a65e38ff8a0bf90b043b75
# Rain: slanted rain at four depths: far drops fade into the dark, near ones glint and splash, drops ring the puddles
# An overcast haze (the soft layer), the wet floor with its puddles and the mist low over it (canvas shaders,
# fx/weather/_rain_sky.gdshader, with their light), and four depths of rain as GPU particles placed from the clock by
# the original's own trips (_rain.gdshader): far drops thinned by sweeping gusts and ending in the air, near ones
# landing in crowns on the floor or rings along a puddle (splash emitters of their own, _rain_splash.gdshader), the
# nearest catching the light (light twins). Streaks drawn as the original's two-tone lines (_streak.gdshader).
extends "res://build/fx/weather/_weather.gd"

const COLS := [[2, 2, 3], [2, 3, 4], [3, 4, 5], [3, 5, 7]]
const NN := [200, 150, 96, 42]
const QUAD := [4, 12, 20, 32]


func make() -> void:
	var C := fitc("palette", 8)
	var W := Color.WHITE
	keep_colour(W)
	var S := 4
	sky("Haze", "haze", {"top": mixc(C[0], C[1], 0.6), "a0": 0.3, "a1": 0.26, "e0": -170.0, "e1": 0.0, "y0": -170.0, "y1": 0.0},
		{"layer": "soft"})
	var crest := mixc(C[4], C[5], 0.5)
	var sk := {"C": C, "crest": crest, "seed": S, "M": field_tex(S + 9)}
	sky("FloorSheen", "rain_sky", sk.merged({"pass_": 1, "soft": true}), {"layer": "soft"})
	sky("Floor", "rain_sky", sk.merged({"pass_": 1, "soft": false}))
	sky("FloorLight", "rain_sky_light", sk.merged({"pass_": 0}), {"layer": "light"})
	var G := field_tex(S + 21, 256, 128, [4, 8, 16])
	for L in 3:
		drops(L, C, G)
	splashes(2, C)
	sky("Mist", "rain_sky", sk.merged({"pass_": 2, "soft": true}), {"layer": "soft"})
	var near := drops(3, C, G)
	body_light(near, "streak_light", 12, {"glow_color": C[5], "radius": 4.0, "off": Vector2(0, -2)})
	var sp := splashes(3, C)
	body_light(sp, "rain_splash_light", 16, {"glow_color": C[5]})


func drops(L: int, C: PackedColorArray, G: Texture2D) -> GPUParticles2D:
	var c: Array = COLS[L]
	return bodies("Drops%d" % L, NN[L], "rain", "streak", QUAD[L], {"layer": L, "seed": 4, "G": G, "mode": 3 if L == 0 else 0,
		"split": 0.45, "ta0": 0.35, "ta1": 0.65, "tail": [C[c[0]], C[c[0]], C[c[0]]], "bodyc": [C[c[1]], C[c[1]], C[c[1]]],
		"head": [C[c[2]], C[c[2]], C[c[2]]]})


func splashes(L: int, C: PackedColorArray) -> GPUParticles2D:
	return bodies("Splashes%d" % L, NN[L] * 3, "rain", "rain_splash", 40, {"layer": L + 2, "seed": 4, "C": C, "white": Color.WHITE})
