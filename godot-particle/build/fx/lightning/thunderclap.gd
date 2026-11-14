# reimagined-from: src/fx/lightning/thunderclap.js@6fac4bbf932c9ad91d01085d257b97fcdd309c09
# Thunderclap: A thunderclap round the caster: a white flash, forked bolts burst out and stab the floor, a heavy shock ring tears across the ground raising dust and grit, sparks streak away.
# one-shot, 1.90 s, 288x156 canvas, origin [144.0, 124.0], backdrop ground, stand-in 2
# Sparks streak in to the caster's chest; at the clap the stand-in flashes white (fx/lightning/_shock_actor.gdshader),
# an 8-ray flare (fx/lightning/_flare.gdshader) and a white core burst, light flares, eight forked bolts
# (fx/lightning/_volt.gd) strike out on the original's flicker, the lower ones stabbing the floor (a flash, sparks,
# hot sparks and a scorch where each lands); a shock band (fx/lightning/_band.gdshader) tears out along the floor,
# its far half behind the caster, raising dust and grit from emitters that ride its front; a dithered ring bursts
# through the air; a big spray of sparks and smoke; small arcs crackle round the caster as the charge bleeds away.
extends "res://build/fx/lightning/_base.gd"

const CLAP := 0.12
const CY := -22.0
const REACH := 104.0
const BK := [1.0, 0.7, 0.95, 0.5, 0.8, 0.3]
const D := 1.9
const NF := 58


static func out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func front(t: float) -> float:
	return 0.0 if t < CLAP else 8.0 + (REACH - 8.0) * out_cubic(clampf((t - CLAP) / 0.5, 0.0, 1.0))


