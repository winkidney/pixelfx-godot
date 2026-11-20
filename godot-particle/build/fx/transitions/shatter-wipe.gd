# reimagined-from: src/fx/transitions/shatter-wipe.js@ab23b72a030c19a49243b179b18069c867d90996
# Shatter wipe: A dark glass pane drops over the screen and bounces; cracks race out from an impact with a flash, then it bursts into tumbling glass shards with lit edges that fall away.
# one-shot, 2.80 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The original's break pattern (rays and rings out of the impact, the cracks' pixels and when each is reached, the
# wedge-shaped cells) is rolled from its seed at build time, and its create()/update() replayed at its 120 Hz steps
# with its own generator. The pane is a screen shader (fx/transitions/_pane.gdshader: the dark glass dropping and
# bouncing, its lit bevel, the cracks racing out from the per-pixel crack list) with its reflections on the soft layer
# and a light twin. Each shard is a particle (fx/transitions/_shard.gdshader: its own polygon tumbling as the
# original's physics moves it, filled and edged as the original draws it, in its draw order for the frame). The glass
# splinters (sim.js Bits), the impact's flare and the edge's sparkle are frame-table particles (marks()); the glints
# and the glass dust are the original's particles (scifi ghosts); its flashes are Lights.
extends "res://build/fx/transitions/_transitions.gd"

const LAND := 0.55
const REST := 0.3
const CRACK := 1.32
const BREAK := 1.62
const WAVE := 520.0
const NR := 13
const RING := [0, 9, 21, 37, 58, 86, 122, 168, 232]
const MAXV := 64

var GP := 2.0 * 180.0 / (LAND * LAND)
var BOUNCES := []


func pane_y(t: float) -> float:
	if t < LAND:
		return -SHH + 0.5 * GP * t * t
	for b in BOUNCES:
		if t < b.t0 + b.T:
			return -(b.v * (t - b.t0) - 0.5 * GP * pow(t - b.t0, 2.0))
	return 0.0


