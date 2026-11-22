# reimagined-from: src/fx/lightning/storm-cloud.js@ba598245265c83ec0ecaa46d0b3e6ec59e0aaebc
# Storm cloud: A storm cloud boils overhead, billows lit from inside by flickering discharges, ragged scud under its flat dark base; rain slants down and once a loop a bolt cracks to the floor.
# loop, 3.00 s, 168x176 canvas, origin [84.0, 164.0], backdrop ground
# The cloud is one shader (fx/lightning/_cloud.gdshader): the original's billows fused into a field, drifting and
# boiling on seamless clocks, shaded as one mass and lit from inside, a billow at a time, on the original's
# discharge frames; scud is the fog shader drifting under the base; rain is aligned streaks landing on the floor with
# a splash emitter along it; a crackle crawls the belly on the bright discharges; once a loop a forked bolt
# (fx/lightning/_volt.gd) flickers to the floor with a flash, light up the cloud and sparks thrown where it lands.
extends "res://build/fx/lightning/_base.gd"

const N := 90
const BASE := -100.0
const TOP := -156.0
const VIS := 0.6391
const BILLOWS := [
	[-6, -132, 17], [18, -127, 14], [-28, -122, 12], [38, -118, 10], [0, -142, 12],
	[14, -149, 19, 0.38], [40, -148, 14, 0.34],
	[-48, -113, 10], [55, -110, 9], [-17, -115, 13], [22, -113, 12],
	[-42, -104, 11], [-10, -104, 12], [20, -104, 11], [48, -103, 9], [-63, -104, 7], [66, -103, 6],
]
const FLASHES := [[7, 2, 0.8], [8, 9, 0.55], [29, 1, 0.75], [31, 10, 1.0], [33, 3, 0.5], [70, 0, 0.8], [71, 4, 0.55], [72, 5, 0.35]]
const BOLT := 52
const BOLT_B := 12
const BK := [1.0, 0.7, 0.3, 0.95, 0.5, 0.75, 0.2]
const BX0 := -12.0
const BX1 := 2.0


