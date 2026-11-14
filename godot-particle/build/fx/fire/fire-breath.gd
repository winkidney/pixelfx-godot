# reimagined-from: src/fx/fire/fire-breath.js@0f9ab2b138afd733a34503395505b37f34ea68a7
# Fire breath: a roaring cone of fire streaming right from the mouth: white-hot at the lips, billowing out and
# cooling to red and smoke at its edges, sparks thrown out ahead.
# A white-hot jet of overlapping layered tongues lying along the stream (fire/_fire.gd tongue() with a direction) at
# the lips; billows blown out of the mouth that slow, swell, rise and cool; further out the same stream as tongues
# licking up and back (a tongue-shaped particle shader, fx/fire/_fire-breath_tongue.gdshader); licks curling off the
# cone's edges; bright streaks racing through its heart; sparks flung ahead and falling; embers and rolling smoke off
# the far end; light along the cone, all surging with the roar.
extends "res://build/fx/fire/_fire.gd"

const S := 6
const A := 0.24
const V := 320.0
const JET := [[42.0, 4.2, 0.0], [32.0, 3.8, -0.08], [30.0, 3.8, 0.08], [20.0, 4.6, 0.0]]


func roar(t: float) -> float:
	return 0.85 + 0.15 * N(t, 3.0, S + 1)


func sway(t: float) -> float:
	return N(t, 1.3, S + 2) * 0.05


func tongue_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/fx/fire/_fire-breath_tongue.gdshader")
	m.set_shader_parameter("rim", H[7])
	m.set_shader_parameter("heart", H[1])
	m.set_shader_parameter("width", 0.3)
	m.set_shader_parameter("lean", -0.12)
	return m


func puff_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/fx/fire/_fire-breath_puff.gdshader")
	m.set_shader_parameter("rim", H[6])
	m.set_shader_parameter("heart", H[0])
	return m


## The cone's stream: emitters aimed along it, speed surging with the roar and aim swaying.
func stream(p: GPUParticles2D, vmin: float, vmax: float, off := -0.04) -> void:
	key(p, "process_material:initial_velocity_min", sampled(func(t): return vmin * roar(t)))
	key(p, "process_material:initial_velocity_max", sampled(func(t): return vmax * roar(t)))
	key(p, "process_material:direction", sampled(func(t):
		var a: float = sway(t) + off
		return Vector3(cos(a), sin(a), 0.0)))


