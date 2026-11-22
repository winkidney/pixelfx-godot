# reimagined-from: src/fx/lightning/electrified.js@e79222e69e8344f1fd0d3bb6f40afc4ab8757692
# Electrified: Current runs through a character: arcs crawl over and leap across the body, sparks spit off, the body flares to an electric silhouette on each jolt, and the feet ground out.
# loop, 2.00 s, 108x92 canvas, origin [54.0, 76.0], backdrop ground, stand-in 2
# The stand-in is the effect's own Actor with a shader (fx/lightning/_shock_actor.gdshader) that flares it to an
# electric silhouette on each of the three jolts; a cold aura (its outline, lifted from the stand-in's pixels here)
# flickers behind it; crackles (fx/lightning/_volt.gd) leap between points of its edge, re-picked every other frame
# and re-struck every frame, from the original's own choices made here with a fixed seed; the feet ground out to
# the floor; sparks burst off the edge on each jolt (radial bursts from the silhouette) and a few spit between.
extends "res://build/fx/lightning/_base.gd"

const N := 60
const JOLTS := [[3, 1.0], [22, 0.7], [41, 0.9]]


func jolt(f: int) -> Array:
	for j in JOLTS:
		if f >= j[0] and f < j[0] + 3:
			return [f - j[0], j[1]]
	return []


