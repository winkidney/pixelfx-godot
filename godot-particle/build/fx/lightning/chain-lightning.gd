# reimagined-from: src/fx/lightning/chain-lightning.js@3600eb2a1e914fe08e478758092f95d28c70086e
# Chain lightning: A bolt leaps from the caster's hand through three targets in turn; each flashes, sparks and grounds itself to the floor while the arcs between them flicker, then the chain snaps.
# one-shot, 1.80 s, 248x104 canvas, origin [40.0, 82.0], backdrop ground, stand-in 2
# Every link is a bowed layered bolt (fx/lightning/_volt.gd): it races out from the last node with a hot head, then
# hums on the original's level curve, re-struck every other frame, stutters out and leaves a dotted trace that
# cools and goes. The hand and each target are stacked discs that swell with the current, crackles crawl over them
# and ground out to the floor; each hit flares light, throws sparks (and hot ones), a glint and smoke, the links
# shed sparks while they hold, the floor scorches (fx/lightning/_scorch.gdshader) where each target grounds, and
# each target pops once more as its link gives out.
extends "res://build/fx/lightning/_base.gd"

const HAND := Vector2(10, -16)
const HOPS := [Vector2(58, -22), Vector2(104, -30), Vector2(150, -19)]
const WIND := 0.12
const LEAP := 0.05
const GAP := 0.075
const HOLD := 0.78
const BREAK := 0.16
const NF := 55


static func on_t(i: int) -> float:
	return WIND + i * GAP + LEAP


static func off_t(i: int) -> float:
	return HOLD + i * 0.05


static func level(i: int, t: float) -> float:
	var a := t - on_t(i)
	if a < 0.0:
		return 0.0
	var hum: float = ([1.0, 0.55, 1.0][int(floor(a * 30.0))] if int(floor(a * 30.0)) < 3 else 1.0) if a < 0.1 else 0.78 + 0.22 * sin(t * 61.0 + i) * sin(t * 23.0 + i * 2)
	var b := t - off_t(i)
	if b < 0.0:
		return hum
	if b < BREAK:
		return hum * (1.0 - b / BREAK) * (0.5 if int(floor(b * 60.0)) % 3 == 1 else 1.0)
	return 0.0


