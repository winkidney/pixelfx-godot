# reimagined-from: src/fx/arcane/mana-burst.js@85b6735b58c0b932db53a20953879ea58d1ea26e
# Mana burst: Energy rushes into a point and blows out in a white flash and rings, flinging glowing runes that flare and pop into sparks one after another.
# one-shot, 1.80 s, 208x150 canvas, origin [104.0, 124.0], backdrop ground
# The gather is streaks rushing in (an emitter pulling inward) into a swelling ball (ring shader discs) with a ring
# collapsing onto it; the release is a white disc and flare, two rings rolling out cut off at the floor
# (fx/arcane/_cutring.gdshader), a big light, a spray of motes, stars and sparks (one-shot emitters). Nine runes (the
# original's sigils, fx/arcane/_sigils.png) are flung out on the original's dragged paths (replayed at its 120 Hz
# into keys), bob and shed motes as they burn, flare white and pop in turn into a small flare, a ring and sparks.
extends "res://build/fx/arcane/_arcane.gd"

const CY := -28.0
const GATHER := 0.22
const N := 9


func make() -> void:
	ground()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	# the floor beneath catches the burst
	var fl := glow("FloorLight", 51, {"radius": 50, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -1), "back": true})
	keyf(fl, "material:shader_parameter/alpha", func(t: float):
		var k := 0.4 * t / GATHER if t < GATHER else maxf(0.0, 1.0 - (t - GATHER) / 1.1)
		return 0.3 * k, 0.0, GATHER + 1.15)

	gather()
	release()
	runes(rng)


func gather() -> void:
	# streaks rushing in from all round, faster as they come
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 120:
		var a := rng.randf() * TAU
		var d := rng.randf_range(24, 52)
		pts.append(Vector2(cos(a) * d, minf(-2.0 - CY, sin(a) * d * 0.85)))
	var rush := particles("Rush", {"at": Vector2(0, CY), "amount": 40, "lifetime": 0.18, "texture": "streak6", "align": true,
		"emit": {"points": pts}, "radial": [-1400, -900], "initial": gradient([C[6], C[5]]),
		"ramp": gradient([C[5], C[6], Color.WHITE], [0.0, 0.5, 0.85])})
	radial_speed(rush, -60, -30)
	life_rand(rush, 0.33)
	emit(rush, 0.0, GATHER - 0.03)

	# the point it gathers into: a swelling ball with a white heart, light, a ring collapsing onto it
	var ball := group("Ball", {"at": Vector2(0, CY)})
	show(ball, 0.0, GATHER)
	var layers := [[1.2, C[4], 1.0], [0.0, C[6], 1.0], [0.0, Color.WHITE, 0.5]]
	for i in layers.size():
		var L: Array = layers[i]
		var disc := ring("Disc%d" % i, 8, {"radius": 1.0, "color": L[1]}, {"parent": ball})
		keyf(disc, "material:shader_parameter/radius", func(t: float):
			var k := t / GATHER
			return (1.0 + 3.5 * k * k) * L[2] + L[0], 0.0, GATHER)
	var bl := glow("BallLight", 31, {"radius": 10, "color": C[5], "alpha": 0.4}, {"parent": ball})
	keyf(bl, "material:shader_parameter/radius", func(t: float): return 10.0 + 20.0 * t / GATHER, 0.0, GATHER)
	keyf(bl, "material:shader_parameter/alpha", func(t: float): return 0.4 + 0.4 * t / GATHER, 0.0, GATHER)
	var inward := ring("Inward", 24, {"radius": 20, "thickness": 1, "color": C[6]}, {"parent": ball})
	keyf(inward, "material:shader_parameter/radius", func(t: float):
		var k := t / GATHER
		var q := seg(t, GATHER * 0.35, GATHER)
		return 1.0 + 3.5 * k * k + 2.0 + 16.0 * (1.0 - out_cubic(q)), GATHER * 0.35, GATHER)
	keyf(inward, "material:shader_parameter/alpha", func(t: float): return 1.0 - seg(t, GATHER * 0.35, GATHER) * 0.5, GATHER * 0.35, GATHER)
	key(inward, "material:shader_parameter/color", [[0.0, C[6]], [GATHER * 0.35 + GATHER * 0.65 * 0.6, Color.WHITE]], "nearest")
	show(inward, GATHER * 0.35, GATHER)


