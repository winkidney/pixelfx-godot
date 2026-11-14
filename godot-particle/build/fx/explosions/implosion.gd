# reimagined-from: src/fx/explosions/implosion.js@a5688ab93bdd3199533cc2f6f1b378f5734eef8d
# Implosion: everything is sucked in: streaks and grit rush inward, rings contract and a dark sphere collapses onto a
# crushed white point; a beat of stillness, then a sharp pop.
# The void (a translucent dark disc, its lit edge and glow), the four rings pulled in after it, the crushed core and
# the pop's rings are ring shaders keyed every frame from the original's curves; the cross flare and the sparkle are
# Line2Ds. Streaks rush in on three rings of inward-pointing emission points, accelerating to arrive at the middle
# as they die; grit spirals in (inward pull and orbit), vapour drifts in; the pop throws motes and stars out, each
# with a light-layer twin.
extends "res://addons/pixelfx_particles/core/build.gd"

const SUCK := 0.8
const STILL := 1.02
const VOID := Color("#05040a")


static func in_cubic(x: float) -> float:
	return x * x * x


static func in_quad(x: float) -> float:
	return x * x


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	keep_colour(VOID)
	var D: float = meta.duration

	# the void: a dark sphere edged with light, collapsing onto the core
	var void_disc := ring("Void", 70, {"radius": 67, "color": VOID, "translucent": true, "alpha": 0.35})
	var void_glow := glow("VoidGlow", 74, {"radius": 67, "thickness": 5, "color": C[4], "alpha": 0.18})
	var void_edge := ring("VoidEdge", 70, {"radius": 68, "thickness": 1, "color": C[3], "alpha": 0.5})
	var vr := []
	var va := []
	var er := []
	var ea := []
	var gr := []
	var ga := []
	var ec := []
	var n_suck := int(ceil(SUCK * 60.0))
	for i in n_suck + 1:
		var t := i / 60.0
		var k := clampf(t / SUCK, 0.0, 1.0)
		var r := 64.0 * (1.0 - in_cubic(k)) + 3.0
		vr.append([t, r])
		va.append([t, 0.35 + 0.35 * k])
		er.append([t, r + 1.0])
		ea.append([t, 0.5 + 0.5 * k])
		gr.append([t, r])
		ga.append([t, 0.18 + 0.3 * k])
	key(void_disc, "material:shader_parameter/radius", vr)
	key(void_disc, "material:shader_parameter/alpha", va)
	key(void_edge, "material:shader_parameter/radius", er)
	key(void_edge, "material:shader_parameter/alpha", ea)
	key(void_edge, "material:shader_parameter/color", [[0.0, C[3]], [SUCK * 0.5, C[4]]], "nearest")
	key(void_glow, "material:shader_parameter/radius", gr)
	key(void_glow, "material:shader_parameter/alpha", ga)
	for n in [void_disc, void_glow, void_edge]:
		show(n, 0.0, SUCK)

	# rings pulled in after it, one after another, brighter as they go
	for i in 4:
		var t0 := i * 0.17
		var rg := ring("Pull%d" % i, 74, {"radius": 72 - i * 8, "thickness": 1, "color": C[3], "alpha": 0.4})
		var rk := []
		var ak := []
		for j in 21:
			var u := j / 20.0
			rk.append([t0 + u * 0.34, (70.0 - i * 8) * (1.0 - in_quad(u)) + 2.0])
			ak.append([t0 + u * 0.34, 0.4 + 0.6 * u])
		key(rg, "material:shader_parameter/radius", rk)
		key(rg, "material:shader_parameter/alpha", ak)
		key(rg, "material:shader_parameter/thickness", [[0.0, 1.0], [t0 + 0.7 * 0.34, 2.0]], "nearest")
		key(rg, "material:shader_parameter/color", [[0.0, C[3]], [t0 + 0.6 * 0.34, C[5]]], "nearest")
		show(rg, t0 + 0.001, t0 + 0.34)

	# the core: growing hotter as it's crushed, then a white point trembling in the stillness
	var core_void := ring("CoreVoid", 9, {"radius": 4.5, "color": VOID, "translucent": true, "alpha": 0.85})
	var core_rim := ring("CoreRim", 7, {"radius": 2.2, "color": C[4]})
	var core := ring("Core", 6, {"radius": 1.0, "color": Color.WHITE})
	var core_light := glow("CoreLight", 38, {"radius": 10, "color": C[4], "alpha": 0.3})
	var still_light := glow("StillLight", 10, {"radius": 8, "color": Color.WHITE, "alpha": 0.4})
	var ck := [[], [], [], [], [], [], []]
	for i in int(ceil(STILL * 60.0)) + 1:
		var t := i / 60.0
		var k := clampf(t / SUCK, 0.0, 1.0)
		var still := t > SUCK
		var jit := (0.5 if int(floor(t * 40.0)) % 2 else -0.5) if still else 0.0
		var cr := 1.6 if still else 1.0 + 3.5 * (1.0 - k) * k * 4.0
		ck[0].append([t, cr + 3.5])
		ck[1].append([t, cr + 1.2])
		ck[2].append([t, cr])
		ck[3].append([t, Vector2(roundf(jit), 0)])
		ck[4].append([t, 10.0 + 26.0 * k])
		ck[5].append([t, 0.3 + 0.5 * k])
		ck[6].append([t, (0.4 + 0.2 * sin(t * 60.0)) if still else 0.0])
	key(core_void, "material:shader_parameter/radius", ck[0])
	key(core_rim, "material:shader_parameter/radius", ck[1])
	key(core, "material:shader_parameter/radius", ck[2])
	for n in [core_void, core_rim, core]:
		key(n, "position", ck[3], "nearest")
		show(n, 0.0, STILL)
	key(core_light, "material:shader_parameter/radius", ck[4])
	key(core_light, "material:shader_parameter/alpha", ck[5])
	key(still_light, "material:shader_parameter/alpha", ck[6])
	show(core_light, 0.0, STILL)
	show(still_light, SUCK, STILL)

	# streaks of light rushing in from all round, faster and faster, more of them as it goes: each ring of emission
	# points throws them inward so they reach the middle just as they die
	var T := 0.19
	var streak := _streak_texture(C)
	var rings := [42.0, 60.0, 78.0]
	for i in rings.size():
		var R: float = rings[i]
		var s := particles("Streaks%d" % i, {"amount": 18, "lifetime": T, "randomness": 0.5, "emitting": false, "texture": streak,
			"align": true, "speed": [0.5 * R / T * 0.9, 0.5 * R / T * 1.1], "radial": [-R / (T * T), -R / (T * T)],
			"initial": gradient([Color.WHITE, C[5].lerp(Color.WHITE, 0.5)])})
		_inward(s, R, 0.0)
		emit(s, 0.0, SUCK - 0.26)
		key(s, "amount_ratio", [[0.0, 0.34], [0.2, 0.67], [0.4, 1.0]], "nearest")
	# grit pulled in: specks spiralling toward the middle, faster and faster
	var grit_cols := gradient([C[2], C[3], C[4], Color("#4a4458"), Color("#6e6880")])
	for i in 3:
		var R := 46.0 + i * 18.0
		var L := 0.42
		var g := particles("Grit%d" % i, {"amount": 26, "lifetime": L, "randomness": 0.3, "emitting": false, "texture": "streak4",
			"align": true, "emit": {"ring": [R, R - 6.0]}, "radial": [-2.0 * R / (L * L), -1.8 * R / (L * L)],
			"orbit": [-0.7, 0.7], "initial": grit_cols})
		emit(g, 0.0, 0.4)
	# vapour drawn in along the way
	var vap := particles("Vapour", {"layer": "soft", "amount": 8, "lifetime": 0.55, "randomness": 0.5, "emitting": false,
		"texture": "disc9", "speed": [80, 95], "drag": 4.0, "scale": [0.7, 1.1], "scale_curve": [[0, 0.7], [1, 1.5]],
		"color": Color(C[3], 0.45), "alpha_curve": [[0, 1], [0.3, 0.6], [0.7, 0.2], [1, 0]]})
	_inward(vap, 65.0, 15.0)
	emit(vap, 0.02, SUCK - 0.26)

	# the pop: a white point bursting, a cross flare, a fast thin ring and a slower one, a sparkle, light
	var pop := ring("Pop", 8, {"radius": 7, "color": Color.WHITE})
	key(pop, "material:shader_parameter/radius", [[STILL, 7.0], [STILL + 0.04, 1.0]])
	show(pop, STILL, STILL + 0.04)
	# (a Line2D only takes its gradient's colour at its points: the flares are split into many short segments)
	var long_g := gradient([Color(C[5], 0.0), Color(C[5], 0.5), C[5], Color.WHITE, C[5], Color(C[5], 0.5), Color(C[5], 0.0)],
		[0.0, 0.08, 0.15, 0.3, 0.7, 0.85, 0.92], true)
	var short_g := gradient([Color(C[5], 0.0), C[5], Color(C[5], 0.0)], [0.0, 0.5, 1.0], true)
	var flare := []
	for i in 4:
		var a := PI / 4.0 + (i % 2) * PI / 2.0 + (PI / 4.0 if i >= 2 else 0.0)
		var ln := line("Flare%d" % i, _seg(Vector2.ZERO, Vector2.ZERO, 24), {"width": 1, "gradient": long_g if i < 2 else short_g})
		var pk := []
		for j in 12:
			var t := STILL + j * 0.175 / 11.0
			var q := (t - STILL) / 0.5
			var L := (1.0 - q / 0.35) * 34.0 + 3.0
			var l := L if i < 2 else L * 0.45
			var dv := Vector2(cos(a), sin(a))
			pk.append([t, _seg(-dv * l, dv * l, 24)])
		key(ln, "points", pk)
		show(ln, STILL, STILL + 0.175)
		flare.append(ln)
	var fast := ring("PopRing", 80, {"radius": 4, "thickness": 2.5, "color": Color.WHITE})
	var slow := ring("PopRing2", 44, {"radius": 2, "thickness": 1, "color": C[4]})
	var fk := [[], [], [], [], []]
	for j in 31:
		var q := j / 30.0
		var t := STILL + q * 0.5
		fk[0].append([t, 4.0 + 74.0 * out_cubic(q)])
		fk[1].append([t, maxf(1.0, 2.5 * (1.0 - q))])
		fk[2].append([t, minf(1.0, 1.15 - q)])
		fk[3].append([t, 2.0 + 40.0 * out_cubic(clampf(q * 1.4, 0.0, 1.0))])
		fk[4].append([t, 1.0 - q])
	key(fast, "material:shader_parameter/radius", fk[0])
	key(fast, "material:shader_parameter/thickness", fk[1])
	key(fast, "material:shader_parameter/alpha", fk[2])
	key(fast, "material:shader_parameter/color", [[0.0, Color.WHITE], [STILL + 0.1, C[5]]], "nearest")
	key(slow, "material:shader_parameter/radius", fk[3])
	key(slow, "material:shader_parameter/alpha", fk[4])
	show(fast, STILL, STILL + 0.5)
	show(slow, STILL, STILL + 0.5)
	# the sparkle: a white-hot cross shrinking away
	var sg := gradient([C[5], Color.WHITE, Color.WHITE, C[5]], [0.0, 0.2, 0.8, 1.0])
	for i in 2:
		var ln := line("Sparkle%d" % i, _seg(Vector2.ZERO, Vector2.ZERO, 10), {"width": 1, "gradient": sg})
		var dv := Vector2(1, 0) if i == 0 else Vector2(0, 1)
		var sk := []
		for j in 10:
			var t := STILL + j * 0.3 / 9.0
			var arm := roundf(5.0 * (1.0 - (t - STILL) / 0.3))
			sk.append([t, _seg(-dv * (arm + 0.5), dv * (arm + 0.5), 10)])
		key(ln, "points", sk, "nearest")
		key(ln, "position", [[0.0, Vector2(0.5, 0.5)]])
		show(ln, STILL, STILL + 0.28)
	var big_light := glow("PopLight", 92, {"radius": 90, "color": C[4], "alpha": 1.0})
	var white_light := glow("PopWhite", 32, {"radius": 30, "color": Color.WHITE, "alpha": 0.9})
	var bl := [[0.0, 0.0], [STILL - 0.001, 0.0]]
	var br := []
	for j in 13:
		var u := j / 12.0
		var k := 1.0 - u
		bl.append([STILL + u * 0.4, k * k])
		br.append([STILL + u * 0.4, 90.0 * (0.55 + 0.45 * k)])
	key(big_light, "material:shader_parameter/alpha", bl)
	key(big_light, "material:shader_parameter/radius", br)
	key(white_light, "material:shader_parameter/alpha", [[0.0, 0.0], [STILL - 0.001, 0.0], [STILL, 0.9], [STILL + 0.04, 0.2], [STILL + 0.08, 0.0]])
	key(white_light, "material:shader_parameter/radius", [[STILL, 30.0], [STILL + 0.08, 17.0]])
	var sparkle_light := glow("SparkleLight", 16, {"radius": 14, "color": Color.WHITE, "alpha": 0.0})
	key(sparkle_light, "material:shader_parameter/alpha", [[0.0, 0.0], [STILL - 0.001, 0.0], [STILL, 0.6], [STILL + 0.3, 0.0]])

	# motes and stars thrown out by the pop, each with its light
	var mote_tex := _mote_texture()
	for spec in [["Motes", 20, mote_tex, 0.6, true], ["Stars", 14, "plus3", 1.6, false]]:
		var p := particles(spec[0], {"amount": spec[1], "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": spec[2], "align": spec[4], "spread": 180, "speed": [120, 330], "drag": spec[3],
			"initial": gradient([C[6], C[5], C[4]]), "alpha_curve": [[0, 1], [0.5, 1], [1, 0]]})
		(p.process_material as ParticleProcessMaterial).lifetime_randomness = 0.5
		emit(p, STILL)
		var lit := particles(spec[0] + "Light", {"layer": "light", "amount": spec[1], "lifetime": 0.45, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "glow8", "modulate": Color(1, 1, 1, 0.4)})
		lit.process_material = p.process_material
		lit.seed = p.seed
		emit(lit, STILL)


