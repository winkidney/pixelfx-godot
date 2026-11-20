# reimagined-from: src/fx/weather/blizzard.js@c906269a2a79d4678a323741c8138a0bd447e51f
# Blizzard: Snow driven almost flat by a gale: streaks at three depths race past, gusts throw translucent sheets of snow across the sky and spindrift streams off the drifts.
# loop, 8.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp palette: #0d111f #182035 #27324d #3e4d6e #64779c #9cb0d0 #d8e4f6 #ffffff
# The whiteout haze and sheets of blown snow, and the drift with its spindrift, are canvas shaders over the canvas
# (fx/weather/_blizzard_sky.gdshader, the soft layer, with light twins); the streaks at three depths and the grains
# skipping along the crest are GPU particles placed from the clock by the original's own trips
# (_blizzard.gdshader), drawn as its two-tone streaks (_streak.gdshader), the near ones with a light twin.
extends "res://build/fx/weather/_weather.gd"

const COLS := [[3, 4, 5], [4, 5, 6], [4, 6, 7]]
const QUAD := [12, 24, 48]


func make() -> void:
	var C := fitc("palette", 8)
	var W := Color.WHITE
	keep_colour(W)
	var S := 9
	var haze := mixc(C[2], C[3], 0.5)
	var far := field_tex(S * 3 + 7)
	var near := field_tex(S * 3 + 8)
	var spin := field_tex(S * 5 + 1)
	sky("SheetsFar", "blizzard_sky", {"C": C, "white": W, "haze": haze, "F": far, "pass_": 0}, {"layer": "soft"})
	sky("SheetsFarLight", "blizzard_sky_light", {"C": C, "white": W, "haze": haze, "F": far, "pass_": 0}, {"layer": "light"})
	for L in 2:
		streaks(L, C)
	sky("Ground", "blizzard_sky", {"C": C, "white": W, "F": spin, "pass_": 2}, {"layer": "soft"})
	sky("GroundLight", "blizzard_sky_light", {"C": C, "white": W, "F": spin, "pass_": 2}, {"layer": "light"})
	bodies("Grains", 40, "blizzard", "streak", 4, {"layer": 3, "seed": S, "mode": 2, "head": [C[6], W, C[6]],
		"bodyc": [C[5], C[5], C[5]], "tail": [C[5], C[5], C[5]]})
	sky("SheetsNear", "blizzard_sky", {"C": C, "white": W, "F": near, "pass_": 1}, {"layer": "soft"})
	sky("SheetsNearLight", "blizzard_sky_light", {"C": C, "white": W, "F": near, "pass_": 1}, {"layer": "light"})
	var front := streaks(2, C)
	body_light(front, "streak_light", 12, {"glow_color": C[5], "radius": 5.0})


func streaks(L: int, C: PackedColorArray) -> GPUParticles2D:
	var c: Array = COLS[L]
	return bodies("Streaks%d" % L, [240, 130, 34][L], "blizzard", "streak", QUAD[L], {"layer": L, "seed": 9, "mode": 0,
		"split": 0.45, "ta0": 0.3, "ta1": 0.7, "tail": [C[c[0]], C[c[0]], C[c[0]]], "bodyc": [C[c[1]], C[c[1]], C[c[1]]],
		"head": [C[c[2]], Color.WHITE, C[c[2]]]})
