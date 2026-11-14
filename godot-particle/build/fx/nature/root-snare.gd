# reimagined-from: src/fx/nature/root-snare.js@e5516f80b0ce27b1cc30fe10dde750b526be1864
# Root snare: The floor cracks and roots burst up round the character, spiralling round its legs; they cinch tight with
# a snap, hold, then crack and crumble into bark and dust.
# The five roots are a shader of their own (fx/nature/_roots.gdshader: the original's bark strokes along the
# original's spiral paths, from its seeded numbers via build/fx/nature/_lib_wind.gd), one pass behind the character
# for the far side of each turn and one in front, each root's growth and the cinch keyed from the original's curves;
# buds open into little leaves (build-time leaf textures, keyed along the roots). Two cracks run out from the feet
# glowing green (Line2D). Particles: grit and bark chips bursting where each root breaks the floor, dust and stars as
# they cinch, green motes while they hold, then the roots crumble into bark chips (emitted along their paths) that
# bounce on a collision floor, grit and dust; the light swells and flickers with them.
# one-shot, 2.70 s, 128x96 canvas, origin [64, 78], backdrop ground, stand-in 2
extends "res://addons/pixelfx_particles/core/build.gd"

const N := preload("res://build/fx/nature/_lib.gd")
const W := preload("res://build/fx/nature/_lib_wind.gd")
const ROOTS := preload("res://addons/pixelfx_particles/fx/nature/_roots.gdshader")
const BARK_SHADER := preload("res://addons/pixelfx_particles/fx/nature/_bark.gdshader")
const SY := 0.34
const CINCH := 0.62
const BREAK := 1.75
const NP := 48

var roots := []


func path(r: Dictionary, cinch: float) -> Array:
	var pts := []
	for i in NP + 1:
		var s := i / float(NP)
		var th: float = r.th0 + r.dir * TAU * r.turns * s
		var rad: float = lerpf(r.r0, r.leg - cinch * 1.6, N.out_cubic(minf(1.0, s * 3.5)))
		pts.append(Vector3(cos(th) * rad, -r.h * pow(s, 1.05) + sin(th) * rad * SY, sin(th)))
	return pts


static func squeeze(t: float) -> float:
	return N.smooth(CINCH - 0.03, CINCH + 0.05, t) * (1.0 - 0.4 * N.smooth(CINCH + 0.05, CINCH + 0.25, t))


