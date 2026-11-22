# reimagined-from: src/fx/transitions/iris.js@022b4ba67998bba6943eb6aefbc748ec23df8868
# Iris: a lit iris closes onto a warm spotlight where dust drifts, holds as its rim twinkles, snaps shut into a glint,
# then pops open from a flash with a white-hot rim throwing sparks.
# The hole's radius and the rim's heat are keyed every frame from the original's curves (on its own clock); one screen
# shader inks round the hole with the rim's bevel (fx/transitions/_iris.gdshader), its light twin lights the bevel and
# pools light inside it. The glint running round the rim, the glints where it shuts and pops and the spotlight's pool
# are frame-table particles (marks()); the dust in the spotlight, the rim's twinkles, the sparks it pops with and the
# motes the racing rim sheds are the original's particles replayed from its generator (scifi ghosts); its flashes are
# Lights.
extends "res://build/fx/transitions/_transitions.gd"

const CLOSE := 0.62
const SNAP := 0.9
const SHUT := 0.99
const POP := 1.2
const OPEN := 1.75
const RS := 24.0
const RW := 5.0


func radius(t: float, R0: float) -> float:
	if t < CLOSE:
		return RS + (R0 - RS) * (1.0 - in_out_cubic(t / CLOSE))
	if t < SNAP:
		return RS + sin((t - CLOSE) * 22.0) * 0.8 * (1.0 - (t - CLOSE) / (SNAP - CLOSE))
	if t < SHUT:
		return RS * (1.0 - in_cubic((t - SNAP) / (SHUT - SNAP)))
	if t < POP:
		return 0.0
	return R0 * out_quart(clampf((t - POP) / (OPEN - POP), 0.0, 1.0))


