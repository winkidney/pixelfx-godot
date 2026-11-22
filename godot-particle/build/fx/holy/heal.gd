# reimagined-from: src/fx/holy/heal.js@b6640aeffdc0d855bb6afe9ac2724f67646e3349
# Heal: Petals of light bloom under the feet, a hoop of light rises up the body restoring its colour and leaving sparkles, and motes spiral up and pop into tiny hearts.
# one-shot, 1.90 s, 80x104 canvas, origin [40.0, 92.0], backdrop ground
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The lotus is a shader (fx/holy/_heal_petals.gdshader, soft layer; the far petals behind the character) whose
# blooms follow the original's back-eased beats, with a glow on each tip. The hoop is a flat oval shader
# (fx/holy/_heal_hoop.gdshader), far half behind and near half in front, rising on the original's curve; the stand-in
# is the effect's own Actor with fx/holy/_heal_body.gdshader: drained above the hoop's line, white on it, restored
# and warm below. Sparkles left on the body are particle bursts from the outline rows as the hoop passes them
# (stepping through the original's sparkle). The motes ride their spirals as keyed dots with a short tail and a
# glow, behind the body on the far side of each turn, and pop into a heart or a star that floats up and fades.
extends "res://build/fx/holy/_holy.gd"

const SY := 0.3
const NP := 8
const PR := 16.0
const LIFT0 := 0.16
const LIFT1 := 0.74
const TOPY := -43.0
const HEART := [".#.#.", "#####", ".###.", "..#.."]


static func hoop_y(t: float) -> float:
	return lerpf(0.0, TOPY, in_out_sine(seg(t, LIFT0, LIFT1)))


static func hoop_r(t: float) -> float:
	return lerpf(PR, 12.0, seg(t, LIFT0, LIFT1))


static func in_back(x: float, s := 1.70158) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else (s + 1.0) * x * x * x - s * x * x)


