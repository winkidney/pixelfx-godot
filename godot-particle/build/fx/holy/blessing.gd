# reimagined-from: src/fx/holy/blessing.js@e3e0ed7add397cb71b4c001e6633497aad44fb3c
# Blessing: A soft cone of light rests on the character from above; sparkles drift down through it, twinkling, and wink out where they land on the head and shoulders.
# loop, 3.00 s, 80x128 canvas, origin [40.0, 108.0], backdrop ground
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The cone is a shader behind the character (fx/holy/_bless_cone.gdshader: a soft gold haze of four shimmering rays,
# two of them as fine lines with light running down them) and its light (fx/holy/_bless_cone_light.gdshader). The
# rim of light on the head and shoulders is drawn at build time from the stand-in's own pixels; the pool on the
# floor is drawn once too. Sparkles are particles thrown down the cone along its own slant (directed points),
# stepping through the original's twinkling sparkle: those over the character live until they reach it and a
# wink flares on the head and shoulders; the ones beside it drift to the floor. Fine motes hang in the light.
extends "res://build/fx/holy/_holy.gd"

const TOP := -108.0


static func half_w(y: float) -> float:
	return lerpf(5.0, 20.0, (y - TOP) / -TOP)


func make() -> void:
	# the cone, behind the character
	var haze := shape("Haze", holy_shader("bless_cone"), Vector2(52, 110), {"mode": 0, "c6": C[6], "translucent": true}, {"at": Vector2(0, -54), "back": true})
	loop_t(haze)
	var lines := shape("Lines", holy_shader("bless_cone"), Vector2(52, 110), {"mode": 1, "c6": C[6]}, {"at": Vector2(0, -54), "back": true})
	loop_t(lines)
	var cone_light := shape("ConeLight", holy_shader("bless_cone_light"), Vector2(52, 110), {"c4": C[4]}, {"at": Vector2(0, -54)})
	loop_t(cone_light)
	glow("FootGlow", 32, {"radius": 30, "color": C[4], "alpha": 0.22}, {"at": Vector2(0, -4)})

	# light catching the top of the head and the shoulders
	var img: Image = load(EFFECT.STAND_INS[maxi(1, root.actor)]).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var rim := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tops := PackedVector2Array()
	for i in w:
		for j in h:
			var c := img.get_pixel(i, j)
			if c.a < 0.5 or c.get_luminance() < 0.15:
				continue
			rim.set_pixel(i, j, Color(c.lerp(C[6], 0.35), 1.0))
			tops.append(Vector2(i - floorf(w / 2.0) + 0.5, j - h - 0.5))
			break
	sprite("Rim", asset("rim.png", rim), {"centered": false, "at": Vector2(-floorf(w / 2.0), -h), "layer": "prop"})
	glow("BodyGlow", 22, {"radius": 20, "color": C[5], "alpha": 0.22}, {"at": Vector2(0, -30)})

	# the floor catches it: a lit line and a pool fading out into the stone
	var pool := Image.create(49, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in range(-24, 25):
			var u := Vector2(x / 24.0, y / 4.0).length()
			if u >= 1.0:
				continue
			var c: Color = ((C[5] if y else Color.WHITE) if u < 0.3 else (C[5] if u < 0.6 else (C[4] if u < 0.85 else C[3])))
			pool.set_pixel(x + 24, y, Color(c, sqrt(1.0 - u) if y == 0 else (1.0 - u) * 0.7))
	sprite("Pool", asset("pool.png", pool), {"centered": false, "at": Vector2(-24, 0)})

	# sparkles drifting down the cone, twinkling: over the character they live until they reach it
	var NF := 16
	var twinkle := func(size: float) -> Callable:
		return func(u: float) -> float: return maxf(1.0, size * (0.6 + 0.4 * sin(u * 20.0)) * minf(1.0, u * 8.0))
	var slant := func(q0: float, q1: float) -> Array:
		var pts := PackedVector2Array()
		var nrm := PackedVector2Array()
		for k in 24:
			var q := lerpf(q0, q1, (k + 0.5) / 24.0)
			pts.append(Vector2(q * half_w(TOP + 6), TOP + 6))
			nrm.append(Vector2(q * 15.0 / 108.0, 1.0))
		return [pts, nrm]
	var mid: Array = slant.call(-0.4, 0.4)
	var over := particles("SparklesOver", {"amount": 7, "lifetime": 2.25, "life_random": 0.12, "emit": {"points": mid[0], "normals": mid[1]}, "dir": 0,
		"speed": [26, 30], "texture": asset("sparkle.png", sparkle_strip(NF, twinkle.call(2.0), C[6], C[5], 3))})
	flip(over, NF)
	twin(over, {"texture": "glow8", "modulate": Color(C[5], 0.35)})
	var k := 0
	for side in [[-0.9, -0.4], [0.4, 0.9]]:
		var sl: Array = slant.call(side[0], side[1])
		var p := particles("SparklesSide%d" % k, {"amount": 5, "lifetime": 3.0, "life_random": 0.1, "emit": {"points": sl[0], "normals": sl[1]}, "dir": 0,
			"speed": [22, 34], "texture": asset("sparkle%d.png" % k, sparkle_strip(NF, twinkle.call(1.7 + 0.7 * k), C[6], C[5], 3))})
		flip(p, NF)
		twin(p, {"texture": "glow8", "modulate": Color(C[5], 0.35)})
		k += 1
	# they wink out where they land on the head and shoulders
	var WF := 8
	var wink := particles("Winks", {"amount": 1, "lifetime": 0.32, "emit": {"points": tops},
		"texture": asset("wink.png", sparkle_strip(WF, func(u: float) -> float: return 3.0 * (1.0 - u * 2.2) + 1.0 if u < 0.45 else 0.0, Color.WHITE, C[6], 4))})
	flip(wink, WF)
	twin(wink, {"texture": "glow16", "modulate": Color(1, 1, 1, 0.4)})

	# fine motes hanging in the light
	var field := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 96:
		var y := TOP + 10 + rng.randf_range(0, 90)
		field.append(Vector2(rng.randf_range(-0.8, 0.8) * half_w(y), y))
	particles("Motes", {"amount": 8, "lifetime": 2.4, "life_random": 0.5, "emit": {"points": field}, "dir": 90, "speed": [3, 6],
		"texture": "dot1", "ramp": gradient([Color(C[6], 0.0), Color(C[6], 0.5), Color.WHITE, Color(C[6], 0.5), Color(C[6], 0.0)], [0.0, 0.2, 0.4, 0.6, 0.8])})
