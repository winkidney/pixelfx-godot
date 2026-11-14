# reimagined-from: src/fx/projectiles/arrow.js@943676edad93d3bea42e4d6f1eb2533e590b7ea2
# Arrow: An arrow in flight: a steel broadhead catching the light, a wooden shaft, fletching fluttering in the wind, streaks of air peeling off its head and swirling off its feathers.
# loop, 0.60 s, 112x32 canvas, origin [92.0, 16.0], backdrop sky
# The arrow is still and the air streams past (the original's frame). The arrow is a rigid body drawn at build time
# from the original's own pixel rows (shaft, binding, broadhead, and the fletching's three poses: a three-frame
# sprite whose pose is the original's pick each frame). The air is particles: streaks peeling off the head and the
# feathers (the projectiles' wake process shader with the original's own beat() draws, stretching back, cooling and
# thinning) and little eddies spinning off the feathers (an emitter of small arcs, spinning and fading). A glint
# runs down the blade twice a loop: the original's sparkle and its light, keyed.
extends "res://build/fx/projectiles/_projectiles.gd"

const LEN := 36
const HEAD := ["..LL....", "..sLLL..", "bbsSSSSW", "..dDDD..", "..DD...."]
const FLETCH := [
	["AAa.........", ".aAAa.......", "..aaAAa.....", "nkkkkkkkkkkk", "..cCCc......", ".cCCc.......", "CCc........."],
	[".AAa........", "..aAAa......", "..aaAAAa....", "nkkkkkkkkkkk", "..cCCCc.....", "..cCCc......", ".CCc........"],
	["AAAa........", "aAAa........", ".aaAAa......", "nkkkkkkkkkkk", "..ccCc......", "cCCc........", "CCc........."],
]


static func stamp(img: Image, rows: Array, pal_: Dictionary, x0: int, y0: int) -> void:
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			if pal_.has(row[i]):
				img.set_pixel(x0 + i, y0 + j, pal_[row[i]])


## Streaks moved by the wake process shader (fx/projectiles/_energy-disc_wake), drawn by _energy-disc_spark.
func wake_emitter(name: String, C: Array, amount: int, params: Dictionary, look: Dictionary = {}) -> void:
	var p := particles(name, {"amount": amount, "lifetime": root.duration, "local": true, "texture": "streak8"})
	var pm := ShaderMaterial.new()
	pm.shader = pshader("energy-disc_wake")
	for k in params:
		var v: Variant = params[k]
		pm.set_shader_parameter(k, float(v) if v is int else v)
	p.process_material = pm
	var m := ShaderMaterial.new()
	m.shader = pshader("energy-disc_spark")
	for i in 4:
		m.set_shader_parameter("s%d" % i, C[i])
		keep_colour(C[i])
	for k in look:
		m.set_shader_parameter(k, float(look[k]))
	p.material = m


