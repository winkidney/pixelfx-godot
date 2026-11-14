# reimagined-from: src/fx/impacts/impact-frame.js@4cd616d4d3cc442da4ce3cf3c591ca6567e83cb7
# Impact frame: An anime impact: two frames of white with black burst lines rushing at the hit, two frames inverted,
# then the lines pull out past the edges and vanish.
# One screen shader (fx/impacts/_impact_frame.gdshader): the original's two sets of burst lines (rolled from its seed),
# the jagged star at the hit and the inversion, stepped through its eight frames by a keyed `frame` uniform.
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	R = JsRng.new(int(o.seed))
	var n: int = int(o.lines)
	var lines := []
	for s in 2:
		for i in n:
			var thick := R.chance(0.18)
			var a := ((i + R.range(0.1, 0.9)) / n) * TAU
			var inner := R.range(30, 48) if thick else R.range(18, 70)
			lines.append(Vector4(a, inner, R.range(5, 8) if thick else R.range(1.2, 3.6), 0.0))
	var jit := []
	for s in 2:
		var jx := floorf(R.range(-2, 2) + 0.5)
		jit.append(Vector2(jx, floorf(R.range(-1, 1) + 0.5)))
	var ph := []
	for i in 4:
		ph.append(R.range(0, TAU))
	var sz := Vector2(root.canvas_size)
	var scr := shape("Frame", sh("impact_frame"), sz, {"lines": PackedVector4Array(lines), "per_set": float(n), "jit": PackedVector2Array(jit),
		"ph": PackedFloat32Array(ph), "frame": 0.0, "ink": C[0], "paper": C[1]}, {"at": sz / 2.0 - Vector2(root.origin)})
	var ks := []
	for f in 9:
		ks.append([f / 30.0, float(f)])
	steps(scr, "material:shader_parameter/frame", ks)
	show(scr, 0.0, 8 / 30.0)
