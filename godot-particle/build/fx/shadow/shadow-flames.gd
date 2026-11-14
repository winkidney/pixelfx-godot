# reimagined-from: src/fx/shadow/shadow-flames.js@e1228257fcc5af65dba6014b69afcf6f6b287bac
# Shadow flames: Inside-out fire on the floor: a black heart wrapped in violet flame with pale skin and tips, shedding embers and dark smoke.
# loop, 2.40 s, 104x112 canvas, origin [52.0, 102.0], backdrop ground
# ramp palette: #06040b #150c26 #2a1150 #461a84 #6f2cc0 #9d5cec #cfa6ff #f6eaff
# The tongues are a canvas shader (fx/shadow/_shadow-flames_tongues.gdshader: the original's five tongues of four
# nested layers on looping noise, inside out: pale skin, violet, deep violet, a black heart), drawn twice: whole on the
# colour layer, and its black heart again above the light layer so the violet bloom never lands on it. Licks of pale
# flame break off the tips, embers drift up with a light twin, dark smoke climbs behind (soft), a scorched floor and
# a flickering violet bloom.
extends "res://build/fx/shadow/_shadow.gd"

const D := 2.4
const TONGUES := [[-11, 20, 4.2, 1], [11, 22, 4.4, 2], [-6, 31, 5.4, 3], [6, 29, 5.2, 4], [0, 40, 6.6, 5]]


static func _rnd(x: float, y: float, s: float) -> float:
	var v := sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453
	return v - floorf(v)


static func noise2(x: float, y: float, s: float) -> float:
	var ix := floorf(x)
	var iy := floorf(y)
	var fx := x - ix
	var fy := y - iy
	var ux := fx * fx * (3.0 - 2.0 * fx)
	var uy := fy * fy * (3.0 - 2.0 * fy)
	var a := _rnd(ix, iy, s)
	var b := _rnd(ix + 1, iy, s)
	var c := _rnd(ix, iy + 1, s)
	var d := _rnd(ix + 1, iy + 1, s)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy) * 2.0 - 1.0


static func lnoise(t: float, v: float, seed: float, speed := 5.0) -> float:
	return noise2(cos(TAU * t / D) * speed + v, sin(TAU * t / D) * speed, seed)