func release() -> void:
	var T0 := GATHER
	var Q := 0.6
	var burst := group("Burst", {"at": Vector2(0, CY)})
	# a white disc in a violet rim, gone in a few frames
	for L in [[2.0, C[5], "Rim"], [0.0, Color.WHITE, "Core"]]:
		var disc := ring("Flash" + L[2], 15, {"radius": 14, "color": L[1]}, {"parent": burst})
		var add: float = L[0]
		keyf(disc, "material:shader_parameter/radius", func(t: float): return 12.0 * (1.0 - (t - T0) / Q / 0.12) + add, T0, T0 + Q * 0.12)
		show(disc, T0, T0 + Q * 0.12)
	var fl := flare("Flare", Vector2(0, CY), 34, 1.0)
	keyf(fl, "material:shader_parameter/len", func(t: float): return 30.0 * (1.0 - seg(t, T0, T0 + Q * 0.32)) + 4.0, T0, T0 + Q * 0.32)
	keyf(fl, "material:shader_parameter/k", func(t: float): return 1.0 - seg(t, T0, T0 + Q * 0.32), T0, T0 + Q * 0.32)
	show(fl, T0, T0 + Q * 0.32)
	# the rings, cut off where they meet the floor
	var big := cut_ring("Ring", 68, {"radius": 4, "thickness": 5, "color": Color.WHITE, "cut_y": -0.5}, {"at": Vector2(0, CY)})
	keyf(big, "material:shader_parameter/radius", func(t: float): return 4.0 + 62.0 * out_cubic((t - T0) / Q), T0, T0 + Q)
	keyf(big, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 5.0 * (1.0 - (t - T0) / Q)), T0, T0 + Q)
	keyf(big, "material:shader_parameter/alpha", func(t: float): return clampf(1.2 - (t - T0) / Q, 0.0, 1.0), T0, T0 + Q)
	key(big, "material:shader_parameter/color", [[0.0, Color.WHITE], [T0 + Q * 0.2, C[6]]], "nearest")
	show(big, T0, T0 + Q)
	var small := cut_ring("Ring2", 42, {"radius": 2, "thickness": 2, "color": C[5], "cut_y": -0.5}, {"at": Vector2(0, CY)})
	keyf(small, "material:shader_parameter/radius", func(t: float): return 2.0 + 38.0 * out_cubic(minf(1.0, (t - T0) / Q * 1.4)), T0, T0 + Q)
	keyf(small, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 2.0 * (1.0 - (t - T0) / Q)), T0, T0 + Q)
	keyf(small, "material:shader_parameter/alpha", func(t: float): return clampf(1.0 - (t - T0) / Q, 0.0, 1.0), T0, T0 + Q)
	show(small, T0, T0 + Q)
	# light: the burst's own, a big pool and a white pop
	var bl := glow("BurstLight", 61, {"radius": 24, "color": C[5], "alpha": 0.9}, {"at": Vector2(0, CY)})
	keyf(bl, "material:shader_parameter/radius", func(t: float): return 60.0 * (0.4 + 0.6 * out_cubic((t - T0) / Q)), T0, T0 + Q)
	keyf(bl, "material:shader_parameter/alpha", func(t: float): return 0.9 * (1.0 - (t - T0) / Q), T0, T0 + Q)
	show(bl, T0, T0 + Q)
	var pool := glow("Pool", 97, {"radius": 96, "color": C[5], "alpha": 1.0}, {"at": Vector2(0, CY - 12)})
	keyf(pool, "material:shader_parameter/radius", func(t: float): return 96.0 * (0.55 + 0.45 * (1.0 - seg(t, T0, T0 + 0.5))), T0, T0 + 0.5)
	keyf(pool, "material:shader_parameter/alpha", func(t: float): return pow(1.0 - seg(t, T0, T0 + 0.5), 2.0), T0, T0 + 0.5)
	show(pool, T0, T0 + 0.5)
	var pop := glow("Pop", 41, {"radius": 40, "color": Color.WHITE, "alpha": 0.9}, {"at": Vector2(0, CY)})
	keyf(pop, "material:shader_parameter/radius", func(t: float): return 40.0 * (0.55 + 0.45 * (1.0 - seg(t, T0, T0 + 0.1))), T0, T0 + 0.1)
	keyf(pop, "material:shader_parameter/alpha", func(t: float): return 0.9 * pow(1.0 - seg(t, T0, T0 + 0.1), 2.0), T0, T0 + 0.1)
	show(pop, T0, T0 + 0.1)

	# the spray: motes and stars, thrown less hard at the floor, and sparks
	var cols := gradient([Color.WHITE, C[6], C[5]])
	for half in [["Up", -90.0, 1.0, 34], ["Down", 90.0, 0.45, 28]]:
		var sp: float = half[2]
		var m := particles("Motes" + half[0], {"at": Vector2(0, CY), "amount": half[3] * 2 / 3, "lifetime": 0.55, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "streak6", "align": true, "dir": half[1], "spread": 90, "speed": [100 * sp, 250 * sp],
			"damping": [40 * sp, 90 * sp], "initial": cols, "alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
		life_rand(m, 0.55)
		emit(m, T0)
		var s := particles("Stars" + half[0], {"at": Vector2(0, CY), "amount": half[3] / 3, "lifetime": 0.55, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "plus3", "dir": half[1], "spread": 90, "speed": [100 * sp, 250 * sp], "damping": [150 * sp, 250 * sp],
			"initial": cols, "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
		life_rand(s, 0.55)
		emit(s, T0)
	var sparks := particles("Sparks", {"at": Vector2(0, CY), "amount": 20, "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "streak4", "align": true, "spread": 180, "speed": [130, 280], "damping": [250, 400],
		"gravity": Vector2(0, 428), "ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
	life_rand(sparks, 0.55)
	emit(sparks, T0)
	var ml := particles("SprayLight", {"layer": "light", "at": Vector2(0, CY), "amount": 22, "lifetime": 0.55, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "glow8", "dir": -90, "spread": 90, "speed": [100, 250], "damping": [40, 90],
		"color": Color(C[6], 0.35), "alpha_curve": [[0, 1], [1, 0]]})
	life_rand(ml, 0.55)
	emit(ml, T0)


func runes(rng: RandomNumberGenerator) -> void:
	for i in N:
		var a := float(i) / N * TAU + rng.randf_range(-0.25, 0.25) - PI / 2
		var sp := rng.randf_range(150, 210)
		var r := {"x": 0.0, "y": CY, "vx": cos(a) * sp, "vy": sin(a) * sp * (0.42 if sin(a) > 0.0 else 0.85),
			"pop": GATHER + 0.42 + i * 0.065 + rng.randf_range(0, 0.05), "ph": rng.randf_range(0, TAU)}
		# the original's update at 120 Hz, from the release to the pop
		var path := []
		var t := GATHER
		var dt := 1.0 / 120.0
		while t < r.pop:
			r.vx -= r.vx * 4.2 * dt
			r.vy -= r.vy * 4.2 * dt + 8.0 * dt
			r.x += r.vx * dt
			r.y += r.vy * dt
			t += dt
			path.append([t, Vector2(r.x, r.y)])
		var pop: float = r.pop
		var ph: float = r.ph
		var where := func(tt: float) -> Vector2:
			var j := clampi(int(roundf((tt - GATHER) * 120.0)) - 1, 0, path.size() - 1)
			return path[j][1]
		var end: Vector2 = path[-1][1]
		var rune := sigil("Rune%d" % i, i, Vector2(0, CY), Color.WHITE, C[4])
		keyf(rune, "position", func(tt: float): return (where.call(tt) + Vector2(0, sin(tt * 9 + ph) * 0.6)).round(), GATHER, pop, 30.0, "nearest")
		show(rune, GATHER, pop)
		var hot_keys := [[0.0, true], [GATHER + 0.08, false], [pop - 0.06, true]]
		for n in rune.get_children():
			var is_body := String(n.name) == "Body"
			key(n, "modulate", hot_keys.map(func(k): return [k[0], (Color.WHITE if k[1] else C[6]) if is_body else (C[4] if k[1] else C[3])]), "nearest")
		keep_colour(C[3])
		var rl := glow("RuneLight", 11, {"radius": 10, "color": C[5], "alpha": 0.7}, {"parent": rune})
		key(rl, "material:shader_parameter/alpha", hot_keys.map(func(k): return [k[0], 0.7 if k[1] else 0.35]), "nearest")
		var sp_glint := sparkle("Glint", Vector2.ZERO, 3, C[6], C[5], {"parent": rune})
		keyf(sp_glint, "material:shader_parameter/arm", func(tt: float): return 3.0 + 4.0 * (1.0 - (pop - tt) / 0.06), pop - 0.06, pop, 60.0)
		show(sp_glint, pop - 0.06, pop)
		# motes shed as it burns
		var shed := particles("Shed%d" % i, {"at": Vector2(0, CY), "amount": 10, "lifetime": 0.4, "texture": "dot1", "emitting": false,
			"emit": {"box": Vector2(1.5, 0.5)}, "dir": -90, "spread": 35, "speed": [6, 26], "color": C[5],
			"alpha_curve": [[0, 1], [0.35, 1], [1, 0]]})
		life_rand(shed, 0.5)
		keyf(shed, "position", func(tt: float): return where.call(tt), GATHER, pop, 30.0)
		emit(shed, GATHER, pop)
		# the pop: a small flare and a ring, light, sparks and stars
		var at_pop := end
		var fl := flare("PopFlare%d" % i, at_pop, 13, 1.0)
		keyf(fl, "material:shader_parameter/len", func(tt: float): return 11.0 * (1.0 - seg(tt, pop, pop + 0.112)) + 2.0, pop, pop + 0.112)
		keyf(fl, "material:shader_parameter/k", func(tt: float): return 1.0 - seg(tt, pop, pop + 0.112), pop, pop + 0.112)
		show(fl, pop, pop + 0.112)
		var rr := ring("PopRing%d" % i, 14, {"radius": 2, "thickness": 2, "color": Color.WHITE}, {"at": at_pop})
		keyf(rr, "material:shader_parameter/radius", func(tt: float): return 2.0 + 11.0 * out_cubic((tt - pop) / 0.32), pop, pop + 0.32)
		keyf(rr, "material:shader_parameter/thickness", func(tt: float): return maxf(1.0, 2.0 * (1.0 - (tt - pop) / 0.32)), pop, pop + 0.32)
		keyf(rr, "material:shader_parameter/alpha", func(tt: float): return clampf(1.15 - (tt - pop) / 0.32, 0.0, 1.0), pop, pop + 0.32)
		key(rr, "material:shader_parameter/color", [[0.0, Color.WHITE], [pop + 0.096, C[6]]], "nearest")
		show(rr, pop, pop + 0.32)
		var pl := glow("PopLight%d" % i, 35, {"radius": 34, "color": C[5], "alpha": 0.9}, {"at": at_pop})
		keyf(pl, "material:shader_parameter/radius", func(tt: float): return 34.0 * (0.55 + 0.45 * (1.0 - seg(tt, pop, pop + 0.22))), pop, pop + 0.22)
		keyf(pl, "material:shader_parameter/alpha", func(tt: float): return 0.9 * pow(1.0 - seg(tt, pop, pop + 0.22), 2.0), pop, pop + 0.22)
		show(pl, pop, pop + 0.22)
		var ph2 := glow("PopHot%d" % i, 13, {"radius": 12, "color": Color.WHITE, "alpha": 0.8}, {"at": at_pop})
		keyf(ph2, "material:shader_parameter/alpha", func(tt: float): return 0.8 * pow(1.0 - seg(tt, pop, pop + 0.06), 2.0), pop, pop + 0.06)
		show(ph2, pop, pop + 0.06)
		var sparks := particles("PopSparks%d" % i, {"at": at_pop, "amount": 9, "lifetime": 0.4, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "streak3", "align": true, "spread": 180, "speed": [70, 200], "damping": [150, 300],
			"gravity": Vector2(0, 428), "ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "collide": {"bounce": 0.45, "friction": 0.3}})
		life_rand(sparks, 0.6)
		emit(sparks, pop)
		var stars := particles("PopStars%d" % i, {"at": at_pop, "amount": 5, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": "plus3", "spread": 180, "speed": [20, 80], "damping": [30, 60], "gravity": Vector2(0, -20),
			"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
		life_rand(stars, 0.5)
		emit(stars, pop)
