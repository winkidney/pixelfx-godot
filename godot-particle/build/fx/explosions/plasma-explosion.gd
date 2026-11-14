# reimagined-from: src/fx/explosions/plasma-explosion.js@5ab1c800b2a6785f63d41e6e5a1c8bb7d075dfef
# Plasma explosion: a blue-violet energy blast with no smoke: a white flash, a ball of plasma swelling into a thinning
# shell, shock rings in and out of depth, lightning arcs crackling off it.
# The ball is a shader of its own (_plasma-explosion_ball.gdshader: the original's swirling bands, filaments and
# boiling violet rim) keyed from its swell and hollowing; the flash, the shock rings and the tilted ring (its far half
# behind the ball, its near half in front) are ring shaders keyed every frame, the flare eight Line2D rays; arcs are
# bolts re-struck on the original's 18 Hz beat with a cyan offset copy and a violet glow; motes and flakes burst out
# (motes with light twins), and the shell sheds sparkles as it thins.
extends "res://addons/pixelfx_particles/core/build.gd"

const BALL := 0.55


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func shell(t: float) -> float:
	return 5.0 + 30.0 * out_cubic(clampf(t / BALL, 0.0, 1.0))


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var V: PackedColorArray = root.ramps.accent
	var D: float = meta.duration
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# the light: a blue swell, a white pop, a violet afterglow
	for L in [["Light", 96.0, C[4], 1.0, 0.6], ["Pop", 40.0, Color.WHITE, 0.9, 0.1], ["Afterglow", 70.0, V[2], 0.5, 1.1]]:
		var g := glow(L[0], L[1] + 2, {"radius": L[1], "color": L[2], "alpha": L[3]})
		var ak := []
		var rk := []
		for j in 21:
			var t: float = L[4] * j / 20.0
			var k: float = 1.0 - j / 20.0
			ak.append([t, L[3] * k * k])
			rk.append([t, L[1] * (0.55 + 0.45 * k)])
		key(g, "material:shader_parameter/alpha", ak)
		key(g, "material:shader_parameter/radius", rk)

	# the tilted ring's far half, behind the ball
	var bands := []
	for half in [[1.0, true, "Far"], [-1.0, false, "Near"]]:
		var outer := ring("Band%sEdge" % half[2], 100, {"radius": 12, "thickness": 1.2, "squash": 0.28, "color": Color.WHITE, "side": half[0]},
			{"at": Vector2(0, 4), "back": half[1]})
		var inner := ring("Band%s" % half[2], 100, {"radius": 11, "thickness": 3, "squash": 0.28, "color": C[4], "side": half[0]},
			{"at": Vector2(0, 4), "back": half[1]})
		bands.append([outer, inner])

	# the ball: swelling, then hollowing out
	var ball := shape("Ball", load("res://addons/pixelfx_particles/fx/explosions/_plasma-explosion_ball.gdshader"), Vector2(84, 84),
		{"white": Color.WHITE, "c3": C[3], "c4": C[4], "c5": C[5], "v2": V[2], "v3": V[3]})
	var ball_glow := glow("BallGlow", 64, {"radius": 14, "color": C[4], "alpha": 0.6})
	var bk := [[], [], [], [], [], []]
	for i in int(ceil(BALL * 60.0)) + 1:
		var t := i / 60.0
		var u := t / BALL
		bk[0].append([t, shell(t)])
		bk[1].append([t, u])
		bk[2].append([t, floorf(t * 20.0)])
		bk[3].append([t, t])
		bk[4].append([t, shell(t) * 1.6 + 6.0])
		bk[5].append([t, 0.6 * (1.0 - u)])
	key(ball, "material:shader_parameter/radius", bk[0])
	key(ball, "material:shader_parameter/u", bk[1])
	key(ball, "material:shader_parameter/boil", bk[2], "nearest")
	key(ball, "material:shader_parameter/clock", bk[3])
	key(ball_glow, "material:shader_parameter/radius", bk[4])
	key(ball_glow, "material:shader_parameter/alpha", bk[5])
	show(ball, 0.0, BALL)
	show(ball_glow, 0.0, BALL)

	# the flash and the flare
	var flash := ring("Flash", 10, {"radius": 9, "color": Color.WHITE})
	key(flash, "material:shader_parameter/radius", [[0.0, 9.0], [0.07, 4.8]])
	show(flash, 0.0, 0.07)
	var fg := gradient([Color.WHITE, C[5], Color(C[4], 0.7), Color(C[4], 0.2)], [0.0, 0.35, 0.7, 0.9], true)
	for i in 8:
		var an := i * PI / 4.0
		var share := 1.0 if i % 4 == 0 else (0.6 if i % 2 == 0 else 0.3)
		var dv := Vector2(cos(an), sin(an))
		var ray := line("Flare%d" % i, _seg(Vector2.ZERO, Vector2.ZERO, 16), {"width": 1, "gradient": fg})
		var fk := []
		for j in 16:
			var t := j * 0.25 / 15.0
			var L := 52.0 * pow(1.0 - t / 0.25, 1.3) * share
			fk.append([t, _seg(Vector2.ZERO, dv * maxf(L, 0.5), 16)])
		key(ray, "points", fk)
		key(ray, "modulate:a", [[0.0, 1.0], [0.25, 0.6]])
		show(ray, 0.0, 0.25)

	# shock rings: a fast bright one with its light, a slower violet one; and the tilted ring racing out
	var r1 := ring("Shock", 94, {"radius": 8, "thickness": 3, "color": Color.WHITE})
	var r1_light := glow("ShockLight", 98, {"radius": 8, "thickness": 5, "color": C[4], "alpha": 0.35})
	var r2 := ring("Shock2", 68, {"radius": 6, "thickness": 2, "color": V[3]})
	var rk := [[], [], [], [], [], [], []]
	for j in 31:
		var u1 := j / 30.0
		var t := u1 * 0.42
		rk[0].append([t, 8.0 + 84.0 * out_cubic(u1)])
		rk[1].append([t, maxf(1.0, 3.0 * (1.0 - u1))])
		rk[2].append([t, minf(1.0, 1.15 - u1)])
		rk[3].append([t, 0.35 * (1.0 - u1)])
		var u2 := j / 30.0
		var t2 := 0.06 + u2 * 0.6
		rk[4].append([t2, 6.0 + 60.0 * out_cubic(u2)])
		rk[5].append([t2, maxf(1.0, 2.0 * (1.0 - u2))])
		rk[6].append([t2, minf(1.0, 1.1 - u2)])
	key(r1, "material:shader_parameter/radius", rk[0])
	key(r1, "material:shader_parameter/thickness", rk[1])
	key(r1, "material:shader_parameter/alpha", rk[2])
	key(r1, "material:shader_parameter/color", [[0.0, Color.WHITE], [0.25 * 0.42, C[5]]], "nearest")
	key(r1_light, "material:shader_parameter/radius", rk[0])
	key(r1_light, "material:shader_parameter/alpha", rk[3])
	key(r2, "material:shader_parameter/radius", rk[4])
	key(r2, "material:shader_parameter/thickness", rk[5])
	key(r2, "material:shader_parameter/alpha", rk[6])
	show(r1, 0.0, 0.42)
	show(r1_light, 0.0, 0.42)
	show(r2, 0.06, 0.66)
	var bkeys := [[], [], [], []]
	for j in 31:
		var u := j / 30.0
		var t := 0.03 + u * 0.5
		var R := 12.0 + 86.0 * out_cubic(u)
		var th := maxf(1.0, 4.0 * (1.0 - u))
		bkeys[0].append([t, R])
		bkeys[1].append([t, R - 0.8])
		bkeys[2].append([t, maxf(0.6, th - 0.8)])
		bkeys[3].append([t, minf(1.0, 1.15 - u)])
	for pair in bands:
		key(pair[0], "material:shader_parameter/radius", bkeys[0])
		key(pair[1], "material:shader_parameter/radius", bkeys[1])
		key(pair[1], "material:shader_parameter/thickness", bkeys[2])
		key(pair[0], "material:shader_parameter/alpha", bkeys[3])
		key(pair[1], "material:shader_parameter/alpha", bkeys[3])
		key(pair[0], "material:shader_parameter/color", [[0.0, Color.WHITE], [0.03 + 0.15 * 0.5, C[5]]], "nearest")
		show(pair[0], 0.03, 0.53)
		show(pair[1], 0.03, 0.53)

	# arcs: lightning crackling out of the heart, re-struck 18 times a second, shorter and fewer as the charge runs out
	var arc_g := gradient([Color.WHITE, Color.WHITE, C[5]], [0.0, 0.3, 0.6])
	var strikes := int(ceil(0.85 * 18.0))
	for i in 6:
		var core := bolt("Arc%d" % i, Vector2.ZERO, Vector2(30, 0), {"width": 1, "gradient": arc_g, "jag": 4, "segments": 9, "rate": 18,
			"seed": 40 + i, "branches": 1, "branch_length": 0.3})
		var halo := bolt("ArcHalo%d" % i, Vector2.ZERO, Vector2(30, 0), {"width": 1, "color": C[4], "jag": 4, "segments": 9, "rate": 18,
			"seed": 40 + i, "branches": 1, "branch_length": 0.3})
		halo.position = Vector2(1, 0)
		halo.z_index = 0
		var lit := bolt("ArcLight%d" % i, Vector2.ZERO, Vector2(30, 0), {"width": 5, "color": Color(V[2], 0.35), "layer": "light", "jag": 4,
			"segments": 9, "rate": 18, "seed": 40 + i})
		var tos := []
		var vis := [[0.0, false]]
		var al := []
		for s in strikes + 1:
			var t := s / 18.0
			var left := 1.0 - smooth(0.15, 0.85, t)
			var n := 2 + int(roundf(4.0 * left))
			var a := rng.randf_range(0, TAU)
			var L := rng.randf_range(26, 58) * (0.45 + 0.55 * left)
			tos.append([t, Vector2(cos(a), sin(a)) * L])
			vis.append([t, i < n and left > 0.06])
			al.append([t, minf(1.0, left * 1.4)])
		for b in [core, halo, lit]:
			# a bolt only re-rolls its points on its own beat: start it where the first strike points
			b.to = tos[0][1]
			key(b, "to", tos, "nearest")
			key(b, "visible", vis, "nearest")
			b.visible = true
		key(core, "modulate:a", al, "nearest")
		key(halo, "modulate:a", al.map(func(k): return [k[0], k[1] * 0.6]), "nearest")
		key(lit, "modulate:a", al, "nearest")
	# and little arcs crawling over the shell
	for i in 3:
		var crawl := bolt("Crawl%d" % i, Vector2(10, 0), Vector2(0, 10), {"width": 1, "color": C[5], "jag": 2, "segments": 5, "rate": 18,
			"seed": 70 + i})
		var fr := []
		var tt := []
		var al := []
		for s in strikes + 1:
			var t := s / 18.0
			var left := 1.0 - smooth(0.15, 0.85, t)
			var rs := shell(t)
			var a := rng.randf_range(0, TAU)
			var b := a + rng.randf_range(0.3, 0.6)
			fr.append([t, Vector2(cos(a), sin(a)) * rs])
			tt.append([t, Vector2(cos(b), sin(b)) * rs])
			al.append([t, minf(1.0, left * 0.85)])
		crawl.from = fr[0][1]
		crawl.to = tt[0][1]
		key(crawl, "from", fr, "nearest")
		key(crawl, "to", tt, "nearest")
		key(crawl, "modulate:a", al, "nearest")
		show(crawl, 0.0, 0.8)

	# motes and flakes thrown out, sparkles shed off the shell as it thins
	var mote := _mote_texture()
	var motes := particles("Motes", {"amount": 46, "lifetime": 0.42, "one_shot": true, "explosiveness": 1.0, "texture": mote,
		"align": true, "speed": [140, 360], "drag": 0.6, "scale": [0.7, 1.1],
		"initial": gradient([C[6], C[5], C[4], V[3]]), "alpha_curve": [[0, 1], [0.6, 1], [1, 0.3]]})
	_radial(motes, 4.0)
	(motes.process_material as ParticleProcessMaterial).lifetime_randomness = 0.5
	var motes_lit := particles("MotesLight", {"layer": "light", "amount": 46, "lifetime": 0.42, "one_shot": true, "explosiveness": 1.0,
		"texture": "glow8", "modulate": Color(1, 1, 1, 0.28)})
	motes_lit.process_material = motes.process_material
	motes_lit.seed = motes.seed
	for spec in [["Flakes", 18, "dot1"], ["FlakesBig", 8, "plus3"]]:
		var f := particles(spec[0], {"amount": spec[1], "lifetime": 1.5, "one_shot": true, "explosiveness": 1.0, "texture": spec[2],
			"speed": [40, 140], "drag": 2.2, "gravity": Vector2(0, 35), "initial": gradient([C[5], V[3], V[4]]),
			"alpha_curve": [[0, 1], [0.75, 1], [1, 0]]})
		_radial(f, 10.0)
		(f.process_material as ParticleProcessMaterial).lifetime_randomness = 0.45
	for spec in [["Shed", 12, "dot1"], ["ShedStars", 10, "plus3"]]:
		var s := particles(spec[0], {"amount": spec[1], "lifetime": 0.6, "randomness": 0.6, "emitting": false, "texture": spec[2],
			"emit": {"ring": [10, 9]}, "dir": 0, "spread": 180, "speed": [10, 40], "drag": 1.6,
			"initial": gradient([C[5], V[4]]), "alpha_curve": [[0, 1], [0.6, 1], [0.8, 0.3], [1, 0]]})
		(s.process_material as ParticleProcessMaterial).lifetime_randomness = 0.5
		var er := []
		for j in 25:
			var t := 0.12 + j * 0.78 / 24.0
			er.append([t, shell(t)])
		key(s, "process_material:emission_ring_radius", er)
		key(s, "process_material:emission_ring_inner_radius", er.map(func(k): return [k[0], k[1] - 1.0]))
		emit(s, 0.12, 0.9)


## Burst particles flung straight out from a ring of radius r round the origin (directed emission points).
func _radial(p: GPUParticles2D, r: float, n := 48) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in n:
		var a := (i + 0.5) / float(n) * TAU
		pts.append(Vector2(cos(a), sin(a)) * r)
		nor.append(Vector2(cos(a), sin(a)))
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(pts)
	m.emission_normal_texture = _points_texture(nor)
	m.emission_point_count = n
	m.direction = Vector3(1, 0, 0)
	m.spread = 0.0


## A mote (aligned with its flight, head on the bottom row): a bright head, a tail a little over half as bright.
func _mote_texture() -> ImageTexture:
	var img := Image.create(1, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		img.set_pixel(0, y, Color.WHITE if y >= 5 else Color(0.55, 0.55, 0.55, 0.6 if y < 1 else 1.0))
	return ImageTexture.create_from_image(img)


## n + 1 points evenly from a to b: a Line2D takes its gradient's colour only at its points.
static func _seg(a: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(a.lerp(b, i / float(n)))
	return out
