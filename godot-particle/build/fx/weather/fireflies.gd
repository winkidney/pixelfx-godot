# reimagined-from: src/fx/weather/fireflies.js@25511900cc17f40531342253430ea82206f2db98
# Fireflies: Fireflies wander over a meadow at night, each glowing up and fading on its own rhythm, trailing light and lighting the grass tips beneath them.
# loop, 12.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp grass: #070f0b #0c1a12 #13281a #1d3a24 #2b5232 #3f6e40
# ramp palette: #2a3a10 #5a7a1a #9ad02a #d6ff5a #f4ffb8 #ffffff
# A night haze (the soft layer), then GPU particles placed from the clock (fx/weather/_fireflies.gdshader): the back
# row of grass blades swaying in the breeze, the far fireflies wandering on whole-cycle paths and glowing on their
# own rhythms, the front row of blades, the near fireflies with dark bodies and beating wings; blade tips near a
# lit fly catch its light; every fly has a light twin (its lantern).
extends "res://build/fx/weather/_weather.gd"


func make() -> void:
	var C := fitc("palette", 6)
	var G := fitc("grass", 6)
	keep_colour(Color.WHITE)
	keep_mix(G[0], G[1], 12)
	sky("Haze", "haze", {"mode": 1, "top": G[0], "low": G[1], "pw": 1.0, "a0": 0.48, "a1": 0.14, "e0": -170.0, "e1": 10.0,
		"y0": -170.0, "y1": 9.0}, {"layer": "soft"})
	var pr := {"seed": 2, "C": C, "G": G, "wing": mixc(C[1], Color.WHITE, 0.4)}
	bodies("GrassBack", 230, "fireflies", "blade", 48, pr.merged({"layer": 2}))
	fly("FliesFar", 26, 0, pr)
	bodies("GrassFront", 150, "fireflies", "blade", 48, pr.merged({"layer": 3}))
	fly("FliesNear", 6, 1, pr)


func fly(name: String, n: int, layer: int, pr: Dictionary) -> void:
	var p := bodies(name, n, "fireflies", "firefly", 24, pr.merged({"layer": layer}))
	clock(p, "material:shader_parameter/t")
	# the wings beat on the reference's own frame count (floor(t * 30) on its accumulated clock)
	var keys := []
	var t := 0.0
	for i in int(roundf(root.duration * 30.0)) + 1:
		keys.append([i / 30.0, float(int(floor(t * 30.0)) % 2)])
		t += 1.0 / 30.0
	key(p, "material:shader_parameter/beat", keys, "nearest")
	var lp := body_light(p, "firefly_light", 64, pr)
	clock(lp, "material:shader_parameter/t")
