# reimagined-from: src/fx/holy/smite.js@bbfe3825e06e97aece43af1099acaf5f3e3a379b
# Smite: A glint marks the spot, then a bolt of light drops like a hammer: a white flash, a shockwave over the floor, stone chips flying and cracks that glow and cool.
# one-shot, 2.80 s, 224x176 canvas, origin [112.0, 148.0], backdrop dark
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The mark (fx/holy/_smite_mark.gdshader: an oval closing on the spot, a spinning glint) and a faint thread of light
# from the sky; the hammer (fx/holy/_smite_beam.gdshader: a blunt beam and its white head falling faster and faster,
# speed lines over it) keyed on the original's fall; at the hit a white hero frame, a star glint, flashes of light, a
# dome of light thrown up and a shockwave band rolling over the floor (its far half behind), the bolt's afterimage
# thinning out. The cracks are the original's own (its seeded bolts, rolled here as it rolls them), baked into a
# data texture that a shader grows and cools crack by crack (fx/holy/_smite_cracks.gdshader) with their light. Sparks,
# stars, stone chips and grit fly and bounce off the floor, dust rolls out along it and smoke lifts off the crater;
# the cracks spit embers and stars while they're hot.
extends "res://build/fx/holy/_strike.gd"

const TOP := -148.0
const SY := 0.38
const MARK := 0.42
const HIT := 0.54
const LEN := 44.0


