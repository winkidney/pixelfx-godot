# reimagined-from: src/fx/fire/flamethrower.js@fd7a2da6ad55ef6fca734298aed7baf819d954ce
# Flamethrower: a pressurised jet shooting right: a blue pilot at the nozzle, a tight stream with surges racing down
# it, a sputter, burning drops falling off, a tip that curls up into smoke.
# The stream is fuel shot out of the nozzle at the original's speed: five emitters, one per band of its cross-section
# (a ragged dark skin, red, orange, yellow, a white core), their discs widening as they run out and sagging under a
# little gravity; the sputter is the emitters cut for a tenth of a second, so the gap races down the stream by
# itself. Flames lick up off it and ride along (a tongue-shaped particle shader); at the end the fuel rolls up and
# back on itself (orbiting puffs) and turns to smoke; burning drops fall off; the cough spits sparks and blobs; the
# light runs along the stream and dims with the sputter.
extends "res://build/fx/fire/_fire.gd"

const S := 3
const L := 112.0
const V := 280.0
const COUGH := 0.55


static func smoothf(a: float, b: float, x: float) -> float:
	var u := clampf((x - a) / (b - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func flow(te: float) -> float:
	var u := fposmod(te, root.duration)
	return 1.0 - smoothf(COUGH, COUGH + 0.04, u) * (1.0 - smoothf(COUGH + 0.1, COUGH + 0.16, u)) + 0.25 * exp(-pow((u - COUGH - 0.2) / 0.05, 2.0))


func cy(x: float) -> float:
	return 5.0 * pow(x / L, 2.0)


func width(x: float) -> float:
	return 2.1 + 5.0 * pow(x / L, 0.7)


func shader_mat(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/fx/fire/" + path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func make() -> void:
	fire_begin()
	var PL: PackedColorArray = root.ramps.pilot
	var GLOW := glow_colour()
	var SMOKE := Color("#2a2430").lerp(H[7], 0.3)
	var life := L / V
	var g := 2.0 * 5.0 * V * V / (L * L)

	# smoke rolling off the curl, drifting back and up
	var sm := gradient([Color(SMOKE, 0.0), Color(SMOKE, 0.5), Color(SMOKE, 0.4), Color(SMOKE.darkened(0.1), 0.2), Color(SMOKE, 0.0)], [0.0, 0.1, 0.4, 0.75, 0.97])
	keep_colour(SMOKE)
	particles("Smoke", {"layer": "soft", "at": Vector2(L - 4, cy(L) - 22), "amount": 30, "lifetime": 0.85, "randomness": 0.3,
		"texture": "disc11", "emit": {"box": Vector2(6, 5)}, "dir": -110, "spread": 20, "speed": [10, 20], "gravity": Vector2(-2, -6),
		"scale": [0.6, 0.9], "scale_curve": [[0, 0.6], [0.4, 1.0], [1, 1.25]], "ramp": sm})

	# the curl: burning fuel rolling forward, up and back over the top as it runs out of push, cooling
	var curl_pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = S * 100 + 1
	for i in 48:
		var R := rng.randf_range(9, 15)
		var a0 := rng.randf_range(-0.3, 0.5)
		curl_pts.append(Vector2(R * sin(a0) + rng.randf_range(-6, 2), R * cos(a0)))
	var curl_ramp := gradient([H[0], H[1], H[2], H[3], H[4], H[5], H[6], Color(H[7], 0.0)], [0.0, 0.05, 0.15, 0.3, 0.45, 0.6, 0.78, 0.95])
	var curl := particles("Curl", {"at": Vector2(L, cy(L) - 12), "amount": 26, "lifetime": 0.5, "randomness": 0.3, "texture": "dot4",
		"emit": {"points": curl_pts}, "orbit": [-1.2, -0.8], "gravity": Vector2(0, -10), "scale": [1.3, 2.0],
		"scale_curve": [[0, 0.8], [0.6, 1.2], [1, 1.5]], "ramp": curl_ramp})
	curl.material = shader_mat("_fire-breath_puff.gdshader", {"rim": H[6], "heart": H[0]})
	key(curl, "amount_ratio", sampled(func(t): return 1.0 if flow(t - L / V) >= 0.4 else 0.0), "nearest")

	# flames licking up off the burning fuel, riding along the stream, swept back by the wind of it
	var tg := particles("Tongues", {"at": Vector2(10, -4), "amount": 13, "lifetime": root.duration * 0.98, "texture": "dot4",
		"emit": {"box": Vector2(2, 0.5)}, "dir": 0, "speed": [(L - 14) / root.duration, (L - 14) / root.duration], "angle": [10, 25],
		"scale": [2.6, 3.4], "scale_curve": [[0, 0.25], [0.5, 0.75], [0.85, 1.0], [1, 0.0]],
		"ramp": gradient([H[3], H[4], H[4]], [0.0, 0.4, 0.8])})
	tg.material = shader_mat("_fire-breath_tongue.gdshader", {"rim": H[7], "heart": H[1], "width": 0.28, "lean": -0.2})

	# the stream: five bands of its cross-section, white core to ragged skin, widening and sagging as it runs out
	var bands := [
		["Skin", 1.15, [H[7]], 0.65],
		["Red", 1.0, [H[6]], 1.0],
		["Orange", 0.78, [H[4]], 1.0],
		["Yellow", 0.55, [H[2], H[4]], 1.0],
		["Core", 0.3, [H[0], H[2]], 1.0],
	]
	var stream := []
	for b in bands:
		var share: float = b[1]
		var pts := []
		for i in 11:
			var u := i / 10.0
			var d := 2.0 * width(u * L) * share * 0.92 + (0.6 if share > 1.0 else 0.0)
			# the end frays into the curl
			pts.append([u, d / 9.0 * (1.0 - smoothf(0.85, 1.0, u) * 0.7)])
		var o := {"at": Vector2(1, 0), "amount": 112, "lifetime": life, "texture": "disc9", "emit": {"box": Vector2(0.5, 0.3 if share < 1.0 else 0.8)},
			"dir": 0, "speed": [V, V], "gravity": Vector2(0, g), "scale_curve": pts}
		var cols: Array = b[2]
		if cols.size() > 1:
			o.ramp = gradient(cols, [0.0, 0.45])
		else:
			o.color = cols[0]
		if b[3] < 1.0:
			o.alpha_curve = [[0, 0.6], [1, 0.45]]
		var p := particles(b[0], o)
		stream.append(p)
	# the white strands twisting through the fuel, racing downstream
	stream.append(particles("Strands", {"at": Vector2(1, 0), "amount": 40, "lifetime": life * 0.9, "texture": "streak3", "align": true,
		"emit": {"box": Vector2(0.5, 1.0)}, "dir": 0, "spread": 1.6, "speed": [V * 1.02, V * 1.06], "gravity": Vector2(0, g),
		"ramp": gradient([H[0], H[1]], [0.0, 0.6])}))
	# the sputter: the jet coughs once a loop (its gap races down the stream on its own), then surges back
	for p in stream:
		key(p, "amount_ratio", sampled(func(t): return 1.0 if flow(t) >= 0.5 else 0.0), "nearest")
		key(p, "process_material:direction", sampled(func(t):
			var a := N(t, 1.2, S + 9) * 0.012
			return Vector3(cos(a), sin(a), 0.0)))

	# the pilot at the nozzle: a blue cone of gas where it lights, a white point
	for x in 6:
		for y in range(-2, 3):
			if absf(y) <= 2.0 - x * 0.3:
				var c: Color = (PL[2] if x < 2 else PL[1]) if absi(y) < 1 else PL[0]
				rect("Pilot%d_%d" % [x, y + 2], Rect2(x, y, 1, 1), c)
	var tip := ring("Nozzle", 3, {"radius": 1.6, "color": Color.WHITE}, {"at": Vector2(1.5, 0.5)})
	key(tip, "material:shader_parameter/radius", sampled(func(t): return 1.6 * flow(t)))

	# burning drops shaken off the stream: they arc down trailing flame and burn out
	var drops := particles("Drops", {"at": Vector2(57, 2), "amount": 5, "lifetime": 0.5, "randomness": 0.3, "texture": "streak6", "align": true,
		"emit": {"box": Vector2(37, 1)}, "dir": 5, "spread": 10, "speed": [84, 168], "damping": [60, 100], "gravity": Vector2(0, 260),
		"ramp": gradient([H[1], H[2], H[3], H[4], H[5]], [0.0, 0.2, 0.45, 0.7, 0.85])})
	key(drops, "amount_ratio", sampled(func(t): return 1.0 if flow(t - 0.2) >= 0.5 else 0.0), "nearest")

	# the cough spits sparks and a few blobs of burning fuel that fall short, and a puff of smoke
	var sparks := particles("CoughSparks", {"at": Vector2(4, 0), "amount": 12, "lifetime": 0.4, "one_shot": true, "explosiveness": 0.7,
		"randomness": 0.4, "texture": "streak4", "align": true, "dir": 0, "spread": 46, "speed": [120, 240], "damping": [200, 300],
		"gravity": Vector2(0, 300), "ramp": gradient([H[1], H[2], H[4], H[5]], [0.0, 0.3, 0.6, 0.85])})
	emit(sparks, COUGH)
	var blobs := particles("CoughBlobs", {"at": Vector2(4, 0), "amount": 5, "lifetime": 0.35, "one_shot": true, "explosiveness": 0.6,
		"texture": "dot4", "dir": -5, "spread": 12, "speed": [90, 170], "damping": [100, 160], "gravity": Vector2(0, 200),
		"scale": [0.9, 1.3], "ramp": gradient([H[1], H[3], H[4], H[6]], [0.0, 0.25, 0.5, 0.8])})
	blobs.material = shader_mat("_fire-breath_puff.gdshader", {"rim": H[6], "heart": H[0]})
	emit(blobs, COUGH + 0.01)
	var puff := particles("CoughSmoke", {"layer": "soft", "at": Vector2(8, 0), "amount": 2, "lifetime": 0.7, "one_shot": true,
		"explosiveness": 1.0, "texture": "disc7", "dir": -42, "speed": [26, 30], "scale_curve": [[0, 0.7], [1, 1.3]], "ramp": sm})
	emit(puff, COUGH)

	# light: the pilot, the stream, the burning tip, all dimming with the sputter
	var lights := [[Vector2(2, 0), 34.0, GLOW, 0.8, 0.0, 2.0], [Vector2(2, 0), 9.0, PL[2], 0.45, 0.0, 1.0]]
	var d := 8.0
	while d <= L:
		lights.append([Vector2(d, cy(d)), 12.0 + d * 0.16, GLOW, 0.3, d / V, 1.0])
		d += 8.0
	lights.append([Vector2(L, cy(L) - 10), 52.0, GLOW, 0.34, L / V, 1.0])
	var li := 0
	for l2 in lights:
		var k: float = l2[3]
		var lag: float = l2[4]
		var pw: float = l2[5]
		var gl := glow("Light%d" % li, l2[1], {"radius": l2[1], "color": l2[2], "alpha": k}, {"at": l2[0]})
		key(gl, "material:shader_parameter/alpha", sampled(func(t): return k * pow(flow(t - lag), pw)))
		li += 1
