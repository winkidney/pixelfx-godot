# reimagined-from: src/fx/nature/healing-bloom.js@10f753d3d97181996cba65342cfb53c65be58d21
# Healing bloom: A sprout pushes up and unfurls, a bud swells and opens round a glowing golden heart in a flare of
# healing light; its petals lift away one by one as motes.
# The flower is a shader of its own (fx/nature/_bloom.gdshader: the original's shoot, leaves, bud, petals and heart
# and the lit floor line, all from a keyed `t`). Light is made here: streaks drawn into the bud, the pop (glows,
# motes, stars and a sparkle), a column of soft light, a ring blooming out on the floor (a far-half Line2D ellipse over
# a ring-shader band), the heart's pulsing glow; bevelled crosses and golden embers drift up as it blooms (particles
# with light twins on the same seed); the petals let go and flutter up (leaf sprites replaying the original's
# flight, flipping) and twinkle out; a little grit and dust as it sprouts.
extends "res://addons/pixelfx_particles/core/build.gd"

const NL := preload("res://build/fx/nature/_lib.gd")
const STEM := 0.42
const BUD := 0.75
const OPEN := 1.05
const LIFT := 1.7
const WILT := 2.4
const H := 36.0


static func grow(t: float) -> float:
	return NL.out_cubic(clampf(t / STEM, 0.0, 1.0)) * (1.0 - NL.in_cubic(clampf((t - WILT) / 0.6, 0.0, 1.0)))


static func top(t: float) -> Vector2:
	var sway := sin(t * 2.6) * 1.4 * NL.smooth(0.2, 0.6, t)
	return Vector2(sin(3.2) * 2.2 + sway, (1.0 - grow(t)) * H * 1.1 - H)


static func bloom(t: float) -> float:
	return NL.smooth(OPEN - 0.15, OPEN + 0.2, t) * (1.0 - NL.smooth(WILT - 0.2, WILT + 0.5, t))


## a bevelled cross of light, arms L px: upper/left arms lit, a dark bevel round it
static func cross_tex(L: int, C: PackedColorArray) -> ImageTexture:
	var n := 2 * L + 3
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ins := func(dx: int, dy: int) -> bool: return (dx == 0 and absi(dy) <= L) or (dy == 0 and absi(dx) <= L)
	for dy in range(-L - 1, L + 2):
		for dx in range(-L - 1, L + 2):
			if ins.call(dx, dy):
				img.set_pixel(dx + L + 1, dy + L + 1, C[6] if (dy < 0 or dx < 0) else C[5])
			elif L > 1 and (ins.call(dx - 1, dy) or ins.call(dx + 1, dy) or ins.call(dx, dy - 1) or ins.call(dx, dy + 1)):
				img.set_pixel(dx + L + 1, dy + L + 1, Color(C[2], 0.8))
	return ImageTexture.create_from_image(img)


