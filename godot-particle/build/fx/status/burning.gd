# reimagined-from: src/fx/status/burning.js
# Burning: burning over time: small flames lick from four hot spots, trailing sparks and thin smoke; every 0.6 s they
# flare, the body flashes white then orange, scorch marks spread.
# The stand-in is the effect's own Actor node (shaders/actor.gdshader) so the flare can flash it; a small flame
# emitter sits on each hot spot of its outline, with embers, thin soft smoke and a warm glow that swell on each flare.
extends "res://addons/pixelfx_particles/core/build.gd"

const SPOTS := [Vector2(1, -36), Vector2(-5, -25), Vector2(5, -15), Vector2(7, -21)]
const FLARE := [0.0, 0.6]


func make() -> void:
	var body := actor_node()
	var flash := []
	var tint := []
	for t in FLARE:
		flash += [[t, 0.0], [t + 0.001, 1.0], [t + 0.07, 1.0], [t + 0.071, 0.0]]
		tint += [[t + 0.07, 0.55], [t + 0.3, 0.0]]
	key(body, "material:shader_parameter/flash", flash, "nearest")
	key(body, "material:shader_parameter/tint", tint)
	body.material.set_shader_parameter("tint_color", color("palette", 0.5))

	var glowing := glow("Glow", 30, {"radius": 26, "color": Color("#ffb060")}, {"at": Vector2(0, -20)})
	var g := []
	for t in FLARE:
		g += [[t, 0.6], [t + 0.25, 0.22], [t + 0.55, 0.16]]
	key(glowing, "material:shader_parameter/alpha", g)

	var i := 0
	for at in SPOTS:
		var f := particles("Flame%d" % i, {"at": at, "amount": 16, "lifetime": 0.4, "randomness": 0.3, "texture": "dot2",
			"emit": {"box": Vector2(1.5, 1)}, "dir": -90, "spread": 12, "speed": [16, 26], "damping": [10, 20],
			"scale_curve": [[0, 1.4], [1, 0.4]], "ramp": ramp("palette", {"reverse": true, "from": 0.2, "to": 0.95})})
		var r := []
		for t in FLARE:
			r += [[t, 1.0], [t + 0.12, 1.0], [t + 0.3, 0.55]]
		key(f, "amount_ratio", r)
		i += 1
	particles("Sparks", {"at": Vector2(0, -24), "amount": 12, "lifetime": 0.9, "randomness": 0.5, "texture": "dot1",
		"emit": {"box": Vector2(8, 14)}, "dir": -90, "spread": 40, "speed": [14, 30], "gravity": Vector2(0, -6),
		"ramp": ramp("palette", {"reverse": true, "from": 0.5, "to": 1.0, "alpha": [[0, 1], [0.8, 1], [1, 0]]})})
	var smoke := gradient([Color(meta.options.smoke).lerp(color("palette", 0.86), 0.2), Color(meta.options.smoke), Color(meta.options.smoke, 0.0)], [0.0, 0.5, 0.95])
	particles("Smoke", {"layer": "soft", "at": Vector2(1, -40), "amount": 6, "lifetime": 1.0, "texture": "dot2",
		"emit": {"box": Vector2(3, 2)}, "dir": -90, "spread": 10, "speed": [10, 16], "gravity": Vector2(2, 0), "ramp": smoke})
