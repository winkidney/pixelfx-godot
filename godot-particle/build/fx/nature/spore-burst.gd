# reimagined-from: src/fx/nature/spore-burst.js@38e27a8cd8d09e0a5b7b12510d1300d51c4dfaea
# Spore burst: A toadstool pushes up, swells and trembles as its gills glow, then squashes and puffs a lumpy cloud of
# glowing spores that billows up and drifts down twinkling.
# The toadstool is a shader (fx/nature/_toadstool.gdshader) drawing it as the original does at its growth, squash and
# stretch, gill glow and sink, keyed every frame from the original's curves. The cloud is puffs (a lumpy gas puff
# drawn the original's way at build time: a dark belly, a body, a lit cap) shoved up and out from under the cap,
# swelling, rising and thinning on the soft layer; spores (motes streaking, flakes drifting down), twinkles, dust
# and grit are emitters; streaks gather to the gills as it charges; a sparkle, a flash and a cool glow riding the
# cloud are the light.
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const GROW := 0.32
const PUFF := 0.8
const SINK := 2.15


static func out_back(x: float, s: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return 1.0 + (s + 1.0) * pow(x - 1.0, 3.0) + s * pow(x - 1.0, 2.0)


func g_at(t: float) -> float:
	return out_back(clampf(t / GROW, 0.0, 1.0), 1.6) * (1.0 - N.in_cubic(clampf((t - SINK) / 0.45, 0.0, 1.0)))


func charge(t: float) -> float:
	return N.smooth(GROW, PUFF, t)


func squash(t: float) -> Vector2:
	if t < PUFF:
		var k := charge(t)
		var j := sin(t * 70.0) * 0.04 * k
		return Vector2(1.0 + 0.28 * k + j, 1.0 + 0.22 * k - j)
	var e := t - PUFF
	var sp := exp(-e * 7.0) * cos(e * 26.0)
	return Vector2(1.0 + 0.25 * sp, 1.0 - 0.35 * sp)


func gill_glow(t: float) -> float:
	if t < PUFF:
		var c := charge(t)
		return c * (0.75 + 0.25 * sin(t * (20.0 + 30.0 * c)))
	return maxf(0.0, 1.0 - (t - PUFF) * 1.5)


## A puff of gas (the original's gasPuff) at radius r, as a texture: a darker belly hanging low, a body, a denser
## core, a lit cap up and to the left, a pale rim on top.
func puff_texture(r: float, K: PackedColorArray, hi: bool) -> ImageTexture:
	var n := int(ceil(r * 1.3)) + 2
	var img := Image.create(2 * n + 1, 2 * n + 1, false, Image.FORMAT_RGBA8)
	var discs := [[Vector2(r * 0.06, r * 0.28), r * 0.9, K[2], 0.55], [Vector2.ZERO, r, K[4], 0.45],
		[Vector2(r * 0.03, -r * 0.02), r * 0.76, K[4], 0.5], [Vector2(-r * 0.2, -r * 0.34), r * 0.52, K[6], 0.45]]
	if hi:
		discs.append([Vector2(-r * 0.3, -r * 0.55), r * 0.26, K[7], 0.32])
	for j in 2 * n + 1:
		for i in 2 * n + 1:
			var p := Vector2(i - n + 0.5, j - n + 0.5)
			var c := Color(0, 0, 0, 0)
			for d in discs:
				if p.distance_to(d[0]) > d[1]:
					continue
				var a: float = d[3] * 1.25
				var oa := a + c.a * (1.0 - a)
				var k := a / oa
				c = Color(Color(d[2]).r * k + c.r * (1.0 - k), Color(d[2]).g * k + c.g * (1.0 - k), Color(d[2]).b * k + c.b * (1.0 - k), oa)
			if c.a > 0.0:
				img.set_pixel(i, j, c)
	return ImageTexture.create_from_image(img)


func make() -> void:
	var K: PackedColorArray = root.ramps.palette
	var Cs: PackedColorArray = root.ramps.cap
	var Sm: PackedColorArray = root.ramps.stem
	var D: float = meta.duration
	ground()

	# a ring of glow on the floor round it while it charges and puffs
	var ring_cols := []
	var ring_offs := []
	for x in range(-20, 21):
		ring_cols.append(Color(K[5] if absi(x) < 10 else K[4], 1.0 - absi(x) / 21.0))
		ring_offs.append((x + 20) / 41.0)
	var floor_ring := line("FloorRing", PackedVector2Array([Vector2(-20, 0.5), Vector2(21, 0.5)]), {"gradient": gradient(ring_cols, ring_offs), "back": true})
	var floor_glow := glow("FloorGlow", 32, {"radius": 30, "color": K[4], "alpha": 0.0}, {"at": Vector2(0, -2), "back": true})
	var rk := []
	var rg := []
	for i in int(D * 30.0) + 2:
		var t := i / 30.0
		var k := charge(t) * (1.0 - N.smooth(PUFF + 0.2, PUFF + 1.2, t))
		rk.append([t, k])
		rg.append([t, 0.25 * k])
	key(floor_ring, "modulate:a", rk)
	key(floor_glow, "material:shader_parameter/alpha", rg)

	# grit and dust kicked up as it pushes out of the floor
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 10, "lifetime": 0.65, "randomness": 0.2, "one_shot": true,
		"explosiveness": 1.0, "texture": "dot1", "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 30,
		"speed": [45, 125], "gravity": Vector2(0, 950), "initial": gradient([Sm[1], Sm[2]]), "collide": {"bounce": 0.1, "friction": 1.0}})
	emit(grit, 0.0)
	var kick := particles("Kick", {"layer": "soft", "at": Vector2(0, -1), "amount": 4, "lifetime": 0.55, "one_shot": true,
		"explosiveness": 1.0, "texture": "disc5", "emit": {"box": Vector2(4, 0.5)}, "dir": 0, "spread": 180, "speed": [10, 40],
		"damping": [40, 60], "scale_curve": [[0, 0.7], [1, 1.4]], "ramp": gradient([Color(Sm[1], 0.7), Color(Sm[1], 0.4), Color(Sm[1], 0.1)])})
	emit(kick, 0.0)

	# the toadstool, keyed every frame
	var body := shape("Toadstool", load("res://addons/pixelfx_particles/fx/nature/_toadstool.gdshader"), Vector2(64, 64),
		{"ramp": ramp("palette", {"stops": 8}), "cap": ramp("cap", {"stops": 6}), "stem": ramp("stem", {"stops": 5})},
		{"at": Vector2(0, -28)})
	var gills := glow("GillLight", 50, {"radius": 10, "color": K[5], "alpha": 0.0})
	var kk := {"g": [], "sx": [], "sy": [], "glow": [], "sink": []}
	var gp := []
	var gr := []
	var ga := []
	for i in int(D * 30.0) + 2:
		var t := i / 30.0
		var g := g_at(t)
		var sq := squash(t)
		var gl := gill_glow(t)
		var sink := N.in_cubic(clampf((t - SINK) / 0.45, 0.0, 1.0)) * 20.0
		kk.g.append([t, g])
		kk.sx.append([t, sq.x])
		kk.sy.append([t, sq.y])
		kk.glow.append([t, gl])
		kk.sink.append([t, sink])
		var top := sink - 17.0 * g
		gp.append([t, Vector2(0, top + 3)])
		gr.append([t, 17.0 * sq.x * g * 1.5 + 6.0])
		ga.append([t, 0.5 * gl if (g >= 0.05 and gl > 0.05 and top + 1.0 <= 0.0) else 0.0])
	for k in kk:
		key(body, "material:shader_parameter/" + k, kk[k], "nearest")
	key(gills, "position", gp, "nearest")
	key(gills, "material:shader_parameter/radius", gr, "nearest")
	key(gills, "material:shader_parameter/alpha", ga, "nearest")

	# charging: spores gather toward the gills
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 48:
		var a := rng.randf_range(PI * 1.05, PI * 1.95)
		var d := rng.randf_range(20, 38)
		pts.append(Vector2(cos(a) * d, sin(a) * d * 0.7))
	var gather := particles("Gather", {"at": Vector2(0, -18), "amount": 3, "lifetime": 0.25, "emitting": false, "texture": "streak4",
		"align": true, "emit": {"points": pts}, "radial": [-1100, -800], "color": K[6], "alpha_curve": [[0, 1], [0.8, 1], [1, 0]]})
	emit(gather, GROW, PUFF - 0.05)

	# the puff: a flash, a sparkle, the cloud's light
	var flash := glow("PuffFlash", 32, {"radius": 30, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -22)})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [PUFF - 0.001, 0.0], [PUFF, 0.6 + 0.6], [PUFF + 0.05, 0.2], [PUFF + 0.1, 0.0]])
	var cool := glow("PuffLight", 72, {"radius": 70, "color": K[5], "alpha": 0.0}, {"at": Vector2(0, -28)})
	var ck := [[0.0, 0.0], [PUFF - 0.001, 0.0]]
	var cr := []
	for i in 19:
		var k := 1.0 - i / 18.0
		ck.append([PUFF + 0.05 * i, 0.55 * k * k])
		cr.append([PUFF + 0.05 * i, 70.0 * (0.55 + 0.45 * k)])
	key(cool, "material:shader_parameter/alpha", ck)
	key(cool, "material:shader_parameter/radius", cr)
	var star := gradient([K[6], K[7], K[6]], [0.0, 0.3, 0.7])
	for k in 3:
		var arm := roundf(10.0 * (1.0 - (k / 30.0) / 0.1))
		for axis in [Vector2(1, 0), Vector2(0, 1)]:
			var sl := line("Sparkle%d%s" % [k, "H" if axis.x > 0 else "V"], PackedVector2Array([Vector2(0.5, -19.5) - axis * arm, Vector2(0.5, -19.5) + axis * arm]), {"gradient": star})
			show(sl, PUFF + k / 30.0, PUFF + (k + 1) / 30.0)
	var cloud_light := glow("CloudLight", 48, {"radius": 46, "color": K[5], "alpha": 0.0})
	key(cloud_light, "position", [[PUFF, Vector2(0, -24)], [PUFF + 0.6, Vector2(0, -42)], [PUFF + 1.6, Vector2(0, -52)], [PUFF + 2.2, Vector2(0, -56)]])
	key(cloud_light, "material:shader_parameter/alpha", [[0.0, 0.0], [PUFF, 0.0], [PUFF + 0.15, 0.32], [PUFF + 1.0, 0.32], [PUFF + 1.6, 0.18], [PUFF + 2.2, 0.0]])

	# the cloud: lumps shoved up and out from under the cap, swelling as they go, rising, thinning out
	var fade := [[0, 0], [0.08, 1], [0.4, 1], [1, 0]]
	var cloud := {"layer": "soft", "at": Vector2(0, -20), "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"emit": {"box": Vector2(8, 3)}, "dir": -90, "spread": 60, "speed": [35, 95], "damping": [65, 100],
		"local": true, "alpha_curve": fade, "color": Color(1, 1, 1, 0.62)}
	var big := particles("Cloud", cloud.merged({"amount": 18, "lifetime": 2.1, "randomness": 0.15, "texture": puff_texture(12.0, K, true),
		"scale": [0.75, 1.15], "scale_curve": [[0, 0.33], [0.15, 0.75], [0.6, 1.0], [1, 1.0]]}))
	emit(big, PUFF)
	# the puffs' own push dies away; the cloud as a whole rises (the emitters carry them, local coordinates)
	key(big, "position", [[PUFF, Vector2(0, -20)], [PUFF + 2.3, Vector2(0, -20 - 9.0 * 2.3)]])
	var mid := particles("CloudSmall", cloud.merged({"amount": 12, "lifetime": 1.8, "randomness": 0.15, "texture": puff_texture(9.0, K, true),
		"scale": [0.85, 1.15], "scale_curve": [[0, 0.35], [0.15, 0.75], [0.6, 1.0], [1, 1.0]]}))
	emit(mid, PUFF)
	key(mid, "position", [[PUFF, Vector2(0, -20)], [PUFF + 2.3, Vector2(0, -20 - 9.0 * 2.3)]])
	for sd in [-1, 1]:
		var low := particles("Low%s" % ("L" if sd < 0 else "R"), cloud.merged({"at": Vector2(sd * 9, -5), "amount": 3, "lifetime": 1.0,
			"randomness": 0.15, "texture": puff_texture(5.0, K, false), "emit": {"box": Vector2(3, 1)}, "dir": 90 - sd * 90 - sd * 8,
			"spread": 6, "speed": [30, 70], "damping": [50, 80],
			"scale_curve": [[0, 0.5], [0.3, 0.9], [1, 1.0]]}))
		emit(low, PUFF)
		key(low, "position", [[PUFF, Vector2(sd * 9, -5)], [PUFF + 1.1, Vector2(sd * 9, -5 - 6.0 * 1.1)]])

	# spores: motes streaking out and flakes drifting down, twinkling stars, dust along the floor
	var spore_cols := gradient([K[7], K[6], K[6], K[5]])
	var motes := particles("Motes", {"at": Vector2(0, -20), "amount": 20, "lifetime": 1.5, "randomness": 0.35, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "streak3", "align": true, "emit": {"box": Vector2(5, 1)}, "dir": -90,
		"spread": 80, "speed": [14, 56], "damping": [6, 14], "initial": spore_cols, "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
	emit(motes, PUFF)
	var mote_light := particles("MoteLight", {"layer": "light", "at": Vector2(0, -20), "amount": 20, "lifetime": 1.5, "randomness": 0.35,
		"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "glow8", "emit": {"box": Vector2(5, 1)}, "dir": -90,
		"spread": 80, "speed": [14, 56], "damping": [6, 14], "color": Color(K[6], 0.35), "alpha_curve": [[0, 1], [1, 0]]})
	mote_light.seed = motes.seed
	emit(mote_light, PUFF)
	for f in [["Flakes", "dot1", 12], ["FlakesBig", "plus3", 8]]:
		var fl := particles(f[0], {"at": Vector2(0, -20), "amount": f[2], "lifetime": 1.6, "randomness": 0.35, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": f[1], "emit": {"box": Vector2(5, 1)}, "dir": -90, "spread": 80,
			"speed": [28, 112], "damping": [70, 120], "gravity": Vector2(0, 16), "initial": spore_cols,
			"alpha_curve": [[0, 1], [0.66, 1], [1, 0]], "turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.02]}})
		emit(fl, PUFF)
	var stars := particles("Stars", {"at": Vector2(0, -26), "amount": 6, "lifetime": 0.45, "randomness": 0.3, "one_shot": true,
		"explosiveness": 0.3, "emitting": false, "texture": "star5", "emit": {"box": Vector2(20, 14)}, "speed": [6, 6],
		"color": K[7], "alpha_curve": [[0, 1], [0.5, 0.5], [0.7, 1], [1, 0]]})
	emit(stars, PUFF + 0.05)
	for sd in [-1, 1]:
		var dust := particles("Dust%s" % ("L" if sd < 0 else "R"), {"layer": "soft", "at": Vector2(sd * 7, -1), "amount": 4,
			"lifetime": 0.7, "randomness": 0.3, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "disc7",
			"emit": {"box": Vector2(3, 0.5)}, "dir": 90 - sd * 90 - sd * 5, "spread": 4, "speed": [30, 90], "damping": [80, 130],
			"scale_curve": [[0, 0.6], [1, 1.3]], "ramp": gradient([Color(K[3], 0.7), Color(K[3], 0.45), Color(K[3], 0.15)])})
		emit(dust, PUFF)

	# after it: spores keep drifting down out of the cloud, twinkling; dust as it sinks back into the floor
	var drift := particles("Drift", {"at": Vector2(0, -50), "amount": 5, "lifetime": 1.2, "randomness": 0.25, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(40, 20)}, "dir": 90, "spread": 30, "speed": [4, 14],
		"initial": gradient([K[7], K[6]]), "alpha_curve": [[0, 0], [0.1, 1], [0.66, 1], [1, 0]],
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(drift, PUFF + 0.1, 1.95)
	var settle := particles("Settle", {"layer": "soft", "at": Vector2(0, -1), "amount": 4, "lifetime": 0.45, "emitting": false,
		"texture": "disc5", "emit": {"box": Vector2(5, 0.5)}, "dir": 0, "spread": 180, "speed": [10, 30], "damping": [30, 50],
		"ramp": gradient([Color(Sm[1], 0.7), Color(Sm[1], 0.4), Color(Sm[1], 0.1)])})
	emit(settle, SINK, SINK + 0.4)
