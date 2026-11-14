# reimagined-from: src/fx/shadow/hex-sigil.js@8452c54739a41e7dce5a253dc6932391b65fde2c
# Hex sigil: A burning pen traces a cursed sigil in the air, its glyphs pop in one by one, then it flares white and crumbles into falling embers.
# one-shot, 4.20 s, 168x128 canvas, origin [84.0, 112.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The pen's strokes and the glyphs are one canvas shader (fx/shadow/_hex-sigil_strokes.gdshader) over a data box baked
# at build time from the original's stroke list: when the pen passed each pixel, when each glyph popped; the shader
# colours them by age off the keyed clock (white behind the pen, cooling to violet, pulsing while held, white in the
# flare) and a light pass lights them in the flare. The pen is a keyed glint (sparkle shader) with its light, spitting
# sparks and dripping embers (emitters riding its keyed path); streaks race into the heart; glyphs pop with a ring,
# sparks and a light; the flare is a glint, a burst ring and two lights; then it crumbles: burning slivers (an emitter
# on the strokes' points, white-tipped by its own shader) drop, bounce and settle on a collision floor, embers rise,
# soot puffs roll up (soft layer).
extends "res://build/fx/shadow/_shadow.gd"

const CY := -50.0
const RO := 28.0
const RI := 22.0
const RC := 6.0
const GLYPH := 1.62
const FLARE := 2.6
const BREAK := 2.74
const GRAVITY := 950.0
const BOX := 64

var pts: Array = []    # [x, y, t]
var s_end := 0.0


# ---- the original's Rng (mulberry32) and hash, for its glyph shapes
static func hash_ints(ns: Array) -> int:
	var h := 0x9e3779b9
	for n in ns:
		h = JsRng.imul(h ^ (int(n) & 0xFFFFFFFF), 0x85ebca6b)
		h ^= h >> 13
		h = JsRng.imul(h, 0xc2b2ae35)
		h ^= h >> 16
	return h & 0xFFFFFFFF


class JsRng:
	var s := 1

	static func imul(a: int, b: int) -> int:
		a &= 0xFFFFFFFF
		b &= 0xFFFFFFFF
		return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

	func _init(seed_: int) -> void:
		s = seed_ & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s = (s + 0x6d2b79f5) & 0xFFFFFFFF
		var t := s
		t = imul(t ^ (t >> 15), t | 1)
		t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

	func range_f(a: float, b: float) -> float:
		return a + (b - a) * next()

	func int_r(a: int, b: int) -> int:
		return int(floor(range_f(a, b + 1)))


func circle_path(r: float, a0: float) -> Array:
	var n := int(ceil(r * TAU))
	var out := []
	for i in n + 1:
		var a := a0 + float(i) / n * TAU
		out.append(Vector2(cos(a) * r, CY + sin(a) * r))
	return out


func make_strokes() -> void:
	var paths := []
	paths.append(circle_path(RO, -PI / 2))
	var star := []
	for i in 8:
		var a := -PI / 2 + ((i * 3) % 7) * (TAU / 7)
		star.append(Vector2(cos(a) * RI, CY + sin(a) * RI))
	paths.append(star)
	paths.append(circle_path(RI, -PI / 2))
	paths.append(circle_path(RC, PI / 2))
	paths.append([Vector2(0, CY - 3.5), Vector2(2, CY), Vector2(0, CY + 3.5), Vector2(-2, CY), Vector2(0, CY - 3.5)])
	var speeds := [420.0, 700.0, 550.0, 380.0, 300.0]
	var t := 0.12
	for k in paths.size():
		var path: Array = paths[k]
		for i in range(1, path.size()):
			var a: Vector2 = path[i - 1]
			var b: Vector2 = path[i]
			var L := a.distance_to(b)
			var d := 0.0
			while d < L:
				pts.append([a.x + (b.x - a.x) * d / L, a.y + (b.y - a.y) * d / L, t + d / speeds[k]])
				d += 0.5
			t += L / speeds[k]
		t += 0.04
	s_end = t


