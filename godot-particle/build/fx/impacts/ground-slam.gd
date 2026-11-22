# reimagined-from: src/fx/impacts/ground-slam.js@880a0bc93a5926649f3aa5184c71a306afc271b8
# Ground slam: Something lands hard: the floor flashes and cracks, two crescent shock waves race out along it, a dust
# wave and a tall dust cloud rise, rocks erupt, bounce and settle.
# Shaders keyed from the original's curves at 60 Hz: the flat half-star (fx/impacts/_star) and floor flash (_ellipse),
# the ring rolling out on the floor (_band, far half behind the dust, near half in front), the two standing crescent
# fronts (_front), the cracks growing and cooling (_cracks over a map baked from the original's jagged lines, with
# the light along their hot parts and the embers caught in them), the dent (the original's cells). Sparks, grit, the
# dust column and bank, the dust the racing fronts kick up, flakes settling and the rocks (faceted, bouncing, kicking
# dust where they land) are GPU particles from the original's own draws, on its physics (_sim.gdshader).
extends "res://build/fx/impacts/_impacts.gd"

const WAVE := 0.6


func make() -> void:
	var o: Dictionary = meta.options
	var st := stone(Color(o.stone))
	var REACH: float = o.reach
	R = JsRng.new(int(o.seed))
	var D: float = meta.duration
	var W := Color.WHITE
	var dust_lit := mixc(st.dust, W, 0.2)
	var cracks := make_cracks(10, {"len": [22.0, 58.0], "dive": 0.55, "maxY": 22.0, "forks": 0.7, "x0": [2.0, 9.0]})
	var front := func(t: float) -> float: return 7.0 + (REACH - 7.0) * out_cubic((t - 0.015) / WAVE)
	var heat := func(t: float) -> float: return pow(clampf(1.0 - t / 0.8, 0.0, 1.0), 1.4)
	var fade := func(t: float) -> float: return 1.0 - smooth(D - 0.9, D - 0.15, t)
	var burst := []
	burst.append(Vector4(-0.07, R.range(34, 40), 1.9, 0))
	burst.append(Vector4(PI + 0.07, R.range(34, 40), 1.9, 0))
	var b2 := -0.42 + R.range(-0.08, 0.08)
	burst.append(Vector4(b2, R.range(15, 20), 1.5, 0))
	var b3 := -PI + 0.42 + R.range(-0.08, 0.08)
	burst.append(Vector4(b3, R.range(15, 20), 1.5, 0))
	var b4 := -PI / 2 + R.range(-0.15, 0.15)
	burst.append(Vector4(b4, R.range(18, 24), 1.7, 0))
	var b5 := -1.05 + R.range(-0.1, 0.1)
	burst.append(Vector4(b5, R.range(10, 14), 1.2, 0))
	var b6 := -PI + 1.05 + R.range(-0.1, 0.1)
	burst.append(Vector4(b6, R.range(10, 14), 1.2, 0))
	var embers := []
	for c in cracks:
		for p in c.pts:
			if p.z > 3 and p.z < 32 and R.chance(0.25):
				var life := R.range(0.8, 2.2)
				embers.append(Vector4(p.x, p.y, life, R.range(0, TAU)))
	# contact: sparks fly off the stone and skitter along the floor
	for i in 56:
		var low := i < 14
		var s := R.sign()
		var a := (-R.range(0.04, 0.6) if s > 0 else PI + R.range(0.04, 0.6)) if low else -PI / 2 + R.range(-1.15, 1.15)
		var v := R.range(150, 380) if low else R.range(200, 500)
		var x0 := R.range(-4, 4)
		var life := R.range(0.2, 0.5) if low else R.range(0.25, 0.65)
		spawn(SPARK, x0, -1, cos(a) * v, sin(a) * v, life, W, 1, 0.0 if low else R.range(0, 0.05))
	# rocks erupt from the dent
	for i in 20:
		var s := 4 if i < 3 else R.int_(1, 3)
		var a := -PI / 2 + R.range(-0.5, 0.5)
		var v := R.range(110, 190) if s > 3 else R.range(170, 380) * (0.8 if s > 2 else 1.0)
		var x0 := R.range(-7, 7)
		var life := R.range(1.9, 2.7)
		var a0 := R.range(0, TAU)
		var va := R.range(-14, 14)
		var pts := []
		for j in 6:
			pts.append(R.range(0.7, 1.12))
		add_bit({"kind": CHUNK, "x": x0, "y": -2.0, "vx": cos(a) * v, "vy": sin(a) * v, "g": 1.0, "drag": 0.4, "bounce": 0.38,
			"life": life, "a": a0, "va": va, "s": float(s), "pts": pts})
	# grit: a fan of floor bits
	for i in 110:
		var u := R.range(-1, 1)
		var a := -PI / 2 + u * 0.65
		var v := R.range(110, 380) * (1.0 - 0.35 * absf(u))
		var life := R.range(1, 2.2)
		var c: Color = R.pick([st.light, st.body, st.body, st.shade, st.shade, st.lip])
		spawn(GRIT, u * 6, -1, cos(a) * v, sin(a) * v, life, c, 2 if R.chance(0.35) else 1)
	# the dust cloud: a column that shoots up and spreads, and a heavy bank at its foot
	for i in 28:
		var core := i < 14
		var s := R.sign()
		var x0 := R.range(-5, 5) if core else s * R.range(4, 12)
		var y0 := -R.range(2, 10)
		var vx := R.range(-12, 12) if core else s * R.range(14, 38)
		var vy := -R.range(50, 130) * (1.0 if core else R.range(0.3, 0.6))
		var life := R.range(1.9, 2.7)
		var c: Color = dust_lit if R.chance(0.35) else st.dust
		var sz := R.range(4.5, 9) if core else R.range(4, 7.5)
		spawn(SMOKE, x0, y0, vx, vy, life, c, sz, R.range(0.02, 0.22), BIG)
	for i in 10:
		var s := R.sign()
		var x0 := s * R.range(2, 14)
		var y0 := -R.range(2, 6)
		var vx := s * R.range(20, 70)
		var vy := -R.range(4, 20)
		var life := R.range(1.4, 2.3)
		var sz := R.range(6, 9)
		spawn(SMOKE, x0, y0, vx, vy, life, st.dust, sz, R.range(0, 0.08), BIG)
	for i in 26:
		var x0 := R.range(-22, 22)
		var y0 := -R.range(14, 80)
		var vx := R.range(-12, 12)
		var vy := R.range(-10, 4)
		var life := R.range(1.2, 2)
		var c: Color = st.lip if R.chance(0.5) else dust_lit
		var sz := R.range(0.5, 1.2)
		spawn(FLAKE, x0, y0, vx, vy, life, c, sz, R.range(0.25, 1))
	# dust kicked up behind the racing fronts, spray off their crests (the original's update, at its 120 Hz)
	var acc := [R.next(), R.next()]
	var t := 0.0
	while t < 0.015 + WAVE:
		t += DT
		var u := clampf((t - 0.015) / WAVE, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var fr: float = front.call(t)
		var h := 6.0 + 28.0 * pow(1.0 - u, 0.75)
		for k in 2:
			var s := 1.0 if k else -1.0
			acc[k] += DT * 120.0 * (1.0 - u * 0.7)
			while acc[k] > 1.0:
				acc[k] -= 1.0
				var x0 := s * (fr - R.range(1, 7))
				var y0 := -R.range(0.5, 3)
				var vx := s * R.range(15, 70) * (1.0 - u)
				var vy := -R.range(2, 12)
				var life := R.range(1, 2.1)
				var c: Color = dust_lit if R.chance(0.3) else st.dust
				spawn(SMOKE, x0, y0, vx, vy, life, c, R.range(2.5, 6.5) * (1.0 - 0.4 * u), 0.0, BIG, t - DT)
				if R.chance(0.5):
					var dx := s * (fr - R.range(0, 3))
					var dy := -R.range(0.3, 0.9) * h
					var dvx := s * R.range(-15, 25)
					var dvy := -R.range(8, 35)
					var dl := R.range(0.3, 0.6)
					var dc: Color = dust_lit if R.chance(0.5) else st.dust
					spawn(DUST, dx, dy, dvx, dvy, dl, dc, R.range(1.2, 2.4), 0.0, 0, t - DT)
				if R.chance(0.4):
					var gvx := s * R.range(10, 60)
					var gvy := -R.range(40, 140) * (1.0 - u)
					var gl := R.range(0.5, 1)
					spawn(GRIT, s * fr, -1, gvx, gvy, gl, R.pick([st.light, st.body, st.lip]), 1, 0.0, 0, t - DT)
				if u < 0.45 and R.chance(0.2):
					var svx := s * R.range(60, 200)
					var svy := -R.range(30, 160)
					spawn(SPARK, s * fr, -1, svx, svy, R.range(0.12, 0.3), W, 1, 0.0, 0, t - DT)
	# rocks that land hard kick up dust
	var kick := func(b: Dictionary, tt: float, pvy: float) -> void:
		for j in (3 if pvy > 200 else 2):
			var x0: float = b.x + R.range(-1.5, 1.5)
			var vx := R.sign() * R.range(8, 35)
			var vy := -R.range(2, 16)
			var life := R.range(0.3, 0.65)
			spawn(DUST, x0, -0.5, vx, vy, life, st.dust, R.range(1.3, 2.4) * (0.7 + b.b.s * 0.25), 0.0, 0, tt - DT)
	replay_bits(kick, 70.0)

	var U := "material:shader_parameter/"
	# ---- behind the dust: the dent, the cracks, embers, the ring's far half
	var soot := []
	var bottom := []
	var lips := [[], []]
	var top := []
	for x in range(-12, 12):
		var q := absf(x + 0.5) / 12.0
		var dep := int(floor(2.6 * (1.0 - q * q) + 0.5))
		if q < 0.84:
			for y in dep:
				soot.append(Vector2i(x, y))
			bottom.append(Vector2i(x, dep))
		else:
			lips[0 if q > 0.93 else 1].append(Vector2i(x, -1))
			if q < 0.9:
				top.append(Vector2i(x, -2))
	for c in [SOOT, st.lip, st.light, C[5], C[4]]:
		keep_colour(c)
	var dent := [[cells("DentSoot", soot, SOOT, {"back": true}), SOOT, 1.0], [cells("DentLipA", lips[0], st.light, {"back": true}), st.light, 1.0],
		[cells("DentLipB", lips[1], st.lip, {"back": true}), st.lip, 1.0], [cells("DentTop", top, st.light, {"back": true}), st.light, 0.8]]
	for d in dent:
		var col: Color = d[1]
		var ak: float = d[2]
		keyf(d[0], "modulate", func(tt: float) -> Color: return Color(col, fade.call(tt) * ak), 0.0, D, 30.0)
		show(d[0], 0.021)
	var floor_hot := cells("DentFloor", bottom, st.lip, {"back": true})
	var floor_col := func(tt: float) -> Color:
		var hh: float = heat.call(tt)
		return Color(C[5] if hh > 0.5 else C[4] if hh > 0.2 else st.lip, fade.call(tt))
	keyf(floor_hot, "modulate", floor_col, 0.0, D, 30.0, "nearest")
	show(floor_hot, 0.021)
	var cr := cracks_node("Cracks", cracks, {"grow": 0.1, "hot0": W, "hot1": C[5], "hot2": C[4], "hot3": C[3], "dark": SOOT, "lip": st.light}, {"back": true})
	clock(cr[0], 0.0, 0.2)
	keyf(cr[0], U + "heat", heat, 0.0, 0.85)
	keyf(cr[0], U + "fade", fade, 0.0, D, 30.0)
	var em := []
	for e in embers:
		em.append(e)
	while em.size() < 64:
		em.append(Vector4.ZERO)
	var emb := shape("Embers", sh("embers"), Vector2(140, 28), {"pts": PackedVector4Array(em.slice(0, 64)), "count": float(mini(64, embers.size())),
		"hi": C[5], "mid": C[4], "lo": C[3]}, {"at": Vector2(0, 12), "back": true})
	clock(emb)
	var ru := func(tt: float) -> float: return clampf((tt - 0.015) / (WAVE + 0.1), 0.0, 1.0)
	for half in [["RingBack", 1.0, true], ["RingFront", -1.0, false]]:
		if half[0] == "RingFront":
			# the dust (the original's back layer) lies over the dent and under the ring's near half
			flush({"only": [DUST, SMOKE]})
		var rb := shape(half[0], sh("band"), Vector2(2 * (REACH + 6), 40), {"mid": Vector2(0, 0.5), "radius": 8.0, "th": 4.0, "squash": 0.16, "side": half[1],
			"c0": C[3], "c1": C[4], "c2": C[5], "c3": W}, {"at": Vector2(0, 0), "back": half[2]})
		keyf(rb, U + "radius", func(tt: float) -> float: return front.call(tt) + 1.0, 0.015, 0.65)
		keyf(rb, U + "th", func(tt: float) -> float: return maxf(1.0, 4.0 * pow(1.0 - ru.call(tt), 0.8)), 0.015, 0.65)
		keyf(rb, U + "alpha", func(tt: float) -> float: return 1.1 if ru.call(tt) < 0.55 else (0.9 - ru.call(tt)) / 0.35, 0.015, 0.65)
		keyf(rb, U + "c0", func(tt: float) -> Color: return C[3] if ru.call(tt) < 0.35 else st.body, 0.015, 0.65, 60.0, "nearest")
		keyf(rb, U + "c1", func(tt: float) -> Color: return C[4] if ru.call(tt) < 0.35 else st.light, 0.015, 0.65, 60.0, "nearest")
		keyf(rb, U + "c2", func(tt: float) -> Color: return C[5] if ru.call(tt) < 0.35 else C[4], 0.015, 0.65, 60.0, "nearest")
		keyf(rb, U + "c3", func(tt: float) -> Color: return W if tt < 0.09 else C[6] if ru.call(tt) < 0.35 else C[5], 0.015, 0.65, 60.0, "nearest")
		show(rb, 0.015, 0.645)
	keep_colour(st.body)
	keep_colour(st.dust)

	# ---- the two standing fronts racing out
	var fu := func(tt: float) -> float: return clampf((tt - 0.03) / (WAVE + 0.16), 0.0, 1.0)
	var fcols := func(tt: float, j: int) -> Color:
		var v: float = fu.call(tt)
		var cs: Array = [W, C[6], C[5]] if v < 0.14 else [C[6], C[5], C[4]] if v < 0.34 else [C[5], C[4], st.lip] if v < 0.55 else [st.lip, st.light, st.dust]
		return cs[j]
	var fk := func(tt: float) -> float: return 1.0 if fu.call(tt) < 0.7 else (1.0 - fu.call(tt)) / 0.3
	var fh := func(tt: float) -> float: return 6.0 + 28.0 * pow(1.0 - fu.call(tt), 0.75)
	for s in [-1.0, 1.0]:
		var nm := "FrontL" if s < 0 else "FrontR"
		var fr := shape(nm, sh("front"), Vector2(2 * (REACH + 30), 40), {"pos": 0.0, "dir": s, "h": 34.0, "w": 6.5, "edge_c": W, "body_c": C[6], "back_c": C[5]},
			{"at": Vector2(0, -20)})
		keyf(fr, U + "pos", func(tt: float) -> float: return s * front.call(tt), 0.03, 0.79)
		keyf(fr, U + "h", fh, 0.03, 0.79)
		keyf(fr, U + "w", func(tt: float) -> float: return 1.5 + 5.0 * pow(1.0 - fu.call(tt), 0.9), 0.03, 0.79)
		keyf(fr, U + "alpha", fk, 0.03, 0.79)
		keyf(fr, U + "edge_c", func(tt: float) -> Color: return fcols.call(tt, 0), 0.03, 0.79, 60.0, "nearest")
		keyf(fr, U + "body_c", func(tt: float) -> Color: return fcols.call(tt, 1), 0.03, 0.79, 60.0, "nearest")
		keyf(fr, U + "back_c", func(tt: float) -> Color: return fcols.call(tt, 2), 0.03, 0.79, 60.0, "nearest")
		show(fr, 0.03, 0.79)
		var fg := glow(nm + "Light", 34, {"radius": 30.0, "color": C[4], "alpha": 0.0}, {"at": Vector2(s * 7, -10)})
		keyf(fg, "position", func(tt: float) -> Vector2: return Vector2(s * front.call(tt), -fh.call(tt) * 0.3).round(), 0.03, 0.79)
		keyf(fg, U + "radius", func(tt: float) -> float: return 8.0 + fh.call(tt) * 0.7, 0.03, 0.79)
		keyf(fg, U + "alpha", func(tt: float) -> float: return 0.5 * (1.0 - fu.call(tt)) * fk.call(tt) if (tt >= 0.03 and fu.call(tt) < 1.0) else 0.0, 0.0, 0.8)

	# ---- rocks, then sparks, grit and flakes
	flush({"sparks": [C[6], C[5], C[4], C[3]], "stone": st})

	# ---- the flash: a flat half-star hugging the floor on its two frames
	var fl := shape("Flash", sh("ellipse"), Vector2(64, 12), {"mid_at": Vector2(0, 0), "rx": 30.0, "ry": 4.5, "t1": 0.5, "t2": 0.8, "inner": W, "mid": C[6], "outer": C[4]},
		{"at": Vector2(0, 0)})
	show(fl, 0.0, 0.035)
	hit_star("Star", Vector2(0, -1), burst, 2.4, [[0.0, 1.0, 1.0, 1.0, [C[4], C[6], W, W]], [0.035, 1.25, 0.5, 1.0, [C[3], C[5], C[6], W]], [0.07]])

	# ---- light
	glow_line("FloorFlash", Vector2(-80, 0), Vector2(80, 0), 10, C[5], func(tt: float) -> float: return 0.55 * (1.0 - tt / 0.14) if tt < 0.14 else 0.0, 0.0, 0.15)
	glow_fn("DentGlow", Vector2(0, 1), 46, C[4], func(tt: float) -> float: return 0.35 * heat.call(tt), 0.0, 0.82)
	var cl := points_light("CrackLight", cr[1], Vector2(-80, -8), Vector2(80, 32), {"mode": 0.0, "color": C[4]})
	keyf(cl, U + "heat", heat, 0.0, 0.85)
	keyf(cl, U + "fade", fade, 0.0, D, 30.0)
	var el := points_light("EmberLight", embers, Vector2(-80, -8), Vector2(80, 32), {"mode": 1.0, "color": C[4]})
	clock(el)
	light_add("Light", Vector2(0, -12), 96, C[4], 0.6, 0.6)
	light_add("LightWhite", Vector2(0, -4), 50, W, 0.9, 0.14)
