# reimagined-from: src/fx/impacts/heavy-landing.js@673802dfca343b212b8720838b4776998b8e4bcc
# Heavy landing: A character lands hard: the floor dents and cracks under their feet, two rings of dust roll out along
# the floor one after the other, and pebbles hop away.
# The two dust rings are a soft-layer shader (fx/impacts/_dustring.gdshader, the original's lumpy ring tearing into
# clumps) keyed from its curves, far halves behind the stand-in and near halves in front, the fast one led by a crisp
# band (_band); the dent is the original's cells and the cracks its jagged lines (_cracks), growing in 0.08 s. Dust
# puffs riding the rings, the low cloud at the feet, pebbles that hop away (faceted, bouncing, kicking dust) and grit
# are GPU particles from the original's own draws on its physics (_sim.gdshader), split behind / in front as it does.
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	var st := stone(Color(o.stone))
	R = JsRng.new(int(o.seed))
	var D: float = meta.duration
	var W := Color.WHITE
	var cracks := make_cracks(6, {"len": [8.0, 20.0], "dive": 0.7, "maxY": 12.0, "forks": 0.4, "x0": [2.0, 6.0]})
	var DUSTC := mixc(st.dust, C[5], 0.4)
	var LIT := mixc(DUSTC, W, 0.3)
	var PH := R.range(0, TAU)
	for rg in [[20, 140.0, 190.0, 2.2, 3.4, 0.01], [18, 70.0, 110.0, 3.4, 5.4, 0.12]]:
		var n: int = rg[0]
		for i in n:
			var g := (i / float(n)) * TAU + R.range(-0.1, 0.1)
			var v := R.range(rg[1], rg[2])
			var far := sin(g) < 0
			var vy := sin(g) * v * 0.16 - R.range(2, 10)
			var life := R.range(0.45, 0.8)
			var c := LIT if R.chance(0.45) else DUSTC
			var sz := R.range(rg[3], rg[4])
			spawn(DUST, cos(g) * 4, sin(g) * 0.7 - 1, cos(g) * v, vy, life, c, sz, rg[5] + R.range(0, 0.03), 0, 0.0, "back" if far else "front")
	for i in 12:
		var s := R.sign()
		var up := i < 6
		var x0 := s * R.range(2, 10)
		var y0 := -R.range(1, 4)
		var vx := s * R.range(10, 35) * (0.6 if up else 1.0)
		var vy := -(R.range(25, 60) if up else R.range(4, 12))
		var life := R.range(0.55, 0.9)
		var c := LIT if R.chance(0.5) else DUSTC
		var sz := R.range(3, 5)
		spawn(DUST, x0, y0, vx, vy, life, c, sz, R.range(0.02, 0.1), 0, 0.0, "front" if i % 2 else "back")
	for i in 12:
		var s := R.sign()
		var v := R.range(50, 130)
		var x0 := s * R.range(3, 8)
		var vy := -R.range(140, 230)
		var life := R.range(1, 1.45)
		var a0 := R.range(0, TAU)
		var va := s * R.range(8, 16)
		var sz := 2.0 if R.chance(0.3) else 1.0
		var pts := []
		for j in 6:
			pts.append(R.range(0.7, 1.12))
		add_bit({"kind": CHUNK, "x": x0, "y": -1.0, "vx": s * v, "vy": vy, "g": 1.0, "drag": 0.5, "bounce": 0.55, "life": life, "a": a0, "va": va, "s": sz, "pts": pts})
	for i in 24:
		var s := R.sign()
		var a := -PI / 2 + s * R.range(0.3, 1.2)
		var v := R.range(60, 170)
		var x0 := s * R.range(2, 7)
		var life := R.range(0.6, 1.1)
		var c: Color = R.pick([st.light, st.body, st.lip])
		spawn(GRIT, x0, -1, cos(a) * v, sin(a) * v, life, c, 2 if R.chance(0.3) else 1)
	var kick := func(b: Dictionary, tt: float, _pvy: float) -> void:
		var vx := R.sign() * R.range(6, 20)
		var vy := -R.range(2, 10)
		var life := R.range(0.25, 0.45)
		spawn(DUST, b.x, -0.5, vx, vy, life, DUSTC, R.range(1, 1.8), 0.0, 0, tt - DT, "front")
	replay_bits(kick, 80.0)

	var U := "material:shader_parameter/"
	var fade := func(t: float) -> float: return 1.0 - smooth(D - 0.5, D - 0.1, t)
	# behind the character: the dent, the cracks, the rings' far halves, the far dust
	var dl := []
	for x in range(-10, 10):
		var q := absf(x + 0.5) / 10.0
		var dep := int(floor(1.8 * (1.0 - q * q) + 0.5))
		if q < 0.82:
			for y in dep:
				dl.append([Vector2(x, y), SOOT, 1.0])
			dl.append([Vector2(x, dep), st.lip, 1.0])
		else:
			dl.append([Vector2(x, -1), st.light if q > 0.92 else st.lip, 1.0])
	var dent := dots("Dent", dl, {"back": true})
	keyf(dent, "modulate:a", fade, 0.0, D, 30.0)
	var cr := cracks_node("Cracks", cracks, {"grow": 0.08, "hot0": W, "hot1": W, "hot2": W, "hot3": W, "dark": SOOT, "lip": st.light}, {"back": true})
	clock(cr[0], 0.0, 0.2)
	keyf(cr[0], U + "fade", fade, 0.0, D, 30.0)
	keep_colour(DUSTC)
	keep_colour(LIT)
	keep_colour(st.body)
	var rings := func(far: bool) -> void:
		var j := 0
		for rg in [[0.01, 0.45, 58.0, 4.5, 0.75, true], [0.12, 0.85, 42.0, 6.0, 0.8, false]]:
			var t0: float = rg[0]
			var dur: float = rg[1]
			var r1: float = rg[2]
			var w: float = rg[3]
			var k0: float = rg[4]
			var gg := func(t: float) -> float: return clampf((t - t0) / dur, 0.0, 1.0)
			var nm := "Ring%d%s" % [j, "Far" if far else "Near"]
			var dr := shape(nm, sh("dustring"), Vector2(2 * (r1 + 30), 2 * ceilf((r1 + 30) * 0.2) + 4), {"mid": Vector2.ZERO, "radius": 6.0, "w": w, "alpha": 0.0,
				"squash": 0.2, "ph": PH + t0 * 10.0, "brk": 0.0, "side": 1.0 if far else -1.0, "color": DUSTC, "lite": mixc(DUSTC, W, 0.35), "translucent": true},
				{"at": Vector2.ZERO, "back": far})
			keyf(dr, U + "radius", func(t: float) -> float: return 6.0 + r1 * out_cubic(gg.call(t)), t0, t0 + dur)
			keyf(dr, U + "w", func(t: float) -> float: return w * (1.0 + gg.call(t)), t0, t0 + dur)
			keyf(dr, U + "brk", func(t: float) -> float: return gg.call(t) * 0.8, t0, t0 + dur)
			keyf(dr, U + "alpha", func(t: float) -> float: return k0 * pow(1.0 - gg.call(t), 1.2) * minf(1.0, gg.call(t) / 0.06), t0, t0 + dur)
			show(dr, t0 + 0.001, t0 + dur)
			if rg[5]:
				var bd := shape(nm + "Edge", sh("band"), Vector2(2 * (r1 + 12), 32), {"mid": Vector2(0, 0.5), "radius": 8.0, "th": 2.5, "squash": 0.2,
					"side": 1.0 if far else -1.0, "c0": st.body, "c1": st.light, "c2": LIT, "c3": W}, {"at": Vector2.ZERO, "back": far})
				keyf(bd, U + "radius", func(t: float) -> float: return 8.0 + r1 * out_cubic(gg.call(t)), t0, t0 + dur * 0.75)
				keyf(bd, U + "th", func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - gg.call(t))), t0, t0 + dur * 0.75)
				keyf(bd, U + "alpha", func(t: float) -> float: return 1.1 - gg.call(t) / 0.75, t0, t0 + dur * 0.75)
				show(bd, t0 + 0.001, t0 + dur * 0.75)
			j += 1
	rings.call(true)
	flush({"only": [DUST]})   # the far dust goes behind with it; the near dust is flushed in front below
	rings.call(false)
	flush({"stone": st})

	# the thud: a flat streak of light along the floor for a frame or two
	var fl := shape("Thud", sh("ellipse"), Vector2(34, 8), {"mid_at": Vector2.ZERO, "rx": 15.0, "ry": 2.5, "t1": 0.55, "t2": 2.0, "inner": W, "mid": C[6], "outer": C[6]},
		{"at": Vector2.ZERO})
	show(fl, 0.0, 0.035)
	var sl := []
	for x in range(-22, 23):
		sl.append([Vector2(x, 0), W if absi(x) < 10 else C[5], 1.0 - absi(x) / 24.0])
	var streak := dots("Streak", sl)
	show(streak, 0.035, 0.07)
	glow_line("ThudLight", Vector2(-20, 0), Vector2(20, 0), 8, C[6], func(t: float) -> float: return 0.45 * (1.0 - t / 0.12) if t < 0.12 else 0.0, 0.0, 0.13)
