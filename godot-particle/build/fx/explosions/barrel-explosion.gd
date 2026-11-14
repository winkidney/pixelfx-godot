# reimagined-from: src/fx/explosions/barrel-explosion.js@626b63b7e7ea1969801787b5a96aa53eb7c6d742
# Barrel explosion: an explosive barrel shudders, its lid bulging and spitting flame, then blows: a fireball column,
# staves and the lid flying, burning fuel splashed over the floor.
# The drum is a shader of its own (_barrel.gdshader: the original's drum, its shake and bulge keyed every frame);
# flame and sparks spit from the seam under its lid, smoke curls off the top. The blast: a hot disc, an eight-ray
# flare (lines), a band rolling out along the floor (ring shader), the scorch and the burning fuel slicks
# (_barrel_scorch.gdshader), glows and a pool of light; a fireball of puffs (_barrel_fire.gdshader: a ball with a
# darker rim) bursting out and driven up in a column, cooling into oily smoke; sparks, embers, burning brands that
# arc out and land, fires burning on where the fuel and the brands fell; the staves (_barrel_stave.gdshader) and the
# lid (_barrel_lid.gdshader) replay the original's tumbling, bouncing debris, keyed every frame; dust rolls out along
# the floor and grit lands on a collision floor.
extends "res://addons/pixelfx_particles/core/build.gd"

const BLOW := 0.8
const BW := 8.0
const BH := 22.0
const Y := -11.0
const STONE := ["#5a4f6b", "#3e3650", "#776c88"]
const DUST := "#7d7280"
const SMOKE := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]
const HOT := ["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"]
const SHADERS := "res://addons/pixelfx_particles/fx/explosions/"


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


var fire_mat: ShaderMaterial