func make() -> void:
	ground()
	var D: float = root.duration
	var S := [Color.WHITE, C[6], C[5], C[3]]
	var s0 := Color(meta.options.stone)
	var st := [s0 * Color(0.5, 0.5, 0.5, 1), s0 * Color(0.75, 0.75, 0.75, 1), s0, (s0 * Color(1.4, 1.4, 1.4, 1)).clamp().lerp(Color.WHITE, 0.1)]
	var dust := s0.lerp(Color("#8a8094"), 0.4)
	var R := Rng.new(int(meta.options.seed))

	# the cracks, rolled as the original rolls them
	var cracks := []
	for i in 7:
		var a := 0.12 + (i / 6.0) * (PI - 0.24) + R.range(-0.12, 0.12)
		var L := R.range(30, 54) * (0.6 if absf(sin(a)) > 0.7 else 1.0)
		var raw := bolt_path(R, Vector2.ZERO, Vector2(cos(a) * L, sin(a) * L), 0.28, 4)
		var pts := PackedVector2Array()
		for q in raw:
			pts.append(Vector2(q.x, q.y * SY))
		var fork := PackedVector2Array()
		if pts.size() > 6:
			var m := pts[int(floor(pts.size() * 0.5))]
			var fx_ := m.x + cos(a + R.sign() * 0.7) * L * 0.35
			var fy := m.y + sin(a + R.sign() * 0.7) * L * 0.35 * SY
			fork = bolt_path(R, m, Vector2(fx_, fy), 0.3, 3)
		cracks.append({"pts": pts, "fork": fork, "L": L, "cool": R.range(1.6, 2.1)})
	_cracks(cracks)

	# ---- the mark: an oval closing on the spot, a glint spinning over it, a thread of light from the sky
	var mark := shape("Mark", holy_shader("smite_mark"), Vector2(64, 48), {"sy": SY, "c3": C[3], "c5": C[5]}, {"at": Vector2(0, -2)})
	keyn(mark, "material:shader_parameter/k", func(t: float) -> float: return smooth(0.0, 0.08, t) if t < HIT else 0.0)
	keyn(mark, "material:shader_parameter/ka", func(t: float) -> float: return smooth(0.0, 0.08, t) * (0.65 + 0.35 * sin(t * 40.0)) if t < HIT else 0.0, 0.0, HIT + 0.05)
	keyn(mark, "material:shader_parameter/rr", func(t: float) -> float: return lerpf(26.0, 8.0, _in_out_cubic(seg(t, 0.0, MARK))), 0.0, HIT)
	keyn(mark, "material:shader_parameter/spin", func(t: float) -> float: return t * 3.0, 0.0, HIT)
	keyn(mark, "material:shader_parameter/arm", func(t: float) -> float: return (3.0 + 8.0 * out_back(clampf(t / 0.2, 0.0, 1.0), 2.0)) * ((1.0 + 0.6 * seg(t, MARK, HIT)) if t > MARK else 1.0), 0.0, HIT)
	var mark_light := shape("MarkLight", holy_shader("smite_glowseg"), Vector2(60, 180),
		{"a": Vector2(0, TOP + 6), "b": Vector2(0, -2), "radius": 5.0, "color": C[4], "at": Vector2(0, -2), "color2": C[5]}, {"at": Vector2(0, -60)})
	keyn(mark_light, "material:shader_parameter/k", func(t: float) -> float: return 0.12 * seg(t, 0.0, MARK) if t < HIT else 0.0, 0.0, HIT + 0.05)
	keyn(mark_light, "material:shader_parameter/radius2", func(t: float) -> float: return 14.0 + 10.0 * seg(t, 0.0, MARK), 0.0, HIT)
	keyn(mark_light, "material:shader_parameter/k2", func(t: float) -> float: return 0.5 * smooth(0.0, 0.08, t) if t < HIT else 0.0, 0.0, HIT + 0.05)
	# stars twinkle up off the mark while it closes
	var tipw := Color(0.75, 0.75, 0.75)
	keep_colour(tipw)
	var ms := star_particles("MarkStars", 1.0, Color.WHITE, tipw, {"amount": 12, "lifetime": 0.4, "life_random": 0.5, "one_shot": false,
		"explosiveness": 0.0, "at": Vector2(0, -9), "emit": {"box": Vector2(10, 9)}, "dir": -90.0, "speed": [4.0, 12.0], "preprocess": 0.0})
	emit(ms, 0.0, MARK)

	# ---- the hammer, falling faster and faster
	var hammer := shape("Hammer", holy_shader("smite_beam"), Vector2(40, 170), {"c4": C[4], "c5": C[5], "c6": C[6]}, {"at": Vector2(0, -73)})
	var ham_light := shape("HammerLight", holy_shader("smite_glowseg"), Vector2(70, 190), {"radius": 16.0, "color": C[5], "color2": Color.WHITE}, {"at": Vector2(0, -70)})
	var K := {}
	for n in ["on", "y0", "y1", "bon", "hy0", "hy1", "ly0", "ly1", "lk", "white", "la", "lb", "lk1", "lat", "lr2", "lk2"]:
		K[n] = []
	for f in range(0, int(ceilf(D * FPS)) + 1):
		var t := f / FPS
		var at := maxf(0.0, t - 0.002)
		var on := t >= MARK and t < HIT + 0.06
		var y1 := 0.0 if t >= HIT else lerpf(TOP - 6.0, 0.0, in_cubic(seg(t, MARK, HIT)))
		var y0 := maxf(TOP + 5.0, y1 - LEN * ((1.0 - (t - HIT) / 0.06) if t >= HIT else 1.0))
		if y1 < TOP + 12.0:
			on = false
		K.on.append([at, on])
		K.y0.append([at, y0])
		K.y1.append([at, y1 - 3.0])
		K.bon.append([at, 1.0 if y1 - 3.0 > y0 else 0.0])
		K.hy0.append([at, y1 - 6.0])
		K.hy1.append([at, y1 - 1.0])
		K.ly0.append([at, maxf(TOP, y0 - 70.0)])
		K.ly1.append([at, y0])
		K.lk.append([at, 1.0 if y0 > TOP + 2.0 else 0.0])
		K.white.append([at, 1.0 if t >= HIT else 0.0])
		K.la.append([at, Vector2(0, y0 + 10.0)])
		K.lb.append([at, Vector2(0, y1)])
		K.lk1.append([at, 0.6 if on else 0.0])
		K.lat.append([at, Vector2(0, y1 - 4.0)])
		K.lr2.append([at, minf(22.0, y1 - TOP - 6.0)])
		K.lk2.append([at, 0.5 if on else 0.0])
	key(hammer, "visible", K.on, "nearest")
	for pair in [["y0", "y0"], ["y1", "y1"], ["body_on", "bon"], ["hy0", "hy0"], ["hy1", "hy1"], ["ly0", "ly0"], ["ly1", "ly1"], ["lk", "lk"], ["white", "white"]]:
		key(hammer, "material:shader_parameter/" + pair[0], K[pair[1]], "nearest")
	hammer.material.set_shader_parameter("head_on", 1.0)
	for pair in [["a", "la"], ["b", "lb"], ["k", "lk1"], ["at", "lat"], ["radius2", "lr2"], ["k2", "lk2"]]:
		key(ham_light, "material:shader_parameter/" + pair[0], K[pair[1]], "nearest")

	# ---- the bolt's afterimage: a thread of light from the sky to the mark, thinning out
	var after := shape("Afterimage", holy_shader("smite_beam"), Vector2(16, 150), {"mode": 1.0, "y0": TOP + 4.0, "y1": -4.0, "body_on": 1.0, "c4": C[4], "c5": C[5], "c6": C[6]}, {"at": Vector2(0, -74)})
	var after_light := shape("AfterLight", holy_shader("smite_glowseg"), Vector2(30, 160), {"a": Vector2(0, TOP + 16), "b": Vector2(0, -6), "radius": 10.0, "color": C[5]}, {"at": Vector2(0, -70)})
	var ai := func(t: float) -> float: return seg(t, HIT + 0.04, HIT + 0.55)
	show(after, HIT + 0.04 + 1.0 / FPS * 0.5, HIT + 0.55)
	keyn(after, "material:shader_parameter/width", func(t: float) -> float: return 1.0 + 4.0 * pow(1.0 - ai.call(t), 2.0), HIT, HIT + 0.6)
	keyn(after, "material:shader_parameter/fade", func(t: float) -> float: return 1.0 - ai.call(t) * 0.5, HIT, HIT + 0.6)
	keyn(after_light, "material:shader_parameter/k", func(t: float) -> float: return 0.4 * (1.0 - ai.call(t)) if (t > HIT + 0.04 and ai.call(t) < 1.0) else 0.0)

	# ---- the hit: a white hero frame, a star glint, flashes of light
	var hero := ring("Hero", 20, {"radius": 16.0, "color": Color.WHITE}, {"at": Vector2(0, -6)})
	var hero2 := ring("Hero2", 20, {"radius": 19.0, "color": C[6], "alpha": 0.6}, {"at": Vector2(0, -6)})
	for h in [hero, hero2]:
		show(h, HIT, HIT + 0.07)
	var glint := shape("Glint", holy_shader("sparkle"), Vector2(35, 35), {"arm": 0.0, "c": Color.WHITE, "tip": C[5], "heart": Color.WHITE}, {"at": Vector2(0.5, -7.5)})
	keyn(glint, "material:shader_parameter/arm", func(t: float) -> float: return 16.0 * (1.0 - (t - HIT) / 0.25) if (t >= HIT and t < HIT + 0.25) else 0.0)
	var glint_light := glow("GlintLight", 40, {"radius": 36.0, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, -8)})
	keyn(glint_light, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + 2.0 * roundf(16.0 * (1.0 - (t - HIT) / 0.25)) if (t >= HIT and t < HIT + 0.25) else 4.0)
	keyn(glint_light, "material:shader_parameter/alpha", func(t: float) -> float: return 0.7 if (t >= HIT and t < HIT + 0.25) else 0.0)
	light_burst("HitLight", HIT, Vector2(0, -24), 92, C[5], 1.0, 0.6)
	light_burst("HitWhite", HIT, Vector2(0, -8), 40, Color.WHITE, 0.9, 0.12)

	# ---- the shockwave over the floor (its far half behind) and the dome of light thrown up over the hit
	var bk := func(t: float) -> float: return seg(t, HIT, HIT + 0.42)
	for half in [[1.0, true, "BandFar"], [-1.0, false, "BandNear"]]:
		var b := shape(half[2], holy_shader("smite_band"), Vector2(188, 64), {"radius": 6.0, "thickness": 5.0, "squash": SY * 0.8,
			"c0": Color.WHITE, "c1": C[6], "c2": C[5], "c3": C[4], "k": 1.0, "side": half[0]}, {"back": half[1]})
		show(b, HIT, HIT + 0.42)
		keyn(b, "material:shader_parameter/radius", func(t: float) -> float: return 6.0 + 84.0 * out_cubic(bk.call(t)), HIT, HIT + 0.45)
		keyn(b, "material:shader_parameter/thickness", func(t: float) -> float: return maxf(1.0, 5.0 * (1.0 - bk.call(t))), HIT, HIT + 0.45)
		keyn(b, "material:shader_parameter/k", func(t: float) -> float: return 1.15 - bk.call(t), HIT, HIT + 0.45)
	var dk := func(t: float) -> float: return seg(t, HIT, HIT + 0.28)
	var dome := shape("Dome", holy_shader("smite_band"), Vector2(104, 104), {"radius": 8.0, "thickness": 3.0, "squash": 1.0,
		"c0": Color.WHITE, "c1": Color.WHITE, "c2": Color.WHITE, "c3": Color.WHITE, "k": 1.0, "even": true, "side": 1.0})
	show(dome, HIT, HIT + 0.28)
	keyn(dome, "material:shader_parameter/radius", func(t: float) -> float: return 8.0 + 40.0 * out_cubic(dk.call(t)), HIT, HIT + 0.3)
	keyn(dome, "material:shader_parameter/thickness", func(t: float) -> float: return maxf(1.0, 3.0 * (1.0 - dk.call(t))), HIT, HIT + 0.3)
	keyn(dome, "material:shader_parameter/k", func(t: float) -> float: return 1.1 - dk.call(t), HIT, HIT + 0.3)
	for c in ["c2", "c3"]:
		keyn(dome, "material:shader_parameter/" + c, func(t: float) -> Color: return Color.WHITE if dk.call(t) < 0.2 else C[5], HIT, HIT + 0.3)
	var g := PI * 1.1
	var gi := 0
	while g < TAU - 0.2:
		var gg := g
		var dl := glow("DomeLight%d" % gi, 10, {"radius": 8.0, "color": C[5], "alpha": 0.0})
		keyn(dl, "position", func(t: float) -> Vector2: return Vector2(cos(gg), sin(gg)) * (8.0 + 40.0 * out_cubic(dk.call(t))), HIT, HIT + 0.3)
		keyn(dl, "material:shader_parameter/alpha", func(t: float) -> float: return 0.3 * (1.0 - dk.call(t)) if (t >= HIT and dk.call(t) < 1.0) else 0.0)
		g += 0.5
		gi += 1

	# ---- sparks, stars, stone chips, grit
	var sp_o := {"amount": 60, "lifetime": 0.75, "life_random": 0.67, "at": Vector2(0, -2), "emit": {"box": Vector2(3, 0.5)},
		"dir": -90.0, "spread": 72.0, "speed": [110.0, 280.0]}
	var sparks := spark_particles("Sparks", S, sp_o)
	emit(sparks, HIT)
	var spl := spark_particles("SparkLight", S, sp_o.merged({"texture": "glow8", "layer": "light", "modulate": Color(1, 1, 1, 0.4)}))
	emit(spl, HIT)
	var stars := star_particles("Stars", 1.8, Color.WHITE, tipw, {"amount": 16, "lifetime": 0.9, "life_random": 0.55, "at": Vector2(0, -4),
		"emit": {"box": Vector2(4, 0.5)}, "dir": -90.0, "spread": 57.0, "speed": [60.0, 160.0]})
	emit(stars, HIT)
	for s in [1, 2, 3]:
		var chip := particles("Chips%d" % s, {"amount": [5, 5, 4][s - 1], "lifetime": 1.8, "life_random": 0.33, "one_shot": true, "explosiveness": 1.0,
			"emitting": false, "texture": asset("chip%d.png" % s, _chip(s, st)), "at": Vector2(0, -2), "emit": {"box": Vector2(5, 0.5)},
			"dir": -90.0, "spread": 69.0, "speed": [90.0, 230.0], "gravity": Vector2(0, GRAV), "drag": 0.4, "angle": [0.0, 360.0],
			"spin": [-800.0, 800.0], "alpha_curve": [[0.0, 1.0], [0.72, 1.0], [1.0, 0.0]],
			"collide": {"bounce": 0.35, "friction": 0.9, "size": 0.6 + s * 0.7}})
		emit(chip, HIT)
	var grit_ramp := gradient([st[1], st[2], st[3]])
	for big in [false, true]:
		var gr := particles("Grit2" if big else "Grit1", {"amount": 14 if big else 20, "lifetime": 1.5, "life_random": 0.4, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "dot2" if big else "dot1", "at": Vector2(0, -1), "emit": {"box": Vector2(4, 0.5)},
			"dir": -90.0, "spread": 57.0, "speed": [60.0, 220.0], "gravity": Vector2(0, GRAV), "drag": 0.8, "initial": grit_ramp,
			"collide": {"bounce": 0.15, "friction": 1.0, "size": 2.0 if big else 1.0}})
		emit(gr, HIT)

	# ---- dust rolls out along the floor, a little smoke lifts off the crater
	var smoke_c := dust.lerp(C[4], 0.18)
	var smoke_r := gradient([Color(smoke_c, 0.0), Color(smoke_c, 0.5), Color(Color("#5d5660"), 0.42), Color(Color("#433d48"), 0.3), Color(Color("#433d48"), 0.0)],
		[0.0, 0.08, 0.4, 0.75, 1.0], true)
	for side in [-1.0, 1.0]:
		var sm := particles("Dust" + ("L" if side < 0 else "R"), {"layer": "soft", "amount": 5 if side < 0 else 4, "lifetime": 1.2, "life_random": 0.4,
			"one_shot": true, "explosiveness": 0.9, "emitting": false, "texture": "disc11", "at": Vector2(side * 6.0, -2.5),
			"emit": {"box": Vector2(4, 1.5)}, "dir": -4.0 if side > 0 else 184.0, "spread": 5.0, "speed": [50.0, 130.0],
			"gravity": Vector2(0, -23), "drag": 1.4, "scale": [0.6, 1.0], "scale_curve": [[0.0, 0.5], [0.4, 1.05], [1.0, 1.45]], "ramp": smoke_r})
		emit(sm, HIT)
	var lift_c := dust.lerp(C[5], 0.25)
	var lift_r := gradient([Color(lift_c, 0.0), Color(lift_c, 0.45), Color(Color("#5d5660"), 0.4), Color(Color("#433d48"), 0.25), Color(Color("#433d48"), 0.0)],
		[0.0, 0.08, 0.4, 0.75, 1.0], true)
	var lift := particles("Smoke", {"layer": "soft", "amount": 4, "lifetime": 1.8, "life_random": 0.33, "one_shot": true, "explosiveness": 0.3,
		"emitting": false, "texture": "disc11", "at": Vector2(0, -5), "emit": {"box": Vector2(4, 3)}, "dir": -90.0, "spread": 15.0,
		"speed": [20.0, 45.0], "gravity": Vector2(0, -16), "drag": 1.2, "scale": [0.7, 1.0], "scale_curve": [[0.0, 0.5], [0.4, 1.05], [1.0, 1.45]], "ramp": lift_r})
	emit(lift, HIT + 0.05)

	# ---- the cracks spit embers and stars while they're hot
	var cpts := PackedVector2Array()
	for c in cracks:
		for q in c.pts:
			cpts.append(q + Vector2(0, -1))
	var em_o := {"amount": 40, "lifetime": 0.9, "life_random": 0.45, "emit": {"points": cpts}, "dir": -90.0, "spread": 15.0,
		"speed": [15.0, 35.0], "gravity": Vector2(0, -30), "drag": 1.6, "texture": "dot1",
		"ramp": gradient([Color.WHITE, C[6], C[5]], [0.0, 0.4, 0.7]), "turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.025]},
		"emitting": false, "preprocess": 0.0}
	var em := particles("Embers", em_o)
	emit(em, HIT, HIT + 1.3)
	var eml := particles("EmberLight", em_o.merged({"texture": "glow8", "layer": "light", "modulate": Color(1, 1, 1, 0.35)}))
	emit(eml, HIT, HIT + 1.3)
	var cst := star_particles("CrackStars", 1.3, Color.WHITE, tipw, {"amount": 9, "lifetime": 0.6, "life_random": 0.5, "one_shot": false,
		"explosiveness": 0.0, "emit": {"points": cpts}, "dir": -90.0, "speed": [4.0, 12.0], "preprocess": 0.0})
	emit(cst, HIT, HIT + 1.3)


