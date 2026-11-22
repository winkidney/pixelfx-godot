# reimagined-from: src/fx/ui/confetti.js@735fd4e6ee4ab5ef68812cad339c59cfbc4332cb
# Confetti: Two party poppers bang one after the other: paper bits and curly streamers burst out, stall, then tumble and flutter down, flipping, and settle on the floor.
# one-shot, 3.40 s, 200x140 canvas, origin [100, 126], backdrop ground
# ramp palette: #ff4a5a #ff9a2a #ffe03c #5ad84a #3cc8ff #7a6cff #f53cd1
# The paper is particles: every bit (a card turned by its tilt, its width by its flip, its back darker, a white edge
# face-on) is a paper kind of the frame-table particles (_ui.gd, fx/ui/_bits.gdshader), replayed from the original's
# own flutter (drag, stall, swing, flip, settle) at its 120 Hz steps; the streamers are two-tone line particles
# whose links follow their heads as the original's do; sparks and the poppers' smoke (blended in its own colours)
# too. The poppers are a canvas shader (fx/ui/_popper.gdshader) keyed with their kick; every light is a light table.
extends "res://build/fx/ui/_ui.gd"

const POP_INK := Color("#141019")


func make() -> void:
	var W := Color.WHITE
	var R := JsRng.new(int(meta.options.seed))
	var poppers := [{"x": -74.0, "y": -1.0, "a": -PI / 2.0 + 0.62, "t": 0.1}, {"x": 74.0, "y": -1.0, "a": -PI / 2.0 - 0.62, "t": 0.26}]
	var ps := sim_new(R, [Color("#ffffff"), Color("#fff3a6"), Color("#ffc23d"), Color("#ff8a2a")], 0.0)
	var lights := lights_new()
	var bits := []
	var ribbons := []
	var fired := [false, false]
	var end: float = D - 0.05
	var kick := func(t: float, pp: Dictionary) -> float: return 0.0 if t < pp.t else 3.0 * exp(-(t - pp.t) * 14.0)
	var fire := func(pp: Dictionary) -> void:
		var mx: float = pp.x + cos(pp.a) * 11.0
		var my: float = pp.y + sin(pp.a) * 11.0
		lights_add(lights, mx, my, 34, W, 0.6, 0.12)
		lights_add(lights, mx, my, 50, C[2], 0.4, 0.4)
		for i in 6:
			var vx: float = cos(pp.a) * R.range(20, 60) + R.range(-10, 10)
			var vy: float = sin(pp.a) * R.range(20, 60)
			spawn(ps, SMOKE, mx, my, vx, vy, R.range(0.6, 1), Color("#5d5660"), R.range(2.5, 4))
		for i in 12:
			var an: float = pp.a + R.range(-0.5, 0.5)
			var sp := R.range(120, 260)
			spawn(ps, SPARK, mx, my, cos(an) * sp, sin(an) * sp, R.range(0.1, 0.25))
		for i in 46:
			var an: float = pp.a + R.range(-0.38, 0.38)
			var sp := R.range(200, 380)
			var b := {"x": mx, "y": my, "vx": cos(an) * sp, "vy": sin(an) * sp}
			b.c = R.pick(Array(C))
			b.w = R.range(2, 3)
			b.h = R.range(3, 4.6)
			b.ang = R.range(0, TAU)
			b.spin = R.range(-14, 14)
			b.flip = R.range(0, TAU)
			b.fs = R.range(5, 13)
			b.ph = R.range(0, TAU)
			b.amp = R.range(5, 12)
			b.fw = R.range(2, 3.4)
			b.x0 = 0.0
			b.mode = 0
			b.rest = 0.0
			b.fall = R.range(26, 40)
			bits.append(b)
		for i in 4:
			var an: float = pp.a + R.range(-0.25, 0.25)
			var sp := R.range(220, 330)
			var pts := []
			for j in 11:
				pts.append([mx, my])
			var r := {"pts": pts, "vx": cos(an) * sp, "vy": sin(an) * sp}
			r.c = R.pick(Array(C))
			r.ph = R.range(0, TAU)
			r.amp = R.range(6, 12)
			r.fw = R.range(1.5, 2.4)
			r.mode = 0
			r.x0 = 0.0
			r.curl = R.range(0.7, 1.1)
			r.fall = R.range(22, 32)
			ribbons.append(r)
	var cr := canvas_rect()
	var gback := group("Smoke", {"back": true})
	var pop := shape("Poppers", ush("popper"), cr.size, {"ink": POP_INK, "stripe_lit": C[2], "stripe_dark": scalec(C[2], 0.75), "paper_dark": Color("#c8c0d8"),
		"pos": PackedVector4Array([Vector4(poppers[0].x, poppers[0].y, poppers[0].a, 0), Vector4(poppers[1].x, poppers[1].y, poppers[1].a, 0)])},
		{"at": cr.get_center()})
	var gpop := group("Bang")
	var grib := group("Streamers")
	var gpaper := group("Paper")
	var gfront := group("Sparks")

	var upd := func(dt: float) -> void:
		var t := T
		for i in 2:
			if not fired[i] and t >= poppers[i].t:
				fired[i] = true
				fire.call(poppers[i])
		for b in bits:
			if b.mode == 2:
				b.rest += dt
				continue
			b.flip += b.fs * dt
			if b.mode == 0:
				b.vx -= b.vx * 3.4 * dt
				b.vy -= b.vy * 3.4 * dt - 140.0 * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				b.ang += b.spin * dt
				if sqrt(b.vx * b.vx + b.vy * b.vy) < 40.0:
					b.mode = 1
					b.x0 = b.x - sin(b.ph) * b.amp
			else:
				b.ph += b.fw * dt
				b.x0 += b.vx * dt
				b.vx -= b.vx * 2.0 * dt
				b.x = b.x0 + sin(b.ph) * b.amp
				b.y += b.fall * (0.4 + 0.9 * absf(cos(b.ph))) * dt
				b.ang = cos(b.ph) * 0.9
				if b.y >= -1.0:
					b.y = -0.5
					b.mode = 2
					b.ang = R.range(-0.3, 0.3)
					b.flip = 0.0
		for r in ribbons:
			var h: Array = r.pts[0]
			if r.mode == 0:
				r.vx -= r.vx * 3.0 * dt
				r.vy -= r.vy * 3.0 * dt - 120.0 * dt
				h[0] += r.vx * dt
				h[1] += r.vy * dt
				if sqrt(r.vx * r.vx + r.vy * r.vy) < 35.0:
					r.mode = 1
					r.x0 = h[0] - sin(r.ph) * r.amp
			elif h[1] < -1.0:
				r.ph += r.fw * dt
				r.x0 += r.vx * dt
				r.vx -= r.vx * 2.0 * dt
				h[0] = r.x0 + sin(r.ph) * r.amp
				h[1] += r.fall * (0.5 + 0.7 * absf(cos(r.ph))) * dt
			for i in range(1, r.pts.size()):
				var a: Array = r.pts[i - 1]
				var b: Array = r.pts[i]
				b[1] = minf(-0.5, b[1] + 20.0 * dt)
				var dx: float = b[0] - a[0]
				var dy: float = b[1] - a[1]
				var d := sqrt(dx * dx + dy * dy)
				if d == 0.0:
					d = 1.0
				if d > 2.6:
					b[0] = a[0] + (dx / d) * 2.6
					b[1] = a[1] + (dy / d) * 2.6
		sim_update(ps, dt)
		lights_update(lights, dt)

	var drw := func(_f: int) -> void:
		var t := T
		sim_draw(ps, "back", "smoke")
		var fade := 1.0 - seg(t, end - 0.45, end - 0.05)
		fk(pop, "material:shader_parameter/kick", Vector2(kick.call(t, poppers[0]), kick.call(t, poppers[1])))
		fk(pop, "material:shader_parameter/alpha", 1.0 - seg(t, 2.5, 2.9))
		lay = "bang"
		for pp in poppers:
			var ft: float = t - pp.t
			if ft > 0.0 and ft < 0.12:
				psparkle(pp.x + cos(pp.a) * 13.0, pp.y + sin(pp.a) * 13.0, 7.0 * (1.0 - ft / 0.12), W, C[2], 0.7)
		lay = "ribbons"
		for r in ribbons:
			var pts := []
			for i in r.pts.size():
				var q: Array = r.pts[i]
				pts.append([q[0] + sin(i * r.curl + t * 9.0 + r.ph) * (1.6 if i else 0.0), q[1]])
			for i in range(1, pts.size()):
				var front: bool = sin(i * r.curl + t * 9.0 + r.ph) > 0.0
				var c: Color = r.c
				pline(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1], c if front else scalec(c, 0.6), {"a": fade})
				pline(pts[i - 1][0] + 1.0, pts[i - 1][1], pts[i][0] + 1.0, pts[i][1], mixc(c, W, 0.35) if front else scalec(c, 0.45), {"a": fade})
		lay = "paper"
		for b in bits:
			if b.y > 1.0:
				continue
			var c: Color = b.c
			var fw: float = 1.0 if b.mode == 2 else cos(b.flip)
			var w := maxf(0.5, absf(fw) * b.w)
			if b.mode == 2:
				pdot(b.x, b.y, scalec(c, 0.8), fade)
				pdot(b.x + 1.0, b.y, scalec(c, 0.6), fade)
				continue
			_put(_e(Q_PAPER, b.x, b.y, fade, c if fw >= 0.0 else scalec(c, 0.62), [b.x - floorf(b.x), b.y - floorf(b.y), w, b.h, cos(b.ang), sin(b.ang), absf(fw)], 5.0))
			if absf(fw) > 0.97:
				pglow(b.x, b.y, 5, mixc(c, W, 0.5), 0.35 * fade)
		lay = "sparks"
		sim_draw(ps, "front")
		lights_draw(lights)

	run(upd, drw)
	utable("Smoke", "smoke", {"parent": gback, "back": true, "raw": true})
	utable("Bang", "bang", {"parent": gpop})
	utable("Streamers", "ribbons", {"parent": grib})
	utable("Paper", "paper", {"parent": gpaper})
	utable("Sparks", "sparks", {"parent": gfront})
	light_table()
	flush_keys()
