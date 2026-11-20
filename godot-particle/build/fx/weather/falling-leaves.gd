# reimagined-from: src/fx/weather/falling-leaves.js@d758e3b1cee0272df06280d928cde1d3e6452bf0
# Falling leaves: Autumn leaves swing down through the air, tilting and flipping to show their pale backs, ride a gust, land flat in the litter and fade.
# loop, 10.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# ramp golds: #3e300c #7a5c14 #b8901e #e8c23a #fff09a #fffbe0
# ramp palette: #4a1d0c #8a3a14 #c8621e #f0982e #ffcf72 #fff0c4
# ramp reds: #40101a #7c1c22 #b8302a #e85a3c #ff9a72 #ffd8c4
# A faint dusk haze (the soft layer), then GPU particles placed from the clock by the original's own trips
# (fx/weather/_leaves.gdshader): the litter already lying along the floor, the far leaves, then the near ones, each
# swinging down a whole number of times a loop like a pendulum, tilting, flipping to show its pale back, riding the
# periodic gust, landing flat and fading; shaded as the original shades them (_leaf.gdshader), a glint's glow on a
# leaf turned to the light (light twins).
extends "res://build/fx/weather/_weather.gd"


func make() -> void:
	var sets := [fitc("palette", 6), fitc("reds", 6), fitc("golds", 6)]
	var top := Color("#0e0a12")
	var low := mixc(Color("#140c14"), sets[0][0], 0.3)
	keep_mix(top, low, 12)
	sky("Haze", "haze", {"mode": 1, "top": top, "low": low, "pw": 2.0, "a0": 0.32, "a1": 0.1, "e0": -170.0, "e1": 10.0,
		"y0": -170.0, "y1": 9.0}, {"layer": "soft"})
	var P := []
	for dull in [false, true]:
		for s in sets:
			var col := PackedColorArray()
			for c in s:
				col.append(mixc(c, s[0], 0.12) if dull else c)
			P += [col[0], col[1], col[2], col[3], col[4], mixc(col[2], Color("#e8dcc8"), 0.5), mixc(col[1], Color("#9c8a78"), 0.2),
				mixc(col[2], Color("#c8b49c"), 0.22), mixc(col[3], Color("#e0d0b8"), 0.22), col[5], col[4]]
	var pr := {"seed": 8, "P": P}
	bodies("Litter", 64, "leaves", "leaf", 24, pr.merged({"layer": 2}))
	for front in [0, 1]:
		var p := bodies("Leaves" + ("Near" if front else "Far"), 62, "leaves", "leaf", 24, pr.merged({"layer": front}))
		body_light(p, "leaf_light", 32, {"P": P})