func make() -> void:
	fire_begin()
	var GLOW := glow_colour()
	var SMOKE := SMOKE1.lerp(H[6], 0.3)

	# rolling smoke off the far end of the cone, swelling and thinning as it rises
	var sm := gradient([Color(SMOKE, 0.0), Color(SMOKE, 0.42), Color(SMOKE.lerp(SMOKE1, 0.5), 0.36), Color(SMOKE1.darkened(0.1), 0.2), Color(SMOKE1.darkened(0.2), 0.0)],
		[0.0, 0.1, 0.4, 0.75, 0.97])
	var smoke := particles("Smoke", {"layer": "soft", "at": Vector2(72, -10), "amount": 34, "lifetime": 0.85, "randomness": 0.3,
		"texture": "disc13", "emit": {"box": Vector2(22, 9)}, "dir": -40, "spread": 30, "speed": [25, 60], "damping": [30, 50],
		"gravity": Vector2(0, -26), "scale": [0.7, 1.0], "scale_curve": [[0, 0.7], [0.5, 1.0], [1, 1.2]], "ramp": sm})

	# billows blown out of the mouth: slow, swell, rise, cool
	var billow_ramp := gradient([H[0], H[1], H[2], H[3], H[4], Color(H[5], 0.6), Color(H[6], 0.0)], [0.0, 0.1, 0.25, 0.4, 0.55, 0.75, 0.9])
	var billows := particles("Billows", {"at": Vector2(7, 0), "amount": 130, "lifetime": 0.62, "randomness": 0.35, "texture": "dot4",
		"emit": {"box": Vector2(3, 1.5)}, "dir": -2.3, "spread": rad_to_deg(A), "speed": [240, 352], "damping": [440, 500],
		"gravity": Vector2(0, -65), "scale": [1.3, 2.0], "scale_curve": [[0, 0.45], [0.3, 1.0], [0.6, 0.8], [1, 0.5]], "ramp": billow_ramp})
	billows.material = puff_material()
	stream(billows, 240, 352)

	# further out each billow tears into a tongue licking up and back, cooling to deep red
	var tongue_ramp := gradient([Color(H[2], 0.0), H[2], H[3], H[4], H[5], H[6], H[7]], [0.0, 0.3, 0.4, 0.5, 0.62, 0.74, 0.86])
	var tongues := particles("Tongues", {"at": Vector2(7, 0), "amount": 64, "lifetime": 0.62, "randomness": 0.35, "texture": "dot4",
		"emit": {"box": Vector2(3, 1.5)}, "dir": -2.3, "spread": rad_to_deg(A) * 1.1, "speed": [240, 352], "damping": [480, 560],
		"gravity": Vector2(0, -150), "angle": [22, 42], "scale": [3.0, 4.2], "scale_curve": [[0, 0.6], [0.35, 0.9], [0.7, 0.85], [1, 0.0]],
		"ramp": tongue_ramp})
	tongues.material = tongue_material()
	stream(tongues, 240, 352)

	# licks curling off the edges of the cone
	for i in 6:
		var n := (S * 3 + i) * 19
		var side := 1.0 if i % 2 else -1.0
		var d := 18.0 + (i >> 1) * 16.0
		var L := (9.0 + 5.0 * 0.5) * (1.0 - d / 120.0)
		var dv := Vector2(0.75, side * 0.45 - 0.48).normalized()
		var at := Vector2(d, side * d * A * 0.85 - d * 0.06)
		tongue("Lick%d" % i, at, L, 1.6 + L * 0.08, {"layers": LAYERS, "life": 0.22, "dir": rad_to_deg(dv.angle()),
			"height": func(t): return 0.9 + 0.25 * N(t, 5.0, n + 1),
			"sweep": func(t): return -side * 3.0 + N(t, 2.0, n) * 1.5})

	# the roar: bright streaks racing out through the heart of the cone
	var streaks := particles("Streaks", {"at": Vector2(6, 0), "amount": 10, "lifetime": 0.19, "randomness": 0.4, "texture": "streak6",
		"align": true, "emit": {"box": Vector2(1, 1)}, "dir": -1.7, "spread": rad_to_deg(A * 0.6), "speed": [330, 470],
		"damping": [500, 700], "gravity": Vector2(0, -60), "ramp": gradient([H[0], H[1], H[2], H[3]], [0.0, 0.3, 0.55, 0.8])})
	stream(streaks, 330, 470, -0.03)

	# the jet at the lips: white-hot, overlapping tongues fluttering as the breath roars
	var j := 0
	for jet in JET:
		var n2 := (S * 5 + j) * 17
		var a0: float = jet[2]
		tongue("Jet%d" % j, Vector2.ZERO, jet[0], jet[1], {"layers": LAYERS, "life": 0.13, "dir": rad_to_deg(a0), "density": 0.8,
			"height": func(t): return roar(t) * (0.85 + 0.2 * N(t, 5.0, n2)),
			"sweep": func(t): return N(t, 3.0, n2 + 3) * 3.0 + sway(t) * jet[0]})
		j += 1

	# sparks flung out ahead and falling; embers lifting off the far end
	particles("Sparks", {"at": Vector2(30, 0), "amount": 12, "lifetime": 0.4, "randomness": 0.4, "texture": "streak4", "align": true,
		"emit": {"box": Vector2(26, 5)}, "dir": -6.9 - 7.0, "spread": rad_to_deg(A * 1.8), "speed": [140, 280], "damping": [150, 250],
		"gravity": Vector2(0, 190), "ramp": gradient([H[1], H[2], H[4], H[5]], [0.0, 0.3, 0.6, 0.85])})
	particles("Embers", {"at": Vector2(75, -4), "amount": 13, "lifetime": 1.1, "randomness": 0.4, "texture": "dot1",
		"emit": {"box": Vector2(25, 10)}, "dir": -60, "spread": 25, "speed": [25, 60], "damping": [25, 45], "gravity": Vector2(0, -20),
		"ramp": ember_ramp(), "turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.02, 0.03]}})

	# light: a flare at the lips, light all along the cone widening with it, a broad halo
	var lights := [[Vector2(3, 0), 34.0, GLOW, 0.75, true], [Vector2(3, 0), 10.0, H[0], 0.55, false]]
	var d2 := 10.0
	while d2 < 126.0:
		lights.append([Vector2(d2, -d2 * 0.1), 10.0 + d2 * 0.2, GLOW, 0.32 * (1.0 - d2 / 150.0), true])
		d2 += 8.0
	lights.append([Vector2(64, -12), 96.0, GLOW, 0.16, true])
	var li := 0
	for L2 in lights:
		var k: float = L2[3]
		var g := glow("Light%d" % li, L2[1], {"radius": L2[1], "color": L2[2], "alpha": k}, {"at": L2[0]})
		if L2[4]:
			key(g, "material:shader_parameter/alpha", sampled(func(t): return k * roar(t)))
		li += 1
