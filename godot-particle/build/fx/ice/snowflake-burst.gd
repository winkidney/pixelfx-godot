# reimagined-from: src/fx/ice/snowflake-burst.js@26d60c74a7b850479cca215709d76e5c1514dc55
# Snowflake burst: a cold pop: frost gathers and flashes white in a ring, then crisp six-armed snowflakes spin out,
# slow, twinkle and drift down to settle and melt.
# Frost streaks spiral in (an emitter on a ring, pulled inward); the pop is a white disc, a flare, a ring running out
# and flashes of light, with motes, snow and twinkling stars thrown out by emitters. The nine snowflakes are a
# snowflake shader each (arms, branches, plate or forked tips by design, detail by size), their flight, spin, twinkle,
# landing and melt replayed from the original's little physics into keys; each goes out with two glints.
extends "res://build/fx/ice/_ice.gd"

const POP := 0.16
const CY := -48.0
const SIZES := [2, 0, 1, 0, 2, 0, 1, 0, 1]


func make() -> void:
	var D: float = root.duration
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var count: int = meta.options.count

	# the flakes, as the original makes them
	var flakes := []
	for i in count:
		var z: int = SIZES[i % SIZES.size()]
		var r := rng.randf_range(9.5, 11.5) if z == 2 else (rng.randf_range(6, 7.5) if z == 1 else rng.randf_range(3, 4.5))
		var a := float(i) / count * TAU + rng.randf_range(-0.3, 0.3) + 0.4
		var sp := rng.randf_range(80, 120) * (1.4 - r / 14.0)
		var nb := rng.randi_range(1, 3)
		var br := []
		for b in nb:
			br.append([0.38 + (0.4 * (b + rng.randf_range(0.2, 0.8))) / nb, rng.randf_range(0.24, 0.36) * (1.0 - b * 0.15)])
		while br.size() < 2:
			br.append([0.0, 0.0])
		flakes.append({"x": 0.0, "y": CY, "vx": cos(a) * sp, "vy": sin(a) * sp * 0.85 - 20.0, "r": r, "rot": rng.randf_range(0, TAU),
			"w0": (1 if rng.randf() < 0.5 else -1) * rng.randf_range(7, 12), "w1": (1 if rng.randf() < 0.5 else -1) * rng.randf_range(0.4, 1),
			"nb": nb, "br": Vector4(br[0][0], br[0][1], br[1][0], br[1][1]), "plate": rng.randf() < 0.45, "fork": rng.randf() < 0.45,
			"life": rng.randf_range(2.1, 2.8), "age": 0.0, "ph": rng.randf_range(0, TAU), "tw": rng.randf_range(0.5, 0.85),
			"tw0": rng.randf_range(0.15, 0.6), "rest": false, "popped": false, "keys": [], "out": -1.0, "out_at": Vector2.ZERO})

	# the cold light left where it burst, and the pop's flashes
	var cold := glow("Cold", 48, {"radius": 46, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, CY)})
	key(cold, "material:shader_parameter/alpha", sample(func(t): return 0.3 * (1.0 - smooth(POP, POP + 1.6, t)) if t >= POP else 0.0))
	light_flash("PopWhite", Vector2(0, CY), 44, Color.WHITE, 0.8, POP, 0.1)
	light_flash("PopCold", Vector2(0, CY), 72, C[4], 0.5, POP, 0.6)
	var gather_glow := glow("GatherGlow", 24, {"radius": 8, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, CY)})
	var gg := []
	var gr := []
	for i in 7:
		var t := i / FPS
		var k := t / POP
		gg.append([t, (0.3 + 0.4 * k) if t < POP else 0.0])
		gr.append([t, 8.0 + 14.0 * k])
	key(gather_glow, "material:shader_parameter/alpha", gg, "nearest")
	key(gather_glow, "material:shader_parameter/radius", gr, "nearest")

	# the cold gathers: streaks of frost spiral in
	var gather := particles("Gather", {"at": Vector2(0, CY), "amount": 8, "lifetime": 0.14, "texture": tex("fade6"), "align": true,
		"emit": {"ring": [44, 22]}, "speed": [0, 0], "radial": [-700, -700], "initial": gradient([C[6], C[5]])})
	gather.process_material.radial_velocity_min = -210.0
	gather.process_material.radial_velocity_max = -170.0
	lit_copy(gather, "GatherLight", "glow8", Color(C[5], 0.4))
	emit_all([gather, root.get_node("GatherLight")], 0.0, POP - 0.03)

	# the pop: a white disc, a flare, a ring of frost running out, its light
	var disc := ring("Flash", 8, {"radius": 7, "color": Color.WHITE}, {"at": Vector2(0.5, CY + 0.5)})
	show(disc, POP, POP + 0.07)
	key(disc, "material:shader_parameter/radius", sample(func(t): return 6.0 * (1.0 - clampf((t - POP) / 0.07, 0, 1)) + 1.0, POP, POP + 0.07))
	var fl := flare("Flare", Vector2(0, CY))
	key(fl, "material:shader_parameter/len", sample(func(t): return 28.0 * pow(maxf(0.0, 1.0 - (t - POP) / 0.26), 1.5) if t >= POP else 0.0, 0.0, POP + 0.3), "nearest")
	key(fl, "material:shader_parameter/k", sample(func(t): return 1.0 - (t - POP) / 0.26, POP, POP + 0.3), "nearest")
	var rim := ring("Ring", 42, {"radius": 5, "thickness": 2.4, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0.5, CY + 0.5)})
	var rim_light := glow("RingLight", 46, {"radius": 5, "thickness": 5.0, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, CY)})
	var rr := []
	var rt := []
	var rc := []
	var ra := []
	var la := []
	for i in 14:
		var q := i / FPS
		var e := out_cubic(minf(1.0, q / 0.4))
		var t := POP + q
		rr.append([t, 5.0 + 34.0 * e])
		rt.append([t, maxf(1.0, 2.4 * (1.0 - e))])
		rc.append([t, Color.WHITE if q < 0.08 else (C[6] if q < 0.2 else C[5])])
		ra.append([t, (1.15 - e) if q < 0.4 else 0.0])
		la.append([t, 0.4 * (1.0 - e) if q < 0.4 else 0.0])
	ra.push_front([0.0, 0.0])
	la.push_front([0.0, 0.0])
	key(rim, "material:shader_parameter/radius", rr, "nearest")
	key(rim_light, "material:shader_parameter/radius", rr, "nearest")
	key(rim, "material:shader_parameter/thickness", rt, "nearest")
	key(rim, "material:shader_parameter/color", rc, "nearest")
	key(rim, "material:shader_parameter/alpha", ra, "nearest")
	key(rim_light, "material:shader_parameter/alpha", la, "nearest")

	# frost thrown out: streaking motes, snow, glints that come and go round it
	var motes := particles("Motes", {"at": Vector2(0, CY), "amount": 22, "lifetime": 0.5, "one_shot": true, "explosiveness": 1.0,
		"texture": tex("fade4"), "align": true, "spread": 180, "speed": [80, 150], "damping": [40, 70],
		"initial": gradient([C[6], C[5]]), "alpha_curve": [[0, 1], [0.65, 1], [1, 0]]})
	motes.process_material.lifetime_randomness = 0.5
	var mote_light := lit_copy(motes, "MoteLight", "glow8", Color(C[5], 0.4), [[0, 1], [1, 0]])
	emit_all([motes, mote_light], POP)
	var snow_o := {"at": Vector2(0, CY), "amount": 14, "lifetime": 1.6, "one_shot": true, "explosiveness": 1.0, "texture": "dot1",
		"dir": -84, "spread": 96, "speed": [30, 110], "damping": [110, 150], "gravity": Vector2(0, 35), "initial": gradient([Color.WHITE, Color.WHITE, C[6]]),
		"alpha_curve": [[0, 1], [0.66, 1], [1, 0]], "turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}}
	var snow := particles("Snow", snow_o)
	snow.process_material.lifetime_randomness = 0.35
	var snow_o2 := snow_o.duplicate()
	snow_o2.amount = 4
	snow_o2.texture = "plus3"
	var snow2 := particles("SnowBig", snow_o2)
	snow2.process_material.lifetime_randomness = 0.35
	emit_all([snow, snow2], POP)
	var stars := particles("Stars", {"at": Vector2(0, CY), "amount": 4, "lifetime": 0.45, "texture": "plus3", "emitting": false,
		"emit": {"ring": [44, 10]}, "dir": 90, "speed": [2, 6], "initial": gradient([Color.WHITE, C[6]]),
		"alpha_curve": [[0, 0], [0.1, 1], [0.3, 0.4], [0.5, 1], [0.7, 0.3], [0.85, 1], [1, 0]]})
	var star_hearts := particles("StarHearts", {"at": Vector2(0, CY), "amount": 4, "lifetime": 0.45, "texture": "dot1", "emitting": false,
		"emit": {"ring": [44, 10]}, "dir": 90, "speed": [2, 6], "color": Color.WHITE,
		"alpha_curve": [[0, 0], [0.1, 1], [0.3, 0.4], [0.5, 1], [0.7, 0.3], [0.85, 1], [1, 0]]})
	star_hearts.seed = stars.seed
	emit_all([stars, star_hearts], POP + 0.08, POP + 1.6)

	# the flakes: replay the original's flight at its 30 steps a second
	var dt := 1.0 / FPS
	var n := int(roundf(D * FPS))
	var gk := []
	for fi in n + 1:
		var t := fi * dt
		if fi > 0:
			var tp := t
			if tp >= POP:
				for f in flakes:
					step(f, tp, dt)
		for f in flakes:
			f.keys.append(draw_state(f, t, flakes[0]))
	var i := 0
	for f in flakes:
		var node := shape("Flake%d" % i, load(ICE + "_flake.gdshader"), Vector2(33, 33), {"r": f.r, "rot": f.rot, "branches": f.br,
			"nb": float(f.nb), "plate": 1.0 if f.plate else 0.0, "fork": 1.0 if f.fork else 0.0, "c6": C[6], "c5": C[5]},
			{"at": cell(Vector2(0, CY))})
		var halo := glow("FlakeGlow%d" % i, 22, {"radius": 8, "color": C[4], "alpha": 0.0}, {"at": Vector2(0, CY)})
		var hot_glow := glow("FlakeHot%d" % i, 9, {"radius": 4, "color": Color.WHITE, "alpha": 0.0}, {"at": Vector2(0, CY)})
		var twinkle := flare("Twinkle%d" % i, Vector2(0, CY), 12)
		var tracks := {"pos": [], "r": [], "rot": [], "hot": [], "smear": [], "vis": [], "gpos": [], "grad": [], "galpha": [], "hrad": [], "halpha": [], "flen": [], "fk": []}
		for k in f.keys:
			var t: float = k.t
			var at: Vector2 = cell(k.pos)
			tracks.pos.append([t, at])
			tracks.r.append([t, k.r])
			tracks.rot.append([t, k.rot])
			tracks.hot.append([t, k.hot])
			tracks.smear.append([t, k.smear])
			tracks.vis.append([t, k.vis])
			tracks.gpos.append([t, at])
			tracks.grad.append([t, k.grad])
			tracks.galpha.append([t, k.galpha if k.vis else 0.0])
			tracks.hrad.append([t, 2.0 + 0.5 * k.r])
			tracks.halpha.append([t, 0.3 * k.hot if (k.vis and k.hot > 0.3 and k.smear < 0.0) else 0.0])
			tracks.flen.append([t, k.flare if k.vis else 0.0])
			tracks.fk.append([t, k.tw])
		key(node, "position", tracks.pos, "nearest")
		key(node, "material:shader_parameter/r", tracks.r, "nearest")
		key(node, "material:shader_parameter/rot", tracks.rot, "nearest")
		key(node, "material:shader_parameter/hot", tracks.hot, "nearest")
		key(node, "material:shader_parameter/smear", tracks.smear, "nearest")
		key(node, "visible", tracks.vis, "nearest")
		key(halo, "position", tracks.gpos, "nearest")
		key(halo, "material:shader_parameter/radius", tracks.grad, "nearest")
		key(halo, "material:shader_parameter/alpha", tracks.galpha, "nearest")
		key(hot_glow, "position", tracks.gpos, "nearest")
		key(hot_glow, "material:shader_parameter/radius", tracks.hrad, "nearest")
		key(hot_glow, "material:shader_parameter/alpha", tracks.halpha, "nearest")
		key(twinkle, "position", tracks.gpos, "nearest")
		key(twinkle, "material:shader_parameter/len", tracks.flen, "nearest")
		key(twinkle, "material:shader_parameter/k", tracks.fk, "nearest")
		# a spent flake goes out with a glint or two
		if f.out >= 0.0 and f.out < D - 0.1:
			var g := particles("Glint%d" % i, {"at": f.out_at, "amount": 2, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0,
				"texture": "plus3", "emitting": false, "emit": {"box": Vector2(2, 2)}, "dir": -90, "spread": 40, "speed": [3, 9],
				"initial": gradient([Color.WHITE, C[6]]), "alpha_curve": [[0, 1], [0.4, 0.5], [0.7, 1], [1, 0]]})
			emit(g, f.out)
		i += 1


func size_of(f: Dictionary) -> float:
	return f.r * minf(1.0, out_back(clamp01(f.age / 0.18), 2.0)) * minf(1.0, (f.life - f.age) / 0.35)


## One step of the original's update for a flake (after the pop).
func step(f: Dictionary, t: float, dt: float) -> void:
	f.age += dt
	if f.age >= f.life:
		return
	if not f.rest:
		f.vx -= f.vx * 2.8 * dt
		f.vy -= f.vy * 2.8 * dt - 26.0 * dt
		f.x += f.vx * dt + sin(t * 1.8 + f.ph) * 5.0 * dt
		f.y += f.vy * dt
		f.rot += (f.w1 + (f.w0 - f.w1) * exp(-f.age * 2.5)) * dt
		if f.y > -size_of(f) * 0.3:
			f.rest = true
			f.y = -1.0
			f.life = minf(f.life, f.age + 0.6)
	if not f.popped and f.life - f.age < 0.1:
		f.popped = true
		f.out = t
		f.out_at = Vector2(f.x, f.y)


## What the original draws for a flake at time t: {t, pos, r, rot, hot, smear, vis, grad, galpha, flare, tw}.
func draw_state(f: Dictionary, t: float, first: Dictionary) -> Dictionary:
	var s := {"t": t, "pos": Vector2(f.x, f.y), "r": 0.0, "rot": 0.0, "hot": 0.0, "smear": -1.0, "vis": false, "grad": 8.0, "galpha": 0.0, "flare": 0.0, "tw": 0.0}
	if t < POP:
		# the gathering: the first flake's design spins up at the heart, faster and brighter
		if is_same(f, first):
			var k := t / POP
			s.merge({"pos": Vector2(0, CY), "r": 1.0 + 3.2 * k * k, "rot": t * 20.0, "hot": k, "vis": true, "grad": 3.0 + (1.0 + 3.2 * k * k) * 1.2,
				"galpha": 0.14 + 0.35 * k}, true)
		return s
	if f.age >= f.life:
		return s
	var r := size_of(f)
	var tw := pow(maxf(0.0, sin(((f.age - f.tw0) / f.tw) * TAU)), 8.0) * (1.0 if f.age > f.tw0 else 0.0)
	if f.rest:
		var L := maxf(1.0, roundf(r * 1.2 * ((f.life - f.age) / 0.6)))
		s.merge({"pos": Vector2(f.x, -1.0), "r": r, "smear": L, "vis": true, "grad": 3.0 + L, "galpha": 0.3}, true)
		return s
	var hot := maxf(tw, 1.0 - clamp01(f.age / 0.12))
	s.merge({"r": r, "rot": f.rot, "hot": hot, "vis": true, "grad": 5.0 + r * 1.3, "galpha": 0.12 + 0.14 + 0.35 * hot,
		"flare": (3.0 + r * 0.7) * tw if tw > 0.5 else 0.0, "tw": tw}, true)
	return s
