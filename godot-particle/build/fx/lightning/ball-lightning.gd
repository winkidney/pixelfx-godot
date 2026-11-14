# reimagined-from: src/fx/lightning/ball-lightning.js@4c7331701d630b3d58746c470764cc60c4459a03
# Ball lightning: A crackling ball of plasma drifts on a wandering loop, spitting arcs off its skin and leaving a wake of fading motes, and zaps the floor when it dips low.
# loop, 4.00 s, 136x104 canvas, origin [68.0, 92.0], backdrop ground
# The ball is a group keyed along the original's closed path every frame: stacked discs (a halo, a churning skin,
# a white heart) whose radius breathes, three hot spots rolling round it, a corona of short streaks bristling off it
# (an emitter riding the ball); the wake is two emitters it drags (discs shrinking and cooling, a halo under them,
# their light); motes shed along the path drift and die; crackles (fx/lightning/_volt.gd) spit off the skin, re-thrown
# every frame; once a loop, low over the floor, a bolt zaps down, the floor flashes and sparks fly.
extends "res://build/fx/lightning/_base.gd"

const P := 4.0
const N := 120
const ZAP := 62
const GX := 2.0


static func at_t(t: float) -> Vector2:
	var a := t / P * TAU
	return Vector2(38.0 * sin(a) + 9.0 * sin(2.0 * a + 1.0), -42.0 + 13.0 * sin(2.0 * a + 0.4) + 6.0 * sin(3.0 * a + 0.5))


