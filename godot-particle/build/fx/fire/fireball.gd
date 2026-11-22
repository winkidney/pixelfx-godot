# reimagined-from: src/fx/fire/fireball.js@0f9ab2b138afd733a34503395505b37f34ea68a7
# Fireball: a fireball flying right: a churning white-hot head with a corona of flame, a long torn tail of flame puffs
# cooling into smoke, embers shed behind.
# Everything is in the head's frame (it flies right, so what it sheds streams left and speeds up as the head outruns
# it): the head is a shader (fx/fire/_fireball_head.gdshader, the original's churning ball); the comet body is four
# layered tongues lying back off it and a corona of thin licks (fire/_fire.gd tongue() with a direction); the tail is
# flame puffs (a puff-shaped particle shader) cooling and swelling, then smoke; sparks and big embers fall behind;
# motes flick off the skin; a hot heart, a halo and a beam of light down the tail flicker.
extends "res://build/fx/fire/_fire.gd"

const S := 5
const R0 := 5.0
const V := 120.0
const BODY := [[30.0, 4.2, 0.0], [23.0, 4.4, -1.6], [22.0, 4.4, 1.6], [15.0, 4.6, 0.0]]
const CORONA := [[-1.3, 6.0, 1.1], [-1.8, 8.0, 1.2], [-2.3, 7.0, 1.1], [1.3, 6.0, 1.1], [1.8, 8.0, 1.2], [2.3, 7.0, 1.1]]


