# reimagined-from: src/fx/projectiles/muzzle-shotgun.js@248ae511a1090ab181c0a9835bb6af9426233553
# Shotgun blast: A shotgun blast from a muzzle `height` px above the floor (the origin): a wide ragged fan of flame, pellet streaks, a heavy rolling smoke cloud, a red shell kicked out on the pump.
# one-shot, 3.20 s, 160x88 canvas, origin [44.0, 82.0], backdrop ground
# Everything the original spawns comes from its own Rng in its own order (projectiles/_projectiles.gd Rng): the
# flash is its fan (a fat fireball and nine ragged tongues across the cone: _projectiles.gd flash(), three frames
# cooling and spreading); the pellets, sparks and burning wad are GPU particles stepped with its physics (_muzzle.gd
# bits(): pellets streaking off the canvas in a few frames, sparks flung wide that cool and drop, embers flickering
# out, with their points of light); the smoke is its puffs as GPU particles (_muzzle.gd smoke_puffs(): a heavy shove
# of gas that slows, rolls, swells and lifts, lit warm by the blast, and a few wisps curling off the muzzle), lit on
# their crowns (_muzzle_lobe.gdshader); the red shell is kicked out on the pump, tumbles, bounces and lies a moment
# (_lib.js casing(), _muzzle_casing.gdshader); the pop floods the floor with light.
extends "res://build/fx/projectiles/_muzzle.gd"

const F1 := 1.0 / 30.0


## The original's fan(): a fat fireball at the muzzle and a spray of ragged tongues across the cone, each its own
## length (R: the original's 32 jitter numbers), frame f cooler and spread.
static func fan(R: Array, f: int) -> Array:
	var k := 1.0 if f == 1 else 0.82 if f == 2 else 0.55
	var w := 1.0 if f == 1 else 1.25
	var L := [{"off": 0.5, "a": 0.0, "len": 11.0 * k, "wid": 3.6 * w, "core": 0.5}]
	for i in 9:
		var u := i / 8.0 - 0.5
		var a: float = u * 1.15 + R[i * 3] * 0.12
		var ln: float = (17.0 + 11.0 * (1.0 - absf(u) * 1.4) + R[i * 3 + 1] * 7.0) * k
		L.append({"off": 2.0, "a": a, "len": ln, "wid": (1.7 + R[i * 3 + 2]) * w, "core": 0.32 if f == 1 else 0.0})
	if f == 1:
		for s: float in [-1.0, 1.0]:
			L.append({"off": 1.0, "a": s * (1.6 + R[27 + (1 if s > 0 else 0)] * 0.4), "len": 5.0 + R[29] * 3.0, "wid": 1.2, "core": 0.0})
	return L