func make() -> void:
	var PL := pal("palette")
	var W := pal("wood")
	var ST := pal("steel")
	var wind := Color(meta.options.wind)
	var S := int(meta.options.seed)
	var D: float = root.duration
	var left := -float(root.origin.x) + 2.0
	var dark := Color("#2a2540")

	# streaks of air peeling off the head and the fletching, stretching back and thinning (the original's
	# beat(t, D, 9, S) draws)
	var la := PackedVector4Array()
	var lb := PackedVector4Array()
	for i in 9:
		var life := rng([S, i, 911]).range(0.14, 0.26)
		var r := rng([S, i])
		var top := -1.0 if r.chance(0.5) else 1.0
		var from := -3.0 if r.chance(0.6) else -LEN + 6.0
		var sp := r.range(160, 240)
		var ln := r.range(8, 16)
		var y := 0.5 + top * (r.range(3, 5) + 0.5 * r.range(1, 2.5))
		la.append(Vector4(life, PI, sp, ln))
		lb.append(Vector4(from, y, 0.0, 0.0))
	wake_emitter("Air", [mixc(wind, Color.WHITE, 0.2), wind, mixc(wind, dark, 0.45), wind], 9, {"slots": 9.0, "slot_a": la, "slot_b": lb,
		"spawn_r": 0.0, "spawn_at": Vector2.ZERO, "mode": 1.0, "V": 0.0, "k": 0.0001, "len_range": Vector2(8, 16), "ahead": 1.0, "clip_x": left + 12.0},
		{"th0": 0.75, "th1": 0.4, "head_from": -1.0, "fade_tail": 1.0})

	# little eddies spinning off the feathers
	var arc := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	var k := 0
	for q in [Vector2i(4, 2), Vector2i(4, 3), Vector2i(3, 4), Vector2i(2, 4)]:
		arc.set_pixel(q.x, q.y, Color(1, 1, 1, 1.0 - k * 0.2))
		k += 1
	particles("Eddies", {"at": Vector2(-LEN - 2, 0.5), "amount": 6, "lifetime": 0.25, "life_random": 0.4, "texture": asset("eddy", arc),
		"emit": {"points": PackedVector2Array([Vector2(0, -2.2), Vector2(0, -3.6), Vector2(0, 2.2), Vector2(0, 3.6)])}, "dir": 180, "speed": [100, 150],
		"spin": [-1700, -1700], "angle": [0, 360], "scale_curve": [[0, 0.75], [1, 1.5]], "color": wind, "alpha_curve": [[0, 1], [1, 0]]})
	keep_colour(wind)

	# the arrow: shaft with a lit top line, fletching (three poses), binding and broadhead
	var img := Image.create(37 * 3, 7, false, Image.FORMAT_RGBA8)
	for f in 3:
		var ox := f * 37
		for x in range(-LEN + 11, -6):
			img.set_pixel(ox + x + LEN, 3, W[2])
		var x2 := -LEN + 14
		while x2 < -8:
			img.set_pixel(ox + x2 + LEN, 3, W[3])
			x2 += 6
		stamp(img, FLETCH[f], {"a": PL[2], "A": PL[3], "c": PL[0], "C": PL[1], "k": W[1], "n": W[0]}, ox, 0)
		stamp(img, HEAD, {"L": ST[3], "s": ST[2], "S": ST[2], "d": ST[0], "D": ST[1], "b": W[0], "W": Color.WHITE}, ox + LEN - 7, 1)
	var body := sprite("Arrow", asset("arrow", img), {"layer": "prop", "centered": false, "offset": Vector2(-LEN, -3), "hframes": 3})
	keyf(body, "frame", func(t: float) -> int: return floori(jrand([floori(t * 30.0 + 1e-6), S]) * 3.0), 0.0, D - 1.0 / 30.0, 30.0, "nearest")

	# a glint runs down the blade now and then
	var arm := func(t: float) -> float:
		var g := fposmod(t / D * 2.0 + 1e-6, 1.0)
		return 1.0 + roundf(2.0 * sin(g / 0.25 * PI)) if g < 0.25 else 0.0
	var gpos := func(t: float) -> Vector2:
		var g := fposmod(t / D * 2.0 + 1e-6, 1.0)
		return Vector2(floorf(-5.0 + g * 16.0) + 0.5, -0.5)
	var glint := sparkle("Glint", Vector2(-5, -1), 0, Color.WHITE, ST[3])
	keyf(glint, "position", gpos, 0.0, D, 30.0, "nearest")
	keyf(glint, "material:shader_parameter/arm", arm, 0.0, D, 30.0, "nearest")
	var gl := light_at("GlintLight", Vector2(-5, -1), 10, Color.WHITE, 0.0)
	keyf(gl, "position", gpos, 0.0, D, 30.0, "nearest")
	keyf(gl, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * maxf(1.0, arm.call(t)), 0.0, D, 30.0, "nearest")
	keyf(gl, "material:shader_parameter/alpha", func(t: float) -> float: return 0.25 if arm.call(t) >= 1.0 else 0.0, 0.0, D, 30.0, "nearest")
