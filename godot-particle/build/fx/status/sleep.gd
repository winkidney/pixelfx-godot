# reimagined-from: src/fx/status/sleep.js@c0048fcc7b959011fccee93dce8a5ed24be3f213
# Sleep: Fast asleep: eyes shut, soft outlined Zs float up off the head one after another, swaying and growing as they rise, dream motes drift, a slow breathing glow.
# loop, 2.40 s, 60x82 canvas, origin [26.0, 74.0], backdrop ground, stand-in 2
# ramp palette: #1a1636 #3c3a7a #6f78c8 #a9b8f0 #dfe6ff #ffffff
# The eyes are painted shut (a still mark over the stand-in). Three Zs (the original's shaded, outlined icons at four
# sizes, young and old, as frames of one strip) ride the original's path, sampled into keys, a dotted trail of
# three dots behind each, the young on top; each pops into a burst of motes (a one-shot emitter) at the end of its
# life. Dream motes drift up (an emitter, with a light twin), soft dream light wanders (glows replaying the
# original's cycle), and a breathing glow swells round the head.
extends "res://build/fx/status/_status.gd"

const NZ := 3
const ZS := [
	["#####", "...#.", "..#..", ".#...", "#####"],
	["#######", ".....#.", "....#..", "...#...", "..#....", ".#.....", "#######"],
	[".#######.", "#########", "......##.", ".....##..", "....##...", "...##....", "..##.....", "#########", ".#######."],
	[".#########.", "###########", ".......###.", "......###..", ".....###...", "....###....", "...###.....", "..###......", ".###.......", "###########", ".#########."],
]
const LIGHT_Z := 5   # light nodes sit over the Zs (which take z 1..3 by age)

var D := 2.4


## a Z at age u (0..1): where it is, how big, how solid (sleep.js zAt)
func z_at(i: int, u: float) -> Dictionary:
	var side := 1.0 if i % 2 else 0.6
	var x0 := AX + AW * 0.78
	var y0 := AY + 7.0
	var x := x0 + 13.0 * side * u + 2.5 * sin(TAU * 1.1 * u + i * 2.1)
	var y := y0 - 32.0 * (1.0 - pow(1.0 - u, 1.35))
	var size := 0 if u < 0.18 else (1 if u < 0.42 else (2 if u < 0.68 else 3))
	return {"x": x, "y": y, "size": size, "k": minf(1.0, u / 0.06)}


