# reimagined-from: src/fx/impacts/hit-spark.js@970f6a183cf1f0c4c46415b634f283ffe71469db
# Hit spark: The everyday hit: a sharp, lopsided cross flare with one long ray along the blow round a white diamond
# core, then a cone of sparks and hot chips that fall and bounce.
# The cross is a shader of its own (fx/impacts/_rays.gdshader: the original's tapered rays and diamond) stepped through
# its three looks on the original's beats (0.025, 0.058, 0.092 s); the pop of light and the three lights are glows
# keyed from the original's curves. Sparks and chips are GPU particles rolled from the original's own seeded draws and
# moved by its physics (fx/impacts/_sim.gdshader: drag, half gravity, a floor they skip off; chips tick and stop).
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	R = JsRng.new(int(o.seed))
	var X := 0.0
	var Y := -float(o.height)
	var A: float = o.aim
	var W := Color.WHITE
	var tilt := R.range(-0.08, 0.08)
	var rays := [
		Vector4(A + tilt, R.range(33, 37), 2.2, 0.0),
		Vector4(A + PI + tilt, R.range(8, 10), 2.2, 0.0),
		Vector4(A - PI / 2 + tilt, R.range(15, 18), 2.6, 0.0),
		Vector4(A + PI / 2 + tilt, R.range(10, 12), 2.3, 0.0),
		Vector4(A - PI / 4 + tilt, R.range(5, 7), 1.0, 0.0),
	]
	for i in 9:
		var a := A + R.range(-0.6, 0.6) - 0.15
		var v := R.range(170, 360)
		spawn(SPARK, X + 1, Y, cos(a) * v, sin(a) * v - 40, R.range(0.25, 0.45), W, 1, R.range(0.01, 0.03) if i > 6 else 0.0)
	for i in 6:
		var a := A + R.range(-1.1, 0.5) - 0.3
		var v := R.range(70, 170)
		spawn(GRIT, X + 1, Y, cos(a) * v, sin(a) * v - R.range(30, 80), R.range(0.35, 0.45), R.pick([C[5], C[4], C[4], C[3]]), 1)
	flush({"sparks": [C[6], C[5], C[4], C[2]]})

	# the cross: whole, then reaching further and thinner off the root, then only the long ray burning away
	var reach := 37.0 * 1.3 + 4.0
	var e := ceilf(reach + 2) * 2
	var cross := shape("Cross", sh("rays"), Vector2(e, e), {"rays": PackedVector4Array(rays + [Vector4.ZERO, Vector4.ZERO, Vector4.ZERO]),
		"count": 5.0, "c_white": W, "c_hi": C[5], "c_mid": C[4], "c_lo": C[3], "side_hi": C[5], "side_lo": C[4], "diamond": 4.0, "rim": C[3]},
		{"at": Vector2(X, Y)})
	var u := "material:shader_parameter/"
	steps(cross, u + "scale_len", [[0.0, 1.0], [0.025, 1.2], [0.058, 1.3]])
	steps(cross, u + "scale_w", [[0.0, 1.0], [0.025, 0.55]])
	steps(cross, u + "w_fixed", [[0.0, 0.0], [0.058, 0.6]])
	steps(cross, u + "from", [[0.0, 0.0], [0.025, 0.12], [0.058, 0.4]])
	steps(cross, u + "diamond", [[0.0, 4.0], [0.025, 3.0], [0.058, -1.0]])
	steps(cross, u + "first", [[0.0, 0.0], [0.058, 1.0]])
	steps(cross, u + "c_hi", [[0.0, C[5]], [0.058, C[4]]])
	steps(cross, u + "c_mid", [[0.0, C[4]], [0.058, C[3]]])
	steps(cross, u + "c_lo", [[0.0, C[3]], [0.058, C[3]]])
	show(cross, 0.0, 0.092)

	# light: the pop (two glows and a beam along the blow) and the three lights
	var pop := func(k: float) -> Callable: return func(t: float) -> float: return k * exp(-t / 0.045) if exp(-t / 0.045) > 0.02 else 0.0
	glow_fn("Pop", Vector2(X, Y), 22, C[4], pop.call(0.3), 0.0, 0.2)
	glow_fn("PopWhite", Vector2(X, Y), 7, W, pop.call(0.15), 0.0, 0.2)
	glow_line("PopBeam", Vector2(X, Y), Vector2(X + cos(A) * 26, Y + sin(A) * 26), 4, C[5], pop.call(0.25), 0.0, 0.2)
	light_add("Light", Vector2(X, Y), 38, C[4], 0.35, 0.18)
	light_add("LightFwd", Vector2(X + cos(A) * 10, Y + sin(A) * 10), 22, C[5], 0.45, 0.1)
	light_add("LightFloor", Vector2(X, -2), 26, C[3], 0.22, 0.22)
