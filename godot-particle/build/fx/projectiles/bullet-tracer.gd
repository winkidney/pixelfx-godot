# reimagined-from: src/fx/projectiles/bullet-tracer.js@75f195d979ad43f1ec19046297fe7e5af1e77f47
# Bullet tracer: A white-hot slug tearing along, its tracer burning behind it in a long streak that sputters and cools from white through gold to red, shedding sparks and a thread of smoke.
# loop, 0.60 s, 200x40 canvas, origin [184.0, 18.0], backdrop sky
# The slug is still and the air streams past (the original's frame). The trace is a shader (fx/projectiles/
# _bullet-tracer_trace: the tapering banded body of burning gas, then the one-pixel line cooling to red, rippling and
# breaking into dashes, keyed off the clock); a thread of smoke comes off its cool end (an emitter of lit puffs,
# _projectiles.gd lobes(), streaming back, wavering and thinning); sparks of burning compound are shed off it,
# dropping and cooling as they fall behind (the projectiles' wake process shader with the original's beat() draws,
# two-tone streaks with a light twin); the slug is a small sprite drawn at build time; light along the trace and
# round the nose.
extends "res://build/fx/projectiles/_projectiles.gd"

const SLUG := ["..oyyp..", ".ypwwwwp", "ywwwwwww", ".ypwwwwp", "..oyyp.."]


## Streaks moved by the wake process shader (fx/projectiles/_energy-disc_wake), drawn two-tone by
## _energy-disc_spark, with a light twin.
func wake_emitter(name: String, C: Array, amount: int, params: Dictionary, glow_k := 0.45) -> void:
	for lit in [false, true]:
		var p := particles(name + ("Light" if lit else ""), {"amount": amount, "lifetime": root.duration, "local": true,
			"texture": "glow8" if lit else "streak8", "layer": "light" if lit else "color"})
		var pm := ShaderMaterial.new()
		pm.shader = pshader("energy-disc_wake")
		var pp := params.duplicate()
		if lit:
			pp.merge({"glow": 6.0, "glow_k": glow_k, "s0": C[0], "s1": C[1], "s2": C[2]}, true)
		for k in pp:
			var v: Variant = pp[k]
			pm.set_shader_parameter(k, float(v) if v is int else v)
		p.process_material = pm
		if not lit:
			var m := ShaderMaterial.new()
			m.shader = pshader("energy-disc_spark")
			for i in 4:
				m.set_shader_parameter("s%d" % i, C[i])
				keep_colour(C[i])
			p.material = m


func make() -> void:
	var F := pal("palette")
	var SM := pal("smoke")
	var S := int(meta.options.seed)
	var D: float = root.duration
	var L: float = meta.options.length
	var V: float = meta.options.speed
	var left := -float(root.origin.x) + 2.0

	# a thread of smoke off the cool end of the trace, wavering as it thins
	lobes("Smoke", {"at": Vector2(-L * 0.625, 0.5), "amount": 26, "lifetime": 0.7, "life_random": 0.28, "emit": {"box": Vector2(L * 0.175, 0.4)},
		"dir": 180, "spread": 2.5, "speed": [88, 92], "gravity": Vector2(0, -16), "radius": [2.6, 3.6],
		"scale_curve": [[0, 0.3], [0.5, 0.65], [1, 1.0]]},
		[[0.0, 0.95, 0.0, 0.0], [0.18, 0.9, 0.0, 0.5], [0.5, 0.75, 0.0, 0.3], [1.0, 0.55, 0.0, 0.0]], SM, SM)

	# the trace
	var tr := shape("Trace", pshader("bullet-tracer_trace"), Vector2(126, 12), {"len": L, "seed": float(S), "period": D, "cols": F, "t": 0.0, "fr": 0.0},
		{"at": Vector2(-61, 0)})
	key(tr, "material:shader_parameter/t", [[0.0, 0.0], [D, D]])
	keyf(tr, "material:shader_parameter/fr", func(t: float) -> float: return floorf(t * 30.0 + 1e-6), 0.0, D, 30.0, "nearest")
	glow_line("TraceLight", Vector2(-2, 1), Vector2(-L * 0.45, 1), 6, F[4], 0.35)
	glow_line("TraceHot", Vector2(-2, 1), Vector2(-L * 0.2, 1), 3, F[7], 0.3)

	# sparks of burning compound shed off the trace, dropping and cooling as they fall behind (beat(t, D, 16, S + 2))
	var sa := PackedVector4Array()
	var sb := PackedVector4Array()
	for i in 16:
		var life := rng([S + 2, i, 911]).range(0.1, 0.28)
		var r := rng([S + 2, i])
		var x := -r.range(4, L * 0.5)
		var y := 0.5 + r.range(-0.5, 1)
		var vx := -r.range(10, 80)
		var vy := r.range(-60, 50)
		sa.append(Vector4(life, atan2(vy, vx), Vector2(vx, vy).length(), 0.0))
		sb.append(Vector4(x, y, 0.0, 0.0))
	wake_emitter("Sparks", [F[7], F[6], F[4], F[3]], 16, {"slots": 16.0, "slot_a": sa, "slot_b": sb, "spawn_r": 0.0, "mode": 1.0,
		"V": V * 0.35, "k": 3.0, "g": 260.0, "stretch": 0.012, "max_len": 6.0, "clip_x": left + 8.0})

	# the slug: a white-hot pointed round, pale-rimmed, its nose a point of light
	var img := Image.create(8, 5, false, Image.FORMAT_RGBA8)
	var pm := {"w": Color.WHITE, "p": F[7], "y": F[6], "o": F[5]}
	for j in 5:
		for i in 8:
			if pm.has(SLUG[j][i]):
				img.set_pixel(i, j, pm[SLUG[j][i]])
	sprite("Slug", asset("slug", img), {"layer": "prop", "centered": false, "offset": Vector2(-1, -1)})
	light_at("Halo", Vector2(2, 1), 24, F[4], 0.5)
	light_at("Nose", Vector2(3, 1), 8, Color.WHITE, 0.55)
