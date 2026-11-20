# reimagined-from: src/fx/transitions/star-iris.js@b46315a107bab00a2a2e37f2a202ed23251e81a2
# Star iris: A five-point star iris spins shut on the middle of the screen, its gold rim lit and its tips twinkling and shedding motes; it closes on a glint and spins open again from a flash.
# one-shot, 2.20 s, 320x180 canvas, origin [0.0, 0.0], backdrop sky
# The star's ten points are keyed every frame from the original's curve (on its own clock); one screen shader fills
# the dark outside them row by row and strokes the gold rim along each edge (fx/transitions/_star.gdshader), its light
# twin the rim's light. The twinkles on the tips, the glints where it shuts and opens and the pool of light are
# frame-table particles (marks()); the motes and stars the tips shed and the burst as it opens are the original's
# particles replayed from its generator (scifi ghosts); its flashes are Lights.
extends "res://build/fx/transitions/_transitions.gd"

const CLOSE := 0.98
const OPEN0 := 1.16
const OPEN1 := 2.0
const RMAX := 430.0
const INNER := 0.46


static func star_at(t: float) -> Vector2:
	if t < CLOSE:
		return Vector2(RMAX * pow(1.0 - in_out_quad(t / CLOSE), 1.3), -PI / 2.0 + in_out_cubic(t / CLOSE) * 1.6 * TAU)
	if t < OPEN0:
		return Vector2.ZERO
	var u := clampf((t - OPEN0) / (OPEN1 - OPEN0), 0.0, 1.0)
	return Vector2(RMAX * pow(in_out_cubic(u), 1.15), -PI / 2.0 - in_out_cubic(u) * 1.6 * TAU)


static func points(f: Vector2, r: float, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 10:
		var rr := r * INNER if i % 2 else r
		var an := a + i * PI / 5.0
		out.append(Vector2(f.x + cos(an) * rr, f.y + sin(an) * rr))
	return out


func make() -> void:
	var o: Dictionary = meta.options
	var R := JsRng.new(int(o.seed))
	var F := Vector2(o.focus[0], o.focus[1])
	var end: float = D - 0.05
	var st := {"shut": false, "opened": false, "prev": star_at(0.0)}
	var lights := []
	ghosts_begin(0.0)
	var step := func(t: float, dt: float) -> void:
		var s := star_at(t)
		var pts := points(F, s.x, s.y)
		var prev: Vector2 = st.prev
		var spin := (s.y - prev.y) / dt
		if s.x > 2.0:
			for i in range(0, 10, 2):
				var x: float = pts[i].x
				var y: float = pts[i].y
				if x < 0.0 or y < 0.0 or x >= SW or y >= SHH or not R.chance(0.35):
					continue
				var an := s.y + i * PI / 5.0
				var v := spin * s.x * 0.25
				var k := STAR if R.chance(0.6) else MOTE
				var life := minf(R.range(0.25, 0.55), end - t)
				var col: Color = C[6] if R.chance(0.5) else C[5]
				var sz := R.range(0.6, 1.8)
				spawn(R, t, k, x, y, -sin(an) * v + cos(an) * 20.0, cos(an) * v + sin(an) * 20.0, life, col, sz)
		if not st.shut and t >= CLOSE:
			st.shut = true
			lights.append([t, F, 60.0, C[5], 0.7, 0.3])
		if not st.opened and t >= OPEN0:
			st.opened = true
			lights.append([t, F, 120.0, C[5], 0.7, 0.4])
			lights.append([t, F, 40.0, Color.WHITE, 0.8, 0.12])
			for i in 24:
				var a := R.range(0, TAU)
				var v := R.range(60, 200)
				var life := R.range(0.3, 0.6)
				var col: Color = Color.WHITE if R.chance(0.5) else C[6]
				var sz := R.range(0.6, 2)
				spawn(R, t, STAR, F.x, F.y, cos(a) * v, sin(a) * v, life, col, sz)
		st.prev = s
	var clocks := replay(step)

	var modes := []
	var pts_k := []
	var rows := []
	for i in NF:
		var t: float = clocks[i]
		var s := star_at(t)
		var pts := points(F, s.x, s.y)
		var mode := 1.0 if (t >= CLOSE and t < OPEN0) else (2.0 if s.x < RMAX - 2.0 else 0.0)
		modes.append([i / 30.0, mode])
		pts_k.append([i / 30.0, pts])
		var out := []
		if mode == 2.0:
			for k in range(0, 10, 2):
				var p: Vector2 = pts[k]
				if p.x < 2.0 or p.y < 2.0 or p.x > SW - 2.0 or p.y > SHH - 2.0:
					continue
				out.append(glint_m(p.x, p.y, 5.0 + 3.0 * sin(t * 13.0 + k), t * 2.0 + k, 6, 5))
			if s.x < 140.0:
				out.append({"k": M_NONE, "x": F.x, "y": F.y, "lc": 5, "lp": F, "lr": s.x * 0.7 + 8.0, "lk": 0.35 * (1.0 - s.x / 140.0)})
		var u := t - CLOSE
		if u > -0.05 and u < 0.2:
			out.append(glint_m(F.x, F.y, 14.0 * (1.0 - absf(u) / 0.2), u * 4.0, 6, 5))
		var v := t - OPEN0
		if v >= 0.0 and v < 0.16:
			var g: Variant = glint_m(F.x, F.y, 18.0 * (1.0 - v / 0.16), 0.3 - v * 5.0, 6, 5)
			if g != null:
				g.lc = 8
				g.lp = F
				g.lr = 50.0
				g.lk = 0.5 * (1.0 - v / 0.16)
			out.append(g)
		rows.append(out)
	for n in [screen("Star", "star"), screen("Light", "star_light")]:
		key(n, "material:shader_parameter/mode", modes, "nearest")
		key(n, "material:shader_parameter/pts", pts_k, "nearest")
	marks("Glints", rows)
	ghosts({"sparks": [Color.WHITE, C[6], C[5], C[4]]})
	var li := 0
	for l in lights:
		light_at("Flash%d" % li, l[0], l[1], l[2], l[3], l[4], l[5], clocks)
		li += 1
