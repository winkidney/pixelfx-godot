# reimagined-from: src/fx/projectiles/laser-bolt.js@a503d9efc797355af967151e4edf957b3d00f280
# Laser bolt: A red laser bolt: a white-hot core in a rounded head, red bands tapering back, pulses racing down it, a tail that shimmers apart into wavering dashes.
# loop, 0.50 s, 128x32 canvas, origin [108.0, 16.0], backdrop sky
# The bolt is still and the air streams past (the original's frame): its body is a shader (fx/projectiles/
# _laser-bolt_body: the banded taper, the pulses, the shimmering edge and the two sparks spiralling round the core,
# keyed off the loop); the tail is dashes shed off its end, an emitter of streaks streaming back, wavering and cooling
# (with a light twin while they're young); the head's glint is the original's sparkle; light along it and round it.
extends "res://build/fx/projectiles/_projectiles.gd"

const L := 40.0


func make() -> void:
	var C := pal("palette")
	var D: float = root.duration

	# the shimmering tail: dashes shed off the bolt's end, wavering, flickering and cooling as they fall behind
	var dash := {"at": Vector2(-L * 0.8, 0.5), "amount": 14, "lifetime": 0.3, "life_random": 0.4, "texture": "streak6", "align": true,
		"emit": {"box": Vector2(0.5, 0.6)}, "dir": 180, "spread": 1.6, "speed": [150, 230], "scale": [0.65, 1.2],
		"scale_curve": [[0, 1.0], [1, 0.55]]}
	var d1 := dash.duplicate()
	d1.ramp = gradient([C[5], C[4], C[3], Color(C[3], 0.5)], [0.0, 0.3, 0.6, 0.85])
	particles("Dashes", d1)
	var d2 := dash.duplicate()
	d2.layer = "light"
	d2.texture = "glow8"
	d2.align = false
	d2.scale = [1.0, 1.0]
	d2.erase("scale_curve")
	d2.ramp = gradient([Color(C[4], 0.3), Color(C[4], 0.15), Color(C[4], 0.0)], [0.0, 0.2, 0.4], true)
	particles("DashLight", d2)

	# the body: the banded taper, its pulses and shimmer, the spiralling sparks
	var body := shape("Body", pshader("laser-bolt_body"), Vector2(56, 16), {"len": L, "cols": C, "t": 0.0, "fr": 0.0}, {"at": Vector2(-18, 0)})
	loop_t(body)
	keyf(body, "material:shader_parameter/fr", func(t: float) -> float: return floorf(t * 30.0 + 1e-6), 0.0, D, 30.0, "nearest")

	# the head's glint, flickering, and the light
	var g := func(t: float) -> float: return 0.75 + 0.25 * sin(t / D * TAU * 2.0)
	var glint := sparkle("Glint", Vector2(1, 0.5), 4, C[6], C[4])
	keyf(glint, "material:shader_parameter/arm", func(t: float) -> float: return 3.0 + roundf(g.call(t) * 2.0), 0.0, D, 30.0, "nearest")
	var gl := light_at("GlintLight", Vector2(1, 0.5), 12, C[6], 0.5)
	keyf(gl, "material:shader_parameter/radius", func(t: float) -> float: return 4.0 + (3.0 + roundf(g.call(t) * 2.0)) * 2.0, 0.0, D, 30.0, "nearest")
	glow_line("Beam", Vector2(1, 0.5), Vector2(-L, 0.5), 9, C[3], 0.4)
	var pool := light_at("Pool", Vector2(-2, 0.5), 20, C[3], 0.5)
	keyf(pool, "material:shader_parameter/alpha", func(t: float) -> float: return 0.5 * g.call(t))
	light_at("Hot", Vector2(1, 0.5), 6, Color.WHITE, 0.25)