func make() -> void:
	ground()
	var C := pal()
	var S: PackedColorArray = root.ramps.sparks
	var R := RandomNumberGenerator.new()
	R.seed = 6
	var bolts := []
	for i in 8:
		var down := i % 2 == 0
		var side := -1.0 if i % 4 < 2 else 1.0
		var a: float
		if down:
			a = R.randf_range(0.33, 0.6) if side > 0 else PI - R.randf_range(0.33, 0.6)
		else:
			a = -R.randf_range(0.15, 1.2) if side > 0 else PI + R.randf_range(0.15, 1.2)
		var L := -CY / sin(a) if down else R.randf_range(40, 62)
		var x1 := cos(a) * L
		bolts.append({"down": down, "x1": roundf(x1), "y1": 0.0 if down else CY + sin(a) * L, "t0": ([4, 4, 5, 4, 6, 5, 4, 5][i] - 0.5) / FPS})

	# the floor: scorches where the bolts struck, the far half of the shock band
	for b in bolts:
		if b.down:
			var sc := scorch("Scorch%d" % bolts.find(b), b.x1, 9)
			var heat := []
			var fade := []
			for f in NF:
				var t := f / FPS
				var st := maxf(0.0, (f - 0.5) / FPS)
				heat.append([st, pow(clampf(1.0 - (t - b.t0) / 1.1, 0.0, 1.0), 1.3) if t >= b.t0 else 0.0])
				fade.append([st, (1.0 - smoothstep(1.4, 1.85, t)) if t >= b.t0 else 0.0])
			key(sc, "material:shader_parameter/heat", heat, "nearest")
			key(sc, "material:shader_parameter/fade", fade, "nearest")
	var band_far := band("BandFar", REACH + 2, {"radius": 0.0, "thickness": 16.0, "squash": 0.18, "c0": Color.WHITE, "c1": C[4], "c2": C[2], "c3": C[1], "side": 1.0}, {"back": true})
	var band_near := band("BandNear", REACH + 2, {"radius": 0.0, "thickness": 16.0, "squash": 0.18, "c0": Color.WHITE, "c1": C[4], "c2": C[2], "c3": C[1], "side": -1.0})

	# the caster flashes white
	var body := shocked_actor()
	key(body, "material:shader_parameter/flash", [[0.0, 0.0], [CLAP, 1.0], [CLAP + 0.07, 0.0]], "nearest")
	key(body, "material:shader_parameter/flash_color", [[0.0, Color.WHITE], [CLAP + 0.035, C[6]]], "nearest")

	# the breath before: sparks rush in to the chest
	var rush := particles("Rush", {"at": Vector2(0, CY), "amount": 6, "lifetime": 0.09, "texture": "streak4", "align": true,
		"emit": {"ring": [30.0, 16.0]}, "speed": [0, 0], "initial": gradient([C[6], C[5]], [0.0, 0.5]), "emitting": true, "preprocess": 0.0})
	var rm: ParticleProcessMaterial = rush.process_material
	rm.radial_velocity_min = -320.0
	rm.radial_velocity_max = -200.0
	emit(rush, 0.0, CLAP)

	# light
	flash("ClapLight", Vector2(0, CY - 10), 100, C[4], 0.65, 0.45, CLAP)
	flash("ClapWhite", Vector2(0, CY), 26, Color.WHITE, 0.5, 0.07, CLAP)
	var fl := flare("Flare", 46, {"at": Vector2(0, CY)})
	var core := ring("Core", 13, {"radius": 0.0, "color": Color.WHITE}, {"at": Vector2(0, CY)})
	var core_light := glow("CoreLight", 46, {"radius": 44, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, CY)})
	var kf := {"reach": [], "k": [], "core": [], "cl": []}
	for f in NF:
		var t := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var a := t - CLAP
		var on := a >= 0.0 and a < 0.2
		var q := a / 0.2
		kf.reach.append([st, 44.0 * pow(1.0 - q, 1.4) if on else 0.0])
		kf.k.append([st, 1.0 - q])
		kf.core.append([st, 10.0 * (1.0 - q * 2.0) + 2.0 if (on and q < 0.35) else 0.0])
		kf.cl.append([st, 0.32 * (1.0 - q) if on else 0.0])
	key(fl, "material:shader_parameter/reach", kf.reach, "nearest")
	key(fl, "material:shader_parameter/k", kf.k, "nearest")
	key(core, "material:shader_parameter/radius", kf.core, "nearest")
	key(core_light, "material:shader_parameter/alpha", kf.cl, "nearest")

	# the bolts: struck, flickering, re-struck every other frame; where the lower ones land, a flash and sparks
	var i := 0
	for b in bolts:
		var v := volt("Bolt%d" % i, Vector2(0, CY), Vector2(b.x1, b.y1), {"jag": 0.25, "forks": 0.5 if b.down else 0.8, "rate": 0.0, "visible": false})
		var vis := [[0.0, false]]
		var ks := []
		var hero := []
		var th := []
		var steps := []
		for ba in 6:
			var st: float = b.t0 + ba / FPS
			vis.append([st, true])
			ks.append([st, BK[ba]])
			hero.append([st, ba == 0])
			th.append([st, 1.0 if ba == 0 else 0.8])
			steps.append([st, i * 10 + (ba >> 1)])
		vis.append([b.t0 + 6 / FPS, false])
		key(v, "visible", vis, "nearest")
		key(v, "k", ks, "nearest")
		key(v, "hero", hero, "nearest")
		key(v, "thick", th, "nearest")
		key(v, "step", steps, "nearest")
		if b.down:
			var spot := ring("Spot%d" % i, 6, {"radius": 0.0, "color": C[5]}, {"at": Vector2(b.x1, -1)})
			var px := rect("SpotPx%d" % i, Rect2(b.x1, -1, 1, 1), Color.WHITE)
			var gl := glow("SpotLight%d" % i, 22, {"radius": 20, "color": C[5], "alpha": 0.0}, {"at": Vector2(b.x1, -3)})
			var rr := [[0.0, 0.0]]
			var al := [[0.0, 0.0]]
			for ba in 6:
				rr.append([b.t0 + ba / FPS, 3.0 * BK[ba] + 1.0])
				al.append([b.t0 + ba / FPS, 0.5 * BK[ba]])
			rr.append([b.t0 + 6 / FPS, 0.0])
			al.append([b.t0 + 6 / FPS, 0.0])
			key(spot, "material:shader_parameter/radius", rr, "nearest")
			key(gl, "material:shader_parameter/alpha", al, "nearest")
			show(px, b.t0, b.t0 + 6 / FPS)
			flash("Land%d" % i, Vector2(b.x1, -4), 46, C[4], 0.7, 0.25, b.t0)
			var sp := sparks("LandSparks%d" % i, {"at": Vector2(b.x1, -1), "amount": 12, "lifetime": 0.4, "randomness": 0.5, "dir": -90,
				"spread": 69, "speed": [70, 240], "damping": [200, 300]})
			emit(sp, b.t0)
			var hot := sparks("HotSparks%d" % i, {"at": Vector2(b.x1, -1), "amount": 5, "lifetime": 0.8, "randomness": 0.5, "dir": -90,
				"spread": 30, "speed": [60, 180], "ramp": gradient(["#fff3a6", "#ffe26b", "#ff8a2a", "#f2561d"], [0.0, 0.4, 0.7, 0.85])})
			emit(hot, b.t0)
		else:
			var star := sprite("Glint%d" % i, "spark7", {"at": Vector2(b.x1, b.y1), "modulate": C[6]})
			show(star, b.t0, b.t0 + 2 / FPS)
		i += 1

	# the shock: the band's near half on the floor, its light at the fronts, a ring bursting through the air
	var air := band("AirRing", 70, {"radius": 0.0, "thickness": 2.0, "c0": C[5], "c1": C[5], "c2": C[5], "c3": C[5], "even": true, "clip": -1.0 - CY}, {"at": Vector2(0, CY)})
	var fronts := []
	for s in [-1, 1]:
		fronts.append(glow("FrontLight%s" % ("L" if s < 0 else "R"), 30, {"radius": 28, "color": C[4], "alpha": 0.0}))
	var kb := {"r": [], "th": [], "k": [], "c0": [], "fa": [], "fl": [], "fr": [], "ar": [], "at": [], "ak": [], "ac": []}
	for f in NF:
		var t := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var u := (t - CLAP) / 0.5
		var on := u > 0.0 and u < 1.0
		var fr := front(t)
		kb.r.append([st, fr if on else 0.0])
		kb.th.append([st, maxf(2.0, 16.0 * (1.0 - u))])
		kb.k.append([st, 1.25 - u])
		kb.c0.append([st, Color.WHITE if u < 0.15 else C[6]])
		kb.fa.append([st, 0.45 * (1.0 - u) if on else 0.0])
		kb.fl.append([st, Vector2(-fr, -3)])
		kb.fr.append([st, Vector2(fr, -3)])
		var ua := (t - CLAP) / 0.26
		var air_on := ua > 0.0 and ua < 1.0
		kb.ar.append([st, 8.0 + 60.0 * out_cubic(ua) if air_on else 0.0])
		kb.at.append([st, maxf(1.0, 2.0 * (1.0 - ua))])
		kb.ak.append([st, 0.85 - 0.85 * ua])
		kb.ac.append([st, C[5] if ua < 0.25 else (C[4] if ua < 0.6 else C[3])])
	for bn in [band_far, band_near]:
		key(bn, "material:shader_parameter/radius", kb.r, "nearest")
		key(bn, "material:shader_parameter/thickness", kb.th, "nearest")
		key(bn, "material:shader_parameter/k", kb.k, "nearest")
		key(bn, "material:shader_parameter/c0", kb.c0, "nearest")
	key(fronts[0], "position", kb.fl, "nearest")
	key(fronts[1], "position", kb.fr, "nearest")
	key(fronts[0], "material:shader_parameter/alpha", kb.fa, "nearest")
	key(fronts[1], "material:shader_parameter/alpha", kb.fa, "nearest")
	key(air, "material:shader_parameter/radius", kb.ar, "nearest")
	key(air, "material:shader_parameter/thickness", kb.at, "nearest")
	key(air, "material:shader_parameter/k", kb.ak, "nearest")
	for c in ["c0", "c1", "c2", "c3"]:
		key(air, "material:shader_parameter/" + c, kb.ac, "nearest")

	# the ring tears the floor up as it passes: dust rolling out, grit tossed, from emitters riding its fronts
	var dust := Color("#6e6382")
	var stone := gradient(["#655b7a", "#4a4263", "#342d45"])
	for s in [-1, 1]:
		var nm := "L" if s < 0 else "R"
		var d := particles("Dust" + nm, {"layer": "soft", "amount": 50, "lifetime": 1.1, "randomness": 0.4, "texture": "disc9", "emitting": false,
			"emit": {"box": Vector2(3, 1.5)}, "dir": -90 + s * 70, "spread": 20, "speed": [10, 40], "damping": [15, 25], "gravity": Vector2(0, -12),
			"scale": [0.6, 1.2], "scale_curve": [[0, 0.7], [0.4, 1.0], [1, 1.3]],
			"ramp": gradient([Color(dust, 0.0), Color(dust, 0.6), Color(Color("#5d5660"), 0.4), Color(Color("#433d48"), 0.0)], [0.0, 0.06, 0.55, 0.95])})
		var g := particles("Grit" + nm, {"amount": 45, "lifetime": 1.2, "randomness": 0.3, "texture": "dot1", "emitting": false,
			"dir": -90 + s * 15, "spread": 15, "speed": [60, 180], "gravity": Vector2(0, 950), "initial": stone,
			"collide": {"bounce": 0.25, "friction": 0.8}})
		var pos := []
		for f in range(int(CLAP * FPS), int((CLAP + 0.5) * FPS) + 2):
			var t := f / FPS
			pos.append([t, Vector2(s * front(t), -2)])
		key(d, "position", pos)
		key(g, "position", pos)
		emit(d, CLAP, CLAP + 0.5)
		emit(g, CLAP, CLAP + 0.5)

	# the spray: sparks streaking away from the clap, smoke rolling up
	var spray := sparks("Spray", {"at": Vector2(0, CY), "amount": 64, "lifetime": 0.45, "randomness": 0.6, "emit": {"circle": 6.0},
		"dir": -90, "spread": 180, "speed": [170, 380], "gravity": Vector2(0, 380), "damping": [350, 550]})
	emit(spray, CLAP)
	var ash := Color("#5b5566").lerp(C[4], 0.3)
	var smoke := particles("Smoke", {"layer": "soft", "at": Vector2(0, CY), "amount": 8, "lifetime": 1.3, "randomness": 0.4, "one_shot": true,
		"explosiveness": 1.0, "emitting": false, "texture": "disc13", "emit": {"box": Vector2(8, 6)}, "dir": -90, "spread": 50, "speed": [10, 30],
		"damping": [6, 12], "gravity": Vector2(0, -16), "scale": [0.6, 1.0], "scale_curve": [[0, 0.65], [0.4, 1.0], [1, 1.3]],
		"ramp": gradient([Color(ash, 0.0), Color(ash, 0.4), Color(Color("#5d5660"), 0.3), Color(Color("#433d48"), 0.0)], [0.0, 0.06, 0.55, 0.95])})
	emit(smoke, CLAP)

	# the hum after: small arcs crackle round the caster as the charge bleeds away
	var hum := volt("Hum", Vector2.ZERO, Vector2(1, 0), {"style": 1, "jag": 0.4, "forks": 0.3, "rate": 30.0, "light": 0.35, "visible": false})
	var hk := {"v": [], "a": [], "b": [], "k": []}
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for f in NF:
		var t := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var a := t - CLAP
		var on := a > 0.2 and a < 0.9 and r.randf() < 0.8
		hk.v.append([st, on])
		var x0 := r.randf_range(-14, 14)
		var y0 := r.randf_range(-34, -4)
		var bb := r.randf_range(0, TAU)
		var l := r.randf_range(6, 13)
		hk.a.append([st, Vector2(x0, y0)])
		hk.b.append([st, Vector2(x0 + cos(bb) * l, y0 + sin(bb) * l)])
		hk.k.append([st, 0.85 * (1.0 - (a - 0.2) / 0.7) + 0.1])
	key(hum, "visible", hk.v, "nearest")
	key(hum, "from", hk.a, "nearest")
	key(hum, "to", hk.b, "nearest")
	key(hum, "k", hk.k, "nearest")
