# reimagined-from: src/fx/lightning/charge-up.js@ef7c5201698fa75c0bc0ebd9abd4aad5cf238513
# Charge up: Sparks streak and arcs whip in to a crackling core at the caster's hand that swells and pulses faster, then it flashes and bursts: bolts every way, a ring, a spray of sparks.
# one-shot, 2.70 s, 272x184 canvas, origin [124.0, 148.0], backdrop ground, stand-in 2
# The charge: streaks spiral in to the hand (an emitter whose rate climbs with the charge), arcs whip in
# (fx/lightning/_volt.gd crackles), rings fall inward on a pulse that quickens (the original's beat, replayed here),
# the core swells in stacked discs, spits crackles and lights the caster's edge (fx/lightning/_shock_actor.gdshader).
# The release: the caster flashes white, a flare (fx/lightning/_flare.gdshader) and a white core burst, eight bolts
# strike out every way on the original's flicker, a ring and its echo burst out (fx/lightning/_band.gdshader), sparks
# and motes spray, stars drift, smoke rolls up, the last crackles bleed off the hand.
extends "res://build/fx/lightning/_base.gd"

const REL := 1.6
# the original's clock passes REL a hair after frame 48, so it lets go on frame 49
const GO := 49.0 / 30.0
const CX := 15.0
const CY := -21.0
const BK := [1.0, 0.7, 0.95, 0.5, 0.8, 0.35]
const NF := 82


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func make() -> void:
	ground()
	var C := pal()
	var R := RandomNumberGenerator.new()
	R.seed = 4
	var at := Vector2(CX, CY)

	var back_glow := glow("ChargeGlow", 42, {"radius": 40, "color": C[3], "alpha": 0.0}, {"at": Vector2(CX * 0.5, -3), "back": true})
	var body := shocked_actor()

	# energy rushes in: streaks spiralling in from all round, more and more of them
	var rush := particles("Rush", {"at": at, "amount": 90, "lifetime": 0.21, "randomness": 0.25, "texture": "streak6", "align": true,
		"emit": {"ring": [55.0, 30.0]}, "speed": [0, 0], "orbit": [0.25, 0.4], "initial": gradient([C[7], C[6], C[5]]), "preprocess": 0.0})
	var rm: ParticleProcessMaterial = rush.process_material
	rm.radial_velocity_min = -260.0
	rm.radial_velocity_max = -160.0
	emit(rush, 0.0, REL)
	var stars := particles("Stars", {"at": at + Vector2(0, -2), "amount": 3, "lifetime": 0.3, "texture": "plus3", "emit": {"box": Vector2(14, 12)},
		"dir": -90, "speed": [4, 4], "color": C[6], "preprocess": 0.0})
	emit(stars, 0.6, REL)

	# arcs whipping in, rings falling in on the beat, the core
	var arcs := []
	for i in 4:
		arcs.append(volt("Whip%d" % i, Vector2.ZERO, at, {"style": 1, "k": 0.85, "jag": 0.35, "forks": 0.4, "rate": 30.0, "light": 0.4, "visible": false}))
	var rings := []
	for i in 4:
		rings.append(band("Beat%d" % i, 44, {"radius": 0.0, "thickness": 1.0, "c0": C[4], "c1": C[4], "c2": C[4], "c3": C[4], "even": true}, {"at": at}))
	var core := orb("Core", at, [[2.5, C[2]], [1.2, C[4]], [0.8, C[5]], [0.5, Color.WHITE]], {"reach": 14.0})
	var spit := volt("Spit", at, at + Vector2(4, 0), {"style": 1, "k": 0.7, "jag": 0.4, "forks": 0.3, "rate": 30.0, "light": 0.3, "visible": false})
	var g1 := glow("CoreLight", 44, {"radius": 12, "color": C[4], "alpha": 0.0}, {"at": at})
	var g2 := glow("CoreShine", 14, {"radius": 6, "color": C[6], "alpha": 0.0}, {"at": at})

	# replay the charge at 120 Hz: the beat, the arcs whipping in
	var beats := []
	var whips := []
	var phase := 0.0
	var dt := 1.0 / 120.0
	var t := 0.0
	while t < REL:
		t += dt
		var k := clampf(t / REL, 0.0, 1.0)
		var e := k * k
		if k > 0.2 and R.randf() < (2.0 + 16.0 * e) * dt:
			var a := R.randf_range(0, TAU)
			var d := R.randf_range(20, 40)
			whips.append({"t": t, "p": Vector2(CX + cos(a) * d, minf(-3.0, CY + sin(a) * d))})
		phase += (1.5 + 11.0 * e) * dt
		if phase >= 1.0:
			phase -= 1.0
			beats.append(t)
	var K := {"bg": [], "ratio": [], "g1": [], "g1r": [], "g2": [], "g2r": [], "pos": [], "c0": [], "c1": [], "c2": [], "c3": [],
		"sv": [], "sa": [], "sb": [], "la": [], "lr": [], "lh": []}
	var W := []
	for i in 4:
		W.append({"v": [], "a": [], "b": []})
	var B := []
	for i in 4:
		B.append({"r": [], "k": [], "c": []})
	phase = 0.0
	var tt := 0.0
	for f in NF:
		var ft := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var k := clampf(ft / REL, 0.0, 1.0)
		var e := k * k
		var charging := ft < GO - 0.001
		while tt < ft:
			tt += dt
			phase += (1.5 + 11.0 * clampf(tt / REL, 0.0, 1.0) ** 2) * dt
		var jit := (1.0 if f % 2 else -1.0) * ((k - 0.85) / 0.15) if k > 0.85 else 0.0
		var x := CX + jit
		var pr := 0.5 + 0.5 * sin(phase * TAU)
		var r := 1.2 + 6.5 * e + pr * (0.5 + 1.2 * k)
		K.bg.append([st, 0.3 * e if charging else 0.0])
		K.ratio.append([st, (60.0 + 360.0 * e) / 420.0])
		K.g1.append([st, (0.35 + 0.45 * k) if charging else 0.0])
		K.g1r.append([st, 12.0 + 30.0 * k])
		K.g2.append([st, (0.25 + 0.3 * k) if charging else 0.0])
		K.g2r.append([st, 6.0 + 6.0 * k])
		K.pos.append([st, Vector2(x, CY)])
		K.c0.append([st, r + 1.3 if charging else 0.0])
		K.c1.append([st, r if charging else 0.0])
		K.c2.append([st, r * 0.7 if charging else 0.0])
		K.c3.append([st, r * 0.38 if charging else 0.0])
		K.la.append([st, Vector2(x, CY)])
		K.lr.append([st, (6.0 + 10.0 * k) if (charging and e > 0.08) else 0.0])
		K.lh.append([st, (4.0 + 6.0 * k) if e > 0.4 else 0.0])
		var live := whips.filter(func(w): return ft - w.t >= 0.0 and ft - w.t <= 0.07)
		for i in 4:
			if charging and i < live.size():
				W[i].v.append([st, true])
				W[i].a.append([st, live[i].p])
				W[i].b.append([st, Vector2(x, CY)])
			else:
				W[i].v.append([st, false])
		var on_beats := beats.filter(func(b): return ft - b >= 0.0 and ft - b < 0.22)
		for i in 4:
			if charging and i < on_beats.size():
				var q: float = (ft - on_beats[i]) / 0.22
				B[i].r.append([st, 4.0 + 20.0 * (1.0 - q * q) * (0.5 + k)])
				B[i].k.append([st, 0.4 + 0.6 * q])
				B[i].c.append([st, C[6] if q > 0.6 else C[4]])
			else:
				B[i].r.append([st, 0.0])
		var sp_on := charging and k > 0.35
		K.sv.append([st, sp_on])
		var a2 := R.randf_range(0, TAU)
		var l := R.randf_range(3, 6) * (0.5 + k)
		K.sa.append([st, Vector2(x, CY) + Vector2(cos(a2), sin(a2)) * r])
		K.sb.append([st, Vector2(x, CY) + Vector2(cos(a2), sin(a2)) * (r + l)])
	key(back_glow, "material:shader_parameter/alpha", K.bg, "nearest")
	key(rush, "amount_ratio", K.ratio, "nearest")
	key(g1, "material:shader_parameter/alpha", K.g1, "nearest")
	key(g1, "material:shader_parameter/radius", K.g1r, "nearest")
	key(g2, "material:shader_parameter/alpha", K.g2, "nearest")
	key(g2, "material:shader_parameter/radius", K.g2r, "nearest")
	for j in 4:
		key(core[j], "material:shader_parameter/radius", K["c%d" % j], "nearest")
		key(core[j], "position", K.pos.map(func(p): return [p[0], p[1] + ([Vector2.ZERO, Vector2.ZERO, Vector2(-0.6, -0.6), Vector2.ZERO][j])]), "nearest")
	key(body, "material:shader_parameter/light_at", K.la, "nearest")
	key(body, "material:shader_parameter/light_r", K.lr, "nearest")
	key(body, "material:shader_parameter/light_hot", K.lh, "nearest")
	for i in 4:
		key(arcs[i], "visible", W[i].v, "nearest")
		key(arcs[i], "from", W[i].a, "nearest")
		key(arcs[i], "to", W[i].b, "nearest")
		key(rings[i], "material:shader_parameter/radius", B[i].r, "nearest")
		key(rings[i], "material:shader_parameter/k", B[i].k, "nearest")
		for c in ["c0", "c1", "c2", "c3"]:
			key(rings[i], "material:shader_parameter/" + c, B[i].c, "nearest")
	key(spit, "visible", K.sv, "nearest")
	key(spit, "from", K.sa, "nearest")
	key(spit, "to", K.sb, "nearest")

	# ---- the release
	key(body, "material:shader_parameter/flash", [[0.0, 0.0], [GO - 0.5 / FPS, 1.0], [GO + 0.07, 0.0]], "nearest")
	key(body, "material:shader_parameter/flash_color", [[0.0, Color.WHITE], [GO + 0.035, C[6]]], "nearest")
	flash("Burst", at, 110, C[4], 0.8, 0.5, GO - 0.5 / FPS)
	flash("BurstWhite", at, 28, Color.WHITE, 0.6, 0.08, GO - 0.5 / FPS)
	var fl := flare("Flare", 48, {"at": at})
	var heart := ring("Heart", 15, {"radius": 0.0, "color": Color.WHITE}, {"at": at})
	var ring_out := band("Ring", 90, {"radius": 0.0, "thickness": 3.0, "c0": Color.WHITE, "c1": Color.WHITE, "c2": Color.WHITE, "c3": Color.WHITE, "even": true, "clip": -1.0 - CY}, {"at": at})
	var ring_in := band("Echo", 64, {"radius": 0.0, "thickness": 1.0, "c0": C[4], "c1": C[4], "c2": C[4], "c3": C[4], "even": true, "clip": -1.0 - CY}, {"at": at})
	var ring_light := glow("RingLight", 48, {"radius": 8, "color": C[3], "alpha": 0.0}, {"at": at + Vector2(0, -6)})
	var bleed := volt("Bleed", at, at + Vector2(6, 0), {"style": 1, "jag": 0.45, "forks": 0.3, "rate": 30.0, "light": 0.3, "visible": false})
	var KR := {"reach": [], "k": [], "heart": [], "r": [], "th": [], "rk": [], "rc": [], "r2": [], "r2k": [], "lr": [], "la": [], "bv": [], "bb": [], "bk": []}
	for f in NF:
		var ft := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var a := ft - GO
		var q := a / 0.22
		var on := a >= 0.0 and a < 0.22
		KR.reach.append([st, 46.0 * pow(1.0 - q, 1.4) if on else 0.0])
		KR.k.append([st, 1.0 - q])
		KR.heart.append([st, 12.0 * (1.0 - q * 2.5) + 1.5 if (on and q < 0.3) else 0.0])
		var qr := a / 0.45
		var ron := a >= 0.0 and qr < 1.0
		var rr := 8.0 + 80.0 * out_cubic(clampf(qr, 0.0, 1.0))
		KR.r.append([st, rr if ron else 0.0])
		KR.th.append([st, maxf(1.0, 3.0 * (1.0 - qr))])
		KR.rk.append([st, 1.1 - qr])
		KR.rc.append([st, Color.WHITE if qr < 0.25 else C[5]])
		KR.r2.append([st, 6.0 + 56.0 * out_cubic(minf(1.0, qr * 1.3)) if ron else 0.0])
		KR.r2k.append([st, 0.8 - qr])
		KR.lr.append([st, minf(rr * 0.9, 46.0)])
		KR.la.append([st, 0.42 * (1.0 - qr) * (1.0 - qr) if ron else 0.0])
		var bon := a > 0.15 and a < 0.5
		KR.bv.append([st, bon])
		var ang := R.randf_range(0, TAU)
		var l := R.randf_range(5, 10)
		KR.bb.append([st, at + Vector2(cos(ang), sin(ang)) * l])
		KR.bk.append([st, 0.8 * (1.0 - (a - 0.15) / 0.35) + 0.15])
	key(fl, "material:shader_parameter/reach", KR.reach, "nearest")
	key(fl, "material:shader_parameter/k", KR.k, "nearest")
	key(heart, "material:shader_parameter/radius", KR.heart, "nearest")
	key(ring_out, "material:shader_parameter/radius", KR.r, "nearest")
	key(ring_out, "material:shader_parameter/thickness", KR.th, "nearest")
	key(ring_out, "material:shader_parameter/k", KR.rk, "nearest")
	for c in ["c0", "c1", "c2", "c3"]:
		key(ring_out, "material:shader_parameter/" + c, KR.rc, "nearest")
	key(ring_in, "material:shader_parameter/radius", KR.r2, "nearest")
	key(ring_in, "material:shader_parameter/k", KR.r2k, "nearest")
	key(ring_light, "material:shader_parameter/radius", KR.lr, "nearest")
	key(ring_light, "material:shader_parameter/alpha", KR.la, "nearest")
	key(bleed, "visible", KR.bv, "nearest")
	key(bleed, "to", KR.bb, "nearest")
	key(bleed, "k", KR.bk, "nearest")

	# bolts every way, struck and flickering, re-struck every other frame
	var BR := RandomNumberGenerator.new()
	BR.seed = 44
	for i in 8:
		var a := i / 8.0 * TAU + BR.randf_range(-0.25, 0.25)
		var L := BR.randf_range(44, 72)
		var x1 := CX + cos(a) * L
		var y1 := minf(0.0, CY + sin(a) * L)
		var f0: int = 49 + (1 if BR.randf() < 0.5 else 0)
		var v := volt("Bolt%d" % i, at, Vector2(x1, y1), {"jag": 0.25, "forks": 0.75, "rate": 0.0, "visible": false})
		var vis := [[0.0, false]]
		var ks := []
		var hero := []
		var th := []
		var steps := []
		for ba in 6:
			var st := (f0 + ba - 0.5) / FPS
			vis.append([st, true])
			ks.append([st, BK[ba]])
			hero.append([st, ba == 0])
			th.append([st, 0.95 if ba == 0 else 0.75])
			steps.append([st, i * 10 + (ba >> 1)])
		vis.append([(f0 + 5.5) / FPS, false])
		key(v, "visible", vis, "nearest")
		key(v, "k", ks, "nearest")
		key(v, "hero", hero, "nearest")
		key(v, "thick", th, "nearest")
		key(v, "step", steps, "nearest")
		if y1 > -1.0:
			var gl := glow("BoltFoot%d" % i, 20, {"radius": 18, "color": C[5], "alpha": 0.0}, {"at": Vector2(x1, -3)})
			key(gl, "material:shader_parameter/alpha", [[0.0, 0.0]] + ks.map(func(kk): return [kk[0], 0.5 * kk[1]]) + [[(f0 + 5.5) / FPS, 0.0]], "nearest")

	# the spray: sparks and motes every way (weaker downward), stars drifting out, smoke
	var spray := sparks("Spray", {"at": at, "amount": 46, "lifetime": 0.55, "randomness": 0.5, "dir": -90, "spread": 180, "speed": [140, 330],
		"damping": [300, 450], "ramp": gradient([C[7], C[6], C[5], C[4]], [0.0, 0.3, 0.6, 0.85])})
	emit(spray, GO - 0.5 / FPS)
	var motes := particles("Motes", {"at": at, "amount": 24, "lifetime": 0.55, "randomness": 0.5, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "streak6", "align": true, "dir": -90, "spread": 70, "speed": [140, 330], "damping": [40, 80],
		"initial": gradient([C[7], C[6], C[5]]), "alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	emit(motes, GO - 0.5 / FPS)
	var drift := particles("Glints", {"at": at, "amount": 10, "lifetime": 0.8, "randomness": 0.5, "one_shot": true, "explosiveness": 1.0,
		"emitting": false, "texture": "plus3", "dir": -90, "spread": 180, "speed": [60, 160], "damping": [120, 200],
		"initial": gradient([C[6], C[5]], [0.0, 0.5])})
	emit(drift, GO - 0.5 / FPS)
	var ash := Color("#5b5566").lerp(C[4], 0.3)
	var smoke := particles("Smoke", {"layer": "soft", "at": at, "amount": 4, "lifetime": 0.85, "randomness": 0.3, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "disc9", "emit": {"box": Vector2(5, 4)}, "dir": -90, "spread": 40, "speed": [8, 18],
		"scale_curve": [[0, 0.65], [0.4, 1.0], [1, 1.3]],
		"ramp": gradient([Color(ash, 0.0), Color(ash, 0.4), Color(Color("#5d5660"), 0.3), Color(Color("#433d48"), 0.0)], [0.0, 0.06, 0.55, 0.95])})
	emit(smoke, GO - 0.5 / FPS)