func make() -> void:
	var F := pal("palette")
	var SM := pal("smoke")
	var SH := pal("shell")
	var D: float = root.duration
	var H: float = meta.options.height
	var MY := -H
	var R := Rng.new(int(meta.options.seed))
	var jit := []
	for i in 32:
		jit.append(R.next())
	# pellets: a tight spray, gone off the canvas in a few frames, each dragging a hot streak
	var bl := []
	for i in 10:
		var a := R.range(-0.13, 0.13)
		var v := R.range(900, 1150)
		var d0 := R.range(0, 4)
		bl.append({"kind": PELLET, "x": 0.0, "y": MY, "vx": a, "vy": v, "life": 0.2, "size": 1.0, "delay": 0.0, "seed": 0.0,
			"g": d0, "drag": 0.0, "stretch": 0.0, "max": 0.0, "floor": false, "glow": 0.5})
	# sparks and burning wad, flung wide
	for i in 16:
		var a := R.range(-0.55, 0.55)
		var sp := R.range(180, 460)
		spawn(bl, R, SPARK, 4, MY, cos(a) * sp, sin(a) * sp - 20, R.range(0.08, 0.3))
	for i in 7:
		var a := R.range(-0.5, 0.3)
		var sp := R.range(70, 200)
		spawn(bl, R, EMBER, 4, MY, cos(a) * sp, sin(a) * sp, R.range(0.4, 0.9))
	# the smoke: a heavy shove of gas forward that slows, rolls, swells and lifts; the first of it lit by the blast
	var sl := []
	for i in 26:
		var a := R.range(-0.45, 0.35)
		var sp := R.range(60, 230) * (1.15 if i < 8 else 0.8)
		var q := {}
		q.x = 4.0 + R.range(0, 4)
		q.y = MY + R.range(-1.5, 1.5)
		q.vx = cos(a) * sp
		q.vy = sin(a) * sp
		q.r0 = R.range(2.5, 3.5)
		q.r1 = R.range(7, 12.5)
		q.life = R.range(2.1, 2.9)
		q.a = R.range(0.55, 0.72)
		q.b = R.range(0.9, 1)
		q.drag = R.range(2.6, 3.6)
		q.rise = R.range(9, 15)
		q.grow = R.range(1.8, 2.8)
		q.warm = 1.0
		q.delay = R.range(0, 0.04)
		smoke_add(sl, R, q)
	for i in 6:
		var q := {"x": 2.0, "y": MY}
		q.vx = R.range(15, 50)
		q.vy = -R.range(10, 25)
		q.r0 = 1.5
		q.r1 = R.range(4, 6)
		q.life = R.range(1.8, 2.4)
		q.a = 0.5
		q.b = 1.0
		q.drag = 2.0
		q.rise = 10.0
		q.curl = -R.range(1.5, 3)
		q.warm = 0.6
		q.delay = 0.08 + i * 0.05
		smoke_add(sl, R, q)
	# the pump throws the spent shell a beat later
	var shell := {"t0": 0.42}
	shell.vx = -R.range(30, 55)
	shell.vy = -R.range(110, 150)
	shell.va = R.sign() * R.range(16, 24)
	shell.a0 = R.range(0, 6.28)

	var pop := func(t: float) -> float: return exp(-(t + 0.008) / 0.05)
	var WR := PackedColorArray([SM[0], mixc(F[1], SM[1], 0.5), mixc(F[2], SM[2], 0.4), F[3], F[4], F[5], F[7]])
	var smoke := smoke_puffs("Smoke", sl, SM, WR, {"dens": 1.4, "max": 0.86, "lit": 1.4})
	keyf(smoke, "process_material:shader_parameter/wmul", func(t: float) -> float: return 0.25 + pop.call(t) * 1.2, 0.0, 0.6)

	# the shell: red hull, brass head, tumbling up and back, bouncing, lying a moment
	var t0: float = shell.t0
	var cf := func(t: float) -> Dictionary:
		var k := casing(-9, MY, shell.vx, shell.vy, shell.va, maxf(0.0, t - t0), 850, -1, 0.35, shell.a0)
		k.fade = clampf((D - 0.05 - t) / 0.3, 0.0, 1.0)
		k.glint = 0.0
		return k
	var lo := Vector2(1e9, 1e9)
	var hi := -lo
	for i in int(D * 30.0) + 1:
		var k: Dictionary = cf.call(i / 30.0)
		lo = Vector2(minf(lo.x, k.x), minf(lo.y, k.y))
		hi = Vector2(maxf(hi.x, k.x), maxf(hi.y, k.y))
	casing_node("Shell", 1, [SH[0], SH[1], SH[2], SH[3], SH[4]], lo, hi, cf, t0 + 0.001, D - 0.05)
	var cg := light_at("ShellGlint", Vector2.ZERO, 5, SH[4], 0.0)
	keyf(cg, "position", func(t: float) -> Vector2:
		var k: Dictionary = cf.call(t)
		return Vector2(k.x, k.y), t0, D, 30.0, "nearest")
	keyf(cg, "material:shader_parameter/alpha", func(t: float) -> float:
		var k: Dictionary = cf.call(t)
		return 0.5 * (1.0 - k.hit / 0.07) if (t > t0 and k.hit >= 0.0 and k.hit < 0.07) else 0.0, t0, D, 30.0, "nearest")

	# the flash: a white-hot hero frame, then the fan cooling and spreading as the gas balloons
	var cols := [[Color.WHITE, F[7], F[6], F[3]], [F[7], F[6], F[4], F[2]], [F[5], F[4], F[3], F[1]]]
	for f in [1, 2, 3]:
		var fl := flash("Flash%d" % f, Vector2(0, MY), 0.0, fan(jit, f), cols[f - 1], f + 9)
		var ff: int = f
		fl.visible = f == 1
		key_frames(fl, "visible", 6, func(t: float) -> bool: return t < 3 * F1 and (1 if t < F1 else 2 if t < 2 * F1 else 3) == ff)

	# pellets, sparks and wad
	bits("Bits", bl, [F[7], F[6], F[4], F[3]], {"pellet": [Color.WHITE, F[6], F[4]]})

	# light: a big pop that floods the floor, a white heart
	pop_light("Pop", Vector2(8, MY), 46, F[4], 0.95, pop, 0.0, 0.6)
	pop_light("PopHot", Vector2(4, MY), 12, Color.WHITE, 0.6, pop, 0.0, 0.6)
	pop_light("PopFloor", Vector2(10, 0), 30, F[4], 0.28, pop, 0.0, 0.6)
