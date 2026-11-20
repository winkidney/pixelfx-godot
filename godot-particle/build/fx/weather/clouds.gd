# reimagined-from: src/fx/weather/clouds.js@eb7454a67fbef6fd3f32f71c08f6cde8f1df4db3
# Clouds: Layers of clouds drift past a bright moon at night: silver-lit tops, dark bellies, edges that flare where they cross the moon, forming and thinning as they go.
# loop, 12.00 s, 320x180 canvas, origin [160.0, 180.0], backdrop sky
# ramp palette: #0c0c18 #16172a #232540 #363a5a #545a80 #8088ae #bcc4e2 #f2f4ff
# The moon is a small canvas shader (fx/weather/_moon.gdshader); every cloud is one GPU particle placed from the clock
# on its own once-a-loop life (_clouds.gdshader) and drawn whole by a canvas shader that walks the original's puffs
# (_cloud.gdshader, the soft layer: the far ones see-through), with a light twin for its silver lining; the moon's
# halo over everything is a keyed glow shader (_glows.gdshader).
extends "res://build/fx/weather/_weather.gd"


func make() -> void:
	var C := fitc("palette", 8)
	var W := Color.WHITE
	keep_colour(W)
	sky("Moon", "moon", {"C": C, "white": W})
	var p := bodies("Clouds", 18, "clouds", "cloud", 192, {"seed": 7, "C": C}, {"layer": "soft"})
	clock(p, "material:shader_parameter/t")
	var lp := body_light(p, "cloud_light", 192, {"seed": 7, "C": C})
	clock(lp, "material:shader_parameter/t")
	var m := Vector2(92, -128)
	sky("Halo", "glows", {"pos": PackedVector2Array([m, m, m, m]), "rad": PackedFloat32Array([110, 40, 18, 0]),
		"k": PackedFloat32Array([0.14, 0.25, 0.3, 0]), "col": [C[4], C[5], C[6], C[6]]}, {"layer": "light"})
