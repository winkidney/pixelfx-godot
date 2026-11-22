# reimagined-from: src/fx/projectiles/muzzle-pistol.js@44e57bc92b0f17d9f74c16f68ff10c6baa6f7fce
# Pistol shot: One pistol shot from a muzzle `height` px above the floor (the origin): a spiky white-cored flash, sparks, a curl of smoke hooking up and back, a casing that bounces and settles.
# one-shot, 1.80 s, 96x72 canvas, origin [44.0, 66.0], backdrop ground
# Everything the original spawns comes from its own Rng in its own order (projectiles/_projectiles.gd Rng), so this
# is its shot: the flash is its lobes (_projectiles.gd flash_shape() + flash(): the hero frame white-cored, then one
# cooler); the sparks and powder grains are GPU particles stepped with its physics (_muzzle.gd bits(): streaks that
# cool and drop, embers that flicker out, with their points of light); the smoke is its puffs as GPU particles
# (_muzzle.gd smoke_puffs(): a forward puff of gas and a chain of wisps that push out, slow and curl up and back,
# lit warm by the pop, drawn lit on their crowns by _lobe.gdshader); the casing tumbles up and back, bounces and
# settles along _lib.js casing() (_muzzle_casing.gdshader); the pop lights the muzzle and the floor.
extends "res://build/fx/projectiles/_muzzle.gd"

const F1 := 1.0 / 30.0


func make() -> void:
	var F := pal("palette")
	var B := pal("brass")
	var SM := pal("smoke")
	var D: float = root.duration
	var H: float = meta.options.height
	var MY := -H
	var R := Rng.new(int(meta.options.seed))
	var shape_seed := R.int_(0, 1000000)
	var tilt := R.range(-0.05, 0.05)
	# sparks spat forward, a few grains of unburnt powder that drop
	var bl := []
	for i in 6:
		var a := R.range(-0.3, 0.3)
		var sp := R.range(180, 400)
		spawn(bl, R, SPARK, 3, MY, cos(a) * sp, sin(a) * sp, R.range(0.06, 0.16))
	for i in 5:
		var a := R.range(-0.35, 0.25)
		var sp := R.range(60, 160)
		spawn(bl, R, EMBER, 3, MY, cos(a) * sp, sin(a) * sp, R.range(0.25, 0.5))
	# a puff of gas forward, then a chain of wisps that push out, slow and curl up and back over the muzzle
	var sl := []
	for i in 3:
		smoke_add(sl, R, {"x": 3.0, "y": MY, "vx": R.range(70, 120), "vy": R.range(-12, 6), "r0": 1.6, "r1": R.range(4.5, 6),
			"life": R.range(0.8, 1.05), "a": 0.55, "drag": 3.5, "rise": 10.0, "warm": 0.9, "delay": i * 0.012})
	for i in 14:
		var k := i / 13.0
		var q := {"x": 2.0, "y": MY}
		q.vx = 115.0 - 75.0 * k + R.range(-12, 12)
		q.vy = -6.0 - 10.0 * k + R.range(-5, 5)
		q.r0 = 1.4
		q.r1 = (3.6 + k * 2.6) * R.range(0.75, 1.25)
		q.life = 1.15 + k * 0.3
		q.a = 0.62
		q.b = R.range(0.85, 1)
		q.drag = 2.2
		q.rise = 6.0
		q.curl = -4.4 + k * 1.8 + R.range(-0.5, 0.5)
		q.grow = 1.6
		q.warm = 0.7
		q.delay = 0.02 + i * 0.022
		smoke_add(sl, R, q)
	smoke_add(sl, R, {"x": -7.0, "y": MY - 2, "vx": -6.0, "vy": -18.0, "r0": 1.2, "r1": 4.0, "life": 1.05, "a": 0.4, "rise": 8.0, "delay": 0.03})
	var shell := {}
	shell.vx = -R.range(25, 45)
	shell.vy = -R.range(95, 130)
	shell.va = R.sign() * R.range(22, 32)
	shell.a0 = R.range(0, 6.28)

	var pop := func(t: float) -> float: return exp(-(t + 0.008) / 0.035)
	# the smoke, its young puffs lit by the pop
	var WR := PackedColorArray([SM[0], mixc(F[1], SM[1], 0.5), mixc(F[2], SM[2], 0.4), F[3], F[4], F[5], F[7]])
	var smoke := smoke_puffs("Smoke", sl, SM, WR, {"dens": 1.5, "max": 0.8, "lit": 1.4})
	keyf(smoke, "process_material:shader_parameter/wmul", func(t: float) -> float: return 0.4 + pop.call(t), 0.0, 0.5)

	# the casing: out of the port, up and back, tumbling, a bounce or two, then it lies there and fades
	var cf := func(t: float) -> Dictionary:
		var k := casing(-7, MY - 1, shell.vx, shell.vy, shell.va, t, 850, -0.5, 0.42, shell.a0)
		k.fade = minf(1.0, (D - 0.05 - t) / 0.3)
		k.glint = 1.0 if (k.hit >= 0.0 and k.hit < 0.07) else 0.0
		return k
	var lo := Vector2(1e9, 1e9)
	var hi := -lo
	for i in int(D * 30.0) + 1:
		var k: Dictionary = cf.call(i / 30.0)
		lo = Vector2(minf(lo.x, k.x), minf(lo.y, k.y))
		hi = Vector2(maxf(hi.x, k.x), maxf(hi.y, k.y))
	casing_node("Casing", 0, [B[1], B[2], B[3]], lo, hi, cf, 0.0, D)
	var cg := light_at("CasingGlint", Vector2.ZERO, 5, B[3], 0.0)
	keyf(cg, "position", func(t: float) -> Vector2:
		var k: Dictionary = cf.call(t)
		return Vector2(k.x, k.y - 0.5), 0.0, D, 30.0, "nearest")
	keyf(cg, "material:shader_parameter/alpha", func(t: float) -> float:
		var k: Dictionary = cf.call(t)
		return 0.55 * (1.0 - k.hit / 0.07) if (k.hit >= 0.0 and k.hit < 0.07) else 0.0, 0.0, D, 30.0, "nearest")

	# the flash: the hero frame with a white core, then one cooler, smaller frame
	for f in [1, 2]:
		var L := flash_shape(rng([shape_seed]), f, {"size": 1.15, "spike": [15, 22], "diag": [7, 12], "cross": [4.5, 8], "back": [3, 5.5]})
		var C: Array = [Color.WHITE, F[7], F[6], F[3]] if f == 1 else [F[7], F[6], F[4], F[2]]
		var fl := flash("Flash%d" % f, Vector2(0, MY), tilt, L, C, f + int(meta.options.seed))
		var ff: int = f
		fl.visible = f == 1
		key_frames(fl, "visible", 6, func(t: float) -> bool: return t < 2 * F1 and (1 if t < F1 else 2 if t < 2 * F1 else 3) == ff)

	# sparks and grains
	bits("Sparks", bl, [F[7], F[6], F[4], F[3]])

	# light: the pop, its warm pool, a touch on the floor below
	pop_light("Pop", Vector2(4, MY), 30, F[4], 0.85, pop, 0.0, 0.4)
	pop_light("PopHot", Vector2(2, MY), 8, Color.WHITE, 0.5, pop, 0.0, 0.4)
	pop_light("PopFloor", Vector2(4, 0), 16, F[4], 0.2, pop, 0.0, 0.4)