static func _in_out_cubic(x: float) -> float:
	return 4.0 * x * x * x if x < 0.5 else 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


## A chip of stone (the original's chip()): an outlined, lit and shaded disc of radius 0.6 + s * 0.7.
func _chip(s: int, st: Array) -> Image:
	var r := 0.6 + s * 0.7
	var n := int(ceilf(r + 1.0)) * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c0 := n / 2.0
	var outline := Color("#1a1422")
	keep_colour(outline)
	for c in st:
		keep_colour(c)
	var lx := r * 0.4
	for y in n:
		for x in n:
			var dx := x + 0.5 - c0
			var dy := y + 0.5 - c0
			var d := Vector2(dx * 1.2, dy).length()
			if d > r + 0.9:
				continue
			var lit := dx * lx
			img.set_pixel(x, y, outline if d > r else (st[3] if lit < -0.3 else (st[1] if lit > 0.5 else st[2])))
	return img


## Bake the cracks (the original's drawing order: each crack, then its fork; a deeper lower edge near the heart)
## into a data texture for fx/holy/_smite_cracks.gdshader, and their glows for fx/holy/_smite_cracklight.gdshader.
func _cracks(cracks: Array) -> void:
	var px := {}
	var glows := []
	for c in cracks:
		var paths := [c.pts]
		if c.fork.size() > 0:
			paths.append(c.fork)
		for pi in paths.size():
			var path: PackedVector2Array = paths[pi]
			var last := path.size() - 1
			for i in last:
				var p0 := path[i]
				var p1 := path[i + 1]
				var d := Vector2(p0.x, p0.y / SY).length() / float(c.L)
				var b := 0.0 if i == 0 else (i + 0.5) / float(last)
				_raster(px, p0, p1, Color(d / 2.0, float(c.cool) - 1.5, b, 1.0))
				if d < 0.45 and pi == 0:
					_raster(px, p0 + Vector2(0, 1), p1 + Vector2(0, 1), Color(d / 2.0, float(c.cool) - 1.5, b, 0.5))
				if i % 2 == 0:
					glows.append(Vector4(p0.x, p0.y, d, float(c.cool)))
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for q in px:
		lo = Vector2i(mini(lo.x, q.x), mini(lo.y, q.y))
		hi = Vector2i(maxi(hi.x, q.x), maxi(hi.y, q.y))
	lo = Vector2i(mini(lo.x, -6), mini(lo.y, -3))
	hi = Vector2i(maxi(hi.x, 6), maxi(hi.y, 3))
	var sz := hi - lo + Vector2i.ONE
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	for q in px:
		img.set_pixel(q.x - lo.x, q.y - lo.y, px[q])
	var cr := shape("Cracks", holy_shader("smite_cracks"), Vector2(sz), {"data": asset("cracks.png", img), "lo": Vector2(lo), "pal": C},
		{"at": Vector2(lo) + Vector2(sz) / 2.0, "back": true})
	var tk := [[0.0, -1.0], [HIT - 0.001, -1.0], [HIT, 0.0], [root.duration, root.duration - HIT]]
	key(cr, "material:shader_parameter/t", tk)
	keyn(cr, "material:shader_parameter/grow", func(t: float) -> float: return out_cubic(seg(t, HIT, HIT + 0.1)), HIT - 0.04, HIT + 0.15)
	var pts := PackedVector4Array()
	for q in glows:
		pts.append(q)
	var lsz := Vector2(sz) + Vector2(24, 24)
	var cl := shape("CrackLight", holy_shader("smite_cracklight"), lsz, {"pts": pts, "count": glows.size(), "c4": C[4]},
		{"at": Vector2(lo) + Vector2(sz) / 2.0, "back": true})
	key(cl, "material:shader_parameter/t", tk)


## The original's line(): Bresenham between the cells of a and b, writing v on each.
static func _raster(px: Dictionary, a: Vector2, b: Vector2, v: Color) -> void:
	var sx := floori(a.x)
	var sy := floori(a.y)
	var ex := floori(b.x)
	var ey := floori(b.y)
	var dx := absi(ex - sx)
	var dy := -absi(ey - sy)
	var stx := 1 if sx < ex else -1
	var sty := 1 if sy < ey else -1
	var err := dx + dy
	while true:
		px[Vector2i(sx, sy)] = v
		if sx == ex and sy == ey:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			sx += stx
		if e2 <= dx:
			err += dx
			sy += sty