## Chips thrown off with the original's numbers ([[launch (x, y, vx, vy), spin (a0, va, scale, life)], ...]): a
## one-shot emitter running fx/nature/_bark.gdshader (they fly, bounce once and lie still on the floor).
func bark(name: String, chips: Array, tex: Texture2D) -> GPUParticles2D:
	var life := 0.0
	var la := PackedVector4Array()
	var sp := PackedVector4Array()
	for c in chips:
		la.append(c[0])
		sp.append(c[1])
		life = maxf(life, c[1].w)
	var p := particles(name, {"amount": chips.size(), "lifetime": life + 0.02, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": tex, "local": true})
	var m := ShaderMaterial.new()
	m.shader = BARK_SHADER
	m.set_shader_parameter("launch", la)
	m.set_shader_parameter("spin", sp)
	p.process_material = m
	return p


## A light that flares and dies (the core's Lights): radius r * (0.55 + 0.45 k), strength k0 * k * k.
func flare(name: String, at: Vector2, r: float, c: Color, k0: float, t0: float, life: float) -> void:
	var g := glow(name, r + 2, {"radius": r, "color": c, "alpha": 0.0}, {"at": at})
	var a := [[0.0, 0.0], [maxf(0.0, t0 - 0.001), 0.0]]
	var rr := []
	for i in 7:
		var k := 1.0 - i / 6.0
		a.append([t0 + life * i / 6.0, k0 * k * k])
		rr.append([t0 + life * i / 6.0, r * (0.55 + 0.45 * k)])
	key(g, "material:shader_parameter/alpha", a)
	key(g, "material:shader_parameter/radius", rr)


func make() -> void:
	ground()
	var C: PackedColorArray = root.ramps.palette
	var G: PackedColorArray = root.ramps.glow
	var D: float = meta.duration
	keep_colour(Color.WHITE)
	var BARK := PackedColorArray([C[0], C[1], C[2], C[2], C[3], C[4], C[5]])

	# the original's roots and cracks, rolled from its seed in its order
	var R := W.Rng.new(int(meta.options.seed))
	for i in 5:
		var r := {}
		r.th0 = i / 5.0 * TAU + R.range(-0.3, 0.3)
		r.dir = 1.0 if i % 2 else -1.0
		r.turns = R.range(1.1, 1.6)
		r.r0 = R.range(14, 19)
		r.leg = R.range(8, 10)
		r.h = R.range(13, 21)
		r.at = 0.16 + i * 0.07 + R.range(0, 0.04)
		r.buds = [R.range(0.35, 0.55), R.range(0.6, 0.85)]
		roots.append(r)
	var cracks := []
	for side in [-1.0, 1.0]:
		var length := R.range(18, 26)
		var pts := [Vector2.ZERO]
		var x := 0.0
		while absf(x) < length:
			x += side * R.range(2, 5)
			pts.append(Vector2(x, R.int_(0, 2)))
		cracks.append(pts)

	# the cracks running out from the feet, a mossy light seeping up out of them
	var ck := 0
	for c in cracks:
		var lo := line("CrackShadow%d" % ck, PackedVector2Array([Vector2(0, 1), Vector2(0, 1)]), {"color": C[0], "back": true})
		var hi := line("Crack%d" % ck, PackedVector2Array([Vector2.ZERO, Vector2.ZERO]), {"color": C[1], "back": true})
		var lo_k := []
		var hi_k := []
		var col_k := []
		for f in 9:
			var t := f / 30.0
			var m := maxi(2, int(ceil(c.size() * N.out_cubic(t / 0.25))))
			var seg := PackedVector2Array(c.slice(0, m))
			hi_k.append([t, seg])
			var low := PackedVector2Array()
			for p in seg:
				low.append(p + Vector2(0, 1))
			lo_k.append([t, low])
		for f in 46:
			var t := f / 30.0
			var hot := N.smooth(0.0, 0.3, t) * (1.0 - N.smooth(0.5, 1.4, t))
			col_k.append([t, G[3] if hot > 0.5 else G[2] if hot > 0.2 else C[1]])
		key(lo, "points", lo_k, "nearest")
		key(hi, "points", hi_k, "nearest")
		key(hi, "default_color", col_k, "nearest")
		for n in [lo, hi]:
			key(n, "modulate:a", [[0.0, 1.0], [D - 0.6, 1.0], [D - 0.15, 0.0]])
		for k in range(2, c.size(), 2):
			var cg := glow("CrackLight%d_%d" % [ck, k], 8, {"radius": 6, "color": G[2], "alpha": 0.0}, {"at": c[k]})
			var a := []
			for f in 31:
				var t := f / 20.0
				var hot := N.smooth(0.0, 0.3, t) * (1.0 - N.smooth(0.5, 1.4, t))
				a.append([t, 0.3 * hot if t > k / float(c.size()) * 0.25 else 0.0])
			key(cg, "material:shader_parameter/alpha", a)
		ck += 1

	# the hold: light swelling round the legs, flickering
	var hold1 := glow("Hold", 32, {"radius": 30, "color": G[2], "alpha": 0.0}, {"at": Vector2(0, -12)})
	var hold2 := glow("HoldFeet", 24, {"radius": 22, "color": G[3], "alpha": 0.0}, {"at": Vector2(0, -1)})
	var h1 := []
	var h2 := []
	for f in int(D * 30) + 1:
		var t := f / 30.0
		var hold := N.smooth(0.3, CINCH, t) * (1.0 - N.smooth(BREAK, BREAK + 0.3, t)) * (0.8 + 0.2 * sin(t * 8.0))
		h1.append([t, 0.3 * hold])
		h2.append([t, 0.16 * hold])
	key(hold1, "material:shader_parameter/alpha", h1)
	key(hold2, "material:shader_parameter/alpha", h2)

	# the roots: far side behind the character, near side in front
	var ra := PackedVector4Array()
	var rb := PackedVector4Array()
	for r in roots:
		ra.append(Vector4(r.th0, r.dir, r.turns, r.r0))
		rb.append(Vector4(r.leg, r.h, 0, 0))
	var grain := Image.create(41, 1, false, Image.FORMAT_RGBA8)
	for k in 41:
		var v := W.rand([k, 3])
		grain.set_pixel(k, 0, Color(v, v, v, 1))
	var pal := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	for k in 8:
		pal.set_pixel(k, 0, C[k])
	var params := {"root_a": ra, "root_b": rb, "pal": ImageTexture.create_from_image(pal),
		"grain": ImageTexture.create_from_image(grain), "squeeze": 0.0, "white": 0.0}
	var sq := []
	for f in 31:
		var t := CINCH - 0.05 + f / 60.0
		sq.append([t, squeeze(t)])
	var leaf_frames := []
	for k in 5:
		leaf_frames.append(N.leaf_image((k + 1) * 1.0, 1.6, 0.3, [G[0], G[1], G[2], G[3]], -0.6))
	var leaf_tex := N.strip(leaf_frames)
	# behind: every root's far side in one pass; in front: each root's near side, then its buds, root by root
	var passes := [[-1.0, -1]]
	for i in 5:
		passes.append([1.0, i])
	passes.append([2.0, -1])
	for ps in passes:
		var s: float = ps[0]
		var only: int = ps[1]
		var pr := params.duplicate()
		pr.side = minf(s, 1.0)
		pr.only = float(only)
		pr.white_only = 1.0 if s > 1.5 else 0.0
		var n := shape("RootsBack" if s < 0 else "RootsFlash" if s > 1.5 else "RootFront%d" % only, ROOTS, Vector2(64, 48), pr, {"at": Vector2(0, -16), "back": s < 0})
		for i in 5:
			if only >= 0 and i != only:
				continue
			var r: Dictionary = roots[i]
			var gk := [[0.0, 0.0], [r.at, 0.0]]
			for f in 21:
				var t: float = r.at + f / 60.0
				gk.append([t, N.out_cubic((t - r.at) / 0.32)])
			key(n, "material:shader_parameter/g%d" % i, gk)
		key(n, "material:shader_parameter/squeeze", sq)
		if s > 1.5:
			key(n, "material:shader_parameter/white", [[0.0, 0.0], [BREAK - 0.045, 1.0], [BREAK, 0.0]], "nearest")
		show(n, 0.0, BREAK)
		if s < 0 or s > 1.5:
			continue
		# its buds opening into small leaves once it has hold
		var r: Dictionary = roots[only]
		var bi := 0
		for b in r.buds:
			var q: Vector3 = path(r, 1.0)[int(floor(b * NP))]
			if q.z < 0.0:
				continue
			var bud := sprite("Bud%d_%d" % [only, bi], leaf_tex, {"hframes": 5})
			var t0: float = CINCH + 0.1 + b * 0.2
			var fr := []
			var pos := []
			var rot := []
			var t := t0
			while t < BREAK:
				var lk := clampf((t - t0) / 0.25, 0.0, 1.0)
				var qq: Vector3 = path(r, squeeze(t))[int(floor(b * NP))]
				fr.append([t, clampi(int(roundf(lk * 5.0)) - 1, 0, 4)])
				pos.append([t, Vector2(roundf(qq.x + 2), roundf(qq.y - 2))])
				rot.append([t, sin(t * 5.0 + b * 9.0) * 0.2])
				t += 1.0 / 30.0
			key(bud, "frame", fr, "nearest")
			key(bud, "position", pos, "nearest")
			key(bud, "rotation", rot)
			show(bud, t0 + 0.02, BREAK)
			bi += 1

	# where each root breaks the floor: bark chips, dust, a little green light
	var chip_tex := N.rock(17, 1.6, BARK)
	var dust := Color(C[5])
	var puff := gradient([Color(dust, 0.7), Color(dust, 0.5), Color(dust, 0.3), Color(dust, 0.1)])
	var CR := W.Rng.new(71)
	var i := 0
	for r in roots:
		var x: float = cos(r.th0) * r.r0
		var cl := []
		for k in 4:
			cl.append([Vector4(x, -1, CR.range(-60, 60), -CR.range(60, 160)), Vector4(CR.range(0, TAU), CR.range(-15, 15), CR.range(1.2, 2.0) / 1.6, CR.range(0.6, 0.9))])
		var chips := bark("Chips%d" % i, cl, chip_tex)
		emit(chips, r.at)
		var dp := particles("BurstDust%d" % i, {"layer": "soft", "back": true, "at": Vector2(x, -1), "amount": 3, "lifetime": 0.6,
			"one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "disc7", "dir": -90, "spread": 80,
			"speed": [8, 28], "damping": [30, 60], "scale_curve": [[0, 0.5], [1, 1.1]], "ramp": puff})
		emit(dp, r.at)
		flare("BurstLight%d" % i, Vector2(x, -4), 20, G[2], 0.35, r.at, 0.3)
		i += 1
	for sd in [-1, 1]:
		var grit := particles("Grit%s" % ("L" if sd < 0 else "R"), {"at": Vector2(sd * 13, -1), "amount": 3, "lifetime": 0.7,
			"emitting": false, "texture": "dot1", "emit": {"box": Vector2(9, 0.5)}, "dir": -90, "spread": 18,
			"speed": [30, 90], "gravity": Vector2(0, 950), "initial": gradient([C[5], C[4]]),
			"collide": {"bounce": 0.1, "friction": 1.0}})
		emit(grit, 0.0, 0.4)

	# the cinch: a snap of light, sparkles, dust kicked out, green stars
	flare("CinchLight", Vector2(0, -10), 40, G[3], 0.5, CINCH, 0.3)
	flare("CinchWhite", Vector2(0, -10), 16, Color.WHITE, 0.4, CINCH, 0.06)
	var spark := gradient([G[3], C[7], C[7], G[3]], [0.0, 0.2, 0.8, 1.0])
	var sk := 0
	for at in [Vector2(-8, -6), Vector2(8, -10), Vector2(-7, -15)]:
		for f in 4:
			var e := f / 30.0
			var arm := roundf(5.0 * (1.0 - e / 0.12))
			if arm < 1.0:
				continue
			for ax in [Vector2(1, 0), Vector2(0, 1)]:
				var sl := line("Snap%d_%d%s" % [sk, f, "H" if ax.x > 0 else "V"], PackedVector2Array([at - ax * arm, at + ax * (arm + 1)]), {"gradient": spark})
				show(sl, CINCH + e, CINCH + e + 1.0 / 30.0)
		var sg := glow("SnapLight%d" % sk, 16, {"radius": 14, "color": C[7], "alpha": 0.0}, {"at": at})
		key(sg, "material:shader_parameter/alpha", [[0.0, 0.0], [CINCH - 0.001, 0.0], [CINCH, 0.4], [CINCH + 0.12, 0.0]])
		sk += 1
	for sd in [-1, 1]:
		var cd := particles("CinchDust%s" % ("L" if sd < 0 else "R"), {"layer": "soft", "back": true, "at": Vector2(sd * 6, -2),
			"amount": 4, "lifetime": 0.75, "randomness": 0.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
			"texture": "disc7", "emit": {"box": Vector2(6, 2)}, "dir": 90 - sd * 90 - sd * 10, "spread": 10,
			"speed": [20, 60], "damping": [40, 80], "scale_curve": [[0, 0.6], [1, 1.2]], "ramp": puff})
		emit(cd, CINCH)
	var stars := particles("Stars", {"at": Vector2(0, -12), "amount": 6, "lifetime": 0.4, "randomness": 0.3, "one_shot": true,
		"explosiveness": 0.8, "emitting": false, "texture": "plus3", "emit": {"box": Vector2(9, 8)}, "speed": [4, 4],
		"color": G[3], "alpha_curve": [[0, 1], [0.6, 0.8], [1, 0]]})
	emit(stars, CINCH)
	var motes := particles("Motes", {"at": Vector2(0, -10), "amount": 3, "lifetime": 0.7, "randomness": 0.3, "emitting": false,
		"texture": "dot1", "emit": {"box": Vector2(9, 7)}, "dir": -90, "spread": 15, "speed": [14, 30], "color": G[3],
		"alpha_curve": [[0, 0], [0.2, 1], [1, 1]]})
	emit(motes, CINCH, BREAK)
	var mote_light := particles("MoteLight", {"layer": "light", "at": Vector2(0, -10), "amount": 3, "lifetime": 0.7, "randomness": 0.3,
		"emitting": false, "texture": "glow8", "emit": {"box": Vector2(9, 7)}, "dir": -90, "spread": 15, "speed": [14, 30],
		"color": Color(G[3], 0.4), "alpha_curve": [[0, 1], [1, 0]]})
	emit(mote_light, CINCH, BREAK)

	# the break: every root crumbles into bark chips along its length, grit and dust
	flare("BreakLight", Vector2(0, -10), 36, G[2], 0.4, BREAK, 0.25)
	var big := []
	var small := []
	for r in roots:
		var pts := path(r, 1.0)
		for k in range(2, NP, 4):
			var q: Vector3 = pts[k]
			var w := 1.4 + 3.6 * pow(1.0 - k / float(NP), 0.8)
			var sz := clampf(w * 0.75, 1.5, 3.0)
			var sg := signf(q.x) if q.x != 0.0 else 1.0
			var lv := Vector4(q.x, minf(q.y, -1.0), sg * CR.range(25, 85) + q.x * 3.0, -CR.range(50, 150))
			var sv := Vector4(CR.range(0, TAU), CR.range(-10, 10), sz, minf(CR.range(0.7, 0.95), D - 0.05 - BREAK))
			if sz > 2.2:
				sv.z = sz / 2.7
				big.append([lv, sv])
			else:
				sv.z = sz / 1.7
				small.append([lv, sv])
	emit(bark("BarkBig", big, N.rock(23, 2.7, BARK)), BREAK)
	emit(bark("BarkSmall", small, N.rock(29, 1.7, BARK)), BREAK)
	var bgrit := particles("BreakGrit", {"at": Vector2(0, -8), "amount": 15, "lifetime": 0.8, "randomness": 0.2, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "dot1", "emit": {"box": Vector2(14, 7)}, "dir": -90, "spread": 50,
		"speed": [30, 90], "gravity": Vector2(0, 950), "initial": gradient([C[4], C[3], C[2]]),
		"collide": {"bounce": 0.1, "friction": 1.0}})
	emit(bgrit, BREAK)
	var smoke := gradient([Color(dust, 0.0), Color(dust, 0.6), Color(dust.lerp(Color("#5d5660"), 0.4), 0.45),
		Color(Color("#433d48"), 0.25), Color(Color("#433d48"), 0.0)], [0.0, 0.08, 0.4, 0.75, 0.95])
	var bsmoke := particles("BreakDust", {"layer": "soft", "back": true, "at": Vector2(0, -9), "amount": 10, "lifetime": 0.85,
		"randomness": 0.2, "one_shot": true, "explosiveness": 1.0, "emitting": false, "texture": "disc9",
		"emit": {"box": Vector2(12, 7)}, "dir": -90, "spread": 80, "speed": [8, 30], "damping": [20, 40],
		"gravity": Vector2(0, -16), "scale": [0.7, 1.1], "scale_curve": [[0, 0.7], [1, 1.4]], "ramp": smoke})
	emit(bsmoke, BREAK)
