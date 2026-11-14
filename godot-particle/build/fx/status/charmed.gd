# reimagined-from: src/fx/status/charmed.js@4b49304cc5da9538e1adfbf880d20c04e9a8e975
# Charmed: Smitten: a big heart beats over the head, throwing a ring and a flush of light with every beat, little hearts float up, the eyes go pink and the cheeks blush.
# loop, 2.40 s, 60x76 canvas, origin [30.0, 68.0], backdrop ground, stand-in 2
# ramp palette: #3a0a1e #7a1238 #c4245a #f04e86 #ff8ab0 #ffc8da #ffffff
# The big heart and the rings it throws are a shader (fx/status/_charmed_heart.gdshader: the original's shaded,
# outlined heart icon at a keyed scale, or the ring between two hearts) beating on the original's lub-dub; its
# light and a back flush swell with each beat, a sparkle flares off it on the lub. Little hearts (icon sprites, a
# third of them behind the stand-in) replay the original's cycle up and away, swaying, and pop into sparkles.
# Twinkles wink round the big heart (an emitter with a light twin). The eyes go pink and the cheeks blush (a still
# mark over the stand-in).
extends "res://build/fx/status/_status.gd"

const HEART5 := [".#.#.", "#####", "#####", ".###.", "..#.."]
const HEART7 := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const LIGHT_Z := 5

var D := 2.4
var BEAT := 1.2


## a heartbeat: a strong lub and a softer dub
static func thump(ph: float) -> float:
	return exp(-pow((ph - 0.04) / 0.07, 2.0)) + 0.6 * exp(-pow((ph - 0.26) / 0.07, 2.0))