func make() -> void:
	ground()
	var C: PackedColorArray = root.ramps.palette
	var Pt: PackedColorArray = root.ramps.petal
	var Ht: PackedColorArray = root.ramps.heart
	var D: float = meta.duration
	var pop := OPEN - 0.12

	# light: a column of soft healing light while it blooms, light along the floor line
	for j in 10:
		var h := j * 7.0
		var g := glow("Column%d" % j, 24, {"radius": 22, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -h)})
		var ks := []
		for i in int(D * 15) + 1:
			var t := i / 15.0
			ks.append([t, 0.12 * bloom(t) * (1.0 - h / 80.0)])
		key(g, "material:shader_parameter/alpha", ks)
	for j in 9:
		var x := (j - 4) * 5.0
		var g := glow("FloorLight%d" % j, 10, {"radius": 8, "color": C[5], "alpha": 0.0}, {"at": Vector2(x, 0)})
		var ks := []
		for i in int(D * 15) + 1:
			var t := i / 15.0
			var fw := 6.0 + 16.0 * NL.smooth(0.0, 0.8, t)
			var u := absf(x) / fw
			var a := sqrt(maxf(0.0, 1.0 - u)) * NL.smooth(0.0, 0.4, t) * (1.0 - NL.smooth(WILT, WILT + 0.6, t)) if u <= 1.0 else 0.0
			ks.append([t, 0.2 * a * (1.0 - minf(u, 1.0))])
		key(g, "material:shader_parameter/alpha", ks)

	# the ring blooming out on the floor as it opens (its far half)
	var band := ring("Band", 40, {"radius": 6, "thickness": 2, "squash": 0.18, "color": Ht[2], "side": 1}, {"at": Vector2(0, 0.5), "back": true})
	var rim := line("BandRim", PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"color": Ht[3], "back": true})
	var bk := []
	var bt := []
	var ba := []
	var rk := []
	var ra := []
	for i in 19:
		var e := i / 30.0
		var k := e / 0.6
		var r := 6.0 + 30.0 * NL.out_cubic(k)
		var pts := NL.ellipse(Vector2(0, 0.5), r, 0.18, 48)
		rk.append([pop + e, pts.slice(24, 49)])
		ra.append([pop + e, clampf(1.2 * (1.1 - k), 0.0, 1.0)])
		bk.append([pop + e, r - 0.8])
		bt.append([pop + e, maxf(0.0, 3.0 * (1.0 - k) - 0.8)])
		ba.append([pop + e, clampf(1.1 - k, 0.0, 1.0)])
	key(band, "material:shader_parameter/radius", bk)
	key(band, "material:shader_parameter/thickness", bt)
	key(band, "material:shader_parameter/alpha", ba)
	key(rim, "points", rk, "nearest")
	key(rim, "modulate:a", ra)
	show(band, pop, pop + 0.4)
	show(rim, pop, pop + 0.6)

	# the flower
	var flower := shape("Flower", load("res://addons/pixelfx_particles/fx/nature/_bloom.gdshader"), Vector2(124, 112),
		{"c1": C[1], "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6], "p0": Pt[0], "p1": Pt[1], "p2": Pt[2], "p3": Pt[3],
		"g1": Ht[1], "g2": Ht[2], "g3": Ht[3]}, {"at": Vector2(0, -55)})
	key(flower, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])

	# it sprouts: grit and a little dust
	var grit := particles("Grit", {"at": Vector2(0, -1), "amount": 8, "lifetime": 0.7, "randomness": 0.3, "one_shot": true,
		"explosiveness": 1.0, "texture": "dot1", "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 25, "speed": [45, 105],
		"gravity": Vector2(0, 950), "initial": gradient([C[2], C[3]]), "collide": {"bounce": 0.1, "friction": 1.0}})
	emit(grit, 0.0)
	var dust := particles("Dust", {"layer": "soft", "at": Vector2(0, -1), "amount": 3, "lifetime": 0.5, "one_shot": true,
		"explosiveness": 1.0, "texture": "disc5", "emit": {"box": Vector2(3, 0.5)}, "dir": -90, "spread": 70, "speed": [10, 30],
		"damping": [30, 60], "scale_curve": [[0, 0.7], [1, 1.2]], "ramp": gradient([Color(C[3], 0.7), Color(C[3], 0.4), Color(C[3], 0.15)])})
	emit(dust, 0.0)

	# the bud draws light in as it swells
	var tops := []
	for i in int(D * 30) + 1:
		var t := i / 30.0
		tops.append([t, top(t)])
	var inward := particles("Inward", {"at": top(STEM) + Vector2(0, -3), "amount": 5, "lifetime": 0.22, "randomness": 0.3,
		"emitting": false, "texture": "streak4", "align": true, "emit": {"ring": [24, 15]}, "speed": [0, 0],
		"radial": [-260, -160], "initial": gradient([Ht[2], C[6]])})
	(inward.process_material as ParticleProcessMaterial).radial_velocity_min = -85.0
	(inward.process_material as ParticleProcessMaterial).radial_velocity_max = -50.0
	key(inward, "position", tops.map(func(k): return [k[0], k[1] + Vector2(0, -3)]))
	emit(inward, STEM, BUD)
	var bud_light := glow("BudLight", 18, {"radius": 8, "color": Ht[2], "alpha": 0.0})
	var bp := []
	var bl := []
	var br := []
	for i in int(D * 30) + 1:
		var t := i / 30.0
		var b := clampf((t - STEM + 0.1) / (BUD - STEM), 0.0, 1.0)
		var on := t > STEM - 0.1 and t < OPEN - 0.1
		bp.append([t, top(t) - Vector2(0, (3.5 + 5.0 * b) * 0.6)])
		bl.append([t, 0.25 * b if on else 0.0])
		br.append([t, 8.0 + 8.0 * b])
	key(bud_light, "position", bp)
	key(bud_light, "material:shader_parameter/alpha", bl)
	key(bud_light, "material:shader_parameter/radius", br)

	# it opens: a flash of light, motes thrown out, stars, a sparkle
	var at_pop := top(pop) + Vector2(0, -3)
	var flash := glow("PopFlash", 24, {"radius": 22, "color": Color.WHITE, "alpha": 0.0}, {"at": at_pop})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [pop - 0.001, 0.0], [pop, 0.45], [pop + 0.04, 0.11], [pop + 0.08, 0.0]])
	var gold := glow("PopLight", 72, {"radius": 70, "color": Ht[2], "alpha": 0.0}, {"at": at_pop})
	var gk := [[0.0, 0.0], [pop - 0.001, 0.0]]
	var gr := []
	for i in 9:
		var k := 1.0 - i / 8.0
		gk.append([pop + 0.1 * i, 0.5 * k * k])
		gr.append([pop + 0.1 * i, 70.0 * (0.55 + 0.45 * k)])
	key(gold, "material:shader_parameter/alpha", gk)
	key(gold, "material:shader_parameter/radius", gr)
	var mote := {"at": at_pop, "amount": 16, "lifetime": 0.7, "randomness": 0.3, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "spread": 180, "speed": [40, 120], "damping": [25, 50], "gravity": Vector2(0, -15),
		"alpha_curve": [[0, 1], [0.65, 1], [1, 0]]}
	var motes := particles("Motes", mote.merged({"texture": "streak3", "align": true, "initial": gradient([Ht[3], C[7]])}))
	var mote_light := particles("MoteLight", mote.merged({"layer": "light", "texture": "glow8", "scale": [0.6, 0.6], "color": Color(Ht[3], 0.15)}))
	mote_light.seed = motes.seed
	emit(motes, pop)
	emit(mote_light, pop)
	var stars := particles("Stars", {"at": at_pop + Vector2(0, -4), "amount": 5, "lifetime": 0.6, "randomness": 0.5, "one_shot": true,
		"explosiveness": 0.6, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(10, 7)}, "speed": [6, 6],
		"color": Ht[3], "alpha_curve": [[0, 1], [0.3, 0.5], [0.5, 1], [0.8, 0.6], [1, 0]]})
	emit(stars, pop)
	var spk := gradient([Ht[2], Ht[3], Ht[3], Ht[2]], [0.0, 0.2, 0.8, 1.0])
	for i in 5:
		var e := i / 30.0
		var arm := roundf(10.0 * (1.0 - e / 0.16))
		if arm < 1.0:
			continue
		var c := top(pop + e).floor() + Vector2(0.5, -2.5)
		for axis in [Vector2(1, 0), Vector2(0, 1)]:
			var sp := line("Sparkle%d%s" % [i, "H" if axis.x > 0 else "V"], PackedVector2Array([c - axis * (arm + 0.5), c + axis * (arm + 0.5)]), {"gradient": spk})
			show(sp, pop + e, pop + e + 1.0 / 30.0)
	var spark_light := glow("SparkleLight", 26, {"radius": 24, "color": Ht[3], "alpha": 0.0}, {"at": at_pop})
	key(spark_light, "material:shader_parameter/alpha", [[0.0, 0.0], [pop - 0.001, 0.0], [pop, 0.6], [pop + 0.16, 0.0]])

	# the heart glows, pulsing, while it blooms
	var heart := glow("HeartLight", 20, {"radius": 16, "color": Ht[2], "alpha": 0.0})
	var halo := glow("HeartHalo", 36, {"radius": 34, "color": C[5], "alpha": 0.0})
	var hp := []
	var ha := []
	var hr := []
	var hh := []
	for i in int(D * 30) + 1:
		var t := i / 30.0
		var on := t > pop and t < WILT + 0.3
		var k := 1.0 - NL.smooth(WILT - 0.3, WILT + 0.3, t)
		hp.append([t, top(t) - Vector2(0, 4)])
		ha.append([t, 0.5 * k if on else 0.0])
		hr.append([t, 16.0 * (0.85 + 0.15 * sin(t * 9.0))])
		hh.append([t, 0.2 * k if on else 0.0])
	for g in [heart, halo]:
		key(g, "position", hp)
	key(heart, "material:shader_parameter/alpha", ha)
	key(heart, "material:shader_parameter/radius", hr)
	key(halo, "material:shader_parameter/alpha", hh)

	# while it blooms, bevelled crosses and golden embers drift up round it
	for L in [2, 3]:
		var o := {"at": Vector2(0, -19), "amount": 4 if L == 2 else 2, "lifetime": 0.9, "randomness": 0.3, "emitting": false,
			"emit": {"box": Vector2(22, 17)}, "dir": -90, "speed": [24, 30], "alpha_curve": [[0, 0], [0.25, 0.75], [0.5, 1], [0.75, 0.75], [1, 0]],
			"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}}
		var gly := particles("Cross%d" % L, o.merged({"texture": cross_tex(L, C)}))
		var gl := particles("CrossLight%d" % L, o.merged({"layer": "light", "texture": "glow16", "scale": [0.6 + L * 0.15, 0.6 + L * 0.15], "color": Color(C[6], 0.35)}))
		gl.seed = gly.seed
		emit(gly, OPEN, WILT)
		emit(gl, OPEN, WILT)
	var emb := {"at": Vector2(0, -4), "amount": 22, "lifetime": 0.9, "randomness": 0.3, "emitting": false,
		"emit": {"box": Vector2(20, 4)}, "dir": -90, "spread": 12, "speed": [25, 55], "damping": [20, 35], "gravity": Vector2(0, -12),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.025]}}
	var embers := particles("Embers", emb.merged({"texture": "dot1", "ramp": gradient([Ht[3], Ht[2], Ht[1]], [0.0, 0.4, 0.7]),
		"alpha_curve": [[0, 1], [0.75, 1], [0.8, 0], [0.85, 1], [0.9, 0], [0.95, 1], [1, 0]]}))
	var ember_light := particles("EmberLight", emb.merged({"layer": "light", "texture": "glow8", "color": Color(Ht[2], 0.3)}))
	ember_light.seed = embers.seed
	emit(embers, OPEN - 0.1, WILT)
	emit(ember_light, OPEN - 0.1, WILT)

	# the petals let go one by one and flutter up, turning, then twinkle out (the original's flight, replayed)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for i in 6:
		var az := i / 6.0 * TAU + 0.3
		var at_ := LIFT + fmod(i * 0.37, 1.0) * 0.55
		var e := PI / 2.0 - 0.15
		var dx := sin(e) * cos(az)
		var tp := top(at_)
		var q := {"x": tp.x + dx * 6.0, "y": tp.y - 3.0 - cos(e) * 6.0, "vx": dx * 30.0 + rng.randf_range(-10, 10),
			"vy": -rng.randf_range(25, 45), "a": atan2(-cos(e), dx), "va": rng.randf_range(-5, 5), "fl": 0.0, "vf": rng.randf_range(5, 9)}
		var life := minf(rng.randf_range(0.75, 1.0), D - 0.45 - at_)
		var tex := NL.leaf(6, 2.2, 0.0, [Pt[0], Pt[1], Pt[2], Pt[3]])
		var under := NL.leaf(6, 2.2, PI, [Pt[0], Pt[1], Pt[2], Pt[3]])
		var s := sprite("Petal%d" % i, tex)
		var pos := []
		var rot := []
		var sc := []
		var tx := []
		var al := []
		var t := at_
		var dt := 1.0 / 120.0
		var step := 0
		while t < at_ + life:
			if step % 4 == 0:
				pos.append([t, Vector2(roundf(q.x), roundf(q.y))])
				rot.append([t, q.a])
				sc.append([t, Vector2(1, maxf(0.25, absf(cos(q.fl))))])
				tx.append([t, tex if cos(q.fl) >= 0.0 else under])
				al.append([t, minf(1.0, (at_ + life - t) / 0.3)])
			q.vx -= q.vx * 1.5 * dt
			q.vy -= q.vy * 0.8 * dt + 10.0 * dt
			q.x += q.vx * dt + sin(q.fl) * 12.0 * dt
			q.y += q.vy * dt
			q.a += q.va * dt
			q.fl += q.vf * dt
			t += dt
			step += 1
		key(s, "position", pos, "nearest")
		key(s, "rotation", rot, "nearest")
		key(s, "scale", sc, "nearest")
		key(s, "texture", tx, "nearest")
		key(s, "modulate:a", al, "nearest")
		show(s, at_, at_ + life)
		var star := particles("PetalStar%d" % i, {"at": Vector2(q.x, q.y), "amount": 1, "lifetime": 0.35, "one_shot": true,
			"emitting": false, "texture": "plus3", "speed": [8, 8], "color": Pt[3], "alpha_curve": [[0, 1], [0.4, 0.4], [0.6, 1], [1, 0]]})
		emit(star, at_ + life)
		var sl := glow("PetalStarLight%d" % i, 10, {"radius": 8, "color": Pt[3], "alpha": 0.0}, {"at": Vector2(q.x, q.y - 1)})
		key(sl, "material:shader_parameter/alpha", [[0.0, 0.0], [at_ + life - 0.001, 0.0], [at_ + life, 0.35], [at_ + life + 0.35, 0.0]])
