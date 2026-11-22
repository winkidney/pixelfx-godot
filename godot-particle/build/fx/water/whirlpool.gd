# reimagined-from: src/fx/water/whirlpool.js@e1772bb1a31c07713612d34e9a64914486888cfc
# Whirlpool: Seen from above, dark water winds into a vortex: foam arms spiral in, darkening as they're drawn down into a deep eye with a lit far rim, flecks of foam circling in after them.
# loop, 3.00 s, 128x84 canvas, origin [64.0, 42.0], backdrop dark
# ramp palette: #0a1630 #123063 #1b5596 #2a7fc4 #45a9e3 #86d3f5 #cdf1ff #ffffff
# The swirl is a canvas shader (fx/water/_whirlpool.gdshader): the see-through water on the soft layer, the foam
# arms wound along a turning log spiral, the lip and the eye on the colour layer, the light off the brightest foam on
# the light layer, all turning once a loop. Flecks of foam circle in after them: an emitter orbiting inside a group
# squashed to the ellipse, pulled inward as it goes. Glints wink on the foam; light pools on the swirl and the eye.
extends "res://build/fx/water/_water.gd"

const D := 3.0
const R := 60.0
const SY := 0.6
const K := 2.4
const EYE := 0.16


static func foam(rho: float, th: float, ph: float) -> float:
	var s := log(maxf(rho, 0.02))
	var a := th + K * s + ph * TAU
	var b := th + K * 1.35 * s + ph * TAU * 2.0
	var one := pow(0.5 + 0.5 * cos(7.0 * a + 0.9 * sin(3.0 * a + s * 4.0)), 26.0)
	var two := pow(0.5 + 0.5 * cos(11.0 * b + 1.3), 34.0) * 0.7
	var three := pow(0.5 + 0.5 * cos(17.0 * (th + K * 0.8 * s + ph * TAU * 3.0)), 30.0) * 0.8 * maxf(0.0, 1.0 - (rho - EYE) * 2.2)
	var dash := 0.55 + 0.45 * sin(s * 22.0 - ph * TAU * 4.0 + a * 2.0)
	return (one + two + three) * dash


func make() -> void:
	var ry := R * SY
	var size := Vector2(R * 2.0, ry * 2.0)
	var params := {"pal": C, "R": R, "sy": SY, "K": K, "eye": EYE}
	var water := params.duplicate()
	water.mode = 0
	water.translucent = true
	var body := shape("Water", water_shader("whirlpool"), size, water)
	loop_t(body)
	var arms := params.duplicate()
	arms.mode = 1
	var swirl := shape("Foam", water_shader("whirlpool"), size, arms)
	loop_t(swirl)
	var lit := shape("FoamLight", water_shader("whirlpool_light"), size, params)
	loop_t(lit)

	# flecks of foam drawn round and in along the arms: an orbit squashed to the swirl's ellipse
	var flat := group("Flat")
	flat.scale = Vector2(1.0, SY)
	var fleck := gradient([C[5], C[7], C[6], Color(C[6], 0.0)], [0.0, 0.2, 0.6, 0.92])
	var flecks := particles("Flecks", {"parent": flat, "local": true, "amount": 17, "lifetime": 1.7, "randomness": 0.3,
		"texture": "streak3", "align": true, "scale": [1.7, 1.7], "emit": {"ring": [0.8 * R, 0.78 * R]},
		"orbit": [-0.75, -0.6], "radial": [-16, -10], "ramp": fleck})
	# drawn inward as they circle (rho 0.8 -> 0.18 over a life)
	var pm: ParticleProcessMaterial = flecks.process_material
	pm.radial_velocity_min = -14.0
	pm.radial_velocity_max = -8.0

	# glints winking on the foam: the original's cycle of eight, replayed
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for g in 8:
		var born := rng.randf() * D
		var life := rng.randf_range(0.25, 0.45)
		var rho := rng.randf_range(0.35, 0.8)
		var th0 := rng.randf_range(0.0, TAU)
		glint("Glint%d" % g, func(t: float) -> Array:
			var age := fposmod(t - born, D)
			var th := th0 - age * 2.5
			var k := sin(PI * age / life) if age < life else 0.0
			if foam(rho, th, t / D) < 0.35:
				k = 0.0
			return [cos(th) * rho * R, sin(th) * rho * ry, k], 0.55)

	# light: a cool sheen on the swirl, a glow off the eye's lit rim
	glow("Sheen", R * 0.9, {"radius": R * 0.9, "color": C[4], "alpha": 0.2})
	glow("EyeLight", R * EYE * 1.6 + 6.0, {"radius": R * EYE * 1.6 + 6.0, "color": C[5], "alpha": 0.28})
	glow("RimLight", 14, {"radius": 14, "color": C[5], "alpha": 0.32}, {"at": Vector2(0, -ry * EYE * 0.8)})
