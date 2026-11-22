# reimagined-from: src/fx/nature/vine-whip.js@b82ba7f3b1591cd3b32b3f18cab8eb41b9a4ac07
# Vine whip: A thorny vine bursts from the floor, rears back coiled, then lashes out right in a whip crack that sprays
# sap and tears off leaves, before sliding back into the ground.
# The vine is a shader of its own (fx/nature/_vine.gdshader: the original's lit stroke, bark notches, hooked thorns
# and swaying leaves) drawn through 25 points keyed at 60 Hz from the original's pose (stand, rear, a damped spring
# running up it as a wave, relax, sink). The smear is the tip's swept paths: Line2D streaks cooling down the ramp
# over a translucent polygon, with a soft light line. The crack is air lines, a ring and a sparkle (Line2D), light,
# sap drops (aligned bead-and-tail particles that vanish into the floor, a light twin on the same seed) that leave
# spots on the floor, torn leaves (build-time leaf textures, tumbling), stars; dirt bursts as it comes up and sinks.
extends "res://addons/pixelfx_particles/core/build.gd"

const NL := preload("res://build/fx/nature/_lib.gd")
const N := 24
const LS := 3.3
const LASH := 0.36
const LAG := 0.0052
const TAU_S := 0.055
const OMEGA := TAU / 0.21


static func spring(u: float) -> float:
	return 0.0 if u <= 0.0 else 1.0 - exp(-u / TAU_S) * (cos(OMEGA * u) + sin(OMEGA * u) / (OMEGA * TAU_S))


static func pose(t: float) -> PackedVector2Array:
	var grow := NL.out_cubic(clampf(t / 0.14, 0.0, 1.0)) * (1.0 - NL.in_cubic(clampf((t - 1.0) / 0.3, 0.0, 1.0)))
	var rear := NL.smooth(0.1, LASH, t)
	var relax := NL.smooth(0.82, 1.0, t)
	var pts := PackedVector2Array([Vector2(0, (1.0 - grow) * (N * LS + 6.0))])
	for i in N:
		var s := i / float(N)
		var stand := -PI / 2.0 + 0.25 * sin(s * 3.0 + t * 7.0) * s
		var back := -PI / 2.0 - 0.3 - 1.65 * pow(s, 1.3)
		var out := -1.0 + 0.9 * pow(s, 0.6)
		var a := lerpf(stand, back, rear)
		a = lerpf(a, out, spring(t - LASH - LAG * i))
		a = lerpf(a, stand, relax)
		pts.append(pts[i] + Vector2(cos(a), sin(a)) * LS)
	return pts


