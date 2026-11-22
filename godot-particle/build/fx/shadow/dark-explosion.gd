# reimagined-from: src/fx/shadow/dark-explosion.js@0a088c0633e271d5a02a231c7ab61a0b6cf4a0b0
# Dark explosion: Motes swirl into a pulsing core, a black star cuts across a violet-white flash, and a black sphere burns at the rim, throws lit shards and smoke, then collapses.
# one-shot, 3.80 s, 280x248 canvas, origin [140.0, 206.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The black sphere (void body, white rim, tongues of flame crawling round it) is a canvas shader
# (_dark-explosion_sphere.gdshader) whose radius and heat follow the original's curves, its body lifted above the light
# layer; the black star is another (_dark-explosion_star.gdshader), also above the light; the shock rings in the air
# stop at the floor (_dark-explosion_shock.gdshader) and the big one runs on along the floor as a squashed ring with
# dust under it. Particles: motes and streaks swirling into the core, shards thrown out (a drawn sliver, tumbling) that
# land and lie flat (an emitter along the floor), sparks, embers, flame off the rim, soft smoke lit violet while the
# sphere burns, the collapse's streaks and the pop's burst. Light: the flash, the corona, the pop.
extends "res://build/fx/shadow/_shadow.gd"

const Y := -54.0
const RS := 16.0
const REL := 0.52
const BURN := 1.62
const POP := 1.84
const SMOKE := Color("#5d5468")
const AT := Vector2(0, Y)
const HZ := 60.0


static func core_r(tt: float) -> float:
	var beat := 1 + 0.3 * exp(-pow(tt - REL * 0.5, 2) / 0.0015) + 0.4 * exp(-pow(tt - REL * 0.8, 2) / 0.0015)
	return (1.5 + 5 * in_quad(tt / REL)) * beat if tt < REL - 0.07 else 0.0


static func sphere_r(tt: float) -> float:
	if tt < REL:
		return 0.0
	if tt < BURN:
		return RS * out_back(clampf((tt - REL) / 0.14, 0, 1), 2.4) * (1 + 0.06 * smooth(REL + 0.3, BURN, tt) + 0.02 * sin(tt * 11))
	if tt < POP:
		return RS * 1.08 * (1 - in_quad((tt - BURN) / (POP - BURN)))
	return 0.0


static func burning(tt: float) -> float:
	return clampf(tt / REL, 0, 1) * 0.7 if tt < REL else 1.0 if tt < BURN else 1.2 if tt < POP else maxf(0.0, 1 - (tt - POP) / 0.35)


## The original's light(): a glow that shrinks a little and dies (k * (life left)^2) from t0.
func light_burst(name: String, t0: float, r0: float, c: Color, k: float, life: float) -> void:
	var lg := glow(name, r0 + 1, {"radius": r0, "color": c, "alpha": 0.0}, {"at": AT})
	keyf(lg, "material:shader_parameter/radius", func(t: float): return r0 * (0.55 + 0.45 * (1.0 - seg(t, t0, t0 + life))), t0, t0 + life, HZ)
	keyf(lg, "material:shader_parameter/alpha", func(t: float): return k * pow(1.0 - seg(t, t0, t0 + life), 2.0) if t >= t0 else 0.0, t0 - 1.0 / HZ, t0 + life + 0.02, HZ)


func shock(name: String, t0: float, r0: float, r1: float, life: float, th: float, hot: bool, pal: Array) -> void:
	var n := shape(name, shadow_shader("dark-explosion_shock"), Vector2(r1 + 2, r1 + 2) * 2, {"pal": pal, "hot": 1.0 if hot else 0.0, "radius": r0}, {"at": AT})
	var q := func(t: float) -> float: return 1.0 - seg(t, t0, t0 + life)
	keyf(n, "material:shader_parameter/radius", func(t: float): return r0 + (r1 - r0) * (1 - pow(q.call(t), 3)), t0, t0 + life, HZ)
	keyf(n, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, th * q.call(t) + 0.4), t0, t0 + life, HZ)
	keyf(n, "material:shader_parameter/alpha", func(t: float): return minf(1.0, q.call(t) * 1.6), t0, t0 + life, HZ)
	show(n, t0, t0 + life)


