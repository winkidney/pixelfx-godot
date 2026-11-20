# reimagined-from: src/fx/weather/snow.js@b1307a4f4a41ea4efaada42895d2f3df1561afa8
# Snow: Snow at three depths in a gusty breeze: far specks, drifting flakes, big near crystals that spin and glow; they settle on a sparkling drift and melt away.
# loop, 12.00 s, 320x180 canvas, origin [160.0, 170.0], backdrop sky
# A cold haze (the soft layer), then three depths of flakes as GPU particles placed from the clock by the original's
# own trips (fx/weather/_snow.gdshader: every flake falls a whole number of times a loop, swaying in the periodic
# gust, and lies on the drift for the rest of its fall), the drift and its twinkling glints (a canvas shader), and
# the near crystals in front with their light twin.
extends "res://build/fx/weather/_weather.gd"

const AXIS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG := [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


func make() -> void:
	var C := fitc("palette", 8)
	keep_colour(Color.WHITE)
	var haze := mixc(C[1], C[2], 0.4)
	sky("Haze", "haze", {"top": haze, "a0": 0.26, "a1": 0.22, "e0": -170.0, "e1": 0.0, "y0": -170.0, "y1": 9.0}, {"layer": "soft"})
	var pr := {"C": C, "white": Color.WHITE, "seed": 6, "atlas": crystals()}
	var far := bodies("Specks", 230, "snow", "snow_draw", 2, pr.merged({"layer": 0}))
	var drift := sky("Drift", "snow_drift", {"C": C, "white": Color.WHITE, "seed": 6})
	sky("DriftLight", "snow_drift_light", {"C": C, "seed": 6}, {"layer": "light"})
	var flakes := bodies("Flakes", 140, "snow", "snow_draw", 4, pr.merged({"layer": 1}))
	var near := bodies("Crystals", 24, "snow", "snow_draw", 16, pr.merged({"layer": 2}))
	body_light(near, "snow_light", 40, {"C": C})
	# the original's draw order: specks, the drift, then the flakes over it
	root.move_child(drift, far.get_index() + 1)
	root.move_child(flakes, drift.get_index() + 1)


## snow.js crystal() for r 3..5, turned or not: 16 x 16 cells of palette steps (1..8: C[0..7], 9: white).
func crystals() -> Texture2D:
	var img := Image.create(16 * 6, 16, false, Image.FORMAT_R8)
	for r in [3, 4, 5]:
		for turn in [0, 1]:
			var px := {}
			var lng: Array = DIAG if turn else AXIS
			var sht: Array = AXIS if turn else DIAG
			var R: int = r - 1 if turn else r
			for dv in lng:
				var dx: int = dv.x
				var dy: int = dv.y
				for d in range(1, R + 1):
					px[Vector2i(dx * d, dy * d)] = 9 if d == R else 7
				var nubs: Array = ([R - 1] if R >= 3 else []) if turn else ([R - 1, R - 2] if R >= 5 else [R - 1] if R >= 4 else [])
				for n in nubs:
					var ox: int = dx if turn else dy
					var oy: int = -dy if turn else -dx
					px[Vector2i(dx * n + (0 if turn else ox), dy * n + oy)] = 5
					px[Vector2i(dx * n + (-dx if turn else -ox) + (dx if turn else 0), dy * n + (0 if turn else -oy))] = 5
			for dv in sht:
				var top: int = 1 if turn else maxi(1, R / 2)
				for d in range(1, top + 1):
					px[Vector2i(dv.x * d, dv.y * d)] = 7 if d == 1 else 6
			px[Vector2i.ZERO] = 9
			var v: int = (r - 3) * 2 + turn
			for c in px:
				img.set_pixel(v * 16 + 8 + c.x, 8 + c.y, Color8(px[c], 0, 0))
	return asset("_crystals", img)
