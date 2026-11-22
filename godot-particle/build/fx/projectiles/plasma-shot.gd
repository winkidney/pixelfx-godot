# reimagined-from: src/fx/projectiles/plasma-shot.js@2e1a0f5b74cf80a7e98ae53500c644908d844edc
# Plasma shot: A glowing plasma blob: hot knots churning in its core, a corona crackling over its skin, its tail necking into droplets that tear off, cool and wink out behind.
# loop, 0.80 s, 144x60 canvas, origin [108.0, 30.0], backdrop sky
# The blob is still and the air streams past (the original's frame). The blob is a shader (fx/projectiles/
# _plasma-shot_blob: a field of balls, the body, its churning knots and wagging tail keyed off the loop, and the
# droplets that cling to the tail's end until the air tears them off, replayed from the original's cycle() in the
# build script and keyed in as arrays, so the skin necks as they part; the ion streak behind). The corona is arcs
# and rays (Line2Ds) re-rolled every frame from the original's own rng, a white spark and a light on each arc;
# motes flung off the corona stream back (the wake process shader of energy-disc, two-tone streaks and a light
# twin); light: a pool and a heart pulsing with the churn, a beam down the tail, a point on every droplet.
extends "res://build/fx/projectiles/_projectiles.gd"

const ND := 11


## Streaks moved by the wake process shader (fx/projectiles/_energy-disc_wake.gdshader), drawn two-tone by
## _energy-disc_spark, with a light twin (same as energy-disc.gd's).
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


## The original's droplets at time t (its cycle(t, D, 11, S, ...)): per slot {x, y, r, h, core, k} or {} when none.
func drops(t: float, R: float, S: int) -> Array:
	var D: float = root.duration
	var w := TAU * t / D
	var out := []
	for i in ND:
		var g := rng([S, i, 911])
		var born := g.next() * D
		var life := g.range(0.34, 0.5)
		var age := fposmod(t - born, D)
		if age >= life:
			out.append({})
			continue
		var r := rng([S, i])
		var k := age / life
		var pull := r.range(450, 800)
		var x := -R * 2.9 - 0.5 * pull * age * age - r.range(0, 16) * age
		var y := sin(w * 2.0 - 5.4 + age * 12.0) * 2.0 + r.range(-30, 30) * age * (0.4 + age)
		var rad := R * r.range(0.3, 0.48) * (1.0 - k * 0.6)
		out.append({"x": x, "y": y, "r": rad, "h": 0.97 * (1.0 - k * 0.75), "core": sqrt(maxf(0.0, 1.0 - k * 1.3) * 7.0 * 0.3) / rad, "k": k})
	return out