func make() -> void:
	ground()
	var C := pal()
	var R := RandomNumberGenerator.new()
	R.seed = 3
	var pts := [HAND] + HOPS
	var grounds := []
	for h in HOPS:
		grounds.append(roundf(h.x + R.randf_range(-5, 5)))

	# the floor scorches where the targets ground themselves
	for i in 3:
		var sc := scorch("Scorch%d" % i, grounds[i], 7)
		var heat := []
		var fade := []
		for f in NF:
			var t := f / FPS
			var st := maxf(0.0, (f - 0.5) / FPS)
			var a := t - on_t(i)
			heat.append([st, minf(1.0, a / 0.2) * pow(clampf(1.0 - (t - off_t(i)) / 0.7, 0.0, 1.0), 1.3) * 0.9 if a >= 0.0 else 0.0])
			fade.append([st, (1.0 - smoothstep(1.35, 1.75, t)) if a >= 0.0 else 0.0])
		key(sc, "material:shader_parameter/heat", heat, "nearest")
		key(sc, "material:shader_parameter/fade", fade, "nearest")

	# the charge gathers at the hand
	var charge := particles("Charge", {"at": HAND, "amount": 7, "lifetime": 0.1, "texture": "streak4", "align": true, "emit": {"ring": [24.0, 10.0]},
		"speed": [0, 0], "initial": gradient([C[6], C[5]], [0.0, 0.5]), "preprocess": 0.0})
	var cm: ParticleProcessMaterial = charge.process_material
	cm.radial_velocity_min = -260.0
	cm.radial_velocity_max = -160.0
	emit(charge, 0.0, WIND)

	# the links: a leap with a hot head, then the humming link, then the spent channel
	var links := []
	var leaps := []
	var spent := []
	for i in 3:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var L := a.distance_to(b)
		leaps.append(volt("Leap%d" % i, a, b, {"bow": -L * 0.1, "jag": 0.2, "forks": 0.08, "rate": 0.0, "thick": 0.75, "head": 2.0,
			"head_light": 0.7, "head_reach": 16.0, "visible": false}))
		links.append(volt("Link%d" % i, a, b, {"bow": -L * 0.1, "jag": 0.2, "forks": 0.08, "rate": 0.0, "thick": 0.75, "visible": false}))
		spent.append(volt("Spent%d" % i, a, b, {"style": 2, "bow": -L * 0.1, "jag": 0.2, "forks": 0.08, "rate": 0.0, "trace_color": C[4], "visible": false}))

	# the hand node and the target nodes
	var hand := orb("Hand", HAND, [[4.0, C[4]], [3.0, C[6]], [1.5, Color.WHITE]])
	var hand_light := glow("HandLight", 20, {"radius": 18, "color": C[4], "alpha": 0.0}, {"at": HAND})
	var hand_arc := volt("HandArc", HAND, HAND + Vector2(5, 0), {"style": 1, "jag": 0.4, "forks": 0.3, "rate": 30.0, "light": 0.3, "visible": false})
	var nodes := []
	for i in 3:
		var h: Vector2 = HOPS[i]
		var n := {}
		n.flash = orb("Hit%d" % i, h, [[7.5, C[5]], [5.0, Color.WHITE]])
		n.star = sprite("HitStar%d" % i, "star5", {"at": h, "modulate": C[6], "visible": false})
		n.node = orb("Node%d" % i, h, [[4.0, C[2]], [3.3, C[5]], [1.6, Color.WHITE]])
		n.l1 = glow("NodeLight%d" % i, 28, {"radius": 26, "color": C[4], "alpha": 0.0}, {"at": h})
		n.l2 = glow("NodeShine%d" % i, 10, {"radius": 8, "color": C[6], "alpha": 0.0}, {"at": h})
		n.crawl = [volt("Crawl%d_0" % i, h, h, {"style": 1, "jag": 0.35, "forks": 0.0, "rate": 30.0, "light": 0.25, "visible": false}),
			volt("Crawl%d_1" % i, h, h, {"style": 1, "jag": 0.35, "forks": 0.0, "rate": 30.0, "light": 0.25, "visible": false})]
		n.down = volt("Ground%d" % i, h, Vector2(grounds[i], -0.5), {"style": 1, "jag": 0.3, "forks": 0.35, "rate": 30.0, "light": 0.35, "visible": false})
		n.down_light = glow("GroundLight%d" % i, 14, {"radius": 12, "color": C[5], "alpha": 0.0})
		nodes.append(n)

	# every frame, the original's levels and choices
	var KH := {"r": [[], [], []], "l": [], "av": [], "aa": [], "ab": [], "ak": []}
	var KL := []
	for i in 3:
		KL.append({"lv": [], "lu": [], "v": [], "k": [], "step": [], "bow": [], "sv": [], "sc": [], "sa": [], "fr": [[], []], "star": [], "nr": [[], [], []],
			"l1": [], "l2": [], "cv": [[], []], "cf": [[], []], "ct": [[], []], "ck": [[], []], "dv": [], "dt": [], "dk": [], "dlp": [], "dla": []})
	var r2 := RandomNumberGenerator.new()
	r2.seed = 11
	for f in NF:
		var t := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var f2 := f >> 1
		var kh := t / WIND if t < WIND else level(0, t)
		var hr := (1.2 + 1.6 * kh + sin(t * 53.0) * 0.4) * minf(1.0, kh * 1.5)
		var hon := kh > 0.02
		KH.r[0].append([st, hr + 1.2 if hon else 0.0])
		KH.r[1].append([st, hr if hon else 0.0])
		KH.r[2].append([st, hr * 0.5 if hon else 0.0])
		KH.l.append([st, 0.6 * kh if hon else 0.0])
		var a0 := r2.randf_range(0, TAU)
		var d0 := r2.randf_range(4, 8)
		KH.av.append([st, hon and t > WIND * 0.5])
		KH.ab.append([st, HAND + Vector2(cos(a0), sin(a0)) * d0])
		KH.ak.append([st, 0.6 * kh])
		for i in 3:
			var K: Dictionary = KL[i]
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var L := a.distance_to(b)
			var h: Vector2 = HOPS[i]
			var t0 := WIND + i * GAP
			var leaping := t >= t0 and t < on_t(i)
			K.lv.append([st, leaping])
			var u := (t - t0) / LEAP
			K.lu.append([st, 1.0 - (1.0 - u) * (1.0 - u) if leaping else 1.0])
			var k := level(i, t)
			K.v.append([st, k > 0.0])
			K.k.append([st, k])
			K.step.append([st, i * 1000 + f2])
			var rb := RandomNumberGenerator.new()
			rb.seed = hash(Vector3i(31, i, f2))
			K.bow.append([st, -L * rb.randf_range(0.05, 0.15)])
			var gone := t - off_t(i) - BREAK
			var spent_on := k <= 0.0 and gone >= 0.0 and gone < 0.35
			var g := 1.0 - gone / 0.35
			K.sv.append([st, spent_on])
			K.sc.append([st, C[4] if g > 0.5 else C[2]])
			K.sa.append([st, g * 0.9])
			# the target: a flash as the bolt lands, then a node with arcs crawling over it and down to the floor
			var ah := t - on_t(i)
			var flashing := ah >= 0.0 and ah < 0.09
			var q := ah / 0.09
			K.fr[0].append([st, 6.0 * (1.0 - q) + 1.5 if flashing else 0.0])
			K.fr[1].append([st, 5.0 * (1.0 - q) if flashing else 0.0])
			K.star.append([st, flashing])
			var live := k > 0.05
			var nr := (2.6 + sin(t * 47.0 + i) * 0.7) * k
			K.nr[0].append([st, nr + 1.5 if live else 0.0])
			K.nr[1].append([st, nr + 0.7 if live else 0.0])
			K.nr[2].append([st, nr * 0.6 if live else 0.0])
			K.l1.append([st, 0.6 * k if live else 0.0])
			K.l2.append([st, 0.5 * k if live else 0.0])
			var rc := RandomNumberGenerator.new()
			rc.seed = hash(Vector3i(11, i, f))
			var n := 2 if ah < 0.12 else 1
			for j in 2:
				var c0 := rc.randf_range(0, TAU)
				var c1 := c0 + (1.0 if rc.randf() < 0.5 else -1.0) * rc.randf_range(0.5, 1.0)
				var e0 := rc.randf_range(4, 6)
				var e1 := rc.randf_range(5, 8)
				K.cv[j].append([st, live and j < n])
				K.cf[j].append([st, h + Vector2(cos(c0), sin(c0)) * e0])
				K.ct[j].append([st, h + Vector2(cos(c1), sin(c1)) * e1])
				K.ck[j].append([st, rc.randf_range(0.45, 0.7) * k])
			var down := live and rc.randf() < 0.3 * k
			var gx: float = grounds[i] + rc.randf_range(-3, 3)
			K.dv.append([st, down])
			K.dt.append([st, Vector2(gx, -0.5)])
			K.dk.append([st, 0.75 * k])
			K.dlp.append([st, Vector2(gx, -1)])
			K.dla.append([st, 0.5 * k if down else 0.0])
	for j in 3:
		key(hand[j], "material:shader_parameter/radius", KH.r[j], "nearest")
	key(hand_light, "material:shader_parameter/alpha", KH.l, "nearest")
	key(hand_arc, "visible", KH.av, "nearest")
	key(hand_arc, "to", KH.ab, "nearest")
	key(hand_arc, "k", KH.ak, "nearest")
	for i in 3:
		var K: Dictionary = KL[i]
		var n: Dictionary = nodes[i]
		key(leaps[i], "visible", K.lv, "nearest")
		key(leaps[i], "up_to", K.lu, "nearest")
		key(links[i], "visible", K.v, "nearest")
		key(links[i], "k", K.k, "nearest")
		key(links[i], "step", K.step, "nearest")
		key(links[i], "bow", K.bow, "nearest")
		key(spent[i], "visible", K.sv, "nearest")
		key(spent[i], "trace_color", K.sc, "nearest")
		key(spent[i], "alpha", K.sa, "nearest")
		spent[i].step = i * 1000 + int(floor((off_t(i) + BREAK) * 15.0))
		spent[i].bow = K.bow[mini(NF - 1, int((off_t(i) + BREAK) * FPS))][1]
		for j in 2:
			key(n.flash[j], "material:shader_parameter/radius", K.fr[j], "nearest")
		key(n.star, "visible", K.star, "nearest")
		for j in 3:
			key(n.node[j], "material:shader_parameter/radius", K.nr[j], "nearest")
		key(n.l1, "material:shader_parameter/alpha", K.l1, "nearest")
		key(n.l2, "material:shader_parameter/alpha", K.l2, "nearest")
		for j in 2:
			key(n.crawl[j], "visible", K.cv[j], "nearest")
			key(n.crawl[j], "from", K.cf[j], "nearest")
			key(n.crawl[j], "to", K.ct[j], "nearest")
			key(n.crawl[j], "k", K.ck[j], "nearest")
		key(n.down, "visible", K.dv, "nearest")
		key(n.down, "to", K.dt, "nearest")
		key(n.down, "k", K.dk, "nearest")
		key(n.down_light, "position", K.dlp, "nearest")
		key(n.down_light, "material:shader_parameter/alpha", K.dla, "nearest")

	# each hit: light, sparks, hot sparks, smoke; sparks shed while it holds; a last pop as it gives out
	var ash := Color("#5b5566").lerp(C[2], 0.35)
	var smoke_ramp := gradient([Color(ash, 0.0), Color(ash, 0.45), Color(Color("#433d48"), 0.3), Color(Color("#433d48"), 0.0)], [0.0, 0.08, 0.6, 0.95])
	var hot_ramp := gradient(["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"], [0.0, 0.4, 0.7, 0.85])
	for i in 3:
		var h: Vector2 = HOPS[i]
		var dir := rad_to_deg((h - (pts[i] as Vector2)).angle())
		var t1 := on_t(i)
		var te := t1 - 0.5 / FPS
		flash("HitLight%d" % i, h, 56, C[4], 0.85, 0.22, te)
		flash("HitWhite%d" % i, h, 16, Color.WHITE, 0.7, 0.08, te)
		if i == 0:
			flash("HandFlash", HAND, 40, C[4], 0.6, 0.15, te)
		var sp := sparks("HitSparks%d" % i, {"at": h, "amount": 18, "lifetime": 0.4, "randomness": 0.6, "dir": dir - 10, "spread": 80,
			"speed": [70, 230], "damping": [200, 320]})
		emit(sp, te)
		var hot := sparks("HotSparks%d" % i, {"at": h + Vector2(0, 2), "amount": 5, "lifetime": 0.9, "randomness": 0.4, "dir": -90, "spread": 70,
			"speed": [20, 60], "ramp": hot_ramp})
		emit(hot, te)
		var smoke := particles("HitSmoke%d" % i, {"layer": "soft", "at": h, "amount": 2, "lifetime": 1.0, "randomness": 0.3, "one_shot": true,
			"explosiveness": 1.0, "emitting": false, "texture": "disc7", "emit": {"box": Vector2(4, 2)}, "dir": -90, "spread": 25, "speed": [8, 16],
			"scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.2]], "ramp": smoke_ramp})
		emit(smoke, te)
		var a: Vector2 = pts[i]
		var shed := sparks("Shed%d" % i, {"at": (a + h) / 2.0 + Vector2(0, -2), "amount": 3, "lifetime": 0.25, "one_shot": false, "explosiveness": 0.0,
			"emit": {"box": Vector2(absf(h.x - a.x) / 2.0, 3)}, "dir": -90, "spread": 60, "speed": [30, 90], "preprocess": 0.0})
		emit(shed, te, off_t(i))
		var spit := sparks("Spit%d" % i, {"at": Vector2(grounds[i], -1), "amount": 2, "lifetime": 0.3, "one_shot": false, "explosiveness": 0.0,
			"dir": -90, "spread": 35, "speed": [40, 140], "preprocess": 0.0})
		emit(spit, te, off_t(i))
		var pop_t := off_t(i) + BREAK
		var pop := sparks("Pop%d" % i, {"at": h, "amount": 7, "lifetime": 0.3, "randomness": 0.5, "dir": -90, "spread": 180, "speed": [40, 140], "damping": [150, 250]})
		emit(pop, pop_t)
		var pop_smoke := particles("PopSmoke%d" % i, {"layer": "soft", "at": h, "amount": 1, "lifetime": 0.7, "one_shot": true, "emitting": false,
			"texture": "disc7", "dir": -90, "speed": [10, 16], "scale_curve": [[0, 0.8], [0.4, 1.0], [1, 1.2]], "ramp": smoke_ramp})
		emit(pop_smoke, pop_t)
		flash("PopLight%d" % i, h, 30, C[4], 0.5, 0.12, pop_t)
