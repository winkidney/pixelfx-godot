# reimagined-from: src/fx/holy/sunburst.js@2083d4e40049dd9e9b183fddb7db37b640c6bfd9
# Sunburst: A white-hot core in a gold corona; long and short rays turn slowly round it, breathing, with glints running out along them that wink at the tips.
# loop, 4.00 s, 128x128 canvas, origin [64.0, 64.0], backdrop dark
# ramp palette: #3b1d2a #7a3a2c #c4652e #f0a040 #ffd25e #fff0a0 #fffbe0 #ffffff
# The sun is a shader (fx/holy/_sun.gdshader) keyed by the loop's clock: threads, tapered rays turning and breathing,
# the glints that run out along the long rays and wink at their tips, the flickering corona and the core; its light
# (fx/holy/_sun_light.gdshader) sums the gold glow, a beam down each ray and the glints' glows. Twinkles round it are
# particles stepping through the original's sparkle as it swells and shrinks (fx/holy/_flip.gdshader), with a light
# twin each.
extends "res://build/fx/holy/_holy.gd"


func make() -> void:
	var n_rays: int = meta.options.rays
	var sun := shape("Sun", holy_shader("sun"), Vector2(128, 128), {"rays": n_rays, "pal": C})
	loop_t(sun)
	var sun_light := shape("SunLight", holy_shader("sun_light"), Vector2(128, 128), {"rays": n_rays, "pal": C})
	loop_t(sun_light)

	# twinkles round it: a sparkle swells and shrinks over 0.35..0.7 s, 16..44 px out
	var NF := 11
	var strip := sparkle_strip(NF, func(u: float) -> float: return 1.0 + 2.4 * sin(u * PI) * 0.75, Color.WHITE, C[5], 4)
	var tw_o := {"amount": 2, "lifetime": 0.7, "life_random": 0.5, "emit": {"ring": [44.0, 16.0]},
		"alpha_curve": [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]], "color": Color.WHITE}
	var tw := particles("Twinkles", tw_o.merged({"texture": asset("sparkle.png", strip)}))
	flip(tw, NF)
	var twl := particles("TwinkleLight", tw_o.merged({"texture": "glow16", "layer": "light", "modulate": Color(1, 1, 1, 0.4)}))
	twl.process_material.anim_speed_min = 1.0
	twl.process_material.anim_speed_max = 1.0