func make() -> void:
	D = root.duration
	BEAT = D / 2.0
	var C := fit("palette", 7)
	var seed_: int = int(meta.options.seed)
	var hx := 0.0
	var hy := AY - 10.0
	var ph_of := func(t: float) -> float: return fposmod(t, BEAT)

	# behind: a flush of light swelling with each beat
	var flush := glow("Flush", 36, {"radius": 26, "color": C[3], "alpha": 0.16}, {"at": Vector2(0, AY - 8), "back": true})
	flush.z_index = LIGHT_Z
	sample(flush, "material:shader_parameter/radius", func(t: float) -> float: return 26.0 + 8.0 * thump(ph_of.call(t)), "linear")
	sample(flush, "material:shader_parameter/alpha", func(t: float) -> float: return 0.16 + 0.22 * thump(ph_of.call(t)), "linear")

	# lovestruck: pink eyes with a bright catchlight, flushed cheeks
	var face := {}
	for e in eyes():
		for q in e.px:
			face[Vector2i(AX + q.x, AY + q.y)] = C[3] if q.y == e.y0 else C[2]
		face[Vector2i(AX + e.x0, AY + e.y0 + 1)] = C[6]
		var blush: Color = (e.skin as Color).lerp(C[3], 0.55)
		var bx: int = e.x0 - 1 if e.x0 < AW / 2.0 else e.x1
		face[Vector2i(AX + bx, AY + e.y1 + 1)] = blush
		face[Vector2i(AX + bx + 1, AY + e.y1 + 1)] = blush
	pixels("Face", face, {"layer": "prop"})

	# little hearts drifting up (every third behind the stand-in), each from the original's cycle
	var little := []
	var R_back := [C[0], C[1], C[2], C[3]]
	var R_front := [C[0], C[2], C[3], C[4]]
	for i in 12:
		var back := i % 3 == 0
		var r := rng([seed_ + 4, i])
		r.next()
		r.range(0, TAU)
		var big := r.next() < 0.3
		var img := icon_image(bitmap(HEART7 if big else HEART5), 4, R_back if back else R_front)
		var n := {"back": back, "big": big}
		n.icon = icon_sprite("Heart%d" % i, img, {"back": back, "file": "_heart%d" % i})
		if not back:
			n.shine = pixels("HeartShine%d" % i, {Vector2i(0, 0): C[6]})
		n.light = glow("HeartLight%d" % i, 8, {"radius": 6, "color": C[3], "alpha": 0.0})
		n.light.z_index = LIGHT_Z
		n.pop = sparkle("HeartPop%d" % i, {"color": C[5], "tip": C[4], "back": back})
		n.pop[1].z_index = LIGHT_Z
		n.K = {"v": [], "p": [], "a": [], "sv": [], "sp": [], "lp": [], "la": [], "pop": []}
		little.append(n)
	for t in frame_times():
		var alive := {}
		cycle(t, D, 12, seed_ + 4, func(g: Rng) -> float: return g.range(1.3, 1.9), func(age: float, life: float, r: Rng, i: int) -> void:
			var n: Dictionary = little[i]
			var K: Dictionary = n.K
			var u := age / life
			var side := -1.0 if r.next() < 0.5 else 1.0
			var ph := r.range(0, TAU)
			var big := r.next() < 0.3
			var x := side * r.range(4, 15) + sin(age * 4.0 + ph) * 2.2
			var y := AY + r.range(8, 30) - age * r.range(14, 22)
			var k := minf(1.0, u * 6.0)
			alive[i] = true
			if u > 0.88:
				var q := (u - 0.88) / 0.12
				K.v.append([t, false])
				K.sv.append([t, false])
				K.la.append([t, 0.0])
				K.pop.append([t, Vector2(x, y), jround(2.0 * (1.0 - q)), 0.4 * (1.0 - q)])
				return
			K.v.append([t, true])
			K.p.append([t, Vector2(jround(x), jround(y))])
			K.a.append([t, k])
			K.sv.append([t, true])
			K.sp.append([t, Vector2(floorf(x - (2 if big else 1)), floorf(y - 1))])
			K.lp.append([t, Vector2(x, y)])
			K.la.append([t, (0.12 if n.back else 0.22) * k])
			K.pop.append([t, Vector2(x, y), 0, 0.0]))
		for i in 12:
			if not alive.has(i):
				var K: Dictionary = little[i].K
				K.v.append([t, false])
				K.sv.append([t, false])
				K.la.append([t, 0.0])
				K.pop.append([t, Vector2.ZERO, 0, 0.0])
	for n in little:
		var K: Dictionary = n.K
		key(n.icon, "visible", K.v, "nearest")
		key(n.icon, "position", K.p, "nearest")
		key(n.icon, "modulate:a", K.a, "nearest")
		if n.has("shine"):
			key(n.shine, "visible", K.sv, "nearest")
			key(n.shine, "position", K.sp, "nearest")
			key(n.shine, "modulate:a", K.a, "nearest")
		key(n.light, "position", K.lp, "nearest")
		key(n.light, "material:shader_parameter/alpha", K.la, "nearest")
		sparkle_keys(n.pop, K.pop)

	# the rings thrown off with each beat (lub, then a fainter dub), then the big heart over them
	var shader: Shader = load(STATUS + "_charmed_heart.gdshader")
	var rings := []
	for j in 2:
		rings.append(shape("Ring%d" % j, shader, Vector2(42, 42), {"s": 7.0, "inner": 5.7, "c2": C[5], "alpha": 0.0}, {"at": Vector2(hx, hy)}))
	var heart := shape("Heart", shader, Vector2(42, 42), {"s": 5.6, "c0": C[0], "c1": C[2], "c2": C[3], "c3": C[4],
		"glint": C[6], "glint2": C[5]}, {"at": Vector2(hx, hy)})
	var heart_light := glow("HeartGlow", 22, {"radius": 12, "color": C[4], "alpha": 0.3}, {"at": Vector2(hx, hy)})
	heart_light.z_index = LIGHT_Z
	var flare := sparkle("Flare", {"color": C[5], "tip": C[4]})
	flare[1].z_index = LIGHT_Z
	var K := {"s": [], "gr": [], "ga": [], "fl": [], "r0s": [], "r0i": [], "r0c": [], "r0a": [], "r1s": [], "r1i": [], "r1c": [], "r1a": []}
	for t in frame_times():
		var ph: float = ph_of.call(t)
		var th := thump(ph)
		var s := 5.6 * (1.0 + 0.24 * th)
		K.s.append([t, s])
		K.gr.append([t, 12.0 + 6.0 * th])
		K.ga.append([t, 0.3 + 0.4 * th])
		K.fl.append([t, Vector2(hx + s * 0.9, hy - s * 0.8), jround(3.0 * th) if th > 0.5 else 0.0, 0.4 * th])
		var beats := [[0.04, 1.0], [0.26, 0.6]]
		for j in 2:
			var u: float = (ph - beats[j][0]) / 0.5
			var pre := "r%d" % j
			if u < 0.0 or u > 1.0:
				K[pre + "a"].append([t, 0.0])
				continue
			var S1 := 5.6 * (1.25 + 1.3 * u)
			K[pre + "s"].append([t, S1])
			K[pre + "i"].append([t, S1 - 1.3])
			K[pre + "c"].append([t, C[5] if u < 0.3 else C[4]])
			K[pre + "a"].append([t, (1.0 - u) * beats[j][1] * 1.3])
	key(heart, "material:shader_parameter/s", K.s, "nearest")
	key(heart_light, "material:shader_parameter/radius", K.gr, "nearest")
	key(heart_light, "material:shader_parameter/alpha", K.ga, "nearest")
	sparkle_keys(flare, K.fl)
	for j in 2:
		var pre := "r%d" % j
		key(rings[j], "material:shader_parameter/s", K[pre + "s"], "nearest")
		key(rings[j], "material:shader_parameter/inner", K[pre + "i"], "nearest")
		key(rings[j], "material:shader_parameter/c2", K[pre + "c"], "nearest")
		key(rings[j], "material:shader_parameter/alpha", K[pre + "a"], "nearest")

	# twinkles winking round the heart
	var tw_img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	tw_img.fill(Color(0, 0, 0, 0))
	for q in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		tw_img.set_pixel(q.x, q.y, C[5])
	tw_img.set_pixel(1, 1, WHITE)
	keep_colour(C[5])
	var tw_tex := asset("_twinkle", tw_img)
	var tw_o := {"at": Vector2(hx, hy), "amount": 2, "lifetime": 0.4, "life_random": 0.2, "emit": {"ring": [15.0, 8.0]},
		"alpha_curve": [[0, 0.0], [0.15, 1.0], [0.85, 1.0], [1, 0.0]]}
	var tw := particles("Twinkles", tw_o)
	tw.texture = tw_tex
	# at the top of its wink it opens to a 2 px cross (the same particles: same options, same seed)
	var big_img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	big_img.fill(Color(0, 0, 0, 0))
	for q in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		big_img.set_pixel(q.x, q.y, C[5])
	for q in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(4, 2), Vector2i(2, 4)]:
		big_img.set_pixel(q.x, q.y, C[4])
	big_img.set_pixel(2, 2, WHITE)
	var bo := tw_o.duplicate()
	bo.alpha_curve = [[0, 0.0], [0.38, 0.0], [0.39, 1.0], [0.61, 1.0], [0.62, 0.0], [1, 0.0]]
	var tb := particles("TwinkleBig", bo)
	tb.texture = asset("_twinkle_big", big_img)
	tb.seed = tw.seed
	var lo := tw_o.duplicate()
	lo.layer = "light"
	lo.texture = "glow16"
	var tl := particles("TwinkleLight", lo)
	tl.seed = tw.seed
	tl.modulate = Color(C[5], 0.3)
	tl.z_index = LIGHT_Z