func make() -> void:
	ground()
	var C := pal()
	var E := actor_points(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	# the body: flares to an electric silhouette on each jolt
	var body := actor_node()
	var m := ShaderMaterial.new()
	m.shader = load("res://addons/pixelfx_particles/fx/lightning/_shock_actor.gdshader")
	m.set_shader_parameter("ramp", PackedColorArray([C[1], C[2], C[3], C[4], C[5], C[6], C[7]]))
	body.material = m

	# a cold aura: a broken outline flickering round the body, light pooling at the feet
	var aura := sprite("Aura", _outline(), {"back": true, "centered": false})
	aura.offset = Vector2(-13, -39)
	var aura_glow := glow("AuraGlow", 32, {"radius": 30, "color": C[3]}, {"at": Vector2(0, -18), "back": true})
	glow("FeetGlow", 24, {"radius": 22, "color": C[4], "alpha": 0.18}, {"at": Vector2(0, -2), "back": true})
	var jolt_glow := glow("JoltGlow", 28, {"radius": 26, "color": C[5], "alpha": 0.0}, {"at": Vector2(0, -19)})

	var arcs := []
	for i in 4:
		arcs.append(volt("Arc%d" % i, Vector2.ZERO, Vector2(1, 0), {"style": 1, "jag": 0.42, "forks": 0.35, "rate": 30.0, "light": 0.4}))
	var feet := volt("Ground", Vector2.ZERO, Vector2(1, 0), {"style": 1, "jag": 0.45, "forks": 0.3, "rate": 30.0, "light": 0.35, "k": 0.7})
	var feet_glow := glow("GroundGlow", 12, {"radius": 10, "color": C[5], "alpha": 0.0})

	var K := {"jolt": [], "lift": [], "aura": [], "aura_a": [], "jg": [], "fv": [], "ff": [], "ft": [], "fg": [], "fga": []}
	var A := []
	for i in 4:
		A.append({"v": [], "a": [], "b": [], "k": []})
	var pick := {}
	for f in N + 1:
		var ff := f % N
		var at := maxf(0.0, (f - 0.5) / FPS)
		var j := jolt(ff)
		var r := RandomNumberGenerator.new()
		r.seed = hash(Vector2i(4, ff))
		K.jolt.append([at, not j.is_empty()])
		K.lift.append([at, ([1.1, 0.6, -0.2][j[0]] * j[1]) if j else 0.0])
		K.aura.append([at, C[4] if j else (C[2] if r.randf() < 0.5 else C[1])])
		K.aura_a.append([at, 0.55 * j[1] if j else 0.16 + 0.1 * r.randf()])
		K.jg.append([at, 0.5 * j[1] * (1.0 - j[0] / 3.0) if j else 0.0])
		# arcs: picked every other frame, two or three at a time (four on a jolt)
		var rp := RandomNumberGenerator.new()
		rp.seed = hash(Vector2i(7, ff >> 1))
		var n := 2 + (2 if j else rp.randi_range(0, 1))
		for i in 4:
			if i < n:
				var a: Vector2 = E[rp.randi_range(0, E.size() - 1)]
				var ang := rp.randf_range(0, TAU)
				var d := rp.randf_range(6, 14)
				var b := a + Vector2(cos(ang), sin(ang)) * d
				for _k in 10:
					var c: Vector2 = E[rp.randi_range(0, E.size() - 1)]
					if c.distance_to(b) < 5.0 and c.distance_to(a) > 4.0:
						b = c
				A[i].v.append([at, true])
				A[i].a.append([at, a])
				A[i].b.append([at, b])
				A[i].k.append([at, (0.75 if ff & 1 else 0.95) * rp.randf_range(0.6, 1.0)])
			else:
				A[i].v.append([at, false])
		# the feet ground out now and then
		if rp.randf() < (0.9 if j else 0.35):
			var s := 1.0 if rp.randf() < 0.5 else -1.0
			var x0 := s * rp.randf_range(3, 8)
			K.fv.append([at, true])
			K.ff.append([at, Vector2(x0, -1.5)])
			K.ft.append([at, Vector2(x0 + s * rp.randf_range(5, 12), -0.5)])
			K.fg.append([at, Vector2(x0, -1)])
			K.fga.append([at, 0.35])
		else:
			K.fv.append([at, false])
			K.fga.append([at, 0.0])
	key(body, "material:shader_parameter/jolt", K.jolt, "nearest")
	key(body, "material:shader_parameter/lift", K.lift, "nearest")
	key(aura, "modulate", K.aura, "nearest")
	key(aura_glow, "material:shader_parameter/alpha", K.aura_a, "nearest")
	key(jolt_glow, "material:shader_parameter/alpha", K.jg, "nearest")
	for i in 4:
		key(arcs[i], "visible", A[i].v, "nearest")
		key(arcs[i], "from", A[i].a, "nearest")
		key(arcs[i], "to", A[i].b, "nearest")
		key(arcs[i], "k", A[i].k, "nearest")
	key(feet, "visible", K.fv, "nearest")
	key(feet, "from", K.ff, "nearest")
	key(feet, "to", K.ft, "nearest")
	key(feet_glow, "position", K.fg, "nearest")
	key(feet_glow, "material:shader_parameter/alpha", K.fga, "nearest")

	# sparks: a spray off the edge with every jolt, and a few spat out between
	var upper := PackedVector2Array()
	for p in E:
		upper.append(p)
	var i := 0
	for jj in JOLTS:
		var sp := sparks("Sparks%d" % i, {"amount": 9, "lifetime": 0.4, "randomness": 0.5, "emit": {"points": upper},
			"spread": 40, "speed": [0, 0]})
		_radial(sp, 60.0 * jj[1], 150.0 * jj[1])
		emit(sp, jj[0] / FPS)
		i += 1
	var spit := sparks("Spit", {"amount": 2, "lifetime": 0.3, "one_shot": false, "explosiveness": 0.0, "emitting": true,
		"randomness": 0.5, "emit": {"points": upper}, "spread": 35, "speed": [0, 0]})
	_radial(spit, 50.0, 110.0)


## Out from the body's middle, a little up, as the original throws them (away from (0, -19), 30 px/s up).
func _radial(p: GPUParticles2D, lo: float, hi: float) -> void:
	var m: ParticleProcessMaterial = p.process_material
	m.radial_velocity_min = lo
	m.radial_velocity_max = hi
	m.velocity_pivot = Vector3(0, -19, 0)
	m.initial_velocity_min = 20.0
	m.initial_velocity_max = 40.0
	m.direction = Vector3(0, -1, 0)


## The 1 px outline just outside the stand-in (white, tinted by modulate), with a 1 px margin round it.
func _outline() -> ImageTexture:
	var img: Image = load(EFFECT.STAND_INS[2]).get_image()
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	var on := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and img.get_pixel(x, y).a >= 0.5
	for y in range(-1, h + 1):
		for x in range(-1, w + 1):
			if not on.call(x, y) and (on.call(x - 1, y) or on.call(x + 1, y) or on.call(x, y - 1) or on.call(x, y + 1)):
				out.set_pixel(x + 1, y + 1, Color.WHITE)
	return ImageTexture.create_from_image(out)