func make() -> void:
	D = root.duration
	var C := fit("palette", 6)
	var seed_: int = int(meta.options.seed)

	# eyes shut: painted over with skin, a soft ink lid line
	var lids := {}
	for e in eyes():
		for q in e.px:
			lids[Vector2i(AX + q.x, AY + q.y)] = e.skin
		var y: int = AY + e.y1 - 1
		for x in range(e.x0, e.x1 + 1):
			lids[Vector2i(AX + x, y)] = INK
		lids[Vector2i(AX + e.x0 - 1, y - 1)] = INK
		lids[Vector2i(AX + e.x1 + 1, y - 1)] = INK
	pixels("Lids", lids, {"layer": "prop"})

	# a slow breathing glow round the head
	var breath := glow("Breath", 26, {"radius": 24, "color": C[3], "alpha": 0.1}, {"at": Vector2(0, AY + 10)})
	breath.z_index = LIGHT_Z
	sample(breath, "material:shader_parameter/alpha", func(t: float) -> float: return 0.1 + 0.1 * (0.5 + 0.5 * sin(t / D * TAU * 2.0)), "linear")

	# soft dream light wandering about the head: the original's five, replayed
	var dream := []
	for i in 5:
		var g := glow("Dream%d" % i, 14, {"radius": 8, "color": C[3], "alpha": 0.0})
		g.z_index = LIGHT_Z
		dream.append({"node": g, "pos": [], "rad": [], "a": []})
	for t in frame_times():
		var seen := {}
		cycle(t, D, 5, seed_ + 6, D, func(age: float, life: float, r: Rng, i: int) -> void:
			var u := age / life
			var x := AX + AW * r.range(0.3, 1.1) + sin(u * TAU + r.next() * TAU) * 3.0
			var y := AY + r.range(-6, 8) - u * 10.0
			var rad := r.range(3, 5) * (0.8 + 0.4 * u)
			dream[i].pos.append([t, Vector2(x, y)])
			dream[i].rad.append([t, rad * 2.4])
			dream[i].a.append([t, 0.1 * sin(PI * u)])
			seen[i] = true)
		for i in 5:
			if not seen.has(i):
				dream[i].a.append([t, 0.0])
	for d in dream:
		key(d.node, "position", d.pos)
		key(d.node, "material:shader_parameter/radius", d.rad)
		key(d.node, "material:shader_parameter/alpha", d.a)

	# dream motes drifting up, twinkling, a glow on each
	var mote := {"at": Vector2(AX + AW * 0.75, AY + 5), "amount": 10, "lifetime": 1.6, "life_random": 0.25, "texture": "dot1",
		"emit": {"box": Vector2(8.4, 5)}, "dir": -90, "spread": 6, "speed": [10, 18],
		"ramp": gradient([C[4], C[5], C[4]], [0.0, 0.3, 0.7]),
		"alpha_curve": [[0, 0.0], [0.12, 0.5], [0.5, 1.0], [0.88, 0.5], [1, 0.0]],
		"turbulence": {"strength": 1.0, "scale": 3.0, "influence": [0.01, 0.02]}}
	particles("Motes", mote)
	# now and then one flares into a little cross with a glow (the original's sparkle at arm 1)
	var tw_o := {"at": Vector2(AX + AW * 0.75, AY - 7), "amount": 1, "lifetime": 0.8, "texture": "plus3",
		"emit": {"box": Vector2(8.4, 6)}, "dir": -90, "speed": [10, 18], "color": C[4],
		"alpha_curve": [[0, 0.0], [0.45, 0.0], [0.46, 1.0], [0.8, 1.0], [0.81, 0.0], [1, 0.0]]}
	var tw := particles("Twinkle", tw_o)
	var twl_o := tw_o.duplicate()
	twl_o.layer = "light"
	var twl := particles("TwinkleLight", twl_o)
	twl.texture = texture("glow16")
	twl.seed = tw.seed
	twl.modulate = Color(C[3], 0.3)
	twl.z_index = LIGHT_Z

	# the Zs: a strip of young (lit) and old (dimmed down the ramp) frames at four sizes each
	var imgs := []
	for old in [false, true]:
		var R: Array = [C[0], C[1], C[2], C[3]] if old else [C[1], C[2], C[3], C[4]]
		for s in 4:
			imgs.append(icon_image(bitmap(ZS[s]), 7, R))
	var Z := []
	for i in NZ:
		var n := {}
		n.z = icon_strip("Z%d" % i, imgs, {"file": "_zs%d" % i})
		n.hl = pixels("Shine%d" % i, {Vector2i(0, 0): C[5]})
		n.trail = []
		for j in 3:
			n.trail.append(pixels("Trail%d_%d" % [i, j], {Vector2i(0, 0): C[3]}))
		n.glow = glow("ZGlow%d" % i, 18, {"radius": 7, "color": C[3], "alpha": 0.0})
		n.glow.z_index = LIGHT_Z
		n.K = {"zp": [], "zf": [], "zv": [], "za": [], "zz": [], "hp": [], "hv": [], "gp": [], "gr": [], "ga": [], "tp": [[], [], []], "tv": [[], [], []]}
		# it pops into a ring of seven motes at the end of its life
		n.pop = []
		for j in 7:
			n.pop.append(pixels("Pop%d_%d" % [i, j], {Vector2i(0, 0): C[4] if j % 2 else C[5]}))
		n.K.pp = [[], [], [], [], [], [], []]
		n.K.pv = []
		n.K.pa = []
		Z.append(n)
	for t in frame_times():
		var order := []
		for i in NZ:
			order.append([fposmod(t - i * D / NZ, D) / D, i])
		order.sort()   # youngest first
		for rank in NZ:
			var u: float = order[rank][0]
			var i: int = order[rank][1]
			var n: Dictionary = Z[i]
			var K: Dictionary = n.K
			var z := z_at(i, u)
			K.zz.append([t, NZ - rank])   # youngest on top
			if u > 0.9:
				var k := (u - 0.9) / 0.1
				K.zv.append([t, false])
				K.hv.append([t, false])
				for j in 3:
					K.tv[j].append([t, false])
				K.pv.append([t, true])
				K.pa.append([t, 1.2 - k])
				for j in 7:
					var an := j / 7.0 * TAU + i
					var d := 3.0 + 6.0 * sqrt(k)
					K.pp[j].append([t, Vector2(floorf(z.x + cos(an) * d), floorf(z.y + sin(an) * d * 0.8))])
				K.gp.append([t, Vector2(z.x, z.y)])
				K.gr.append([t, 10.0])
				K.ga.append([t, 0.25 * (1.0 - k)])
				continue
			K.pv.append([t, false])
			var old := u > 0.78
			var X := jround(z.x)
			var Y := jround(z.y)
			K.zv.append([t, true])
			K.zp.append([t, Vector2(X, Y)])
			K.zf.append([t, int(z.size) + (4 if old else 0)])
			K.za.append([t, z.k])
			K.hv.append([t, not old])
			K.hp.append([t, Vector2(floorf(z.x - 2 - z.size), floorf(z.y - 2 - z.size * 0.8))])
			# the dotted trail where it has been
			for j in 3:
				var jj := 2 * j + 1
				var uu := u - jj * 0.025
				if uu < 0.05:
					K.tv[j].append([t, false])
					continue
				var q := z_at(i, maxf(0.0, uu))
				K.tv[j].append([t, true])
				K.tp[j].append([t, Vector2(floorf(q.x - 1), floorf(q.y + 4 + q.size))])
			K.gp.append([t, Vector2(z.x, z.y)])
			K.gr.append([t, 7.0 + z.size * 3.0])
			K.ga.append([t, (0.12 if old else 0.26) * z.k])
	for n in Z:
		var K: Dictionary = n.K
		key(n.z, "visible", K.zv, "nearest")
		key(n.z, "position", K.zp, "nearest")
		key(n.z, "frame", K.zf, "nearest")
		key(n.z, "modulate:a", K.za, "nearest")
		key(n.z, "z_index", K.zz, "nearest")
		key(n.hl, "visible", K.hv, "nearest")
		key(n.hl, "position", K.hp, "nearest")
		key(n.hl, "z_index", K.zz, "nearest")
		for j in 3:
			key(n.trail[j], "visible", K.tv[j], "nearest")
			key(n.trail[j], "position", K.tp[j], "nearest")
			n.trail[j].modulate.a = (1.0 - (2 * j + 1) / 7.0) * 0.9
		for j in 7:
			key(n.pop[j], "visible", K.pv, "nearest")
			key(n.pop[j], "position", K.pp[j], "nearest")
			key(n.pop[j], "modulate:a", K.pa, "nearest")
		key(n.glow, "position", K.gp, "nearest")
		key(n.glow, "material:shader_parameter/radius", K.gr, "nearest")
		key(n.glow, "material:shader_parameter/alpha", K.ga, "nearest")
