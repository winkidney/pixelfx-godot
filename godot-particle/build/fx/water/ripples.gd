# reimagined-from: src/fx/water/ripples.js@d3352f45bc85a93811e0aa628c49cbc36cc5c027
# Ripples: A drop plinks on still dark water and rings spread out across it at a low angle: the swell of each ring catches the light, crests glint, and they fade into the calm.
# loop, 2.00 s, 136x52 canvas, origin [68.0, 30.0], backdrop ground
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The water is a canvas shader (fx/water/_swell.gdshader): a see-through patch shading with the slope of the swell
# each ring carries. The rings are four ripple-ring shaders (fx/water/_ring.gdshader, the original's ring()), one per
# ring alive at once, their radius, strength, crest gap and wobble keyed from the original's curves. Each ring starts
# with a white fleck and a bead thrown up and back; glints wink on the near crests; light pools where they start.
extends "res://build/fx/water/_water.gd"

const D := 2.0
const SY := 0.26
const EVERY := 0.5
const LIFE := 2.0
const RMAX := 60.0
const PATCH := 64.0


static func radius(a: float) -> float:
	return 2.0 + (RMAX - 2.0) * out_cubic(a / LIFE)


static func power(a: float) -> float:
	return pow(maxf(0.0, 1.0 - a / LIFE), 1.5) * minf(1.0, a / 0.08)


## The age of ring `i` (born at i * EVERY, every loop) at t.
static func age(i: int, t: float) -> float:
	return fposmod(t - i * EVERY, D)


func make() -> void:
	var surf := shape("Water", water_shader("swell"), Vector2(PATCH * 2.0, ceilf(PATCH * SY) * 2.0 + 2.0),
		{"pal": C, "dur": D, "every": EVERY, "life": LIFE, "rmax": RMAX, "patch_r": PATCH, "sy": SY, "translucent": true},
		{"back": true})
	loop_t(surf)

	# a cool light on the water, brightest where the rings start
	glow("Light", 40, {"radius": 40, "squash": 1.0, "color": C[4], "alpha": 0.14})
	glow("LightCore", 14, {"radius": 14, "color": C[5], "alpha": 0.12})

	var n := int(LIFE / EVERY)
	for i in n:
		var rg := water_ring("Ring%d" % i, RMAX + 4.0, {"sy": SY, "n": 2.0, "seed": float(i + 1)})
		sample_shader(rg, func(t: float) -> Dictionary:
			var a := age(i, t)
			var k := power(a)
			return {"r": radius(a), "k": 0.85 * k, "gap": 3.0 + a * 1.4, "hot": a < 0.14, "glint": k if a > 0.1 else 0.0,
				"wob": 0.4 + a * 1.1})

	# each ring starts with a drop: a white fleck, a bead thrown up and back down, a flash of light
	var fleck := group("Fleck")
	dot("FleckL", C[6], Vector2(-1, 0), {"parent": fleck, "size": Vector2(3, 1)})
	dot("FleckC", C[7], Vector2(0, 0), {"parent": fleck})
	var flash := glow("Flash", 8, {"radius": 8, "color": C[5], "alpha": 0.0})
	var bead := group("Bead")
	dot("BeadTop", C[7], Vector2(0, 0), {"parent": bead})
	dot("BeadLow", C[5], Vector2(0, 1), {"parent": bead})
	var vis := []
	var bvis := []
	var bpos := []
	var fl := []
	for f in int(D * 30.0) + 1:
		var t := f / 30.0
		var on := false
		var b_on := false
		var h := 0.0
		var k := 0.0
		for i in n:
			var a := age(i, t)
			if a < 0.08:
				on = true
				k = maxf(k, 0.5 * (1.0 - a / 0.08))
			var b := a - 0.04
			var hh := 90.0 * b - 0.5 * 700.0 * b * b
			if b > 0.0 and hh > 0.0:
				b_on = true
				h = hh
		vis.append([t, on])
		bvis.append([t, b_on])
		bpos.append([t, Vector2(0, floorf(-h))])
		fl.append([t, k])
	key(fleck, "visible", vis, "nearest")
	key(bead, "visible", bvis, "nearest")
	key(bead, "position", bpos, "nearest")
	key(flash, "material:shader_parameter/alpha", fl, "nearest")

	# glints ride the near crests, winking: the original's cycle of ten, replayed
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for g in 10:
		var born := rng.randf() * D
		var life := rng.randf_range(0.25, 0.45)
		var ring_i := rng.randi() % n
		var ang := rng.randf_range(0.3, PI - 0.3)
		glint("Glint%d" % g, func(t: float) -> Array:
			var ga := fposmod(t - born, D)
			var a := age(ring_i, t)
			var R := radius(a)
			var k := sin(PI * ga / life) * power(a) if ga < life else 0.0
			return [cos(ang) * R, sin(ang) * R * SY, k if (k >= 0.15 and R >= 6.0) else 0.0])