func shard_tex() -> Texture2D:
	var L := 11.0
	var W := L * 0.55
	var im := Image.create(13, 9, false, Image.FORMAT_RGBA8)
	for j in 9:
		for i in 13:
			var u := i - 6.0
			var v := j - 4.0
			if u < -L / 2 - 0.4 or u > L / 2 + 0.4:
				continue
			var half := (W / 2) * (L / 2 - u) / L + 0.4
			if absf(v) > half:
				continue
			var c := C[2]
			if u > L / 2 - 1.3:
				c = Color.WHITE
			elif v < -half + 1:
				c = C[6] if u > -L / 4 else C[5]
			elif v > half - 1:
				c = C[1]
			im.set_pixel(i, j, c)
	return asset("shard", im)


func make() -> void:
	ground()
	var white := Color.WHITE
	keep_colour(white)
	var pal := [C[0], C[1], C[2], C[3], C[4], C[5], C[6], C[7], white]
	var soot0 := C[3].lerp(C[1], 0.3).lerp(SMOKE, 0.45)
	var soot1 := C[1].lerp(SMOKE, 0.3)
	var soot := gradient([Color(soot0.lerp(C[5], 0.45), 0.0), Color(soot0.lerp(C[5], 0.45), 0.7), Color(soot0.lerp(C[4], 0.3), 0.7), Color(soot0, 0.62), Color(soot1, 0.4), Color(soot1, 0.0)],
		[0.0, 0.06, 0.3, 0.55, 0.8, 1.0], true)
	var soot_dull := gradient([Color(soot0, 0.0), Color(soot0, 0.65), Color(soot1, 0.45), Color(soot1, 0.0)], [0.0, 0.08, 0.6, 1.0], true)
	var puff_curve := [[0, 0.65], [0.4, 1.1], [1, 1.55]]

	# ---- light under everything: the floor's glow, following how hard the sphere burns
	var fg := glow("FloorGlow", 76, {"radius": 74, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -3)})
	keyf(fg, "material:shader_parameter/alpha", func(t: float): return 0.24 * minf(1.0, burning(t)), 0.0, POP + 0.4, HZ)

	# ---- the shock's flat ring along the floor, dust rolling out under it
	var rr := func(t: float) -> float: return RS + (104 - RS) * (1 - pow(1.0 - seg(t, REL, REL + 0.46), 3))
	var rf := func(t: float) -> float:
		var r: float = rr.call(t)
		return sqrt(r * r - Y * Y) if r > -Y else 0.0
	var t_floor := REL + 0.05
	var band := ring("FloorBand", 92, {"radius": 1, "thickness": 3, "squash": 0.16, "color": C[5]}, {"at": Vector2(0, 0.5)})
	keyf(band, "material:shader_parameter/radius", rf, t_floor, REL + 0.46, HZ)
	keyf(band, "material:shader_parameter/thickness", func(t: float): return 5.0 + 5.0 * (1.0 - seg(t, REL, REL + 0.46)), t_floor, REL + 0.46, HZ)
	keyf(band, "material:shader_parameter/alpha", func(t: float): return minf(1.0, (1.0 - seg(t, REL, REL + 0.46)) * 1.5), t_floor, REL + 0.46, HZ)
	keyf(band, "material:shader_parameter/color", func(t: float): return C[6] if seg(t, REL, REL + 0.46) < 0.35 else C[5] if seg(t, REL, REL + 0.46) < 0.7 else C[4], t_floor, REL + 0.46, HZ, "nearest")
	show(band, t_floor, REL + 0.46)
	for s in [-1, 1]:
		var nm := "L" if s < 0 else "R"
		var bg := glow("BandGlow" + nm, 17, {"radius": 16, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -2)})
		keyf(bg, "position", func(t: float): return Vector2(s * rf.call(t), -2), t_floor, REL + 0.46, HZ)
		keyf(bg, "material:shader_parameter/alpha", func(t: float): return 0.4 * (1.0 - seg(t, REL, REL + 0.46)) if rf.call(t) > 0 else 0.0, t_floor - 0.02, REL + 0.47, HZ)
		var dust := particles("Dust" + nm, {"layer": "soft", "at": Vector2(0, -2), "amount": 14, "lifetime": 0.7, "life_random": 0.4, "texture": "disc5",
			"emit": {"box": Vector2(2, 1)}, "dir": 0 if s > 0 else 180, "spread": 12, "speed": [20, 50], "gravity": Vector2(0, -8), "drag": 4.0,
			"scale": [0.7, 1.3], "scale_curve": [[0, 0.6], [1, 1.5]], "initial": gradient([C[2], C[3]]), "alpha_curve": [[0, 0.7], [1, 0]], "emitting": false})
		keyf(dust, "position", func(t: float): return Vector2(s * rf.call(t), -2), t_floor, REL + 0.46, HZ)
		emit(dust, t_floor, REL + 0.46)

	# ---- smoke (soft, behind the sphere): lit violet while it burns
	var gather := particles("GatherSmoke", {"layer": "soft", "at": AT, "amount": 5, "lifetime": 0.5, "texture": "disc9",
		"emit": {"ring": [60, 34]}, "orbit": [0.25, 0.4], "radial": [-520, -360], "scale": [0.7, 1.3], "ramp": soot_dull, "emitting": false})
	emit(gather, 0.0, REL - 0.25)
	var blast := particles("BlastSmoke", {"layer": "soft", "at": AT, "amount": 24, "lifetime": 2.6, "life_random": 0.25, "one_shot": true, "explosiveness": 0.9,
		"texture": "disc13", "emit": {"ring": [RS * 0.9, RS * 0.8]}, "spread": 180, "speed": [30, 110], "gravity": Vector2(0, -26), "drag": 1.3,
		"scale": [1.2, 2.0], "scale_curve": puff_curve, "ramp": soot, "emitting": false})
	emit(blast, REL + 0.03)
	for s in [-1, 1]:
		var fs := particles("FloorSmoke" + ("L" if s < 0 else "R"), {"layer": "soft", "at": Vector2(s * 25, -5), "amount": 6, "lifetime": 2.2, "life_random": 0.25,
			"one_shot": true, "explosiveness": 0.9, "texture": "disc13", "emit": {"box": Vector2(15, 1.5)}, "dir": 0 if s > 0 else 180, "spread": 5,
			"speed": [90, 210], "gravity": Vector2(0, -10), "drag": 2.0, "scale": [0.8, 1.4], "scale_curve": puff_curve, "ramp": soot, "emitting": false})
		emit(fs, REL + 0.1)
	var rise := particles("RimSmoke", {"layer": "soft", "at": AT + Vector2(0, -RS * 0.9), "amount": 14, "lifetime": 1.5, "life_random": 0.25, "texture": "disc13",
		"emit": {"box": Vector2(RS * 0.8, 3)}, "dir": -90, "spread": 50, "speed": [25, 55], "gravity": Vector2(0, -24), "drag": 1.3,
		"scale": [0.9, 1.6], "scale_curve": puff_curve, "ramp": soot, "emitting": false})
	emit(rise, REL + 0.05, BURN)
	var pop_smoke := particles("PopSmoke", {"layer": "soft", "at": AT, "amount": 10, "lifetime": 1.6, "life_random": 0.3, "one_shot": true, "explosiveness": 1.0,
		"texture": "disc9", "emit": {"circle": 3}, "spread": 180, "speed": [35, 110], "gravity": Vector2(0, -22), "drag": 1.3,
		"scale": [0.8, 1.6], "scale_curve": puff_curve, "ramp": soot_dull, "emitting": false})
	emit(pop_smoke, POP)
	var column := particles("Column", {"layer": "soft", "at": AT + Vector2(0, 1), "amount": 12, "lifetime": 1.8, "life_random": 0.25, "one_shot": true, "explosiveness": 0.85,
		"texture": "disc13", "emit": {"box": Vector2(12, 8)}, "dir": -90, "spread": 40, "speed": [30, 80], "gravity": Vector2(0, -26), "drag": 1.2,
		"scale": [1.2, 2.0], "scale_curve": puff_curve, "ramp": soot_dull, "emitting": false})
	emit(column, POP + 0.02)

	# ---- the charge: motes swirling in, streaks shot at the core, a contracting ring, a beating core
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var mpts := PackedVector2Array()
	for i in 240:
		var a := rng.randf() * TAU
		var dd := rng.randf_range(36, 84)
		mpts.append(Vector2(cos(a) * dd, minf(-3 - Y, sin(a) * dd)))
	var motes := particles("Motes", {"at": AT, "amount": 110, "lifetime": 0.62, "life_random": 0.3, "texture": "streak6", "align": true,
		"emit": {"points": mpts}, "orbit": [0.35, 0.7], "radial": [-420, -200], "scale": [0.7, 1.2],
		"initial": gradient([white, C[6], C[6], C[5]]), "alpha_curve": [[0, 0], [0.3, 1], [1, 1]], "emitting": false})
	radial_speed(motes, -40, -10)
	emit(motes, 0.0, REL - 0.1)
	key(motes, "amount_ratio", [[0.0, 0.4], [REL - 0.1, 1.0]])
	show(motes, 0.0, REL)
	var ml := twin(motes, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	var spts := PackedVector2Array()
	for i in 120:
		spts.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(28, 70))
	var in_streaks := particles("ChargeStreaks", {"at": AT, "amount": 6, "lifetime": 0.24, "texture": "streak6", "align": true,
		"emit": {"points": spts}, "radial": [-1900, -1300], "ramp": gradient([C[6], C[7], white], [0.0, 0.4, 0.8]), "emitting": false})
	radial_speed(in_streaks, -30, -20)
	emit(in_streaks, 0.0, REL - 0.26)
	show(in_streaks, 0.0, REL)
	twin(in_streaks, {"texture": "glow8", "modulate": Color(C[6], 0.4)})

	var cring := ring("ChargeRing", 80, {"radius": 77, "thickness": 1.0, "color": C[5], "alpha": 0.2}, {"at": AT})
	keyf(cring, "material:shader_parameter/radius", func(t: float): return 3 + 74 * (1 - in_quad(t / REL)), 0.0, REL, HZ)
	keyf(cring, "material:shader_parameter/alpha", func(t: float): return 0.2 + 0.7 * t / REL, 0.0, REL, HZ)
	key(cring, "material:shader_parameter/color", [[0.0, C[5]], [REL * 0.7, C[6]]], "nearest")
	show(cring, 0.0, REL)
	var cglow := glow("ChargeGlow", 92, {"radius": 60, "color": C[4], "alpha": 0.12}, {"at": AT})
	keyf(cglow, "material:shader_parameter/radius", func(t: float): return 60 + 30 * t / REL, 0.0, REL, HZ)
	keyf(cglow, "material:shader_parameter/alpha", func(t: float): return 0.12 + 0.3 * t / REL if t < REL else 0.0, 0.0, REL + 1.0 / HZ, HZ)
	var chalo := halo("ChargeHalo", AT, 56, 2, 16, C[5], 0.45)
	keyf(chalo, "material:shader_parameter/r0", core_r, 0.0, REL, HZ)
	keyf(chalo, "material:shader_parameter/r1", func(t: float): return core_r(t) + 14 + 30 * t / REL, 0.0, REL, HZ)
	keyf(chalo, "material:shader_parameter/k", func(t: float): return (0.45 + 0.7 * t / REL) * (core_r(t) / (1.5 + 5 * in_quad(t / REL)) if t < REL - 0.07 else 1.0) if t < REL else 0.0, 0.0, REL + 1.0 / HZ, HZ)
	var dot := ring("CoreDot", 3, {"radius": 1.6, "color": white}, {"at": AT})
	show(dot, REL - 0.07, REL)

	# ---- the release: a violet-white flash
	var fu := func(t: float) -> float: return (t - REL) / 0.12
	for f in [["FlashEdge", 1.5, 1.0, C[5], 1.2, 1.0], ["Flash", 0.0, 1.0, white, 1.1, 1.0], ["FlashHeart", 0.0, 0.62, white, 9.0, 0.6]]:
		var fl := ring(f[0], 39, {"radius": 36, "color": f[3]}, {"at": AT})
		keyf(fl, "material:shader_parameter/radius", func(t: float): return (36 * (1 - 0.3 * fu.call(t)) + f[1]) * f[2], REL, REL + 0.12, HZ)
		keyf(fl, "material:shader_parameter/alpha", func(t: float): return clampf(f[4] - fu.call(t), 0, 1), REL, REL + 0.12, HZ)
		if f[0] == "Flash":
			key(fl, "material:shader_parameter/color", [[REL, white], [REL + 0.12 * 0.35, C[6]]], "nearest")
		show(fl, REL, REL + 0.12 * f[5])

	# ---- shock rings in the air
	shock("Shock0", REL, RS, 104, 0.46, 3.6, true, pal)
	shock("Shock1", REL + 0.02, RS * 0.8, 62, 0.3, 1.6, true, pal)
	shock("Shock2", REL + 0.07, RS, 124, 0.62, 1.2, false, pal)
	shock("PopShock", POP, 2, 40, 0.28, 2, true, pal)

	# ---- the sphere's flame and rim (its black body goes above the light, below)
	var sph_r := func(t: float) -> float: return core_r(t) if t < REL else sphere_r(t)
	var sph_heat := func(t: float) -> float: return 0.3 + 0.3 * t / REL if t < REL else 1.0 if t < BURN else 1 + 0.5 * clampf((t - BURN) / (POP - BURN), 0, 1)
	var bodies := []
	for m in 2:
		var sp := shape("Sphere" if m == 0 else "SphereBody", shadow_shader("dark-explosion_sphere"), Vector2(84, 84), {"pal": pal, "mode": float(m), "r": 0.0}, {"at": AT})
		keyf(sp, "material:shader_parameter/r", sph_r, 0.0, POP + 1.0 / HZ, HZ)
		keyf(sp, "material:shader_parameter/heat", sph_heat, 0.0, POP, HZ)
		key(sp, "material:shader_parameter/tt", [[0.0, 0.0], [root.duration, root.duration]])
		show(sp, 0.0, POP)
		bodies.append(sp)

	# ---- flame off the rim, shards, sparks, embers
	var flame := gradient([white, C[7], C[6], C[5], C[5], C[4], C[4], C[3], Color(C[2], 0.0)])
	var licks := particles("Licks", {"at": AT + Vector2(0, -RS * 0.75), "amount": 14, "lifetime": 0.45, "life_random": 0.4, "texture": "disc5",
		"emit": {"box": Vector2(RS * 0.8, 5)}, "dir": -90, "spread": 50, "speed": [20, 55], "gravity": Vector2(0, -95), "drag": 3.2,
		"scale": [0.5, 0.9], "scale_curve": [[0, 0.55], [0.14, 1.0], [1, 0.45]], "ramp": flame, "emitting": false})
	emit(licks, REL + 0.04, BURN)
	var burst_flame := particles("BurstFlame", {"at": AT + Vector2(0, -RS * 0.5), "amount": 10, "lifetime": 0.6, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
		"texture": "disc7", "emit": {"box": Vector2(RS, 6)}, "dir": -90, "spread": 80, "speed": [50, 110], "gravity": Vector2(0, -95), "drag": 3.2,
		"scale": [0.6, 1.05], "scale_curve": [[0, 0.55], [0.14, 1.0], [1, 0.45]], "ramp": flame, "emitting": false})
	emit(burst_flame, REL)

	var shards := particles("Shards", {"at": AT, "amount": 34, "lifetime": 1.4, "one_shot": true, "explosiveness": 1.0, "texture": shard_tex(),
		"emit": {"ring": [RS * 0.7, RS * 0.6]}, "spread": 180, "speed": [80, 220], "gravity": Vector2(0, 712), "drag": 1.5,
		"angle": [0, 360], "spin": [-900, 900], "scale": [0.3, 1.0], "collide": {"hide": true, "size": 2}, "emitting": false})
	shards.process_material.direction = Vector3(0, -0.45, 0)
	emit(shards, REL)
	var sglow := twin(shards, {"texture": "glow8", "modulate": Color(C[5], 0.2)})
	var lain := particles("ShardsLain", {"at": Vector2(0, -1.5), "amount": 30, "lifetime": 1.9, "life_random": 0.3, "one_shot": true, "explosiveness": 0.72,
		"texture": shard_tex(), "emit": {"box": Vector2(98, 0.4)}, "angle": [-10, 10], "scale": [0.3, 1.0],
		"ramp": gradient([white, white, Color(0.55, 0.5, 0.7), Color(0.55, 0.5, 0.7, 0.0)], [0.0, 0.3, 0.75, 1.0], true), "emitting": false})
	emit(lain, REL + 0.38)
	var lain2 := particles("ShardsLainFlip", {"at": Vector2(0, -1.5), "amount": 14, "lifetime": 1.9, "life_random": 0.3, "one_shot": true, "explosiveness": 0.72,
		"texture": shard_tex(), "emit": {"box": Vector2(98, 0.4)}, "angle": [170, 190], "scale": [0.3, 1.0],
		"ramp": gradient([white, white, Color(0.55, 0.5, 0.7), Color(0.55, 0.5, 0.7, 0.0)], [0.0, 0.3, 0.75, 1.0], true), "emitting": false})
	emit(lain2, REL + 0.38)
	var wisps := particles("Wisps", {"layer": "soft", "at": Vector2(0, -3), "amount": 26, "lifetime": 0.8, "one_shot": true, "explosiveness": 0.4,
		"texture": "disc5", "emit": {"box": Vector2(98, 0.5)}, "dir": -90, "spread": 15, "speed": [8, 16], "scale_curve": [[0, 0.5], [1, 1.2]],
		"ramp": soot_dull, "emitting": false})
	emit(wisps, REL + 1.9)

	var spark_ramp := gradient([white, white, C[7], C[6], C[5]], [0.0, 0.2, 0.4, 0.7, 0.9])
	var sparks := particles("Sparks", {"at": AT, "amount": 84, "lifetime": 0.7, "life_random": 0.7, "one_shot": true, "explosiveness": 1.0,
		"texture": "streak4", "align": true, "emit": {"ring": [RS * 0.8, RS * 0.7]}, "spread": 180, "speed": [120, 235], "gravity": Vector2(0, 427),
		"drag": 2.2, "ramp": spark_ramp, "collide": {"bounce": 0.45, "friction": 0.3}, "emitting": false})
	emit(sparks, REL)
	twin(sparks, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	var ember_ramp := gradient([C[7], C[7], C[6], C[5], Color(C[5], 0.0)], [0.0, 0.4, 0.7, 0.9, 1.0])
	var embers := particles("Embers", {"at": AT, "amount": 28, "lifetime": 2.5, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
		"texture": "dot1", "emit": {"ring": [RS * 0.9, RS * 0.8]}, "spread": 180, "speed": [30, 130], "gravity": Vector2(0, -30), "drag": 1.6,
		"ramp": ember_ramp, "turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.005, 0.02]}, "emitting": false})
	emit(embers, REL)
	twin(embers, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	var odd := particles("BurnSparks", {"at": AT, "amount": 4, "lifetime": 0.45, "life_random": 0.5, "texture": "streak4", "align": true,
		"emit": {"ring": [RS, RS - 1]}, "spread": 180, "speed": [110, 200], "gravity": Vector2(0, 427), "drag": 2.2, "ramp": spark_ramp, "emitting": false})
	emit(odd, REL + 0.2, BURN)
	var odd_embers := particles("BurnEmbers", {"at": AT + Vector2(0, -RS), "amount": 9, "lifetime": 1.4, "life_random": 0.4, "texture": "dot1",
		"emit": {"box": Vector2(RS * 0.8, 3)}, "dir": -90, "spread": 35, "speed": [20, 50], "gravity": Vector2(0, -30), "drag": 1.6,
		"ramp": ember_ramp, "emitting": false})
	emit(odd_embers, REL + 0.2, BURN)
	twin(odd_embers, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})

	# ---- the collapse: streaks race to the heart; the pop: a glint, sparks, embers
	var cpts := PackedVector2Array()
	for i in 60:
		cpts.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(26, 48))
	var collapse := particles("CollapseStreaks", {"at": AT, "amount": 14, "lifetime": 0.2, "life_random": 0.3, "one_shot": true, "explosiveness": 1.0,
		"texture": "streak6", "align": true, "emit": {"points": cpts}, "radial": [-1900, -1500], "initial": gradient([white, C[6]]), "emitting": false})
	radial_speed(collapse, -40, -25)
	emit(collapse, BURN)
	twin(collapse, {"texture": "glow8", "modulate": Color(C[6], 0.4)})
	var pop_sparks := particles("PopSparks", {"at": AT, "amount": 26, "lifetime": 0.6, "life_random": 0.65, "one_shot": true, "explosiveness": 1.0,
		"texture": "streak4", "align": true, "spread": 180, "speed": [120, 250], "gravity": Vector2(0, 427), "drag": 2.2, "ramp": spark_ramp,
		"collide": {"bounce": 0.45, "friction": 0.3}, "emitting": false})
	emit(pop_sparks, POP)
	twin(pop_sparks, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	var pop_embers := particles("PopEmbers", {"at": AT, "amount": 14, "lifetime": 1.6, "life_random": 0.45, "one_shot": true, "explosiveness": 1.0,
		"texture": "dot1", "spread": 180, "speed": [20, 90], "gravity": Vector2(0, -30), "drag": 1.6, "ramp": ember_ramp, "emitting": false})
	emit(pop_embers, POP)
	twin(pop_embers, {"texture": "glow8", "modulate": Color(1, 1, 1, 0.3)})
	var glint := shape("Glint", shadow_shader("hex-sigil_sparkle"), Vector2(27, 27), {"arm": 12.0, "c": C[6], "tip": C[5], "heart": white}, {"at": AT + Vector2(0.5, 0.5)})
	keyf(glint, "material:shader_parameter/arm", func(t: float): return 12 * (1 - (t - POP) / 0.2), POP, POP + 0.2, HZ)
	show(glint, POP, POP + 0.2)

	# ---- light: the blast's flare, the sphere's corona, the pop
	light_burst("ReleaseLight", REL, 100, C[4], 1.25, 0.85)
	light_burst("ReleaseFlare", REL, 86, C[6].lerp(white, 0.5), 1.3, 0.22)
	light_burst("PopFlare", POP, 56, white, 0.9, 0.18)
	light_burst("PopLight", POP, 120, C[5], 0.8, 0.5)
	var corona := halo("Corona", AT, 36, 0, 16, C[6], 0.0)
	keyf(corona, "material:shader_parameter/r0", func(t: float): return sphere_r(t) - 0.5, REL, POP, HZ)
	keyf(corona, "material:shader_parameter/r1", func(t: float): return sphere_r(t) + 16, REL, POP, HZ)
	keyf(corona, "material:shader_parameter/k", func(t: float): return 0.46 * minf(1.0, burning(t)) if sphere_r(t) > 1 else 0.0, REL - 1.0 / HZ, POP + 1.0 / HZ, HZ)
	var cg := glow("CoronaGlow", 74, {"radius": 70, "color": C[4], "alpha": 0.0}, {"at": AT})
	keyf(cg, "material:shader_parameter/radius", func(t: float): return sphere_r(t) + 54, REL, POP, HZ)
	keyf(cg, "material:shader_parameter/alpha", func(t: float): return 0.46 * minf(1.0, burning(t)) if sphere_r(t) > 1 else 0.0, REL - 1.0 / HZ, POP + 1.0 / HZ, HZ)

	# ---- black takes its light back: the sphere's body, then the star
	over_light(bodies[1])
	var star := shape("Star", shadow_shader("dark-explosion_star"), Vector2(130, 130), {"body": C[0], "rim": C[5], "len": 0.0}, {"at": AT})
	keyf(star, "material:shader_parameter/len", func(t: float): return 60 * (1 - in_quad(clampf((t - REL - 0.05) / 0.21, 0, 1))), REL, REL + 0.26, HZ)
	keyf(star, "material:shader_parameter/rot", func(t: float): return 0.32 + (t - REL) * 2.2, REL, REL + 0.26, HZ)
	keyf(star, "material:shader_parameter/cut", func(t: float): return maxf(36 * (1 - 0.3 * (t - REL) / 0.12) + 1.5 if t - REL < 0.12 else 0.0, sphere_r(t)), REL, REL + 0.26, HZ)
	key(star, "material:shader_parameter/rim", [[REL, C[5]], [REL + 0.1, C[4]]], "nearest")
	show(star, REL, REL + 0.26)
	over_light(star)