func make() -> void:
	ground()
	var C := pal()
	var K: PackedColorArray = root.ramps.cloud
	var RN: PackedColorArray = root.ramps.rain

	# rain: slanting streaks from the belly, splashing on the floor
	var drop := Image.create(1, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		drop.set_pixel(0, y, RN[3] if y >= 4 else (RN[2] if y >= 2 else RN[1]))
	var fall := rad_to_deg(atan2(1.0, -0.18))
	particles("Rain", {"at": Vector2(0, BASE + 4), "amount": 34, "lifetime": 0.62, "randomness": 0.2, "texture": ImageTexture.create_from_image(drop),
		"align": true, "emit": {"box": Vector2(62, 1)}, "dir": fall, "speed": [194, 244], "collide": {"hide": true, "size": 1}})
	particles("Splash", {"at": Vector2(-17, -1), "amount": 7, "lifetime": 0.12, "texture": "dot1", "emit": {"box": Vector2(62, 0.5)},
		"dir": -90, "spread": 70, "speed": [20, 40], "gravity": Vector2(0, 300), "initial": gradient([RN[3], RN[2]], [0.0, 0.5])})

	# scud hanging under the base, drifting off on the wind
	fog("Scud", Vector2(150, 20), {"profile": Vector4(BASE + 1, BASE + 4, BASE + 7, BASE + 10), "drift": Vector2(1, 0),
		"period": Vector2(256 / 1.0, 64 / 4.0), "low": K[3], "high": K[2], "crest": K[3], "alpha": 0.5, "threshold": 0.36,
		"contrast": 2.4}, {"at": Vector2(0, BASE + 6)})

	# the cloud
	var bl := PackedVector4Array()
	for b in BILLOWS:
		bl.append(Vector4(b[0], b[1], b[2], b[3] if b.size() > 3 else 1.0))
	var ramp := PackedColorArray([K[0], K[1], K[2], K[3], K[4], K[5], K[6], C[3], C[4], C[5], C[6]])
	var cloud := shape("Cloud", load("res://addons/pixelfx_particles/fx/lightning/_cloud.gdshader"), Vector2(168, 70),
		{"billows": bl, "ramp": ramp, "base_y": BASE, "top_y": TOP, "flash": Vector2(-1, 0)}, {"at": Vector2(0, -127)})
	key(cloud, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, 1.0]])

	# light inside: the lit billow's glow, the sky's
	var inner := glow("Inner", 64, {"radius": 30, "color": C[4], "alpha": 0.0})
	var sky := glow("Sky", 82, {"radius": 80, "color": C[2], "alpha": 0.05}, {"at": Vector2(0, -122)})
	var belly := volt("Belly", Vector2.ZERO, Vector2(1, 0), {"style": 1, "k": 0.6, "jag": 0.25, "forks": 0.5, "rate": 0.0, "light": 0.4, "visible": false})

	# the bolt
	var bolt := volt("Bolt", Vector2(BX0, BASE - 3), Vector2(BX1, 0), {"jag": 0.22, "forks": 0.3, "rate": 0.0, "visible": false})
	var spot := orb("Spot", Vector2(BX1, -1), [[4.5, C[2]], [3.5, C[5]], [2.0, Color.WHITE]])
	var l1 := glow("BoltSky", 80, {"radius": 78, "color": C[3], "alpha": 0.0}, {"at": Vector2(BX1, -22)})
	var l2 := glow("BoltFoot", 20, {"radius": 18, "color": C[5], "alpha": 0.0}, {"at": Vector2(BX1, -3)})
	var l3 := glow("BoltRoot", 86, {"radius": 84, "color": C[4], "alpha": 0.0}, {"at": Vector2(BX0, BASE)})
	var sp := sparks("Sparks", {"at": Vector2(BX1, -1), "amount": 16, "lifetime": 0.6, "randomness": 0.5, "dir": -90, "spread": 75, "speed": [60, 200]})
	emit(sp, BOLT / FPS)

	var ks := {"flash": [], "in_p": [], "in_r": [], "in_a": [], "sky": [], "bv": [], "bf": [], "bt": [], "bs": [], "v": [], "k": [], "hero": [],
		"thick": [], "r0": [], "r1": [], "r2": [], "l1": [], "l2": [], "l3": []}
	var rng := RandomNumberGenerator.new()
	rng.seed = 87
	for f in N + 1:
		var ff := f % N
		var st := maxf(0.0, (f - 0.5) / FPS)
		var ph := ff / float(N)
		var lit := Vector2(-1, 0)
		for fl in FLASHES:
			if fl[0] == ff:
				lit = Vector2(fl[1], fl[2])
		var ba := ff - BOLT
		var bolt_on := ba >= 0 and ba < BK.size()
		if bolt_on:
			lit = Vector2(BOLT_B, maxf(lit.y if lit.x == BOLT_B else 0.0, BK[ba]))
		ks.flash.append([st, lit])
		if lit.x >= 0:
			var b: Array = BILLOWS[int(lit.x)]
			var sq: float = b[3] if b.size() > 3 else 1.0
			ks.in_p.append([st, Vector2(b[0], b[1])])
			ks.in_r.append([st, b[2] / VIS * VIS * (1.6 if sq < 1.0 else 2.2)])
			ks.in_a.append([st, 0.4 * lit.y])
		else:
			ks.in_a.append([st, 0.0])
		ks.sky.append([st, 0.05 + 0.22 * maxf(0.0, lit.y)])
		# a discharge crawls along the belly now and then
		var crawl := lit.x >= 0 and lit.y > 0.6 and not bolt_on
		ks.bv.append([st, crawl])
		if crawl:
			var x: float = BILLOWS[int(lit.x)][0]
			ks.bf.append([st, Vector2(x - rng.randf_range(12, 22), BASE - rng.randf_range(2, 6))])
			ks.bt.append([st, Vector2(x + rng.randf_range(12, 22), BASE - rng.randf_range(1, 5))])
			ks.bs.append([st, ff])
		var k: float = BK[ba] if bolt_on else 0.0
		ks.v.append([st, bolt_on])
		ks.k.append([st, k])
		ks.hero.append([st, ba == 0])
		ks.thick.append([st, 1.15 if ba == 0 else 1.0])
		ks.r0.append([st, 3.0 * k + 1.5 if bolt_on else 0.0])
		ks.r1.append([st, 3.0 * k + 0.5 if bolt_on else 0.0])
		ks.r2.append([st, 2.0 * k])
		ks.l1.append([st, 0.5 * k])
		ks.l2.append([st, 0.45 * k])
		ks.l3.append([st, 0.3 * k])
	key(cloud, "material:shader_parameter/flash", ks.flash, "nearest")
	key(inner, "position", ks.in_p, "nearest")
	key(inner, "material:shader_parameter/radius", ks.in_r, "nearest")
	key(inner, "material:shader_parameter/alpha", ks.in_a, "nearest")
	key(sky, "material:shader_parameter/alpha", ks.sky, "nearest")
	key(belly, "visible", ks.bv, "nearest")
	key(belly, "from", ks.bf, "nearest")
	key(belly, "to", ks.bt, "nearest")
	key(belly, "step", ks.bs, "nearest")
	key(bolt, "visible", ks.v, "nearest")
	key(bolt, "k", ks.k, "nearest")
	key(bolt, "hero", ks.hero, "nearest")
	key(bolt, "thick", ks.thick, "nearest")
	for q in 3:
		key(spot[q], "material:shader_parameter/radius", ks["r%d" % q], "nearest")
	key(l1, "material:shader_parameter/alpha", ks.l1, "nearest")
	key(l2, "material:shader_parameter/alpha", ks.l2, "nearest")
	key(l3, "material:shader_parameter/alpha", ks.l3, "nearest")