func shader_mat(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/fx/fire/" + path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func bob(t: float) -> Vector2:
	return Vector2(N(t, 3.0, S + 50) * 0.5, N(t, 2.5, S + 51) * 0.7)


func make() -> void:
	fire_begin()
	var GLOW := glow_colour()
	var SMOKE := SMOKE1.lerp(H[6], 0.3)

	# smoke the tail burns out into, left behind
	var sm := gradient([Color(SMOKE, 0.0), Color(SMOKE, 0.4), Color(SMOKE.lerp(SMOKE1, 0.5), 0.3), Color(SMOKE1, 0.15), Color(SMOKE1, 0.0)], [0.0, 0.1, 0.4, 0.75, 0.97])
	keep_colour(SMOKE)
	particles("Smoke", {"layer": "soft", "at": Vector2(-46, -2), "amount": 26, "lifetime": 0.55, "randomness": 0.4, "texture": "disc7",
		"emit": {"box": Vector2(16, 4)}, "dir": 185, "spread": 12, "speed": [60, 100], "damping": [150, 220], "gravity": Vector2(0, -12),
		"scale": [0.6, 1.0], "scale_curve": [[0, 0.6], [0.5, 1.0], [1, 1.2]], "ramp": sm})

	# the tail: flame puffs thrown off the back; the head outruns them; they cool, swell and rise
	var puff_ramp := gradient([H[1], H[2], H[3], H[4], H[5], H[6], H[7]], [0.0, 0.08, 0.2, 0.36, 0.55, 0.75, 0.92])
	var tail := particles("Tail", {"at": Vector2(-11, 0), "amount": 66, "lifetime": 0.5, "randomness": 0.45, "texture": "dot4",
		"emit": {"box": Vector2(10, 2.5)}, "dir": 180, "spread": 9, "speed": [48, 84], "gravity": Vector2(-150, -25),
		"scale": [0.85, 1.75], "scale_curve": [[0, 0.6], [0.4, 1.0], [0.8, 1.0], [1, 0.6]], "ramp": puff_ramp})
	tail.material = shader_mat("_fire-breath_puff.gdshader", {"rim": H[6], "heart": H[0], "rim_mix": 0.35, "rim_width": 0.12})

	# the body: tongues rooted in the head streaming back, and a corona licking round it
	var i := 0
	for b in BODY:
		var n := (S * 5 + i) * 17
		var dy: float = b[2]
		tongue("Body%d" % i, Vector2(1, dy * 0.5), b[0], b[1] * R0 / 5.0, {"layers": LAYERS, "life": 0.22, "dir": 180.0 - rad_to_deg(dy * 0.02),
			"height": func(t): return (0.82 + 0.25 * N(t, 4.0, n)) * (1.0 + 0.3 * maxf(0.0, N(t, 2.4, n + 3))),
			"sweep": func(t): return N(t, 3.0, n + 5) * 3.0 + dy})
		i += 1
	i = 0
	for c in CORONA:
		var n2 := (S * 5 + i + 20) * 17
		var a: float = c[0]
		var dv := Vector2(cos(a) * 0.55 - 1.0, sin(a) * 0.55).normalized()
		tongue("Corona%d" % i, Vector2(cos(a), sin(a)) * R0 * 0.85, c[1], c[2], {"layers": LAYERS, "life": 0.16, "dir": rad_to_deg(dv.angle()),
			"height": func(t): return 0.7 + 0.4 * (0.5 + 0.5 * N(t, 6.0, n2)),
			"sweep": func(t): return signf(a) * 1.5})
		i += 1

	# the head: a churning white-hot ball, bobbing a hair as it flies
	var hd := shape("Head", load("res://addons/pixelfx_particles/fx/fire/_fireball_head.gdshader"), Vector2(30, 24), {"radius": R0, "seed": float(S),
		"h0": H[0], "h1": H[1], "h2": H[2], "h3": H[3], "h4": H[4], "h5": H[5], "h6": H[6]})
	loop_t(hd)
	key(hd, "material:shader_parameter/offset", sampled(func(t): return bob(t)))

	# motes flicked off the head's skin: short hot streaks that die at once
	particles("Motes", {"at": Vector2(-1, 0), "amount": 4, "lifetime": 0.14, "randomness": 0.4, "texture": "streak3", "align": true,
		"emit": {"ring": [R0 * 0.9, R0 * 0.8]}, "dir": 0, "spread": 140, "speed": [30, 70], "gravity": Vector2(-200, 0),
		"ramp": gradient([H[1], H[3]], [0.0, 0.5])})
	# embers left behind: sparks the head outruns, falling as they cool, and a few big ones
	particles("Sparks", {"at": Vector2(-9, 0), "amount": 10, "lifetime": 0.42, "randomness": 0.4, "texture": "streak4", "align": true,
		"emit": {"box": Vector2(7, 3)}, "dir": 180, "spread": 16, "speed": [24, 84], "gravity": Vector2(-180, 50),
		"ramp": gradient([H[1], H[2], H[4], H[5]], [0.0, 0.3, 0.6, 0.85])})
	particles("BigEmbers", {"at": Vector2(-9, 0), "amount": 4, "lifetime": 0.42, "randomness": 0.4, "texture": "plus3",
		"emit": {"box": Vector2(7, 3)}, "dir": 180, "spread": 16, "speed": [24, 84], "gravity": Vector2(-180, 50),
		"ramp": gradient([H[2], H[4], H[6], Color(H[6], 0.0)], [0.0, 0.4, 0.75, 0.97])})

	# light: a beam down the tail, a warm halo, a hot heart, flickering
	var fl := func(t: float) -> float: return 0.85 + 0.15 * N(t, 9.0, S + 7)
	var beam := shape("TailLight", load("res://addons/pixelfx_particles/fx/fire/_fireball_glowline.gdshader"), Vector2(80, 32),
		{"a": Vector2(22, 0), "b": Vector2(-22, -2), "radius": 12.0, "color": GLOW, "alpha": 0.2}, {"at": Vector2(-28, 0)})
	key(beam, "material:shader_parameter/alpha", sampled(func(t): return 0.2 * fl.call(t)))
	var halo := glow("Halo", 42, {"radius": 42, "color": GLOW, "alpha": 0.42}, {"at": Vector2(-2, 0)})
	key(halo, "material:shader_parameter/alpha", sampled(func(t): return 0.42 * fl.call(t)))
	var heart := glow("Heart", 13, {"radius": 13, "color": H[1], "alpha": 0.3})
	key(heart, "material:shader_parameter/alpha", sampled(func(t): return 0.3 * fl.call(t)))
