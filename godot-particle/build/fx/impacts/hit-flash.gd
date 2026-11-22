# reimagined-from: src/fx/impacts/hit-flash.js@60531d91ee66d5bafa9d0850a62c7244fde7628f
# Hit flash: The character takes damage: a white frame, then their own colors flushed red and blinking white, cooling
# off, while comic hit lines jab in at them.
# The stand-in's flash is a shader over its own pixels (fx/impacts/_body.gdshader: white, its shading carried into the
# red ramp, a white rim, a red wash cooling off, with the outline) stepped on the original's beats; the comic lines
# are wedges worked out from the effect's clock (_jabs); the blow is the original's little burst of lines on its two
# frames; the lights are glows keyed from its curves.
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	R = JsRng.new(int(o.seed))
	var W := Color.WHITE
	var S: float = o.side
	var tex: Texture2D = load(EFFECT.STAND_INS[root.actor])
	var tw := tex.get_width()
	var thh := tex.get_height()
	var cx := 0.0
	var cy := -26.0
	var hx := cx + S * 12
	var hy := cy - 5
	var jabs := []
	var n: int = int(o.lines)
	for i in n:
		var a := -PI - 0.3 + ((i + R.range(0.25, 0.75)) / n) * (PI + 0.6)
		var d := R.range(15, 19)
		var ln := R.range(6, 9)
		jabs.append(Vector4(a, d, ln, R.range(0, 0.04)))
	var U := "material:shader_parameter/"

	# the body: white, white, red, red, a white rim, red cooling off
	var body := shape("Body", sh("body"), Vector2(tw + 2, thh + 2), {"tex": tex, "look": 1.0, "cool": 0.0, "reds": Array(C), "wash": C[4],
		"outline_c": C[6], "outline_a": 1.0}, {"at": Vector2(-floorf(tw / 2.0) + tw / 2.0, -thh / 2.0)})
	steps(body, U + "look", [[0.0, 1.0], [0.058, 2.0], [0.125, 0.0], [0.158, 3.0], [0.36, 0.0]])
	steps(body, U + "outline_c", [[0.0, C[6]], [0.025, C[5]], [0.125, W], [0.158, C[4]]])
	var cool := func(t: float) -> float: return clampf(1.0 - (t - 0.158) / (0.36 - 0.158), 0.0, 1.0)
	keyf(body, U + "cool", cool, 0.158, 0.36)
	keyf(body, U + "outline_a", func(t: float) -> float: return 1.0 if t < 0.158 else (maxf(0.0, (cool.call(t) - 0.5) * 2.0) if t < 0.36 else 0.0), 0.0, 0.37)
	show(body, 0.0, 0.36)

	# the blow: a small hot burst on the side it came from, two frames
	for f in 2:
		var list := []
		var big := 1.0 if f == 0 else 1.3
		for i in 8:
			var a := (i / 8.0) * TAU + 0.2
			var L := (4.0 if i % 2 else 9.0) * big
			var p0 := Vector2(hx + cos(a) * L * 0.45 * f, hy + sin(a) * L * 0.45 * f)
			var lc := line_cells(p0, Vector2(hx + cos(a) * L, hy + sin(a) * L))
			for j in lc.size():
				var u := j / float(maxi(1, lc.size() - 1))
				list.append([Vector2(lc[j]), W if (u < 0.45 and f == 0) else C[6] if u < 0.75 else C[4], 1.0])
		if f == 0:
			for d in [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				list.append([Vector2(hx, hy) + d, W, 1.0])
		var b := dots("Blow%d" % f, list)
		show(b, 0.0 if f == 0 else 0.035, 0.035 if f == 0 else 0.07)
	glow_fn("BlowLight", Vector2(hx, hy), 14, C[6], func(t: float) -> float: return 0.5 * (1.0 - t / 0.07) if t < 0.07 else 0.0, 0.0, 0.08)

	# comic hit lines jab in toward the body, then are gone
	var jb := shape("Jabs", sh("jabs"), Vector2(80, 64), {"jabs": PackedVector4Array(jabs), "count": float(n), "ink": C[3], "white": W, "late": C[6]},
		{"at": Vector2(cx, cy)})
	clock(jb, 0.0, 0.22)
	show(jb, 0.0, 0.22)

	var k := func(t: float) -> float: return 0.35 * exp(-t / 0.08) if exp(-t / 0.08) > 0.02 else 0.0
	glow_fn("FlushWhite", Vector2(cx, cy), 26, W, func(t: float) -> float: return k.call(t) if t < 0.05 else 0.0, 0.0, 0.07, null)
	glow_fn("Flush", Vector2(cx, cy), 26, C[5], func(t: float) -> float: return k.call(t) if t >= 0.05 else 0.0, 0.0, 0.34)
	light_add("BlowFlash", Vector2(hx, hy), 34, W, 0.6, 0.1)
	light_add("Light", Vector2(cx, cy), 30, C[4], 0.5, 0.35)