func make() -> void:
	var o: Dictionary = meta.options
	var R := JsRng.new(int(o.seed))
	var F := Vector2(o.focus[0], o.focus[1])
	var R0 := 0.0
	for c in [Vector2(0, 0), Vector2(SW, 0), Vector2(0, SHH), Vector2(SW, SHH)]:
		R0 = maxf(R0, c.distance_to(F))
	R0 += RW + 2.0
	var end: float = D - 0.05
	var st := {"shut": false, "popped": false, "prev": R0}
	var lights := []
	ghosts_begin(0.0)
	var step := func(t: float, dt: float) -> void:
		var r := radius(t, R0)
		if t > CLOSE - 0.25 and t < SNAP and R.chance(0.25):
			var a := R.range(0, TAU)
			var d := sqrt(R.next()) * r * 0.9
			var vx := R.range(-6, 6)
			var vy := -R.range(4, 14)
			spawn(R, t, EMBER, F.x + cos(a) * d, F.y + sin(a) * d, vx, vy, R.range(0.4, 0.8), Color.WHITE, 1.0)
		if t > CLOSE - 0.1 and t < SNAP and R.chance(0.3):
			var a := R.range(0, TAU)
			var life := R.range(0.2, 0.4)
			var col: Color = Color.WHITE if R.chance(0.5) else C[6]
			spawn(R, t, STAR, F.x + cos(a) * (r + 1.0), F.y + sin(a) * (r + 1.0), 0.0, 0.0, life, col, R.range(1, 2.4))
		if not st.shut and t >= SHUT:
			st.shut = true
			lights.append([t, F, 50.0, C[5], 0.7, 0.3])
		if not st.popped and t >= POP:
			st.popped = true
			lights.append([t, F, 140.0, C[5], 0.7, 0.45])
			lights.append([t, F, 50.0, Color.WHITE, 0.9, 0.12])
			for i in 40:
				var a := R.range(0, TAU)
				var v := R.range(150, 420)
				spawn(R, t, SPARK, F.x + cos(a) * 3.0, F.y + sin(a) * 3.0, cos(a) * v, sin(a) * v, R.range(0.2, 0.5))
		if t > POP and t < OPEN - 0.1:
			var vr := (r - float(st.prev)) / dt
			for k in 2:
				if not R.chance(0.6):
					continue
				var a := R.range(0, TAU)
				var x := F.x + cos(a) * r
				var y := F.y + sin(a) * r
				if x < 0.0 or y < 0.0 or x >= SW or y >= SHH:
					continue
				var life := minf(R.range(0.2, 0.45), end - t)
				var col: Color = C[6] if R.chance(0.5) else C[5]
				spawn(R, t, MOTE, x, y, cos(a) * vr * 0.35, sin(a) * vr * 0.35, life, col, 0.7)
		st.prev = r
	var clocks := replay(step)

	var km := []
	var kr := []
	var kh := []
	var kw := []
	var rows := []
	for i in NF:
		var t: float = clocks[i]
		var r := radius(t, R0)
		var hot := (1.0 - smooth(POP, OPEN, t)) if t >= POP else ((0.45 + 0.25 * smooth(CLOSE - 0.2, CLOSE, t)) if t < SNAP else 0.7)
		var mode := 0.0
		if t < OPEN + 0.05 and not (t >= SHUT and t < POP and r <= 0.0):
			mode = 1.0
		elif t >= SHUT and t < POP:
			mode = 2.0
		km.append([i / 30.0, mode])
		kr.append([i / 30.0, r])
		kh.append([i / 30.0, hot])
		kw.append([i / 30.0, RW + (3.0 * hot if t >= POP else 0.0)])
		var out := []
		# the spotlight's pool of light, gathering as the iris closes
		if r > 0.0 and r < 80.0 and t < SHUT:
			var k := 1.0 - r / 80.0
			out.append({"k": M_NONE, "x": F.x, "y": F.y, "lc": 5, "lp": F, "lr": r * 1.15 + 6.0, "lk": 0.18 + 0.32 * k})
			out.append({"k": M_NONE, "x": F.x, "y": F.y, "lc": 6, "lp": F, "lr": r * 0.6 + 3.0, "lk": 0.25 * k})
		# light catches the iris as it turns: a glint runs once round the rim while it closes
		if t > 0.08 and t < SNAP:
			var a := -2.4 + ((t - 0.08) / (SNAP - 0.08)) * TAU
			var g := F + Vector2(cos(a), sin(a)) * (r + 1.0)
			if g.x > 2.0 and g.y > 2.0 and g.x < SW - 2.0 and g.y < SHH - 2.0:
				out.append(glint_m(g.x, g.y, 7.0 + 3.0 * sin(t * 9.0), t * 3.0, 6, 5, 0.9))
		var s := t - SHUT
		if s > -0.06 and s < 0.22:
			out.append(glint_m(F.x, F.y, 14.0 * (1.0 - absf(s + 0.01) / 0.23), s * 4.0, 6, 5))
		var u := t - POP
		if u >= 0.0 and u < 0.18:
			var gg: Variant = glint_m(F.x, F.y, 20.0 * (1.0 - u / 0.18), 0.4 - u * 3.0, 6, 5)
			out.append(gg)
			out.append({"k": M_NONE, "x": F.x, "y": F.y, "lc": 8, "lp": F, "lr": 60.0, "lk": 0.6 * (1.0 - u / 0.18)})
		rows.append(out)
	for n in [screen("Iris", "iris", {"focus": F}), screen("Light", "iris_light", {"focus": F})]:
		key(n, "material:shader_parameter/mode", km, "nearest")
		key(n, "material:shader_parameter/r", kr, "nearest")
		key(n, "material:shader_parameter/hot", kh, "nearest")
		key(n, "material:shader_parameter/rw", kw, "nearest")
	marks("Glints", rows)
	ghosts({"sparks": [Color.WHITE, C[6], C[5], C[4]]})
	var li := 0
	for l in lights:
		light_at("Flash%d" % li, l[0], l[1], l[2], l[3], l[4], l[5], clocks)
		li += 1