## Emission points round a ring of radius r (and a band dr wide) whose normals point at the middle: particles fly in.
func _inward(p: GPUParticles2D, r: float, dr: float, n := 64) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = n + int(r)
	for i in n:
		var a := (i + rng.randf()) / float(n) * TAU
		var rr := r + rng.randf_range(-dr, dr)
		pts.append(Vector2(cos(a), sin(a)) * rr)
		nor.append(-Vector2(cos(a), sin(a)))
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(pts)
	m.emission_normal_texture = _points_texture(nor)
	m.emission_point_count = n
	m.direction = Vector3(1, 0, 0)
	m.spread = 0.0


## A streak of light (aligned with its flight, head on the bottom row): a white head, a lilac body, a dim tail.
func _streak_texture(C: PackedColorArray) -> ImageTexture:
	var img := Image.create(1, 6, false, Image.FORMAT_RGBA8)
	var cols := [Color(C[4], 0.5), C[4], C[5], C[5], C[5], Color.WHITE]
	for y in 6:
		img.set_pixel(0, y, cols[y])
	return ImageTexture.create_from_image(img)


## A mote: a bright head and a tail at a little over half its brightness.
func _mote_texture() -> ImageTexture:
	var img := Image.create(1, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		img.set_pixel(0, y, Color.WHITE if y >= 7 else Color(0.55, 0.55, 0.55, 0.6 if y < 2 else 1.0))
	return ImageTexture.create_from_image(img)


## n + 1 points evenly from a to b: a Line2D takes its gradient's colour only at its points.
static func _seg(a: Vector2, b: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		out.append(a.lerp(b, i / float(n)))
	return out
