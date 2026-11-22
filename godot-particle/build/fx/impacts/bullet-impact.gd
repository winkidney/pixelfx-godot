# reimagined-from: src/fx/impacts/bullet-impact.js@88ac95432599715b51462367f11203cff207ea95
# Bullet impact: A bullet hits a wall on the right: a hot half-star, sparks sprayed back in a cone, a puff of grit,
# chips that fall and bounce, a pock mark cooling to soot.
# The half-star is the impacts' star shader (fx/impacts/_star.gdshader, the original's spikes rolled from its seed) on
# its two frames; the half ring opening off the wall a ring of dots (_dotring) keyed from the original's curve; the
# pock mark and its cracks are the original's cells, recoloured step by step as they cool. Sparks, chips, grit dust
# and the wisp of smoke are GPU particles from the original's draws, moved by its physics (_sim.gdshader).
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	var st := stone(Color(o.stone))
	R = JsRng.new(int(o.seed))
	var X := 0.0
	var Y := -float(o.height)
	var D: float = meta.duration
	var W := Color.WHITE
	var N := PI
	var B := PI - 0.08
	var sp := spikes(9, B, {"len": [7.0, 10.5], "w": [1.6, 2.1], "fwd": 1.8, "back": 0.4})
	for i in sp.size():
		if cos(sp[i].x - N) < -0.2:
			sp[i].y *= 0.3
	# the pock mark: a ragged hole and a rim
	var rim := [[], []]
	for y in range(-2, 3):
		for x in range(0, 4):
			var d := Vector2((x - 1) / 1.6, y / 2.1).length() + rand([x, y, int(o.seed)]) * 0.35
			if d < 0.75:
				rim[0].append(Vector2i(x, y))
			elif d < 1.25:
				rim[1].append(Vector2i(x, y))
	var cracks := []
	for i in 3:
		var a := R.range(-1.2, 1.2)
		var L := R.range(2, 4.5)
		cracks.append([Vector2(cos(a) * 2.2 + 1, sin(a) * 2.2), Vector2(cos(a) * (2.2 + L) + 1, sin(a) * (2.2 + L))])
	for i in 18:
		var a := B + R.range(-1, 1) * 0.8
		var v := R.range(170, 450)
		spawn(SPARK, X - 1, Y, cos(a) * v, sin(a) * v - 30, R.range(0.12, 0.4), W, 1, R.range(0.01, 0.04) if i > 13 else 0.0)
	for i in 8:
		var a := N + R.range(-0.8, 0.6)
		var v := R.range(60, 190)
		var y0 := Y + R.range(-1, 1)
		var vy := sin(a) * v - R.range(20, 70)
		var life := R.range(0.9, 1.3)
		spawn(GRIT, X - 1, y0, cos(a) * v, vy, life, R.pick([st.light, st.body, st.body, st.lip]), 2 if i < 3 else 1)
	for i in 9:
		var a := N + R.range(-1.1, 1.1)
		var v := R.range(15, 60)
		var y0 := Y + R.range(-1.5, 1.5)
		var life := R.range(0.3, 0.55)
		var c: Color = st.dust if R.chance(0.5) else mixc(st.dust, W, 0.25)
		spawn(DUST, X - 2, y0, cos(a) * v, sin(a) * v, life, c, R.range(1.2, 2.3))
	var svx := R.range(-10, -4)
	var svy := R.range(-16, -8)
	var sl := R.range(0.8, 1.2)
	spawn(SMOKE, X - 4, Y, svx, svy, sl, st.dust, R.range(1.8, 2.4), 0.05)

	var heat := func(t: float) -> float: return pow(clampf(1.0 - t / 0.9, 0.0, 1.0), 1.3)
	var fade := func(t: float) -> float: return 1.0 - smooth(D - 0.45, D - 0.1, t)
	# the pock mark's cracks, then its cells: white hot, cooling down the ramp to soot and a dark rim
	for c in [SOOT, W, C[5], C[4], C[3], C[2], st.shade]:
		keep_colour(c)
	var ci := 0
	for cr in cracks:
		var ln := cells("Crack%d" % ci, line_cells(Vector2(X, Y) + cr[0], Vector2(X, Y) + cr[1]), C[3])
		var crack_col := func(t: float) -> Color:
			var h: float = heat.call(t)
			return Color(C[3] if h > 0.5 else st.shade, fade.call(t) * (1.0 if h > 0.5 else 0.85))
		keyf(ln, "modulate", crack_col, 0.0, -1.0, 30.0, "nearest")
		ci += 1
	for k in 2:
		var px := []
		for c in rim[k]:
			px.append(Vector2i(c) + Vector2i(int(X), int(Y)))
		var node := cells("Pock%d" % k, px, W)
		var kk := k
		var pock_col := func(t: float) -> Color:
			var h: float = heat.call(t) * (0.85 if kk == 1 else 1.15)
			var c: Color = SOOT if (kk == 0 and h < 0.75) else W if h > 0.85 else C[5] if h > 0.6 else C[4] if h > 0.4 else C[3] if h > 0.22 else C[2] if h > 0.1 else st.shade
			return Color(c, fade.call(t))
		keyf(node, "modulate", pock_col, 0.0, -1.0, 30.0, "nearest")
	glow_fn("PockGlow", Vector2(X + 1, Y), 12, C[3], func(t: float) -> float: return 0.5 * heat.call(t) * fade.call(t),
		0.0, 0.95, func(t: float) -> float: return 6.0 + 6.0 * heat.call(t))

	# a half ring opening away from the wall
	var ring := dot_ring("HalfRing", Vector2(X, Y), 18, {"radius": 5.0, "dir": PI, "open": -0.25, "color": C[5]})
	keyf(ring, "material:shader_parameter/radius", func(t: float) -> float: return 5.0 + 12.0 * out_cubic((t - 0.03) / 0.18), 0.03, 0.21)
	keyf(ring, "material:shader_parameter/alpha", func(t: float) -> float: return 1.15 - (t - 0.03) / 0.18, 0.03, 0.21)
	var ring_col := func(t: float) -> Color:
		var u := (t - 0.03) / 0.18
		return C[5] if u < 0.3 else C[4] if u < 0.6 else C[3]
	keyf(ring, "material:shader_parameter/color", ring_col, 0.03, 0.21, 60.0, "nearest")
	show(ring, 0.03, 0.21)

	# sparks and chips over it; grit dust and the smoke (the original's back layer) behind
	flush({"sparks": [C[6], C[5], C[4], C[2]]})

	# the half-star on its two frames
	hit_star("Star", Vector2(X, Y), sp, 2.2, [[0.0, 1.0, 1.0, 1.0, [C[2], C[5], C[4], W]], [0.03, 1.25, 0.55, 1.0, [C[1], C[4], C[3], C[5]]], [0.06]])

	# light: the pop, light grazing the wall's face, the two lights
	var pop := func(k: float) -> Callable: return func(t: float) -> float: return k * exp(-t / 0.045) if exp(-t / 0.045) > 0.02 else 0.0
	glow_fn("Pop", Vector2(X - 2, Y), 22, C[3], pop.call(0.6), 0.0, 0.2)
	glow_fn("PopWhite", Vector2(X - 1, Y), 8, W, pop.call(0.5), 0.0, 0.2)
	glow_line("Graze", Vector2(X + 1, Y - 16), Vector2(X + 1, Y + 16), 4, C[4], pop.call(0.4), 0.0, 0.2)
	light_add("Light", Vector2(X - 4, Y), 40, C[4], 0.6, 0.22)
	light_add("LightWhite", Vector2(X - 2, Y), 14, W, 0.6, 0.06)