func make_glyphs() -> Array:
	var out := []
	for i in 7:
		var r := JsRng.new(hash_ints([meta.options.seed, i, 31]))
		var segs := [[Vector2i(1, 0), Vector2i(1, 2)]]
		var k := 0
		while k < 2 + (1 if r.next() < 0.5 else 0):
			var a := Vector2i(r.int_r(0, 2), r.int_r(0, 2))
			var b := Vector2i(clampi(a.x + r.int_r(-1, 1), 0, 2), clampi(a.y + r.int_r(-1, 1), 0, 2))
			if a != b:
				segs.append([a, b])
			k += 1
		var ang := -PI / 2 + i * TAU / 7 + PI / 7
		var rr := (RO + RI) / 2
		out.append({"x": cos(ang) * rr, "y": CY + sin(ang) * rr, "segs": segs, "t": GLYPH + i * 0.07})
	return out


# the pen's point at t (the original advances its index to the last point already passed)
func pen_at(t: float) -> Vector2:
	var lo := 0
	var hi: int = pts.size() - 1
	if pts[0][2] > t:
		return Vector2(pts[0][0], pts[0][1])
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if pts[mid][2] <= t:
			lo = mid
		else:
			hi = mid - 1
	return Vector2(pts[lo][0], pts[lo][1])


