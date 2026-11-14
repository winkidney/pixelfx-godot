# reimagined-from: src/fx/impacts/parry.js@4c9960eb8015112b20dd8118240c9920c8300b15
# Parry: Two blades clash: their edges flash in an X, a white four-point star rings out, a ring breaks into arcs and a
# fan of gold sparks sprays up and rains down.
# The four-point star is the impacts' star shader (fx/impacts/_star.gdshader) on the original's three frames; the ring
# breaking into arcs is _bring keyed from the original's curve with its glow; the two blade edges are the original's
# dots on its two frames, with light along them. The fan of sparks, motes and glints are GPU particles from the
# original's own draws, thrown up and raining down on its physics (_sim.gdshader: they skip off the floor).
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	R = JsRng.new(int(o.seed))
	var X := 0.0
	var Y := -float(o.height)
	var W := Color.WHITE
	var sp := []
	for i in 8:
		var a := i * PI / 4 + R.range(-0.04, 0.04)
		var L := R.range(6, 8) if i % 2 else (R.range(19, 22) if i % 4 == 0 else R.range(14, 17))
		sp.append(Vector4(a, L, 1.2 if i % 2 else 2.2, 0.0))
	var segs := []
	for i in 6:
		var a := (i / 6.0) * TAU + R.range(-0.1, 0.1)
		var gap := R.range(0.55, 0.8)
		segs.append(Vector4(a, gap, R.range(0.1, 0.35), 1.0))
	var edges := [-0.62 + R.range(-0.08, 0.08), PI + 0.62 + R.range(-0.08, 0.08)]
	for i in 24:
		var s := 1.0 if i % 2 else -1.0
		var a := -PI / 2 + s * R.range(0.3, 1.3)
		var v := R.range(130, 290)
		var x0 := X + s * R.range(1, 3)
		var life := R.range(0.45, 0.85)
		spawn(SPARK, x0, Y, cos(a) * v, sin(a) * v, life, W, 1, R.range(0.02, 0.07) if i > 17 else 0.0)
	for i in 8:
		var a := R.range(0, TAU)
		var v := R.range(40, 110)
		var life := R.range(0.3, 0.55)
		spawn(MOTE, X, Y, cos(a) * v, sin(a) * v - 20, life, R.pick([C[5], C[6]]), 0.6, R.range(0, 0.04))
	for i in 3:
		var a := R.range(0, TAU)
		var d := R.range(12, 26)
		var life := R.range(0.22, 0.34)
		spawn(STAR, X + cos(a) * d, Y + sin(a) * d, 0, -3, life, W, R.range(1.6, 2.6), R.range(0.1, 0.3))

	# the ring rings out off the star and breaks into arcs that fly on and cool
	var u := "material:shader_parameter/"
	var uu := func(t: float) -> float: return clampf((t - 0.03) / 0.36, 0.0, 1.0)
	var ring := broken_ring("Ring", Vector2(X, Y), segs, 32 * 1.4 + 4, {"radius": 8.0, "th": 2.6, "brk": 0.0, "max_y": 0.0, "color": C[6], "color2": C[4]})
	keyf(ring, u + "radius", func(t: float) -> float: return 8.0 + 24.0 * out_cubic(uu.call(t)), 0.03, 0.39)
	keyf(ring, u + "brk", func(t: float) -> float: return smooth(0.15, 0.6, uu.call(t)), 0.03, 0.39)
	keyf(ring, u + "th", func(t: float) -> float: return maxf(1.0, 2.6 * pow(1.0 - uu.call(t), 1.2)), 0.03, 0.39)
	keyf(ring, u + "alpha", func(t: float) -> float: return 1.0 if uu.call(t) < 0.6 else (1.0 - uu.call(t)) / 0.4, 0.03, 0.39)
	var ci := func(t: float) -> int:
		var v: float = uu.call(t)
		return 6 if v < 0.15 else 5 if v < 0.35 else 4 if v < 0.6 else 3
	keyf(ring, u + "color", func(t: float) -> Color: return C[ci.call(t)], 0.03, 0.39, 60.0, "nearest")
	keyf(ring, u + "color2", func(t: float) -> Color: return C[maxi(2, ci.call(t) - 2)], 0.03, 0.39, 60.0, "nearest")
	show(ring, 0.03, 0.39)
	glow_ring("RingLight", Vector2(X, Y), 32, 5, C[4], func(t: float) -> float: return 8.0 + 24.0 * out_cubic(uu.call(t)),
		func(t: float) -> float: return 0.3 * (1.0 - uu.call(t) / 0.5) if (t >= 0.03 and uu.call(t) < 0.5) else 0.0, 0.0, 0.4)

	flush({"sparks": [C[4], C[4], C[3], C[2]]})

	# the edges flash where they met: two frames of dots in an X, light along them
	for f in 2:
		var L := 26.0 if f == 0 else 32.0
		var k := 1.0 if f == 0 else 0.6
		var list := []
		for a in edges:
			var d := -L
			while d <= L:
				var q := absf(d) / L
				list.append([Vector2(X + cos(a) * d, Y + sin(a) * d), W if q < 0.4 else C[5] if q < 0.75 else C[4], 1.0 if q < 0.6 else k * (1.3 - q)])
				d += 0.5
		var e := dots("Edges%d" % f, list)
		show(e, 0.0 if f == 0 else 0.025, 0.025 if f == 0 else 0.058)
		var ei := 0
		for a in edges:
			var kk := k
			var t0 := 0.0 if f == 0 else 0.025
			var t1 := 0.025 if f == 0 else 0.058
			glow_line("EdgeLight%d%d" % [f, ei], Vector2(X - cos(a) * L, Y - sin(a) * L), Vector2(X + cos(a) * L, Y + sin(a) * L), 4, C[5],
				func(t: float) -> float: return 0.35 * kk if (t >= t0 and t < t1) else 0.0, 0.0, 0.07)
			ei += 1

	# the star: white, then bigger and gold as it thins, then just a glint
	var star := hit_star("Star", Vector2(X, Y), sp, 2.6, [[0.0, 1.0, 1.0, 1.0, [C[4], W, W, W]], [0.025, 1.25, 0.65, 1.0, [C[2], C[5], C[6], W]],
		[0.058, 1.4, 0.3, 1.0, [C[2], C[4], C[5], C[6]]], [0.092]])
	steps(star, u + "heart", [[0.0, 2.6], [0.058, 2.0]])

	var pop := func(k: float) -> Callable: return func(t: float) -> float: return k * exp(-t / 0.05) if exp(-t / 0.05) > 0.02 else 0.0
	glow_fn("Pop", Vector2(X, Y), 30, C[4], pop.call(0.5), 0.0, 0.25)
	glow_fn("PopWhite", Vector2(X, Y), 10, W, pop.call(0.4), 0.0, 0.25)
	light_add("Light", Vector2(X, Y), 60, C[4], 0.65, 0.4)
	light_add("LightWhite", Vector2(X, Y), 22, W, 0.8, 0.08)
