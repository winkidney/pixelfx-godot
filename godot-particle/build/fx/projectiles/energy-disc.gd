# reimagined-from: src/fx/projectiles/energy-disc.js@e46a4755323461d7918f479da876af02302291e4
# Energy disc: A sawblade of crackling energy spinning flat out as it flies: hooked teeth bright on their leading edges, a white hub, spiral arms churning, sparks flung off the teeth.
# loop, 0.50 s, 120x52 canvas, origin [92.0, 26.0], backdrop sky
# The disc is still and the air streams past (the original's frame). The disc is a shader (fx/projectiles/
# _energy-disc_disc: hub, collar, churning arms, rim, hooked teeth and their blur ring, keyed through three turns a
# loop); filaments crackle from hub to rim, three Line2Ds re-rolled every frame from the original's own rng. Speed
# lines peel off the rim (streak emitters); sparks are flung off the tooth tips along the spin and left behind in
# the air (a particle process shader replaying the original's wake(): _energy-disc_wake, drawn as two-tone streaks
# by _energy-disc_spark, with a light twin); light: a soft pool, a hot hub, a beam behind, a glint riding the rim.
extends "res://build/fx/projectiles/_projectiles.gd"


## Streaks moved by the wake process shader (each slot's numbers from its index: with lifetime = the loop it repeats
## as the original's beat() does), drawn two-tone by _energy-disc_spark; glow_k > 0 adds a light twin (same process).
func wake_emitter(name: String, C: Array, amount: int, params: Dictionary, look: Dictionary = {}, glow_k := 0.45) -> void:
	for lit in ([false, true] if glow_k > 0.0 else [false]):
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
			for k in look:
				m.set_shader_parameter(k, float(look[k]))
			p.material = m


func make() -> void:
	var C := pal("palette")
	var R: float = meta.options.size
	var V: float = meta.options.speed
	var S: int = meta.options.seed
	var D: float = root.duration
	var left: float = -root.origin.x + 2.0

	# speed lines peeling off the rim, top and bottom, stretching back and cooling: each slot with the original's own
	# draws (its beat(t, D, 8, S + 4))
	var la := PackedVector4Array()
	var lb := PackedVector4Array()
	for i in 8:
		var life := rng([S + 4, i, 911]).range(0.12, 0.22)
		var r := rng([S + 4, i])
		var side := -1.0 if r.chance(0.5) else 1.0
		var sp := r.range(180, 260)
		var ln := r.range(8, 16)
		la.append(Vector4(life, PI, sp, ln))
		lb.append(Vector4(0.0, side * (R + r.range(0.5, 3)), 0.0, 0.0))
	wake_emitter("SpeedLines", [C[5], C[4], C[3], C[3]], 8, {"slots": 8.0, "slot_a": la, "slot_b": lb, "spawn_r": 0.0,
		"spawn_at": Vector2(-2, 0), "mode": 1.0, "V": 0.0, "k": 0.0001, "len_range": Vector2(8, 16), "ahead": 1.0, "clip_x": left + 22.0},
		{"th0": 0.65, "th1": 0.3, "head_from": -1.0, "fade_tail": 1.0}, 0.0)
	glow_line("Wake", Vector2(-2, 0), Vector2(-26, 0), 8, C[3], 0.35)

	# sparks flung off the tooth tips along the spin, then left behind in the air (the original's beat(t, D, 20, S)
	# draws; their launch angles turn with the disc, as the original's do)
	var sa := PackedVector4Array()
	var sb := PackedVector4Array()
	for i in 20:
		var life := rng([S, i, 911]).range(0.12, 0.3)
		var r := rng([S, i])
		r.range(0, TAU)
		var a := r.range(0, TAU)
		sa.append(Vector4(life, a, r.range(120, 230), 0.0))
		sb.append(Vector4.ZERO)
	wake_emitter("Sparks", [Color.WHITE, C[5], C[4], C[3]], 20, {"slots": 20.0, "slot_a": sa, "slot_b": sb, "seed": float(S),
		"spawn_r": R + 3.5, "mode": 0.0, "V": V * 0.6, "k": 2.4, "g": 60.0, "stretch": 0.014, "max_len": 7.0, "clip_x": left + 8.0, "clip_y": 23.0})
	for nm in ["Sparks", "SparksLight"]:
		keyf(root.get_node(nm), "process_material:shader_parameter/ang_add", func(t: float) -> float: return TAU * 3.0 * t / D, 0.0, D, 60.0)

	# the disc
	var disc := shape("Disc", pshader("energy-disc_disc"), Vector2(32, 32), {"R": R, "teeth": float(meta.options.teeth), "cols": C, "t": 0.0})
	loop_t(disc)

	# filaments crackling from the hub to the rim, new every frame
	for j in 3:
		var fil := line("Filament%d" % j, PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]), {"color": Color.WHITE if j == 0 else C[6]})
		keyf(fil, "points", func(t: float) -> PackedVector2Array:
			var fr := floori(t * 30.0 + 1e-6)
			var g := rng([fr, j, S])
			var a0 := g.range(0, TAU)
			var out := PackedVector2Array()
			for i in 5:
				var rr := 2.5 + (R - 3.0) * i / 4.0
				var a := a0 + i * 0.25 + (g.range(-0.35, 0.35) if i > 0 else 0.0)
				out.append(Vector2(cos(a) * rr, sin(a) * rr))
			return out, 0.0, D, 30.0, "nearest")

	# light: a soft pool, a hot hub, a glint riding the top of the rim
	light_at("Pool", Vector2.ZERO, 30, C[3], 0.4)
	light_at("Hub", Vector2.ZERO, 6, C[5], 0.35)
	var gl := light_at("Glint", Vector2(R, 0), 5, C[6], 0.4)
	keyf(gl, "position", func(t: float) -> Vector2:
		var rot := TAU * 3.0 * t / D
		return Vector2(cos(rot) * R, sin(rot) * R), 0.0, D, 60.0)