func bres(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var sx := a.x
	var sy := a.y
	var dx := absi(b.x - sx)
	var dy := -absi(b.y - sy)
	var stx := 1 if sx < b.x else -1
	var sty := 1 if sy < b.y else -1
	var err := dx + dy
	while true:
		out.append(Vector2i(sx, sy))
		if sx == b.x and sy == b.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			sx += stx
		if e2 <= dx:
			err += dx
			sy += sty
	return out


func bake(glyphs: Array) -> Texture2D:
	var first := {}
	var second := {}
	var lightc := {}
	var glyph_t := {}
	for q in pts:
		var c := Vector2i(int(floor(q[0])), int(floor(q[1])))
		var tq: float = q[2]
		if not first.has(c):
			first[c] = tq
		elif tq > first[c] + 0.1 and not second.has(c):
			second[c] = tq
		elif second.has(c) and tq < second[c] + 0.1:
			pass
		if int(q[0] * 2) % 3 == 0:
			lightc[c] = lightc.get(c, 0) + 1
	for g in glyphs:
		for sg in g.segs:
			var a := Vector2i(int(floor(g.x - 2 + sg[0].x * 2)), int(floor(g.y - 2 + sg[0].y * 2)))
			var b := Vector2i(int(floor(g.x - 2 + sg[1].x * 2)), int(floor(g.y - 2 + sg[1].y * 2)))
			for c in bres(a, b):
				if not glyph_t.has(c):
					glyph_t[c] = g.t
	var img := Image.create(BOX, BOX, false, Image.FORMAT_RGBA8)
	var o := Vector2i(-BOX / 2, int(CY) - BOX / 2)
	for y in BOX:
		for x in BOX:
			var c := o + Vector2i(x, y)
			var r := (roundf(first[c] * 60.0) if first.has(c) else 255.0) / 255.0
			var g := (roundf(second[c] * 60.0) if second.has(c) else 255.0) / 255.0
			var b := (roundf(glyph_t[c] * 60.0) if glyph_t.has(c) else 255.0) / 255.0
			var a := minf(1.0, lightc.get(c, 0) * 0.25)
			img.set_pixel(x, y, Color(r, g, b, a))
	return asset("strokes.png", img)


func spark_opts(o: Dictionary) -> Dictionary:
	var base := {"texture": "streak3", "align": true, "gravity": Vector2(0, GRAVITY * 0.45), "drag": 2.2,
		"ramp": gradient([Color.WHITE, C[7], C[6]], [0.0, 0.4, 0.7])}
	base.merge(o, true)
	return base


# an emitter and its light twin (core twin(): same particles, glowing)
func pair(name: String, o: Dictionary, glow_tex: String, tint: Color) -> Array:
	var p := particles(name, o)
	if o.has("life_random"):
		life_rand(p, o.life_random)
	return [p, twin(p, {"texture": glow_tex, "modulate": tint})]


func make() -> void:
	make_strokes()
	var glyphs := make_glyphs()
	ground()
	keep_colour(Color.WHITE)

	# the dim light behind it, swelling as it's written, dying as it crumbles
	var back := glow("BackGlow", 53, {"radius": 52, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, CY), "back": true})
	keyf(back, "material:shader_parameter/alpha", func(t: float):
		return 0.3 * (smooth(0.1, 0.6, t) if t < BREAK else 1.0 - smooth(BREAK, BREAK + 0.6, t)), 0.0, BREAK + 0.7)

	# the strokes and glyphs, and their light in the flare
	var data := bake(glyphs)
	var st := shape("Strokes", shadow_shader("hex-sigil_strokes"), Vector2(BOX, BOX),
		{"data": data, "s_end": s_end, "flare": FLARE, "white": Color.WHITE, "c5": C[5], "c6": C[6], "c7": C[7]}, {"at": Vector2(0, CY)})
	key(st, "material:shader_parameter/t", [[0.0, 0.0], [root.duration, root.duration]])
	show(st, 0.0, BREAK)
	var sl := shape("StrokeLight", shadow_shader("hex-sigil_strokelight"), Vector2(BOX, BOX), {"data": data, "color": C[6]}, {"at": Vector2(0, CY)})
	show(sl, FLARE, BREAK)

	# glyphs: a glow while they last, a ring and a flash of light as each pops, four sparks
	var gi := 0
	for g in glyphs:
		var gt: float = g.t
		var at := Vector2(g.x, g.y)
		var gg := glow("Glyph%dGlow" % gi, 7, {"radius": 6, "color": C[5], "alpha": 0.25}, {"at": at})
		show(gg, gt, BREAK)
		var rr := ring("Glyph%dRing" % gi, 7, {"radius": 2, "thickness": 1, "color": C[7]}, {"at": at})
		keyf(rr, "material:shader_parameter/radius", func(t: float): return 2.0 + 4.0 * seg(t, gt, gt + 0.18), gt, gt + 0.18)
		key(rr, "material:shader_parameter/color", [[gt, C[7]], [gt + 0.09, C[5]]], "nearest")
		show(rr, gt, gt + 0.18)
		var pl := glow("Glyph%dPop" % gi, 15, {"radius": 14, "color": C[6], "alpha": 0.0}, {"at": at})
		keyf(pl, "material:shader_parameter/radius", func(t: float): return 14.0 * (0.6 + 0.4 * (1.0 - seg(t, gt, gt + 0.2))), gt, gt + 0.2)
		keyf(pl, "material:shader_parameter/alpha", func(t: float): return 0.0 if t < gt else 0.7 * pow(1.0 - seg(t, gt, gt + 0.2), 2.0), gt - 0.034, gt + 0.2)
		var sp := pair("Glyph%dSparks" % gi, spark_opts({"at": at, "amount": 4, "lifetime": 0.25, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "dir": -90, "spread": 60, "speed": [20, 70], "life_random": 0.6}), "glow8", Color(1, 1, 1, 0.4))
		for e in sp:
			emit(e, gt)
		gi += 1

	# the pen: a white-hot glint with its light, spitting sparks and dripping embers as it writes
	var pen := shape("Pen", shadow_shader("hex-sigil_sparkle"), Vector2(19, 19), {"arm": 3.0, "c": C[7], "tip": C[6], "heart": Color.WHITE},
		{"at": Vector2(0.5, CY - RO + 0.5)})
	keyf(pen, "position", func(t: float): return pen_at(t).floor() + Vector2(0.5, 0.5), 0.0, s_end + 0.1, 30.0, "nearest")
	keyf(pen, "material:shader_parameter/arm", func(t: float): return roundf(3.0 + sin(t * 60.0)), 0.0, s_end + 0.1, 30.0, "nearest")
	show(pen, 0.12, s_end + 0.05)
	var pen_light := glow("PenLight", 17, {"radius": 16, "color": C[6], "alpha": 0.55}, {"at": Vector2(0, CY - RO)})
	var pen_glint := glow("PenGlint", 11, {"radius": 10, "color": C[7], "alpha": 0.6}, {"at": Vector2(0, CY - RO)})
	for n in [pen_light, pen_glint]:
		keyf(n, "position", func(t: float): return pen_at(t), 0.0, s_end + 0.1, 30.0, "nearest")
		show(n, 0.12, s_end + 0.05)
	var pen_path := group("PenPath")
	keyf(pen_path, "position", func(t: float): return pen_at(t), 0.0, s_end + 0.1, 60.0)
	var pen_sparks := pair("PenSparks", spark_opts({"parent": pen_path, "amount": 24, "lifetime": 0.35, "dir": -90, "spread": 65,
		"speed": [20, 100], "life_random": 0.65}), "glow8", Color(1, 1, 1, 0.45))
	var pen_embers := pair("PenEmbers", {"parent": pen_path, "amount": 9, "lifetime": 0.9, "texture": "dot1", "dir": 90, "spread": 35,
		"speed": [5, 25], "gravity": Vector2(0, -30), "drag": 1.6, "life_random": 0.45,
		"ramp": gradient([C[7], C[6], C[5]], [0.0, 0.4, 0.7]), "alpha_curve": [[0, 1], [0.75, 1], [0.8, 0], [0.85, 1], [0.9, 0], [0.95, 1], [1, 0]]},
		"glow8", Color(1, 1, 1, 0.35))
	for e in pen_sparks + pen_embers:
		emit(e, 0.12, s_end)

	# power drawn in: streaks racing into the heart, more as it nears the flare
	var streak_o := {"at": Vector2(0, CY), "amount": 7, "lifetime": 0.32, "texture": "streak6", "align": true,
		"emit": {"ring": [60, 40]}, "radial_speed": [-125, -95], "radial": [-520, -420], "life_random": 0.3,
		"initial": gradient([C[7], C[6]]), "alpha_curve": [[0, 1], [0.85, 1], [1, 0]]}
	var streaks := pair("Streaks", streak_o, "glow8", Color(1, 1, 1, 0.4))
	for e in streaks:
		emit(e, 0.2, FLARE - 0.05)
		keyf(e, "amount_ratio", func(t: float): return (8.0 + 14.0 * smooth(0.2, FLARE, t)) / 22.0, 0.2, FLARE)

	# the flare: a big glint, a burst ring rolling out, two lights, sparks thrown off the heart
	var fg := shape("FlareGlint", shadow_shader("hex-sigil_sparkle"), Vector2(39, 39), {"arm": 18.0, "c": C[7], "tip": C[5], "heart": Color.WHITE},
		{"at": Vector2(0.5, CY + 0.5)})
	keyf(fg, "material:shader_parameter/arm", func(t: float): return roundf(18.0 * (1.0 - seg(t, FLARE, FLARE + 0.22))), FLARE, FLARE + 0.22, 30.0, "nearest")
	show(fg, FLARE, FLARE + 0.22)
	var fgl := glow("FlareGlintLight", 41, {"radius": 40, "color": C[7], "alpha": 0.9}, {"at": Vector2(0, CY)})
	keyf(fgl, "material:shader_parameter/radius", func(t: float): return 4.0 + 2.0 * roundf(18.0 * (1.0 - seg(t, FLARE, FLARE + 0.22))), FLARE, FLARE + 0.22)
	keyf(fgl, "material:shader_parameter/alpha", func(t: float): return 0.9 * (1.0 - seg(t, FLARE, FLARE + 0.22)), FLARE, FLARE + 0.22)
	show(fgl, FLARE, FLARE + 0.22)
	var burst := ring("Burst", 44, {"radius": RO + 3, "thickness": 3, "color": Color.WHITE}, {"at": Vector2(0, CY)})
	keyf(burst, "material:shader_parameter/radius", func(t: float): return RO + 3.0 + 12.0 * out_cubic(seg(t, FLARE, FLARE + 0.35)), FLARE, FLARE + 0.35)
	keyf(burst, "material:shader_parameter/thickness", func(t: float): return maxf(1.0, 3.0 * (1.0 - seg(t, FLARE, FLARE + 0.35))), FLARE, FLARE + 0.35)
	key(burst, "material:shader_parameter/color", [[FLARE, Color.WHITE], [FLARE + 0.14, C[6]], [FLARE + 0.245, C[4]]], "nearest")
	show(burst, FLARE, FLARE + 0.35)
	for l in [["FlareLight", 96.0, 1.4, 0.45, C[5]], ["FlareCore", 44.0, 1.0, 0.14, C[6]]]:
		var r0: float = l[1]
		var k0: float = l[2]
		var life: float = l[3]
		var fl := glow(l[0], r0 + 1, {"radius": r0, "color": l[4], "alpha": 0.0}, {"at": Vector2(0, CY)})
		keyf(fl, "material:shader_parameter/radius", func(t: float): return r0 * (0.6 + 0.4 * (1.0 - seg(t, FLARE, FLARE + life))), FLARE, FLARE + life)
		keyf(fl, "material:shader_parameter/alpha", func(t: float): return 0.0 if t < FLARE else k0 * pow(1.0 - seg(t, FLARE, FLARE + life), 2.0), FLARE - 0.034, FLARE + life)
	var fs := pair("FlareSparks", spark_opts({"at": Vector2(0, CY), "amount": 24, "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "emit": {"ring": [13, 12.5]}, "radial_speed": [60, 130], "life_random": 0.55}), "glow8", Color(1, 1, 1, 0.45))
	for e in fs:
		emit(e, FLARE)

	# it crumbles: burning slivers drop off every stroke, bounce and settle; embers rise; soot rolls up
	var shard_pts := PackedVector2Array()
	var ember_pts := PackedVector2Array()
	for i in range(0, pts.size() - 1, 7):
		shard_pts.append(Vector2(pts[i][0], pts[i][1]))
		if i % 27 == 0:
			ember_pts.append(Vector2(pts[i][0], pts[i][1]))
	var sliver := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	sliver.set_pixel(0, 0, Color(0, 0, 0, 1))
	sliver.set_pixel(1, 0, Color(0, 0, 0, 1))
	sliver.set_pixel(2, 0, Color(1, 0, 0, 1))
	var shards := particles("Shards", {"amount": shard_pts.size(), "lifetime": 1.2, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"texture": asset("sliver.png", sliver), "emit": {"points": shard_pts}, "dir": -90, "spread": 180, "speed": [0, 12],
		"gravity": Vector2(0, GRAVITY * 0.33), "angle": [0, 360], "spin": [-170, 170], "life_random": 0.33,
		"initial": gradient([C[7], C[6], C[6], C[5]]), "alpha_curve": [[0, 1], [0.66, 1], [1, 0]],
		"collide": {"bounce": 0.25, "friction": 0.9, "size": 1.0}})
	var sm := ShaderMaterial.new()
	sm.shader = shadow_shader("hex-sigil_shard")
	sm.set_shader_parameter("white", Color.WHITE)
	shards.material = sm
	emit(shards, BREAK)
	var crumble_embers := pair("CrumbleEmbers", {"amount": ember_pts.size(), "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "dot1", "emit": {"points": ember_pts}, "dir": -90, "spread": 15, "speed": [10, 40],
		"gravity": Vector2(0, -30), "drag": 1.6, "life_random": 0.45, "ramp": gradient([C[7], C[6], C[5]], [0.0, 0.4, 0.7]),
		"alpha_curve": [[0, 1], [0.75, 1], [0.8, 0], [0.85, 1], [0.9, 0], [0.95, 1], [1, 0]]}, "glow8", Color(1, 1, 1, 0.35))
	for e in crumble_embers:
		emit(e, BREAK)
	var soot_g := gradient([C[3].lerp(C[2], 0.5), C[2].lerp(C[1], 0.5)], [0.0, 0.6])
	var gpts := PackedVector2Array()
	for g in glyphs:
		gpts.append(Vector2(g.x, g.y))
	var soot_a := particles("SootGlyphs", {"layer": "soft", "back": true, "amount": 7, "lifetime": 1.1, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "disc13", "emit": {"points": gpts}, "dir": -90, "spread": 30, "speed": [8, 18],
		"gravity": Vector2(0, -18), "drag": 1.4, "life_random": 0.35, "scale": [0.46, 0.77],
		"scale_curve": [[0, 0.65], [0.4, 1.28], [1, 1.55]], "ramp": soot_g, "alpha_curve": [[0, 0], [0.1, 0.62], [0.55, 0.62], [1, 0]]})
	emit(soot_a, BREAK)
	var soot_b := particles("SootHeart", {"layer": "soft", "back": true, "at": Vector2(0, CY), "amount": 8, "lifetime": 1.2, "one_shot": true,
		"explosiveness": 0.88, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(20, 20)}, "dir": -90, "spread": 30,
		"speed": [6, 16], "gravity": Vector2(0, -18), "drag": 1.4, "life_random": 0.33, "scale": [0.46, 0.92],
		"scale_curve": [[0, 0.65], [0.4, 1.28], [1, 1.55]], "ramp": soot_g, "alpha_curve": [[0, 0], [0.1, 0.62], [0.55, 0.62], [1, 0]]})
	emit(soot_b, BREAK)