func make() -> void:
	# the scorched floor: a dark burn
	ring("Burn", 23, {"radius": 22, "squash": 3.2 / 22.0, "color": C[1]}, {"at": Vector2(0, 0.5), "back": true})
	ring("BurnCore", 14, {"radius": 13.2, "squash": 3.2 / 22.0, "color": C[0]}, {"at": Vector2(0, 0.5), "back": true})

	# dark smoke climbing off the tips (behind), its underside lit
	var smoke := gradient([Color(C[3].lerp(C[2], 0.5), 0.0), Color(C[3].lerp(C[2], 0.5), 0.75), Color(C[2].lerp(C[1], 0.3), 0.6),
		Color(C[2].lerp(C[1], 0.6), 0.3), Color(C[1], 0.0)], [0.0, 0.1, 0.4, 0.75, 1.0], true)
	var sm := {"layer": "soft", "back": true, "at": Vector2(0, -30), "amount": 11, "lifetime": 1.9, "texture": "disc9",
		"emit": {"box": Vector2(6, 1)}, "dir": -90, "spread": 8, "speed": [20, 28], "scale": [0.7, 0.7],
		"scale_curve": [[0, 0.7], [1, 2.0]], "ramp": smoke, "turbulence": {"strength": 2.0, "scale": 3.0, "influence": [0.01, 0.02]}}
	var s1 := particles("Smoke", sm)
	life_rand(s1, 0.37)
	var lit := sm.duplicate()
	lit.ramp = gradient([Color(C[5], 0.0), Color(C[5], 0.4), Color(C[5], 0.15), Color(C[5], 0.0)], [0.0, 0.12, 0.5, 0.8], true)
	lit.at = Vector2(0, -28)
	lit.scale_curve = [[0, 0.38], [1, 1.1]]
	var s2 := particles("SmokeLit", lit)
	life_rand(s2, 0.37)
	s2.seed = s1.seed

	# light: a violet bloom round it (the floor's own pool, the bloom, a paler heart), flickering
	var fl := func(t: float) -> float: return 0.85 + 0.15 * lnoise(t, 0, 77, 6)
	glow("FloorLight", 47, {"radius": 46, "color": C[4], "alpha": 0.3}, {"at": Vector2(0, -2)})
	var g1 := glow("Bloom", 53, {"radius": 52, "color": C[4], "alpha": 0.5}, {"at": Vector2(0, -16)})
	keyf(g1, "material:shader_parameter/alpha", func(t: float): return 0.5 * fl.call(t))
	var g2 := glow("Heart", 27, {"radius": 26, "color": C[6], "alpha": 0.34}, {"at": Vector2(0, -12)})
	keyf(g2, "material:shader_parameter/alpha", func(t: float): return 0.34 * fl.call(t))

	# the tongues, and their black heart again above the light
	var params := {"c0": C[0], "c2": C[2], "c4": C[4], "c6": C[6], "c7": C[7], "white": Color.WHITE}
	var body := shape("Tongues", shadow_shader("shadow-flames_tongues"), Vector2(44, 60), params, {"at": Vector2(0, -30)})
	loop_t(body)
	params.heart_only = 1.0
	var heart := shape("Heart", shadow_shader("shadow-flames_tongues"), Vector2(44, 60), params, {"at": Vector2(0, -30)})
	loop_t(heart)
	over_light(heart)

	# licks of pale flame breaking off the tips
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var tips := PackedVector2Array()
	for i in 120:
		var tg: Array = TONGUES[rng.randi_range(0, 4)]
		tips.append(Vector2(tg[0] + rng.randf_range(-4, 4), -tg[1] * rng.randf_range(0.45, 0.85)))
	var lk := {"amount": 7, "lifetime": 0.5, "texture": "disc5", "emit": {"points": tips}, "dir": -90, "spread": 18,
		"speed": [20, 40], "scale": [0.75, 1.25], "scale_curve": [[0, 1.0], [1, 0.3]],
		"ramp": gradient([C[6], C[4]], [0.0, 0.5])}
	var l1 := particles("Licks", lk)
	life_rand(l1, 0.5)
	var lk2 := lk.duplicate()
	lk2.texture = "disc3"
	lk2.scale_curve = [[0, 0.55], [0.4, 0.34], [0.41, 0.0], [1, 0.0]]
	lk2.ramp = gradient([C[2], C[4]], [0.0, 0.3])
	var l2 := particles("LickCores", lk2)
	life_rand(l2, 0.5)
	l2.seed = l1.seed

	# embers drifting up, flickering, cooling to violet, each with a little light
	var em := {"at": Vector2(0, -10), "amount": 22, "lifetime": 1.8, "texture": "dot1", "emit": {"box": Vector2(12, 1)},
		"dir": -90, "spread": 8, "speed": [24, 46], "ramp": gradient([Color.WHITE, C[7], C[6], Color(C[6], 0.5), C[6], Color(C[6], 0.3)], [0.0, 0.3, 0.6, 0.72, 0.84, 0.94]),
		"turbulence": {"strength": 3.0, "scale": 3.0, "influence": [0.01, 0.02]}}
	var e1 := particles("Embers", em)
	life_rand(e1, 0.44)
	var el := em.duplicate()
	el.layer = "light"
	el.texture = "glow8"
	el.scale = [0.75, 0.75]
	el.ramp = gradient([Color(C[6], 0.35), Color(C[6], 0.0)], [0.0, 1.0], true)
	var e2 := particles("EmberLight", el)
	life_rand(e2, 0.44)
	e2.seed = e1.seed
