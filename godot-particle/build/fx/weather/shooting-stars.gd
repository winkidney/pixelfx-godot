# reimagined-from: src/fx/weather/shooting-stars.js@292d44454a83d069beb930edabd68c9f0ac0ef82
# Shooting stars: Meteors burn across a starry sky, white heads trailing gold and rose; the big ones flare and break up, and each leaves a glowing train that twists and fades.
# loop, 10.00 s, 320x180 canvas, origin [160.0, 180.0], backdrop sky
# ramp palette: #3a1e5a #7a3a8a #e0607a #ffa86a #ffe6a8 #ffffff
# ramp sky: #141428 #2a2a4a #4c4c7c #8e8ec4 #dcdcff
# The faint milky band and its specks are a still canvas shader (fx/weather/_milky.gdshader, with its light); the
# starfield's 130 stars are GPU particles twinkling on whole cycles (_stars.gdshader, _star.gdshader,
# light twins for the glints); each of the seven meteors is a GPU particle riding its head on the original's
# timetable, drawn whole by a canvas shader: its train, head, flare, little stars and fragments (_meteor.gdshader,
# with its light twin).
extends "res://build/fx/weather/_weather.gd"


func make() -> void:
	var C := fitc("palette", 6)
	var K := fitc("sky", 5)
	var W := Color.WHITE
	keep_colour(W)
	sky("Band", "milky", {"K": K, "seed": 4})
	sky("BandLight", "milky_light", {"K": K}, {"layer": "light"})
	var st := bodies("Stars", 130, "stars", "star", 8, {"seed": 4, "D": 10.0, "ylen": 178.0, "cut": 0.94, "sel": 0.8,
		"dim": K[3], "steady": [K[4], W], "spark": K[4], "spark_tip": K[3], "white": W})
	body_light(st, "star_light", 24, {"steady_glow": K[3], "steady_k": 0.22, "spark": K[4], "spark_k": 0.3})
	var me := bodies("Meteors", 7, "shooting", "meteor", 640, {"seed": 4, "C": C, "white": W})
	clock(me, "material:shader_parameter/t")
	var ml := body_light(me, "meteor_light", 640, {"seed": 4, "C": C, "white": W})
	clock(ml, "material:shader_parameter/t")
