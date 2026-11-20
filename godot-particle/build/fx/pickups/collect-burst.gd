# reimagined-from: src/fx/pickups/collect-burst.js@cf0330c93189518219ee68e86f6c49ee04ba2c1c
# Collect burst: The moment of pickup: a white flash and a cross of light, a thin ring snapping out ahead of a softer one, twinkles thrown wide on curving paths that brake, hang and wink out.
# one-shot, 1.35 s, 112x108 canvas, origin [56, 94], backdrop ground
# ramp palette: #1a0516 #3d0a33 #701560 #b0228f #f53cd1 #ff86e6 #ffd2f6 #ffffff
# The pop (the flash disc, the cross of light, the two rings) is a canvas shader keyed every frame from the original's
# timings (fx/pickups/_burst.gdshader); its light (the flash, the rings' glow, the two bursts of light) is keyed. The
# twinkles are particles: the original's own simulation (its seeded Rng, its 120 Hz steps: curving headings, drag,
# the floor turning them back up) is replayed at build time and each twinkle placed frame by frame with its short
# trail, its flicker and its glow; the motes drifting up after are particles the same way.
extends "res://build/fx/pickups/_pickups.gd"

const CY := -30.0


func make() -> void:
	var W := Color.WHITE
	var R := JsRng.new(3)
	var stars := []
	for i in 14:
		var s := {}
		s.a = (i / 14.0) * TAU + R.range(-0.2, 0.2)
		s.sp = R.range(145, 225) * (1.12 if i % 3 == 0 else 0.85)
		s.turn = (1.0 if i % 2 else -1.0) * R.range(2.5, 5)
		s.life = R.range(0.75, 1.15)
		s.size = 2.6 if i % 3 == 0 else R.range(1.2, 2)
		s.c = 8 if i % 4 == 0 else (6 if i % 2 else 5)
		s.ph = R.range(0, TAU)
		s.x = 0.0
		s.y = CY
		s.age = 0.0
		s.tr = []
		stars.append(s)
	var motes := []
	for i in 7:
		var m := {}
		m.x = R.range(-8, 8)
		m.y = CY + R.range(-4, 6)
		m.vy = -R.range(12, 30)
		m.life = R.range(0.5, 0.9)
		m.d = R.range(0.05, 0.25)
		m.w = R.range(0, TAU)
		motes.append(m)
	# the lights: [x, y, r, colour, k, life left, life]
	var lights := [[0.0, CY, 36.0, C[5], 0.85, 0.32, 0.32], [0.0, CY, 14.0, W, 0.75, 0.08, 0.08]]
	# replay: frame i is drawn after i updates of 1/30 s, each four steps of 1/120 s (the effect's own clock adds them)
	var tclock := []
	var trails := []
	var glints := []
	var mote_rows := []
	var light_rows := []
	var t := 0.0
	var dt := (1.0 / 30.0) / 4.0
	for f in NF:
		if f > 0:
			for step in 4:
				t += dt
				for s in stars:
					if s.age > s.life:
						continue
					s.age += dt
					s.tr.push_front([s.x, s.y])
					if s.tr.size() > 4:
						s.tr.pop_back()
					s.a += s.turn * dt * maxf(0.0, 1.0 - s.age * 1.5)
					s.sp -= s.sp * 4.3 * dt
					s.x += cos(s.a) * s.sp * dt
					s.y += sin(s.a) * s.sp * dt + 6.0 * s.age * dt
					if s.y > -2.0:
						s.y = -2.0
						s.a = -absf(s.a)
						s.sp *= 0.5
				for l in lights:
					l[5] -= dt
				lights = lights.filter(func(l: Array) -> bool: return l[5] > 0.0)
		tclock.append(t)
		var tr := []
		var gr := []
		for s in stars:
			if s.age > s.life:
				tr += [null, null, null]
				gr.append(null)
				continue
			var k: float = 1.0 - s.age / s.life
			var tw: float = 0.65 + 0.35 * sin(s.age * 26.0 + s.ph)
			for j in range(1, 4):
				tr.append(dot_e(s.tr[j][0], s.tr[j][1], 5 if j < 2 else 4, (1.0 - j / 4.0) * k * 1.4) if j < s.tr.size() else null)
			if k < 0.3 and sin(s.age * 40.0 + s.ph) < 0.0:
				gr.append(null)
			else:
				gr.append(glint_e(s.x, s.y, jround(s.size * tw * minf(1.0, k * 2.5)), s.c, 0.45 * k))
		trails.append(tr)
		glints.append(gr)
		var mr := []
		for m in motes:
			var a: float = t - m.d
			if a < 0.0 or a > m.life:
				mr.append(null)
				continue
			var k: float = 1.0 - a / m.life
			var x: float = m.x + sin(a * 6.0 + m.w) * 1.5
			var y: float = m.y + m.vy * a
			mr.append(dot_e(x, y, 6 if k > 0.5 else 5, k * 1.5, [x + 0.5, y + 0.5, 3.0, C[5], 0.3 * k]))
		mote_rows.append(mr)
		var lr := []
		for l in lights:
			var k: float = l[5] / l[6]
			lr.append([l[0], l[1], l[2] * (0.55 + 0.45 * k), l[3], l[4] * k * k])
		light_rows.append(lr)
	var at := func(i: int) -> float: return tclock[i]
	glows("Glow", func(i: int, _t: float) -> Array:
		var tt: float = at.call(i)
		var l := []
		if tt < 0.16:
			var k := 1.0 - tt / 0.16
			l.append({"c": C[5], "p": Vector2(0, CY), "r": 20.0 * k + 4.0, "k": 0.6 * k})
		else:
			l.append(null)
		var u1 := tt / 0.32
		l.append({"t": G_RING, "c": C[5], "p": Vector2(0, CY), "r": 3.0 + 23.0 * out_expo(u1), "w": 4.0, "k": 0.4 * (1.0 - u1)} if u1 < 1.0 else null)
		var lit: Array = light_rows[i]
		for j in 2:
			if j < lit.size():
				var q: Array = lit[j]
				l.append({"c": q[3], "p": Vector2(q[0], q[1]), "r": q[2], "k": q[4]})
			else:
				l.append(null)
		return l)
	var pop := body("Pop", "burst", {"cy": CY})
	var kf := func(prop: String, f: Callable) -> void:
		per_frame(pop, "material:shader_parameter/" + prop, func(i: int, _t: float) -> Variant: return f.call(float(at.call(i))))
	kf.call("flash_r", func(tt: float) -> float: return 5.5 * (1.0 - tt / 0.07) + 1.0 if tt < 0.07 else 0.0)
	kf.call("cross_l", func(tt: float) -> float:
		if tt >= 0.16:
			return 0.0
		var k := 1.0 - tt / 0.16
		return 26.0 * out_cubic(minf(1.0, tt / 0.03 + 0.4)) * k)
	kf.call("cross_a", func(tt: float) -> float: return 0.5 + (1.0 - tt / 0.16) if tt < 0.16 else 0.0)
	kf.call("r1", func(tt: float) -> float: return 3.0 + 23.0 * out_expo(tt / 0.32) if tt / 0.32 < 1.0 else 0.0)
	kf.call("a1", func(tt: float) -> float: return 1.3 - (tt / 0.32) * 1.2)
	kf.call("r1_white", func(tt: float) -> bool: return tt / 0.32 < 0.3)
	kf.call("r2", func(tt: float) -> float:
		var u2 := (tt - 0.04) / 0.5
		return 2.0 + 16.0 * out_cubic(u2) if u2 > 0.0 and u2 < 1.0 else 0.0)
	kf.call("w2", func(tt: float) -> float: return maxf(1.0, 2.6 * (1.0 - (tt - 0.04) / 0.5)))
	kf.call("a2", func(tt: float) -> float: return 1.0 - (tt - 0.04) / 0.5)
	table("Trails", K_DOT, trails)
	table("Twinkles", K_GLINT, glints)
	table("Motes", K_DOT, mote_rows)