func make() -> void:
	ground()
	var F: PackedColorArray = root.ramps.palette
	var C: PackedColorArray = root.ramps.barrel
	var D: float = meta.duration
	var FR := [F[7], F[6], F[5], F[4], F[3], F[2], F[1], F[1].lerp(F[0], 0.5), F[0]]
	var SOOT := Color("#0d0a12")
	var OUTLINE := Color("#1a1422")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	fire_mat = ShaderMaterial.new()
	fire_mat.shader = load(SHADERS + "_barrel_fire.gdshader")
	var spark_ramp := gradient([F[6], F[5], F[3], F[2]], [0.0, 0.4, 0.7, 0.85])
	var fire := gradient([FR[0], FR[1], FR[2], FR[3], FR[4], FR[5], FR[6], FR[7], Color(FR[7], 0.0)],
		[0.0, 0.03, 0.08, 0.16, 0.25, 0.36, 0.48, 0.64, 0.92])
	var bu := []                    # every frame after the blast (60 Hz)
	for i in int(ceil((D - BLOW) * 60.0)) + 1:
		bu.append(BLOW + i / 60.0)

	# ---------------------------------------------------------------- the drum straining
	var drum := shape("Drum", load(SHADERS + "_barrel.gdshader"), Vector2(24, 34), {"c1": C[1], "c2": C[2], "c3": C[3], "c4": C[4],
		"c5": C[5], "outline": OUTLINE, "band_lit": Color("#e8d8b0"), "band_mid": Color("#b8a888"), "band_dark": Color("#6e6050")},
		{"at": Vector2(0, -14)})
	var sk := []
	var kk := []
	var la := []
	var lr := []
	for i in int(BLOW * 60.0) + 1:
		var t := i / 60.0
		var k := t / BLOW
		sk.append([t, Vector2(sin(t * 70.0) * k * k * 1.4, -absf(sin(t * 53.0)) * k * k * 0.8)])
		kk.append([t, k])
		lr.append([t, 10.0 + 8.0 * k])
		la.append([t, 0.25 + 0.35 * k * k * (0.6 + 0.4 * sin(t * 40.0))])
	key(drum, "material:shader_parameter/shake", sk)
	key(drum, "material:shader_parameter/k", kk)
	show(drum, 0.0, BLOW)
	var lid_light := glow("LidLight", 20, {"radius": 10, "color": F[4], "alpha": 0.25}, {"at": Vector2(0, -BH)})
	key(lid_light, "material:shader_parameter/radius", lr)
	key(lid_light, "material:shader_parameter/alpha", la)
	show(lid_light, 0.0, BLOW)
	# flame and sparks spitting from the seam under the lid, quicker as it goes; smoke curling off the top
	for s in [-1, 1]:
		var spit := particles("Spit%s" % ("L" if s < 0 else "R"), {"at": Vector2(s * 5.5, -BH + 1), "amount": 6, "lifetime": 0.3,
			"randomness": 0.5, "texture": "dot4", "emit": {"box": Vector2(1.5, 0.5)}, "dir": -90 + s * 50, "spread": 25,
			"speed": [30, 70], "damping": [120, 180], "gravity": Vector2(0, -60), "scale": [0.6, 1.2],
			"scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
		spit.material = fire_mat
		var sp := particles("SeamSparks%s" % ("L" if s < 0 else "R"), {"at": Vector2(s * 6, -BH + 1), "amount": 5, "lifetime": 0.25,
			"randomness": 0.5, "texture": "streak3", "align": true, "dir": -90 + s * 45, "spread": 30, "speed": [60, 150],
			"damping": [150, 250], "gravity": Vector2(0, 430), "ramp": spark_ramp})
		var r := []
		for i in 9:
			var t := i * BLOW / 8.0
			var k := t / BLOW
			r.append([t, clampf((6.0 + 30.0 * k * k) / 2.0 * 0.3 / 6.0 * 1.6, 0.1, 1.0)])
		key(spit, "amount_ratio", r)
		key(sp, "amount_ratio", r)
		emit(spit, 0.0, BLOW)
		emit(sp, 0.0, BLOW)
	var curl := particles("Curl", {"layer": "soft", "at": Vector2(0, -BH - 2), "amount": 12, "lifetime": 1.3, "randomness": 0.4,
		"texture": "disc7", "emit": {"box": Vector2(5, 1)}, "dir": -90, "spread": 15, "speed": [15, 35], "damping": [10, 20],
		"gravity": Vector2(0, -10), "scale": [0.5, 0.8], "scale_curve": [[0, 0.7], [0.4, 1.1], [1, 1.5]],
		"ramp": gradient([Color(SMOKE[0], 0.0), Color(SMOKE[0], 0.5), Color(SMOKE[1], 0.4), Color(SMOKE[2], 0.25), Color(SMOKE[3], 0.0)],
			[0.0, 0.06, 0.35, 0.7, 0.95])})
	emit(curl, 0.0, BLOW)

	# ---------------------------------------------------------------- the floor
	var heat := gradient(FR.slice(0, 8) + [FR[8].lerp(SOOT, 0.3), FR[8].lerp(SOOT, 0.65)])
	var px := PackedFloat32Array()
	var pw := PackedFloat32Array()
	for i in 7:
		px.append(rng.randf_range(-34, 34))
		pw.append(rng.randf_range(5, 10))
	var scorch := shape("Scorch", load(SHADERS + "_barrel_scorch.gdshader"), Vector2(90, 10),
		{"heat": heat, "soot": SOOT, "soot2": Color("#17121d"), "oil": Color("#221a22"), "fleck": F[4], "rx0": 30.0, "cool": 2.2,
		"rows": 3.0, "u": 0.0, "fade": 0.0, "left": 0.0, "pool_x": px, "pool_w": pw}, {"back": true})
	var su := [[0.0, 0.0]]
	var sf := [[0.0, 0.0]]
	var sl := [[0.0, 0.0]]
	var fl := [[0.0, 0.0]]
	for t in bu:
		var u: float = t - BLOW
		su.append([t, u])
		sf.append([t, 1.0 - smooth(D - BLOW - 1.0, D - BLOW - 0.2, u)])
		sl.append([t, 1.0 - smooth(1.6, 3.4, u)])
		fl.append([t, floorf(t * 12.0)])
	key(scorch, "material:shader_parameter/u", su)
	key(scorch, "material:shader_parameter/fade", sf, "nearest")
	key(scorch, "material:shader_parameter/left", sl, "nearest")
	key(scorch, "material:shader_parameter/flick", fl, "nearest")
	for side in [[1.0, true, "BandBack"], [-1.0, false, "BandFront"]]:
		var band := ring(side[2], 106, {"radius": 1, "thickness": 4.5, "squash": 0.16, "color": F[3], "edge": 1.0, "edge_color": F[6],
			"side": side[0]}, {"at": Vector2(0, 0.5), "back": side[1]})
		var rk := []
		var tk := []
		var ak := []
		for i in 28:
			var u := i * 0.45 / 27.0
			var k := u / 0.45
			rk.append([BLOW + u, maxf(1.0, 100.0 * out_cubic(k))])
			tk.append([BLOW + u, maxf(1.0, 4.5 * (1.0 - k))])
			ak.append([BLOW + u, minf(1.0, 1.15 - k)])
		key(band, "material:shader_parameter/radius", rk)
		key(band, "material:shader_parameter/thickness", tk)
		key(band, "material:shader_parameter/alpha", ak)
		key(band, "material:shader_parameter/color", [[BLOW, F[3]], [BLOW + 0.22, Color("#6e6390")]], "nearest")
		key(band, "material:shader_parameter/edge_color", [[BLOW, F[6]], [BLOW + 0.17, F[3]], [BLOW + 0.31, Color("#6e6390")]], "nearest")
		show(band, BLOW, BLOW + 0.45)

	# ---------------------------------------------------------------- light
	var swell := glow("Swell", 92, {"radius": 90, "color": F[3].lerp(F[6], 0.45), "alpha": 0.0}, {"at": Vector2(0, Y - 20)})
	var pop := glow("Pop", 46, {"radius": 44, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, Y)})
	var pool := glow("Pool", 92, {"radius": 90, "squash": 14.0 / 90.0, "color": F[3], "alpha": 0.0}, {"at": Vector2(0, 1)})
	var sw_r := [[0.0, 90.0]]
	var sw_a := [[0.0, 0.0], [BLOW - 0.001, 0.0]]
	var po_r := [[0.0, 44.0]]
	var po_a := [[0.0, 0.0], [BLOW - 0.001, 0.0]]
	var pl_a := [[0.0, 0.0], [BLOW - 0.001, 0.0]]
	for t in bu:
		var u: float = t - BLOW
		var k1 := maxf(0.0, 1.0 - u / 0.9)
		var k2 := maxf(0.0, 1.0 - u / 0.09)
		if u <= 1.0:
			sw_r.append([t, 90.0 * (0.55 + 0.45 * k1)])
			sw_a.append([t, 0.85 * k1 * k1])
			po_r.append([t, 44.0 * (0.55 + 0.45 * k2)])
			po_a.append([t, 0.7 * k2 * k2])
		pl_a.append([t, 0.5 * maxf(0.0, 1.0 - u / 0.7) + 0.22 * (1.0 - smooth(1.6, 3.4, u))])
	key(swell, "material:shader_parameter/radius", sw_r)
	key(swell, "material:shader_parameter/alpha", sw_a)
	key(pop, "material:shader_parameter/radius", po_r)
	key(pop, "material:shader_parameter/alpha", po_a)
	key(pool, "material:shader_parameter/alpha", pl_a)

	# ---------------------------------------------------------------- the flash and the flare
	var flash := ring("Flash", 22, {"radius": 18, "color": F[6], "edge": 1.4, "edge_color": F[2]}, {"at": Vector2(0, Y)})
	var core := ring("FlashCore", 12, {"radius": 10.8, "color": Color.WHITE}, {"at": Vector2(0, Y)})
	key(flash, "material:shader_parameter/radius", [[BLOW, 18.0], [BLOW + 0.034, 16.9], [BLOW + 0.067, 15.8]], "nearest")
	key(flash, "material:shader_parameter/color", [[BLOW, F[6]], [BLOW + 0.044, F[5]]], "nearest")
	key(core, "material:shader_parameter/radius", [[BLOW, 10.8], [BLOW + 0.034, 10.1], [BLOW + 0.067, 9.5]], "nearest")
	key(core, "material:shader_parameter/color", [[BLOW, Color.WHITE], [BLOW + 0.044, F[6]]], "nearest")
	show(flash, BLOW, BLOW + 0.08)
	show(core, BLOW, BLOW + 0.08)
	var ray_grad := gradient([Color.WHITE, F[6], F[5]], [0.0, 0.35, 0.7])
	for i in 8:
		var an := i * PI / 4.0
		var lf := 1.0 if i % 4 == 0 else (0.6 if i % 2 == 0 else 0.3)
		var dv := Vector2(cos(an), sin(an))
		var ray := line("Flare%d" % i, PackedVector2Array([Vector2.ZERO, dv]), {"width": 1, "gradient": ray_grad, "at": Vector2(0, Y)})
		var pts := []
		for k in 15:
			var u := k * 0.22 / 14.0
			pts.append([BLOW + u, PackedVector2Array([Vector2.ZERO, dv * maxf(54.0 * pow(1.0 - u / 0.22, 1.4) * lf, 0.5)])])
		key(ray, "points", pts)
		key(ray, "modulate:a", [[BLOW, 1.0], [BLOW + 0.22, 0.5]])
		show(ray, BLOW, BLOW + 0.22)

	# ---------------------------------------------------------------- fire and smoke
	var at := Vector2(0, Y)
	var big := particles("FireCore", {"at": at, "amount": 5, "lifetime": 0.28, "one_shot": true, "explosiveness": 1.0, "randomness": 0.35,
		"emitting": false, "texture": "dot4", "emit": {"circle": 3}, "dir": -90, "spread": 50, "speed": [10, 40], "damping": [80, 120],
		"gravity": Vector2(0, -95), "scale": [5.9, 7.9], "scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
	big.material = fire_mat
	emit(big, BLOW)
	var ball := particles("Fire", {"at": at + Vector2(0, -10), "amount": 30, "lifetime": 1.05, "one_shot": true, "explosiveness": 1.0,
		"randomness": 0.48, "emitting": false, "texture": "dot4", "emit": {"circle": 8}, "dir": -90, "spread": 100, "speed": [50, 180],
		"damping": [300, 360], "gravity": Vector2(0, 80), "scale": [3.3, 6.6], "scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
	ball.material = fire_mat
	emit(ball, BLOW)
	var column := particles("Column", {"at": at + Vector2(0, -5), "amount": 12, "lifetime": 1.15, "one_shot": true, "explosiveness": 0.9,
		"randomness": 0.4, "emitting": false, "texture": "dot4", "emit": {"box": Vector2(6, 5)}, "dir": -90, "spread": 4, "speed": [170, 300],
		"damping": [400, 460], "gravity": Vector2(0, -40), "scale": [3.9, 6.6], "scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
	column.material = fire_mat
	emit(column, BLOW)
	# oily black smoke off the fireball, grey smoke where the column's fire burns out
	var soot := gradient([Color("#1f1a24", 0.0), Color("#1f1a24", 0.7), Color(SMOKE[3], 0.6), Color(SMOKE[3], 0.35), Color(SMOKE[4], 0.0)],
		[0.0, 0.05, 0.4, 0.7, 0.95])
	var oily := particles("Soot", {"layer": "soft", "at": at + Vector2(0, -8), "amount": 12, "lifetime": 2.2, "one_shot": true, "explosiveness": 0.85,
		"randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(14, 6)}, "dir": -90, "spread": 30, "speed": [30, 90],
		"damping": [25, 45], "gravity": Vector2(0, -14), "scale": [1.1, 1.6], "scale_curve": [[0, 0.7], [0.4, 1.1], [1, 1.5]], "ramp": soot,
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(oily, BLOW + 0.1)
	var grey := gradient([Color(SMOKE[0], 0.0), Color(SMOKE[0], 0.6), Color(SMOKE[1], 0.5), Color(SMOKE[2], 0.35), Color(SMOKE[3], 0.0)],
		[0.0, 0.05, 0.35, 0.7, 0.95])
	var high := particles("SmokeHigh", {"layer": "soft", "at": Vector2(0, -88), "amount": 11, "lifetime": 1.7, "one_shot": true, "explosiveness": 0.6,
		"randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(7, 26)}, "dir": -90, "spread": 25, "speed": [10, 40],
		"damping": [10, 20], "gravity": Vector2(0, -30), "scale": [0.8, 1.2], "scale_curve": [[0, 0.7], [0.4, 1.1], [1, 1.5]], "ramp": grey,
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(high, BLOW + 0.55)
	var low := particles("SmokeLow", {"layer": "soft", "at": at + Vector2(-4, -30), "amount": 15, "lifetime": 1.7, "one_shot": true, "explosiveness": 0.6,
		"randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(30, 16)}, "dir": -90, "spread": 30, "speed": [10, 40],
		"damping": [10, 20], "gravity": Vector2(0, -16), "scale": [0.7, 1.1], "scale_curve": [[0, 0.7], [0.4, 1.1], [1, 1.5]], "ramp": grey,
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(low, BLOW + 0.4)
	var dust := gradient([Color(DUST, 0.0), Color(DUST, 0.7), Color(SMOKE[0], 0.55), Color(SMOKE[1], 0.35), Color(SMOKE[1], 0.0)], [0.0, 0.04, 0.35, 0.7, 0.96])
	var roll := particles("Dust", {"layer": "soft", "at": Vector2(0, -3), "amount": 12, "lifetime": 1.8, "one_shot": true, "explosiveness": 0.95,
		"randomness": 0.4, "emitting": false, "texture": "disc13", "dir": 0, "speed": [80, 220], "damping": [110, 160],
		"gravity": Vector2(0, -8), "scale": [0.8, 1.1], "scale_curve": [[0, 0.7], [0.5, 1.2], [1, 1.5]], "ramp": dust})
	two_ways(roll, 10.0)
	emit(roll, BLOW)

	# ---------------------------------------------------------------- sparks, embers, brands and the fires they light
	var sparks := particles("Sparks", {"at": at, "amount": 90, "lifetime": 0.6, "one_shot": true, "explosiveness": 1.0, "randomness": 0.6,
		"emitting": false, "texture": "streak4", "align": true, "dir": -90, "spread": 180, "speed": [160, 400], "damping": [240, 380],
		"gravity": Vector2(0, 430), "ramp": spark_ramp, "collide": {"bounce": 0.45, "friction": 0.3}})
	emit(sparks, BLOW)
	var sparks_lit := particles("SparksLight", {"layer": "light", "at": at, "amount": 90, "lifetime": 0.6, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.6, "emitting": false, "texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	sparks_lit.process_material = sparks.process_material
	sparks_lit.seed = sparks.seed
	emit(sparks_lit, BLOW)
	var embers := particles("Embers", {"at": at, "amount": 40, "lifetime": 2.6, "one_shot": true, "explosiveness": 1.0, "randomness": 0.55,
		"emitting": false, "texture": "dot1", "emit": {"ring": [8, 7]}, "dir": -90, "spread": 180, "speed": [30, 140], "damping": [60, 90],
		"gravity": Vector2(0, -20), "ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.95]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})
	emit(embers, BLOW)
	var brands := particles("Brands", {"at": at, "amount": 14, "lifetime": 1.4, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": "disc3", "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 69, "speed": [120, 300],
		"damping": [60, 120], "gravity": Vector2(0, 760), "ramp": gradient([Color(HOT[0]), Color(HOT[3]), Color(HOT[1]), Color(HOT[3])], [0.0, 0.1, 0.5, 0.6]),
		"collide": {"hide": true, "size": 2}})
	emit(brands, BLOW)
	var trail := particles("BrandTrails", {"at": at, "amount": 14, "lifetime": 1.4, "one_shot": true, "explosiveness": 1.0, "randomness": 0.4,
		"emitting": false, "texture": trail_tex(9), "align": true, "color": Color(HOT[2])})
	trail.process_material = brands.process_material.duplicate()
	(trail.process_material as ParticleProcessMaterial).particle_flag_align_y = true
	(trail.process_material as ParticleProcessMaterial).color_ramp = null
	(trail.process_material as ParticleProcessMaterial).color = Color(HOT[2])
	trail.seed = brands.seed
	emit(trail, BLOW)
	var brands_lit := particles("BrandsLight", {"layer": "light", "at": at, "amount": 14, "lifetime": 1.4, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.4, "emitting": false, "texture": "glow16", "modulate": Color(1, 0.7, 0.4, 0.45)})
	brands_lit.process_material = brands.process_material
	brands_lit.seed = brands.seed
	emit(brands_lit, BLOW)
	# where the brands fell: small fires along the floor
	var blazes := particles("Blazes", {"at": Vector2(0, -1), "amount": 26, "lifetime": 0.5, "randomness": 0.4, "emitting": false,
		"texture": "dot4", "emit": {"box": Vector2(85, 0.5)}, "dir": -90, "spread": 12, "speed": [12, 30], "damping": [10, 20],
		"gravity": Vector2(0, -60), "scale": [0.6, 1.4], "scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
	blazes.material = fire_mat
	emit(blazes, BLOW + 0.45, BLOW + 2.2)
	key(blazes, "amount_ratio", [[BLOW + 0.45, 0.4], [BLOW + 0.8, 1.0], [BLOW + 1.4, 0.6], [BLOW + 2.2, 0.2]])
	# the smoke off the little fires: wisps rising off the floor
	var wisps := particles("Wisps", {"layer": "soft", "at": Vector2(0, -8), "amount": 16, "lifetime": 0.9, "randomness": 0.4, "emitting": false,
		"texture": "disc3", "emit": {"box": Vector2(36, 3)}, "dir": -90, "spread": 12, "speed": [14, 26], "gravity": Vector2(0, -10),
		"scale_curve": [[0, 0.7], [1, 1.4]], "ramp": gradient([Color(SMOKE[1], 0.6), Color(SMOKE[2], 0.45), Color(SMOKE[2], 0.0)], [0.0, 0.5, 0.95])})
	emit(wisps, BLOW + 0.5, BLOW + 2.9)
	key(wisps, "amount_ratio", [[BLOW + 0.5, 1.0], [BLOW + 1.8, 0.8], [BLOW + 2.9, 0.3]])
	# the spilled fuel burning in pools
	for i in 7:
		var life := rng.randf_range(2.2, 3.0)
		var power := rng.randf_range(0.8, 1.3)
		var f := particles("Pool%d" % i, {"at": Vector2(px[i], -1), "amount": 14, "lifetime": 0.6, "randomness": 0.5, "emitting": false,
			"texture": "dot4", "emit": {"box": Vector2(1.5 + pw[i] * 0.15, 0.5)}, "dir": -90, "spread": 12, "speed": [12, 30],
			"damping": [10, 20], "gravity": Vector2(0, -70), "scale": [0.8 * power, 1.8 * power],
			"scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
		f.material = fire_mat
		emit(f, BLOW, BLOW + life)
		var ar := []
		for k in 11:
			var u := k * life / 10.0
			var kl := 1.0 - u / life
			ar.append([BLOW + u, (1.0 if kl > 0.7 else 0.35 + kl / 0.7 * 0.65) * minf(1.0, power)])
		key(f, "amount_ratio", ar)
		var g := glow("PoolLight%d" % i, 18, {"radius": 11, "color": Color(HOT[2]), "alpha": 0.0}, {"at": Vector2(px[i], 0)})
		key(g, "material:shader_parameter/alpha", [[0.0, 0.0], [BLOW - 0.001, 0.0], [BLOW, 0.3 * power], [BLOW + life, 0.0]])
		key(g, "material:shader_parameter/radius", [[BLOW, 6.0 + 5.0 * power], [BLOW + life, 6.0]])

	# ---------------------------------------------------------------- staves and the lid
	var stave_shader: Shader = load(SHADERS + "_barrel_stave.gdshader")
	for i in 9:
		var side := 1.0 if i % 2 else -1.0
		var a0 := -PI / 2.0 + side * rng.randf_range(0.25, 1.15)
		var spd := rng.randf_range(170, 330)
		var b := {"x": side * rng.randf_range(2, 6), "y": -rng.randf_range(4, BH - 4), "vx": cos(a0) * spd, "vy": sin(a0) * spd,
			"life": rng.randf_range(3.0, 3.8), "a": rng.randf_range(0, TAU), "va": rng.randf_range(-16, 16), "s": rng.randf_range(9, 13),
			"heat": rng.randf_range(0.4, 0.9), "rest": false}
		var keys := replay_stave(b)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for k in keys:
			lo = lo.min(k[1])
			hi = hi.max(k[1])
		var m: float = ceilf(b.s / 2.0) + 4.0
		var c := ((lo + hi) / 2.0).floor()
		var sz := ((hi - lo) / 2.0).ceil() * 2.0 + Vector2(m, m) * 2.0
		var node := shape("Stave%d" % i, stave_shader, sz, {"len": b.s, "face_lit": C[4], "face_dark": C[2], "inside": C[1],
			"outline": OUTLINE, "hot1": FR[3], "hot2": FR[5], "fade": 1.0}, {"at": c})
		key(node, "material:shader_parameter/pos", keys.map(func(k): return [k[0], k[1]]))
		key(node, "material:shader_parameter/a", keys.map(func(k): return [k[0], k[2]]))
		key(node, "material:shader_parameter/heat", keys.map(func(k): return [k[0], k[3]]))
		key(node, "material:shader_parameter/fade", keys.map(func(k): return [k[0], k[4]]))
		show(node, BLOW, keys[-1][0])
		var sg := glow("StaveLight%d" % i, 8, {"radius": 6, "color": FR[4], "alpha": 0.0})
		key(sg, "position", keys.map(func(k): return [k[0], k[1]]))
		key(sg, "material:shader_parameter/alpha", keys.map(func(k): return [k[0], 0.25 * k[3] * k[4] if k[3] > 0.3 else 0.0]))
		show(sg, BLOW, keys[-1][0])
	# the lid, flung high and spinning, landing with a clank
	var lid := {"x": 0.0, "y": -BH, "vx": rng.randf_range(-40, 40), "vy": -rng.randf_range(430, 480), "a": 0.0,
		"va": (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(10, 14), "rest": false}
	var lk := []
	var lands := []
	var dt := 1.0 / 120.0
	var t := BLOW
	var step := 0
	while t <= D + 1e-6:
		if step % 2 == 0:
			var rx: float = 7.5 if lid.rest else maxf(0.8, absf(cos(lid.a)) * 7.5)
			var ry: float = 1.6 if lid.rest else maxf(1.2, absf(sin(lid.a)) * 7.5)
			lk.append([t, Vector2(lid.x, lid.y - (0.5 if lid.rest else 0.0)), Vector2(rx, ry), minf(1.0, (D - t) / 0.4)])
		t += dt
		step += 1
		if lid.rest:
			continue
		lid.vy += 950.0 * dt
		lid.vx -= lid.vx * 0.4 * dt
		lid.x += lid.vx * dt
		lid.y += lid.vy * dt
		lid.a += lid.va * dt
		if lid.y >= -1.0 and lid.vy > 0.0:
			lands.append([t, lid.x])
			lid.y = -1.0
			if lid.vy > 160.0:
				lid.vy *= -0.3
				lid.vx *= 0.5
				lid.va *= 0.5
			else:
				lid.rest = true
				lid.a = PI / 2.0
	var lid_node := shape("Lid", load(SHADERS + "_barrel_lid.gdshader"), Vector2(60, 140), {"face": C[3], "rim_lit": C[4], "rim_dark": C[2],
		"outline": OUTLINE}, {"at": Vector2(0, -66)})
	key(lid_node, "material:shader_parameter/pos", lk.map(func(k): return [k[0], k[1]]))
	key(lid_node, "material:shader_parameter/radii", lk.map(func(k): return [k[0], k[2]]))
	key(lid_node, "material:shader_parameter/alpha", lk.map(func(k): return [k[0], k[3]]))
	show(lid_node, BLOW)
	var dust_ramp := gradient([Color(DUST, 0.7), Color(DUST, 0.45), Color(DUST, 0.2), Color(DUST, 0.0)], [0.0, 0.35, 0.7, 0.95])
	for i in lands.size():
		var l: Array = lands[i]
		var clank := particles("ClankSparks%d" % i, {"at": Vector2(l[1], -1), "amount": 6, "lifetime": 0.25, "one_shot": true,
			"explosiveness": 1.0, "randomness": 0.5, "emitting": false, "texture": "streak3", "align": true, "dir": -90, "spread": 50,
			"speed": [50, 160], "damping": [120, 200], "gravity": Vector2(0, 430), "ramp": spark_ramp})
		emit(clank, l[0])
		var puff := particles("ClankDust%d" % i, {"layer": "soft", "at": Vector2(l[1], -0.5), "amount": 5, "lifetime": 0.7, "one_shot": true,
			"explosiveness": 1.0, "randomness": 0.5, "emitting": false, "texture": "disc5", "emit": {"box": Vector2(4, 0.5)}, "dir": -90,
			"spread": 80, "speed": [15, 60], "damping": [50, 80], "scale_curve": [[0, 0.8], [1, 1.6]], "ramp": dust_ramp})
		emit(puff, l[0])

	# the flash goes over everything, as the original draws it last
	for n in [flash, core]:
		root.move_child(n, -1)
	for i in 8:
		root.move_child(root.get_node("Flare%d" % i), -1)

	# ---------------------------------------------------------------- the floor's grit
	for k in 2:
		var grit := particles("Grit%d" % k, {"at": Vector2(0, -1), "amount": [36, 24][k], "lifetime": 1.9, "one_shot": true, "explosiveness": 1.0,
			"randomness": 0.4, "emitting": false, "texture": ["dot1", "dot2"][k], "emit": {"box": Vector2(6, 0.5)}, "dir": -90, "spread": 40,
			"speed": [120, 330], "damping": [40, 80], "gravity": Vector2(0, 950), "initial": gradient(STONE),
			"alpha_curve": [[0, 1], [0.75, 1], [0.76, 0]], "collide": {"bounce": 0.15, "friction": 1.0}})
		emit(grit, BLOW)


## The original's Bits update for one stave (120 Hz), sampled at 30 Hz: [t, pos, angle, heat, fade].
func replay_stave(b: Dictionary) -> Array:
	var out := []
	var dt := 1.0 / 120.0
	var t := BLOW
	var step := 0
	var X1: float = meta.size[0] - meta.origin[0] - 3 - 8
	var X0: float = -meta.origin[0] + 3 + 8
	while b.life > 0.0:
		if step % 4 == 0:
			out.append([t, Vector2(b.x, b.y), b.a, b.heat, minf(1.0, b.life / 0.5)])
		t += dt
		step += 1
		b.life -= dt
		if not b.rest:
			b.vy += 950.0 * dt
			b.vx -= b.vx * 0.5 * dt
			b.vy -= b.vy * 0.5 * dt
			b.x += b.vx * dt
			b.y += b.vy * dt
			b.a += b.va * dt
			var sp: float = b.vy
			if b.y >= 0.0 and sp > 0.0:
				b.y = -0.01
				if sp > 70.0:
					b.vy = -sp * 0.35
					b.vx *= 0.7
					b.va *= 0.6
				else:
					b.rest = true
					b.vx = 0.0
					b.vy = 0.0
		if b.x < X0 or b.x > X1:
			break
		b.heat = maxf(0.0, b.heat - dt * 0.35)
	out.append([t, Vector2(b.x, b.y), b.a, b.heat, 0.0])
	return out


## Dust thrown out both ways along the floor: half the particles to the left, half to the right.
func two_ways(p: GPUParticles2D, w: float) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in 16:
		pts.append(Vector2((i - 7.5) / 7.5 * w, 0))
		nor.append(Vector2(-1, 0) if i % 2 == 0 else Vector2(1, 0))
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(pts)
	m.emission_normal_texture = _points_texture(nor)
	m.emission_point_count = pts.size()
	m.direction = Vector3(1, -0.05, 0)
	m.spread = 8.0


## A brand's trail for a particle aligned with its flight: flame behind it (the upper half of the texture: an aligned
## particle's +y points along its flight), fading out toward its end, nothing ahead.
func trail_tex(h: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.45), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 1
	tex.height = h
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex
