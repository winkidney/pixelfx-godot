# reimagined-from: src/fx/explosions/grenade.js@9445937985bf8cbf63fcb1d708cc634c463bcea9
# Grenade: a grenade is lobbed in, bounces, rolls to a stop with its fuse fizzing, shudders, then blows: a white
# flash, shrapnel streaks, sparks, a small fireball and a scorch.
# The grenade is a shader of its own (_grenade.gdshader: the original's pineapple, turned) whose place and turn replay
# the original's lob, bounces and roll at its 120 Hz, keyed every frame; the fuse spits sparks and a thread of smoke
# from an emitter riding its tip, and each bounce kicks up dust and sparks. The blast: a hot disc for two frames, an
# eight-ray flare (lines), a shock dome cut off at the floor (_grenade_shock.gdshader), a band rolling out along the
# floor (ring shader), the scorch (_grenade_scorch.gdshader, the original's cooling burn), glows and a pool of light;
# shrapnel streaks, sparks, a fireball of puffs cooling into smoke, embers, casing shards and grit landing on a
# collision floor, dust rolling out along it.
extends "res://addons/pixelfx_particles/core/build.gd"

const BLOW := 1.62
const RB := 6.2
const BY := -5.0
const METAL := ["#3a3c46", "#6a6e7c", "#a8acb8"]
const STONE := ["#5a4f6b", "#3e3650", "#776c88"]
const DUST := "#7d7280"
const SMOKE := ["#7b6f72", "#5d5660", "#433d48", "#2b2630", "#1a171e"]


static func smooth(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func make() -> void:
	ground()
	var F: PackedColorArray = root.ramps.palette
	var G: PackedColorArray = root.ramps.body
	var D: float = meta.duration
	var FR := [F[7], F[6], F[5], F[4], F[3], F[2], F[1], F[1].lerp(F[0], 0.5), F[0]]
	var SOOT := Color("#0d0a12")
	var SOOT2 := Color("#17121d")
	var HR: Array = FR.slice(0, 8) + [FR[8].lerp(SOOT, 0.3), FR[8].lerp(SOOT, 0.65)]

	# ---------------------------------------------------------------- the lob, the bounces, the roll (120 Hz)
	var gx := -140.0
	var gy := -70.0
	var vx := 168.0
	var vy := -150.0
	var ga := 0.0
	var va := -9.0
	var rest := false
	var bounces := []
	var path := []          # [t, pos (with the shudder), angle]
	var dt := 1.0 / 120.0
	var t := 0.0
	var step := 0
	while t < BLOW - 1e-6:
		if step % 2 == 0:
			var jx := smooth(BLOW - 0.45, BLOW, t) * sin(t * 90.0) * 0.8
			path.append([t, Vector2(gx + jx, gy), ga])
		t += dt
		step += 1
		if not rest:
			vy += 900.0 * dt
			gx += vx * dt
			gy += vy * dt
			if gy >= -RB and vy > 0.0:
				gy = -RB
				if vy > 90.0:
					bounces.append([t, gx])
					vy = -vy * 0.36
					vx *= 0.8
				else:
					vy = 0.0
			if gy >= -RB - 0.01 and vy == 0.0:
				vx -= vx * 2.4 * dt
				va = -vx / RB
				if absf(vx) < 3.0:
					rest = true
					vx = 0.0
			ga += va * dt
	path.append([BLOW, Vector2(gx, gy), ga])
	var bx := gx

	# ---------------------------------------------------------------- before the blast
	var body := shape("Grenade", load("res://addons/pixelfx_particles/fx/explosions/_grenade.gdshader"), Vector2(220, 120),
		{"b0": G[0], "b1": G[1], "b2": G[2], "b3": G[3], "b4": G[4], "m0": Color("#2a2c36"), "m1": Color("#5e6270"),
		"m2": Color("#9a9eac"), "m3": Color("#d0d4de"), "outline": Color("#1a1422"), "tip": F[6]}, {"at": Vector2(-44, -54)})
	var gk := []
	var ak := []
	var tk := []
	var tips := []
	var fl_r := []
	var fl_a := []
	for s in path:
		var tt: float = s[0]
		var a: float = s[2]
		var tip: Vector2 = s[1] + Vector2(sin(a) * 10.4, -cos(a) * 10.4)
		gk.append([tt, s[1]])
		ak.append([tt, a])
		tk.append([tt, F[6] if sin(tt * 50.0) > 0.0 else F[5]])
		tips.append([tt, tip])
		var shake := smooth(BLOW - 0.45, BLOW, tt)
		fl_r.append([tt, 6.0 + 3.0 * shake])
		fl_a.append([tt, 0.5 + 0.3 * sin(tt * 37.0)])
	key(body, "material:shader_parameter/g", gk)
	key(body, "material:shader_parameter/a", ak)
	key(body, "material:shader_parameter/tip", tk, "nearest")
	show(body, 0.0, BLOW)
	var fuse_light := glow("FuseLight", 12, {"radius": 6, "color": F[4], "alpha": 0.5})
	key(fuse_light, "position", tips)
	key(fuse_light, "material:shader_parameter/radius", fl_r)
	key(fuse_light, "material:shader_parameter/alpha", fl_a)
	show(fuse_light, 0.0, BLOW)
	var spark_ramp := gradient([F[6], F[5], F[3], F[2]], [0.0, 0.4, 0.7, 0.85])
	# the fuse: sparks spitting off its tip, quicker as it runs down, and a thread of smoke
	var fizz := particles("Fizz", {"amount": 12, "lifetime": 0.2, "randomness": 0.6, "texture": "streak3", "align": true,
		"dir": -90, "spread": 35, "speed": [40, 110], "damping": [120, 200], "gravity": Vector2(0, 430), "ramp": spark_ramp})
	key(fizz, "position", tips)
	var rate := []
	for i in 17:
		var tt := i * BLOW / 16.0
		rate.append([tt, (24.0 + 50.0 * smooth(BLOW - 0.5, BLOW, tt)) / 74.0])
	key(fizz, "amount_ratio", rate)
	emit(fizz, 0.0, BLOW)
	var vapour := particles("Vapour", {"layer": "soft", "amount": 7, "lifetime": 0.9, "randomness": 0.4, "texture": "disc5",
		"dir": -90, "spread": 15, "speed": [10, 20], "damping": [6, 10], "scale_curve": [[0, 0.4], [1, 1.0]],
		"ramp": gradient([Color("#8a8494", 0.4), Color("#8a8494", 0.25), Color("#8a8494", 0.12), Color("#8a8494", 0.0)], [0.0, 0.3, 0.6, 0.9])})
	key(vapour, "position", tips.map(func(k): return [k[0], k[1] + Vector2(0, -1)]))
	emit(vapour, 0.0, BLOW)
	# a clink at each bounce: a puff of dust and a few sparks
	var dust_ramp := gradient([Color(DUST, 0.7), Color(DUST, 0.45), Color(DUST, 0.2), Color(DUST, 0.0)], [0.0, 0.35, 0.7, 0.95])
	for i in bounces.size():
		var b: Array = bounces[i]
		var puff := particles("ClinkDust%d" % i, {"layer": "soft", "at": Vector2(b[1], -0.5), "amount": 4, "lifetime": 0.6,
			"one_shot": true, "explosiveness": 1.0, "randomness": 0.5, "emitting": false, "texture": "disc3", "dir": -90, "spread": 80,
			"speed": [10, 40], "damping": [40, 60], "scale_curve": [[0, 0.8], [1, 1.8]], "ramp": dust_ramp})
		emit(puff, b[0])
		var clink := particles("ClinkSparks%d" % i, {"at": Vector2(b[1], -1), "amount": 3, "lifetime": 0.16, "one_shot": true,
			"explosiveness": 1.0, "randomness": 0.5, "emitting": false, "texture": "streak3", "align": true, "dir": -90, "spread": 40,
			"speed": [50, 130], "damping": [100, 160], "gravity": Vector2(0, 430), "ramp": spark_ramp})
		emit(clink, b[0])

	# ---------------------------------------------------------------- the blast
	var at := Vector2(bx, BY)
	var fu := []
	var n := int(ceil((D - BLOW) * 60.0))
	for i in n + 1:
		fu.append(BLOW + i / 60.0)

	# the floor: the scorch (where the original puts it, under the origin), and a band rolling out along the floor
	var heat := gradient(HR)
	var scorch := shape("Scorch", load("res://addons/pixelfx_particles/fx/explosions/_grenade_scorch.gdshader"), Vector2(52, 8),
		{"heat": heat, "soot": SOOT, "soot2": SOOT2, "rx0": 22.0, "cool": 1.6, "rows": 2.0, "u": 0.0, "fade": 0.0}, {"back": true})
	var su := [[0.0, 0.0]]
	var sf := [[0.0, 0.0]]
	for tt in fu:
		var u: float = tt - BLOW
		su.append([tt, u])
		sf.append([tt, 1.0 - smooth(D - BLOW - 0.8, D - BLOW - 0.15, u)])
	key(scorch, "material:shader_parameter/u", su)
	key(scorch, "material:shader_parameter/fade", sf, "nearest")
	var band_cols := [F[6], F[3], Color("#6e6390"), Color("#4a3f69")]
	for side in [[1.0, true, "BandBack"], [-1.0, false, "BandFront"]]:
		var band := ring(side[2], 74, {"radius": 1, "thickness": 3.5, "squash": 0.16, "color": F[3], "edge": 1.0, "edge_color": F[6],
			"side": side[0]}, {"at": Vector2(bx, 0.5), "back": side[1]})
		var rk := []
		var tk2 := []
		var ak2 := []
		for k in 25:
			var u := k * 0.4 / 24.0
			var kk := u / 0.4
			rk.append([BLOW + u, maxf(1.0, 70.0 * out_cubic(kk))])
			tk2.append([BLOW + u, maxf(1.0, 3.5 * (1.0 - kk))])
			ak2.append([BLOW + u, minf(1.0, 1.15 - kk)])
		key(band, "material:shader_parameter/radius", rk)
		key(band, "material:shader_parameter/thickness", tk2)
		key(band, "material:shader_parameter/alpha", ak2)
		key(band, "material:shader_parameter/color", [[BLOW, F[3]], [BLOW + 0.2, band_cols[2]]], "nearest")
		key(band, "material:shader_parameter/edge_color", [[BLOW, F[6]], [BLOW + 0.15, F[3]], [BLOW + 0.28, band_cols[2]]], "nearest")
		show(band, BLOW, BLOW + 0.4)

	# light: a warm swell, a white pop, a pool on the floor
	var swell := glow("Swell", 72, {"radius": 70, "color": F[3].lerp(F[6], 0.45), "alpha": 0.0}, {"at": Vector2(bx, BY - 10)})
	var pop := glow("Pop", 32, {"radius": 30, "color": Color.WHITE, "alpha": 0.0}, {"at": at})
	var pool := glow("Pool", 72, {"radius": 70, "squash": 12.0 / 70.0, "color": F[3], "alpha": 0.0}, {"at": Vector2(bx, 1)})
	var sw_r := [[0.0, 70.0]]
	var sw_a := [[0.0, 0.0], [BLOW - 0.001, 0.0]]
	var po_r := [[0.0, 30.0]]
	var po_a := [[0.0, 0.0], [BLOW - 0.001, 0.0]]
	var pl_a := [[0.0, 0.0], [BLOW - 0.001, 0.0]]
	for tt in fu:
		var u: float = tt - BLOW
		var k1 := maxf(0.0, 1.0 - u / 0.5)
		var k2 := maxf(0.0, 1.0 - u / 0.07)
		sw_r.append([tt, 70.0 * (0.55 + 0.45 * k1)])
		sw_a.append([tt, 0.85 * k1 * k1])
		po_r.append([tt, 30.0 * (0.55 + 0.45 * k2)])
		po_a.append([tt, 0.7 * k2 * k2])
		pl_a.append([tt, 0.55 * maxf(0.0, 1.0 - u / 0.6)])
		if u > 0.7:
			break
	key(swell, "material:shader_parameter/radius", sw_r)
	key(swell, "material:shader_parameter/alpha", sw_a)
	key(pop, "material:shader_parameter/radius", po_r)
	key(pop, "material:shader_parameter/alpha", po_a)
	key(pool, "material:shader_parameter/alpha", pl_a)

	# the flash: a hot disc for two frames, an eight-ray flare, a shock dome cut off at the floor
	var fat := Vector2(bx, -6)
	var flash := ring("Flash", 14, {"radius": 11, "color": F[6], "edge": 1.2, "edge_color": F[2]}, {"at": fat})
	var core := ring("FlashCore", 8, {"radius": 6.6, "color": Color.WHITE}, {"at": fat})
	key(flash, "material:shader_parameter/radius", [[BLOW, 11.0], [BLOW + 0.035, 10.2]], "nearest")
	key(flash, "material:shader_parameter/color", [[BLOW, F[6]], [BLOW + 0.0385, F[5]]], "nearest")
	key(core, "material:shader_parameter/radius", [[BLOW, 6.6], [BLOW + 0.035, 6.1]], "nearest")
	key(core, "material:shader_parameter/color", [[BLOW, Color.WHITE], [BLOW + 0.0385, F[6]]], "nearest")
	show(flash, BLOW, BLOW + 0.07)
	show(core, BLOW, BLOW + 0.07)
	var ray_grad := gradient([Color.WHITE, F[6], F[5]], [0.0, 0.35, 0.7])
	for i in 8:
		var an := i * PI / 4.0
		var lf := 1.0 if i % 4 == 0 else (0.6 if i % 2 == 0 else 0.3)
		var dv := Vector2(cos(an), sin(an))
		var ray := line("Flare%d" % i, PackedVector2Array([Vector2.ZERO, dv]), {"width": 1, "gradient": ray_grad, "at": fat})
		var pts := []
		for k in 13:
			var u := k * 0.2 / 12.0
			var L := 40.0 * pow(1.0 - u / 0.2, 1.4) * lf
			pts.append([BLOW + u, PackedVector2Array([Vector2.ZERO, dv * maxf(L, 0.5)])])
		key(ray, "points", pts)
		key(ray, "modulate:a", [[BLOW, 1.0], [BLOW + 0.2, 0.5]])
		show(ray, BLOW, BLOW + 0.2)
	var dome := shape("Shock", load("res://addons/pixelfx_particles/fx/explosions/_grenade_shock.gdshader"), Vector2(104, 104),
		{"radius": 8.0, "thickness": 2.9, "clip": 9.0, "color": F[5]}, {"at": fat})
	var dr := []
	var dth := []
	var da := []
	for k in 19:
		var u := k * 0.3 / 18.0
		var k3 := u / 0.3
		var r := 8.0 + 40.0 * out_cubic(k3)
		dr.append([BLOW + u, r])
		dth.append([BLOW + u, maxf(1.0, 2.5 * (1.0 - k3) + 0.4)])
		da.append([BLOW + u, minf(1.0, (1.0 - k3) * 1.6)])
	key(dome, "material:shader_parameter/radius", dr)
	key(dome, "material:shader_parameter/thickness", dth)
	key(dome, "material:shader_parameter/alpha", da)
	show(dome, BLOW, BLOW + 0.3)

	# shrapnel: hot streaks flying straight and far over the top half, with their light
	var shrap := particles("Shrapnel", {"at": at, "amount": 38, "lifetime": 0.26, "one_shot": true, "explosiveness": 1.0, "randomness": 0.5,
		"emitting": false, "texture": streak(10, 0.45), "align": true, "dir": -90, "spread": 87, "speed": [380, 640], "damping": [200, 300],
		"initial": gradient([F[7], F[6], F[5]]), "alpha_curve": [[0, 1], [0.8, 1], [1, 0.3]]})
	emit(shrap, BLOW)
	var shrap_lit := particles("ShrapnelLight", {"layer": "light", "at": at, "amount": 38, "lifetime": 0.26, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.5, "emitting": false, "texture": "glow8", "modulate": Color(1, 1, 1, 0.35)})
	shrap_lit.process_material = shrap.process_material
	shrap_lit.seed = shrap.seed
	emit(shrap_lit, BLOW)
	# sparks falling and bouncing
	var sparks := particles("Sparks", {"at": at, "amount": 60, "lifetime": 0.55, "one_shot": true, "explosiveness": 1.0, "randomness": 0.6,
		"emitting": false, "texture": "streak4", "align": true, "dir": -90, "spread": 180, "speed": [140, 360], "damping": [220, 360],
		"gravity": Vector2(0, 430), "ramp": spark_ramp, "collide": {"bounce": 0.45, "friction": 0.3}})
	emit(sparks, BLOW)
	var sparks_lit := particles("SparksLight", {"layer": "light", "at": at, "amount": 60, "lifetime": 0.55, "one_shot": true,
		"explosiveness": 1.0, "randomness": 0.6, "emitting": false, "texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	sparks_lit.process_material = sparks.process_material
	sparks_lit.seed = sparks.seed
	emit(sparks_lit, BLOW)

	# the fireball: puffs bursting out and rising, cooling down the fire ramp into smoke; a darker rim behind each
	var fire := gradient([FR[0], FR[1], FR[2], FR[3], FR[4], FR[5], FR[6], FR[7], Color(FR[7], 0.0)],
		[0.0, 0.03, 0.09, 0.18, 0.29, 0.41, 0.55, 0.72, 0.95])
	var fire_mat := ShaderMaterial.new()
	fire_mat.shader = load("res://addons/pixelfx_particles/fx/explosions/_grenade_fire.gdshader")
	var big := particles("FireCore", {"at": at, "amount": 4, "lifetime": 0.26, "one_shot": true, "explosiveness": 1.0, "randomness": 0.3,
		"emitting": false, "texture": "dot4", "emit": {"circle": 2}, "dir": -90, "spread": 40, "speed": [8, 30], "damping": [60, 90],
		"gravity": Vector2(0, -95), "scale": [3.9, 5.0], "scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
	big.material = fire_mat
	emit(big, BLOW)
	var puffs := particles("Fire", {"at": at + Vector2(0, -12), "amount": 16, "lifetime": 0.8, "one_shot": true, "explosiveness": 1.0, "randomness": 0.5,
		"emitting": false, "texture": "dot4", "emit": {"circle": 6}, "dir": -90, "spread": 110, "speed": [50, 160], "damping": [240, 300],
		"gravity": Vector2(0, 90), "scale": [2.3, 4.6], "scale_curve": [[0, 0.55], [0.14, 0.93], [1, 0.45]], "ramp": fire})
	puffs.material = fire_mat
	emit(puffs, BLOW)

	# smoke: big puffs rising off the fireball, dust rolling out along the floor
	var smoke := gradient([Color(SMOKE[0], 0.0), Color(SMOKE[0], 0.55), Color(SMOKE[1], 0.5), Color(SMOKE[2], 0.35), Color(SMOKE[3], 0.18), Color(SMOKE[3], 0.0)],
		[0.0, 0.05, 0.25, 0.5, 0.7, 0.9])
	var rise := particles("Smoke", {"layer": "soft", "at": Vector2(bx, BY - 12), "amount": 17, "lifetime": 1.75, "one_shot": true, "explosiveness": 0.9,
		"randomness": 0.35, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(14, 6)}, "dir": -90, "spread": 45,
		"speed": [20, 60], "damping": [20, 40], "gravity": Vector2(0, -12), "scale": [0.7, 1.15], "scale_curve": [[0, 0.7], [0.4, 1.1], [1, 1.45]],
		"ramp": smoke, "turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(rise, BLOW + 0.12)
	var dust := gradient([Color(DUST, 0.0), Color(DUST, 0.7), Color(SMOKE[0], 0.55), Color(SMOKE[1], 0.35), Color(SMOKE[1], 0.0)], [0.0, 0.04, 0.35, 0.7, 0.96])
	var roll := particles("Dust", {"layer": "soft", "at": Vector2(bx, -3), "amount": 10, "lifetime": 1.5, "one_shot": true, "explosiveness": 0.95,
		"randomness": 0.4, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(6, 1.5)}, "dir": 0, "spread": 180,
		"speed": [60, 180], "damping": [100, 150], "gravity": Vector2(0, -8), "scale": [0.75, 1.05], "scale_curve": [[0, 0.7], [0.5, 1.2], [1, 1.5]],
		"ramp": dust})
	var rm: ParticleProcessMaterial = roll.process_material
	rm.direction = Vector3(1, -0.05, 0)
	rm.spread = 8.0
	directed_two_ways(roll)
	emit(roll, BLOW)

	# embers drifting off
	var embers := particles("Embers", {"at": at, "amount": 30, "lifetime": 1.8, "one_shot": true, "explosiveness": 1.0, "randomness": 0.55,
		"emitting": false, "texture": "dot1", "dir": -90, "spread": 180, "speed": [30, 120], "damping": [60, 90], "gravity": Vector2(0, -20),
		"ramp": gradient([F[6], F[5], F[3], Color(F[3], 0.0)], [0.0, 0.4, 0.7, 0.95]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.03]}})
	emit(embers, BLOW)

	# the casing in pieces, the floor's grit: thrown up, they land and lie a moment
	var shards := particles("Shards", {"at": at, "amount": 12, "lifetime": 2.1, "one_shot": true, "explosiveness": 1.0, "randomness": 0.3,
		"emitting": false, "texture": "streak3", "dir": -90, "spread": 78, "speed": [150, 330], "damping": [30, 60], "gravity": Vector2(0, 950),
		"angle": [0, 360], "spin": [-1300, 1300], "initial": gradient(METAL), "alpha_curve": [[0, 1], [0.8, 1], [1, 0]],
		"collide": {"bounce": 0.3, "friction": 0.9, "size": 2}})
	emit(shards, BLOW)
	for k in 2:
		var grit := particles("Grit%d" % k, {"at": Vector2(bx, -1), "amount": [46, 24][k], "lifetime": 1.8, "one_shot": true, "explosiveness": 1.0,
			"randomness": 0.4, "emitting": false, "texture": ["dot1", "dot2"][k], "emit": {"box": Vector2(4, 0.5)}, "dir": -90, "spread": 46,
			"speed": [100, 300], "damping": [40, 80], "gravity": Vector2(0, 950), "initial": gradient(STONE),
			"alpha_curve": [[0, 1], [0.75, 1], [0.76, 0]], "collide": {"bounce": 0.15, "friction": 1.0}})
		emit(grit, BLOW)


	# the flash goes over everything, as the original draws it last
	for nd in [flash, core]:
		root.move_child(nd, -1)
	for i in 8:
		root.move_child(root.get_node("Flare%d" % i), -1)

## Dust thrown out both ways along the floor: half the particles to the left, half to the right.
func directed_two_ways(p: GPUParticles2D) -> void:
	var pts := PackedVector2Array()
	var nor := PackedVector2Array()
	for i in 16:
		pts.append(Vector2((i - 7.5) * 0.8, 0))
		nor.append(Vector2(-1, 0) if i % 2 == 0 else Vector2(1, 0))
	var m: ParticleProcessMaterial = p.process_material
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	m.emission_point_texture = _points_texture(pts)
	m.emission_normal_texture = _points_texture(nor)
	m.emission_point_count = pts.size()


## A streak texture h px long for particles aligned with their flight: a dim tail and a bright head (the last `head`
## of it, toward where it flies).
func streak(h: int, head: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	# the texture's bottom leads (an aligned particle's +y points along its flight); the tail a warm dim (a plain
	# grey would snap a dim yellow to the grenade's greens)
	g.offsets = PackedFloat32Array([0.0, 1.0 - head])
	g.colors = PackedColorArray([Color(0.75, 0.45, 0.25), Color.WHITE])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 1
	tex.height = h
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	return tex
