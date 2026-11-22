# reimagined-from: src/fx/impacts/crit-hit.js@53c1bff8401b3348561b9b158044370c45e82d0c
# Critical hit: A critical hit: a jagged starburst slams in white and overshoots, a ring breaks into flying arcs, sparks
# streak off, shards tumble to the floor under a big flare.
# The starburst is the impacts' star shader (fx/impacts/_star.gdshader) stepped through the original's four key frames;
# the ring a shader that breaks into arcs (_bring) and the lens flare one of its own (_flare), both keyed from the
# original's curves at 60 Hz with their light (glow ring, glow lines, glows). Sparks, motes, glints and the tumbling
# shards are GPU particles from the original's own draws, moved by its physics (_sim.gdshader).
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	R = JsRng.new(int(o.seed))
	var X := 0.0
	var Y := -float(o.height)
	var A: float = o.aim
	var W := Color.WHITE
	var sp := spikes(14, A, {"len": [11.0, 15.0], "w": [1.8, 2.5], "fwd": 1.4, "back": 0.6, "jag": 0.5})
	var order := range(sp.size())
	order.sort_custom(func(a: int, b: int) -> bool: return sp[a].y > sp[b].y)
	for j in 2:
		sp[order[j]].y *= 1.3
	var segs := []
	for i in 7:
		var a := A + (i / 7.0) * TAU
		var gap := R.range(0.55, 0.85)
		var dr := R.range(0.08, 0.4) + 0.15 * maxf(0.0, cos(a - A))
		segs.append(Vector4(a, gap, dr, 0.7 + 0.5 * maxf(0.0, cos(a - A))))
	for i in 36:
		var back := R.chance(0.22)
		var a := (A + PI if back else A) + R.range(-1, 1) * (0.6 if back else 0.8)
		var v := R.range(170, 430) * (0.6 if back else 1.0)
		var life := R.range(0.15, 0.5)
		spawn(SPARK, X, Y, cos(a) * v, sin(a) * v - 50, life, W, 1, R.range(0, 0.04) if R.chance(0.3) else 0.0)
	for i in 10:
		var a := A + R.range(-1, 1) * 1.1 - 0.35
		var v := R.range(110, 280)
		var life := R.range(0.55, 0.85)
		var a0 := R.range(0, TAU)
		var va := R.range(-25, 25)
		var s := R.range(2, 4.5)
		add_bit({"kind": SHARD, "x": X, "y": Y, "vx": cos(a) * v, "vy": sin(a) * v - 40, "g": 0.8, "drag": 0.7, "bounce": 0.35,
			"life": life, "a": a0, "va": va, "s": s, "c": R.pick([C[7], C[6], C[6], C[5]])})
	for i in 12:
		var a := A - PI / 2 + R.range(-1.4, 1.4)
		var v := R.range(35, 110)
		spawn(MOTE, X + cos(a) * 4, Y + sin(a) * 4, cos(a) * v, sin(a) * v - 15, R.range(0.35, 0.7), R.pick([C[6], C[5], C[5]]), 0.6, R.range(0, 0.05))
	for i in 5:
		var a := R.range(0, TAU)
		var d := R.range(14, 34)
		var life := R.range(0.22, 0.38)
		var c: Color = C[6] if R.chance(0.5) else W
		spawn(STAR, X + cos(a) * d, Y + sin(a) * d * 0.8, 0, -4, life, c, R.range(1.6, 3), R.range(0.08, 0.32))

	# the ring swells off the star, then breaks into arcs that fly on and cool
	var u := "material:shader_parameter/"
	var uu := func(t: float) -> float: return clampf((t - 0.03) / 0.37, 0.0, 1.0)
	var ring := broken_ring("Ring", Vector2(X, Y), segs, 40 * 1.6 + 4, {"radius": 10.0, "th": 3.6, "brk": 0.0, "max_y": 0.0, "color": C[7], "color2": C[5]})
	keyf(ring, u + "radius", func(t: float) -> float: return 10.0 + 30.0 * out_cubic(uu.call(t)), 0.03, 0.4)
	keyf(ring, u + "brk", func(t: float) -> float: return smooth(0.12, 0.6, uu.call(t)), 0.03, 0.4)
	keyf(ring, u + "th", func(t: float) -> float: return maxf(1.0, 3.6 * pow(1.0 - uu.call(t), 1.2)), 0.03, 0.4)
	keyf(ring, u + "alpha", func(t: float) -> float: return 1.0 if uu.call(t) < 0.6 else (1.0 - uu.call(t)) / 0.4, 0.03, 0.4)
	var ci := func(t: float) -> int:
		var v: float = uu.call(t)
		return 7 if v < 0.12 else 6 if v < 0.3 else 5 if v < 0.5 else 4 if v < 0.75 else 3
	keyf(ring, u + "color", func(t: float) -> Color: return C[ci.call(t)], 0.03, 0.4, 60.0, "nearest")
	keyf(ring, u + "color2", func(t: float) -> Color: return C[maxi(2, ci.call(t) - 2)], 0.03, 0.4, 60.0, "nearest")
	show(ring, 0.03, 0.4)
	glow_ring("RingLight", Vector2(X, Y), 40, 6, C[5], func(t: float) -> float: return 10.0 + 30.0 * out_cubic(uu.call(t)),
		func(t: float) -> float: return 0.35 * pow(1.0 - uu.call(t) / 0.6, 2.0) if (t >= 0.03 and uu.call(t) < 0.6) else 0.0, 0.0, 0.4)

	# shards, sparks, motes and glints
	flush({"sparks": [C[7], C[6], C[5], C[3]]})

	# the flare blooms as the star collapses
	var ff := func(t: float) -> float: return (t - 0.04) / 0.28
	var fl := shape("Flare", sh("flare"), Vector2(134, 64), {"len": 64.0, "k": 1.0, "white": W, "hi": C[6], "lo": C[5]}, {"at": Vector2(X, Y) + Vector2(0.0, 0.0)})
	keyf(fl, u + "len", func(t: float) -> float: return 64.0 * pow(1.0 - clampf(ff.call(t), 0.0, 1.0), 1.3), 0.04, 0.32)
	keyf(fl, u + "k", func(t: float) -> float: return 1.0 - clampf(ff.call(t), 0.0, 1.0), 0.04, 0.32)
	show(fl, 0.041, 0.32)
	var flk := func(t: float) -> float: return 1.0 - ff.call(t) if (ff.call(t) > 0.0 and ff.call(t) < 1.0) else 0.0
	glow_fn("FlareGlow", Vector2(X, Y), 56, C[5], func(t: float) -> float: return 0.4 * flk.call(t), 0.0, 0.33)
	var beam := glow_path("FlareBeam", Vector2(X - 64, Y), Vector2(X + 64, Y), 6, C[6])
	keyf(beam, u + "a", func(t: float) -> Vector2: return Vector2(X - 64.0 * pow(1.0 - clampf(ff.call(t), 0.0, 1.0), 1.3), Y), 0.04, 0.32)
	keyf(beam, u + "b", func(t: float) -> Vector2: return Vector2(X + 64.0 * pow(1.0 - clampf(ff.call(t), 0.0, 1.0), 1.3), Y), 0.04, 0.32)
	keyf(beam, u + "k", func(t: float) -> float: return 0.5 * flk.call(t), 0.0, 0.33)
	var post := glow_path("FlarePost", Vector2(X, Y - 29), Vector2(X, Y + 29), 4, C[6])
	keyf(post, u + "a", func(t: float) -> Vector2: return Vector2(X, Y - 64.0 * 0.45 * pow(1.0 - clampf(ff.call(t), 0.0, 1.0), 1.3)), 0.04, 0.32)
	keyf(post, u + "b", func(t: float) -> Vector2: return Vector2(X, Y + 64.0 * 0.45 * pow(1.0 - clampf(ff.call(t), 0.0, 1.0), 1.3)), 0.04, 0.32)
	keyf(post, u + "k", func(t: float) -> float: return 0.3 * flk.call(t), 0.0, 0.33)

	# the starburst: a white frame, an overshoot, a settle, then it breaks up
	var cols := func(ix: Array) -> Array: return ix.map(func(j: int) -> Color: return C[j])
	hit_star("Star", Vector2(X, Y), sp, 2.6, [[0.0, 1.0, 1.0, 1.0, cols.call([6, 7, 7, 7])], [0.025, 1.3, 1.0, 1.0, cols.call([2, 5, 6, 7])],
		[0.058, 1.05, 0.72, 1.0, cols.call([2, 4, 5, 6])], [0.092, 1.22, 0.3, 1.0, cols.call([1, 2, 3, 4])], [0.125]])

	# light: the pop and the three lights
	var pop := func(k: float) -> Callable: return func(t: float) -> float: return k * exp(-t / 0.05) if exp(-t / 0.05) > 0.02 else 0.0
	glow_fn("Pop", Vector2(X, Y), 44, C[5], pop.call(0.4), 0.0, 0.25)
	glow_fn("PopWhite", Vector2(X, Y), 12, W, pop.call(0.6), 0.0, 0.25)
	light_add("Light", Vector2(X, Y), 84, C[5], 0.6, 0.5)
	light_add("LightWhite", Vector2(X, Y), 30, W, 0.7, 0.1)
	light_add("LightFloor", Vector2(X, -4), 44, C[4], 0.3, 0.45)