func make() -> void:
	ground()
	var C := pal()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9

	# light under the ball on the floor, stronger as it comes low
	var pool := glow("Pool", 32, {"radius": 30, "color": C[3], "alpha": 0.2}, {"at": Vector2(0, -2)})

	# the wake: discs it drags behind, shrinking and cooling, a darker halo under them, their light
	var wake_o := {"amount": 14, "lifetime": 14 * 0.034, "texture": "disc7", "speed": [0, 0], "preprocess": 0.05,
		"scale_curve": [[0, 6.6 / 7.0], [1, 0.9 / 7.0]], "ramp": gradient([C[6], C[5], C[4]], [0.0, 0.35, 0.7]),
		"alpha_curve": [[0, 1], [0.6, 1], [0.61, 0.5], [1, 0.5]]}
	var halo_o := wake_o.duplicate()
	halo_o.merge({"texture": "disc9", "back": true, "scale_curve": [[0, 8.2 / 9.0], [1, 2.4 / 9.0]], "ramp": gradient([C[3], C[2]], [0.0, 0.35])}, true)
	var wake_light_o := {"layer": "light", "amount": 14, "lifetime": 14 * 0.034, "texture": "glow16", "speed": [0, 0], "preprocess": 0.05,
		"scale_curve": [[0, 20.0 / 16.0], [1, 6.0 / 16.0]], "color": C[4], "alpha_curve": [[0, 0.25], [1, 0.0]]}
	var wake := particles("Wake", wake_o)
	var halo := particles("WakeHalo", halo_o)
	var wake_light := particles("WakeLight", wake_light_o)
	# the wake the ball already had when the loop starts (the emitters only begin dragging one at 0): the same discs
	# where it was, each dropping out as the emitters' own wake reaches its age
	for i in range(1, 15):
		var u := i / 14.0
		var rr := 3.0 * (1.0 - u) + 0.3
		var lead := orb("Lead%d" % i, at_t(-i * 0.034), [[rr + 0.8, C[3] if u < 0.35 else C[2]], [rr, C[6] if u < 0.35 else (C[5] if u < 0.7 else C[4])]])
		var keys := []
		for f in i + 1:
			keys.append([f / FPS, at_t(f / FPS - i * 0.034)])
		for o in lead:
			key(o, "position", keys)
			show(o, 0.0, i * 0.034)
	# motes shed along the path, drifting and dying
	var motes := particles("Motes", {"amount": 8, "lifetime": 0.75, "randomness": 0.33, "texture": "dot1", "preprocess": 0.05,
		"emit": {"circle": 3.0}, "spread": 180, "speed": [4, 14], "gravity": Vector2(0, 8),
		"ramp": gradient([C[6], C[4], C[3]], [0.0, 0.4, 0.7]), "alpha_curve": [[0, 1], [0.75, 1], [0.76, 0.5], [1, 0.5]]})

	# the ball
	var ball := group("Ball")
	var skin_out: ColorRect = ring("Halo", 9, {"radius": 6.5, "color": C[2]}, {"parent": ball})
	var skin: ColorRect = ring("Skin", 8, {"radius": 5.2, "color": C[4]}, {"parent": ball})
	var inner: ColorRect = ring("Inner", 6, {"radius": 3.7, "color": C[5]}, {"parent": ball, "at": Vector2(-0.4, -0.4)})
	var spots := []
	for i in 3:
		spots.append(ring("Spot%d" % i, 2, {"radius": 1.2, "color": Color.WHITE if i == 0 else C[6]}, {"parent": ball}))
	var heart: ColorRect = ring("Heart", 3, {"radius": 1.7, "color": Color.WHITE}, {"parent": ball, "at": Vector2(-0.6, -0.6)})
	glow("BallLight", 32, {"radius": 30, "color": C[4], "alpha": 0.3}, {"parent": ball})
	glow("BallShine", 11, {"radius": 9, "color": C[6], "alpha": 0.1}, {"parent": ball})
	# corona: short streaks bristling off the skin, gone in a frame or two
	var corona := particles("Corona", {"parent": ball, "local": true, "amount": 5, "lifetime": 0.07, "texture": "streak3",
		"align": true, "emit": {"ring": [7.5, 6.5]}, "speed": [0, 0], "initial": gradient([C[4], C[5]], [0.0, 0.5])})
	var cm: ParticleProcessMaterial = corona.process_material
	cm.radial_velocity_min = 20.0
	cm.radial_velocity_max = 30.0
	# arcs spat off its skin, re-struck every frame
	var arcs := []
	for i in 3:
		arcs.append(volt("Arc%d" % i, Vector2.ZERO, Vector2(6, 0), {"parent": ball, "style": 1, "jag": 0.4, "forks": 0.3, "rate": 30.0, "light": 0.25}))

	# once a loop, low over the floor, it zaps down
	var zap := volt("Zap", Vector2.ZERO, Vector2(GX, 0), {"jag": 0.28, "forks": 0.4, "thick": 0.7, "rate": 30.0, "light": 0.5, "visible": false})
	var spot_ring := ring("ZapSpot", 6, {"radius": 3.5, "color": C[5]}, {"at": Vector2(GX, -1)})
	var spot_px := rect("ZapPx", Rect2(GX, -1, 1, 1), Color.WHITE)
	var zap_light := glow("ZapLight", 36, {"radius": 34, "color": C[4], "alpha": 0.0}, {"at": Vector2(GX, -4)})
	var sp := sparks("ZapSparks", {"at": Vector2(GX, -1), "amount": 14, "lifetime": 0.55, "randomness": 0.5, "dir": -90, "spread": 75, "speed": [50, 170]})
	emit(sp, ZAP / FPS)

	var K := {"pos": [], "pool": [], "pool_a": [], "r_out": [], "r": [], "r_in": [], "heart": [], "zv": [], "zf": [], "zk": [], "zh": [],
		"ring": [], "zl": []}
	var S := [[], [], []]
	var A := []
	for i in 3:
		A.append({"v": [], "a": [], "b": [], "k": []})
	for f in N + 1:
		var t := f / FPS
		var st := maxf(0.0, (f - 0.5) / FPS)
		var p := at_t(t)
		K.pos.append([t, p])
		K.pool.append([t, Vector2(p.x, -2)])
		K.pool_a.append([t, 0.12 + 0.3 * clampf((p.y + 60.0) / 40.0, 0.0, 1.0)])
		var R0 := 5.2 + 0.6 * sin(t * 9.0) + 0.4 * rng.randf_range(-1, 1)
		K.r_out.append([st, R0 + 1.3])
		K.r.append([st, R0])
		K.r_in.append([st, R0 * 0.72])
		K.heart.append([st, R0 * 0.32])
		for i in 3:
			var a := t * (5.0 + i * 2.3) + i * 2.1
			S[i].append([st, Vector2(cos(a), sin(a) * 0.8) * R0 * 0.6])
		var n := 2 + (1 if rng.randf() < 0.4 else 0)
		for i in 3:
			if i < n:
				var a := rng.randf_range(0, TAU)
				var l := rng.randf_range(5, 11)
				var p0 := Vector2(cos(a), sin(a)) * (R0 + 1.0)
				var b := a + rng.randf_range(-0.7, 0.7)
				A[i].v.append([st, true])
				A[i].a.append([st, p0])
				A[i].b.append([st, p0 + Vector2(cos(b), sin(b)) * l])
				A[i].k.append([st, rng.randf_range(0.4, 0.7)])
			else:
				A[i].v.append([st, false])
		var za := (f % N) - ZAP
		var live := za >= 0 and za < 4
		var k: float = [1.0, 0.6, 0.9, 0.4][za] if live else 0.0
		K.zv.append([st, live])
		K.zf.append([st, p + Vector2(0, R0)])
		K.zk.append([st, k])
		K.zh.append([st, za == 0])
		K.ring.append([st, 2.5 * k + 1.0 if live else 0.0])
		K.zl.append([st, 0.6 * k])
	key(ball, "position", K.pos)
	for e in [wake, halo, wake_light, motes]:
		key(e, "position", K.pos)
	key(pool, "position", K.pool)
	key(pool, "material:shader_parameter/alpha", K.pool_a)
	key(skin_out, "material:shader_parameter/radius", K.r_out, "nearest")
	key(skin, "material:shader_parameter/radius", K.r, "nearest")
	key(inner, "material:shader_parameter/radius", K.r_in, "nearest")
	key(heart, "material:shader_parameter/radius", K.heart, "nearest")
	for i in 3:
		key(spots[i], "position", S[i], "nearest")
		key(arcs[i], "visible", A[i].v, "nearest")
		key(arcs[i], "from", A[i].a, "nearest")
		key(arcs[i], "to", A[i].b, "nearest")
		key(arcs[i], "k", A[i].k, "nearest")
	key(zap, "visible", K.zv, "nearest")
	key(zap, "from", K.zf, "nearest")
	key(zap, "k", K.zk, "nearest")
	key(zap, "hero", K.zh, "nearest")
	key(spot_ring, "material:shader_parameter/radius", K.ring, "nearest")
	key(zap_light, "material:shader_parameter/alpha", K.zl, "nearest")
	show(spot_px, ZAP / FPS - 0.5 / FPS, (ZAP + 4) / FPS - 0.5 / FPS)
