# reimagined-from: src/fx/weather/aurora.js@64b81a2be72cb56f49bc9c37ab228f54322d64f2
# Aurora: Rippling curtains of green-to-violet light over a starfield: folding hems burn bright, rays shimmer up into violet, and the whole sky slowly breathes.
# loop, 12.00 s, 320x180 canvas, origin [160.0, 180.0], backdrop sky
# ramp palette: #081a1e #0d3a36 #13664e #1fa06a #3fd88e #9af7bf #e6fff0
# ramp upper: #120b2a #26164f #41208a #6a34c0 #9c62e8 #d2b4ff #f6eeff
# The starfield is GPU particles twinkling on whole cycles (fx/weather/_stars.gdshader, _star.gdshader, light twins
# for the glints); the three curtains are canvas shaders over the sky (_aurora.gdshader: every pixel gathers the
# light the original's walk along each curtain drops on its column, posterized green to violet by height, the body
# on the soft layer and the hot hems dithered; _aurora_light.gdshader: its light and bloom); the brightest rays are
# worked out here for every frame by the original's walk and drawn as GPU particles, fine strands rising off the
# hems (_rays.gdshader, _ray.gdshader).
extends "res://build/fx/weather/_weather.gd"

const D := 12.0
const S := 3
# y, slope, amp, lam, fold, flam, height, k, s0, s1, rip, c0, c1, c2
const CURTAINS := [
	[-132.0, -0.08, 8.0, 210.0, 14.0, 150.0, 40.0, 0.6, -210.0, 210.0, 1.6, 1.0, 1.0, 2.0],
	[-88.0, 0.22, 13.0, 250.0, 19.0, 165.0, 82.0, 1.5, -195.0, 180.0, 2.4, 1.0, 2.0, 3.0],
	[-38.0, -0.05, 5.0, 150.0, 10.0, 110.0, 20.0, 0.45, -210.0, 210.0, 1.4, 2.0, 1.0, 3.0],
]


func make() -> void:
	var G := fitc("palette", 7)
	var U := fitc("upper", 7)
	var W := Color.WHITE
	keep_colour(W)
	var GM := PackedColorArray()
	for i in 7:
		GM.append(mixc(G[i], U[i], 0.5))
	var st := bodies("Stars", 150, "stars", "star", 8, {"seed": S, "D": D, "ylen": 175.0, "cut": 0.95, "sel": 0.9,
		"dim": mixc(U[3], W, 0.2), "steady": [mixc(U[5], W, 0.5), W], "spark": mixc(U[5], W, 0.6), "spark_tip": U[4], "white": W})
	body_light(st, "star_light", 24, {"steady_glow": U[5], "steady_k": 0.25, "spark": mixc(U[5], W, 0.6), "spark_k": 0.35})
	var F := field_tex(S * 5 + 1, 256, 128, [8, 16, 32])
	var pr := {"F": F, "G": G, "U": U, "GM": GM}
	sky("Curtains", "aurora", pr.merged({"dither": false}), {"layer": "soft"})
	sky("Hems", "aurora", pr.merged({"dither": true}))
	sky("CurtainsLight", "aurora_light", pr, {"layer": "light"})
	var data := rays_data()
	bodies("Rays", data.get_width(), "rays", "ray", 224, {"data": asset("_rays", data), "frames": float(data.get_height()),
		"low": G[5], "mid": mixc(G[5], U[5], 0.5), "high": U[5], "foot": G[6]}, {"layer": "soft"})


## aurora.js curtain()'s rays, for every frame at the reference's own clock: row f, one texel a ray (x, hem, h, k).
func rays_data() -> Image:
	var fd := field_data(S * 5 + 1, 256, 128, [8, 16, 32])
	var n := int(roundf(D * 30.0))
	var all := []
	var most := 1
	var t := 0.0
	for f in n:
		var rays := []
		var breath := 0.75 + 0.25 * sin(TAU * t / D - 1.2)
		var fast := 256.0 * 2.0 * t / D
		var slow := 256.0 * t / D
		for ci in 3:
			var c: Array = CURTAINS[ci]
			var p1 := 0.0
			var p2 := 0.0
			var last_x := -999.0
			var s: float = c[8]
			while s < c[9]:
				var x: float = s + c[4] * sin(TAU * s / c[5] + TAU * c[11] * t / D + ci * 2) + 5.0 * sin(TAU * s / 64.0 + TAU * c[13] * t / D + ci)
				if x < -162.0 or x >= 161.0:
					s += 0.5
					continue
				var hem: float = c[0] + c[1] * s + c[2] * sin(TAU * s / c[3] + TAU * c[12] * t / D + ci * 1.7) + c[10] * sin(TAU * s / 23.0 - (TAU * 7.0 * t / D + ci))
				var env := smooth(c[8], c[8] + 60.0, s) * (1.0 - smooth(c[9] - 70.0, c[9], s))
				var r1 := clampf((fsample(fd, 256, 128, s * 5.0 - fast + ci * 40, 10 + ci * 30) - 0.38) * 3.2, 0.0, 1.0)
				var r2 := clampf((fsample(fd, 256, 128, s * 4.3 + fast * 0.7 + ci * 90, 50 + ci * 13) - 0.35) * 3.0, 0.0, 1.0)
				var patch := fsample(fd, 256, 128, s * 0.7 + slow + ci * 17, 80 + ci * 9)
				var k: float = c[7] * env * breath * (0.2 + 0.8 * r1) * (0.3 + 1.4 * maxf(0.0, patch - 0.3))
				if k < 0.01:
					s += 0.5
					continue
				var h: float = c[6] * (0.45 + 0.75 * r2) * (0.75 + 0.5 * patch)
				if p1 > 0.75 and p1 >= p2 and p1 >= r1 and absf(x - last_x) > 2.0 and k > 0.25:
					rays.append(Color(x, hem - 1.0, roundf(h * 0.9), minf(0.85, k * 0.9)))
					last_x = x
				p2 = p1
				p1 = r1
				s += 0.5
		most = maxi(most, rays.size())
		all.append(rays)
		t += 1.0 / 30.0
	var img := Image.create(most, n, false, Image.FORMAT_RGBAF)
	for f in n:
		for i in all[f].size():
			img.set_pixel(i, f, all[f][i])
	return img