func make() -> void:
	var R := JsRng.new(int(meta.options.seed))
	var end: float = D - 0.05
	var t0b := LAND
	var vb := GP * LAND * REST
	for k in 3:
		BOUNCES.append({"t0": t0b, "v": vb, "T": 2.0 * vb / GP})
		t0b += 2.0 * vb / GP
		vb *= REST

	# ---- the break pattern (pattern(R))
	var Ix := SW * R.range(0.4, 0.6)
	var Iy := SHH * R.range(0.36, 0.54)
	var ang := []
	for i in NR:
		ang.append(((i + R.range(-0.3, 0.3)) / NR) * TAU)
	var speed := []
	for i in NR:
		speed.append(R.range(800, 1300))
	var V := []
	for i in NR:
		var row := []
		for j in RING.size():
			if j == 0:
				row.append(Vector2(Ix, Iy))
				continue
			var rr: float = RING[j] * R.range(0.84, 1.16)
			var aa: float = ang[i] + R.range(-0.07, 0.07)
			row.append(Vector2(Ix + cos(aa) * rr, Iy + sin(aa) * rr))
		V.append(row)
	var jag := func(A: Vector2, Bp: Vector2) -> Array:
		var dx := Bp.x - A.x
		var dy := Bp.y - A.y
		var L := sqrt(dx * dx + dy * dy)
		if L == 0.0:
			L = 1.0
		var n := 2 if L > 18.0 else 1
		var out := [A]
		for k in range(1, n + 1):
			var f := k / float(n + 1) + R.range(-0.08, 0.08)
			var off := R.range(-1, 1) * minf(3.0, L * 0.07)
			out.append(Vector2(A.x + dx * f - (dy / L) * off, A.y + dy * f + (dx / L) * off))
		out.append(Bp)
		return out
	var rad := []
	for i in NR:
		var es := []
		for j in RING.size() - 1:
			es.append(jag.call(V[i][j], V[i][j + 1]))
		rad.append(es)
	var ring := []
	for i in NR:
		var es := []
		for j in RING.size():
			es.append(jag.call(V[i][j], V[(i + 1) % NR][j]) if j else null)
		ring.append(es)
	var keep := []
	for i in NR:
		var kk := []
		for j in RING.size():
			kk.append(j <= 2 or j == RING.size() - 1 or R.chance(0.78 - 0.07 * j))
		keep.append(kk)
	var cracks := []
	var reach := func(i: int, x: float, y: float) -> float: return CRACK + Vector2(x - Ix, y - Iy).length() / speed[i]
	var trace := func(pts: Array, when: Callable) -> void:
		for k in range(1, pts.size()):
			var a: Vector2 = pts[k - 1]
			var b: Vector2 = pts[k]
			var n := int(ceilf(Vector2(b.x - a.x, b.y - a.y).length() * 2.0))
			for s in n:
				var x: float = a.x + (b.x - a.x) * s / n
				var y: float = a.y + (b.y - a.y) * s / n
				if x >= 0.0 and y >= 0.0 and x < SW and y < SHH:
					cracks.append({"x": int(floorf(x)), "y": int(floorf(y)), "t0": when.call(x, y), "n": cracks.size()})
	for i in NR:
		for e in rad[i]:
			trace.call(e, func(x: float, y: float) -> float: return reach.call(i, x, y))
	for i in NR:
		for j in range(1, RING.size() - 1):
			if not keep[i][j]:
				continue
			var i2 := (i + 1) % NR
			var e: Array = ring[i][j]
			var start := maxf(reach.call(i, V[i][j].x, V[i][j].y), reach.call(i2, V[i2][j].x, V[i2][j].y)) + R.range(0.02, 0.07)
			var a0: Vector2 = e[0]
			trace.call(e, func(x: float, y: float) -> float: return start + Vector2(x - a0.x, y - a0.y).length() / 420.0)
	cracks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t0 < b.t0 or (a.t0 == b.t0 and a.n < b.n))
	var cells := []
	for i in NR:
		var j := 0
		while j < RING.size() - 1:
			var jb := j
			while not keep[i][jb + 1]:
				jb += 1
			var i2 := (i + 1) % NR
			var side := func(r: int) -> Array:
				var out := []
				for k in range(j, jb + 1):
					var e: Array = rad[r][k]
					out.append_array(e.slice(1) if k > j else e)
				return out
			var pts: Array = side.call(i)
			pts.append_array((ring[i][jb + 1] as Array).slice(1))
			var s2: Array = side.call(i2)
			s2.reverse()
			pts.append_array(s2.slice(1))
			if j:
				var rr: Array = (ring[i][j] as Array).duplicate()
				rr.reverse()
				pts.append_array(rr.slice(1, rr.size() - 1))
			else:
				pts.pop_back()
			var x0 := INF
			var y0 := INF
			var x1 := -INF
			var y1 := -INF
			for p in pts:
				x0 = minf(x0, p.x)
				x1 = maxf(x1, p.x)
				y0 = minf(y0, p.y)
				y1 = maxf(y1, p.y)
			if not (x1 < 0.0 or y1 < 0.0 or x0 >= SW or y0 >= SHH):
				var cx := (clampf(x0, 0.0, SW) + clampf(x1, 0.0, SW)) / 2.0
				var cy := (clampf(y0, 0.0, SHH) + clampf(y1, 0.0, SHH)) / 2.0
				var d := Vector2(cx - Ix, cy - Iy).length()
				var lp := []
				for p in pts:
					lp.append(Vector2(p.x - cx, p.y - cy))
				cells.append({"pts": pts, "lp": lp, "cx": cx, "cy": cy, "d": d, "r": Vector2(x1 - x0, y1 - y0).length() / 2.0,
					"tb": BREAK + d / WAVE + R.range(0, 0.04), "broke": false, "gone": false, "id": cells.size()})
			j = jb + 1

	# ---- create() / update()
	var bits := []
	var lights := []
	var st := {"bounce": -1, "struck": false, "burst": false}
	ghosts_begin(0.0)
	var splinters := func(t: float, x: float, y: float, n: int, vx: float, vy: float, spread: float, sp0: float, sp1: float) -> void:
		for i in n:
			var a := atan2(vy, vx) + R.range(-spread, spread)
			var sp := R.range(sp0, sp1)
			var life := minf(R.range(0.6, 1.2), end - t)
			if life > 0.2:
				var ba := R.range(0, TAU)
				var va := R.range(-20, 20)
				var s := R.range(1.5, 3.5)
				var c: Color = R.pick([C[7], C[6], C[5]])
				bits.append({"x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "g": 0.8, "drag": 0.6, "life": life, "a": ba, "va": va, "s": s, "c": c})
	var glint := func(t: float, x: float, y: float, s: float = -1.0) -> void:
		if s < 0.0:
			s = R.range(1, 2.4)
		var vx := R.range(-8, 8)
		var vy := R.range(-10, 4)
		var life := minf(R.range(0.3, 0.6), end - t)
		var col: Color = Color.WHITE if R.chance(0.5) else C[6]
		spawn(R, t, STAR, x, y, vx, vy, life, col, s)
	var step := func(t: float, dt: float) -> void:
		while st.bounce + 1 < BOUNCES.size() and t >= BOUNCES[st.bounce + 1].t0:
			st.bounce += 1
			var k: float = BOUNCES[st.bounce].v / BOUNCES[0].v
			if k < 0.05:
				continue
			for i in 5:
				lights.append([t, Vector2(SW * (i + 0.5) / 5.0, SHH - 2.0), 70.0, C[5], 0.5 * k, 0.35])
			for i in int(jr(26.0 * k)):
				var x := R.range(4, SW - 4)
				var vx := R.range(-0.4, 0.4)
				splinters.call(t, x, SHH - 1.0, 1, vx, -1.0, 0.5, 120.0 * k, 330.0 * k)
			for i in int(jr(9.0 * k)):
				var x := R.range(8, SW - 8)
				var y := SHH - R.range(2, 10)
				glint.call(t, x, y)
		if not st.struck and t >= CRACK:
			st.struck = true
			lights.append([t, Vector2(Ix, Iy), 90.0, C[5], 0.8, 0.35])
			lights.append([t, Vector2(Ix, Iy), 34.0, Color.WHITE, 0.9, 0.1])
			splinters.call(t, Ix, Iy, 16, 0.0, -1.0, PI, 60.0, 240.0)
			for i in 5:
				var vx := R.range(-40, 40)
				var vy := R.range(-40, 30)
				var life := R.range(0.35, 0.6)
				spawn(R, t, VAPOUR, Ix, Iy, vx, vy, life, C[6], R.range(2, 3.5))
		if t > CRACK and t < BREAK and R.chance(0.12):
			var c: Dictionary = cracks[R.int_(0, cracks.size() - 1)]
			if c.t0 < t:
				glint.call(t, float(c.x), float(c.y), R.range(0.6, 1.6))
		if not st.burst and t >= BREAK:
			st.burst = true
			lights.append([t, Vector2(Ix, Iy), 170.0, C[4], 0.55, 0.5])
			lights.append([t, Vector2(Ix, Iy), 60.0, Color.WHITE, 0.8, 0.14])
			splinters.call(t, Ix, Iy, 46, 0.0, -1.0, PI, 90.0, 340.0)
			for i in 14:
				var a := R.range(0, TAU)
				var sp := R.range(30, 110)
				var life := R.range(0.45, 0.8)
				var col: Color = C[6] if R.chance(0.6) else C[5]
				spawn(R, t, VAPOUR, Ix + cos(a) * 4.0, Iy + sin(a) * 4.0, cos(a) * sp, sin(a) * sp, life, col, R.range(3, 6))
		for s in cells:
			if not s.broke and t >= s.tb:
				s.broke = true
				var dx: float = s.cx - Ix
				var dy: float = s.cy - Iy
				var d := Vector2(dx, dy).length()
				if d == 0.0:
					d = 1.0
				var sp := R.range(40, 130) * (1.15 - minf(1.0, s.d / 260.0))
				s.vx = (dx / d) * sp + R.range(-15, 15)
				s.vy = (dy / d) * sp * 0.6 - R.range(20, 90)
				s.a = 0.0
				s.va = R.range(-2.5, 2.5) * (1.0 + 20.0 / (s.r + 10.0))
				s.phi = 0.0
				s.vphi = R.sign() * R.range(3, 9)
				s.psi = R.range(0, TAU)
				s.z = 0.0
				s.vz = R.range(0.25, 0.7)
				s.g = R.range(0.85, 1.1)
				s.edgeOn = false
				splinters.call(t, s.cx, s.cy, 4 if s.r > 24.0 else 2, s.vx, s.vy, 1.2, 60.0, 220.0)
				if R.chance(0.15):
					var gx: float = s.cx + R.range(-4, 4)
					var gy: float = s.cy + R.range(-4, 4)
					glint.call(t, gx, gy)
			if not s.broke or s.gone:
				continue
			s.vy += 950.0 * s.g * dt
			s.vx -= s.vx * 0.3 * dt
			s.cx += s.vx * dt
			s.cy += s.vy * dt
			s.a += s.va * dt
			s.phi += s.vphi * dt
			s.z += s.vz * dt
			var on := absf(cos(s.phi)) < 0.2
			if on and not s.edgeOn and t < end - 0.3:
				glint.call(t, s.cx, s.cy, R.range(1.4, 2.6))
			s.edgeOn = on
			if s.cy - s.r / (1.0 + s.z) > SHH + 2.0:
				s.gone = true
		for i in range(bits.size() - 1, -1, -1):
			var b: Dictionary = bits[i]
			b.life -= dt
			if b.life <= 0.0:
				bits.remove_at(i)
				continue
			b.vy += 950.0 * b.g * dt
			b.vx -= b.vx * b.drag * dt
			b.vy -= b.vy * b.drag * dt
			b.x += b.vx * dt
			b.y += b.vy * dt
			b.a += b.va * dt

	# what each frame draws: the shards in their order, the splinters' dots, the marks
	var shard_rows := []
	var bit_rows := []
	var mark_rows := []
	var frame := func(_i: int, t: float) -> void:
		var sr := []
		if t >= BREAK:
			for s in cells:
				if not s.broke:
					sr.append({"x": s.cx, "y": s.cy, "id": s.id, "still": 1.0, "phi": 0.0, "psi": 0.0, "a": 0.0, "z": 0.0})
			var fall := []
			for s in cells:
				if s.broke and not s.gone:
					fall.append(s)
			fall.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z > b.z or (a.z == b.z and a.id < b.id))
			for s in fall:
				sr.append({"x": s.cx, "y": s.cy, "id": s.id, "still": 0.0, "phi": s.phi, "psi": s.psi, "a": s.a, "z": s.z})
		shard_rows.append(sr)
		var br := []
		for b in bits:
			var a := minf(1.0, b.life / 0.4)
			var ca := cos(b.a)
			var sa := sin(b.a)
			var d: float = -b.s / 2.0
			while d <= b.s / 2.0:
				br.append({"x": b.x + ca * d, "y": b.y + sa * d, "c": Color.WHITE if d > b.s / 2.0 - 0.6 else b.c, "a": a})
				d += 0.5
		bit_rows.append(br)
		var mr := []
		if t < BREAK:
			var yb := pane_y(t) + SHH
			var r1 := minf(SHH, floorf(yb))
			var shine := 1.0 - smooth(0.98, 1.22, t)
			var gx := SW * clampf(t / (LAND + 0.25), 0.0, 1.0) * 1.2 - 20.0
			if r1 > 0.0 and shine > 0.0 and t < LAND + 0.25 and gx > 0.0 and gx < SW and r1 - 1.0 < SHH:
				mr.append(sparkle_m(gx, r1 - 1.0, 6.0, 6, 4, 0.5))
			var u := (t - CRACK) / 0.22
			if t >= CRACK and u < 1.0:
				var Lf := 30.0 * pow(1.0 - u, 1.5)
				var fl := {"k": M_FLARE, "x": Ix, "y": Iy, "L": Lf, "fk": 1.0 - u, "c": 6, "c2": 5, "lc": 8, "lp": Vector2(Ix, Iy), "lr": 50.0, "lk": 0.7 * (1.0 - u)}
				if Lf < 1.0:
					fl.k = M_NONE
				mr.append(fl)
		mark_rows.append(mr)
	var clocks := replay(step, frame)

	# ---- the pane
	var cell_lists := {}
	for c in cracks:
		if c.x + 1 < int(SW) and c.y + 1 < int(SHH):
			var k2 := Vector2i(c.x + 1, c.y + 1)
			if not cell_lists.has(k2):
				cell_lists[k2] = []
			cell_lists[k2].append(-c.t0)
		var k1 := Vector2i(c.x, c.y)
		if not cell_lists.has(k1):
			cell_lists[k1] = []
		cell_lists[k1].append(c.t0)
	var total := 0
	for k in cell_lists:
		total += cell_lists[k].size()
	var cpix := Image.create(int(SW), int(SHH), false, Image.FORMAT_RGF)
	var lw := 4096
	var clist := Image.create(lw, int(ceilf(total / float(lw))) + 1, false, Image.FORMAT_RF)
	var at := 0
	for k in cell_lists:
		var l: Array = cell_lists[k]
		cpix.set_pixel(k.x, k.y, Color(at, l.size(), 0))
		for e in l:
			clist.set_pixel(at % lw, at / lw, Color(e, 0, 0))
			at += 1
	var pp := {"cpix": asset("_cpix", cpix), "clist": asset("_clist", clist)}
	var glass := screen("Glass", "pane", pp)
	var sh := screen("Shine", "pane_shine", pp.merged({"translucent": true}))
	var pane := screen("Pane", "pane", pp.merged({"pass": 1.0}))
	var pl := screen("PaneLight", "pane_light", pp)
	keep_colour(C[6])
	for nd in [glass, sh, pane, pl]:
		per_frame(nd, "material:shader_parameter/t", func(i: int, _t: float) -> float: return clocks[i])
		per_frame(nd, "material:shader_parameter/r1", func(i: int, _t: float) -> float: return minf(SHH, floorf(pane_y(clocks[i]) + SHH)) if clocks[i] < BREAK else 0.0)
		per_frame(nd, "material:shader_parameter/y0", func(i: int, _t: float) -> float: return pane_y(clocks[i]))
		per_frame(nd, "material:shader_parameter/shine", func(i: int, _t: float) -> float: return 1.0 - smooth(0.98, 1.22, clocks[i]))
		per_frame(nd, "material:shader_parameter/gx", func(i: int, _t: float) -> float: return SW * clampf(clocks[i] / (LAND + 0.25), 0.0, 1.0) * 1.2 - 20.0)
		per_frame(nd, "material:shader_parameter/cracks_on", func(i: int, _t: float) -> float: return 1.0 if (clocks[i] >= CRACK and clocks[i] < BREAK) else 0.0)
		per_frame(nd, "material:shader_parameter/wbeat", func(i: int, _t: float) -> float: return maxf(0.0, (clocks[i] - (BREAK - 0.07)) / 0.07) if clocks[i] < BREAK else 0.0)
	marks("Flare", mark_rows)

	# ---- the shards: one particle each, in the frame's draw order
	var shape_img := Image.create(MAXV, cells.size(), false, Image.FORMAT_RGF)
	var info := Image.create(cells.size(), 1, false, Image.FORMAT_RGF)
	var far := 1.0
	for s in cells:
		assert(s.lp.size() <= MAXV, "shard with %d corners" % s.lp.size())
		for k in s.lp.size():
			shape_img.set_pixel(k, s.id, Color(s.lp[k].x, s.lp[k].y, 0))
			far = maxf(far, (s.lp[k] as Vector2).length())
		info.set_pixel(s.id, 0, Color(s.lp.size(), s.r, 0))
	var slots := 1
	for r in shard_rows:
		slots = maxi(slots, r.size())
	var data := Image.create(slots, NF * 4, false, Image.FORMAT_RGBAF)
	for f in NF:
		var r: Array = shard_rows[f]
		for j in r.size():
			var e: Dictionary = r[j]
			data.set_pixel(j, f * 4, Color(floorf(e.x), floorf(e.y), e.id, e.still))
			data.set_pixel(j, f * 4 + 1, Color(e.phi, e.psi, 0, 1))
			data.set_pixel(j, f * 4 + 2, Color(e.x, e.y, e.a, e.z))
	var q := int(ceilf(far + 4.0)) * 2 + 1
	var dtex := asset("_shards", data)
	var stex := asset("_shape", shape_img)
	var itex := asset("_info", info)
	var po := {"amount": slots, "lifetime": D + 0.04, "one_shot": true, "explosiveness": 1.0, "local": true, "texture": _oquad(q),
		"process_shader": psh("ftp"), "process_params": {"data": dtex, "nframes": NF, "looped": false}, "preprocess": 0.0}
	var shards := particles("Shards", po)
	shards.interpolate = false
	shards.draw_order = GPUParticles2D.DRAW_ORDER_INDEX
	key(shards, "process_material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	var lit := particles("ShardsLight", {"amount": slots, "lifetime": D + 0.04, "one_shot": true, "explosiveness": 1.0, "local": true,
		"texture": _oquad(q), "layer": "light", "preprocess": 0.0})
	lit.interpolate = false
	lit.seed = shards.seed
	lit.process_material = shards.process_material
	for pair in [[shards, "shard"], [lit, "shard_light"]]:
		var m := ShaderMaterial.new()
		m.shader = tsh(pair[1])
		m.set_shader_parameter("data", dtex)
		m.set_shader_parameter("shape", stex)
		m.set_shader_parameter("info", itex)
		m.set_shader_parameter("quad", float(q))
		m.set_shader_parameter("C", C)
		m.set_shader_parameter("ink", ink)
		m.resource_name = pair[1]
		pair[0].material = m

	marks("Splinters", bit_rows, {"light": false})
	ghosts({"sparks": [C[7], C[6], C[5], C[4]], "haze": C[5], "back": false})
	var li := 0
	for l in lights:
		light_at("Flash%d" % li, l[0], l[1], l[2], l[3], l[4], l[5], clocks)
		li += 1