func make() -> void:
	var C := pal("palette")
	var R: float = meta.options.size
	var V: float = meta.options.speed
	var S: int = meta.options.seed
	var D: float = root.duration
	var left: float = -root.origin.x + 2.0

	# the blob, its droplets and the ion streak behind it
	var blob := shape("Blob", pshader("plasma-shot_blob"), Vector2(88, 44), {"R": R, "cols": C, "t": 0.0, "left": left + 4.0}, {"at": Vector2(-33, 0)})
	loop_t(blob)
	var keys_a := []
	var keys_b := []
	var nf := roundi(D * FPS)
	for f in nf + 1:
		var t := f / FPS
		var A := PackedVector4Array()
		var B := PackedVector4Array()
		for d in drops(minf(t, D - 1e-4) if f < nf else 0.0, R, S):
			if d.is_empty():
				A.append(Vector4(0, 0, 0, 0))
				B.append(Vector4(0, 1, 0, 0))
			else:
				A.append(Vector4(d.x, d.y, d.r, d.h))
				B.append(Vector4(d.core, d.k, 0, 0))
		var at := maxf(0.0, t - 0.002) if f > 0 else 0.0
		keys_a.append([at if f < nf else D, A])
		keys_b.append([at if f < nf else D, B])
	key(blob, "material:shader_parameter/drop_a", keys_a, "nearest")
	key(blob, "material:shader_parameter/drop_b", keys_b, "nearest")

	# the corona: jagged arcs leaping off the skin and back, a white spark and light on each, new every frame
	for j in 3:
		var arc_pts := func(t: float) -> PackedVector2Array:
			var fr := floori(t * 30.0 + 1e-6)
			var g := rng([fr, j, S])
			var a0 := g.range(-2.3, 2.3)
			var span := g.range(0.45, 0.9) * g.sign()
			var hgt := g.range(1.5, 3.5)
			var out := PackedVector2Array()
			for i in 7:
				var a := a0 + span * i / 6.0
				var rr := R + 0.6 + hgt * sin(PI * i / 6.0) + (g.range(-0.5, 0.5) if i % 6 != 0 else 0.0)
				out.append(Vector2(cos(a) * rr - 0.4, sin(a) * rr * 0.92))
			return out
		var arc := line("Arc%d" % j, PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]), {"color": C[6] if j == 0 else C[5]})
		keyf(arc, "points", arc_pts, 0.0, D, 30.0, "nearest")
		var tip := rect("ArcTip%d" % j, Rect2(0, 0, 1, 1), Color.WHITE)
		keyf(tip, "position", func(t: float) -> Vector2: return (arc_pts.call(t) as PackedVector2Array)[3].floor(), 0.0, D, 30.0, "nearest")
		var tl := light_at("ArcLight%d" % j, Vector2.ZERO, 6, C[5], 0.4)
		keyf(tl, "position", func(t: float) -> Vector2: return (arc_pts.call(t) as PackedVector2Array)[3], 0.0, D, 30.0, "nearest")
	for j in 4:
		var ray := line("Ray%d" % j, PackedVector2Array([Vector2.ZERO, Vector2(1, 0)]), {"color": C[4] if j % 2 else C[5]})
		keyf(ray, "points", func(t: float) -> PackedVector2Array:
			var fr := floori(t * 30.0 + 1e-6)
			var g := rng([fr, j + 9, S])
			var a := g.range(-2.2, 2.2)
			var l := g.range(1.5, 4)
			var p0 := Vector2(cos(a) * (R + 1.0) - 0.4, sin(a) * (R + 1.0) * 0.92)
			return PackedVector2Array([p0, p0 + Vector2(cos(a), sin(a)) * l]), 0.0, D, 30.0, "nearest")

	# motes flung off the corona, streaking back: each slot with the original's own draws (its beat(t, D, 14, S + 5))
	var sa := PackedVector4Array()
	var sb := PackedVector4Array()
	for i in 14:
		var life := rng([S + 5, i, 911]).range(0.12, 0.3)
		var r := rng([S + 5, i])
		var a := r.range(-2.4, 2.4)
		sa.append(Vector4(life, a, r.range(60, 130), 0.0))
		sb.append(Vector4.ZERO)
	wake_emitter("Motes", [Color.WHITE, C[6], C[5], C[3]], 14, {"slots": 14.0, "slot_a": sa, "slot_b": sb, "seed": float(S) + 5.0, "life_min": 0.12, "life_max": 0.3,
		"spawn_r": R + 1.0, "mode": 1.0, "ang_min": -2.4, "ang_max": 2.4, "v_min": 60.0, "v_max": 130.0, "V": V * 0.7, "k": 4.0, "g": 0.0,
		"stretch": 0.015, "max_len": 6.0, "clip_x": left + 4.0, "clip_y": 26.0}, 0.4)

	# light: a big soft pool, a hot heart pulsing with the churn, a beam down the tail, a point on every droplet
	var pulse := func(t: float) -> float: return 0.85 + 0.15 * sin(TAU * t / D * 4.0)
	for L in [["Pool", Vector2(-2, 0), 34.0, C[3], 0.8], ["Heart", Vector2.ZERO, 16.0, C[4], 0.35], ["Hot", Vector2(1, 0), 7.0, C[6], 0.3]]:
		var gl := light_at(L[0], L[1], L[2], L[3], L[4])
		var k0: float = L[4]
		keyf(gl, "material:shader_parameter/alpha", func(t: float) -> float: return k0 * pulse.call(t))
	glow_line("TailLight", Vector2(-R, 0), Vector2(-R * 4.6, 0), 7, C[3], 0.3)
	for i in ND:
		var dl := light_at("DropLight%d" % i, Vector2.ZERO, 8, C[2], 0.0)
		keyf(dl, "position", func(t: float) -> Vector2:
			var d: Dictionary = drops(t, R, S)[i]
			return Vector2(d.x, d.y) if not d.is_empty() else Vector2(-200, 0), 0.0, D, 30.0, "nearest")
		keyf(dl, "material:shader_parameter/radius", func(t: float) -> float:
			var d: Dictionary = drops(t, R, S)[i]
			return 3.0 + d.r * 2.0 if not d.is_empty() else 3.0, 0.0, D, 30.0, "nearest")
		keyf(dl, "material:shader_parameter/alpha", func(t: float) -> float:
			var d: Dictionary = drops(t, R, S)[i]
			return 0.6 * (1.0 - d.k) if not d.is_empty() and d.x >= left + 4.0 else 0.0, 0.0, D, 30.0, "nearest")
