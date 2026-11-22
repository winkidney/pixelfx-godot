# reimagined-from: src/fx/holy/feather-burst.js@16c0cd2393b027c12a763e9d722193efca1bf675
# Feather burst: A white puff pops and throws feathers that brake hard, then rock from side to side as they sink and fade, with down drifting after them.
# one-shot, 3.00 s, 160x160 canvas, origin [80.0, 60.0], backdrop dark
# ramp palette: #4a4560 #7a7494 #aaa5c2 #d6d3e6 #f4f3fa #ffffff
# Each feather is a sprite drawn at build time by the original's feather() (_holy.gd feather_image), white for its
# first frames, with a glow riding it; its flight replays the original's little simulation (thrown, braked hard,
# then rocking like a pendulum as it sinks) into position, rotation and alpha keys. The puff is discs (the ring
# shader) swelling and thinning on the original's curves; the pop is a white disc, a ring of air and a sparkle;
# down and stars are particle bursts (the stars step through the original's sparkle), glints wink among the
# feathers, and two lights flare with a warmth that lingers.
extends "res://build/fx/holy/_holy.gd"


func make() -> void:
	var F := fit(root.ramps.palette, 6)
	var G := Color(meta.options.glow)
	var D: float = meta.duration
	var R := RandomNumberGenerator.new()
	R.seed = 4

	# ---- the puff: soft lobes thrown out from the pop, swelling and thinning (behind the big feathers)
	var rims := []
	var fills := []
	var lobes := []
	for i in 11:
		var a := i / 11.0 * TAU + R.randf_range(-0.25, 0.25)
		var d := R.randf_range(5, 14)
		lobes.append({"x": cos(a) * d, "y": sin(a) * d * 0.8, "r0": R.randf_range(2.5, 4), "r1": R.randf_range(6, 9.5), "life": R.randf_range(0.45, 0.8)})
	for i in 11:
		rims.append(ring("PuffRim%d" % i, 12, {"radius": 0.0, "color": F[2]}, {"back": true}))
	for i in 11:
		fills.append([ring("Puff%d" % i, 11, {"radius": 0.0, "color": F[4]}, {"back": true}),
			ring("PuffLit%d" % i, 8, {"radius": 0.0, "color": Color.WHITE}, {"back": true})])
	for i in 11:
		var l: Dictionary = lobes[i]
		var pos := func(t: float) -> Vector2:
			var u: float = t / l.life
			var e := out_cubic(u)
			return Vector2(l.x * (0.4 + e * 1.3), l.y * (0.4 + e * 1.3) - u * 5.0).round()
		var rad := func(t: float) -> float:
			var u: float = t / l.life
			if u >= 1.0:
				return 0.0
			var r: float = (l.r0 + (l.r1 - l.r0) * out_cubic(minf(1.0, u * 3.0))) * (1.0 - u * u)
			return r if r >= 0.6 else 0.0
		var life: float = l.life
		keyn(rims[i], "position", pos, 0.0, life)
		keyn(rims[i], "material:shader_parameter/radius", func(t: float) -> float: return rad.call(t) + 0.8 if rad.call(t) > 0.0 else 0.0, 0.0, life + 0.04)
		keyn(fills[i][0], "position", pos, 0.0, life)
		keyn(fills[i][0], "material:shader_parameter/radius", rad, 0.0, life + 0.04)
		keyn(fills[i][1], "position", func(t: float) -> Vector2: return (pos.call(t) as Vector2) + Vector2(-1, -1), 0.0, life)
		keyn(fills[i][1], "material:shader_parameter/radius", func(t: float) -> float: return maxf(0.0, rad.call(t) * 0.5), 0.0, life + 0.04)

	# ---- the feathers: 20 big ones thrown out all round, 10 small ones behind
	var list := []
	for i in 20:
		var a := i / 20.0 * TAU + R.randf_range(-0.15, 0.15)
		var sp := R.randf_range(110, 230)
		var up := 0.7 if sin(a) < 0.0 else 0.9
		list.append(_feather(R, {"x": cos(a) * 3, "y": sin(a) * 3, "vx": cos(a) * sp, "vy": sin(a) * sp * up - 20, "a": a + R.randf_range(-0.5, 0.5),
			"len": R.randf_range(10, 14), "wid": R.randf_range(2.6, 3.4), "life": R.randf_range(1.9, 2.6), "delay": R.randf_range(0, 0.03),
			"sink": R.randf_range(26, 38), "amp": R.randf_range(8, 13)}))
	for i in 10:
		var a := R.randf_range(0, TAU)
		var sp := R.randf_range(50, 130)
		list.append(_feather(R, {"x": 0.0, "y": 0.0, "vx": cos(a) * sp, "vy": sin(a) * sp - 20, "a": R.randf_range(0, TAU), "len": R.randf_range(6, 8),
			"wid": R.randf_range(1.8, 2.2), "life": R.randf_range(1.6, 2.4), "back": true, "sink": R.randf_range(18, 28)}))
	var k := 0
	for f in list:
		var body := sprite("Feather%d" % k, asset("feather%d.png" % k, feather_image(f.len, f.wid, F, 1, 0.0, 0.2)), {"back": f.back, "visible": false})
		body.flip_v = f.side < 0.0
		var hot := sprite("Hot", asset("hot%d.png" % k, feather_image(f.len, f.wid, F, 1, 1.0, 0.2)), {"parent": body})
		hot.flip_v = body.flip_v
		var lit := sprite("FeatherLight%d" % k, "glow16", {"layer": "light", "back": f.back, "visible": false,
			"scale": Vector2.ONE * (4.0 + f.len * 0.5) / 8.0, "modulate": F[3]})
		var pos := []
		var rot := []
		var al := []
		var gl := []
		var vis := []
		var hv := []
		var t := 0.0
		var step := 0
		var max_life: float = f.life
		while t <= D + 1e-6:
			if step % 4 == 0:
				var st := maxf(0.0, t - 0.5 / FPS)
				var on: bool = f.delay <= 0.0 and f.life > 0.0
				var a := minf(1.0, minf(f.life / 0.45, f.age / 0.06)) if on else 0.0
				vis.append([st, on])
				pos.append([st, Vector2(f.x, f.y)])
				rot.append([st, f.a])
				al.append([st, a])
				hv.append([st, f.age < 0.06])
				gl.append([st, 0.22 * a * (0.4 + 0.6 * f.life / max_life)])
			_fly(f, 1.0 / 120.0)
			t += 1.0 / 120.0
			step += 1
		key(body, "visible", vis, "nearest")
		key(body, "position", pos, "nearest")
		key(body, "rotation", rot, "nearest")
		key(body, "modulate:a", al, "nearest")
		key(hot, "visible", hv, "nearest")
		key(lit, "visible", vis, "nearest")
		key(lit, "position", pos, "nearest")
		key(lit, "modulate:a", gl, "nearest")
		k += 1

	# ---- the pop: a white flash, a ring of air, a sparkle
	var flash := ring("Flash", 10, {"radius": 9.0, "color": Color.WHITE})
	keyn(flash, "material:shader_parameter/radius", func(t: float) -> float: return 9.0 * (1.0 - t / 0.14) if t < 0.07 else 0.0, 0.0, 0.1)
	var air := ring("Air", 32, {"radius": 6.0, "thickness": 2.5, "color": Color.WHITE})
	keyn(air, "material:shader_parameter/radius", func(t: float) -> float: return 6.0 + 24.0 * out_cubic(t / 0.25) + maxf(1.0, 2.5 * (1.0 - t / 0.25)) / 2.0, 0.0, 0.27)
	keyn(air, "material:shader_parameter/thickness", func(t: float) -> float: return maxf(1.0, 2.5 * (1.0 - t / 0.25)), 0.0, 0.27)
	keyn(air, "material:shader_parameter/alpha", func(t: float) -> float: return 1.1 - t / 0.25 if t < 0.25 else 0.0, 0.0, 0.27)
	var star := sparkle("Pop", Vector2.ZERO, 9.0, Color.WHITE, G)
	keep_colour(G)
	keyn(star, "material:shader_parameter/arm", func(t: float) -> float: return minf(9.0, 10.0 * (1.0 - t / 0.2)) if t < 0.2 else 0.0, 0.0, 0.23)
	light_burst("PopLight", 0.0, Vector2.ZERO, 50, G, 0.75, 0.45)
	light_burst("PopWhite", 0.0, Vector2.ZERO, 20, Color.WHITE, 0.7, 0.1)
	var warm := glow("Warmth", 48, {"radius": 46, "color": G, "alpha": 0.28}, {"at": Vector2(0, 4)})
	keyf(warm, "material:shader_parameter/alpha", func(t: float) -> float: return 0.28 * (1.0 - smooth(0.0, 1.3, t)), 0.0, 1.35)

	# ---- down drifting after them, stars thrown out, glints among the feathers
	var down := particles("Down", {"amount": 26, "lifetime": 2.6, "life_random": 0.45, "one_shot": true, "explosiveness": 1.0, "texture": "dot1",
		"emit": {"circle": 3.0}, "dir": -90, "spread": 180, "speed": [30, 140], "drag": 3.0, "gravity": Vector2(0, 14), "scale": [1.0, 2.0],
		"initial": gradient([Color.WHITE, F[4]], [0.0, 0.6]), "alpha_curve": [[0.0, 1.0], [0.7, 1.0], [1.0, 0.0]],
		"turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}})
	emit(down, 0.0)
	var NF := 7
	var stars := particles("Stars", {"amount": 10, "lifetime": 0.6, "life_random": 0.5, "one_shot": true, "explosiveness": 1.0,
		"dir": -90, "spread": 180, "speed": [60, 160], "drag": 3.0,
		"texture": asset("star.png", sparkle_strip(NF, func(u: float) -> float: return 2.2 * (1.0 - u) + 0.6, Color.WHITE, G, 3))})
	flip(stars, NF)
	emit(stars, 0.0)
	twin(stars, {"texture": "glow8", "modulate": Color(G, 0.4)})
	var GF := 7
	var glints := particles("Glints", {"at": Vector2(0, 8), "amount": 4, "lifetime": 0.4, "life_random": 0.5, "emitting": false, "emit": {"ring": [48.0, 14.0]},
		"texture": asset("glint.png", sparkle_strip(GF, func(u: float) -> float: return 2.0 * sin(u * PI) + 0.5, Color.WHITE, G, 3))})
	flip(glints, GF)
	emit(glints, 0.3, 2.2)
	twin(glints, {"texture": "glow8", "modulate": Color(G, 0.4)})


## A loose feather as the original's Feathers.add() rolls it.
func _feather(R: RandomNumberGenerator, f: Dictionary) -> Dictionary:
	var d := {"vx": 0.0, "vy": 0.0, "a": 0.0, "len": 7.0, "wid": 2.0, "delay": 0.0, "back": false, "side": 1.0 if R.randf() < 0.5 else -1.0,
		"ph": R.randf_range(0, TAU), "w": R.randf_range(3.2, 4.6), "amp": R.randf_range(6, 11), "sink": R.randf_range(14, 24),
		"va": R.randf_range(-9, 9), "tilt": R.randf_range(-0.35, 0.35), "age": 0.0}
	d.merge(f, true)
	return d


## The original's Feathers.update() for one feather: the throw braked hard by drag, then the pendulum flutter.
func _fly(f: Dictionary, dt: float) -> void:
	if f.delay > 0.0:
		f.delay -= dt
		return
	f.life -= dt
	if f.life <= 0.0:
		return
	f.age += dt
	f.vx -= f.vx * 3.4 * dt
	f.vy -= f.vy * 3.4 * dt
	var s := smooth(0.1, 0.6, f.age)
	var ph: float = f.age * f.w + f.ph
	var c := cos(ph)
	f.x += (f.vx + sin(ph) * f.amp * s * 0.9) * dt
	f.y += (f.vy + f.sink * s * (c * c * 1.5 - 0.2)) * dt
	var rest: float = roundf(f.a / PI) * PI + f.tilt + sin(ph) * 0.6
	f.a += f.va * dt * (1.0 - s) + (rest - f.a) * minf(1.0, dt * 5.0 * s)
