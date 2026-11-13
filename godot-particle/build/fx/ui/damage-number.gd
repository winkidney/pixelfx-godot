# reimagined-from: src/fx/ui/damage-number.js@3f026840a40959e48e9ca9a8d1da59734157a1f6
# Damage number: a red -27 punches out of a hit spark, white for a frame, arcs up, lands with a squash, hops once and
# fades out as it lifts.
# The number is a PixelText (the original's word renderer) whose position and squash replay the original's little
# physics, sampled into keys; the hit is a two-frame spiky star (lines), a glint and a ring (the ring shader); sparks
# burst from it and two stars kick up where the number lands.
extends "res://addons/pixelfx_particles/core/build.gd"

const LAND := -8.0
const FADE := 0.84


func make() -> void:
	var C: PackedColorArray = root.ramps.palette
	var D: float = meta.duration
	# the hit: two frames of a fat white-hot star, then a thinner one, then a glint
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var star := group("Star", {"at": Vector2(0, -4)})
	show(star, 0.0, 0.07)
	for i in 9:
		var an := i / 9.0 * TAU + rng.randf_range(-0.2, 0.2)
		var L := rng.randf_range(8, 14)
		var d := Vector2(cos(an), sin(an))
		var big := line("Spike%d" % i, PackedVector2Array([Vector2.ZERO, d * L]), {"width": 3, "color": Color.WHITE, "parent": star})
		key(big, "width", [[0.0, 3.0], [0.035, 1.0]], "nearest")
		key(big, "default_color", [[0.0, Color.WHITE], [0.035, C[6] if i % 2 else C[5]]], "nearest")
		key(big, "points", [[0.0, PackedVector2Array([Vector2.ZERO, d * L])], [0.035, PackedVector2Array([d * L * 0.45 * 1.3, d * L * 1.3])]], "nearest")
	var core := ring("Core", 4, {"radius": 3.2, "color": Color.WHITE}, {"at": Vector2(0, -4)})
	show(core, 0.0, 0.035)
	var glint := sprite("Glint", "star5", {"at": Vector2(0, -4), "modulate": Color.WHITE})
	show(glint, 0.07, 0.16)
	key(glint, "scale", [[0.07, Vector2(1.0, 1.0)], [0.16, Vector2(0.2, 0.2)]])
	var hit_ring := ring("Ring", 14, {"radius": 3, "thickness": 2, "color": Color.WHITE}, {"at": Vector2(0, -4)})
	var rr := []
	for i in 14:
		var t := i / 60.0 * 1.0
		var k := t / 0.22
		rr.append([t, 3.0 + 10.0 * (1.0 - pow(1.0 - k, 3.0))])
	key(hit_ring, "material:shader_parameter/radius", rr)
	key(hit_ring, "material:shader_parameter/thickness", [[0.0, 2.0], [0.22, 1.0]])
	key(hit_ring, "material:shader_parameter/color", [[0.0, Color.WHITE], [0.088, C[5]]], "nearest")
	key(hit_ring, "material:shader_parameter/alpha", [[0.0, 1.0], [0.22, 0.0]])
	show(hit_ring, 0.0, 0.22)
	var flash_light := glow("HitLight", 30, {"radius": 30, "color": C[5]}, {"at": Vector2(0, -4)})
	key(flash_light, "material:shader_parameter/alpha", [[0.0, 0.7], [0.25, 0.0]])
	var sparks := particles("Sparks", {"at": Vector2(0, -4), "amount": 9, "lifetime": 0.25, "one_shot": true, "explosiveness": 1.0,
		"texture": "streak3", "align": true, "dir": -90, "spread": 85, "speed": [90, 200], "damping": [200, 400],
		"ramp": gradient([C[7], C[6], C[4], C[2]])})
	emit(sparks, 0.0)

	# the number: thrown up and out, lands, hops once, settles; punches out big and springs to size
	var word := text("Number", String(meta.options.text), {"font": "big", "sx": 2.0, "sy": 2.0, "at": Vector2(0, LAND),
		"fill": [C[3], C[3], C[4], C[5]], "edge": C[6], "under": C[2], "outline": C[0], "shadow": C[0] * Color(0.5, 0.5, 0.5, 1.0)})
	var glow_word := glow("WordLight", 22, {"radius": 18, "color": C[4]}, {"at": Vector2(0, LAND - 8)})
	var pos := []
	var sxs := []
	var sys := []
	var fl := []
	var al := []
	var gl := []
	var n := {"x": 0.0, "y": LAND, "vx": 34.0, "vy": -175.0, "sq": 0.0, "hops": 0}
	var landed_at := -1.0
	var dt := 1.0 / 120.0
	var t := 0.0
	var step := 0
	while t <= D + 1e-6:
		if step % 4 == 0:
			var s := 2.0 + 1.4 * exp(-t * 22.0) * cos(t * 30.0)
			var sx := s
			var sy := s
			if n.sq > 0.0:
				sx = s * (1.0 + 0.18 * n.sq)
				sy = s * (1.0 - 0.2 * n.sq)
			elif n.hops < 2 and absf(n.vy) > 120.0:
				sx = s * 0.92
				sy = s * 1.1
			var out := clampf((t - FADE) / (D - 0.04 - FADE), 0.0, 1.0)
			pos.append([t, Vector2(roundf(n.x), roundf(n.y - 6.0 * out * out))])
			sxs.append([t, sx])
			sys.append([t, sy])
			fl.append([t, 1.0 if t < 0.035 else (0.4 if t < 0.07 else 0.0)])
			al.append([t, 1.0 - out])
			gl.append([t, 0.3 * (1.0 - out) + (0.4 * (1.0 - t / 0.1) if t < 0.1 else 0.0)])
		# the original's update, at its 120 Hz
		t += dt
		step += 1
		if n.hops < 2:
			n.vy += 900.0 * dt
			n.vx -= n.vx * 2.0 * dt
			n.x += n.vx * dt
			n.y += n.vy * dt
			if n.y >= LAND and n.vy > 0.0:
				n.y = LAND
				n.sq = 1.0
				n.hops += 1
				n.vy = -n.vy * 0.36 if n.hops < 2 else 0.0
				if n.hops == 1:
					landed_at = t
		n.sq = maxf(0.0, n.sq - dt / 0.09)
	key(word, "position", pos, "nearest")
	key(word, "sx", sxs, "nearest")
	key(word, "sy", sys, "nearest")
	key(word, "flash", fl, "nearest")
	key(word, "modulate:a", al)
	key(glow_word, "material:shader_parameter/alpha", gl)
	key(glow_word, "position", pos.map(func(p): return [p[0], p[1] + Vector2(0, -8)]), "nearest")

	# two stars kick up where it first lands
	for s in [-1, 1]:
		var kick := particles("Kick%s" % ("L" if s < 0 else "R"), {"at": Vector2(roundf(n.x) + s * 14, LAND), "amount": 1,
			"lifetime": 0.3, "one_shot": true, "emitting": false, "texture": "plus3", "dir": -90 + s * 50, "spread": 20,
			"speed": [15, 35], "color": C[6], "alpha_curve": [[0, 1], [0.7, 1], [1, 0]]})
		emit(kick, landed_at)