func make() -> void:
	var D: float = meta.duration
	var R := RandomNumberGenerator.new()
	R.seed = 11

	# ---- a warm pool under the flower
	var pool := glow("Pool", 32, {"radius": 30, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, -2)})
	keyf(pool, "material:shader_parameter/alpha", func(t: float) -> float: return 0.3 * smooth(0.0, 0.2, t) * (1.0 - smooth(1.3, 1.75, t)))

	# ---- the lotus: petals blooming on their own beats round the ring
	var pa := PackedFloat32Array()
	var pw := PackedFloat32Array()
	var t0s := []
	for k in NP:
		pa.append(k / float(NP) * TAU + 0.2)
		pw.append(R.randf_range(4.2, 5.2))
		t0s.append(0.02 + ((k * 3) % NP) * 0.035)
	var blooms := func(t: float) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		for k in NP:
			out.append(out_back(seg(t, t0s[k], t0s[k] + 0.3), 1.8) * (1.0 - in_back(seg(t, 1.25 + k * 0.02, 1.6 + k * 0.02), 1.4)))
		return out
	var psz := Vector2(48, 30)
	var pat := Vector2(0, -5)
	for side in [true, false]:
		var pet := shape("PetalsFar" if side else "PetalsNear", holy_shader("heal_petals"), psz,
			{"back": side, "pal": C, "pa": pa, "pw": pw, "pb": blooms.call(0.0), "translucent": true}, {"at": pat, "back": side})
		key(pet, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
		keyn(pet, "material:shader_parameter/pb", blooms)
	var pl := shape("PetalLight", holy_shader("heal_petals_light"), psz + Vector2(12, 12), {"c5": C[5], "pa": pa, "pw": pw, "pb": blooms.call(0.0)}, {"at": pat})
	key(pl, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	keyn(pl, "material:shader_parameter/pb", blooms)

	# ---- the body: drained above the hoop, restored below it
	var body := actor_node()
	var bm := ShaderMaterial.new()
	bm.shader = holy_shader("heal_body")
	bm.set_shader_parameter("c5", C[5])
	bm.set_shader_parameter("c6", C[6])
	body.material = bm
	keyn(body, "material:shader_parameter/line_y", func(t: float) -> float: return 1.0 if t < LIFT0 else roundf(hoop_y(t)))
	keyn(body, "material:shader_parameter/drain", func(t: float) -> float: return smooth(0.0, 0.08, t), 0.0, 0.12)
	keyn(body, "material:shader_parameter/done", func(t: float) -> bool: return t >= LIFT1)
	keyn(body, "material:shader_parameter/wash", func(t: float) -> float: return 0.45 * (1.0 - seg(t, LIFT1, LIFT1 + 0.35)) if t < LIFT1 + 0.35 else 0.0)
	var line_glow := glow("LineGlow", 20, {"radius": 18, "color": C[5], "alpha": 0.0})
	keyn(line_glow, "position", func(t: float) -> Vector2: return Vector2(0, hoop_y(t)))
	keyn(line_glow, "material:shader_parameter/alpha", func(t: float) -> float: return 0.35 if (t > LIFT0 and t < LIFT1) else 0.0)

	# ---- the hoop rising up the body: far half behind, near half in front
	var hr := func(t: float) -> float:
		if t < LIFT0 or t > LIFT1 + 0.12:
			return 0.0
		return hoop_r(t) * ((1.0 - (t - LIFT1) / 0.12) if t > LIFT1 else 1.0)
	var hpos := func(t: float) -> Vector2: return Vector2(0, roundf(hoop_y(t)))
	for side in [true, false]:
		var hp := shape("HoopFar" if side else "HoopNear", holy_shader("heal_hoop"), Vector2(40, 16), {"r": 0.0, "back": side, "c6": C[6], "c4": C[4]}, {"back": side})
		keyn(hp, "position", hpos)
		keyn(hp, "material:shader_parameter/r", hr)
	var hl := glow("HoopLight", 28, {"radius": 24, "thickness": 0.0, "squash": 0.5, "color": C[5], "alpha": 0.0})
	keyn(hl, "position", hpos)
	keyn(hl, "material:shader_parameter/radius", func(t: float) -> float: return hr.call(t) * 0.9 + 8.0)
	keyn(hl, "material:shader_parameter/alpha", func(t: float) -> float: return 0.5 if hr.call(t) > 0.5 else 0.0)

	# ---- sparkles left on the body as the hoop passes each row
	var edge := actor_points(true)
	var NF := 6
	var strip := asset("spark.png", sparkle_strip(NF, func(u: float) -> float: return 1.9 * (1.0 - u) + 0.6, Color.WHITE, C[6], 2))
	for b in 5:
		var y0 := TOPY * b / 5.0
		var y1 := TOPY * (b + 1) / 5.0
		var pts := PackedVector2Array()
		for q in edge:
			if q.y <= y0 and q.y > y1:
				pts.append(q)
		if pts.is_empty():
			continue
		var when := LIFT0
		while hoop_y(when) > y0 and when < LIFT1:
			when += 1.0 / 120.0
		var sp := particles("BodySparks%d" % b, {"amount": 4, "lifetime": 0.5, "life_random": 0.4, "one_shot": true, "explosiveness": 0.55, "emitting": false,
			"emit": {"points": pts}, "dir": -90, "spread": 25, "speed": [4, 12], "texture": strip})
		flip(sp, NF)
		emit(sp, when)
		twin(sp, {"texture": "glow8", "modulate": Color(C[6], 0.45)})

	# ---- the hoop bursts at the top
	light_burst("BurstLight", LIFT1, Vector2(0, TOPY), 26, C[5], 0.55, 0.3)
	light_burst("BurstWhite", LIFT1, Vector2(0, TOPY), 10, Color.WHITE, 0.45, 0.08)
	var top := sparkle("Burst", Vector2(0, TOPY), 0.0, Color.WHITE, C[5])
	keyn(top, "material:shader_parameter/arm", func(t: float) -> float: return 8.0 * (1.0 - (t - LIFT1) / 0.25) if (t >= LIFT1 and t < LIFT1 + 0.25) else 0.0)
	var top_l := glow("BurstStar", 22, {"radius": 20, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, TOPY)})
	keyn(top_l, "material:shader_parameter/alpha", func(t: float) -> float: return 0.6 if (t >= LIFT1 and t < LIFT1 + 0.25) else 0.0)
	keyn(top_l, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 16.0 * (1.0 - seg(t, LIFT1, LIFT1 + 0.25)))

	# ---- motes riding a spiral up round the body, popping into a heart or a star
	var heart := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	var hat := func(i: int, j: int) -> bool: return j >= 0 and j < 4 and i >= 0 and i < 5 and HEART[j][i] == "#"
	for j in range(-1, 5):
		for i in range(-1, 6):
			if hat.call(i, j):
				heart.set_pixel(i + 1, j + 1, Color.WHITE if (i == 1 and j == 1) else (C[5] if j >= 2 else C[6]))
			elif hat.call(i - 1, j) or hat.call(i + 1, j) or hat.call(i, j - 1) or hat.call(i, j + 1):
				heart.set_pixel(i + 1, j + 1, C[3])
	var heart_tex := asset("heart.png", heart)
	var motes := []
	for k in NP:
		motes.append({"t0": 0.2 + k * 0.05, "th0": pa[k], "r0": PR * 0.9, "y0": -1.0, "w": 4.2 * (1.0 if k % 2 else -1.0), "v": R.randf_range(46, 58),
			"life": R.randf_range(0.75, 0.95), "kind": k % 2})
	for k in 8:
		motes.append({"t0": LIFT1 + R.randf_range(0, 0.06), "th0": k / 8.0 * TAU, "r0": R.randf_range(12, 18), "y0": TOPY + R.randf_range(-2, 4),
			"w": 3.6 * (1.0 if k % 2 else -1.0), "v": R.randf_range(14, 34), "life": R.randf_range(0.35, 0.6), "kind": (k + 1) % 2})
	var mi := 0
	for m in motes:
		var at := func(aa: float) -> Vector3:
			var th: float = m.th0 + m.w * aa
			var r: float = m.r0 * (1.0 - 0.45 * (aa / m.life))
			return Vector3(cos(th) * r, m.y0 - m.v * aa, sin(th))
		var t_on: float = m.t0
		var t_pop: float = m.t0 + m.life
		var j := 0
		for lag in [0, 1, 3, 5]:
			var dot := sprite("Mote%d_%d" % [mi, j], "dot1", {"modulate": Color.WHITE if lag == 0 else (C[6] if lag < 3 else C[5]), "centered": false, "visible": false})
			var age := func(t: float) -> float: return t - t_on - lag * 0.03
			keyn(dot, "visible", func(t: float) -> bool: return age.call(t) >= 0.0 and t < t_pop, 0.0, t_pop + 0.04)
			keyn(dot, "position", func(t: float) -> Vector2:
				var q: Vector3 = at.call(maxf(0.0, age.call(t)))
				return Vector2(floorf(q.x), floorf(q.y)), t_on, t_pop)
			keyn(dot, "z_index", func(t: float) -> int: return -2 if (at.call(maxf(0.0, age.call(t))) as Vector3).z < 0.0 else 1, t_on, t_pop)
			if lag > 0:
				dot.modulate.a = 1.0 - lag / 7.0
			j += 1
		var mg := glow("MoteLight%d" % mi, 5, {"radius": 4, "color": C[5], "alpha": 0.0})
		keyn(mg, "position", func(t: float) -> Vector2:
			var q: Vector3 = at.call(clampf(t - t_on, 0.0, m.life))
			return Vector2(q.x, q.y), t_on, t_pop)
		keyn(mg, "material:shader_parameter/alpha", func(t: float) -> float:
			if t < t_on or t >= t_pop:
				return 0.0
			return 0.2 if (at.call(t - t_on) as Vector3).z < 0.0 else 0.4, 0.0, t_pop + 0.04)
		# the pop: a quick sparkle, then a heart (or a star) that floats up and fades
		var end: Vector3 = at.call(m.life)
		var e2 := Vector2(end.x, end.y)
		var t_end := minf(D, t_pop + 0.36)
		var pop := sparkle("Pop%d" % mi, e2, 0.0, Color.WHITE, C[6] if m.kind else C[5])
		var uu := func(t: float) -> float: return (t - t_pop) / 0.36
		keyn(pop, "material:shader_parameter/arm", func(t: float) -> float:
			var u: float = uu.call(t)
			if u < 0.0 or u >= 1.0:
				return 0.0
			if u < 0.12:
				return 3.0
			if m.kind:
				return 0.0
			return 1.0 + 2.0 * (1.0 - smooth(0.5, 1.0, u)) * (0.7 + 0.3 * sin((t - t_on) * 30.0)), 0.0, t_end + 0.04)
		if not m.kind:
			keyn(pop, "position", func(t: float) -> Vector2: return (e2 - Vector2(0, clampf(uu.call(t), 0.0, 1.0) * 5.0)).floor() + Vector2(0.5, 0.5), t_pop, t_end)
		var pg := glow("PopLight%d" % mi, 11, {"radius": 9, "color": C[5] if m.kind else Color.WHITE, "alpha": 0.0}, {"at": e2})
		keyn(pg, "material:shader_parameter/alpha", func(t: float) -> float:
			var u: float = uu.call(t)
			if u < 0.0 or u >= 1.0:
				return 0.0
			return 0.5 if u < 0.12 else 0.42 * (1.0 - smooth(0.5, 1.0, u)), 0.0, t_end + 0.04)
		keyn(pg, "position", func(t: float) -> Vector2: return e2 - Vector2(0, clampf(uu.call(t), 0.0, 1.0) * 5.5), t_pop, t_end)
		if m.kind:
			var hs := sprite("Heart%d" % mi, heart_tex, {"at": e2, "centered": false, "offset": Vector2(-3, -3), "visible": false})
			keyn(hs, "visible", func(t: float) -> bool: return uu.call(t) >= 0.12 and uu.call(t) < 1.0, 0.0, t_end + 0.04)
			keyn(hs, "position", func(t: float) -> Vector2: return (e2 - Vector2(0, clampf(uu.call(t), 0.0, 1.0) * 6.0)).round(), t_pop, t_end)
			keyn(hs, "modulate:a", func(t: float) -> float: return 1.0 - smooth(0.5, 1.0, uu.call(t)), t_pop, t_end)
		mi += 1