func make() -> void:
	ground()
	var C: PackedColorArray = root.ramps.palette
	var T: PackedColorArray = root.ramps.thorn
	var S: PackedColorArray = root.ramps.soil
	var D: float = meta.duration
	var crack := LASH + LAG * N + (PI - atan(OMEGA * TAU_S)) / OMEGA

	# the hole it comes up through, fading as it sinks back
	var hole := group("Hole", {"back": true})
	for x in range(-5, 6):
		rect("Hole%d" % (x + 5), Rect2(x, 0, 1, 1), S[0] if absi(x) < 3 else S[1], {"back": true, "parent": hole,
			"modulate": Color(1, 1, 1, 1.0 - absi(x) / 7.0)})
	key(hole, "modulate:a", [[0.0, 1.0], [1.15, 1.0], [1.25, 0.5], [1.35, 0.0]])

	# the vine
	var vine := shape("Vine", load("res://addons/pixelfx_particles/fx/nature/_vine.gdshader"), Vector2(216, 117),
		{"c0": C[0], "c1": C[1], "c2": C[2], "c3": C[3], "c4": C[4], "c5": C[5], "c6": C[6], "t1": T[1], "t2": T[2], "t3": T[3]},
		{"at": Vector2(48, -57.5)})
	var keys := []
	var n := int(roundf(D * 60.0))
	for i in n + 1:
		var t := i / 60.0
		keys.append([t, pose(t)])
	vine.material.set_shader_parameter("pts", pose(0.0))
	key(vine, "material:shader_parameter/pts", keys, "nearest")
	key(vine, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	# light along it as it lashes
	for j in 4:
		var g := glow("LashLight%d" % j, 14, {"radius": 12, "color": C[5], "alpha": 0.0})
		var gp := []
		var ga := []
		for i in n + 1:
			var t := i / 60.0
			gp.append([t, keys[i][1][(j + 1) * 6]])
			ga.append([t, 0.18 * NL.smooth(LASH, crack, t) * (1.0 - NL.smooth(crack, crack + 0.35, t))])
		key(g, "position", gp)
		key(g, "material:shader_parameter/alpha", ga)

	# the smear: the paths the outer vine just swept, the tip's white, those further in cooling down the ramp
	var hazes := []
	for k in 6:
		var hz := Polygon2D.new()
		hz.name = "Haze%d" % k
		hz.color = C[6] if k < 2 else C[5]
		keep_colour(hz.color)
		add_node(hz, "soft")
		hazes.append(hz)
	var streaks := []
	for s in range(N - 12, N + 1, 2):
		var qn := (N - s) / 12.0
		var col: Color = Color.WHITE if qn < 0.1 else C[7] if qn < 0.3 else C[6] if qn < 0.55 else C[5] if qn < 0.8 else C[4]
		var st := line("Streak%d" % s, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"gradient": gradient([col, col, Color(col, 0.5), Color(col, 0.0)], [0.0, 0.5, 0.75, 1.0], true)})
		streaks.append([st, s, qn])
	# the light along the tip's sweep (the original's glowLine): glows strung along it
	var sweep_lights := []
	for k in 4:
		sweep_lights.append(glow("SweepLight%d" % k, 16, {"radius": 14, "color": C[5], "alpha": 0.0}))
	var t0 := LASH + 0.04
	var t1 := crack + 0.1
	var hk := []
	var ha := []
	var sk := {}
	var sl := []
	var la := []
	var fr := int(floor(t0 * 60.0))
	while fr / 60.0 < t1 + 1.0 / 60.0:
		var t := fr / 60.0
		var age := clampf((t - crack + 0.02) / 0.12, 0.0, 1.0)
		var hist := []
		for k in 12:
			hist.append(pose(t - k * 0.0045))
		for k in 6:
			if hk.size() <= k:
				hk.append([])
			hk[k].append([t, PackedVector2Array([hist[k][N], hist[k + 1][N], hist[k + 1][N - 12], hist[k][N - 12]])])
		ha.append([t, (1.0 - age) if t < t1 else 0.0])
		for st in streaks:
			var L := int(roundf(11.0 * (1.0 - st[2] * 0.6)))
			var p := PackedVector2Array()
			for k in L + 1:
				p.append(hist[k][st[1]])
			if not sk.has(st[1]):
				sk[st[1]] = []
			sk[st[1]].append([t, p])
		sl.append([t, [hist[0][N], hist[2][N], hist[4][N], hist[6][N]]])
		la.append([t, 0.35 * (1.0 - age) if t < t1 else 0.0])
		fr += 1
	for k in 6:
		key(hazes[k], "polygon", hk[k], "nearest")
		key(hazes[k], "modulate:a", ha.map(func(x): return [x[0], 0.4 * (1.0 - k / 6.0) * x[1]]), "nearest")
		show(hazes[k], t0, t1)
	for st in streaks:
		key(st[0], "points", sk[st[1]], "nearest")
		key(st[0], "modulate:a", ha, "nearest")
		show(st[0], t0, t1)
	for k in 4:
		key(sweep_lights[k], "position", sl.map(func(x): return [x[0], x[1][k]]), "nearest")
		key(sweep_lights[k], "material:shader_parameter/alpha", la.map(func(x): return [x[0], x[1] * 0.4]), "nearest")
		show(sweep_lights[k], t0, t1)

	# the crack at the tip
	var a := pose(crack)
	var b := pose(crack - 0.01)
	var tip := a[N]
	var vel := (a[N] - b[N]) / 0.01
	var dirn := vel.normalized()
	var flash := glow("CrackFlash", 24, {"radius": 22, "color": Color.WHITE, "alpha": 0.0}, {"at": tip})
	key(flash, "material:shader_parameter/alpha", [[0.0, 0.0], [crack - 0.001, 0.0], [crack, 0.5], [crack + 0.04, 0.12], [crack + 0.08, 0.0]])
	var green := glow("CrackLight", 52, {"radius": 50, "color": C[5], "alpha": 0.0}, {"at": tip})
	var gk := [[0.0, 0.0], [crack - 0.001, 0.0]]
	var gr := []
	for i in 9:
		var k := 1.0 - i / 8.0
		gk.append([crack + 0.05 * i, 0.35 * k * k])
		gr.append([crack + 0.05 * i, 50.0 * (0.55 + 0.45 * k)])
	key(green, "material:shader_parameter/alpha", gk)
	key(green, "material:shader_parameter/radius", gr)
	var sparkle_light := glow("SparkleLight", 20, {"radius": 18, "color": C[7], "alpha": 0.0}, {"at": tip})
	key(sparkle_light, "material:shader_parameter/alpha", [[0.0, 0.0], [crack - 0.001, 0.0], [crack, 0.4], [crack + 0.12, 0.0]])
	for j in 7:
		var an := j / 7.0 * TAU + 0.3
		var d := Vector2(cos(an), sin(an))
		var al := line("Air%d" % j, PackedVector2Array([tip + d * 4, tip + d * 9]), {"color": Color.WHITE})
		var pk := []
		var ck := []
		for i in 4:
			var e := i / 30.0
			var k := 1.0 - e / 0.12
			var r0 := 4.0 + 10.0 * (1.0 - k)
			var r1 := r0 + 5.0 * k
			pk.append([crack + e, PackedVector2Array([tip + d * r0, tip + d * r1])])
			ck.append([crack + e, Color.WHITE if k > 0.5 else C[6]])
		key(al, "points", pk, "nearest")
		key(al, "default_color", ck, "nearest")
		show(al, crack, crack + 0.12)
	var cring := line("CrackRing", NL.ellipse(tip, 3, 1.0), {"color": C[7]})
	var rk := []
	var rak := []
	for i in 4:
		var e := i / 30.0
		var k := 1.0 - e / 0.12
		rk.append([crack + e, NL.ellipse(tip, 3.0 + 8.0 * (1.0 - k) - 0.5, 1.0)])
		rak.append([crack + e, k])
	key(cring, "points", rk, "nearest")
	key(cring, "modulate:a", rak, "nearest")
	show(cring, crack, crack + 0.12)
	var star := gradient([C[5], C[7], C[7], C[5]], [0.0, 0.2, 0.8, 1.0])
	for i in 4:
		var e := i / 30.0
		var arm := roundf(7.0 * (1.0 - e / 0.12))
		if arm < 1.0:
			continue
		for axis in [Vector2(1, 0), Vector2(0, 1)]:
			var sp := line("Sparkle%d%s" % [i, "H" if axis.x > 0 else "V"], PackedVector2Array([tip.floor() + Vector2(0.5, 0.5) - axis * (arm + 0.5), tip.floor() + Vector2(0.5, 0.5) + axis * (arm + 0.5)]), {"gradient": star})
			show(sp, crack + e, crack + e + 1.0 / 30.0)

	# sap sprays off the tip, lands and leaves spots; leaves torn off flutter away; stars twinkle
	var bead := Image.create(1, 5, false, Image.FORMAT_RGBA8)
	for y in 4:
		bead.set_pixel(0, y, C[4])
	bead.set_pixel(0, 4, C[7])
	var drop_tex := ImageTexture.create_from_image(bead)
	var spread := 40.0
	var dd := rad_to_deg(dirn.angle()) - 8.0
	var drops := particles("Sap", {"at": tip, "amount": 18, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": drop_tex, "align": true, "dir": dd, "spread": spread, "speed": [80, 260],
		"damping": [40, 90], "gravity": Vector2(0, 950), "color": Color.WHITE, "collide": {"hide": true, "size": 1}})
	emit(drops, crack)
	var drop_light := particles("SapLight", {"at": tip, "amount": 18, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "layer": "light", "texture": "glow8", "dir": dd, "spread": spread, "speed": [80, 260],
		"damping": [40, 90], "gravity": Vector2(0, 950), "color": Color(C[6], 0.3), "collide": {"hide": true, "size": 1}})
	drop_light.seed = drops.seed
	emit(drop_light, crack)
	# where they land: the original's drops replayed, a bright spot that cools and fades
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var spots := group("Spots", {"back": true})
	for i in 18:
		var ang := dirn.angle() + rng.randf_range(-0.7, 0.7)
		var v := rng.randf_range(80, 260)
		var s := 2.0 if rng.randf() < 0.3 else 1.0
		var p := tip
		var vv := Vector2(cos(ang), sin(ang)) * v - Vector2(0, rng.randf_range(0, 60))
		var t := crack
		var dt := 1.0 / 120.0
		while t < D:
			var py := p.y
			vv.y += 950.0 * dt
			vv.x -= vv.x * 0.6 / s * dt
			vv.y -= vv.y * 0.6 / s * 0.5 * dt
			p += vv * dt
			t += dt
			if vv.y > 0.0 and py <= 0.0 and p.y >= 0.0:
				break
		if t >= D - 0.3:
			continue
		var w := s * 0.7 + rng.randf_range(0.2, 1.0)
		var x0 := floorf(p.x - w)
		var x1 := ceilf(p.x + w)
		var spot := rect("Spot%d" % i, Rect2(x0, 0, x1 - x0 + 1, 1), C[6], {"back": true, "parent": spots})
		keep_colour(C[4])
		key(spot, "color", [[0.0, C[6]], [t + 0.1, C[4]]], "nearest")
		var fade := []
		var tt := t
		while tt < 1.4:
			fade.append([tt, (1.0 - NL.smooth(0.25, 0.6, tt - t)) * (1.0 - NL.smooth(1.2, 1.35, tt))])
			tt += 0.05
		key(spot, "modulate:a", fade)
		show(spot, t)
	var leaf_pal := [C[1], C[3], C[5], C[6]]
	for k in 2:
		var torn := particles("Torn%d" % k, {"at": tip, "amount": 2, "lifetime": 0.72, "randomness": 0.1, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": NL.leaf(6, 2, 0.4 + k * 2.2, leaf_pal), "dir": -40 if k == 0 else -20,
			"spread": 25, "speed": [60, 130], "damping": [80, 140], "gravity": Vector2(0, 160), "angle": [0, 360],
			"spin": [-690, 690], "alpha_curve": [[0, 1], [0.6, 1], [1, 0]]})
		emit(torn, crack)
	var stars := particles("Stars", {"at": tip, "amount": 8, "lifetime": 0.3, "randomness": 0.4, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(6, 6)}, "spread": 180,
		"speed": [5, 25], "color": C[7], "alpha_curve": [[0, 1], [0.4, 0.5], [0.6, 1], [1, 0]]})
	emit(stars, crack)

	# dirt bursting up as it comes out, and a little as it sinks
	for burst in [[0.0, 1.0, 6, "Up"], [1.08, 0.5, 3, "Down"]]:
		var at0: float = burst[0]
		var sp: float = burst[1]
		var cnt: int = burst[2]
		var life := minf(0.9, D - 0.05 - at0)
		for r in 2:
			var chips := particles("Chips%s%d" % [burst[3], r], {"at": Vector2(0, -1), "amount": maxi(1, cnt / 2), "lifetime": life,
				"randomness": 0.2, "one_shot": true, "explosiveness": 1.0, "emitting": false,
				"texture": NL.rock(11 + r * 7 + cnt, 1.6 + r * 0.8, S), "emit": {"box": Vector2(3, 0.5)}, "dir": -90,
				"spread": 69, "speed": [60 * sp, 200 * sp], "gravity": Vector2(0, 950), "angle": [0, 360], "spin": [-860, 860],
				"alpha_curve": [[0, 1], [0.7, 1], [1, 0]], "collide": {"bounce": 0.3, "friction": 0.4, "size": 1}})
			emit(chips, at0)
		var grit := particles("Grit%s" % burst[3], {"at": Vector2(0, -1), "amount": cnt * 3, "lifetime": life, "randomness": 0.3,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(3, 0.5)},
			"dir": -90, "spread": 57, "speed": [50 * sp, 200 * sp], "gravity": Vector2(0, 950),
			"initial": gradient([S[5], S[4], S[3]]), "collide": {"bounce": 0.1, "friction": 1.0}})
		emit(grit, at0)
		var dust := particles("Dust%s" % burst[3], {"layer": "soft", "at": Vector2(0, -1.5), "amount": cnt, "lifetime": minf(0.7, life),
			"randomness": 0.3, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "disc7",
			"emit": {"box": Vector2(4, 1.5)}, "dir": -90, "spread": 75, "speed": [15, 60], "damping": [50, 100],
			"scale_curve": [[0, 0.5], [1, 1.1]], "ramp": gradient([Color(S[5], 0.7), Color(S[5], 0.45), Color(S[5], 0.2)])})
		emit(dust, at0)


## A node of my own (Polygon2D) on a layer, as build.gd places its helpers' nodes.
func add_node(n: CanvasItem, layer := "color") -> void:
	_place(n, {"layer": layer})
