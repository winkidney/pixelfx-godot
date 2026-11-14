# reimagined-from: src/fx/impacts/blunt-hit.js@f21317155d505cf1a7e923da26bff062a062edeb
# Blunt hit: A heavy, soft thud: a white-hot lumpy blob cools to cream in a warm pool of light, inked wedges jab out
# and snap back, a squashed ring of dust puffs swells and drifts, clods drop.
# The blob is a shader of its own (fx/impacts/_blob.gdshader: the original's lumpy outline) on its two frames; the
# wedges another (_wedges) that works out each jab from the effect's clock, keyed as a uniform. The ring of dust puffs,
# the clods (faceted rocks that bounce and settle) and the dust they kick up where they land are GPU particles from
# the original's own draws, moved by its physics (_sim.gdshader) and drawn as it draws them (_bits.gdshader).
extends "res://build/fx/impacts/_impacts.gd"


func make() -> void:
	var o: Dictionary = meta.options
	R = JsRng.new(int(o.seed))
	var X := 0.0
	var Y := -float(o.height)
	var D: float = meta.duration
	var W := Color.WHITE
	var PH := R.range(0, TAU)
	var WARM := Color(o.warm)
	var DUST := Color(o.dust)
	var st := stone(Color(o.clod))
	var wa := []
	var wt := []
	for i in 9:
		var a := (i / 9.0) * TAU + R.range(-0.2, 0.2)
		var ln := R.range(6, 15)
		var w := R.range(3.2, 5)
		var r0 := R.range(13, 16)
		var t0 := R.range(0.015, 0.04)
		var out := R.range(0.04, 0.06)
		var back := R.range(0.09, 0.14)
		wa.append(Vector4(a, ln, w, r0))
		wt.append(Vector4(t0, out, back, 0.0))
	# the squash ring: puffs flung out from the blob's rim, wider than tall; a few billow up off the top
	for i in 30:
		var a := (i / 30.0) * TAU + R.range(-0.12, 0.12)
		var side := absf(cos(a))
		var v := R.range(40, 140) * (0.6 + 0.5 * side)
		var r := R.range(2.4, 6.2) * (0.75 + 0.35 * side)
		var life := R.range(0.35, 0.85)
		var t0 := R.range(0.03, 0.1)
		var lift := R.range(4, 16)
		puff(X + cos(a) * 9, Y + sin(a) * 6, cos(a) * v, sin(a) * v * 0.5, r, life, t0, 4.5, lift, DUST, WARM, "front")
	for i in 5:
		var x0 := X + R.range(-6, 6)
		var y0 := Y - R.range(3, 6)
		var vx := R.range(-30, 30)
		var vy := -R.range(20, 45)
		var r := R.range(3.5, 5.5)
		var life := R.range(0.6, 0.85)
		var t0 := R.range(0.05, 0.1)
		puff(x0, y0, vx, vy, r, life, t0, 4.5, R.range(14, 24), DUST, WARM, "front")
	# clods knocked loose: they arc out, drop, bounce once and settle
	for i in 5:
		var s := R.sign()
		var a := -PI / 2 + s * R.range(0.5, 1.3)
		var v := R.range(70, 140)
		var x0 := X + s * R.range(4, 8)
		var y0 := Y + R.range(-3, 3)
		var life := R.range(0.65, 0.85)
		var a0 := R.range(0, TAU)
		var va := s * R.range(8, 16)
		var sz := 2.0 if R.chance(0.4) else 1.0
		var pts := []
		for j in 6:
			pts.append(R.range(0.7, 1.12))
		add_bit({"kind": CHUNK, "x": x0, "y": y0, "vx": cos(a) * v, "vy": sin(a) * v, "g": 1.0, "drag": 0.6, "bounce": 0.28,
			"life": life, "a": a0, "va": va, "s": sz, "pts": pts})
	# a clod hitting the floor kicks a little dust
	replay_bits(func(b: Dictionary, t: float, _pvy: float) -> void:
		for j in 2:
			var vx := R.sign() * R.range(8, 22)
			var vy := -R.range(3, 10)
			puff(b.x, -1, vx, vy, R.range(1.2, 2), 0.4, t, 4.0, 0.0, DUST, WARM, "front"))
	flush({"stone": st, "warm": {"k": 0.55, "t0": 0.03, "len": 0.25}})

	# the blob: white-hot and lumpy for a frame, then cream and a little bigger, then gone into the dust
	var u := "material:shader_parameter/"
	var blob := shape("Blob", sh("blob"), Vector2(44, 44), {"r0": 11.5, "sy": 1.1, "ph": PH, "look": 0.0, "white": W, "hi": C[5], "mid": C[4], "lo": C[3]},
		{"at": Vector2(X, Y)})
	steps(blob, u + "r0", [[0.0, 11.5], [0.025, 13.5]])
	steps(blob, u + "sy", [[0.0, 1.1], [0.025, 1.25]])
	steps(blob, u + "ph", [[0.0, PH], [0.025, PH + 0.6]])
	steps(blob, u + "look", [[0.0, 0.0], [0.025, 1.0]])
	show(blob, 0.0, 0.058)

	# the wedges jab out from the blob and snap back
	var wedges := shape("Wedges", sh("wedges"), Vector2(72, 72), {"wa": PackedVector4Array(wa), "wt": PackedVector4Array(wt), "count": 9.0,
		"ink": C[1], "white": W, "hi": C[5]}, {"at": Vector2(X, Y)})
	key(wedges, u + "t", [[0.0, 0.0], [0.25, 0.25]])
	show(wedges, 0.0, 0.25)

	# light: a warm pool, a white-hot heart, a glow on the floor, the pop
	glow_fn("Pop", Vector2(X, Y), 28, WARM, func(t: float) -> float: return 0.5 * exp(-t / 0.06) if exp(-t / 0.06) > 0.02 else 0.0, 0.0, 0.3)
	light_add("Light", Vector2(X, Y), 48, WARM, 0.6, 0.4)
	light_add("LightWhite", Vector2(X, Y), 16, W, 0.6, 0.07)
	light_add("LightFloor", Vector2(X, -2), 36, WARM, 0.25, 0.4)
